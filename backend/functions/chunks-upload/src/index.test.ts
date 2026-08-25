/**
 * `chunks-upload` route behaviour, against a mocked Data API and S3.
 *
 * Standing caveat: this scripts the clients and asserts on what the handler
 * sends. It cannot see a missing GRANT, and it cannot see whether S3 actually
 * assembles the object — the live probes and Mission 7.3's timing measurement
 * cover those respectively.
 */
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mockClient } from 'aws-sdk-client-mock';
import { RDSDataClient, ExecuteStatementCommand } from '@aws-sdk/client-rds-data';
import {
  S3Client,
  CreateMultipartUploadCommand,
  CompleteMultipartUploadCommand,
  ListPartsCommand,
} from '@aws-sdk/client-s3';
import type { APIGatewayProxyEvent } from 'aws-lambda';

import { resetConfigForTest, resetDataApiClientForTest } from '@vump/shared';
import { handler as rawHandler, resetS3ClientForTest, isFinalizeRequest } from './index.js';

/** The handler answers two event shapes; the route tests only use the proxy one. */
const handler = rawHandler as (e: unknown) => Promise<{ statusCode: number; body: string }>;

vi.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: vi.fn((_c: unknown, command: { input: { PartNumber?: number } }) =>
    Promise.resolve(
      `https://s3.example/part-${String(command.input.PartNumber ?? 0)}?X-Amz-Signature=x`,
    ),
  ),
}));

const rds = mockClient(RDSDataClient);
const s3 = mockClient(S3Client);

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
const COLLECTOR = '22222222-2222-4222-8222-222222222222';
const PROJECT = '33333333-3333-4333-8333-333333333333';
const TASK = '44444444-4444-4444-8444-444444444444';
const SESSION = '66666666-6666-4666-8666-666666666666';
const CHUNK = '88888888-8888-4888-8888-888888888888';
const SUM = 'a'.repeat(64);
const KEY = `${ORG}/${PROJECT}/${TASK}/${SESSION}/0003_${CHUNK}.mp4`;

/** 633,232,477 bytes — Mission 3.8.1's real chunk. 38 parts at 16 MiB. */
const REAL_CHUNK_BYTES = 633_232_477;

function event(body: unknown, role: 'admin' | 'collector' = 'collector'): APIGatewayProxyEvent {
  return {
    httpMethod: 'POST',
    resource: '/v1/sessions/{sessionId}/chunks',
    headers: {},
    pathParameters: { sessionId: SESSION },
    queryStringParameters: null,
    body: body === undefined ? null : JSON.stringify(body),
    requestContext: {
      authorizer: { userId: COLLECTOR, orgId: ORG, role, firebaseUid: 'uid-1' },
    },
  } as unknown as APIGatewayProxyEvent;
}

const validBody = {
  chunk_id: CHUNK,
  sequence_index: 3,
  file_size_bytes: REAL_CHUNK_BYTES,
  checksum_sha256: SUM,
};

/** The session/task/project/org join the key is built from. */
const sessionRow = {
  records: [
    [
      { stringValue: SESSION },
      { stringValue: TASK },
      { stringValue: PROJECT },
      { stringValue: ORG },
    ],
  ],
};

function chunkRow(
  overrides: { session?: string; index?: number; sum?: string; uploadAbsent?: boolean } = {},
) {
  return {
    records: [
      [
        { stringValue: CHUNK },
        { stringValue: overrides.session ?? SESSION },
        { longValue: overrides.index ?? 3 },
        { stringValue: overrides.sum ?? SUM },
        { stringValue: KEY },
        overrides.uploadAbsent === true ? { isNull: true } : { stringValue: 'upload-1' },
      ],
    ],
  };
}

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
  s3.reset();
  resetDataApiClientForTest();
  resetS3ClientForTest();
  resetConfigForTest();
  Object.assign(process.env, ENV);
  s3.on(CreateMultipartUploadCommand).resolves({ UploadId: 'upload-1' });
  s3.on(CompleteMultipartUploadCommand).resolves({});
});

afterEach(() => {
  for (const key of Object.keys(ENV)) {
    process.env[key] = undefined;
  }
});

