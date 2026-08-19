/**
 * `chunks-verify` — Chunk status transitions and integrity verification.
 * ADR-015 domain: chunks; role `vump-{env}-chunks-verify`, which holds
 * `s3:GetObject` and cannot write.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   PATCH /v1/chunks/{chunkId}/status
 *
 * ## The completion sequence, and why it spans two functions
 *
 * Reaching `'complete'` requires four things in order, and the first cannot
 * happen here:
 *
 *   1. **Finalise the multipart upload** — `CompleteMultipartUpload` requires
 *      `s3:PutObject`, which this role does not have and must not have. A-143
 *      makes the split structural: *"`chunks-upload` holds `s3:PutObject` and
 *      cannot read; `chunks-verify` holds `s3:GetObject` and cannot write."*
 *      So this function **invokes `chunks-upload`** to do it. Fork 1 option B.
 *   2. **Hash the object** — stream `GetObject` through SHA-256 and compare
 *      against `chunks.checksum_sha256`. Chapter 4.5 §3, FR-META-12.
 *   3. **Set `chunk_metadata.verified_at`** — the column-level grant `0007`
 *      issued for exactly this.
 *   4. **`complete_chunk()`** then **`complete_session()`** — BR-21 and
 *      FR-SES-02, both `SECURITY DEFINER` so this role needs `EXECUTE` and no
 *      `UPDATE` on either table.
 *
 * ## Why this is synchronous, and why that is safe
 *
 * Chapter 4.10 §2 step 3 permits an S3-event trigger instead. It is not used:
 * an event-triggered Lambda has no authorizer in front of it, and ADR-048's
 * authorizer is precisely what absorbs Gap 9's Aurora resume before this
 * function runs. Going asynchronous would reopen a measured, closed risk.
 *
 * The budget was measured rather than assumed, at 1769MB against a real
 * 633,232,477-byte, 38-part upload:
 *
 *   ListParts 48ms + CompleteMultipartUpload 99ms + hash 7780ms = 7928ms
 *   against API Gateway's 29s ceiling — **21072ms of margin.**
 *
 * ## An absent metadata row is a client ordering error — A-191
 *
 * `complete_chunk()` refuses without a verified `chunk_metadata` row, and
 * Chapter 5.10 §1 puts the metadata POST at step 4, *after* this call at step
 * 3. A client following the chapter literally will always be refused here. The
 * refusal names the cause rather than letting `restrict_violation` surface as
 * `INTERNAL_ERROR`.
 */
import { createHash } from 'node:crypto';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import {
  ApiError,
  createRouter,
  execute,
  loadConfig,
  parseBody,
  pathUuid,
  readOptionalString,
  readString,
  requireRole,
  requiredString,
  routeKey,
  textParam,
  uuidParam,
  withEnvelope,
  type RouteTable,
} from '@vump/shared';

/** Chapter 4.4 §6's status palette. `'queued'` is the insert default, never patched to. */
const PATCHABLE = new Set(['uploading', 'failed', 'complete']);

let s3Client: S3Client | undefined;
let lambdaClient: LambdaClient | undefined;

function s3(): S3Client {
  s3Client ??= new S3Client({});
  return s3Client;
}

function lambda(): LambdaClient {
  lambdaClient ??= new LambdaClient({});
  return lambdaClient;
}

/** Resets the memoised clients. Tests only. */
export function resetClientsForTest(): void {
  s3Client = undefined;
  lambdaClient = undefined;
}

/** What the chunk lookup yields. */
interface ChunkContext {
  readonly chunkId: string;
  readonly sessionId: string;
  readonly key: string;
  readonly checksum: string;
  readonly status: string;
  readonly uploadId: string | null;
}

/**
 * Resolves the chunk and confirms the caller owns it.
 *
 * `chunks ⋈ sessions` for ownership and `task_assignments` for BR-19 — both
 * grants added by migration `0010`, without which this role could transition
 * the status of any chunk id it was handed.
 */
async function resolveChunk(chunkId: string, callerId: string): Promise<ChunkContext> {
  const found = await execute(
    `SELECT c.id, c.session_id, c.s3_object_key, c.checksum_sha256, c.status, c.upload_id
       FROM chunks c
       JOIN sessions s          ON s.id = c.session_id
       JOIN task_assignments ta ON ta.task_id = s.task_id AND ta.user_id = s.collector_id
      WHERE c.id = :chunkId
        AND s.collector_id = :callerId
        AND ta.removed_at IS NULL
      LIMIT 1`,
    { parameters: [uuidParam('chunkId', chunkId), uuidParam('callerId', callerId)] },
  );

  const row = found.records?.[0];
  if (row === undefined) {
    throw ApiError.notFound('That chunk');
  }
  return {
    chunkId: readString(row, 0, 'chunks.id'),
    sessionId: readString(row, 1, 'chunks.session_id'),
    key: readString(row, 2, 'chunks.s3_object_key'),
    checksum: readString(row, 3, 'chunks.checksum_sha256'),
    status: readString(row, 4, 'chunks.status'),
    uploadId: readOptionalString(row, 5),
  };
}

/**
 * Streams the uploaded object through SHA-256.
 *
 * O(1) in memory — the hash holds 32 bytes of state and the body is never
 * buffered — which is why 633 MB is a time question rather than a memory one.
 *
 * `GetObjectAttributes` cannot substitute: S3 stores a SHA-256 only if one was
 * requested at upload time, and for a multipart upload it is a
 * composite-of-parts rather than the whole-object digest the device computed.
 * Hashing the delivered bytes sidesteps that entirely and needs no change to
 * what the client sends.
 */
