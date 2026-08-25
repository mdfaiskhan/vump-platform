/**
 * `metadata` — Chunk metadata. ADR-015 domain: metadata. Holds no S3 permission
 * at all.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   POST /v1/chunks/{chunkId}/metadata   — Collector. FR-META-11
 *   GET  /v1/chunks/{chunkId}/metadata   — Admin. A-08 / FR-ADM-06
 *
 * ## The identity group is asserted, never trusted
 *
 * Chapter 4.5 §2's document opens with `identity` — `session_id`,
 * `project_id`, `task_id`, `collector_id` — and migration `0004` deliberately
 * stores none of them: *"reachable by joining chunks → sessions → tasks →
 * projects and are deliberately not duplicated here."*
 *
 * So they are neither stored nor believed. Each is compared against the join
 * from `chunk_id` and a mismatch is refused. Chapter 4.8 §1 is categorical —
 * *"No authorization decision is ever trusted from the mobile client"* — and
 * the same reasoning that made `collector_id` a server-derived value in A-099
 * makes these assertions rather than inputs. The join is only possible because
 * migration `0010` granted this role `SELECT` on `sessions`, `tasks` and
 * `projects`; before it, `GET` could not return the shape Chapter 4.5 §5 says
 * it returns.
 */
import type { SqlParameter } from '@aws-sdk/client-rds-data';
import * as v from 'valibot';
import {
  ApiError,
  createRouter,
  execute,
  jsonParam,
  longParam,
  parseBody,
  pathUuid,
  readOptionalString,
  readString,
  requireRole,
  routeKey,
  textParam,
  uuidParam,
  withEnvelope,
  type Row,
  type RouteTable,
} from '@vump/shared';

import { MetadataDocument } from './schema.js';

/** The identity a chunk really has, from the join rather than the body. */
interface ChunkIdentity {
  readonly sessionId: string;
  readonly taskId: string;
  readonly projectId: string;
  readonly collectorId: string;
  readonly orgId: string;
  readonly sequenceIndex: number;
  readonly checksum: string;
  readonly fileSizeBytes: number;
  readonly status: string;
}

/** Resolves a chunk's true identity. `0010` is what makes this join legal. */
async function resolveIdentity(chunkId: string): Promise<ChunkIdentity> {
  const found = await execute(
    `SELECT s.id, t.id, p.id, s.collector_id, p.org_id,
            c.sequence_index, c.checksum_sha256, c.file_size_bytes, c.status
       FROM chunks c
       JOIN sessions s ON s.id = c.session_id
       JOIN tasks t    ON t.id = s.task_id
       JOIN projects p ON p.id = t.project_id
      WHERE c.id = :chunkId`,
    { parameters: [uuidParam('chunkId', chunkId)] },
  );

  const row = found.records?.[0];
  if (row === undefined) {
    throw ApiError.notFound('That chunk');
  }
  return {
    sessionId: readString(row, 0, 'sessions.id'),
    taskId: readString(row, 1, 'tasks.id'),
    projectId: readString(row, 2, 'projects.id'),
    collectorId: readString(row, 3, 'sessions.collector_id'),
    orgId: readString(row, 4, 'projects.org_id'),
    sequenceIndex: row[5]?.longValue ?? -1,
    checksum: readString(row, 6, 'chunks.checksum_sha256'),
    fileSizeBytes: row[7]?.longValue ?? -1,
    status: readString(row, 8, 'chunks.status'),
  };
}

/**
 * FR-META-11 — Chapter 4.5 §3 step 2. Collector only.
 *
 * ## Idempotent, and it cannot be anything else
 *
 * `chunk_metadata`'s primary key is `chunk_id`, and BR-22 forbids rewriting a
 * system-generated field — the `0006` trigger enforces it. So a repeat is
 * `ON CONFLICT DO NOTHING`: there is no correct `DO UPDATE` to write, because
 * every column except `notes_tags` is frozen by design.
 *
 * This matters for the same reason chunk registration is idempotent: Chapter
 * 5.13 §2 grants six automatic attempts, and a pipeline that retries a metadata
 * POST after a dropped response must not fail.
 */
