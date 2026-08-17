/**
 * `auth-verify` — Token verification and the caller's own profile. ADR-015 domain: auth-verify.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   POST /v1/auth/verify
 *   GET /v1/users/me
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
  [routeKey('POST', '/v1/auth/verify')]: notImplementedRoute(
    'POST /v1/auth/verify',
    'Exchanging a verified token for the session context (role, org_id)',
  ),
  [routeKey('GET', '/v1/users/me')]: notImplementedRoute(
    'GET /v1/users/me',
    "Reading the current user's profile and role",
  ),
};

export const handler = createRouter('auth-verify', routes);