async function digestOf(key: string): Promise<string> {
  const { chunkBucket } = loadConfig();
  const object = await s3().send(new GetObjectCommand({ Bucket: chunkBucket, Key: key }));

  const hash = createHash('sha256');
  const body = object.Body as AsyncIterable<Uint8Array> | undefined;
  if (body === undefined) {
    throw new Error(`GetObject returned no body for ${key}.`);
  }
  for await (const part of body) {
    hash.update(part);
  }
  return hash.digest('hex');
}

/** Asks `chunks-upload` to finalise the multipart upload — the Fork 1 seam. */
async function finalizeUpload(chunk: ChunkContext): Promise<void> {
  if (chunk.uploadId === null) {
    // Registration always stores one, so its absence means the row and the
    // handler disagree rather than that the client did something wrong.
    throw new Error(`Chunk ${chunk.chunkId} has no upload_id; cannot finalise.`);
  }

  const { uploadFunctionName } = loadConfig();
  const response = await lambda().send(
    new InvokeCommand({
      FunctionName: uploadFunctionName,
      // Synchronous. The hash cannot start until the object exists.
      InvocationType: 'RequestResponse',
      Payload: Buffer.from(
        JSON.stringify({
          action: 'finalize-upload',
          chunkId: chunk.chunkId,
          key: chunk.key,
          uploadId: chunk.uploadId,
        }),
        'utf8',
      ),
    }),
  );

  // A Lambda that throws still returns HTTP 200 with FunctionError set, so the
  // status code alone would report every failure as a success.
  if (response.FunctionError !== undefined) {
    const detail = response.Payload === undefined ? '' : Buffer.from(response.Payload).toString();
    throw new Error(`Finalising the upload failed: ${response.FunctionError} ${detail}`);
  }
}

/** What the PATCH returns. `verified` is absent unless completion happened. */
interface StatusResult {
  readonly chunk_id: string;
  readonly status: string;
  readonly verified?: boolean;
}

/**
 * Chapter 4.6 §4 — *"Transitions queued → uploading → complete/failed;
 * 'complete' gated server-side per Chapter 4.2."*
 */
const patchStatus = withEnvelope<StatusResult>(
  'PATCH /v1/chunks/{chunkId}/status',
  async (event, caller) => {
    requireRole(caller, 'collector');
    const chunkId = pathUuid(event.pathParameters, 'chunkId');

    const body = parseBody(event.body);
    const status = requiredString(body, 'status', 20);
    if (!PATCHABLE.has(status)) {
      throw ApiError.invalidRequest("status must be one of 'uploading', 'failed' or 'complete'.");
    }

    const chunk = await resolveChunk(chunkId, caller.userId);

    if (status !== 'complete') {
      // The column-level UPDATE (status) grant. This role cannot touch
      // s3_object_key, checksum_sha256 or file_size_bytes even on a row it may
      // transition, and the 0006 trigger stops it reaching 'complete' this way.
      await execute('UPDATE chunks SET status = :status WHERE id = :chunkId', {
        parameters: [textParam('status', status), uuidParam('chunkId', chunkId)],
      });
      return { data: { chunk_id: chunkId, status } };
    }

    // Chapter 5.10 §3: "a no-op if the chunk is already Complete", so a retried
    // request after a dropped response must not fail — and must not re-hash 633
    // MB to reach the same conclusion.
    if (chunk.status === 'complete') {
      return { data: { chunk_id: chunkId, status: 'complete', verified: true } };
    }

    await requireMetadataRow(chunkId);
    await finalizeUpload(chunk);

    const digest = await digestOf(chunk.key);
    if (digest.toLowerCase() !== chunk.checksum.toLowerCase()) {
      // BR-21's whole point. The chunk stays out of 'complete', so Chapter 5.15's
      // local cleanup never becomes eligible and the bytes survive on the device.
      await execute("UPDATE chunks SET status = 'failed' WHERE id = :chunkId", {
        parameters: [uuidParam('chunkId', chunkId)],
      });
      throw ApiError.invalidRequest(
        'The uploaded object does not match the registered checksum_sha256.',
      );
    }

    // FR-META-12. Column-level, so this role can set verified_at and nothing else
    // in that table — and the 0006 trigger allows NULL → value exactly once.
    await execute(
      'UPDATE chunk_metadata SET verified_at = now() WHERE chunk_id = :chunkId AND verified_at IS NULL',
      { parameters: [uuidParam('chunkId', chunkId)] },
    );

    await execute('SELECT complete_chunk(:chunkId)', {
      parameters: [uuidParam('chunkId', chunkId)],
    });

    // FR-SES-02, via migration 0011. Silent when the session still has open
    // chunks, which is the normal case on every call but the last.
    await execute('SELECT complete_session(:sessionId)', {
      parameters: [uuidParam('sessionId', chunk.sessionId)],
    });

    return { data: { chunk_id: chunkId, status: 'complete', verified: true } };
  },
);

/**
 * Refuses before hashing when no metadata row exists — A-191.
 *
 * `complete_chunk()` would refuse anyway, with `restrict_violation`, which
 * `toEnvelopeError` maps to `INTERNAL_ERROR`. Checking first costs one query
 * and turns a 500 into a sentence naming what is missing — and it happens
 * *before* 633 MB is downloaded and hashed for a call that cannot succeed.
 */
async function requireMetadataRow(chunkId: string): Promise<void> {
  const found = await execute('SELECT 1 FROM chunk_metadata WHERE chunk_id = :chunkId', {
    parameters: [uuidParam('chunkId', chunkId)],
  });
  if ((found.records ?? []).length === 0) {
    throw ApiError.notFound(
      "This chunk's metadata (POST /v1/chunks/{chunkId}/metadata must precede completion)",
    );
  }
}

const routes: RouteTable = {
  [routeKey('PATCH', '/v1/chunks/{chunkId}/status')]: patchStatus,
};

export const handler = createRouter('chunks-verify', routes);
