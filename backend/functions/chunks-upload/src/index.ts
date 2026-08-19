/**
 * `chunks-upload` — Chunk registration, presigned upload URLs, and multipart
 * finalisation. ADR-015 domain: chunks; role `vump-{env}-chunks-upload`, which
 * holds `s3:PutObject` and cannot read.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   POST /v1/sessions/{sessionId}/chunks
 *
 * ## This function is invoked two ways, and that is the Fork 1 seam
 *
 * API Gateway calls it for its own route. **`chunks-verify` also invokes it
 * directly**, to finalise a multipart upload, and the two are told apart by the
 * event shape exactly as ADR-048 tells the authorizer apart from a proxy event.
 *
 * The reason is A-143, which `modules/iam/main.tf` states as a structural
 * property: *"One policy per role, never both on one. `chunks-upload` holds
 * `s3:PutObject` and cannot read; `chunks-verify` holds `s3:GetObject` and
 * cannot write."* `CompleteMultipartUpload` requires `s3:PutObject`, so the
 * function that verifies cannot be the function that finalises — without
 * handing the role that downloads evidentiary footage the ability to overwrite
 * it.
 *
 * Chapter 4.10 §2 step 3 anticipates the split in its own wording: *"a Lambda
 * (**triggered either by that call** or an S3 event notification) verifies…"*.
 *
 * ## Measured, not assumed
 *
 * Mission 7.3's probe timed this against a real 633,232,477-byte, 38-part
 * upload at 1769MB: `ListParts` **48ms**, `CompleteMultipartUpload` **99ms**.
 * Both negligible beside F4's 7780ms hash, which is what made the synchronous
 * PATCH safe with 21 seconds of margin.
 */
