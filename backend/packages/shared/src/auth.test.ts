import { describe, it, expect } from 'vitest';
import { bearerToken } from './auth.js';

describe('bearer token extraction', () => {
  it('reads the token after the scheme', () => {
    expect(bearerToken('Bearer abc.def.ghi')).toBe('abc.def.ghi');
  });

  it('accepts a lowercase scheme', () => {
    // API Gateway does not normalise header values, and RFC 7235 makes the
    // scheme case-insensitive.
    expect(bearerToken('bearer abc')).toBe('abc');
  });

  it('tolerates surrounding and extra internal whitespace', () => {
    expect(bearerToken('  Bearer   abc  ')).toBe('abc');
  });

  it('rejects a missing header with AUTH_TOKEN_MISSING', () => {
    expect(() => bearerToken(undefined)).toThrow(/No bearer token/);
  });

  it('rejects an empty header', () => {
    expect(() => bearerToken('')).toThrow(/No bearer token/);
  });

  it('rejects a header with no scheme', () => {
    expect(() => bearerToken('abc.def.ghi')).toThrow(/No bearer token/);
  });

  it('rejects a scheme with no token', () => {
    expect(() => bearerToken('Bearer')).toThrow(/No bearer token/);
    expect(() => bearerToken('Bearer   ')).toThrow(/No bearer token/);
  });

  it('rejects a non-bearer scheme', () => {
    expect(() => bearerToken('Basic dXNlcjpwYXNz')).toThrow(/No bearer token/);
  });
});
