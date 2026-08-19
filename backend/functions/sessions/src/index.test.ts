/**
 * `sessions` route behaviour, against a mocked Data API.
 *
 * Same standing caveat as Batches 1's suites: this scripts the client and
 * asserts on what the handler *sends*. It cannot see a missing GRANT — that is
 * what the live probes are for, and the report says which ran.
 *
 * **The ON CONFLICT resurrection path is mock-only, deliberately.** Proving it
 * live means inserting a session and re-registering it, and A-173 means no role
 * can delete the row afterwards. Unlike `task_assignments`, a stray `sessions`
 * row is not inert: `chunks.session_id` references it, so it becomes permanent
 * fixture data in a shared dev database.
 */
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mockClient } from 'aws-sdk-client-mock';
import { RDSDataClient, ExecuteStatementCommand } from '@aws-sdk/client-rds-data';
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
const TASK = '44444444-4444-4444-8444-444444444444';
const OTHER_TASK = '55555555-5555-4555-8555-555555555555';
const SESSION = '66666666-6666-4666-8666-666666666666';
const CLIENT_SESSION = '77777777-7777-4777-8777-777777777777';

function event(
  method: string,
  resource: string,
  options: { role?: 'admin' | 'collector'; path?: Record<string, string>; body?: unknown } = {},
): APIGatewayProxyEvent {
  const role = options.role ?? 'collector';
  return {
    httpMethod: method,
    resource,
    headers: {},
    pathParameters: options.path ?? null,
    queryStringParameters: null,
    body: options.body === undefined ? null : JSON.stringify(options.body),
    requestContext: {
      authorizer: {
        userId: role === 'admin' ? ADMIN : COLLECTOR,
        orgId: ORG,
        role,
        firebaseUid: 'uid-1',
      },
    },
  } as unknown as APIGatewayProxyEvent;
}

function sessionRecord(taskId = TASK) {
  return [
    { stringValue: SESSION },
    { stringValue: taskId },
    { stringValue: COLLECTOR },
    { stringValue: CLIENT_SESSION },
    { stringValue: '2026-08-19 10:00:00+00' },
    { stringValue: 'in_progress' },
    { isNull: true },
  ];
}

const assigned = { records: [[{ longValue: 1 }]] };
const notAssigned = { records: [] };

function body(response: { body: string }): Record<string, unknown> {
  return JSON.parse(response.body) as Record<string, unknown>;
}

function statements(): string[] {
  return rds
    .commandCalls(ExecuteStatementCommand)
    .map((c) => (c.args[0].input.sql ?? '').replace(/\s+/g, ' ').trim());
}

function paramsOf(index: number): Record<string, unknown> {
  const list = rds.commandCalls(ExecuteStatementCommand)[index]?.args[0].input.parameters ?? [];
  const entries: [string, unknown][] = list.map((p) => [p.name ?? '', p.value]);
  return Object.fromEntries(entries);
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

describe('POST /v1/tasks/{taskId}/sessions — BR-19', () => {
  it('refuses an Admin, whose role this route is not', async () => {
    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        role: 'admin',
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION },
      }),
    );

    expect(response.statusCode).toBe(403);
    expect(statements()).toHaveLength(0);
  });

  it('404s an unassigned task rather than revealing it exists', async () => {
    rds.on(ExecuteStatementCommand).resolves(notAssigned);

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION },
      }),
    );

    expect(response.statusCode).toBe(404);
    // Nothing was inserted.
    expect(statements().some((s) => s.includes('INSERT INTO sessions'))).toBe(false);
  });

  it('scopes the assignment check by user, org and removed_at', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(assigned)
      .resolves({ records: [sessionRecord()] });

    await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION },
      }),
    );

    const check = statements()[0] ?? '';
    expect(check).toContain('ta.user_id = :userId');
    expect(check).toContain('ta.removed_at IS NULL');
    expect(check).toContain('p.org_id = :orgId');
    expect(paramsOf(0).userId).toEqual({ stringValue: COLLECTOR });
  });
});

describe('POST — idempotent registration', () => {
  it('inserts with DO NOTHING, never DO UPDATE — the role has no UPDATE grant', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(assigned)
      .resolves({ records: [sessionRecord()] });

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION },
      }),
    );

    expect(response.statusCode).toBe(201);
    const insert = statements()[1] ?? '';
    expect(insert).toContain('ON CONFLICT (collector_id, client_session_id) DO NOTHING');
    // DO UPDATE needs INSERT *and* UPDATE. vump_sessions has only INSERT, so
    // this form would be 42501 against the real role.
    expect(insert).not.toContain('DO UPDATE');
  });

  it('re-reads and returns the existing session with 200, not 201', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(assigned)
      .resolvesOnce({ records: [] }) // DO NOTHING returned nothing: it conflicted
      .resolves({ records: [sessionRecord()] });

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION },
      }),
    );

    expect(response.statusCode).toBe(200);
    expect((body(response).data as { id: string }).id).toBe(SESSION);
    expect(statements()[2]).toContain('SELECT');
  });

  it('refuses the same client_session_id under a different task', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(assigned)
      .resolvesOnce({ records: [] })
      // The stored session belongs to a DIFFERENT task than the one requested.
      .resolves({ records: [sessionRecord(OTHER_TASK)] });

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION },
      }),
    );

    // Returning the original would put every later chunk under a task the
    // caller never asked for — F2's chunk_id echo check, one level up.
    expect(response.statusCode).toBe(409);
    expect((body(response).error as { code: string }).code).toBe('SESSION_ALREADY_REGISTERED');
  });

  it('binds the collector from the authorizer, not from the body', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(assigned)
      .resolves({ records: [sessionRecord()] });

    await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION, collector_id: ADMIN },
      }),
    );

    expect(paramsOf(1).collectorId).toEqual({ stringValue: COLLECTOR, typeHint: undefined });
  });
});

