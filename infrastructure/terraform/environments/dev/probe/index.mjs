/**
 * `chunk-hash-probe` — a throwaway measurement function, not part of the API.
 *
 * ## The one question it exists to answer
 *
 * Volume 4 Chapter 4.5 §3 makes the backend verify a chunk's
 * `checksum_sha256` "against the actual uploaded S3 object" before setting
 * `verified_at` and allowing `chunks.status → 'complete'` (FR-META-12, BR-21).
 *
 * `GetObjectAttributes` cannot serve that: S3 only stores a SHA-256 if one was
 * requested at upload time, and for a multipart upload the stored value is a
 * composite-of-parts, not the whole-object digest the device computed. So the
 * verification has to hash the bytes.
 *
 * Hashing the bytes is O(1) in memory — a `crypto` hash holds 32 bytes of state
 * and the stream is never buffered — so **memory is not the question.** The
 * question is time, because `PATCH /v1/chunks/{chunkId}/status` runs behind API
 * Gateway, whose REST integration timeout is 29 seconds.
 *
 * Mission 3.8.1 measured a real full chunk at **633,232,477 bytes** on CPH2707.
 * 29 seconds for 633.2 MB is 21.8 MB/s. Whether Lambda→S3 in-region sustains
 * that, and how much of it is bought by raising memory, is the number this
 * function produces and nothing in the repository currently knows.
 *
 * ## Why this is not a test in `backend/`
 *
 * It measures the network between two AWS services. Nothing on a developer's
 * machine or in `vitest` can observe that, and a figure quoted from a blog post
 * is exactly the "plausible value, minted once, then reused forever" failure
 * A-071 caught on the S3 key.
 *
 * ## Delete this after the measurement
 *
 * Two functions, one role, one prefix. `terraform destroy -target` on the
 * module, or delete the file. It has no callers and nothing depends on it.
 */
import { createHash, randomBytes } from 'node:crypto';
import {
  S3Client,
  GetObjectCommand,
  HeadObjectCommand,
  CreateMultipartUploadCommand,
  UploadPartCommand,
  CompleteMultipartUploadCommand,
  ListPartsCommand,
} from '@aws-sdk/client-s3';

const BUCKET = process.env.CHUNK_BUCKET;

/** Where every probe object lives, so cleanup is one prefix. */
const KEY = '_probe/hash-throughput-fixture.bin';

/**
 * 633,232,477 bytes — Mission 3.8.1's real chunk, to the byte.
 *
 * Not rounded to 600 MB. The measurement is only worth having if it is taken
 * against the size the system will actually meet, and the difference between
 * 600 MB and 633.2 MB is 5.5% of the answer.
 */
const FIXTURE_BYTES = 633_232_477;

/** 16 MiB — the part size approved for F3, so the fixture is shaped like a real upload. */
const PART_BYTES = 16 * 1024 * 1024;

const s3 = new S3Client({});

/**
 * Creates the fixture object if it is absent.
 *
 * Written by the probe rather than uploaded from a laptop because nothing has
 * ever put a byte in this bucket (open item 36) and a 633 MB upload over a
 * domestic connection is not a prerequisite worth having.
 *
 * The body is `randomBytes` rather than zeroes. Zeroes would be compressible
 * and identical part to part, and while S3 does not compress, a fixture whose
 * content is degenerate invites the question at exactly the moment the number
 * matters.
 */
async function seed() {
  try {
    const head = await s3.send(new HeadObjectCommand({ Bucket: BUCKET, Key: KEY }));
    if (head.ContentLength === FIXTURE_BYTES) {
      return { seeded: false, reason: 'already present at the exact size', bytes: head.ContentLength };
    }
  } catch (thrown) {
    // **403 is treated as "absent", and that is not sloppiness.**
    //
    // This role holds `s3:GetObject` on `_probe/*` and deliberately no
    // `s3:ListBucket` on the bucket. AWS documents the consequence: for an
    // object that does not exist, S3 returns 404 only if the caller has
    // `s3:ListBucket`, and **403 if it does not** — on purpose, so that a
    // caller who cannot list the bucket cannot learn which keys exist by
    // probing for them.
    //
    // So on the first ever run — an empty bucket, no fixture yet — a HEAD of
    // the fixture key returns 403, and "forbidden" and "absent" are genuinely
    // indistinguishable from inside this function. Rethrowing treated the
    // normal first run as a fatal error, which is what it did.
    //
    // Granting `s3:ListBucket` would also fix it and is the wrong trade: the
    // `s3:prefix` condition that would keep it narrow is not evaluated for
    // HeadObject (there is no prefix parameter on the request), so the grant
    // would have to be bucket-wide listing on the evidentiary bucket — to
    // improve an error message.
    //
    // Proceeding is safe because the write path is the real permission test:
    // `CreateMultipartUpload` is a POST, so a genuine denial comes back with a
    // parseable `<Error><Code>` body rather than the bodiless HEAD response
    // that produced `UnknownError` here.
    const status = thrown?.$metadata?.httpStatusCode;
    const absent = thrown?.name === 'NotFound' || status === 404 || status === 403;
    if (!absent) {
      throw thrown;
    }
  }

  const created = await s3.send(new CreateMultipartUploadCommand({ Bucket: BUCKET, Key: KEY }));
  const parts = [];
  let written = 0;

  for (let partNumber = 1; written < FIXTURE_BYTES; partNumber++) {
    const size = Math.min(PART_BYTES, FIXTURE_BYTES - written);
    const uploaded = await s3.send(
      new UploadPartCommand({
        Bucket: BUCKET,
        Key: KEY,
        UploadId: created.UploadId,
        PartNumber: partNumber,
        Body: randomBytes(size),
      }),
    );
    parts.push({ ETag: uploaded.ETag, PartNumber: partNumber });
    written += size;
  }

  await s3.send(
    new CompleteMultipartUploadCommand({
      Bucket: BUCKET,
      Key: KEY,
      UploadId: created.UploadId,
      MultipartUpload: { Parts: parts },
    }),
  );

  return { seeded: true, bytes: written, parts: parts.length };
}

