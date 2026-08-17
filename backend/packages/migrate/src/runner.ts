/**
 * The migration runner — ADR-046.
 *
 * ## Why a runner and not a tool
 *
 * `node-pg-migrate` speaks the PostgreSQL wire protocol over TCP; Flyway speaks
 * JDBC. Neither can reach this cluster: ADR-044 puts it behind the Data API,
 * and Mission 6.1's network has no internet gateway, no NAT, and an Aurora
 * security group with **zero ingress rules**. Adopting either would mean
 * opening a network path the architecture deliberately does not have.
 *
 * So migrations run through the same Data API everything else uses. That is a
 * constraint, and it comes with three consequences this file exists to handle.
 *
 * ## One: one statement per call
 *
 * The Data API rejects multi-statement SQL. Files are split by
 * {@link ./split.ts}, which understands dollar-quoted function bodies — without
 * that, `0006_integrity_rules.sql` shatters into fragments.
 *
 * ## Two: each migration is one transaction
 *
 * `BeginTransaction`, every statement, then `Commit` — or `Rollback` on the
 * first failure. PostgreSQL has transactional DDL, and the Data API honours it:
 * verified against the live cluster by creating a table, a role and a grant
 * inside one transaction and rolling back, then confirming none survived.
 *
 * A half-applied migration is therefore impossible. The tracking row is written
 * inside the same transaction as the statements it describes, so the ledger
 * cannot disagree with the schema.
 *
 * ## Three: the cluster may be asleep
 *
 * `min_capacity = 0` means the first call after an idle period fails with
 * `DatabaseResumingException`. Handled by `@vump/shared`'s retry, which is
 * shared with the handlers rather than special-cased here (A-156).
 */
import { readdir, readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
import {
  BeginTransactionCommand,
  CommitTransactionCommand,
  RollbackTransactionCommand,
} from '@aws-sdk/client-rds-data';
import { dataApiClient, execute, withResumeRetry, type StatementTarget } from '@vump/shared';
import { splitStatements } from './split.js';

/** A migration file on disk. */
export interface Migration {
  /** Zero-padded ordinal, e.g. `0007`. */
  readonly id: string;
  readonly name: string;
  readonly sql: string;
  /** SHA-256 of the file, so an edited migration is detectable. */
  readonly checksum: string;
}

/** What a run did. */
export interface RunResult {
  readonly applied: Migration[];
  readonly skipped: Migration[];
}

const TRACKING_TABLE = 'schema_migrations';

const FILENAME = /^(\d{4})_([a-z0-9_]+)\.sql$/;

/** Reads and orders the migration files. */
export async function loadMigrations(dir: string): Promise<Migration[]> {
  const entries = (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort();

  const migrations: Migration[] = [];
  for (const file of entries) {
    const match = FILENAME.exec(file);
    if (match === null) {
      throw new Error(
        `Migration filename "${file}" must match NNNN_lower_snake_case.sql — ordering is the ` +
          'only thing that decides what runs first, so a name that does not sort is a defect.',
      );
    }
    const sql = await readFile(join(dir, file), 'utf8');
    migrations.push({
      id: match[1] ?? '',
      name: match[2] ?? '',
      sql,
      checksum: createHash('sha256').update(sql).digest('hex'),
    });
  }

  const ids = migrations.map((m) => m.id);
  if (new Set(ids).size !== ids.length) {
    throw new Error(`Duplicate migration ordinals in ${dir}: ${ids.join(', ')}`);
  }
  return migrations;
}

/**
 * Creates the tracking table if it is missing.
 *
 * Outside a transaction and idempotent, because it has to work on a database
 * where nothing exists yet — including on the very first run, where the
 * alternative is a chicken-and-egg problem with its own migration.
 */
export async function ensureTrackingTable(target: StatementTarget): Promise<void> {
  await execute(
    `CREATE TABLE IF NOT EXISTS ${TRACKING_TABLE} (
       id          text        PRIMARY KEY,
       name        text        NOT NULL,
       checksum    text        NOT NULL,
       applied_at  timestamptz NOT NULL DEFAULT now(),
       statements  integer     NOT NULL
     )`,
    { target },
  );
}

/** Reads the ledger of what has already run. */
export async function appliedMigrations(
  target: StatementTarget,
): Promise<Map<string, { checksum: string; name: string }>> {
  const out = await execute(`SELECT id, name, checksum FROM ${TRACKING_TABLE} ORDER BY id`, {
    target,
  });

  const applied = new Map<string, { checksum: string; name: string }>();
  for (const record of out.records ?? []) {
    const id = record[0]?.stringValue;
    const name = record[1]?.stringValue;
    const checksum = record[2]?.stringValue;
    if (id !== undefined && name !== undefined && checksum !== undefined) {
      applied.set(id, { checksum, name });
    }
  }
  return applied;
}

/** Reports progress without this module deciding how it is printed. */
export interface RunnerEvents {
  readonly onSkip?: (m: Migration) => void;
  readonly onStart?: (m: Migration, statements: number) => void;
  readonly onDone?: (m: Migration) => void;
}

/**
 * Applies every migration not yet in the ledger, in ordinal order.
 *
 * **A previously applied migration whose file has changed is a hard error.**
 * Editing an applied migration means the database and the repository describe
 * different schemas, and no amount of re-running fixes that — the correct
 * response is a new migration, so the runner refuses rather than papering over
 * it.
 */
export async function runMigrations(
  dir: string,
  target: StatementTarget,
  events: RunnerEvents = {},
): Promise<RunResult> {
  const migrations = await loadMigrations(dir);
  await ensureTrackingTable(target);
  const already = await appliedMigrations(target);

  const applied: Migration[] = [];
  const skipped: Migration[] = [];

  for (const migration of migrations) {
    const previous = already.get(migration.id);

    if (previous !== undefined) {
      if (previous.checksum !== migration.checksum) {
        throw new Error(
          `Migration ${migration.id}_${migration.name} has changed since it was applied.\n` +
            `  applied checksum: ${previous.checksum}\n` +
            `  file checksum   : ${migration.checksum}\n` +
            'An applied migration is history. Add a new migration instead of editing this one.',
        );
      }
      skipped.push(migration);
      events.onSkip?.(migration);
      continue;
    }

    const statements = splitStatements(migration.sql);
    events.onStart?.(migration, statements.length);

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

    try {
      for (const statement of statements) {
        await execute(statement.sql, { target, transactionId });
      }

      await execute(
        `INSERT INTO ${TRACKING_TABLE} (id, name, checksum, statements)
         VALUES (:id, :name, :checksum, :statements)`,
        {
          target,
          transactionId,
          parameters: [
            { name: 'id', value: { stringValue: migration.id } },
            { name: 'name', value: { stringValue: migration.name } },
            { name: 'checksum', value: { stringValue: migration.checksum } },
            { name: 'statements', value: { longValue: statements.length } },
          ],
        },
      );

      await client.send(
        new CommitTransactionCommand({
          resourceArn: target.resourceArn,
          secretArn: target.secretArn,
          transactionId,
        }),
      );
      applied.push(migration);
      events.onDone?.(migration);
    } catch (thrown) {
      await client
        .send(
          new RollbackTransactionCommand({
            resourceArn: target.resourceArn,
            secretArn: target.secretArn,
            transactionId,
          }),
        )
        // A rollback that itself fails must not replace the real error.
        .catch(() => undefined);

      throw new Error(
        `Migration ${migration.id}_${migration.name} failed and was rolled back: ` +
          (thrown instanceof Error ? thrown.message : String(thrown)),
        { cause: thrown },
      );
    }
  }

  return { applied, skipped };
}
