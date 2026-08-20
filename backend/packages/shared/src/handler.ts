/**
 * The one wrapper every Lambda handler goes through.
 *
 * It is the executable form of Volume 4, Chapter 4.7 §4's pseudocode, which is
 * written as middleware ending in `return next()`. Putting it here rather than
 * in each function is the whole argument for the shared package: **seven copies
 * of a token-verification path is the worst thing in this codebase to
 * duplicate**, and drift between them would be a security defect rather than a
 * maintenance annoyance.
 *
 * Responsibilities, in order:
 *
 * 1. Verify the bearer token — Chapter 4.7 §1 step 3, *"before any database
 *    query runs"*.
 * 2. Resolve the caller's `users` row. **Stubbed in Mission 6.2** — see
 *    {@link resolveCaller}.
 * 3. Invoke the domain handler.
 * 4. Wrap whatever comes back in Chapter 4.6 §1's envelope, success or failure.
 */
import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { bearerToken, verifyToken, type TokenIdentity } from './auth.js';
import { success, failure, type EnvelopeMeta } from './envelope.js';
import { ApiError, toEnvelopeError } from './errors.js';
import { logger } from './logger.js';

/**
 * The caller, once both the token and the `users` row are known.
 *
 * ## Why these are not optional — Mission 7.3
 *
 * They used to be `string | undefined`, from Mission 6.2 when `resolveCaller`
 * was a stub that genuinely could not produce them. ADR-048 replaced that: the
 * authorizer resolves the row, and {@link callerFromContext} **throws** when
 * any of the three is missing rather than returning a half-built caller.
 *
 * So the optionality described a state that can no longer reach a handler, and
 * it was not free. ADR-045 adopts `strictTypeChecked`, which forbids
 * `no-non-null-assertion` — so every one of the fourteen authorized routes
 * would have had to re-narrow three fields the wrapper already guaranteed, and
 * each of those guards would be dead code asserting something proven one frame
 * up. A type that lies in the safe direction still costs correctness, because
 * the reader cannot tell a real guard from a ceremonial one.
 */
export interface Caller {
  readonly identity: TokenIdentity;
  /** `users.id`. Guaranteed present — the wrapper refuses the request otherwise. */
  readonly userId: string;
  /** `users.org_id`, which BR-20 scopes every Admin query by. */
  readonly orgId: string;
  /** Authoritative role from the `users` table, not the token claim. */
  readonly role: string;
}

/** The two roles Chapter 1.6 defines. */
export type CallerRole = 'admin' | 'collector';

/**
 * Refuses a caller whose role is not [required] — Chapter 4.8 §2 step 2.
 *
 * The role check is its own step in the chapter's middleware chain, ahead of
 * the scope check, and it is expressed here rather than as an `if` in each
 * handler so that "which roles may call this" is one legible line at the top of
 * every route.
 */
export function requireRole(caller: Caller, required: CallerRole): void {
  if (caller.role !== required) {
    throw ApiError.forbidden(`this endpoint requires the ${required} role`);
  }
}

/** What a domain handler returns. */
export interface HandlerResult<T> {
  readonly data: T;
  readonly meta?: EnvelopeMeta;
  readonly status?: number;
}

/** A domain handler: the part each function actually implements. */
export type DomainHandler<T> = (
  event: APIGatewayProxyEvent,
  caller: Caller,
) => Promise<HandlerResult<T>>;

/**
 * Builds the caller from the authorizer's context — ADR-048.
 *
 * ~~Stubbed.~~ **Replaced.** The lookup no longer happens here. A REQUEST
 * authorizer (`authorizer.ts`) runs in front of fourteen of the fifteen
 * routes, resolves the `users` row once, and API Gateway attaches the result
 * to `event.requestContext.authorizer`. Reading it here means a handler needs
 * neither a query nor a `users` grant — which is what lets Volume 8 Chapter
 * 8.4 §1's restriction survive Chapter 4.8 §2's requirement that every
 * endpoint have `user, role, org_id` attached.
 *
 * **The one route without an authorizer is `POST /v1/auth/verify`**, which is
 * exempt so a first-time caller has a door that is not locked against them.
 * It does its own verification and provisioning and does not use this.
 *
 * A missing context is a configuration error, not an unauthenticated caller:
 * API Gateway cannot invoke the function without one unless the authorizer was
 * detached from the route. It fails rather than falling back to an
 * unauthenticated path, because a silent fallback would turn a detached
 * authorizer into an open endpoint.
 */
function callerFromContext(event: APIGatewayProxyEvent): Caller {
  const context = event.requestContext.authorizer;
  const userId = typeof context?.userId === 'string' ? context.userId : undefined;
  const orgId = typeof context?.orgId === 'string' ? context.orgId : undefined;
  const role = typeof context?.role === 'string' ? context.role : undefined;
  const firebaseUid = typeof context?.firebaseUid === 'string' ? context.firebaseUid : undefined;

  if (
    userId === undefined ||
    orgId === undefined ||
    role === undefined ||
    firebaseUid === undefined
  ) {
    throw new Error(
      'No authorizer context on the request. Every route except POST /v1/auth/verify ' +
        'must sit behind the REQUEST authorizer (ADR-048).',
    );
  }

  return {
    identity: { firebaseUid, roleClaim: role, orgIdClaim: orgId, email: undefined },
    userId,
    orgId,
    role,
  };
}

