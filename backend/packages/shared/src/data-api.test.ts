import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mockClient } from 'aws-sdk-client-mock';
import { RDSDataClient, ExecuteStatementCommand } from '@aws-sdk/client-rds-data';
import { dataApiClient, execute, statementTarget, resetDataApiClientForTest } from './data-api.js';
import { resetConfigForTest } from './config.js';

const rds = mockClient(RDSDataClient);

const ENV = {
  APP_ENV: 'development',
  AWS_REGION: 'ap-south-1',
  CHUNK_BUCKET: 'vump-platform-dev',
  PRESIGN_EXPIRY_SECONDS: '3600',
  DATABASE_CLUSTER_ARN: 'arn:aws:rds:ap-south-1:000000000000:cluster:vump-dev-aurora',
  DATABASE_CREDENTIALS_SECRET_ARN: 'arn:aws:secretsmanager:ap-south-1:000000000000:secret:x',
  DATABASE_NAME: 'vump_dev',
  FIREBASE_PROJECT_ID: 'vump-platform-f86af',
};

beforeEach(() => {
  rds.reset();
  resetDataApiClientForTest();
  resetConfigForTest();
  Object.assign(process.env, ENV);
});

afterEach(() => {
  // Assigning undefined rather than `delete`: the dynamic-delete rule is on,
  // and `loadConfig` treats undefined and absent identically.
  for (const key of Object.keys(ENV)) {
    process.env[key] = undefined;
  }
});

describe('the Data API client', () => {
  it('resolves the cluster, credential ARN and database from configuration', () => {
    expect(statementTarget()).toEqual({
      resourceArn: ENV.DATABASE_CLUSTER_ARN,
      secretArn: ENV.DATABASE_CREDENTIALS_SECRET_ARN,
      database: 'vump_dev',
    });
  });

  it('is constructed once and reused while warm', () => {
    expect(dataApiClient()).toBe(dataApiClient());
  });

  it('refuses to run a statement in Mission 6.2 rather than returning empty', () => {
    // An empty result set is a plausible answer, and would let a caller believe
    // the database had been consulted. A named refusal cannot be mistaken.
    expect(() => execute('SELECT 1')).toThrow(/not implemented yet/);
  });

  it('sends nothing to AWS — the scaffold issues no queries at all', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    expect(() => execute('SELECT 1')).toThrow();

    // The assertion that matters for Mission 6.2's scope: no rds-data call was
    // made. If a future change wires a real query in, this fails.
    expect(rds.commandCalls(ExecuteStatementCommand)).toHaveLength(0);
    await Promise.resolve();
  });
});
