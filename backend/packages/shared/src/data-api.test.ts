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

function awsError(name: string): Error {
  const e = new Error(`${name}: from the SDK`);
  e.name = name;
  return e;
}

beforeEach(() => {
  rds.reset();
  resetDataApiClientForTest();
  resetConfigForTest();
  Object.assign(process.env, ENV);
});

afterEach(() => {
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
});

describe('execute', () => {
  it('sends the statement against the configured target', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [[{ longValue: 1 }]] });

    const out = await execute('SELECT 1');

    expect(out.records).toEqual([[{ longValue: 1 }]]);
    const input = rds.commandCalls(ExecuteStatementCommand)[0]?.args[0].input;
    expect(input?.sql).toBe('SELECT 1');
    expect(input?.resourceArn).toBe(ENV.DATABASE_CLUSTER_ARN);
    expect(input?.database).toBe('vump_dev');
  });

  it('passes named parameters through rather than interpolating', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    await execute('SELECT * FROM users WHERE firebase_uid = :uid', {
      parameters: [{ name: 'uid', value: { stringValue: 'abc' } }],
    });

    const input = rds.commandCalls(ExecuteStatementCommand)[0]?.args[0].input;
    expect(input?.parameters).toEqual([{ name: 'uid', value: { stringValue: 'abc' } }]);
  });

  it('joins a transaction when one is supplied', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    await execute('SET ROLE x', { transactionId: 'tx-1' });

    expect(rds.commandCalls(ExecuteStatementCommand)[0]?.args[0].input.transactionId).toBe('tx-1');
  });

  it('omits transactionId entirely when there is no transaction', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    await execute('SELECT 1');

    const input = rds.commandCalls(ExecuteStatementCommand)[0]?.args[0].input;
    expect(Object.hasOwn(input ?? {}, 'transactionId')).toBe(false);
  });

  it('lets a caller override the target, which the migration runner needs', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    await execute('SELECT 1', {
      target: { resourceArn: 'other-cluster', secretArn: 'other-secret', database: 'other_db' },
    });

    const input = rds.commandCalls(ExecuteStatementCommand)[0]?.args[0].input;
    expect(input?.secretArn).toBe('other-secret');
  });

  it('retries a resuming cluster — the defect Mission 6.3 hit on its first probe', async () => {
    rds
      .on(ExecuteStatementCommand)
      .rejectsOnce(awsError('DatabaseResumingException'))
      .resolves({ records: [[{ longValue: 1 }]] });

    const out = await execute('SELECT 1');

    expect(out.records).toEqual([[{ longValue: 1 }]]);
    expect(rds.commandCalls(ExecuteStatementCommand)).toHaveLength(2);
  }, 10_000);

  it('does not retry a bad statement', async () => {
    rds.on(ExecuteStatementCommand).rejects(awsError('BadRequestException'));

    await expect(execute('SELECT nope')).rejects.toThrow('BadRequestException');
    expect(rds.commandCalls(ExecuteStatementCommand)).toHaveLength(1);
  });
});
