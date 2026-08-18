import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { APIGatewayProxyEvent } from 'aws-lambda';

// Mocked so the suite never reaches Google. What verifyToken does for real is
// established by the probe recorded in A-149, not re-proved on every test run.
vi.mock('./auth.js', async (importOriginal) => {
  const actual = await importOriginal<typeof import('./auth.js')>();
  return { ...actual, verifyToken: vi.fn() };
});

const { verifyToken } = await import('./auth.js');
const { withEnvelope, withVerifiedToken, notImplementedRoute } = await import('./handler.js');
const { ApiError } = await import('./errors.js');

/**
 * A request as it arrives *behind the authorizer* — ADR-048.
 *
 * The authorizer context is what fourteen of the fifteen routes read instead
 * of verifying a token themselves.
 */
function event(context: Record<string, string> | null = AUTHORIZED): APIGatewayProxyEvent {
  return {
    httpMethod: 'GET',
    resource: '/v1/projects',
    headers: {},
    requestContext: { authorizer: context },
  } as unknown as APIGatewayProxyEvent;
}

/** A request to the ONE exempt route, which carries a bearer token instead. */
function tokenEvent(header?: string): APIGatewayProxyEvent {
  return {
    httpMethod: 'POST',
    resource: '/v1/auth/verify',
    headers: header === undefined ? {} : { authorization: header },
    requestContext: {},
  } as unknown as APIGatewayProxyEvent;
}

const AUTHORIZED = {
  userId: 'u-1',
  orgId: '00000000-0000-4000-8000-000000000001',
  role: 'collector',
  firebaseUid: 'uid-1',
};

const identity = {
  firebaseUid: 'uid-1',
  roleClaim: 'collector',
  orgIdClaim: 'vump-default',
  email: 'a@b.test',
};

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

describe('withEnvelope, behind the authorizer', () => {
  it('builds the caller from the authorizer context and never verifies a token', async () => {
    const seen: unknown[] = [];

    await withEnvelope('test', async (_e, caller) => {
      seen.push(caller);
      return Promise.resolve({ data: null });
    })(event());

    // The whole point of ADR-048: the lookup happened once, upstream.
    expect(verifyToken).not.toHaveBeenCalled();
    expect(seen[0]).toMatchObject({
      userId: 'u-1',
      orgId: '00000000-0000-4000-8000-000000000001',
      role: 'collector',
    });
  });

  it('fails rather than falling back when the authorizer context is absent', async () => {
    const domain = vi.fn();

    const response = await withEnvelope('test', domain)(event(null));

    // A detached authorizer must not silently become an open endpoint.
    expect(domain).not.toHaveBeenCalled();
    expect(response.statusCode).toBe(500);
    expect(JSON.parse(response.body).error.code).toBe('INTERNAL_ERROR');
  });

  it('fails when the context is present but incomplete', async () => {
    const response = await withEnvelope('test', vi.fn())(event({ userId: 'u-1' }));

    expect(response.statusCode).toBe(500);
  });

  it('wraps a result in a success envelope', async () => {
    const response = await withEnvelope('test', async () =>
      Promise.resolve({ data: { id: 'p1' } }),
    )(event());

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body)).toEqual({ data: { id: 'p1' }, error: null });
  });

  it('passes pagination meta through as a sibling of data', async () => {
    const response = await withEnvelope('test', async () =>
      Promise.resolve({ data: [], meta: { nextCursor: 'c1' } }),
    )(event());

    expect(JSON.parse(response.body).meta).toEqual({ nextCursor: 'c1' });
  });

  it('does not leak an unexpected error message to the caller', async () => {
    const response = await withEnvelope('test', () => {
      throw new Error('relation "users" does not exist');
    })(event());

    expect(response.statusCode).toBe(500);
    const body = JSON.parse(response.body);
    expect(body.error.code).toBe('INTERNAL_ERROR');
    expect(body.error.message).not.toContain('users');
  });

  it('sets no-store and nosniff on every response', async () => {
    const response = await withEnvelope('test', async () => Promise.resolve({ data: null }))(
      event(),
    );

    expect(response.headers?.['cache-control']).toBe('no-store');
    expect(response.headers?.['x-content-type-options']).toBe('nosniff');
  });
});

describe('withVerifiedToken, the one exempt route', () => {
  it('verifies the token BEFORE invoking the domain handler', async () => {
    const order: string[] = [];
    vi.mocked(verifyToken).mockImplementation(async () => {
      order.push('verify');
      return Promise.resolve(identity);
    });
    const handler = withVerifiedToken('test', async () => {
      order.push('handler');
      return Promise.resolve({ data: { ok: true } });
    });

    await handler(tokenEvent('Bearer t'));

    // Chapter 4.7 §1 step 3: rejected "before any database query runs".
    expect(order).toEqual(['verify', 'handler']);
  });

  it('never invokes the handler when the token is invalid', async () => {
    vi.mocked(verifyToken).mockRejectedValue(ApiError.tokenInvalid());
    const domain = vi.fn();

    const response = await withVerifiedToken('test', domain)(tokenEvent('Bearer bad'));

    expect(domain).not.toHaveBeenCalled();
    expect(response.statusCode).toBe(401);
    expect(JSON.parse(response.body).error.code).toBe('AUTH_TOKEN_INVALID');
  });

  it('rejects a missing Authorization header without calling verifyToken', async () => {
    const response = await withVerifiedToken('test', vi.fn())(tokenEvent());

    expect(verifyToken).not.toHaveBeenCalled();
    expect(JSON.parse(response.body).error.code).toBe('AUTH_TOKEN_MISSING');
  });

  it('hands the verified identity to the handler, not a Caller', async () => {
    const seen: unknown[] = [];

    await withVerifiedToken('test', async (_e, id) => {
      seen.push(id);
      return Promise.resolve({ data: null });
    })(tokenEvent('Bearer t'));

    // At this point the users row may not exist yet — that is the reason this
    // route is exempt from the authorizer at all.
    expect(seen[0]).toEqual(identity);
  });
});

describe('notImplementedRoute', () => {
  it('answers 501 with a named code, behind the authorizer', async () => {
    const response = await notImplementedRoute('GET /v1/projects', 'Listing projects')(event());

    expect(response.statusCode).toBe(501);
    expect(JSON.parse(response.body).error.code).toBe('NOT_IMPLEMENTED');
  });
});