/**
 * Times `CompleteMultipartUpload` in isolation — Mission 7.3 Batch 2b.
 *
 * ## The one number this exists for
 *
 * Fork 1 option B puts MPU completion and the SHA-256 hash inside a single
 * `PATCH /v1/chunks/{chunkId}/status` request, behind API Gateway's 29-second
 * ceiling. F4 measured the hash at **7780ms** for a real chunk. It did not
 * measure assembly, and Part 21 corrected an earlier claim that option B
 * separated the two budgets — it does not, because one client request waits for
 * both however many Lambdas are involved.
 *
 * So the remaining unknown is: how long does S3 take to assemble a 633 MB,
 * 38-part object when `CompleteMultipartUpload` is called? That is what the
 * `completeMs` figure below reports, and the design proceeds or stops on it.
 *
 * ## Parts are uploaded for real rather than copied
 *
 * `UploadPartCopy` from the existing fixture would be far quicker and is the
 * obvious shortcut. It is not taken: the production path assembles parts that
 * arrived as ordinary `UploadPart` writes, and a measurement of a differently
 * constructed upload would be a plausible number for a slightly different
 * question. `seed` already proves 633 MB in 38 parts fits inside the probe's
 * 900-second timeout.
 *
 * ## It leaves an object behind, deliberately
 *
 * No role in this account holds `s3:DeleteObject` — the permissions boundary
 * excludes it entirely, because ADR-013 gates deletion of raw footage behind
 * legal-hold enforcement. So this writes to its own key and that object
 * persists. The whole `_probe/` prefix needs clearing by hand when the probe is
 * deleted, and this adds one more object to it rather than a new problem.
 */
async function timeComplete() {
  const key = `${KEY}.complete-timing`;
  const ms = (from, to) => Number(to - from) / 1_000_000;

  const createStarted = process.hrtime.bigint();
  const created = await s3.send(new CreateMultipartUploadCommand({ Bucket: BUCKET, Key: key }));
  const createMs = ms(createStarted, process.hrtime.bigint());

  const uploadStarted = process.hrtime.bigint();
  const parts = [];
  let written = 0;
  for (let partNumber = 1; written < FIXTURE_BYTES; partNumber++) {
    const size = Math.min(PART_BYTES, FIXTURE_BYTES - written);
    const uploaded = await s3.send(
      new UploadPartCommand({
        Bucket: BUCKET,
        Key: key,
        UploadId: created.UploadId,
        PartNumber: partNumber,
        Body: randomBytes(size),
      }),
    );
    parts.push({ ETag: uploaded.ETag, PartNumber: partNumber });
    written += size;
  }
  const uploadMs = ms(uploadStarted, process.hrtime.bigint());

  // ListParts, because Fork 1 option B has the server discover the parts rather
  // than the client reporting them. Timed separately: it is a second call on
  // the same critical path, and "small" is an assumption until it is a number.
  const listStarted = process.hrtime.bigint();
  const listed = await s3.send(
    new ListPartsCommand({ Bucket: BUCKET, Key: key, UploadId: created.UploadId }),
  );
  const listMs = ms(listStarted, process.hrtime.bigint());

  // **The measurement.** Everything above is setup.
  const completeStarted = process.hrtime.bigint();
  await s3.send(
    new CompleteMultipartUploadCommand({
      Bucket: BUCKET,
      Key: key,
      UploadId: created.UploadId,
      MultipartUpload: {
        Parts: (listed.Parts ?? [])
          .map((p) => ({ ETag: p.ETag, PartNumber: p.PartNumber }))
          .sort((a, b) => (a.PartNumber ?? 0) - (b.PartNumber ?? 0)),
      },
    }),
  );
  const completeMs = ms(completeStarted, process.hrtime.bigint());

  // 29s is API Gateway's REST integration ceiling; 7780ms is F4's measured hash
  // at this memory tier. What is left is the margin the design has to live in.
  const HASH_MS = 7780;
  const budgetMs = Math.round(completeMs + listMs + HASH_MS);

  return {
    memoryMb: Number(process.env.AWS_LAMBDA_FUNCTION_MEMORY_SIZE),
    bytes: written,
    parts: parts.length,
    partsListedByServer: (listed.Parts ?? []).length,
    listTruncated: listed.IsTruncated === true,
    createMs: Math.round(createMs),
    uploadMs: Math.round(uploadMs),
    listMs: Math.round(listMs),
    completeMs: Math.round(completeMs),
    hashMsFromF4: HASH_MS,
    syncPatchBudgetMs: budgetMs,
    marginToApiGateway29sMs: 29_000 - budgetMs,
  };
}

