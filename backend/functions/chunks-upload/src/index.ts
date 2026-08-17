/**
 * `chunks-upload` — Chunk registration and presigned upload URLs. ADR-015 domain: chunks; role vump-{env}-chunks-upload, which holds s3:PutObject and cannot read.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   POST /v1/sessions/{sessionId}/chunks
 *
 * ## Every route here is provisioned and unimplemented, deliberately
 *
 * Each answers with a named `NOT_IMPLEMENTED` refusal in a real Chapter 4.6 §1
 * envelope. **Token verification runs first and is real** — an invalid or
 * expired bearer token gets `AUTH_TOKEN_INVALID` and never reaches the stub, so
 * the authentication path is demonstrable today while the queries behind it are
 * not. Mission 6.3 replaces the stubs; Mission 6.2 does not invent their data.
 */
import { createRouter, notImplementedRoute, routeKey, type RouteTable } from '@vump/shared';

const routes: RouteTable = {
  [routeKey('POST', '/v1/sessions/{sessionId}/chunks')]: notImplementedRoute(
    'POST /v1/sessions/{sessionId}/chunks',
    'Registering a chunk and presigning its multipart upload',
  ),
};

export const handler = createRouter('chunks-upload', routes);