describe('POST /v1/sessions/{sessionId}/chunks — the key', () => {
  it('composes Chapter 5.14 §1s key from the join, zero-padded', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(sessionRow).resolves({ records: [] });

    const response = await handler(event(validBody));

    expect(response.statusCode).toBe(201);
    // {org}/{project}/{task}/{session}/{seq:04d}_{chunk}.mp4 — the value that
    // was uncomputable by this role until migration 0010.
    expect(body(response).data).toMatchObject({ s3_object_key: KEY });
  });

  it('presigns one URL per 16 MiB part — 38 for a real chunk', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(sessionRow).resolves({ records: [] });

    const response = await handler(event(validBody));

    expect((body(response).data as { upload_urls: string[] }).upload_urls).toHaveLength(38);
  });

  it('404s a session the caller does not own', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    const response = await handler(event(validBody));

    expect(response.statusCode).toBe(404);
    expect(s3.commandCalls(CreateMultipartUploadCommand)).toHaveLength(0);
  });

  it('refuses an Admin', async () => {
    const response = await handler(event(validBody, 'admin'));
    expect(response.statusCode).toBe(403);
    expect(statements()).toHaveLength(0);
  });
});

describe('POST — the shared-task write path, migration 0014 / item 148', () => {
  // The second of the three WRITE sites item 148 missed. Without this, a
  // Collector reaching a task through t.shared_with_org could register a
  // session and then be refused the presigned URLs for every chunk of it.
  it('issues upload URLs when the task is shared rather than assigned', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(sessionRow).resolves({ records: [] });

    const response = await handler(event(validBody));

    expect(response.statusCode).toBe(201);
  });

  it('still 404s a session that is neither owned, assigned nor shared', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    const response = await handler(event(validBody));

    expect(response.statusCode).toBe(404);
    expect(s3.commandCalls(CreateMultipartUploadCommand)).toHaveLength(0);
  });

  it('relaxes the assignment gate without touching caller ownership', async () => {
    // Two different questions live in this query and only one is widened:
    //   s.collector_id = :callerId  -> does the CALLER own the session?
    //   ta.user_id = s.collector_id -> does the session OWNER still have access?
    rds.on(ExecuteStatementCommand).resolvesOnce(sessionRow).resolves({ records: [] });

    await handler(event(validBody));

    const resolve = (statements()[0] ?? '').replace(/\s+/g, ' ');
    expect(resolve).toContain('s.collector_id = :callerId');

    const onClause = resolve.slice(
      resolve.indexOf('LEFT JOIN task_assignments'),
      resolve.indexOf('WHERE'),
    );
    // In the ON clause, never the WHERE — the trap item 148 documents.
    expect(onClause).toContain('ta.user_id = s.collector_id');
    expect(onClause).toContain('ta.removed_at IS NULL');

    const whereClause = resolve.slice(resolve.indexOf('WHERE'));
    expect(whereClause).toContain('OR t.shared_with_org');
    expect(whereClause).toContain('p.org_id = :orgId');
    expect(whereClause).not.toContain('ta.removed_at');
  });
});

describe('POST — retry is idempotent, per A-190', () => {
  it('succeeds on a matching repeat and returns fresh URLs against the stored upload', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(sessionRow).resolves(chunkRow());

    const response = await handler(event(validBody));

    // Chapter 5.10 §3: "a retried registration call is safe to repeat".
    expect(response.statusCode).toBe(200);
    expect(body(response).data).toMatchObject({ s3_object_key: KEY });
    // The stored upload is reused, so parts already in S3 survive — NFR-REL-02.
    expect(s3.commandCalls(CreateMultipartUploadCommand)).toHaveLength(0);
  });

  it.each([
    ['a different session', { session: '99999999-9999-4999-8999-999999999999' }],
    ['a different sequence index', { index: 7 }],
    ['a different checksum', { sum: 'b'.repeat(64) }],
  ])('refuses %s with CHUNK_ALREADY_REGISTERED', async (_label, overrides) => {
    rds.on(ExecuteStatementCommand).resolvesOnce(sessionRow).resolves(chunkRow(overrides));

    const response = await handler(event(validBody));

    expect(response.statusCode).toBe(409);
    expect((body(response).error as { code: string }).code).toBe('CHUNK_ALREADY_REGISTERED');
  });

  it('mints a new upload when the stored one was aborted by lifecycle', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(sessionRow)
      .resolvesOnce(chunkRow({ uploadAbsent: true }))
      .resolves({ records: [] });

    const response = await handler(event(validBody));

    expect(response.statusCode).toBe(200);
    expect(s3.commandCalls(CreateMultipartUploadCommand)).toHaveLength(1);
    // The column-level UPDATE grant 0011 added, and nothing wider.
    expect(statements().some((s) => s.includes('UPDATE chunks SET upload_id'))).toBe(true);
  });
});

