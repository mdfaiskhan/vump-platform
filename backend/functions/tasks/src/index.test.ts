/**
 * `tasks` route behaviour, against a mocked Data API.
 *
 * Same caveat as the `projects` suite: this scripts the client and asserts on
 * what the handler *sends*. It proves the SQL, the scope branch, the validation
 * and the envelope. **It cannot see a missing GRANT** — that needs live Aurora,
 * and the report says which paths got it.
 */
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
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
};

const ORG = '00000000-0000-4000-8000-000000000001';
const OTHER_ORG = '00000000-0000-4000-8000-0000000000ff';
const ADMIN = '11111111-1111-4111-8111-111111111111';
const COLLECTOR = '22222222-2222-4222-8222-222222222222';
const PROJECT = '33333333-3333-4333-8333-333333333333';
const TASK = '44444444-4444-4444-8444-444444444444';

function event(
  method: string,
  resource: string,
  options: {
    role?: 'admin' | 'collector';
    path?: Record<string, string>;
    body?: unknown;
  } = {},
): APIGatewayProxyEvent {
  return {
    httpMethod: method,
    resource,
    headers: {},
    pathParameters: options.path ?? null,
    queryStringParameters: null,
    body: options.body === undefined ? null : JSON.stringify(options.body),
    requestContext: {
      authorizer: {
        userId: (options.role ?? 'admin') === 'admin' ? ADMIN : COLLECTOR,
        orgId: ORG,
        role: options.role ?? 'admin',
        firebaseUid: 'uid-1',
      },
    },
  } as unknown as APIGatewayProxyEvent;
}

function taskRecord() {
  return [
    { stringValue: TASK },
    { stringValue: PROJECT },
    { stringValue: 'Walk the north quay' },
    { stringValue: 'Hold the camera level.' },
    { isNull: true },
    { stringValue: '2026-08-19 10:00:00+00' },
  ];
}

/** A `users` row as the three-column F6 read returns it. */
function userRecord(orgId = ORG, role = 'collector') {
  return [{ stringValue: COLLECTOR }, { stringValue: orgId }, { stringValue: role }];
}

const visible = { records: [[{ longValue: 1 }]] };
const invisible = { records: [] };

function body(response: { body: string }): Record<string, unknown> {
  return JSON.parse(response.body) as Record<string, unknown>;
}

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
});

describe('cross-org access is reported as absent, not forbidden — F13', () => {
  it('answers 404 when the project is not in the caller org', async () => {
    rds.on(ExecuteStatementCommand).resolves(invisible);

    const response = await handler(
      event('GET', '/v1/projects/{projectId}/tasks', { path: { projectId: PROJECT } }),
    );

    // 403 would confirm the id exists, which is exactly what a guess is asking.
    expect(response.statusCode).toBe(404);
    expect((body(response).error as { code: string }).code).toBe('RESOURCE_NOT_FOUND');
  });

  it('rejects a malformed path id before any query', async () => {
    const response = await handler(
      event('GET', '/v1/projects/{projectId}/tasks', { path: { projectId: 'not-a-uuid' } }),
    );

    expect(response.statusCode).toBe(400);
    expect((body(response).error as { code: string }).code).toBe('REQUEST_MALFORMED_ID');
    expect(statements()).toHaveLength(0);
  });
});

describe('GET /v1/projects/{projectId}/tasks', () => {
  it('re-applies BR-19 at task level for a Collector, not just at project level', async () => {
    rds.on(ExecuteStatementCommand).resolves(visible);

    await handler(
      event('GET', '/v1/projects/{projectId}/tasks', {
        role: 'collector',
        path: { projectId: PROJECT },
      }),
    );

    // Being assigned to ONE task in a project must not reveal every task in it.
    const listSql = statements()[1] ?? '';
    expect(listSql).toContain('JOIN task_assignments ta');
    expect(listSql).toContain('ta.removed_at IS NULL');
  });

  it('does not consult assignments for an Admin', async () => {
    rds.on(ExecuteStatementCommand).resolves(visible);

    await handler(event('GET', '/v1/projects/{projectId}/tasks', { path: { projectId: PROJECT } }));

    expect(statements()[1]).not.toContain('task_assignments');
  });
});

describe('PATCH /v1/tasks/{taskId} — A-118', () => {
  it('accepts title, which Chapter 4.6 §3 does not name', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(visible)
      .resolves({ records: [taskRecord()] });

    const response = await handler(
      event('PATCH', '/v1/tasks/{taskId}', { path: { taskId: TASK }, body: { title: 'Renamed' } }),
    );

    expect(response.statusCode).toBe(200);
    expect(statements()[1]).toContain('title = :title');
  });

  it('patches only the fields supplied', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(visible)
      .resolves({ records: [taskRecord()] });

    await handler(
      event('PATCH', '/v1/tasks/{taskId}', {
        path: { taskId: TASK },
        body: { instructions: 'New guidance' },
      }),
    );

    const sql = statements()[1] ?? '';
    expect(sql).toContain('instructions = :instructions');
    expect(sql).not.toContain('title =');
    expect(sql).not.toContain('reference_examples =');
  });

  it('refuses an empty patch rather than issuing a no-op UPDATE', async () => {
    const response = await handler(
      event('PATCH', '/v1/tasks/{taskId}', { path: { taskId: TASK }, body: {} }),
    );

    expect(response.statusCode).toBe(400);
    expect(statements()).toHaveLength(0);
  });

  it('rejects an explicit null, which is not the same as absent', async () => {
    // tasks.title is NOT NULL, so "leave unchanged" and "set to null" cannot be
    // the same request. Accepting null would make a clear-the-field PATCH
    // silently succeed as a no-op.
    const response = await handler(
      event('PATCH', '/v1/tasks/{taskId}', { path: { taskId: TASK }, body: { title: null } }),
    );

    expect(response.statusCode).toBe(400);
    expect(statements()).toHaveLength(0);
  });
});

