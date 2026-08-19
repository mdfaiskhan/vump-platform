/**
 * Keyset cursors — the producing half of Volume 4, Chapter 4.6 §1's pagination.
 *
 * ## Why this exists, and why it is not an offset
 *
 * `pagination.ts` has validated `?cursor=` and `?limit=` since Mission 6.2, and
 * `EnvelopeMeta.nextCursor` has been in the envelope just as long — but nothing
 * ever produced a cursor, and `REQUEST_INVALID_CURSOR` was a code with no
 * caller. This closes that half.
 *
 * **Keyset, not `OFFSET`.** An offset re-reads and discards every row it skips,
 * so page 100 costs a hundred pages of work, and a row inserted between two
 * requests shifts every subsequent page by one — the reader sees a duplicate or
 * misses a row entirely. A keyset cursor carries the sort key of the last row
 * and asks for "everything strictly after this", which is O(index seek) and
 * stable under concurrent inserts.
 *
 * That matters more here than usual: ADR-044 terminates any Data API call whose
 * response exceeds **1 MiB**, so pagination is a correctness requirement rather
 * than a nicety, and the pages have to be cheap enough to be worth taking.
 *
 * ## The sort key
 *
 * `(created_at DESC, id DESC)`. No chapter specifies an order — the mobile
 * `ProjectTaskRepository` says outright *"Returns them in the order the backend
 * supplied. No chapter specifies a sort, so none is imposed"* — but a cursor
 * needs a **total** order or pages can overlap. `created_at` alone is not one:
 * two projects created in the same transaction share a timestamp. `id` breaks
 * the tie and is unique by construction, so the pair is total.
 *
 * ## Opaque on purpose
 *
 * Base64 of a JSON pair, and callers are told nothing about the contents. It is
 * not encrypted and is not pretending to be — the values inside are a timestamp
 * and a uuid the caller was just given in the response body. Opacity buys the
 * freedom to change the sort key later without it being a breaking change,
 * which is worth having under Chapter 4.6 §1's rule that a breaking change
 * *"bumps to `/v2` rather than mutating existing contracts"*.
 */
import { ApiError } from './errors.js';

/** The position of the last row on a page. */
export interface Cursor {
  /** `created_at` of the last row, as the ISO string the Data API returned. */
  readonly createdAt: string;
  /** `id` of the last row, breaking ties within one timestamp. */
  readonly id: string;
}

/** A uuid in any version, lower- or upper-case. */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Encodes a position as the opaque string a client sends back. */
export function encodeCursor(cursor: Cursor): string {
  return Buffer.from(JSON.stringify([cursor.createdAt, cursor.id]), 'utf8').toString('base64url');
}

/**
 * Decodes a cursor this API issued.
 *
 * Every failure is the same refusal. A caller who sends a malformed cursor gets
 * `REQUEST_INVALID_CURSOR` whether the base64 was truncated, the JSON was not a
 * pair, or the id was not a uuid — the distinction is useful in a log and
 * useless to the caller, and reporting it would describe the internals of a
 * value documented as opaque.
 *
 * @throws {ApiError} 400 `REQUEST_INVALID_CURSOR`.
 */
export function decodeCursor(raw: string): Cursor {
  let parsed: unknown;
  try {
    parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
  } catch {
    throw invalidCursor();
  }

  if (!Array.isArray(parsed) || parsed.length !== 2) {
    throw invalidCursor();
  }
  const [createdAt, id] = parsed as unknown[];
  if (typeof createdAt !== 'string' || typeof id !== 'string' || !UUID.test(id)) {
    throw invalidCursor();
  }
  // A timestamp is not validated beyond being a string: it is bound as a
  // parameter and Postgres rejects an unparseable one, so re-implementing that
  // check here would be a second, weaker copy of it.
  return { createdAt, id };
}

function invalidCursor(): ApiError {
  return new ApiError('REQUEST_INVALID_CURSOR', 'This cursor was not issued by this API.', 400);
}

/**
 * Builds the `meta` for a page, given one more row than was asked for.
 *
 * The caller fetches `limit + 1` rows. If the extra one came back there is
 * another page, and the cursor points at the **last row of this page** rather
 * than the extra — the extra is discarded and never rendered.
 *
 * Asking for one more row is how a page knows whether it is the last one
 * without a second `COUNT(*)` query. The alternative — returning a cursor
 * whenever the page is full — produces one empty final page every time the
 * total is an exact multiple of the limit.
 */
export function pageMeta<T extends Cursor>(
  rows: readonly T[],
  limit: number,
): { readonly page: readonly T[]; readonly meta: { readonly nextCursor: string | null } } {
  if (rows.length <= limit) {
    return { page: rows, meta: { nextCursor: null } };
  }
  const page = rows.slice(0, limit);
  const last = page[page.length - 1];
  return {
    page,
    meta: { nextCursor: last === undefined ? null : encodeCursor(last) },
  };
}