const writeMetadata = withEnvelope('POST /v1/chunks/{chunkId}/metadata', async (event, caller) => {
  requireRole(caller, 'collector');
  const chunkId = pathUuid(event.pathParameters, 'chunkId');

  const parsed = v.safeParse(MetadataDocument, parseBody(event.body));
  if (!parsed.success) {
    const [first] = parsed.issues;
    const path = (first.path ?? []).map((segment) => String(segment.key)).join('.');
    throw ApiError.invalidRequest(`${path === '' ? 'body' : path}: ${first.message}`);
  }
  const document = parsed.output;

  const truth = await resolveIdentity(chunkId);
  if (truth.collectorId !== caller.userId) {
    // Not this Collector's chunk. Absent rather than forbidden — A-186.
    throw ApiError.notFound('That chunk');
  }

  assertMatches(document, chunkId, truth);

  const gps = document.capture_conditions.gps ?? null;
  const authored = document.collector_authored ?? null;

  await execute(
    `INSERT INTO chunk_metadata (
        chunk_id, captured_start_at, captured_end_at,
        resolution, frame_rate, bitrate_kbps, codec, zoom_factor, camera,
        device_model, os_version, app_version, device_id,
        gps_lat, gps_lng, battery_pct, network_type, notes_tags,
        capture_orientation, thermal_state)
     VALUES (
        :chunkId, :startedAt::timestamptz, :endedAt::timestamptz,
        :resolution, :frameRate, :bitrate, :codec, :zoom, :camera,
        :deviceModel, :osVersion, :appVersion, :deviceId,
        :gpsLat, :gpsLng, :batteryPct, :networkType, :notesTags,
        :captureOrientation, :thermalState)
     ON CONFLICT (chunk_id) DO NOTHING`,
    {
      parameters: [
        uuidParam('chunkId', chunkId),
        textParam('startedAt', document.timing.started_at),
        textParam('endedAt', document.timing.ended_at),
        textParam('resolution', document.capture.resolution),
        longParam('frameRate', document.capture.frame_rate),
        longParam('bitrate', document.capture.bitrate_kbps),
        textParam('codec', document.capture.codec),
        numericParam('zoom', document.capture.zoom_factor),
        textParam('camera', document.capture.camera),
        textParam('deviceModel', document.device_context.device_model),
        textParam('osVersion', document.device_context.os_version),
        textParam('appVersion', document.device_context.app_version),
        textParam('deviceId', document.identity.device_id),
        nullableNumeric('gpsLat', gps?.lat),
        nullableNumeric('gpsLng', gps?.lng),
        nullableLong('batteryPct', document.capture_conditions.battery_pct),
        nullableText('networkType', document.capture_conditions.network_type),
        jsonParam('notesTags', authored === null ? undefined : [JSON.stringify(authored)]),
        nullableText('captureOrientation', document.capture.orientation),
        nullableLong('thermalState', document.capture_conditions.thermal_state),
      ],
    },
  );

  return { data: { chunk_id: chunkId }, status: 201 };
});

/**
 * Refuses a document whose identity disagrees with the database.
 *
 * Every one of these is knowable server-side, which is exactly why the client
 * is not believed about them. A mismatch is a client defect or an attempt to
 * attribute a recording to work it did not come from, and neither should be
 * stored quietly — the same class of silent identity mismatch F2 caught on
 * `chunk_id` and `SESSION_ALREADY_REGISTERED` catches on a session.
 */