describe('POST — F15, the client-supplied started_at', () => {
  it('sends SQL NULL when absent, so the column default applies', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(assigned)
      .resolves({ records: [sessionRecord()] });

    await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION },
      }),
    );

    expect(statements()[1]).toContain('COALESCE(:startedAt::timestamptz, now())');
    expect(paramsOf(1).startedAt).toEqual({ isNull: true });
  });

  it('accepts a past instant — a deferred upload reports when capture began', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(assigned)
      .resolves({ records: [sessionRecord()] });

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION, started_at: '2026-08-18T09:00:00Z' },
      }),
    );

    expect(response.statusCode).toBe(201);
    expect(paramsOf(1).startedAt).toEqual({ stringValue: '2026-08-18T09:00:00Z' });
  });

  it('rejects an instant in the future — a broken or dishonest clock', async () => {
    const future = new Date(Date.now() + 3_600_000).toISOString();

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION, started_at: future },
      }),
    );

    expect(response.statusCode).toBe(400);
    expect(statements()).toHaveLength(0);
  });

  it('accepts an instant seconds ahead, which is drift rather than a claim', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(assigned)
      .resolves({ records: [sessionRecord()] });
    const slightlyAhead = new Date(Date.now() + 5_000).toISOString();

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION, started_at: slightlyAhead },
      }),
    );

    expect(response.statusCode).toBe(201);
  });

  it('has no lower bound — a week-old field recording is still accepted', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(assigned)
      .resolves({ records: [sessionRecord()] });
    const weekOld = new Date(Date.now() - 7 * 86_400_000).toISOString();

    const response = await handler(
      event('POST', '/v1/tasks/{taskId}/sessions', {
        path: { taskId: TASK },
        body: { client_session_id: CLIENT_SESSION, started_at: weekOld },
      }),
    );

    // No requirement anywhere bounds how long a chunk may sit on a device, so
    // inventing a cutoff would silently reject real offline work.
    expect(response.statusCode).toBe(201);
  });
});

describe('GET /v1/tasks/{taskId}/sessions — A-07 / FR-ADM-05', () => {
  it('refuses a Collector — Chapter 4.8 §4 denies them this view', async () => {
    const response = await handler(
      event('GET', '/v1/tasks/{taskId}/sessions', {
        role: 'collector',
        path: { taskId: TASK },
      }),
    );

    expect(response.statusCode).toBe(403);
    expect(statements()).toHaveLength(0);
  });

  it('scopes by org through tasks and projects — BR-20', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    await handler(
      event('GET', '/v1/tasks/{taskId}/sessions', { role: 'admin', path: { taskId: TASK } }),
    );

    const sql = statements()[0] ?? '';
    expect(sql).toContain('JOIN projects p');
    expect(sql).toContain('p.org_id = :orgId');
    expect(sql).toContain('ORDER BY s.started_at DESC, s.id DESC');
  });

  it('does not query chunk counts for an empty page', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    const response = await handler(
      event('GET', '/v1/tasks/{taskId}/sessions', { role: 'admin', path: { taskId: TASK } }),
    );

    expect(body(response).data).toEqual([]);
    // One statement, not two: an aggregate over no sessions is wasted work.
    expect(statements()).toHaveLength(1);
  });

  it('attaches chunk status counts per session — FR-ADM-05 asks for both', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce({ records: [sessionRecord()] })
      .resolves({
        records: [
          [{ stringValue: SESSION }, { stringValue: 'complete' }, { longValue: 37 }],
          [{ stringValue: SESSION }, { stringValue: 'failed' }, { longValue: 1 }],
        ],
      });

    const response = await handler(
      event('GET', '/v1/tasks/{taskId}/sessions', { role: 'admin', path: { taskId: TASK } }),
    );

    const [first] = body(response).data as Record<string, unknown>[];
    expect(first?.chunk_status).toEqual({ complete: 37, failed: 1 });
    expect(statements()[1]).toContain('GROUP BY c.session_id, c.status');
  });

  it('renders a session with no chunks as an empty object, not fabricated zeroes', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce({ records: [sessionRecord()] })
      .resolves({ records: [] });

    const response = await handler(
      event('GET', '/v1/tasks/{taskId}/sessions', { role: 'admin', path: { taskId: TASK } }),
    );

    const [first] = body(response).data as Record<string, unknown>[];
    expect(first?.chunk_status).toEqual({});
  });

  it('never renders the internal sort key', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce({ records: [sessionRecord()] })
      .resolves({ records: [] });

    const response = await handler(
      event('GET', '/v1/tasks/{taskId}/sessions', { role: 'admin', path: { taskId: TASK } }),
    );

    const [first] = body(response).data as Record<string, unknown>[];
    expect(first).toHaveProperty('started_at');
    expect(first).not.toHaveProperty('createdAt');
  });
});
