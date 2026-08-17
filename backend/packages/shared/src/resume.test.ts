import { describe, it, expect, vi } from 'vitest';
import { isResuming, withResumeRetry } from './resume.js';

/** Builds an error shaped like the AWS SDK's, which identifies by `name`. */
function awsError(name: string): Error {
  const e = new Error(`${name}: from the SDK`);
  e.name = name;
  return e;
}

const noSleep = { sleep: (): Promise<void> => Promise.resolve() };

describe('isResuming', () => {
  it('recognises a paused cluster waking up', () => {
    expect(isResuming(awsError('DatabaseResumingException'))).toBe(true);
  });

  it('recognises the database briefly reporting as absent during a resume', () => {
    expect(isResuming(awsError('DatabaseNotFoundException'))).toBe(true);
  });

  it('does not treat a bad request as a resume', () => {
    // The distinction that matters: retrying this would turn a deterministic
    // defect into an intermittent one.
    expect(isResuming(awsError('BadRequestException'))).toBe(false);
    expect(isResuming(awsError('ValidationException'))).toBe(false);
  });

  it('handles non-errors without throwing', () => {
    expect(isResuming(undefined)).toBe(false);
    expect(isResuming(null)).toBe(false);
    expect(isResuming('DatabaseResumingException')).toBe(false);
  });
});

describe('withResumeRetry', () => {
  it('returns the value when the first attempt succeeds', async () => {
    const op = vi.fn().mockResolvedValue('ok');
    await expect(withResumeRetry(op, noSleep)).resolves.toBe('ok');
    expect(op).toHaveBeenCalledOnce();
  });

  it('retries a resuming cluster and returns the eventual success', async () => {
    const op = vi
      .fn()
      .mockRejectedValueOnce(awsError('DatabaseResumingException'))
      .mockRejectedValueOnce(awsError('DatabaseResumingException'))
      .mockResolvedValue('awake');

    await expect(withResumeRetry(op, noSleep)).resolves.toBe('awake');
    expect(op).toHaveBeenCalledTimes(3);
  });

  it('does NOT retry anything else — one attempt, rethrown', async () => {
    const op = vi.fn().mockRejectedValue(awsError('BadRequestException'));

    await expect(withResumeRetry(op, noSleep)).rejects.toThrow('BadRequestException');
    expect(op).toHaveBeenCalledOnce();
  });

  it('gives up after the backoff schedule is exhausted, rethrowing the last error', async () => {
    const op = vi.fn().mockRejectedValue(awsError('DatabaseResumingException'));

    await expect(withResumeRetry(op, noSleep)).rejects.toThrow('DatabaseResumingException');
    // Five backoff steps means six attempts, then the error escapes rather
    // than the call hanging forever.
    expect(op).toHaveBeenCalledTimes(6);
  });

  it('waits with increasing backoff', async () => {
    const waited: number[] = [];
    const op = vi
      .fn()
      .mockRejectedValueOnce(awsError('DatabaseResumingException'))
      .mockRejectedValueOnce(awsError('DatabaseResumingException'))
      .mockResolvedValue('ok');

    await withResumeRetry(op, {
      sleep: (ms) => {
        waited.push(ms);
        return Promise.resolve();
      },
    });

    expect(waited).toEqual([1_000, 2_000]);
  });

  it('reports each retry so a cold start is visible in the log', async () => {
    const onRetry = vi.fn();
    const op = vi
      .fn()
      .mockRejectedValueOnce(awsError('DatabaseResumingException'))
      .mockResolvedValue('ok');

    await withResumeRetry(op, { ...noSleep, onRetry });

    expect(onRetry).toHaveBeenCalledWith(1, 1_000);
  });
});
