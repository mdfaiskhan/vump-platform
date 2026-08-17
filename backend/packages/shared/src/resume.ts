/**
 * Retry for an Aurora Serverless v2 cluster that has scaled to zero.
 *
 * ## The defect this closes
 *
 * Mission 6.1 set `min_capacity = 0`, so the dev cluster auto-pauses after 300
 * seconds idle. The **first** Data API call after a pause does not queue and
 * does not block — it fails:
 *
 * > `DatabaseResumingException: The Aurora DB instance … is resuming after
 * > being auto-paused. Please wait a few seconds and try again.`
 *
 * Mission 6.2 shipped a Data API client with no handling for it. Nothing broke,
 * only because none of the handlers issue a statement yet. **Mission 6.3 found
 * it by hitting it** — the very first probe of the live cluster failed this way
 * — and it is fixed here rather than in the migration runner alone, because the
 * handlers have the same exposure the moment 6.3 wires a query. A-156.
 *
 * ## Why it is not a generic retry
 *
 * Only `DatabaseResumingException` is retried. A resuming cluster is a wait
 * with a known, bounded end; a `BadRequestException` or a constraint violation
 * is a defect that retrying converts into the same defect, later, several
 * times. Retrying broadly is how a deterministic failure becomes an
 * intermittent one.
 *
 * Idempotency does not enter into it: the statement never reached the database,
 * which is what the exception means.
 */

/** Errors AWS raises while a paused cluster comes back. */
const RESUMING = new Set(['DatabaseResumingException', 'DatabaseNotFoundException']);

/** How long to wait before each attempt, in milliseconds. */
const BACKOFF_MS = [1_000, 2_000, 4_000, 8_000, 15_000] as const;

/**
 * True when [thrown] is AWS saying the cluster is waking up.
 *
 * `DatabaseNotFoundException` is included deliberately: a resuming cluster
 * briefly reports the database as absent, and treating that as a hard failure
 * turns a cold start into a 500.
 */
export function isResuming(thrown: unknown): boolean {
  if (typeof thrown !== 'object' || thrown === null) {
    return false;
  }
  const name = (thrown as { name?: unknown }).name;
  return typeof name === 'string' && RESUMING.has(name);
}

/** Injectable sleep, so tests do not wait through the real backoff. */
export interface RetryOptions {
  readonly sleep?: (ms: number) => Promise<void>;
  readonly onRetry?: (attempt: number, delayMs: number) => void;
}

const defaultSleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Runs [operation], retrying only while the cluster is resuming.
 *
 * Six attempts over roughly 30 seconds, which is inside a Lambda's 15-second
 * timeout only for the first few — so a caller may still time out on a cold
 * cluster. That is the honest behaviour: the alternative is a function that
 * hangs for the whole resume and returns nothing useful either way.
 */
export async function withResumeRetry<T>(
  operation: () => Promise<T>,
  options: RetryOptions = {},
): Promise<T> {
  const sleep = options.sleep ?? defaultSleep;

  for (let attempt = 0; ; attempt++) {
    try {
      return await operation();
    } catch (thrown) {
      const delay = BACKOFF_MS[attempt];
      if (!isResuming(thrown) || delay === undefined) {
        throw thrown;
      }
      options.onRetry?.(attempt + 1, delay);
      await sleep(delay);
    }
  }
}
