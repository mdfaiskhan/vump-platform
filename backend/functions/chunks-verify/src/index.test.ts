/**
 * `chunks-verify` route behaviour, against a mocked Data API, S3 and Lambda.
 *
 * The completion sequence spans two functions and four gates, so most of what
 * matters here is **ordering** — that the object is finalised before it is
 * hashed, that a mismatched digest never reaches `complete_chunk()`, and that
 * `complete_session()` is only asked after the chunk itself completed.
 */
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mockClient } from 'aws-sdk-client-mock';
import { RDSDataClient, ExecuteStatementCommand } from '@aws-sdk/client-rds-data';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import type { APIGatewayProxyEvent } from 'aws-lambda';

import { resetConfigForTest, resetDataApiClientForTest } from '@vump/shared';
import { handler, resetClientsForTest } from './index.js';

const rds = mockClient(RDSDataClient);
const s3 = mockClient(S3Client);
const lambda = mockClient(LambdaClient);

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
const SESSION = '66666666-6666-4666-8666-666666666666';
const CHUNK = '88888888-8888-4888-8888-888888888888';

/** sha256 of the bytes the mocked GetObject returns. */
const PAYLOAD = 'the-uploaded-bytes';
const DIGEST = 'f7152b054b44cfa15618ae88d73ffa2c6726abdba8118d46b7c907226e9cd93b';

function event(status: unknown, role: 'admin' | 'collector' = 'collector'): APIGatewayProxyEvent {
  return {
    httpMethod: 'PATCH',
    resource: '/v1/chunks/{chunkId}/status',
    headers: {},
    pathParameters: { chunkId: CHUNK },
    queryStringParameters: null,
    body: JSON.stringify({ status }),
    requestContext: {
      authorizer: { userId: COLLECTOR, orgId: ORG, role, firebaseUid: 'uid-1' },
    },
  } as unknown as APIGatewayProxyEvent;
}

function chunkRow(status = 'uploading', checksum = DIGEST) {
  return {
    records: [
      [
        { stringValue: CHUNK },
        { stringValue: SESSION },
        { stringValue: 'org/proj/task/sess/0003_chunk.mp4' },
        { stringValue: checksum },
        { stringValue: status },
        { stringValue: 'upload-1' },
      ],
    ],
  };
}

const metadataPresent = { records: [[{ longValue: 1 }]] };
const metadataAbsent = { records: [] };

function body(response: { body: string }): Record<string, unknown> {
  return JSON.parse(response.body) as Record<string, unknown>;
}

function paramsOf(index: number): Record<string, unknown> {
  const list = rds.commandCalls(ExecuteStatementCommand)[index]?.args[0].input.parameters ?? [];
  return Object.fromEntries(list.map((p) => [p.name ?? '', p.value]));
}

function statements(): string[] {
  return rds
    .commandCalls(ExecuteStatementCommand)
    .map((c) => (c.args[0].input.sql ?? '').replace(/\s+/g, ' ').trim());
}

/** A GetObject body the handler can iterate, as the SDK returns one. */
function streamBody() {
  return {
    // A one-chunk async iterable, as the SDK's streaming body presents itself.
    Body: {
      // eslint-disable-next-line @typescript-eslint/require-await
      async *[Symbol.asyncIterator]() {
        yield new TextEncoder().encode(PAYLOAD);
      },
    },
  };
}

beforeEach(() => {
  rds.reset();
  s3.reset();
  lambda.reset();
  resetDataApiClientForTest();
  resetClientsForTest();
  resetConfigForTest();
  Object.assign(process.env, ENV);
  lambda.on(InvokeCommand).resolves({ StatusCode: 200 });
  s3.on(GetObjectCommand).resolves(streamBody() as never);
});

afterEach(() => {
  for (const key of Object.keys(ENV)) {
    process.env[key] = undefined;
  }
});