import {
  S3Client,
  CreateMultipartUploadCommand,
  CompleteMultipartUploadCommand,
  ListPartsCommand,
  UploadPartCommand,
  type CompletedPart,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import {
  ApiError,
  createRouter,
  execute,
  loadConfig,
  longParam,
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

/** 16 MiB — Mission 7.3 F3, chosen against a real 633.2 MB chunk. */
const PART_BYTES = 16 * 1024 * 1024;

/** A uuid in any version, lower- or upper-case. */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** A SHA-256 digest as 64 lower- or upper-case hex characters. */
const SHA256_HEX = /^[0-9a-f]{64}$/i;

let s3Client: S3Client | undefined;

/** Created once per cold start, reused while warm. */
function s3(): S3Client {
  s3Client ??= new S3Client({});
  return s3Client;
}

/** Resets the memoised client. Tests only. */
export function resetS3ClientForTest(): void {
  s3Client = undefined;
}

/**
 * Volume 5 Chapter 5.14 §1's key, which is authoritative for both sides.
 *
 * `{org_id}/{project_id}/{task_id}/{session_id}/{sequence_index:04d}_{chunk_id}.mp4`
 *
 * Computed here because Chapter 4.10 §2 step 1 says so — *"the Lambda computes
 * the deterministic key (Volume 5.14) and returns"* it — and A-071 corrected
 * the register's earlier belief that the client composed it.
 *
 * Until migration `0010` this role could read `sessions` and nothing above it,
 * so three of the five components were unreachable and the single most
 * load-bearing value in the upload path was not computable by the role assigned
 * to compute it.
 */
function objectKey(parts: {
  orgId: string;
  projectId: string;
  taskId: string;
  sessionId: string;
  sequenceIndex: number;
}): string {
  const index = String(parts.sequenceIndex).padStart(4, '0');
  return `${parts.orgId}/${parts.projectId}/${parts.taskId}/${parts.sessionId}/${index}_`;
}

/** What the session lookup yields: the ids the key needs, and the owner check. */
interface SessionContext {
  readonly sessionId: string;
  readonly taskId: string;
  readonly projectId: string;
  readonly orgId: string;
}

/**
 * Resolves the session and confirms the caller may add a chunk to it.
 *
 * Two conditions, and both are required rather than either:
 *
 *   - `sessions.collector_id = caller` — this is the caller's own session;
 *   - a live `task_assignments` row — BR-19, because Chapter 4.8 §3 says a
 *     removed assignment *"immediately excludes that Task from all future
 *     queries"*, and a Collector removed mid-session still owns the row.
 *
 * 404 rather than 403 throughout — A-186.
 */
async function resolveSession(
  sessionId: string,
  callerId: string,
  orgId: string,
): Promise<SessionContext> {
  const found = await execute(
    `SELECT s.id, t.id AS task_id, p.id AS project_id, p.org_id
       FROM sessions s
       JOIN tasks t             ON t.id = s.task_id
       JOIN projects p          ON p.id = t.project_id
       JOIN task_assignments ta ON ta.task_id = t.id AND ta.user_id = s.collector_id
      WHERE s.id = :sessionId
        AND s.collector_id = :callerId
        AND ta.removed_at IS NULL
        AND p.org_id = :orgId
      LIMIT 1`,
    {
      parameters: [
        uuidParam('sessionId', sessionId),
        uuidParam('callerId', callerId),
        uuidParam('orgId', orgId),
      ],
    },
  );

  const row = found.records?.[0];
  if (row === undefined) {
    throw ApiError.notFound('That session');
  }
  return {
    sessionId: readString(row, 0, 'sessions.id'),
    taskId: readString(row, 1, 'tasks.id'),
    projectId: readString(row, 2, 'projects.id'),
    orgId: readString(row, 3, 'projects.org_id'),
  };
}

/** Presigns one `UploadPart` URL per part, in part order. */
async function presignParts(
  key: string,
  uploadId: string,
  fileSizeBytes: number,
): Promise<string[]> {
  const { chunkBucket, presignExpirySeconds } = loadConfig();
  const count = Math.max(1, Math.ceil(fileSizeBytes / PART_BYTES));

  const urls: string[] = [];
  for (let partNumber = 1; partNumber <= count; partNumber++) {
    urls.push(
      await getSignedUrl(
        s3(),
        new UploadPartCommand({
          Bucket: chunkBucket,
          Key: key,
          UploadId: uploadId,
          PartNumber: partNumber,
        }),
        { expiresIn: presignExpirySeconds },
      ),
    );
  }
  return urls;
}

/**
 * Chapter 4.6 §5 — *"Registers a finalized chunk; returns a presigned S3
 * multipart upload URL set."* Collector only.
 *
 * ## A repeat succeeds; only a mismatch is refused — A-190
 *
 * Chapter 5.10 §3: *"a retried registration call is safe to repeat"*, and that
 * is not incidental — Chapter 5.13 §2 grants six automatic attempts, so a
 * device that uploads some parts and loses connectivity **must** be able to ask
 * again and get fresh presigned URLs against the same multipart upload. A
 * registration that refused the second call would make NFR-REL-02 unreachable
 * by construction.
 *
 * `CHUNK_ALREADY_REGISTERED` is therefore for a genuine mismatch: the same
 * `chunk_id` presented with a different session, sequence index or checksum.
 * `SESSION_ALREADY_REGISTERED`'s shape, one level down.
 *
 * ## `chunk_id` comes from the client — F2
 *
 * Chapter 5.14 §3 mints it on the device *"the moment a chunk begins
 * finalizing"* and Chapter 5.13 §4 requires every retry reuse *"the exact same
 * chunk_id"*. Migration `0010` dropped `chunks.id`'s `DEFAULT
 * gen_random_uuid()` so that a handler which forgot to bind it fails loudly
 * rather than minting a second identity the client would then reject.
 */
const registerChunk = withEnvelope(
  'POST /v1/sessions/{sessionId}/chunks',
  async (event, caller) => {
    requireRole(caller, 'collector');
    const sessionId = pathUuid(event.pathParameters, 'sessionId');

    const body = parseBody(event.body);
    const chunkId = requiredString(body, 'chunk_id', 64);
    if (!UUID.test(chunkId)) {
      throw new ApiError('REQUEST_MALFORMED_ID', 'chunk_id must be a uuid.', 400);
    }
    const checksum = requiredString(body, 'checksum_sha256', 64);
    if (!SHA256_HEX.test(checksum)) {
      throw ApiError.invalidRequest('checksum_sha256 must be 64 hex characters.');
    }
    const sequenceIndex = requiredInteger(body, 'sequence_index', 0);
    const fileSizeBytes = requiredInteger(body, 'file_size_bytes', 1);

    const session = await resolveSession(sessionId, caller.userId, caller.orgId);
    const key = `${objectKey({ ...session, sequenceIndex })}${chunkId}.mp4`;

    // Read first, so a retry does not create a second multipart upload and
    // orphan the first. `CreateMultipartUpload` is only called when there is no
    // stored upload id — either a first registration, or one whose upload S3's
    // 14-day lifecycle rule has since aborted (A-004).
    const existing = await execute(
      `SELECT id, session_id, sequence_index, checksum_sha256, s3_object_key, upload_id
         FROM chunks WHERE id = :chunkId`,
      { parameters: [uuidParam('chunkId', chunkId)] },
    );
    const row = existing.records?.[0];

    if (row !== undefined) {
      const storedSession = readString(row, 1, 'chunks.session_id');
      const storedIndex = row[2]?.longValue ?? -1;
      const storedChecksum = readString(row, 3, 'chunks.checksum_sha256');

      if (
        storedSession !== sessionId ||
        storedIndex !== sequenceIndex ||
        storedChecksum.toLowerCase() !== checksum.toLowerCase()
      ) {
        throw ApiError.chunkAlreadyRegistered();
      }

      const storedKey = readString(row, 4, 'chunks.s3_object_key');
      let uploadId = readOptionalString(row, 5);
      if (uploadId === null) {
        uploadId = await beginUpload(storedKey);
        await execute('UPDATE chunks SET upload_id = :uploadId WHERE id = :chunkId', {
          parameters: [textParam('uploadId', uploadId), uuidParam('chunkId', chunkId)],
        });
      }

      return {
        data: {
          chunk_id: chunkId,
          s3_object_key: storedKey,
          upload_urls: await presignParts(storedKey, uploadId, fileSizeBytes),
        },
        status: 200,
      };
    }

    const uploadId = await beginUpload(key);
    await execute(
      `INSERT INTO chunks (id, session_id, sequence_index, s3_object_key,
                           checksum_sha256, file_size_bytes, upload_id)
            VALUES (:chunkId, :sessionId, :sequenceIndex, :key,
                    :checksum, :fileSize, :uploadId)
       ON CONFLICT (id) DO NOTHING`,
      {
        parameters: [
          uuidParam('chunkId', chunkId),
          uuidParam('sessionId', sessionId),
          longParam('sequenceIndex', sequenceIndex),
          textParam('key', key),
          textParam('checksum', checksum),
          longParam('fileSize', fileSizeBytes),
          textParam('uploadId', uploadId),
        ],
      },
    );

    return {
      data: {
        chunk_id: chunkId,
        s3_object_key: key,
        upload_urls: await presignParts(key, uploadId, fileSizeBytes),
      },
      status: 201,
    };
  },
);

/** Starts a multipart upload and returns its id. */
async function beginUpload(key: string): Promise<string> {
  const { chunkBucket } = loadConfig();
  const created = await s3().send(
    new CreateMultipartUploadCommand({ Bucket: chunkBucket, Key: key }),
  );
  if (created.UploadId === undefined) {
    throw new Error('CreateMultipartUpload returned no UploadId.');
  }
  return created.UploadId;
}

/** A required integer, at or above [minimum]. */
function requiredInteger(body: Record<string, unknown>, field: string, minimum: number): number {
  const value = body[field];
  if (typeof value !== 'number' || !Number.isInteger(value) || value < minimum) {
    throw ApiError.invalidRequest(`${field} must be an integer of at least ${String(minimum)}.`);
  }
  return value;
}

// --- the Fork 1 seam ---------------------------------------------------------

/** What `chunks-verify` sends when it needs a multipart upload finalised. */
export interface FinalizeRequest {
  readonly action: 'finalize-upload';
  readonly chunkId: string;
  readonly key: string;
  readonly uploadId: string;
}

/** True when [event] is the seam's payload rather than an API Gateway proxy event. */
export function isFinalizeRequest(event: unknown): event is FinalizeRequest {
  return (
    typeof event === 'object' &&
    event !== null &&
    (event as { action?: unknown }).action === 'finalize-upload'
  );
}

/**
 * Finalises a multipart upload on `chunks-verify`'s behalf.
 *
 * **The parts are discovered, never reported.** `ListParts` returns every
 * uploaded part with its `ETag`, so the client is not trusted to enumerate what
 * it uploaded — which is what makes Fork 1's server-driven shape possible at
 * all, and was verified against the API reference before this was designed.
 *
 * Paginated even though it will not paginate in practice: `ListParts` caps at
 * 1,000 parts and a 633 MB chunk is 38, but a handler that assumes one page is
 * a handler that silently truncates the day the assumption stops holding.
 *
 * Idempotent by S3's own semantics — completing an already-completed upload
 * returns the object rather than failing — which matters because Volume 5
 * Chapter 5.10 §3 requires the status PATCH to be *"a no-op if the chunk is
 * already Complete"*.
 */
export async function finalizeUpload(request: FinalizeRequest): Promise<{ key: string }> {
  const { chunkBucket } = loadConfig();

  const parts: CompletedPart[] = [];
  let marker: string | undefined;
  do {
    const listed = await s3().send(
      new ListPartsCommand({
        Bucket: chunkBucket,
        Key: request.key,
        UploadId: request.uploadId,
        ...(marker === undefined ? {} : { PartNumberMarker: marker }),
      }),
    );
    for (const part of listed.Parts ?? []) {
      parts.push({ ETag: part.ETag, PartNumber: part.PartNumber });
    }
    marker =
      listed.IsTruncated === true && listed.NextPartNumberMarker !== undefined
        ? listed.NextPartNumberMarker
        : undefined;
  } while (marker !== undefined);

  if (parts.length === 0) {
    throw new Error(`No uploaded parts for chunk ${request.chunkId}; nothing to finalise.`);
  }

  parts.sort((a, b) => (a.PartNumber ?? 0) - (b.PartNumber ?? 0));

  await s3().send(
    new CompleteMultipartUploadCommand({
      Bucket: chunkBucket,
      Key: request.key,
      UploadId: request.uploadId,
      MultipartUpload: { Parts: parts },
    }),
  );

  return { key: request.key };
}

const routes: RouteTable = {
  [routeKey('POST', '/v1/sessions/{sessionId}/chunks')]: registerChunk,
};

const router = createRouter('chunks-upload', routes);

export const handler = async (event: unknown): Promise<unknown> => {
  if (isFinalizeRequest(event)) {
    return finalizeUpload(event);
  }
  return router(event as Parameters<typeof router>[0]);
};
