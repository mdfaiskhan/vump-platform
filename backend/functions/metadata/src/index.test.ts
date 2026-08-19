/**
 * `metadata` route behaviour, against a mocked Data API.
 *
 * The load-bearing assertions here are the **identity checks**: Chapter 4.5
 * §2's document carries four ids the server already knows, and none of them is
 * believed. A mismatch must be refused rather than stored.
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
const OTHER_ORG = '00000000-0000-4000-8000-0000000000ff';
const ADMIN = '11111111-1111-4111-8111-111111111111';
const COLLECTOR = '22222222-2222-4222-8222-222222222222';
const PROJECT = '33333333-3333-4333-8333-333333333333';
const TASK = '44444444-4444-4444-8444-444444444444';
const SESSION = '66666666-6666-4666-8666-666666666666';
const CHUNK = '88888888-8888-4888-8888-888888888888';
const SUM = 'a'.repeat(64);

function event(
  method: string,
  options: { role?: 'admin' | 'collector'; body?: unknown } = {},
): APIGatewayProxyEvent {
  const role = options.role ?? (method === 'POST' ? 'collector' : 'admin');
  return {
    httpMethod: method,
    resource: '/v1/chunks/{chunkId}/metadata',
    headers: {},
    pathParameters: { chunkId: CHUNK },
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

/** The identity join: session, task, project, collector, org, seq, sum, size, status. */
function identityRow(orgId = ORG) {
  return {
    records: [
      [
        { stringValue: SESSION },
        { stringValue: TASK },
        { stringValue: PROJECT },
        { stringValue: COLLECTOR },
        { stringValue: orgId },
        { longValue: 3 },
        { stringValue: SUM },
        { longValue: 633232477 },
        { stringValue: 'complete' },
      ],
    ],
  };
}

/** Chapter 4.5 §2's document, agreeing with `identityRow`. */
const document = {
  chunk_id: CHUNK,
  identity: {
    session_id: SESSION,
    project_id: PROJECT,
    task_id: TASK,
    collector_id: COLLECTOR,
    device_id: 'CPH2707',
  },
  timing: {
    sequence_index: 3,
    started_at: '2026-08-19T10:00:00.000Z',
    ended_at: '2026-08-19T10:10:01.000Z',
    duration_seconds: 601,
  },
  capture: {
    resolution: '1920x1080',
    frame_rate: 30,
    bitrate_kbps: 8000,
    codec: 'h264',
    zoom_factor: 0.6,
    camera: 'rear-wide',
  },
  device_context: { device_model: 'CPH2707', os_version: '16', app_version: '1.0.0' },
  capture_conditions: { gps: { lat: 19.07, lng: 72.87 }, battery_pct: 51, network_type: 'wifi' },
  integrity: { file_size_bytes: 633232477, checksum_sha256: SUM },
  collector_authored: { notes: 'quay was busy', tags: ['harbour'] },
};

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
});

afterEach(() => {
  for (const key of Object.keys(ENV)) {
    process.env[key] = undefined;
  }
});

describe('POST — valibot validates Chapter 4.5 §2s shape', () => {
  it('accepts the canonical document', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(identityRow()).resolves({ records: [] });

    const response = await handler(event('POST', { body: document }));

    expect(response.statusCode).toBe(201);
    expect(statements()[1]).toContain('ON CONFLICT (chunk_id) DO NOTHING');
  });

  it.each([
    ['a missing group', { ...document, capture: undefined }],
    ['a non-uuid identity id', { ...document, identity: { ...document.identity, task_id: 'x' } }],
    [
      'a battery reading over 100',
      {
        ...document,
        capture_conditions: { ...document.capture_conditions, battery_pct: 140 },
      },
    ],
    [
      'a latitude outside range',
      {
        ...document,
        capture_conditions: { ...document.capture_conditions, gps: { lat: 200, lng: 0 } },
      },
    ],
    [
      'a malformed checksum',
      {
        ...document,
        integrity: { ...document.integrity, checksum_sha256: 'short' },
      },
    ],
  ])('rejects %s before any query', async (_label, payload) => {
    const response = await handler(event('POST', { body: payload }));

    expect(response.statusCode).toBe(400);
    expect((body(response).error as { code: string }).code).toBe('REQUEST_INVALID');
    expect(statements()).toHaveLength(0);
  });

  it('accepts an absent gps block — Chapter 4.4 §7 makes it nullable', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(identityRow()).resolves({ records: [] });

    const response = await handler(
      event('POST', {
        body: {
          ...document,
          capture_conditions: { gps: null, battery_pct: null, network_type: null },
        },
      }),
    );

    expect(response.statusCode).toBe(201);
  });
});