describe('PATCH — the non-completing transitions', () => {
  it.each(['uploading', 'failed'])('sets %s with the column-level grant', async (status) => {
    rds.on(ExecuteStatementCommand).resolvesOnce(chunkRow('queued')).resolves({ records: [] });

    const response = await handler(event(status));

    expect(response.statusCode).toBe(200);
    expect(statements()[1]).toContain('UPDATE chunks SET status = :status');
    // Nothing is finalised or hashed on these paths.
    expect(lambda.commandCalls(InvokeCommand)).toHaveLength(0);
    expect(s3.commandCalls(GetObjectCommand)).toHaveLength(0);
  });

  it('rejects a status outside the palette', async () => {
    const response = await handler(event('queued'));
    expect(response.statusCode).toBe(400);
    expect(statements()).toHaveLength(0);
  });

  it('refuses an Admin — this is a Collector route', async () => {
    const response = await handler(event('uploading', 'admin'));
    expect(response.statusCode).toBe(403);
  });

  it('404s a chunk the caller does not own', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });
    const response = await handler(event('uploading'));
    expect(response.statusCode).toBe(404);
  });
});

describe('PATCH — the shared-task write path, migration 0014 / item 148', () => {
  // chunks-verify was one of the three WRITE sites item 148 missed. Until this
  // landed, a chunk recorded against a shared-but-unassigned task could not be
  // verified even after it uploaded.
  it('resolves a chunk whose task is shared rather than assigned', async () => {
    // The LEFT JOIN matches on t.shared_with_org; the row comes back either
    // way, which is the relaxation working.
    rds.on(ExecuteStatementCommand).resolvesOnce(chunkRow()).resolves({ records: [] });

    const response = await handler(event('failed'));

    expect(response.statusCode).toBe(200);
  });

  it('still 404s a chunk that is neither owned, assigned nor shared', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    const response = await handler(event('uploading'));

    expect(response.statusCode).toBe(404);
  });

  it('ADDS an explicit org check — BR-20 no longer rests on ownership alone', async () => {
    // This query never joined `projects`, so org isolation was transitive
    // through `s.collector_id = :callerId`. Once the assignment join stopped
    // being an inner one that would have been the ONLY org defence left, so
    // the clause is stated rather than inferred. This site is STRENGTHENED by
    // the same change that widens it.
    rds.on(ExecuteStatementCommand).resolvesOnce(chunkRow()).resolves({ records: [] });

    await handler(event('failed'));

    const resolve = (statements()[0] ?? '').replace(/\s+/g, ' ');
    expect(resolve).toContain('JOIN projects p');
    expect(resolve).toContain('p.org_id = :orgId');
    expect(paramsOf(0).orgId).toEqual({ stringValue: ORG });
  });

  it('keeps caller ownership untouched while widening the assignment gate', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(chunkRow()).resolves({ records: [] });

    await handler(event('failed'));

    const resolve = (statements()[0] ?? '').replace(/\s+/g, ' ');
    // The ownership check — NOT relaxed, and not the same question as the
    // assignment join, which is about the session's owner.
    expect(resolve).toContain('s.collector_id = :callerId');

    const onClause = resolve.slice(
      resolve.indexOf('LEFT JOIN task_assignments'),
      resolve.indexOf('WHERE'),
    );
    expect(onClause).toContain('ta.user_id = s.collector_id');
    expect(onClause).toContain('ta.removed_at IS NULL');
    expect(resolve.slice(resolve.indexOf('WHERE'))).toContain('OR t.shared_with_org');
  });
});