/** Serialises an envelope into an API Gateway response. */
function respond(status: number, body: unknown): APIGatewayProxyResult {
  return {
    statusCode: status,
    headers: {
      'content-type': 'application/json',
      // Chapter 4.10 §3's transport rule, restated at the API edge.
      'strict-transport-security': 'max-age=31536000; includeSubDomains',
      'x-content-type-options': 'nosniff',
      'cache-control': 'no-store',
    },
    body: JSON.stringify(body),
  };
}

/**
 * Wraps a domain handler with authentication, the envelope and error mapping.
 *
 * [name] identifies the route in logs. It is not returned to the caller.
 */
export function withEnvelope<T>(name: string, handler: DomainHandler<T>) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const started = Date.now();
    try {
      const caller = callerFromContext(event);

      const result = await handler(event, caller);

      logger.info('request completed', {
        route: name,
        status: result.status ?? 200,
        durationMs: Date.now() - started,
        firebaseUid: caller.identity.firebaseUid,
      });

      return respond(result.status ?? 200, success(result.data, result.meta));
    } catch (thrown) {
      const { code, message, status } = toEnvelopeError(thrown);

      // The full cause is logged and never returned: an exception string can
      // carry a table name, a SQL fragment or a secret ARN.
      logger.error('request failed', {
        route: name,
        code,
        status,
        durationMs: Date.now() - started,
        cause: thrown instanceof Error ? thrown.message : String(thrown),
      });

      return respond(status, failure(code, message));
    }
  };
}

/**
 * Wraps a handler that must verify the bearer token **itself** — ADR-048.
 *
 * Exactly one route uses this: `POST /v1/auth/verify`, the route exempt from
 * the authorizer. It cannot read an authorizer context because there is none,
 * and it must work for a caller who has no `users` row yet — that is the whole
 * reason for the exemption.
 *
 * The handler receives the verified [TokenIdentity] rather than a [Caller],
 * because at this point the row may not exist. Turning the identity into a row
 * is `provisionCaller`'s job, and this route's purpose.
 */
export function withVerifiedToken<T>(
  name: string,
  handler: (event: APIGatewayProxyEvent, identity: TokenIdentity) => Promise<HandlerResult<T>>,
) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const started = Date.now();
    try {
      const header = event.headers.authorization ?? event.headers.Authorization;
      const identity = await verifyToken(bearerToken(header));

      const result = await handler(event, identity);

      logger.info('request completed', {
        route: name,
        status: result.status ?? 200,
        durationMs: Date.now() - started,
        firebaseUid: identity.firebaseUid,
      });

      return respond(result.status ?? 200, success(result.data, result.meta));
    } catch (thrown) {
      const { code, message, status } = toEnvelopeError(thrown);
      logger.error('request failed', {
        route: name,
        code,
        status,
        durationMs: Date.now() - started,
        cause: thrown instanceof Error ? thrown.message : String(thrown),
      });
      return respond(status, failure(code, message));
    }
  };
}

/**
 * Wraps a handler for a route with **no authentication at all** — ADR-048's
 * Mission 7.6 amendment.
 *
 * Exactly one route uses this: `POST /v1/auth/redeem`, the second exempt
 * route. It differs from {@link withVerifiedToken} in the thing that matters:
 * that wrapper's caller has a token and no `users` row, while this one's has
 * neither. There is no identity to verify because this route is what creates
 * it.
 *
 * **So the handler receives the event and nothing else.** There is deliberately
 * no optional-identity parameter: a handler that could sometimes see a caller
 * would invite a branch on whether one is present, and every such branch is a
 * chance to treat an unauthenticated request as authenticated. The type makes
 * that unrepresentable.
 *
 * **What limits exposure here is not authentication.** A-056 made the invite
 * code optional, so the code gates nothing; what bounds this route is that
 * self-signup can only ever produce a Collector in an organisation with no
 * Tasks assigned to it. That property lives in the handler, and this wrapper
 * neither provides nor checks it.
 *
 * No `firebaseUid` is logged on success, because at request time there is no
 * caller to name — the handler logs what it created instead.
 */
export function withoutAuthentication<T>(
  name: string,
  handler: (event: APIGatewayProxyEvent) => Promise<HandlerResult<T>>,
) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const started = Date.now();
    try {
      const result = await handler(event);

      logger.info('request completed', {
        route: name,
        status: result.status ?? 200,
        durationMs: Date.now() - started,
      });

      return respond(result.status ?? 200, success(result.data, result.meta));
    } catch (thrown) {
      const { code, message, status } = toEnvelopeError(thrown);
      logger.error('request failed', {
        route: name,
        code,
        status,
        durationMs: Date.now() - started,
        cause: thrown instanceof Error ? thrown.message : String(thrown),
      });
      return respond(status, failure(code, message));
    }
  };
}

/**
 * A handler for a route that is provisioned but not implemented.
 *
 * Mission 6.2 provisions fifteen routes and implements none of their queries.
 * Each one answers with a named `NOT_IMPLEMENTED` refusal in a real envelope
 * rather than a fabricated success — a stub that returns invented data is
 * indistinguishable from a working integration until something depends on it.
 */
export function notImplementedRoute(name: string, what: string) {
  return withEnvelope(name, (): Promise<HandlerResult<never>> => {
    throw ApiError.notImplemented(what);
  });
}