describe('POST — the identity group is asserted, never trusted', () => {
  it.each([
    [
      'session_id',
      { identity: { ...document.identity, session_id: '99999999-9999-4999-8999-999999999999' } },
    ],
    [
      'task_id',
      { identity: { ...document.identity, task_id: '99999999-9999-4999-8999-999999999999' } },
    ],
    [
      'project_id',
      { identity: { ...document.identity, project_id: '99999999-9999-4999-8999-999999999999' } },
    ],
    [
      'collector_id',
      { identity: { ...document.identity, collector_id: '99999999-9999-4999-8999-999999999999' } },
    ],
  ])('refuses a document whose %s disagrees with the join', async (field, override) => {
    rds.on(ExecuteStatementCommand).resolves(identityRow());

    const response = await handler(event('POST', { body: { ...document, ...override } }));

    expect(response.statusCode).toBe(400);
    expect((body(response).error as { message: string }).message).toContain(field);
    expect(statements().some((s) => s.includes('INSERT INTO chunk_metadata'))).toBe(false);
  });

  it('refuses a sequence index or checksum that disagrees with the chunk', async () => {
    rds.on(ExecuteStatementCommand).resolves(identityRow());

    const response = await handler(
      event('POST', { body: { ...document, timing: { ...document.timing, sequence_index: 9 } } }),
    );

    expect(response.statusCode).toBe(400);
    expect((body(response).error as { message: string }).message).toContain('sequence_index');
  });

  it('404s a chunk belonging to another Collector', async () => {
    rds.on(ExecuteStatementCommand).resolves({
      records: [
        [
          { stringValue: SESSION },
          { stringValue: TASK },
          { stringValue: PROJECT },
          { stringValue: '99999999-9999-4999-8999-999999999999' },
          { stringValue: ORG },
          { longValue: 3 },
          { stringValue: SUM },
          { longValue: 633232477 },
          { stringValue: 'queued' },
        ],
      ],
    });

    const response = await handler(event('POST', { body: document }));
    expect(response.statusCode).toBe(404);
  });

  it('refuses an Admin — a Collector writes metadata, an Admin reads it', async () => {
    const response = await handler(event('POST', { role: 'admin', body: document }));
    expect(response.statusCode).toBe(403);
  });
});

describe('GET — A-08 / FR-ADM-06', () => {
  const storedRow = {
    records: [
      [
        { stringValue: '2026-08-19 10:00:00+00' },
        { stringValue: '2026-08-19 10:10:01+00' },
        { stringValue: '1920x1080' },
        { longValue: 30 },
        { longValue: 8000 },
        { stringValue: 'h264' },
        { stringValue: '0.6' },
        { stringValue: 'rear-wide' },
        { stringValue: 'CPH2707' },
        { stringValue: '16' },
        { stringValue: '1.0.0' },
        { stringValue: 'CPH2707' },
        { stringValue: '19.07' },
        { stringValue: '72.87' },
        { longValue: 51 },
        { stringValue: 'wifi' },
        { isNull: true },
        { stringValue: '2026-08-19 10:11:00+00' },
      ],
    ],
  };

  it('refuses a Collector — Chapter 4.8 §4 denies them this read', async () => {
    const response = await handler(event('GET', { role: 'collector' }));
    expect(response.statusCode).toBe(403);
    expect(statements()).toHaveLength(0);
  });

  it('404s a chunk in another org — BR-20', async () => {
    rds.on(ExecuteStatementCommand).resolves(identityRow(OTHER_ORG));

    const response = await handler(event('GET'));
    expect(response.statusCode).toBe(404);
  });

  it('returns the checksum paired with its verification state, never bare', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(identityRow()).resolves(storedRow);

    const response = await handler(event('GET'));
    const data = body(response).data as { integrity: Record<string, unknown> };

    // Chapter 4.5 §5: "the checksum is always returned paired with its
    // verified/mismatch status, never as a bare value" — Chapter 2.10's
    // colour-not-alone rule applied to data.
    expect(data.integrity).toMatchObject({
      checksum_sha256: SUM,
      verified: true,
      verified_at: '2026-08-19 10:11:00+00',
    });
  });

  it('rebuilds the identity group from the join rather than storing it', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(identityRow()).resolves(storedRow);

    const response = await handler(event('GET'));
    const data = body(response).data as { identity: Record<string, unknown>; status: string };

    // 0004 stores none of these: "reachable by joining chunks → sessions →
    // tasks → projects and are deliberately not duplicated here."
    expect(data.identity).toMatchObject({
      session_id: SESSION,
      project_id: PROJECT,
      task_id: TASK,
      collector_id: COLLECTOR,
    });
    // Chapter 4.5 §5 asks for the chunk's current status alongside.
    expect(data.status).toBe('complete');
  });

  it('reports an unverified chunk as unverified rather than omitting it', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(identityRow())
      .resolves({ records: [[...(storedRow.records[0] ?? []).slice(0, 17), { isNull: true }]] });

    const response = await handler(event('GET'));
    const data = body(response).data as { integrity: Record<string, unknown> };

    expect(data.integrity).toMatchObject({ verified: false, verified_at: null });
  });
});
