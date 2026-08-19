/**
 * Request-body validation — Volume 8, Chapter 8.3 §2.
 *
 * Every handler validates before it queries, and a rejection is
 * `REQUEST_INVALID` with a reason the caller can act on, per Chapter 4.6 §1's
 * rule that an error *"always carries a specific code, never a bare HTTP status
 * alone"*.
 *
 * ## By hand, not by a validator library
 *
 * The bodies in Chapter 4.6 §3 have two or three fields each. ADR-045 makes a
 * runtime dependency a decision rather than a convenience — every one is
 * bundled into all seven functions and audited on every CI run — and a schema
 * library earns that when the shapes are complex or shared with a generated
 * client. Neither is true yet: Chapter 4.6 §6 defers the OpenAPI artifact that
 * would justify one, and it does not exist.
 *
 * Revisit when the first genuinely nested body arrives. That is Chapter 4.5
 * §2's metadata document, in the next batch, which has six groups and twenty-one
 * fields — and it is a much better argument for a validator than anything here.
 *
 * ## Bounded lengths, on purpose
 *
 * Every string has a maximum. Chapter 4.4 types these columns as bare `text`
 * with no length limit, so without a bound at this layer a single request can
 * put a megabyte into a row that is then read back by every list query — and
 * ADR-044 terminates any Data API response over 1 MiB. An unbounded write is
 * therefore a way to make a *read* endpoint fail later, for everyone in the
 * org, which is a poor trade for accepting a longer project name.
 */
import { ApiError } from './errors.js';

/** A uuid in any version, lower- or upper-case. */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Parses a JSON body, refusing anything that is not a JSON object. */
export function parseBody(body: string | null | undefined): Record<string, unknown> {
  if (body === null || body === undefined || body === '') {
    throw ApiError.invalidRequest('A JSON body is required.');
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    throw ApiError.invalidRequest('The body is not valid JSON.');
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw ApiError.invalidRequest('The body must be a JSON object.');
  }
  return parsed as Record<string, unknown>;
}

/** A required, non-blank, length-bounded string. */
export function requiredString(
  body: Record<string, unknown>,
  field: string,
  maxLength: number,
): string {
  const value = body[field];
  if (typeof value !== 'string' || value.trim() === '') {
    throw ApiError.invalidRequest(`${field} is required and must be a non-empty string.`);
  }
  if (value.length > maxLength) {
    throw ApiError.invalidRequest(`${field} must be ${String(maxLength)} characters or fewer.`);
  }
  return value;
}

/**
 * An optional string: `undefined` when absent.
 *
 * **An explicit `null` is rejected rather than read as absent**, and the
 * distinction is load-bearing on `PATCH /v1/tasks/{taskId}`: `tasks.title` and
 * `tasks.instructions` are `NOT NULL`, so "leave unchanged" and "set to null"
 * cannot be the same request. Accepting `null` here would let a PATCH aimed at
 * clearing a field arrive as a no-op and report success.
 */
export function optionalString(
  body: Record<string, unknown>,
  field: string,
  maxLength: number,
): string | undefined {
  const value = body[field];
  if (value === undefined) {
    return undefined;
  }
  if (typeof value !== 'string') {
    throw ApiError.invalidRequest(`${field} must be a string when present.`);
  }
  if (value.trim() === '') {
    throw ApiError.invalidRequest(`${field} must not be blank when present.`);
  }
  if (value.length > maxLength) {
    throw ApiError.invalidRequest(`${field} must be ${String(maxLength)} characters or fewer.`);
  }
  return value;
}

/**
 * An optional array of strings — Chapter 4.4 §3's `reference_examples`.
 *
 * Bounded in both directions: at most 50 entries of at most 2000 characters.
 * Same reasoning as the string bounds above, one dimension further out.
 */
export function optionalStringArray(
  body: Record<string, unknown>,
  field: string,
): readonly string[] | undefined {
  const value = body[field];
  if (value === undefined) {
    return undefined;
  }
  if (!Array.isArray(value) || !value.every((v): v is string => typeof v === 'string')) {
    throw ApiError.invalidRequest(`${field} must be an array of strings when present.`);
  }
  if (value.length > 50) {
    throw ApiError.invalidRequest(`${field} must contain 50 entries or fewer.`);
  }
  if (value.some((v) => v.length > 2000)) {
    throw ApiError.invalidRequest(`each ${field} entry must be 2000 characters or fewer.`);
  }
  return value;
}

/**
 * An optional, client-supplied instant — F15.
 *
 * ## Why a client timestamp is accepted at all
 *
 * `sessions.started_at` defaults to `now()`, which records **registration**
 * time. Chapters 5.11 and 5.13 make the upload path deferred and
 * offline-tolerant, so a session captured in the field and registered hours
 * later would be stamped hours late — and FR-ADM-05's whole purpose is showing
 * an Admin when work happened.
 *
 * The system already trusts device clocks for capture timing:
 * `chunk_metadata.captured_start_at` and `captured_end_at` are device-supplied
 * and always have been. Refusing one here while accepting those would be
 * inconsistent rather than safe.
 *
 * ## Only the future is rejected, and there is no lower bound
 *
 * A timestamp after the server's own clock cannot describe something that has
 * already been captured, so it is either a broken clock or a dishonest one, and
 * either way the value is unusable.
 *
 * **There is deliberately no "too old" bound.** No requirement anywhere states
 * how long a chunk may sit on a device before upload — Chapter 5.13 grants six
 * automatic attempts with no wall-clock deadline, and NFR-AVL-02's *"< 30
 * seconds"* is about resuming after connectivity returns, not about total age.
 * Any cutoff would be invented, and an invented one would silently reject real
 * field recordings from a crew that was offline for a week. `NetworkConstants`
 * declined to guess an upload timeout on exactly this reasoning: *"a guessed
 * value would be worse than none"* because it fails invisibly.
 *
 * A small skew allowance absorbs ordinary clock drift rather than treating it
 * as dishonesty; a device seconds ahead of the server is not making a claim
 * about the future.
 */
export function optionalPastInstant(
  body: Record<string, unknown>,
  field: string,
  now: () => number = Date.now,
): string | undefined {
  const value = body[field];
  if (value === undefined) {
    return undefined;
  }
  if (typeof value !== 'string') {
    throw ApiError.invalidRequest(`${field} must be an ISO-8601 string when present.`);
  }
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) {
    throw ApiError.invalidRequest(`${field} must be a valid ISO-8601 instant.`);
  }
  // Sixty seconds of tolerance: ordinary drift, not a claim about the future.
  if (parsed > now() + 60_000) {
    throw ApiError.invalidRequest(`${field} must not be in the future.`);
  }
  return value;
}

/**
 * A path parameter that must be a uuid.
 *
 * Checked before any query, so a malformed id is `REQUEST_MALFORMED_ID` rather
 * than a Postgres cast error surfacing as `INTERNAL_ERROR` — Chapter 4.6 §1's
 * named-cause rule applied to the commonest client mistake there is.
 */
export function pathUuid(
  parameters: Record<string, string | undefined> | null,
  name: string,
): string {
  const value = parameters?.[name];
  if (value === undefined || !UUID.test(value)) {
    throw new ApiError('REQUEST_MALFORMED_ID', `${name} must be a uuid.`, 400);
  }
  return value.toLowerCase();
}