function assertMatches(document: MetadataDocument, chunkId: string, truth: ChunkIdentity): void {
  const disagreements: string[] = [];
  const check = (field: string, sent: string | number, actual: string | number): void => {
    const same =
      typeof sent === 'string' && typeof actual === 'string'
        ? sent.toLowerCase() === actual.toLowerCase()
        : sent === actual;
    if (!same) {
      disagreements.push(field);
    }
  };

  check('chunk_id', document.chunk_id, chunkId);
  check('identity.session_id', document.identity.session_id, truth.sessionId);
  check('identity.task_id', document.identity.task_id, truth.taskId);
  check('identity.project_id', document.identity.project_id, truth.projectId);
  check('identity.collector_id', document.identity.collector_id, truth.collectorId);
  check('timing.sequence_index', document.timing.sequence_index, truth.sequenceIndex);
  check('integrity.checksum_sha256', document.integrity.checksum_sha256, truth.checksum);
  check('integrity.file_size_bytes', document.integrity.file_size_bytes, truth.fileSizeBytes);

  if (disagreements.length > 0) {
    throw ApiError.invalidRequest(
      `These fields disagree with the registered chunk: ${disagreements.join(', ')}.`,
    );
  }
}

/**
 * A-08 / FR-ADM-06 — Chapter 4.5 §5. Admin only.
 *
 * Chapter 4.8 §4's matrix is explicit that a Collector is denied: *"View/export
 * chunk metadata — Admin allowed (FR-ADM-06), Collector Denied — Collector
 * never reads back metadata, only writes it at capture time."*
 *
 * Returns Chapter 4.5 §2's shape *"plus verified_at and the chunk's current
 * status"*, and Chapter 4.5 §5 adds a rule worth honouring literally: *"the
 * checksum is always returned paired with its verified/mismatch status, never
 * as a bare value"* — Chapter 2.10's colour-not-alone rule applied to data.
 */
const readMetadata = withEnvelope('GET /v1/chunks/{chunkId}/metadata', async (event, caller) => {
  requireRole(caller, 'admin');
  const chunkId = pathUuid(event.pathParameters, 'chunkId');

  const truth = await resolveIdentity(chunkId);
  if (truth.orgId !== caller.orgId) {
    // BR-20. Absent, not forbidden — A-186.
    throw ApiError.notFound('That chunk');
  }

  const found = await execute(
    `SELECT captured_start_at, captured_end_at, resolution, frame_rate, bitrate_kbps,
            codec, zoom_factor, camera, device_model, os_version, app_version, device_id,
            gps_lat, gps_lng, battery_pct, network_type, notes_tags, verified_at
       FROM chunk_metadata WHERE chunk_id = :chunkId`,
    { parameters: [uuidParam('chunkId', chunkId)] },
  );

  const row = found.records?.[0];
  if (row === undefined) {
    throw ApiError.notFound("This chunk's metadata");
  }

  return { data: toDocument(chunkId, row, truth) };
});

/** Rebuilds Chapter 4.5 §2's shape from the flat row plus the join. */
function toDocument(chunkId: string, row: Row, truth: ChunkIdentity): Record<string, unknown> {
  const verifiedAt = readOptionalString(row, 17);
  const startedAt = readString(row, 0, 'chunk_metadata.captured_start_at');
  const endedAt = readString(row, 1, 'chunk_metadata.captured_end_at');

  return {
    chunk_id: chunkId,
    identity: {
      session_id: truth.sessionId,
      project_id: truth.projectId,
      task_id: truth.taskId,
      collector_id: truth.collectorId,
      device_id: readString(row, 11, 'chunk_metadata.device_id'),
    },
    timing: {
      sequence_index: truth.sequenceIndex,
      started_at: startedAt,
      ended_at: endedAt,
      duration_seconds: Math.max(
        0,
        Math.round((Date.parse(endedAt) - Date.parse(startedAt)) / 1000),
      ),
    },
    capture: {
      resolution: readString(row, 2, 'chunk_metadata.resolution'),
      frame_rate: row[3]?.longValue ?? null,
      bitrate_kbps: row[4]?.longValue ?? null,
      codec: readString(row, 5, 'chunk_metadata.codec'),
      zoom_factor: numberOf(row, 6),
      camera: readString(row, 7, 'chunk_metadata.camera'),
    },
    device_context: {
      device_model: readString(row, 8, 'chunk_metadata.device_model'),
      os_version: readString(row, 9, 'chunk_metadata.os_version'),
      app_version: readString(row, 10, 'chunk_metadata.app_version'),
    },
    capture_conditions: {
      gps: gpsOf(row),
      battery_pct: row[14]?.isNull === true ? null : (row[14]?.longValue ?? null),
      network_type: readOptionalString(row, 15),
    },
    integrity: {
      file_size_bytes: truth.fileSizeBytes,
      // Chapter 4.5 §5: never a bare value. The checksum and its verification
      // state are one object, so a reader cannot render one without the other.
      checksum_sha256: truth.checksum,
      verified: verifiedAt !== null,
      verified_at: verifiedAt,
    },
    collector_authored: parseAuthored(readOptionalString(row, 16)),
    status: truth.status,
  };
}