/**
 * Streams the fixture through SHA-256 and reports what it cost.
 *
 * `for await` over the SDK v3 body rather than `pipeline`, so the byte count is
 * observed directly instead of inferred from `ContentLength`. A measurement
 * that trusts the header it was trying to verify is not a measurement.
 *
 * `hashOnlyMs` isolates the CPU half by re-hashing one buffered part. SHA-256
 * on modern x86 runs far faster than any network, and the point of separating
 * them is to be able to say so with a number rather than as an assumption.
 */
async function measure() {
  const started = process.hrtime.bigint();

  const object = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: KEY }));
  const firstByteAt = process.hrtime.bigint();

  const hash = createHash('sha256');
  let bytes = 0;
  let sample;

  for await (const chunk of object.Body) {
    hash.update(chunk);
    bytes += chunk.length;
    sample ??= Buffer.from(chunk);
  }

  const digest = hash.digest('hex');
  const finished = process.hrtime.bigint();

  const ms = (from, to) => Number(to - from) / 1_000_000;
  const totalMs = ms(started, finished);

  const cpuStarted = process.hrtime.bigint();
  const rounds = sample === undefined ? 0 : Math.ceil(bytes / sample.length);
  for (let i = 0; i < rounds; i++) {
    createHash('sha256').update(sample).digest();
  }
  const hashOnlyMs = ms(cpuStarted, process.hrtime.bigint());

  return {
    memoryMb: Number(process.env.AWS_LAMBDA_FUNCTION_MEMORY_SIZE),
    bytes,
    digest,
    ttfbMs: Math.round(ms(started, firstByteAt)),
    totalMs: Math.round(totalMs),
    throughputMbPerSec: Number((bytes / 1_000_000 / (totalMs / 1000)).toFixed(2)),
    hashOnlyMs: Math.round(hashOnlyMs),
    // The whole point. 29s is API Gateway's REST integration ceiling; PATCH
    // /v1/chunks/{chunkId}/status has to finish inside it or move off the
    // synchronous path entirely (Ch 4.10 §2 step 3's S3-event alternative).
    fitsApiGateway29s: totalMs < 29_000,
    marginToApiGatewayMs: Math.round(29_000 - totalMs),
  };
}

/**
 * Rebuilds an AWS SDK error into something the invoke response can carry.
 *
 * The v3 client throws errors whose useful content lives on `$metadata` and on
 * non-enumerable properties, and Lambda serialises a thrown error by reading
 * `name`/`message` alone. An S3 `AccessDenied` therefore arrives at the caller
 * as `{"errorType":"Unknown","errorMessage":"UnknownError"}` with a stack full
 * of `S3RestXmlProtocol.handleError` frames and nothing that says what was
 * denied — which is exactly what happened on the first seed attempt and cost a
 * round trip.
 *
 * Flattening it here is the difference between "an S3 call failed" and "this
 * principal cannot PutObject on that key".
 */
function describeAwsError(thrown) {
  const meta = thrown?.$metadata ?? {};
  return [
    `name=${thrown?.name ?? 'unknown'}`,
    `code=${thrown?.Code ?? thrown?.code ?? 'none'}`,
    `http=${meta.httpStatusCode ?? 'none'}`,
    `requestId=${meta.requestId ?? 'none'}`,
    `extendedRequestId=${meta.extendedRequestId ?? 'none'}`,
    `message=${thrown?.message ?? String(thrown)}`,
  ].join(' | ');
}

export const handler = async (event) => {
  if (BUCKET === undefined || BUCKET === '') {
    throw new Error('CHUNK_BUCKET is not set.');
  }
  const mode = event?.mode ?? 'measure';
  if (mode !== 'seed' && mode !== 'measure' && mode !== 'time-complete') {
    throw new Error(`Unknown mode "${mode}". Use "seed", "measure" or "time-complete".`);
  }

  try {
    if (mode === 'seed') return await seed();
    if (mode === 'time-complete') return await timeComplete();
    return await measure();
  } catch (thrown) {
    // Rethrown rather than returned, so a failure is still a FunctionError and
    // cannot be mistaken for a measurement. Only the *description* improves.
    const described = new Error(
      `${mode} failed against s3://${BUCKET}/${KEY} — ${describeAwsError(thrown)}`,
    );
    described.name = thrown?.name ?? 'ProbeError';
    throw described;
  }
};