describe('POST — validation', () => {
  it.each([
    ['a non-uuid chunk_id', { ...validBody, chunk_id: 'nope' }],
    ['a short checksum', { ...validBody, checksum_sha256: 'abc' }],
    ['a negative sequence index', { ...validBody, sequence_index: -1 }],
    ['a zero file size', { ...validBody, file_size_bytes: 0 }],
    ['a fractional sequence index', { ...validBody, sequence_index: 1.5 }],
  ])('rejects %s before any query', async (_label, payload) => {
    const response = await handler(event(payload));

    expect(response.statusCode).toBe(400);
    expect(statements()).toHaveLength(0);
  });
});

describe('the Fork 1 seam', () => {
  it('recognises a finalize payload and not an API Gateway event', () => {
    expect(isFinalizeRequest({ action: 'finalize-upload' })).toBe(true);
    expect(isFinalizeRequest({ httpMethod: 'POST', resource: '/v1/x' })).toBe(false);
  });

  /** The ownership row `finalizeUpload` checks before touching S3. */
  const ownedBy = (key = KEY, uploadId = 'upload-1') => ({
    records: [[{ stringValue: key }, { stringValue: uploadId }]],
  });

  it('refuses a key the chunk does not own — the compromised-caller case', async () => {
    rds.on(ExecuteStatementCommand).resolves(ownedBy(KEY, 'upload-1'));

    await expect(
      handler({
        action: 'finalize-upload',
        chunkId: CHUNK,
        // Someone else's object, as a compromised chunks-verify could name.
        key: 'other-org/other-project/other-task/other-session/0001_x.mp4',
        uploadId: 'upload-1',
      }),
    ).rejects.toThrow(/does not own the key or upload id/i);

    expect(s3.commandCalls(ListPartsCommand)).toHaveLength(0);
    expect(s3.commandCalls(CompleteMultipartUploadCommand)).toHaveLength(0);
  });

  it('refuses an upload id the chunk does not own', async () => {
    rds.on(ExecuteStatementCommand).resolves(ownedBy(KEY, 'upload-1'));

    await expect(
      handler({ action: 'finalize-upload', chunkId: CHUNK, key: KEY, uploadId: 'upload-999' }),
    ).rejects.toThrow(/does not own the key or upload id/i);

    expect(s3.commandCalls(CompleteMultipartUploadCommand)).toHaveLength(0);
  });

  it('refuses a chunk id that does not exist', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    await expect(
      handler({ action: 'finalize-upload', chunkId: CHUNK, key: KEY, uploadId: 'upload-1' }),
    ).rejects.toThrow(/No chunk/i);

    expect(s3.commandCalls(ListPartsCommand)).toHaveLength(0);
  });

  it('discovers parts with ListParts rather than trusting a reported list', async () => {
    rds.on(ExecuteStatementCommand).resolves(ownedBy());
    s3.on(ListPartsCommand).resolves({
      Parts: [
        { PartNumber: 2, ETag: '"b"' },
        { PartNumber: 1, ETag: '"a"' },
      ],
      IsTruncated: false,
    });

    await handler({ action: 'finalize-upload', chunkId: CHUNK, key: KEY, uploadId: 'upload-1' });

    const complete = s3.commandCalls(CompleteMultipartUploadCommand)[0]?.args[0].input;
    // Sorted, because S3 rejects out-of-order parts and ListParts pagination
    // gives no ordering guarantee across pages.
    expect(complete?.MultipartUpload?.Parts).toEqual([
      { PartNumber: 1, ETag: '"a"' },
      { PartNumber: 2, ETag: '"b"' },
    ]);
  });

  it('follows ListParts pagination rather than assuming one page', async () => {
    rds.on(ExecuteStatementCommand).resolves(ownedBy());
    s3.on(ListPartsCommand)
      .resolvesOnce({
        Parts: [{ PartNumber: 1, ETag: '"a"' }],
        IsTruncated: true,
        NextPartNumberMarker: '1',
      })
      .resolves({ Parts: [{ PartNumber: 2, ETag: '"b"' }], IsTruncated: false });

    await handler({ action: 'finalize-upload', chunkId: CHUNK, key: KEY, uploadId: 'upload-1' });

    expect(s3.commandCalls(ListPartsCommand)).toHaveLength(2);
    expect(
      s3.commandCalls(CompleteMultipartUploadCommand)[0]?.args[0].input.MultipartUpload?.Parts,
    ).toHaveLength(2);
  });

  it('refuses to complete an upload with no parts', async () => {
    rds.on(ExecuteStatementCommand).resolves(ownedBy());
    s3.on(ListPartsCommand).resolves({ Parts: [], IsTruncated: false });

    await expect(
      handler({ action: 'finalize-upload', chunkId: CHUNK, key: KEY, uploadId: 'upload-1' }),
    ).rejects.toThrow(/nothing to finalise/i);
    expect(s3.commandCalls(CompleteMultipartUploadCommand)).toHaveLength(0);
  });
});
