import { describe, it, expect } from 'vitest';
import { parsePageRequest, DEFAULT_LIMIT, MAX_LIMIT } from './pagination.js';

describe('cursor pagination', () => {
  it('pins the two published limits to their values', () => {
    // **Literals, not the constants themselves.** Until Mission 7.10 the test
    // below asserted `limit: DEFAULT_LIMIT`, importing the constant from the
    // module under test — so it asserted that the module agreed with itself
    // and any value survived. The sweep changed 50 to 25 and every test here
    // still passed.
    //
    // MAX_LIMIT was already pinned, by accident rather than design: a sibling
    // test asserts the error text /between 1 and 200/ and hard-codes the
    // number. That asymmetry is the whole lesson — an assertion that NAMES a
    // value holds it, one that BORROWS the value cannot.
    //
    // Both are client-visible. Chapter 4.6 §1 puts pagination in the response
    // envelope, and A-184 records what a silently changed page size costs: an
    // org with 51 Projects rendered 50, with nothing on either side reporting
    // a truncation.
    expect(DEFAULT_LIMIT).toBe(50);
    expect(MAX_LIMIT).toBe(200);
  });

  it('defaults the limit when no query string is present at all', () => {
    expect(parsePageRequest(null)).toEqual({ cursor: undefined, limit: 50 });
  });

  it('reads a cursor and a limit', () => {
    expect(parsePageRequest({ cursor: 'abc', limit: '10' })).toEqual({ cursor: 'abc', limit: 10 });
  });

  it('treats an empty cursor as absent rather than as a cursor', () => {
    expect(parsePageRequest({ cursor: '' }).cursor).toBeUndefined();
  });

  it('rejects a limit above the ceiling rather than clamping it', () => {
    // Clamping would let a caller ask for 10,000, receive 200, and have no way
    // to tell the page it got was not the page it asked for.
    expect(() => parsePageRequest({ limit: String(MAX_LIMIT + 1) })).toThrow(/between 1 and 200/);
  });

  it('rejects a zero or negative limit', () => {
    expect(() => parsePageRequest({ limit: '0' })).toThrow(/between 1 and 200/);
    expect(() => parsePageRequest({ limit: '-5' })).toThrow(/positive integer/);
  });

  it('rejects a non-numeric limit', () => {
    expect(() => parsePageRequest({ limit: 'all' })).toThrow(/positive integer/);
  });

  it('accepts exactly the ceiling', () => {
    expect(parsePageRequest({ limit: String(MAX_LIMIT) }).limit).toBe(MAX_LIMIT);
  });
});
