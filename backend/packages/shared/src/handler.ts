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

/** The caller, once both the token and the `users` row are known. */
export interface Caller {
  readonly identity: TokenIdentity;
  /** `users.id`. Unavailable until Mission 6.3 — see {@link resolveCaller}. */
  readonly userId: string | undefined;
  /** `users.org_id`, which BR-20 scopes every Admin query by. */
  readonly orgId: string | undefined;
  /** Authoritative role from the `users` table, not the token claim. */
  readonly role: string | undefined;
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
 * Looks up the caller's `users` row. **Stubbed.**
 *
 * Chapter 4.7 §1 step 4 requires *"looks up (or creates, on first login) the
 * matching `users` row via `firebase_uid` … and attaches role + org_id to the
 * request context"*. That is a database read and a conditional insert, and
 * Mission 6.3 owns both — the `users` table does not exist yet.
 *
 * It returns a `Caller` with the identity populated and the row fields
 * `undefined`, rather than inventing an id. A handler that needs `orgId` must
 * therefore fail rather than silently scope a query to a fabricated org, which
 * is the failure mode a plausible fake would create.
 *
 * **Amendment A-150** records the resolution of the contradiction this sits on:
 * Volume 8, Chapter 8.4 §1 says auth-verify has *"No database write access"*
 * while Chapter 4.7 §1 step 4 has it creating a row. Read as no UPDATE and no
 * DELETE; INSERT for first-login creation is permitted. Enforcement is a
 * PostgreSQL `GRANT SELECT, INSERT` in Mission 6.3, because ADR-044 records
 * that per-table permission is not expressible in IAM under the Data API.
 */
async function resolveCaller(identity: TokenIdentity): Promise<Caller> {
  return Promise.resolve({ identity, userId: undefined, orgId: undefined, role: undefined });
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
      const header = event.headers.authorization ?? event.headers.Authorization;
      const identity = await verifyToken(bearerToken(header));
      const caller = await resolveCaller(identity);

      const result = await handler(event, caller);

      logger.info('request completed', {
        route: name,
        status: result.status ?? 200,
        durationMs: Date.now() - started,
        firebaseUid: identity.firebaseUid,
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
