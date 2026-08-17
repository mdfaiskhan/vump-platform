/**
 * The Aurora Data API client — ADR-044.
 *
 * ## What this is, and what Mission 6.2 deliberately did not build
 *
 * The client is constructed here and nothing runs a query through it. Mission
 * 6.3 owns the schema and the statements; wiring a real `ExecuteStatement` now
 * would mean inventing table shapes that 6.3 has not settled.
 *
 * `execute` therefore exists and throws. That is a deliberate choice over
 * omitting it: a handler that imports a missing function fails to compile in
 * 6.3, whereas one that calls this gets a named `NOT_IMPLEMENTED` and a stack
 * trace pointing here.
 *
 * ## Two constraints from ADR-044 that shape every future query
 *
 * **The 1 MiB response ceiling.** *"The response size limit is 1 MiB. If the
 * call returns more than 1 MiB of response data, the call is terminated."* That
 * is why Chapter 4.6 §1's cursor pagination is a correctness requirement here
 * rather than a convention — see {@link ./pagination.ts}.
 *
 * **Writer-only.** *"You can only execute Data API queries on writer instances
 * in a DB cluster"*, reads included. There is no reader to route to, and adding
 * one would not help.
 *
 * ## Credentials
 *
 * None are passed. The client resolves them from the execution role through the
 * SDK's default provider chain, exactly as `aws-sdk-integration.md` requires:
 * *"constructed with **no credential parameters at all**, only a region"*.
 */
import { RDSDataClient } from '@aws-sdk/client-rds-data';
import { ApiError } from './errors.js';
import { loadConfig } from './config.js';

let client: RDSDataClient | undefined;

/**
 * The Data API client, created once per cold start and reused while warm.
 *
 * Reused because construction resolves credentials, and doing that per request
 * would add a round trip to every call for no benefit.
 */
export function dataApiClient(): RDSDataClient {
  client ??= new RDSDataClient({ region: loadConfig().region });
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

/**
 * Runs a statement. **Not implemented in Mission 6.2.**
 *
 * Mission 6.3 replaces this body with a real `ExecuteStatementCommand`. Until
 * then it throws rather than returning an empty result set, because an empty
 * result is a plausible answer and would let a caller believe the database was
 * consulted.
 */
export function execute(_sql: string, _parameters?: Record<string, unknown>): never {
  throw ApiError.notImplemented('Database access');
}

/** Resets the memoised client. Tests only. */
export function resetDataApiClientForTest(): void {
  client = undefined;
}
