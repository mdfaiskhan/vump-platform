/**
 * Volume 4, Chapter 4.6 §1's response envelope.
 *
 * > *"Standard envelope: `{ "data": …, "error": null }` on success,
 * > `{ "data": null, "error": { "code", "message" } }` on failure."*
 *
 * The mobile client implements the reading half of this already, in
 * `VumpApi`, and treats *"a 2xx carrying a populated `error`"* as a failure.
 * The two halves have to agree exactly.
 */
import type { ErrorCode } from './errors.js';

/** The `error` object of a failed envelope. */
export interface EnvelopeError {
  readonly code: ErrorCode;
  readonly message: string;
}

/**
 * Pagination state, as a **sibling of `data`** rather than a member of it.
 *
 * Chapter 4.6 §1 fixes cursor pagination — *"cursor-based
 * (`?cursor=…&limit=…`) on every list endpoint"* — but does not say where the
 * next cursor is returned. It is placed here rather than inside `data` so that
 * `data` stays exactly the resource the caller asked for: the client's
 * `VumpApi` returns `data` and nothing else to its callers, so a cursor buried
 * inside it would become a field every DTO has to know to ignore.
 *
 * `nextCursor` is `null` on the last page. Absent entirely on non-list
 * endpoints.
 */
export interface EnvelopeMeta {
  readonly nextCursor: string | null;
}

/** A successful response. */
export interface SuccessEnvelope<T> {
  readonly data: T;
  readonly error: null;
  readonly meta?: EnvelopeMeta;
}

/** A failed response. */
export interface ErrorEnvelope {
  readonly data: null;
  readonly error: EnvelopeError;
}

/** Either shape. */
export type Envelope<T> = SuccessEnvelope<T> | ErrorEnvelope;

/** Wraps [data] as a success envelope, with optional pagination [meta]. */
export function success<T>(data: T, meta?: EnvelopeMeta): SuccessEnvelope<T> {
  return meta === undefined ? { data, error: null } : { data, error: null, meta };
}

/** Wraps a code and message as a failure envelope. */
export function failure(code: ErrorCode, message: string): ErrorEnvelope {
  return { data: null, error: { code, message } };
}
