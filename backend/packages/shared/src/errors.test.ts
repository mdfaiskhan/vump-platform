import { describe, it, expect } from 'vitest';
import { ApiError, ERROR_CODES, toEnvelopeError } from './errors.js';

describe('the error taxonomy', () => {
  it('keeps CHUNK_ALREADY_REGISTERED, which the mobile client knows by name', () => {
    // A Mission 4.2 test scripts this exact code against VumpApi. Renaming it
    // breaks a shipped client, so it is asserted here rather than assumed.
    expect(ERROR_CODES).toContain('CHUNK_ALREADY_REGISTERED');
  });

  it('has no duplicate codes', () => {
    expect(new Set(ERROR_CODES).size).toBe(ERROR_CODES.length);
  });

  it('maps an ApiError to its own code, message and status', () => {
    expect(toEnvelopeError(ApiError.forbidden('reading another org'))).toEqual({
      code: 'AUTH_FORBIDDEN',
      message: 'Not permitted: reading another org.',
      status: 403,
    });
  });

  it('gives an unrecognised throw a fixed message, leaking nothing', () => {
    const leaky = new Error(
      'relation "users" does not exist; secret arn:aws:secretsmanager:...:secret:vump/dev/x',
    );

    const mapped = toEnvelopeError(leaky);

    expect(mapped.code).toBe('INTERNAL_ERROR');
    expect(mapped.status).toBe(500);
    // The point of the test: nothing from the original message survives.
    expect(mapped.message).toBe('The request could not be completed.');
    expect(mapped.message).not.toContain('users');
    expect(mapped.message).not.toContain('secretsmanager');
  });

  it('maps a non-Error throw without crashing', () => {
    expect(toEnvelopeError('a bare string').code).toBe('INTERNAL_ERROR');
  });

  it('marks unbuilt work as 501, not as a plausible success', () => {
    const error = ApiError.notImplemented('Listing projects');
    expect(error.code).toBe('NOT_IMPLEMENTED');
    expect(error.status).toBe(501);
  });
});