describe('PATCH complete — the four gates, in order', () => {
  it('finalises the upload BEFORE hashing', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(chunkRow())
      .resolvesOnce(metadataPresent)
      .resolves({ records: [] });

    // Order asserted by construction rather than by counting calls: the object
    // genuinely does not exist until CompleteMultipartUpload runs, so a real
    // GetObject issued first would 404. The mock reproduces that.
    //
    // Reset first — `.on()` appends a behaviour and the FIRST match wins, so
    // beforeEach's unconditional stub would otherwise shadow these.
    s3.reset();
    lambda.reset();
    const order: string[] = [];
    lambda.on(InvokeCommand).callsFake(() => {
      order.push('finalize');
      return { StatusCode: 200 };
    });
    s3.on(GetObjectCommand).callsFake(() => {
      order.push('hash');
      if (!order.includes('finalize')) {
        throw Object.assign(new Error('NoSuchKey'), { name: 'NoSuchKey' });
      }
      return streamBody();
    });

    const response = await handler(event('complete'));

    expect(response.statusCode).toBe(200);
    expect(order).toEqual(['finalize', 'hash']);
  });

  it('sends the seam payload chunks-upload recognises', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(chunkRow())
      .resolvesOnce(metadataPresent)
      .resolves({ records: [] });

    await handler(event('complete'));

    const invoke = lambda.commandCalls(InvokeCommand)[0]?.args[0].input;
    expect(invoke?.FunctionName).toBe('vump-dev-chunks-upload');
    // Synchronous: the hash cannot start until the object exists.
    expect(invoke?.InvocationType).toBe('RequestResponse');
    const payload = JSON.parse(Buffer.from(invoke?.Payload as Uint8Array).toString()) as {
      action: string;
    };
    expect(payload.action).toBe('finalize-upload');
  });

  it('treats FunctionError as a failure despite the 200 status code', async () => {
    lambda.on(InvokeCommand).resolves({
      StatusCode: 200,
      FunctionError: 'Unhandled',
      Payload: new TextEncoder().encode('{"errorMessage":"boom"}') as never,
    });
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(chunkRow())
      .resolvesOnce(metadataPresent)
      .resolves({ records: [] });

    const response = await handler(event('complete'));

    // A Lambda that throws still answers 200; reading the status alone would
    // report every failure as a success.
    expect(response.statusCode).toBe(500);
    expect(s3.commandCalls(GetObjectCommand)).toHaveLength(0);
  });

  it('calls complete_chunk then complete_session, never the reverse', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(chunkRow())
      .resolvesOnce(metadataPresent)
      .resolves({ records: [] });

    await handler(event('complete'));

    const sql = statements();
    const chunkAt = sql.findIndex((s) => s.includes('complete_chunk'));
    const sessionAt = sql.findIndex((s) => s.includes('complete_session'));
    expect(chunkAt).toBeGreaterThan(-1);
    // FR-SES-02 asks whether every chunk is complete; asking before this one is
    // would answer about a different state.
    expect(sessionAt).toBeGreaterThan(chunkAt);
  });

  it('sets verified_at only while it is null — the 0006 trigger allows one transition', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(chunkRow())
      .resolvesOnce(metadataPresent)
      .resolves({ records: [] });

    await handler(event('complete'));

    const update = statements().find((s) => s.includes('SET verified_at')) ?? '';
    expect(update).toContain('verified_at IS NULL');
  });
});

describe('PATCH complete — refusals', () => {
  it('fails the chunk on a checksum mismatch and never completes it', async () => {
    rds
      .on(ExecuteStatementCommand)
      .resolvesOnce(chunkRow('uploading', 'f'.repeat(64)))
      .resolvesOnce(metadataPresent)
      .resolves({ records: [] });

    const response = await handler(event('complete'));

    expect(response.statusCode).toBe(400);
    // BR-21. The chunk stays out of 'complete', so Chapter 5.15's local cleanup
    // never becomes eligible and the bytes survive on the device.
    expect(statements().some((s) => s.includes("SET status = 'failed'"))).toBe(true);
    expect(statements().some((s) => s.includes('complete_chunk'))).toBe(false);
  });

  it('names the missing metadata row rather than 500ing — A-191', async () => {
    rds.on(ExecuteStatementCommand).resolvesOnce(chunkRow()).resolves(metadataAbsent);

    const response = await handler(event('complete'));

    expect(response.statusCode).toBe(404);
    expect((body(response).error as { message: string }).message).toContain('metadata');
    // Refused before 633 MB is downloaded for a call that cannot succeed.
    expect(lambda.commandCalls(InvokeCommand)).toHaveLength(0);
    expect(s3.commandCalls(GetObjectCommand)).toHaveLength(0);
  });

  it('is a no-op when the chunk is already complete', async () => {
    rds.on(ExecuteStatementCommand).resolves(chunkRow('complete'));

    const response = await handler(event('complete'));

    // Chapter 5.10 §3 requires the retry to be a no-op — and it must not
    // re-hash 633 MB to reach the same conclusion.
    expect(response.statusCode).toBe(200);
    expect(lambda.commandCalls(InvokeCommand)).toHaveLength(0);
    expect(s3.commandCalls(GetObjectCommand)).toHaveLength(0);
  });
});
