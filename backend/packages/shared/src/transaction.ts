/**
 * One Data API transaction, around a handler's writes.
 *
 * ## What forces this
 *
 * Volume 4 Chapter 4.2 §2 makes `audit_log` an *"append-only record of Admin
 * actions on Projects/Tasks/Assignments"*, and five of Chapter 4.6 §3's seven
 * routes therefore write two rows: the resource, and the record that it
 * happened. The Data API rejects multi-statement SQL (ADR-044), so those are
 * two calls, and two calls without a transaction can half-succeed.
 *
 * Both directions of that are wrong and neither is theoretical:
 *
 *   - resource committed, audit row lost — an Admin action with no trail, which
 *     is the one thing the table exists to prevent;
 *   - audit row committed, resource lost — a trail of an action that never
 *     happened, which is worse, because it is evidence of the wrong thing.
 *
 * The migration runner (ADR-046) already reached this conclusion for its own
 * statements and grew its own `BeginTransaction`/`Commit` pair. This is the
 * same shape for handlers, in the shared package, so it is written once.
 *
 * ## Why the transaction id is threaded rather than ambient
 *
 * `execute()` takes an optional `transactionId`. A statement that forgets it
 * silently runs **outside** the transaction and commits on its own — there is
 * no error, and the failure surfaces only as a stray row after a rollback. So
 * the callback receives a bound `execute` and using the wrong one has to be
 * deliberate rather than accidental.
 *
 * Session state does not otherwise survive between Data API calls, which is why
 * per-function identity comes from a per-function credential rather than
 * `SET ROLE` — but state *does* persist inside an explicit transaction, and
 * that is exactly the property being used here.
 */
import {
  BeginTransactionCommand,
  CommitTransactionCommand,
  RollbackTransactionCommand,
  type ExecuteStatementCommandOutput,
} from '@aws-sdk/client-rds-data';
import { dataApiClient, execute, statementTarget, type ExecuteOptions } from './data-api.js';
import { logger } from './logger.js';
import { withResumeRetry } from './resume.js';

/** `execute`, already bound to the open transaction. */
export type TransactionalExecute = (
  sql: string,
  options?: Omit<ExecuteOptions, 'transactionId' | 'target'>,
) => Promise<ExecuteStatementCommandOutput>;

/**
 * Runs [work] inside one transaction, committing on success.
 *
 * Rolls back on any throw and rethrows the original error — a rollback that
 * itself fails is swallowed, because the caller needs to know what actually
 * went wrong rather than what went wrong while cleaning up. The migration
 * runner makes the same choice for the same reason.
 *
 * `BeginTransaction` goes through the resume retry, because it is frequently
 * the first call of a request and therefore the one that meets a paused
 * cluster (A-156, gap 9).
 */
export async function withTransaction<T>(
  work: (run: TransactionalExecute) => Promise<T>,
): Promise<T> {
  const target = statementTarget();
  const client = dataApiClient();

  const begun = await withResumeRetry(() =>
    client.send(
      new BeginTransactionCommand({
        resourceArn: target.resourceArn,
        secretArn: target.secretArn,
        database: target.database,
      }),
    ),
  );

  const transactionId = begun.transactionId;
  if (transactionId === undefined) {
    throw new Error('BeginTransaction returned no transactionId.');
  }

  const run: TransactionalExecute = (sql, options = {}) =>
    execute(sql, { ...options, target, transactionId });

  try {
    const result = await work(run);
    await client.send(
      new CommitTransactionCommand({
        resourceArn: target.resourceArn,
        secretArn: target.secretArn,
        transactionId,
      }),
    );
    return result;
  } catch (thrown) {
    await client
      .send(
        new RollbackTransactionCommand({
          resourceArn: target.resourceArn,
          secretArn: target.secretArn,
          transactionId,
        }),
      )
      .catch((failed: unknown) => {
        // Logged rather than dropped silently: an abandoned transaction holds
        // locks until Aurora times it out, and that is worth seeing.
        logger.error('rollback failed', {
          cause: failed instanceof Error ? failed.message : String(failed),
        });
      });
    throw thrown;
  }
}
