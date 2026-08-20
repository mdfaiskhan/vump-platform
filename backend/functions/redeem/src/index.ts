/**
 * `redeem` — invite-code redemption and account creation.
 *
 * Routes served:
 *
 *   POST /v1/auth/redeem   — exempt from the authorizer, and unauthenticated
 *
 * ## Why this function exists
 *
 * It retires ADR-036's Firebase Cloud Function. That decision put redemption
 * outside AWS for one stated reason — "running the Admin SDK outside Google
 * means holding a service-account private key that can grant `admin` on any
 * organisation" — and Mission 7.6 Phase 2 removed the reason rather than
 * accepting it: this function reaches Firebase through Workload Identity
 * Federation, so no key exists anywhere (A-221).
 *
 * ## Why it is its own function and not a route on `auth-verify`
 *
 * A Lambda has exactly one execution role, and these two need opposite
 * privileges. `auth-verify` holds `SELECT` on `users` and must not be able to
 * create Firebase accounts; this function creates Firebase accounts and must
 * not be able to read `users`. One function would hold both, and the
 * separation would be a convention rather than a boundary — the same reasoning
 * A-143 applies to the chunks domain.
 *
 * ADR-015's six domains are unchanged: this is a second role in the
 * `auth-verify` domain, not a seventh domain.
 *
 * ## Why it is unauthenticated
 *
 * Its caller has no Firebase account — creating one is the point. There is no
 * token to verify and no `users` row to look up, so the REQUEST authorizer
 * would refuse every legitimate caller. ADR-048's Mission 7.6 amendment
 * records the exemption and why the exempt list is a named allowlist rather
 * than a count.
 *
 * **What limits exposure is not authentication.** A-056 made the invite code
 * optional, so it gates nothing. What bounds this route is that self-signup
 * can only ever produce a Collector in an organisation with no Tasks assigned
 * to it.
 *
 * ## Status — Phase 3 of 6
 *
 * **The route is provisioned and the behaviour is not implemented.** Phase 3
 * builds the infrastructure: the function, its execution role, its database
 * credential and its federation identifiers. Phase 4 ports the logic from
 * `functions/src/index.ts` onto Postgres.
 *
 * It answers `NOT_IMPLEMENTED` in a real envelope rather than a fabricated
 * success, for the reason `notImplementedRoute` gives: a stub that returns
 * invented data is indistinguishable from a working integration until
 * something depends on it. `notImplementedRoute` itself is not usable here —
 * it wraps `withEnvelope`, which reads an authorizer context this route does
 * not have, so a caller would receive a misleading 401 instead of a 501.
 */
import type { APIGatewayProxyEvent } from 'aws-lambda';
import {
  ApiError,
  createRouter,
  routeKey,
  withoutAuthentication,
  type HandlerResult,
  type RouteTable,
} from '@vump/shared';

const routes: RouteTable = {
  [routeKey('POST', '/v1/auth/redeem')]: withoutAuthentication(
    'POST /v1/auth/redeem',
    (): Promise<HandlerResult<never>> => {
      throw ApiError.notImplemented('Invite-code redemption');
    },
  ),
};

const router = createRouter('redeem', routes);

export const handler = async (event: unknown): Promise<unknown> =>
  router(event as APIGatewayProxyEvent);
