/**
 * `projects` route behaviour, against a mocked Data API.
 *
 * ## What these tests are and are not evidence of
 *
 * They script `RDSDataClient` and assert on the SQL and parameters the handler
 * *sends*. That covers validation, role gating, which scope branch a caller
 * takes, the envelope and the status codes — real coverage of real logic.
 *
 * **They cannot see a missing GRANT.** A mocked client returns whatever the
 * test scripts, so a statement PostgreSQL would refuse with `42501` passes here
 * exactly like one it would run. Migration 0010 exists *because* of that class
 * of defect, so the report says which paths were checked against live Aurora
 * and which were only mocked — item 41's "a green check over an empty set is
 * not evidence", applied to this file.
 */
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mockClient } from 'aws-sdk-client-mock';
import {
  RDSDataClient,
  ExecuteStatementCommand,
  BeginTransactionCommand,
  CommitTransactionCommand,
  RollbackTransactionCommand,
} from '@aws-sdk/client-rds-data';
import type { APIGatewayProxyEvent } from 'aws-lambda';

import { resetConfigForTest, resetDataApiClientForTest } from '@vump/shared';
import { handler } from './index.js';

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
  UPLOAD_FUNCTION_NAME: 'vump-dev-chunks-upload',
};

const ORG = '00000000-0000-4000-8000-000000000001';
const ADMIN = '11111111-1111-4111-8111-111111111111';
const COLLECTOR = '22222222-2222-4222-8222-222222222222';
const PROJECT = '33333333-3333-4333-8333-333333333333';

function caller(role: 'admin' | 'collector'): Record<string, string> {
  return {
    userId: role === 'admin' ? ADMIN : COLLECTOR,
    orgId: ORG,
    role,
    firebaseUid: 'uid-1',
  };
}

function event(
  method: string,
  resource: string,
  options: {
    role?: 'admin' | 'collector';
    body?: unknown;
    query?: Record<string, string>;
  } = {},
): APIGatewayProxyEvent {
  return {
    httpMethod: method,
    resource,
    headers: {},
    pathParameters: null,
    queryStringParameters: options.query ?? null,
    body: options.body === undefined ? null : JSON.stringify(options.body),
    requestContext: { authorizer: caller(options.role ?? 'admin') },
  } as unknown as APIGatewayProxyEvent;
}

/** A `projects` row in the column order the handler reads. */
function projectRecord(id = PROJECT) {
  return [
    { stringValue: id },
    { stringValue: ORG },
    { stringValue: 'Harbour survey' },
    { isNull: true },
    { stringValue: ADMIN },
    { stringValue: '2026-08-19 10:00:00+00' },
    { isNull: true },
  ];
}

function body(response: { statusCode: number; body: string }): Record<string, unknown> {
  return JSON.parse(response.body) as Record<string, unknown>;
}

/** The SQL of every ExecuteStatement the handler issued, whitespace-collapsed. */
function statements(): string[] {
  return rds
    .commandCalls(ExecuteStatementCommand)
    .map((c) => (c.args[0].input.sql ?? '').replace(/\s+/g, ' ').trim());
}

beforeEach(() => {
  rds.reset();
  resetDataApiClientForTest();
  resetConfigForTest();
  Object.assign(process.env, ENV);
  rds.on(BeginTransactionCommand).resolves({ transactionId: 'tx-1' });
  rds.on(CommitTransactionCommand).resolves({});
  rds.on(RollbackTransactionCommand).resolves({});
});

afterEach(() => {
  for (const key of Object.keys(ENV)) {
    process.env[key] = undefined;
  }
  vi.restoreAllMocks();
});

describe('GET /v1/projects — the A-119 scope split', () => {
  it('scopes an Admin to their org and joins nothing', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [projectRecord()] });

    const response = await handler(event('GET', '/v1/projects', { role: 'admin' }));

    expect(response.statusCode).toBe(200);
    const sql = statements()[0] ?? '';
    expect(sql).toContain('WHERE p.org_id = :orgId');
    // The Admin branch must NOT consult assignments — an Admin sees every
    // project in the org, assigned or not.
    expect(sql).not.toContain('task_assignments');
  });

  it('scopes a Collector through task_assignments, excluding removed ones — BR-19', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [projectRecord()] });

    await handler(event('GET', '/v1/projects', { role: 'collector' }));

    const sql = statements()[0] ?? '';
    expect(sql).toContain('JOIN task_assignments ta');
    expect(sql).toContain('ta.user_id = :userId');
    // Chapter 4.8 §3: a removed assignment "immediately excludes that Task from
    // all future queries". Without this clause an unassigned Collector keeps
    // seeing the project.
    expect(sql).toContain('ta.removed_at IS NULL');
    expect(sql).toContain('DISTINCT');
  });

  it('binds the COLLECTOR from the authorizer context, never from the request', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    // A body naming a different user is ignored entirely: the scope comes from
    // the token context. This is A-119's central claim, asserted rather than
    // assumed.
    await handler(
      event('GET', '/v1/projects', {
        role: 'collector',
        query: { userId: ADMIN },
      }),
    );

    const params = rds.commandCalls(ExecuteStatementCommand)[0]?.args[0].input.parameters ?? [];
    const bound = params.find((p) => p.name === 'userId');
    expect(bound?.value?.stringValue).toBe(COLLECTOR);
  });

  it('excludes archived projects in both branches — the stated F12 default', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    await handler(event('GET', '/v1/projects', { role: 'admin' }));
    await handler(event('GET', '/v1/projects', { role: 'collector' }));

    for (const sql of statements()) {
      expect(sql).toContain('p.archived_at IS NULL');
    }
  });
});