function parseAuthored(raw: string | null): unknown {
  if (raw === null) {
    return null;
  }
  try {
    const parsed: unknown = JSON.parse(raw);
    return Array.isArray(parsed) && typeof parsed[0] === 'string' ? JSON.parse(parsed[0]) : parsed;
  } catch {
    return null;
  }
}

/** Both halves or neither: a latitude without a longitude is not a position. */
function gpsOf(row: Row): { lat: number; lng: number } | null {
  const lat = numberOf(row, 12);
  const lng = numberOf(row, 13);
  return lat === null || lng === null ? null : { lat, lng };
}

function numberOf(row: Row, index: number): number | null {
  const field = row[index];
  if (field === undefined || field.isNull === true) {
    return null;
  }
  if (field.doubleValue !== undefined) {
    return field.doubleValue;
  }
  if (field.longValue !== undefined) {
    return field.longValue;
  }
  return field.stringValue === undefined ? null : Number(field.stringValue);
}

/**
 * A `numeric` column, bound as a string so no precision is lost in transit.
 *
 * **`typeHint: 'DECIMAL'` is load-bearing, not decoration.** Without it the
 * Data API sends a bare `stringValue`, Postgres infers `text`, and the insert
 * fails with `column "zoom_factor" is of type numeric but expression is of type
 * text` (SQLState 42804). That is the house pattern every other non-text
 * parameter already follows — `uuidParam` carries `'UUID'`, `jsonParam` carries
 * `'JSON'` — and these two omitted it.
 *
 * **No test in this project could have caught it.** Every backend test uses
 * `aws-sdk-client-mock`, so the statement is asserted to be *sent* and never to
 * be *accepted*: no INSERT here has ever reached a real Postgres. The device
 * found it, twice in one deploy cycle — `gps_lat`/`gps_lng` were masked by
 * binding typed nulls, which Postgres accepts for any column, so widening the
 * GPS schema is what exposed `zoom_factor` rather than what broke it. A-212.
 */
function numericParam(name: string, value: number): SqlParameter {
  return { name, value: { stringValue: String(value) }, typeHint: 'DECIMAL' };
}

function nullableNumeric(name: string, value: number | null | undefined): SqlParameter {
  return value === null || value === undefined
    ? { name, value: { isNull: true } }
    : numericParam(name, value);
}

function nullableLong(name: string, value: number | null | undefined) {
  return value === null || value === undefined
    ? { name, value: { isNull: true } }
    : longParam(name, value);
}

function nullableText(name: string, value: string | null | undefined) {
  return value === null || value === undefined
    ? { name, value: { isNull: true } }
    : textParam(name, value);
}

const routes: RouteTable = {
  [routeKey('POST', '/v1/chunks/{chunkId}/metadata')]: writeMetadata,
  [routeKey('GET', '/v1/chunks/{chunkId}/metadata')]: readMetadata,
};

export const handler = createRouter('metadata', routes);
