/**
 * The route inventory, asserted against Volume 4 Chapter 4.6's catalogue.
 *
 * This is the test that stops the scaffold drifting from the specification it
 * implements: fifteen endpoints, distributed across seven functions by resource
 * type rather than by URL nesting (the Mission 6.2.1 decision), with the chunks
 * domain split across two functions because it holds two roles (A-143).
 *
 * ## Sixteen routes, fifteen of them Chapter 4.6's
 *
 * Mission 7.6 adds `POST /v1/auth/redeem`, and it is kept in its own constant
 * rather than folded into `CATALOGUE`. **Chapter 4.6 still specifies fifteen
 * endpoints** — the retirement of ADR-036's Cloud Function did not change the
 * volumes, and a catalogue that quietly grew to sixteen would stop being a
 * transcription of anything.
 *
 * So the two are asserted separately: the catalogue against the specification
 * it copies, and the addition against the decision that introduced it. A future
 * route added to the wrong constant is then a visible category error rather
 * than an off-by-one in a count.
 */
import { describe, it, expect } from 'vitest';

import { handler as authVerify } from './auth-verify/src/index.js';
import { handler as projects } from './projects/src/index.js';
import { handler as tasks } from './tasks/src/index.js';
import { handler as sessions } from './sessions/src/index.js';
import { handler as chunksUpload } from './chunks-upload/src/index.js';
import { handler as chunksVerify } from './chunks-verify/src/index.js';
import { handler as metadata } from './metadata/src/index.js';
import { handler as redeem } from './redeem/src/index.js';

/** Chapter 4.6 §§2–4, transcribed. */
const CATALOGUE: Record<string, string[]> = {
  'auth-verify': ['POST /v1/auth/verify', 'GET /v1/users/me'],
  projects: ['GET /v1/projects', 'POST /v1/projects'],
  tasks: [
    'GET /v1/projects/{projectId}/tasks',
    'POST /v1/projects/{projectId}/tasks',
    'PATCH /v1/tasks/{taskId}',
    'POST /v1/tasks/{taskId}/assignments',
    'DELETE /v1/tasks/{taskId}/assignments/{userId}',
  ],
  sessions: ['POST /v1/tasks/{taskId}/sessions', 'GET /v1/tasks/{taskId}/sessions'],
  'chunks-upload': ['POST /v1/sessions/{sessionId}/chunks'],
  'chunks-verify': ['PATCH /v1/chunks/{chunkId}/status'],
  metadata: ['POST /v1/chunks/{chunkId}/metadata', 'GET /v1/chunks/{chunkId}/metadata'],
};

/**
 * Routes this backend serves that Chapter 4.6 does not specify.
 *
 * One entry, and it needs a decision behind it to be here: ADR-036 put
 * invite-code redemption in a Cloud Function and called the arrangement
 * temporary; Mission 7.6 retires it into a route, and ADR-048's Mission 7.6
 * amendment exempts that route from the REQUEST authorizer.
 */
const BEYOND_THE_CATALOGUE: Record<string, string[]> = {
  redeem: ['POST /v1/auth/redeem'],
};

/** Everything the API actually serves. */
const ALL_ROUTES: Record<string, string[]> = { ...CATALOGUE, ...BEYOND_THE_CATALOGUE };

const HANDLERS = {
  'auth-verify': authVerify,
  projects,
  tasks,
  sessions,
  'chunks-upload': chunksUpload,
  'chunks-verify': chunksVerify,
  metadata,
  redeem,
};

describe('the route inventory', () => {
  it('covers all fifteen Chapter 4.6 endpoints', () => {
    expect(Object.values(CATALOGUE).flat()).toHaveLength(15);
  });

  it('serves sixteen routes, the fifteenth-plus-one being redeem', () => {
    // Sixteen served, fifteen specified. The extra one is named rather than
    // counted, so adding another without a decision fails here.
    expect(Object.values(ALL_ROUTES).flat()).toHaveLength(16);
    expect(Object.values(BEYOND_THE_CATALOGUE).flat()).toEqual(['POST /v1/auth/redeem']);
  });

  it('has one function per ADR-015 domain, with two domains split in two', () => {
    // Eight functions across six domains. A Lambda has exactly one execution
    // role, so a domain needing two roles deploys two functions: chunks,
    // because one must write and not read while the other must read and not
    // write (A-143); and auth-verify, because one holds SELECT on `users` and
    // must not create Firebase accounts while the other does the reverse
    // (Mission 7.6).
    expect(Object.keys(HANDLERS)).toHaveLength(8);
    expect(Object.keys(HANDLERS)).toEqual(Object.keys(ALL_ROUTES));
  });

  it('exports a callable handler for every function', () => {
    for (const [name, handler] of Object.entries(HANDLERS)) {
      expect(typeof handler, `${name} must export a handler`).toBe('function');
    }
  });

  it('registers exactly the catalogued routes and no others', async () => {
    // Probed rather than introspected: an unregistered route returns a 404
    // envelope naming the key, and a registered one gets as far as auth.
    for (const [name, routes] of Object.entries(ALL_ROUTES)) {
      const handler = HANDLERS[name as keyof typeof HANDLERS];

      for (const route of routes) {
        const [method, resource] = route.split(' ');
        const response = await handler({
          httpMethod: method,
          resource,
          headers: {},
        } as never);

        // Registration is proved by "not 404". Since ADR-048 the *reason* a
        // bare request is refused differs by route, and that difference is the
        // architecture: POST /v1/auth/verify verifies its own token and says
        // AUTH_TOKEN_MISSING; every other route expects an authorizer context
        // that only API Gateway can supply, so a hand-made event without one
        // is a configuration error rather than an unauthenticated caller.
        //
        // POST /v1/auth/redeem is the third case and the reason this is a
        // per-route expectation rather than one widened list. It is
        // unauthenticated by design, so a bare request is a VALID request and
        // it is refused on behaviour instead — 501 until Phase 4 implements it.
        // Widening the shared list to [401, 500, 501] would let any route
        // answer 501 and still pass, which would stop the assertion meaning
        // that authorized routes refuse unauthenticated callers.
        const acceptable = name === 'redeem' ? [501] : [401, 500];

        expect(response.statusCode, `${name}: ${route} should be registered`).not.toBe(404);
        expect(acceptable, `${name}: ${route} should refuse a bare request`).toContain(
          response.statusCode,
        );
      }

      const unknown = await handler({
        httpMethod: 'GET',
        resource: '/v1/not-a-route',
        headers: {},
      } as never);
      expect(unknown.statusCode, `${name}: unknown route should 404`).toBe(404);
    }
  });

  it('refuses a request with no authorizer context, rather than running the stub', async () => {
    const response = await chunksUpload({
      httpMethod: 'POST',
      resource: '/v1/sessions/{sessionId}/chunks',
      headers: {},
      requestContext: {},
    });

    // ADR-048: a route behind the authorizer cannot be reached without one.
    // Failing here rather than falling back to an unauthenticated path is what
    // stops a detached authorizer from silently opening an endpoint.
    expect(response.statusCode).toBe(500);
    expect(JSON.parse(response.body).error.code).toBe('INTERNAL_ERROR');
  });

  it('still names a missing bearer token on the one route that verifies its own', async () => {
    const response = await authVerify({
      httpMethod: 'POST',
      resource: '/v1/auth/verify',
      headers: {},
      requestContext: {},
    });

    expect(JSON.parse(response.body).error.code).toBe('AUTH_TOKEN_MISSING');
  });
});
