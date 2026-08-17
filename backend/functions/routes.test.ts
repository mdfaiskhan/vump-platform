/**
 * The route inventory, asserted against Volume 4 Chapter 4.6's catalogue.
 *
 * This is the test that stops the scaffold drifting from the specification it
 * implements: fifteen endpoints, distributed across seven functions by resource
 * type rather than by URL nesting (the Mission 6.2.1 decision), with the chunks
 * domain split across two functions because it holds two roles (A-143).
 */
import { describe, it, expect } from 'vitest';

import { handler as authVerify } from './auth-verify/src/index.js';
import { handler as projects } from './projects/src/index.js';
import { handler as tasks } from './tasks/src/index.js';
import { handler as sessions } from './sessions/src/index.js';
import { handler as chunksUpload } from './chunks-upload/src/index.js';
import { handler as chunksVerify } from './chunks-verify/src/index.js';
import { handler as metadata } from './metadata/src/index.js';

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

const HANDLERS = {
  'auth-verify': authVerify,
  projects,
  tasks,
  sessions,
  'chunks-upload': chunksUpload,
  'chunks-verify': chunksVerify,
  metadata,
};

describe('the route inventory', () => {
  it('covers all fifteen Chapter 4.6 endpoints', () => {
    expect(Object.values(CATALOGUE).flat()).toHaveLength(15);
  });

  it('has one function per ADR-015 domain, with chunks split in two', () => {
    // Seven functions across six domains. The chunks domain deploys two
    // because a Lambda has exactly one execution role and A-143 gave the
    // domain two — one that can write and not read, one the reverse.
    expect(Object.keys(HANDLERS)).toHaveLength(7);
    expect(Object.keys(HANDLERS)).toEqual(Object.keys(CATALOGUE));
  });

  it('exports a callable handler for every function', () => {
    for (const [name, handler] of Object.entries(HANDLERS)) {
      expect(typeof handler, `${name} must export a handler`).toBe('function');
    }
  });

  it('registers exactly the catalogued routes and no others', async () => {
    // Probed rather than introspected: an unregistered route returns a 404
    // envelope naming the key, and a registered one gets as far as auth.
    for (const [name, routes] of Object.entries(CATALOGUE)) {
      const handler = HANDLERS[name as keyof typeof HANDLERS];

      for (const route of routes) {
        const [method, resource] = route.split(' ');
        const response = await handler({
          httpMethod: method,
          resource,
          headers: {},
        } as never);

        // 401 (no token) proves the route matched and reached the wrapper.
        expect(response.statusCode, `${name}: ${route} should be registered`).toBe(401);
      }

      const unknown = await handler({
        httpMethod: 'GET',
        resource: '/v1/not-a-route',
        headers: {},
      } as never);
      expect(unknown.statusCode, `${name}: unknown route should 404`).toBe(404);
    }
  });

  it('rejects an unauthenticated request before reaching any stub', async () => {
    const response = await chunksUpload({
      httpMethod: 'POST',
      resource: '/v1/sessions/{sessionId}/chunks',
      headers: {},
    } as never);

    expect(JSON.parse(response.body).error.code).toBe('AUTH_TOKEN_MISSING');
  });
});
