/**
 * The Aurora Data API client — ADR-044.
 *
 * ## What this is, and what Mission 6.2 deliberately did not build
 *
 * The client is constructed here. Mission 6.3 owns the schema, so the
 * statements themselves still belong to the handlers that will issue them —
 * `execute` runs a statement, and no handler calls it yet.
 *
 * ## Two constraints from ADR-044 that shape every query
 *
 * **The 1 MiB response ceiling.** *"The response size limit is 1 MiB. If the
 * call returns more than 1 MiB of response data, the call is terminated."* That
 * is why Chapter 4.6 §1's cursor pagination is a correctness requirement here
 * rather than a convention — see {@link ./pagination.ts}.
 *
 * **Writer-only.** *"You can only execute Data API queries on writer instances
 * in a DB cluster"*, reads included. There is no reader to route to.
 *
 * ## A third constraint, measured in Mission 6.3
 *
 * **Multi-statement calls are rejected.** `SELECT 1; SELECT 2` returns
 * `ValidationException: Multistatements aren't supported`. One statement per
 * call, always — which is why the migration runner splits its files rather
 * than sending them whole.
 *
 * **Session state does not survive between calls unless they share a
 * transaction.** `SET search_path` in one call is invisible to the next; inside
 * an explicit transaction it persists. This is why per-function database
 * identity comes from a per-function *credential* (ADR-046) rather than from
 * `SET ROLE`.
 *
 * ## Credentials
 *
 * None are passed to the client. They resolve from the execution role through
 * the SDK's default provider chain, exactly as `aws-sdk-integration.md`
 * requires: *"constructed with **no credential parameters at all**, only a
 * region"*. The *database* credential is a separate thing — a Secrets Manager
 * ARN named in configuration, never a value.
 */
import {
  RDSDataClient,
  ExecuteStatementCommand,
  type ExecuteStatementCommandOutput,
  type SqlParameter,
} from '@aws-sdk/client-rds-data';
import { loadConfig } from './config.js';
import { logger } from './logger.js';
import { withResumeRetry } from './resume.js';

let client: RDSDataClient | undefined;

/**
 * The Data API client, created once per cold start and reused while warm.
 *
 * Reused because construction resolves credentials, and doing that per request
 * would add a round trip to every call for no benefit.
 *
 * **Region comes from the SDK's own provider chain, not from `loadConfig()`.**
 * It used to read the full backend configuration, which quietly coupled every
 * caller to the Lambda environment: the migration runner resolves its own
 * target from AWS and has no `CHUNK_BUCKET`, yet could not construct a client
 * without one. A client needs a region; requiring six unrelated variables to
 * get it was the defect. Lambda always sets `AWS_REGION`, so nothing changes
 * for the handlers.
 */
export function dataApiClient(): RDSDataClient {
  client ??= new RDSDataClient({});
  return client;
}

/** The identifiers every `rds-data` call carries. */
export interface StatementTarget {
  readonly resourceArn: string;
  readonly secretArn: string;
  readonly database: string;
}

/** Resolves the cluster, credential ARN and database from configuration. */
export function statementTarget(): StatementTarget {
  const config = loadConfig();
  return {
    resourceArn: config.clusterArn,
    secretArn: config.databaseCredentialsSecretArn,
    database: config.databaseName,
  };
}

/** Options for a single statement. */
export interface ExecuteOptions {
  /** Named parameters. Always use these rather than interpolating into SQL. */
  readonly parameters?: SqlParameter[];
  /** Joins an existing transaction, from `BeginTransactionCommand`. */
  readonly transactionId?: string;
  /** Overrides the target — the migration runner uses the master credential. */
  readonly target?: StatementTarget;
}

/**
 * Runs one statement through the Data API.
 *
 * **One statement.** The Data API rejects multi-statement SQL outright, so
 * splitting is the caller's job and a semicolon-joined string is a runtime
 * error rather than a convenience.
 *
 * Retries only while the cluster is resuming from a scale-to-zero pause — see
 * {@link ./resume.ts} for why that is the only retried condition.
 */
export async function execute(
  sql: string,
  options: ExecuteOptions = {},
): Promise<ExecuteStatementCommandOutput> {
  const target = options.target ?? statementTarget();

  return withResumeRetry(
    () =>
      dataApiClient().send(
        new ExecuteStatementCommand({
          resourceArn: target.resourceArn,
          secretArn: target.secretArn,
          database: target.database,
          sql,
          ...(options.parameters === undefined ? {} : { parameters: options.parameters }),
          ...(options.transactionId === undefined ? {} : { transactionId: options.transactionId }),
        }),
      ),
    {
      onRetry: (attempt, delayMs) => {
        // Logged at info rather than warn: a resuming cluster is the expected
        // cost of min_capacity = 0, not a fault.
        logger.info('cluster resuming, retrying', { attempt, delayMs });
      },
    },
  );
}

/** Resets the memoised client. Tests only. */
export function resetDataApiClientForTest(): void {
  client = undefined;
}
