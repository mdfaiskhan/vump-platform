import { describe, it, expect } from 'vitest';
import { success, failure } from './envelope.js';

describe('the Chapter 4.6 §1 envelope', () => {
  it('puts data alongside a null error on success', () => {
    expect(success({ id: 'x' })).toEqual({ data: { id: 'x' }, error: null });
  });

  it('omits meta entirely when there is no pagination', () => {
    // Not `meta: undefined` — JSON.stringify drops that key anyway, but the
    // distinction matters for the type: a non-list endpoint has no meta.
    expect(Object.hasOwn(success({ id: 'x' }), 'meta')).toBe(false);
  });

  it('carries the next cursor as a SIBLING of data, not inside it', () => {
    const envelope = success([{ id: 'a' }], { nextCursor: 'abc' });

    expect(envelope.meta).toEqual({ nextCursor: 'abc' });
    // The decision this asserts: the client's VumpApi returns `data` and
    // nothing else to its callers, so a cursor inside `data` would be a field
    // every DTO has to know to ignore.
    expect(envelope.data).toEqual([{ id: 'a' }]);
  });

  it('signals the last page with a null cursor rather than an absent one', () => {
    expect(success([], { nextCursor: null }).meta).toEqual({ nextCursor: null });
  });

  it('nulls data on failure and carries a code and message', () => {
    expect(failure('AUTH_TOKEN_INVALID', 'nope')).toEqual({
      data: null,
      error: { code: 'AUTH_TOKEN_INVALID', message: 'nope' },
    });
  });
});
