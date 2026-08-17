/**
 * Cursor pagination — Volume 4, Chapter 4.6 §1.
 *
 * > *"Pagination: cursor-based (`?cursor=…&limit=…`) on every list endpoint."*
 *
 * ## Why this exists at scaffold time, before any query does
 *
 * ADR-044's Data API caps a response at **1 MiB**. A list endpoint without a
 * bound does not degrade gracefully past that — the call is terminated. So
 * pagination is a correctness requirement, and one that has to be in the
 * signature from the first version: adding a required parameter later is a
 * breaking change, and Chapter 4.6 §1 says a breaking change *"bumps to `/v2`
 * rather than mutating existing contracts"*.
 *
 * The client does not consume cursors yet — nothing in `mobile/lib` mentions
 * one — so this side defines the contract and the client inherits it.
 */
import { ApiError } from './errors.js';

/** Default page size when `?limit=` is absent. */
export const DEFAULT_LIMIT = 50;

/**
 * Hard ceiling on `?limit=`.
 *
 * Chosen against the 1 MiB Data API ceiling rather than for tidiness: a
 * generous row is on the order of a few kilobytes, so 200 leaves roughly an
 * order of magnitude of headroom. It is a bound, not a measurement — the
 * measurement belongs to Mission 6.3, when real rows exist.
 */
export const MAX_LIMIT = 200;

/** A validated page request. */
export interface PageRequest {
  readonly cursor: string | undefined;
  readonly limit: number;
}

/**
 * Validates `?cursor=` and `?limit=` from a query string.
 *
 * An out-of-range `limit` is rejected rather than clamped. Clamping would let a
 * caller ask for 10,000 rows, receive 200, and have no way to tell that the
 * page it got was not the page it asked for.
 */
export function parsePageRequest(query: Record<string, string | undefined> | null): PageRequest {
  const rawLimit = query?.limit;
  const rawCursor = query?.cursor;

  let limit = DEFAULT_LIMIT;
  if (rawLimit !== undefined && rawLimit !== '') {
    if (!/^\d+$/.test(rawLimit)) {
      throw ApiError.invalidRequest('limit must be a positive integer.');
    }
    limit = Number.parseInt(rawLimit, 10);
    if (limit < 1 || limit > MAX_LIMIT) {
      throw ApiError.invalidRequest(`limit must be between 1 and ${String(MAX_LIMIT)}.`);
    }
  }

  const cursor = rawCursor === undefined || rawCursor === '' ? undefined : rawCursor;
  return { cursor, limit };
}
