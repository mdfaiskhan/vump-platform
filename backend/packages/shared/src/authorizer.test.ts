import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { APIGatewayRequestAuthorizerEvent } from 'aws-lambda';

// `verifyToken` and `lookupCaller` are mocked so this file tests the
// authorizer's own two decisions and nothing else. What each of them does for
// real is established elsewhere — `verify_token.test.ts` and the deployed-route
// tests — and re-proving it here would make a failure ambiguous.
vi.mock('./auth.js', async (importOriginal) => {
  const actual = await importOriginal<typeof import('./auth.js')>();
  return { ...actual, verifyToken: vi.fn() };
});
vi.mock('./caller.js', () => ({ lookupCaller: vi.fn() }));

const { verifyToken } = await import('./auth.js');
const { lookupCaller } = await import('./caller.js');
const { authorize, isAuthorizerEvent } = await import('./authorizer.js');

const IDENTITY = {
  firebaseUid: 'firebase-uid-1',
  email: 'collector@example.com',
  roleClaim: 'collector',
  orgIdClaim: '00000000-0000-4000-8000-0000000000d1',
};

const CALLER = {
  userId: '11111111-1111-4111-8111-111111111111',
  orgId: '00000000-0000-4000-8000-0000000000d1',
  role: 'collector',
};

const ARN = 'arn:aws:execute-api:ap-south-1:123456789012:abc/dev/GET/v1/projects';

function event(headers: Record<string, string>): APIGatewayRequestAuthorizerEvent {
  return { type: 'REQUEST', methodArn: ARN, headers } as APIGatewayRequestAuthorizerEvent;
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(verifyToken).mockResolvedValue(IDENTITY);
  vi.mocked(lookupCaller).mockResolvedValue(CALLER);
  vi.spyOn(console, 'log').mockImplementation(() => undefined);
  vi.spyOn(console, 'warn').mockImplementation(() => undefined);
});

afterEach(() => vi.restoreAllMocks());

/**
 * ADR-048's REQUEST authorizer, untested until Mission 8.1 and exempted from
 * the coverage gate at 9% since Mission 7.9.
 *
 * It has exactly two outcomes and they are not symmetrical. An Allow carries
 * the caller's identity forward in `context`, which every downstream handler
 * then trusts without re-deriving it — so a field missing or misspelled here
 * is not a failure, it is a handler running against the wrong tenant. A Deny
 * must carry no context at all.
 */
describe('isAuthorizerEvent', () => {
  it('accepts a REQUEST event carrying a methodArn', () => {
    expect(isAuthorizerEvent({ type: 'REQUEST', methodArn: ARN })).toBe(true);
  });

  it.each([
    ['null', null],
    ['a string', 'REQUEST'],
    ['a number', 42],
    ['an object with no type', { methodArn: ARN }],
    ['a TOKEN authorizer event', { type: 'TOKEN', methodArn: ARN }],
    ['a REQUEST event with no methodArn', { type: 'REQUEST' }],
    ['a REQUEST event whose methodArn is not a string', { type: 'REQUEST', methodArn: 7 }],
  ])('rejects %s', (_name, candidate) => {
    // Each row is one condition in the guard. Removing any single check must
    // fail at least one of these, or the guard is wider than it reads.
    expect(isAuthorizerEvent(candidate)).toBe(false);
  });
});

describe('authorize — the Allow path', () => {
  it('returns an Allow policy scoped to the invoked method ARN', async () => {
    const result = await authorize(event({ authorization: 'Bearer token-1' }));

    expect(result.policyDocument.Statement[0]).toEqual({
      Action: 'execute-api:Invoke',
      Effect: 'Allow',
      Resource: ARN,
    });
    expect(result.policyDocument.Version).toBe('2012-10-17');
  });

  it('carries the caller the handlers will trust, and the Firebase uid', async () => {
    // Chapter 4.7 §1: the handler reads these rather than resolving them
    // again. `userId` is `users.id`, NOT the Firebase uid — A-206 is the
    // defect that arose from confusing the two, and both appear here.
    const result = await authorize(event({ authorization: 'Bearer token-1' }));

    expect(result.context).toEqual({
      userId: CALLER.userId,
      orgId: CALLER.orgId,
      role: CALLER.role,
      firebaseUid: IDENTITY.firebaseUid,
    });
    expect(result.principalId).toBe(IDENTITY.firebaseUid);
  });

  it('reads a lower-case `authorization` header and an upper-case one', async () => {
    // API Gateway's casing depends on the client. A fallback that only
    // handled one spelling would deny real callers intermittently.
    await authorize(event({ authorization: 'Bearer lower' }));
    expect(vi.mocked(verifyToken)).toHaveBeenCalledWith('lower');

    await authorize(event({ Authorization: 'Bearer upper' }));
    expect(vi.mocked(verifyToken)).toHaveBeenCalledWith('upper');
  });
});

describe('authorize — the Deny path', () => {
  it('denies explicitly when the token does not verify', async () => {
    vi.mocked(verifyToken).mockRejectedValue(new Error('token expired'));

    const result = await authorize(event({ authorization: 'Bearer stale' }));

    expect(result.policyDocument.Statement[0].Effect).toBe('Deny');
    expect(result.principalId).toBe('unauthorized');
  });

  it('denies when the token verifies but no users row exists', async () => {
    // Two different failures, one answer. A caller who is authenticated to
    // Firebase but unknown to this database is not authorized here.
    vi.mocked(lookupCaller).mockRejectedValue(new Error('user not found'));

    const result = await authorize(event({ authorization: 'Bearer orphan' }));

    expect(result.policyDocument.Statement[0].Effect).toBe('Deny');
  });

  it('denies when the Authorization header is absent entirely', async () => {
    vi.mocked(verifyToken).mockRejectedValue(new Error('missing bearer token'));

    const result = await authorize(event({}));

    expect(result.policyDocument.Statement[0].Effect).toBe('Deny');
  });

  it('attaches no context to a Deny', async () => {
    // The context is what a handler trusts. A Deny that carried one would
    // hand identity to a request the authorizer just refused.
    vi.mocked(verifyToken).mockRejectedValue(new Error('nope'));

    const result = await authorize(event({ authorization: 'Bearer x' }));

    expect(result.context).toBeUndefined();
  });

  it('never lets the underlying error escape to the caller', async () => {
    // API Gateway turns a thrown authorizer into a 500. An explicit Deny is a
    // 403, which is the answer the client should get.
    vi.mocked(lookupCaller).mockRejectedValue(new Error('data api timeout'));

    await expect(authorize(event({ authorization: 'Bearer x' }))).resolves.toBeDefined();
  });
});