describe('GET /v1/projects — pagination', () => {
  it('asks for one row more than the limit, so it can detect a next page', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    await handler(event('GET', '/v1/projects', { query: { limit: '2' } }));

    expect(statements()[0]).toContain('LIMIT 3');
  });

  it('returns a cursor only when the extra row came back', async () => {
    rds.on(ExecuteStatementCommand).resolves({
      records: [projectRecord('aaaaaaaa-1111-4111-8111-111111111111'), projectRecord()],
    });

    const response = await handler(event('GET', '/v1/projects', { query: { limit: '1' } }));
    const envelope = body(response);

    expect(envelope.data).toHaveLength(1);
    expect((envelope.meta as { nextCursor: string | null }).nextCursor).not.toBeNull();
  });

  it('refuses a cursor it did not issue', async () => {
    const response = await handler(
      event('GET', '/v1/projects', { query: { cursor: 'not-a-cursor' } }),
    );

    expect(response.statusCode).toBe(400);
    expect((body(response).error as { code: string }).code).toBe('REQUEST_INVALID_CURSOR');
    // Refused before any query ran.
    expect(statements()).toHaveLength(0);
  });

  it('never renders the internal sort key', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [projectRecord()] });

    const response = await handler(event('GET', '/v1/projects'));
    const [first] = body(response).data as Record<string, unknown>[];

    expect(first).toHaveProperty('created_at');
    // `createdAt` is carried internally for the cursor and must not leak into
    // the wire shape beside its snake_case twin.
    expect(first).not.toHaveProperty('createdAt');
  });
});

describe('POST /v1/projects', () => {
  it('refuses a Collector with AUTH_FORBIDDEN before touching the database', async () => {
    const response = await handler(
      event('POST', '/v1/projects', { role: 'collector', body: { name: 'X' } }),
    );

    expect(response.statusCode).toBe(403);
    expect((body(response).error as { code: string }).code).toBe('AUTH_FORBIDDEN');
    expect(statements()).toHaveLength(0);
  });

  it('takes org_id and created_by from the caller and ignores a body that supplies them', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [projectRecord()] });

    await handler(
      event('POST', '/v1/projects', {
        body: {
          name: 'Harbour survey',
          org_id: '99999999-9999-4999-8999-999999999999',
          created_by: COLLECTOR,
        },
      }),
    );

    const params = rds.commandCalls(ExecuteStatementCommand)[0]?.args[0].input.parameters ?? [];
    // Chapter 4.8 §1: no authorization decision is ever trusted from the
    // client. A body proposing its own tenant is the BR-20 failure shape.
    expect(params.find((p) => p.name === 'orgId')?.value?.stringValue).toBe(ORG);
    expect(params.find((p) => p.name === 'createdBy')?.value?.stringValue).toBe(ADMIN);
  });

  it('writes the audit row inside the same transaction and commits once', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [projectRecord()] });

    const response = await handler(event('POST', '/v1/projects', { body: { name: 'Harbour' } }));

    expect(response.statusCode).toBe(201);
    expect(statements()[1]).toContain("'project.create'");
    // Both statements carried the transaction id, so neither can commit alone.
    for (const call of rds.commandCalls(ExecuteStatementCommand)) {
      expect(call.args[0].input.transactionId).toBe('tx-1');
    }
    expect(rds.commandCalls(CommitTransactionCommand)).toHaveLength(1);
    expect(rds.commandCalls(RollbackTransactionCommand)).toHaveLength(0);
  });

  it('rolls back and commits nothing when the audit write fails', async () => {
    // The half that matters: a project committed without its trail is exactly
    // what Chapter 4.2 §2's append-only record exists to prevent.
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce({ records: [projectRecord()] })
      .rejects(new Error('audit_log insert failed'));

    const response = await handler(event('POST', '/v1/projects', { body: { name: 'Harbour' } }));

    expect(response.statusCode).toBe(500);
    expect(rds.commandCalls(RollbackTransactionCommand)).toHaveLength(1);
    expect(rds.commandCalls(CommitTransactionCommand)).toHaveLength(0);
  });

  it.each([
    ['an absent body', undefined],
    ['a blank name', { name: '   ' }],
    ['a non-string name', { name: 42 }],
    ['a name over 200 characters', { name: 'x'.repeat(201) }],
  ])('rejects %s with REQUEST_INVALID', async (_label, payload) => {
    const response = await handler(
      event('POST', '/v1/projects', payload === undefined ? {} : { body: payload }),
    );

    expect(response.statusCode).toBe(400);
    expect((body(response).error as { code: string }).code).toBe('REQUEST_INVALID');
    expect(statements()).toHaveLength(0);
  });
});
