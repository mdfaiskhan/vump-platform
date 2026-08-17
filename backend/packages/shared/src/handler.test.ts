import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { APIGatewayProxyEvent } from 'aws-lambda';

// Mocked so the suite never reaches Google. What verifyToken does for real is
// established by the probe recorded in A-149, not re-proved on every test run.
vi.mock('./auth.js', async (importOriginal) => {
  const actual = await importOriginal<typeof import('./auth.js')>();
  return { ...actual, verifyToken: vi.fn() };
});

const { verifyToken } = await import('./auth.js');
const { withEnvelope, notImplementedRoute } = await import('./handler.js');
const { ApiError } = await import('./errors.js');

function event(header?: string): APIGatewayProxyEvent {
  return {
    httpMethod: 'GET',
    resource: '/v1/projects',
    headers: header === undefined ? {} : { authorization: header },
  } as unknown as APIGatewayProxyEvent;
}

const identity = { firebaseUid: 'uid-1', roleClaim: 'collector', email: 'a@b.test' };

beforeEach(() => {
  // The module mock is created once at import time, so its call record
  // survives restoreAllMocks and accumulates across tests. Cleared explicitly,
  // or "was verifyToken called?" answers for the whole file rather than for
  // the test asking.
  vi.clearAllMocks();
  vi.mocked(verifyToken).mockResolvedValue(identity);
  vi.spyOn(console, 'log').mockImplementation(() => undefined);
  vi.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => vi.restoreAllMocks());

describe('withEnvelope', () => {
  it('verifies the token BEFORE invoking the domain handler', async () => {
    const order: string[] = [];
    vi.mocked(verifyToken).mockImplementation(async () => {
      order.push('verify');
      return Promise.resolve(identity);
    });
    const handler = withEnvelope('test', async () => {
      order.push('handler');
      return Promise.resolve({ data: { ok: true } });
    });

    await handler(event('Bearer t'));

    // Chapter 4.7 §1 step 3: rejected "before any database query runs".
    expect(order).toEqual(['verify', 'handler']);
  });

  it('never invokes the handler when the token is invalid', async () => {
    vi.mocked(verifyToken).mockRejectedValue(ApiError.tokenInvalid());
    const domain = vi.fn();

    const response = await withEnvelope('test', domain)(event('Bearer bad'));

    expect(domain).not.toHaveBeenCalled();
    expect(response.statusCode).toBe(401);
    expect(JSON.parse(response.body).error.code).toBe('AUTH_TOKEN_INVALID');
  });

  it('rejects a missing Authorization header without calling verifyToken', async () => {
    const response = await withEnvelope('test', vi.fn())(event());

    expect(verifyToken).not.toHaveBeenCalled();
    expect(JSON.parse(response.body).error.code).toBe('AUTH_TOKEN_MISSING');
  });

  it('wraps a result in a success envelope', async () => {
    const response = await withEnvelope('test', async () =>
      Promise.resolve({ data: { id: 'p1' } }),
    )(event('Bearer t'));

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body)).toEqual({ data: { id: 'p1' }, error: null });
  });

  it('passes pagination meta through as a sibling of data', async () => {
    const response = await withEnvelope('test', async () =>
      Promise.resolve({ data: [], meta: { nextCursor: 'c1' } }),
    )(event('Bearer t'));

    expect(JSON.parse(response.body).meta).toEqual({ nextCursor: 'c1' });
  });

  it('does not leak an unexpected error message to the caller', async () => {
    const response = await withEnvelope('test', () => {
      throw new Error('relation "users" does not exist');
    })(event('Bearer t'));

    expect(response.statusCode).toBe(500);
    const body = JSON.parse(response.body);
    expect(body.error.code).toBe('INTERNAL_ERROR');
    expect(body.error.message).not.toContain('users');
  });

  it('sets no-store and nosniff on every response', async () => {
    const response = await withEnvelope('test', async () => Promise.resolve({ data: null }))(
      event('Bearer t'),
    );

    expect(response.headers?.['cache-control']).toBe('no-store');
    expect(response.headers?.['x-content-type-options']).toBe('nosniff');
  });

  it('gives the caller no user id, because Mission 6.2 does not look one up', async () => {
    const seen: unknown[] = [];
    await withEnvelope('test', async (_e, caller) => {
      seen.push(caller);
      return Promise.resolve({ data: null });
    })(event('Bearer t'));

    // The stub must not fabricate an id: a handler that needs orgId has to
    // fail rather than scope a query to an invented org.
    expect(seen[0]).toEqual({ identity, userId: undefined, orgId: undefined, role: undefined });
  });
});

describe('notImplementedRoute', () => {
  it('answers 501 with a named code, after real token verification', async () => {
    const response = await notImplementedRoute(
      'GET /v1/projects',
      'Listing projects',
    )(event('Bearer t'));

    expect(verifyToken).toHaveBeenCalledOnce();
    expect(response.statusCode).toBe(501);
    expect(JSON.parse(response.body).error.code).toBe('NOT_IMPLEMENTED');
  });

  it('rejects an invalid token before the stub, so auth is demonstrable today', async () => {
    vi.mocked(verifyToken).mockRejectedValue(ApiError.tokenInvalid());

    const response = await notImplementedRoute(
      'GET /v1/projects',
      'Listing projects',
    )(event('Bearer bad'));

    expect(response.statusCode).toBe(401);
    expect(JSON.parse(response.body).error.code).toBe('AUTH_TOKEN_INVALID');
  });
});
