/**
 * `auth-verify` — Token verification, first-login provisioning, and the
 * REQUEST authorizer for every other route. ADR-015 domain: auth-verify.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   POST /v1/auth/verify   — exempt from the authorizer, and the reason it exists
 *   GET  /v1/users/me      — behind the authorizer, like everything else
 *
 * ## This function is invoked two ways, and that is deliberate — ADR-048
 *
 * API Gateway calls it as the **authorizer** for the other fourteen routes,
 * and as the **handler** for its own two. One function, because only
 * `vump_auth_verify` holds `SELECT` on `users` (migration `0007`, enforcing
 * Volume 8 Chapter 8.4 §1). A separate authorizer function would need the same
 * grant, which would mean a second database role, a second credential and a
 * second secret — to run the same query this function is already the only one
 * permitted to run.
 *
 * The two invocations are told apart by the event shape, not by configuration:
 * an authorizer event carries `type: 'REQUEST'` and a `methodArn`, and a proxy
 * event does not.
 *
 * ## Why POST /v1/auth/verify is not behind the authorizer
 *
 * The authorizer refuses a caller with no `users` row (Chapter 4.7 §4). This
 * route is what creates that row (Chapter 4.7 §1 step 4). Behind the
 * authorizer it would be unreachable by exactly the callers it exists for, and
 * since nothing else writes to `users`, every account would be locked out of
 * every route permanently. A-166.
 */
import type { APIGatewayProxyEvent } from 'aws-lambda';
import {
  authorize,
  createRouter,
  isAuthorizerEvent,
  lookupCaller,
  provisionCaller,
  routeKey,
  withEnvelope,
  withVerifiedToken,
  type RouteTable,
} from '@vump/shared';

/** The session context Chapter 4.6 §2 says this endpoint returns. */
interface SessionContext {
  readonly userId: string;
  readonly orgId: string;
  readonly role: string;
}

const routes: RouteTable = {
  // Chapter 4.6 §2: "Exchanges a Firebase ID token for the app's session
  // context (role, org_id)." Chapter 4.7 §1 step 4's "or creates, on first
  // login" is this route's job and only this route's.
  [routeKey('POST', '/v1/auth/verify')]: withVerifiedToken(
    'POST /v1/auth/verify',
    async (_event, identity) => {
      const caller = await provisionCaller(identity);
      return { data: caller satisfies SessionContext };
    },
  ),

  // Behind the authorizer, so the row is guaranteed to exist by the time this
  // runs. It re-reads rather than trusting the context alone because Chapter
  // 4.6 §2 calls it a "profile" — more than the three fields the authorizer
  // carries — and because Chapter 4.7 §2 makes the table authoritative.
  [routeKey('GET', '/v1/users/me')]: withEnvelope('GET /v1/users/me', async (_event, caller) => {
    const fresh = await lookupCaller(caller.identity);
    return { data: fresh satisfies SessionContext };
  }),
};

const router = createRouter('auth-verify', routes);

export const handler = async (event: unknown): Promise<unknown> => {
  if (isAuthorizerEvent(event)) {
    return authorize(event);
  }
  return router(event as APIGatewayProxyEvent);
};