describe('POST /v1/tasks/{taskId}/assignments — A-181', () => {
  it('resurrects a removed row rather than inserting a second one', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(visible)
      .resolvesOnce({ records: [userRecord()] })
      .resolves({ records: [] });

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/assignments', {
        path: { taskId: TASK },
        body: { collector_id: COLLECTOR },
      }),
    );

    expect(response.statusCode).toBe(204);
    const insert = statements()[2] ?? '';
    // PRIMARY KEY (task_id, user_id) makes a second row impossible, so this is
    // the only expressible form — A-181.
    expect(insert).toContain('ON CONFLICT (task_id, user_id) DO UPDATE');
    expect(insert).toContain('removed_at = NULL');
  });

  it('refuses a collector from another org as 404 — BR-20', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(visible)
      .resolves({ records: [userRecord(OTHER_ORG)] });

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/assignments', {
        path: { taskId: TASK },
        body: { collector_id: COLLECTOR },
      }),
    );

    // The live BR-20 hole migration 0010's users grant was added to close.
    expect(response.statusCode).toBe(404);
    expect(statements().some((s) => s.includes('INSERT INTO task_assignments'))).toBe(false);
  });

  it('refuses assigning an Admin', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(visible)
      .resolves({ records: [userRecord(ORG, 'admin')] });

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/assignments', {
        path: { taskId: TASK },
        body: { collector_id: COLLECTOR },
      }),
    );

    expect(response.statusCode).toBe(400);
    expect(statements().some((s) => s.includes('INSERT INTO task_assignments'))).toBe(false);
  });

  it('refuses a collector that does not exist — UC-07 exception flow', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(visible).resolves({ records: [] });

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/assignments', {
        path: { taskId: TASK },
        body: { collector_id: COLLECTOR },
      }),
    );

    expect(response.statusCode).toBe(404);
  });

  it('reads only the three granted columns from users', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(visible)
      .resolvesOnce({ records: [userRecord()] })
      .resolves({ records: [] });

    await handler(
      event('POST', '/v1/tasks/{taskId}/assignments', {
        path: { taskId: TASK },
        body: { collector_id: COLLECTOR },
      }),
    );

    const usersRead = statements().find((s) => s.includes('FROM users')) ?? '';
    // The grant is column-level: SELECT * would be refused by PostgreSQL, and
    // firebase_uid and email are deliberately outside it.
    expect(usersRead).toContain('SELECT id, org_id, role FROM users');
    expect(usersRead).not.toContain('*');
    expect(usersRead).not.toContain('firebase_uid');
    expect(usersRead).not.toContain('email');
  });

  it('refuses a Collector caller', async () => {
    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/assignments', {
        role: 'collector',
        path: { taskId: TASK },
        body: { collector_id: COLLECTOR },
      }),
    );

    expect(response.statusCode).toBe(403);
    expect(statements()).toHaveLength(0);
  });
});

describe('DELETE /v1/tasks/{taskId}/assignments/{userId}', () => {
  it('soft-removes and never deletes', async () => {
    rds.on(ExecuteStatementCommand).resolves(visible);

    const response = await handler(
      event('DELETE', '/v1/tasks/{taskId}/assignments/{userId}', {
        path: { taskId: TASK, userId: COLLECTOR },
      }),
    );

    expect(response.statusCode).toBe(204);
    const update = statements()[1] ?? '';
    expect(update).toContain('SET removed_at = now()');
    // FR-ADM-04 keeps the row "for audit rather than hard-deleted", and no role
    // in this backend holds SQL DELETE on anything.
    expect(statements().every((s) => !s.startsWith('DELETE FROM'))).toBe(true);
  });

  it('is idempotent without rewriting the original removal time', async () => {
    rds.on(ExecuteStatementCommand).resolves(visible);

    await handler(
      event('DELETE', '/v1/tasks/{taskId}/assignments/{userId}', {
        path: { taskId: TASK, userId: COLLECTOR },
      }),
    );

    // Without this predicate a repeat call resets removed_at, falsifying when
    // the removal actually happened.
    expect(statements()[1]).toContain('removed_at IS NULL');
  });
});

describe('the audit trail', () => {
  it.each([
    [
      'task.create',
      'POST',
      '/v1/projects/{projectId}/tasks',
      { projectId: PROJECT },
      { title: 'T', instructions: 'I' },
    ],
    ['task.update', 'PATCH', '/v1/tasks/{taskId}', { taskId: TASK }, { title: 'T' }],
  ])('records %s in the same transaction', async (action, method, resource, path, payload) => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(visible)
      .resolves({ records: [taskRecord()] });

    await handler(event(method, resource, { path, body: payload }));

    expect(statements().some((s) => s.includes(`'${action}'`))).toBe(true);
    for (const call of rds.commandCalls(ExecuteStatementCommand)) {
      expect(call.args[0].input.transactionId).toBe('tx-1');
    }
    expect(rds.commandCalls(CommitTransactionCommand)).toHaveLength(1);
  });
});
