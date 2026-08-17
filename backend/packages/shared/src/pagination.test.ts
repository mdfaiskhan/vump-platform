import { describe, it, expect } from 'vitest';
import { parsePageRequest, DEFAULT_LIMIT, MAX_LIMIT } from './pagination.js';

describe('cursor pagination', () => {
  it('defaults the limit when no query string is present at all', () => {
    expect(parsePageRequest(null)).toEqual({ cursor: undefined, limit: DEFAULT_LIMIT });
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
