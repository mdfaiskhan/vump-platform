/**
 * `metadata` — Chunk metadata. ADR-015 domain: metadata. Holds no S3 permission at all.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   POST /v1/chunks/{chunkId}/metadata
 *   GET /v1/chunks/{chunkId}/metadata
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
  [routeKey('POST', '/v1/chunks/{chunkId}/metadata')]: notImplementedRoute(
    'POST /v1/chunks/{chunkId}/metadata',
    "Recording a chunk's metadata document",
  ),
  [routeKey('GET', '/v1/chunks/{chunkId}/metadata')]: notImplementedRoute(
    'GET /v1/chunks/{chunkId}/metadata',
    "Reading a chunk's metadata document",
  ),
};

export const handler = createRouter('metadata', routes);
