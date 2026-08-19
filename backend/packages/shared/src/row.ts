/**
 * Reading Data API rows and building its parameters.
 *
 * ## Why this is a module and not inline in each handler
 *
 * The Data API returns a row as an array of tagged unions —
 * `[{stringValue: '…'}, {isNull: true}, {longValue: 3}]` — positional, untyped,
 * and with `isNull` as a *separate* member rather than an absent value. Read
 * inline, every handler ends up repeating the same three mistakes: trusting
 * position without checking arity, treating `{isNull: true}` as a present
 * value, and letting `undefined` from a mis-indexed column become a silent
 * empty string in a response body.
 *
 * `caller.ts` already had to hand-roll this once and left a comment about it:
 * *"A NOT NULL column came back null, which means the query and the schema
 * disagree. Failing loudly beats returning a half-built caller."* That is the
 * rule this module generalises.
 *
 * ## The parameter half
 *
 * `uuidParam` exists because a uuid bound as a bare string is compared as
 * `text` and Postgres refuses `uuid = text` without a cast. Doing it here means
 * the cast lives next to the value rather than being remembered in forty
 * separate SQL strings — and a forgotten one is a runtime `operator does not
 * exist` on a query that reads correctly.
 */
import type { Field, SqlParameter } from '@aws-sdk/client-rds-data';

/** A row, as the Data API returns it. */
export type Row = readonly Field[];

/** Reads a NOT NULL text/uuid/timestamptz column. */
export function readString(row: Row, index: number, column: string): string {
  const value = row[index]?.stringValue;
  if (value === undefined) {
    // The query and the schema disagree. Loud beats plausible.
    throw new Error(
      `Column ${column} (index ${String(index)}) was absent or null, but is NOT NULL.`,
    );
  }
  return value;
}

/** Reads a nullable text column, mapping SQL NULL to `null`. */
export function readOptionalString(row: Row, index: number): string | null {
  const field = row[index];
  if (field === undefined || field.isNull === true) {
    return null;
  }
  return field.stringValue ?? null;
}

/**
 * Reads a nullable `jsonb` column as a string array.
 *
 * Chapter 4.4 §3 types `reference_examples` as `jsonb` and describes it in five
 * words — *"Array of reference media URLs."* — so a list of strings and no
 * further structure is invented. A SQL NULL and an empty array carry the same
 * fact and are collapsed to `[]`, matching the mobile `Task` entity, which
 * collapses them for the same reason: *"no chapter distinguishes them."*
 *
 * A stored value that is not an array of strings is dropped rather than
 * rendered, because it cannot have come from this API.
 */
export function readStringArray(row: Row, index: number): readonly string[] {
  const raw = readOptionalString(row, index);
  if (raw === null) {
    return [];
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return [];
  }
  return Array.isArray(parsed) ? parsed.filter((v): v is string => typeof v === 'string') : [];
}

/** A text parameter. */
export function textParam(name: string, value: string): SqlParameter {
  return { name, value: { stringValue: value } };
}

/** A nullable text parameter, sending SQL NULL rather than an empty string. */
export function optionalTextParam(name: string, value: string | null | undefined): SqlParameter {
  return value === null || value === undefined
    ? { name, value: { isNull: true } }
    : { name, value: { stringValue: value } };
}

/**
 * A uuid parameter.
 *
 * `typeHint: 'UUID'` is what makes `WHERE id = :id` work without writing
 * `:id::uuid` in the SQL. Both are correct; this one cannot be forgotten in a
 * single query and left as a runtime error.
 */
export function uuidParam(name: string, value: string): SqlParameter {
  return { name, value: { stringValue: value }, typeHint: 'UUID' };
}

/** A `jsonb` parameter, or SQL NULL for an absent list. */
export function jsonParam(name: string, value: readonly string[] | undefined): SqlParameter {
  return value === undefined
    ? { name, value: { isNull: true } }
    : { name, value: { stringValue: JSON.stringify(value) }, typeHint: 'JSON' };
}

/** An integer parameter. */
export function longParam(name: string, value: number): SqlParameter {
  return { name, value: { longValue: value } };
}
