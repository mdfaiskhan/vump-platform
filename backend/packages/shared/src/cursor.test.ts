import { describe, it, expect } from 'vitest';

import { encodeCursor, decodeCursor, pageMeta } from './cursor.js';
import { ApiError } from './errors.js';

const AT = '2026-08-19T10:00:00Z';
const ID = '11111111-1111-4111-8111-111111111111';

describe('cursor encoding', () => {
  it('round-trips a position', () => {
    expect(decodeCursor(encodeCursor({ createdAt: AT, id: ID }))).toEqual({
      createdAt: AT,
      id: ID,
    });
  });

  it('is base64url, so it survives a query string without escaping', () => {
    // `+` and `/` from standard base64 would need percent-encoding, and a
    // client that forgot would send a cursor this API cannot decode.
    expect(encodeCursor({ createdAt: AT, id: ID })).toMatch(/^[A-Za-z0-9_-]+$/);
  });
});

describe('cursor rejection', () => {
  const cases: Record<string, string> = {
    'not base64': '!!!!',
    'valid base64, not JSON': Buffer.from('nonsense', 'utf8').toString('base64url'),
    'JSON but not a pair': Buffer.from('["only-one"]', 'utf8').toString('base64url'),
    'pair whose id is not a uuid': Buffer.from(`["${AT}","nope"]`, 'utf8').toString('base64url'),
    'JSON object rather than a pair': Buffer.from('{"createdAt":"x"}', 'utf8').toString(
      'base64url',
    ),
  };

  for (const [name, raw] of Object.entries(cases)) {
    it(`refuses ${name} with REQUEST_INVALID_CURSOR`, () => {
      // Every malformed cursor is the same refusal: the distinction is useful
      // in a log and useless to a caller holding an opaque value.
      expect(() => decodeCursor(raw)).toThrow(
        expect.objectContaining({ code: 'REQUEST_INVALID_CURSOR', status: 400 }) as ApiError,
      );
    });
  }
});

describe('pageMeta', () => {
  const row = (n: number) => ({
    createdAt: AT,
    id: `1111111${String(n)}-1111-4111-8111-111111111111`,
  });

  it('reports no next page when the extra row did not come back', () => {
    const { page, meta } = pageMeta([row(1), row(2)], 3);
    expect(page).toHaveLength(2);
    expect(meta.nextCursor).toBeNull();
  });

  it('does not emit a cursor when the page is exactly full', () => {
    // The trap this guards: returning a cursor whenever the page is full
    // produces one empty final page every time the total is a multiple of the
    // limit, and the client cannot tell that from a real page boundary.
    const { page, meta } = pageMeta([row(1), row(2)], 2);
    expect(page).toHaveLength(2);
    expect(meta.nextCursor).toBeNull();
  });

  it('drops the extra row and points the cursor at the last KEPT row', () => {
    const { page, meta } = pageMeta([row(1), row(2), row(3)], 2);

    expect(page).toHaveLength(2);
    expect(page.map((r) => r.id)).toEqual([row(1).id, row(2).id]);
    // Not row(3): the extra row was a probe and is never rendered, so a cursor
    // pointing at it would skip it on the next page.
    expect(meta.nextCursor).toBe(encodeCursor(row(2)));
  });
});
