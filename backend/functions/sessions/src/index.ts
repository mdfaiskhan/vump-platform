/**
 * `sessions` — Recording sessions. ADR-015 domain: sessions.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   POST /v1/tasks/{taskId}/sessions   — Collector. Starts a recording session
 *   GET  /v1/tasks/{taskId}/sessions   — Admin. A-07 / FR-ADM-05
 *
 * ## What this function may do, and the two things it may not
 *
 *   SELECT, INSERT on sessions
 *   SELECT on task_assignments   — BR-19
 *   SELECT on tasks, projects    — BR-20, added by migration 0010
 *   SELECT on chunks             — A-07's chunk status, added by 0010
 *
 * **No UPDATE on `sessions`**, which is not incidental: it is why the
 * idempotent registration below is `ON CONFLICT DO NOTHING` plus a re-read
 * rather than the `DO UPDATE` shape A-181 uses for `task_assignments`.
 * PostgreSQL requires INSERT *and* UPDATE for `ON CONFLICT DO UPDATE`, so that
 * form would fail with `42501` against this role. `provisionCaller` already
 * solved the same problem the same way for `users`.
 *
 * **No INSERT on `audit_log`**, and the chapter agrees with the grant: Chapter
 * 4.2 §2 scopes that table to *"Admin actions on Projects/Tasks/Assignments"*,
 * and a Collector starting a session is none of those. So unlike every write in
 * Batch 1, `POST` here needs no transaction — there is no second row that has
 * to commit with the first.
 *
 * ## Nothing uploads after this
 *
 * This closes the **backend** half of `SessionRegistrar` (open item 36's first
 * blocker). The port itself is still unimplemented in `mobile/lib` (A-100), and
 * chunk registration, status and metadata are Batch 2b. No byte moves yet.
 */
import {
  ApiError,
  createRouter,
  decodeCursor,
  execute,
  optionalPastInstant,
  optionalTextParam,
  pageMeta,
  parseBody,
  parsePageRequest,
  pathUuid,
  readOptionalString,
  readString,
  requireRole,
  requiredString,
  routeKey,
  textParam,
  uuidParam,
  withEnvelope,
  type Caller,
  type Row,
  type RouteTable,
} from '@vump/shared';

/** A uuid in any version, lower- or upper-case. */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** One session on the wire — Chapter 4.4 §5's columns plus F5's, snake_case. */
interface SessionDto {
  readonly id: string;
  readonly task_id: string;
  readonly collector_id: string;
  readonly client_session_id: string;
  readonly started_at: string;
  readonly status: string;
  readonly notes: string | null;
}

const COLUMNS =
  's.id, s.task_id, s.collector_id, s.client_session_id, s.started_at, s.status, s.notes';

/** A session plus the sort key `pageMeta` needs. `createdAt` never reaches the wire. */
interface SessionRow extends SessionDto {
  readonly createdAt: string;
}

/**
 * Reads a session row.
 *
 * `createdAt` carries `started_at`, because that is this table's sort key —
 * `sessions` has no `created_at`. The name is `cursor.ts`'s internal label for
 * "the timestamp half of the sort key" and never appears on the wire, so it is
 * left alone rather than churning Batch 1's shipped type for a rename.
 */
function toSession(row: Row): SessionRow {
  const startedAt = readString(row, 4, 'sessions.started_at');
  return {
    id: readString(row, 0, 'sessions.id'),
    task_id: readString(row, 1, 'sessions.task_id'),
    collector_id: readString(row, 2, 'sessions.collector_id'),
    client_session_id: readString(row, 3, 'sessions.client_session_id'),
    started_at: startedAt,
    status: readString(row, 5, 'sessions.status'),
    notes: readOptionalString(row, 6),
    createdAt: startedAt,
  };
}

function render(row: SessionRow): SessionDto {
  const { createdAt: _cursorKey, ...dto } = row;
  return dto;
}

/**
 * BR-19 — the Collector must hold a live assignment to this Task.
 *
 * Chapter 4.2 §3 quotes the mechanism verbatim: *"every query from a
 * Collector's token is scoped by a WHERE task_assignments.user_id =
 * :current_user clause the API layer always injects, never left optional"*, and
 * Chapter 4.8 §3 adds that a removed assignment *"immediately excludes that
 * Task from all future queries"*.
 *
 * Joined through `tasks` and `projects` for the org as well. A Collector's
 * assignment is necessarily inside their own org, so that clause is redundant —
 * and it is the same defence-in-depth the `projects` list applies, for the same
 * reason: BR-20 should be stated wherever it holds, not inferred.
 *
 * 404 rather than 403 — A-186. An unassigned Task must not be distinguishable
 * from one that does not exist.
 */
async function assertAssigned(caller: Caller, taskId: string): Promise<void> {
  const found = await execute(
    `SELECT 1
       FROM task_assignments ta
       JOIN tasks t    ON t.id = ta.task_id
       JOIN projects p ON p.id = t.project_id
      WHERE ta.task_id = :taskId
        AND ta.user_id = :userId
        AND ta.removed_at IS NULL
        AND p.org_id = :orgId
      LIMIT 1`,
    {
      parameters: [
        uuidParam('taskId', taskId),
        uuidParam('userId', caller.userId),
        uuidParam('orgId', caller.orgId),
      ],
    },
  );

  if ((found.records ?? []).length === 0) {
    throw ApiError.notFound('That task');
  }
}

/**
 * Chapter 4.6 §4 — *"Starts a new recording session."* Collector only.
 *
 * ## Idempotent, because the port that will call it says so
 *
 * `SessionRegistrar` describes itself as *"idempotent by contract"* and gives
 * the reason: *"a chunk pipeline that runs once per chunk will ask for the same
 * session's id many times — an implementation that created a session per call
 * would fragment one recording across many backend sessions."*
 *
 * F5 gives it something to be idempotent *on*: `client_session_id`, the UUID
 * Chapter 5.3 already mints on the device at session start, unique per
 * collector by `sessions_client_session_id_key`.
 *
 * **Scoped to the collector, not global.** Chapter 5.14 §3 argues the id is
 * globally unique by construction, which would be sound if every client were
 * honest. It is a scope question rather than a uniqueness one: with a global
 * constraint, a caller replaying someone else's `client_session_id` would have
 * the conflict resolve to *their* row and be handed its backend id.
 *
 * ## Re-presenting an id under a different Task is refused
 *
 * Returning the original session would put every subsequent chunk under a Task
 * the caller did not ask for; honouring the new one would move a recording
 * between Tasks mid-flight. Neither is a thing to do quietly, so it is a named
 * `SESSION_ALREADY_REGISTERED`. This is F2's `chunk_id` echo check one level up
 * — the same class of silent identity mismatch, caught for the same reason.
 */
const startSession = withEnvelope('POST /v1/tasks/{taskId}/sessions', async (event, caller) => {
  requireRole(caller, 'collector');
  const taskId = pathUuid(event.pathParameters, 'taskId');

  const body = parseBody(event.body);
  const clientSessionId = requiredString(body, 'client_session_id', 64);
  if (!UUID.test(clientSessionId)) {
    throw new ApiError('REQUEST_MALFORMED_ID', 'client_session_id must be a uuid.', 400);
  }
  // F15. Absent means "use the server clock", which is what the column already
  // defaults to; present means the device is reporting when capture actually
  // began, which may be hours before this call on a deferred upload.
  const startedAt = optionalPastInstant(body, 'started_at');

  await assertAssigned(caller, taskId);

  const inserted = await execute(
    `INSERT INTO sessions (task_id, collector_id, client_session_id, started_at)
          VALUES (:taskId, :collectorId, :clientSessionId,
                  COALESCE(:startedAt::timestamptz, now()))
     ON CONFLICT (collector_id, client_session_id) DO NOTHING
       RETURNING id, task_id, collector_id, client_session_id, started_at, status, notes`,
    {
      parameters: [
        uuidParam('taskId', taskId),
        uuidParam('collectorId', caller.userId),
        uuidParam('clientSessionId', clientSessionId),
        optionalTextParam('startedAt', startedAt),
      ],
    },
  );

  const fresh = inserted.records?.[0];
  if (fresh !== undefined) {
    return { data: render(toSession(fresh)), status: 201 };
  }

  // `DO NOTHING` returns no row on conflict, so the session already existed.
  // Re-read it — the same shape `provisionCaller` uses, and the re-read is what
  // makes two concurrent registrations converge on one row instead of one of
  // them failing on the unique constraint.
  const existing = await execute(
    `SELECT ${COLUMNS}
       FROM sessions s
      WHERE s.collector_id = :collectorId
        AND s.client_session_id = :clientSessionId`,
    {
      parameters: [
        uuidParam('collectorId', caller.userId),
        uuidParam('clientSessionId', clientSessionId),
      ],
    },
  );

  const row = existing.records?.[0];
  if (row === undefined) {
    // The insert conflicted, so a row exists. Its absence a moment later means
    // the statement and the constraint disagree, which is not a client error.
    throw new Error('ON CONFLICT fired but no existing session was found.');
  }

  const session = toSession(row);
  if (session.task_id !== taskId) {
    throw ApiError.sessionAlreadyRegistered();
  }

  // 200 rather than 201: nothing was created. The body is identical, so a
  // client that ignores the status still behaves correctly.
  return { data: render(session), status: 200 };
});

/**
 * A-07 / FR-ADM-05 — *"view Session and chunk status for every Task under
 * Projects they manage."* Admin only.
 *
 * Chapter 4.8 §4's matrix is explicit that a Collector is denied here: *"View
 * Session/Chunk status across org — Admin allowed (FR-ADM-05), Collector
 * Denied."*
 *
 * ## The chunk half is counts, not records
 *
 * FR-ADM-05 asks for session **and chunk** status, so sessions alone would not
 * satisfy it. Volume 2 names A-07 in one line — *"Live status across all
 * Collectors for a given Project/Task"* — and carries no field-level layout, so
 * the shape is chosen here rather than transcribed.
 *
 * Counts grouped by `chunks.status`, per session. A flat list of chunk records
 * would do two things wrong: it duplicates A-08 / FR-ADM-06, which owns *"the
 * full metadata record for any chunk or session"*, and it is unbounded against
 * ADR-044's 1 MiB response ceiling — a single 10-minute session is 38 chunks at
 * F3's part size, and a Task may hold many sessions.
 *
 * The aggregate is a second statement rather than a join, because a join would
 * multiply session rows by chunk rows and then need de-duplicating, and because
 * the first query is already paginated — the counts only have to cover the page
 * that was actually returned.
 */
const listSessions = withEnvelope('GET /v1/tasks/{taskId}/sessions', async (event, caller) => {
  requireRole(caller, 'admin');
  const taskId = pathUuid(event.pathParameters, 'taskId');

  const page = parsePageRequest(event.queryStringParameters);
  const after = page.cursor === undefined ? undefined : decodeCursor(page.cursor);
  const limit = page.limit + 1;

  const keyset =
    after === undefined ? '' : 'AND (s.started_at, s.id) < (:afterAt::timestamptz, :afterId)';

  const found = await execute(
    `SELECT ${COLUMNS}
       FROM sessions s
       JOIN tasks t    ON t.id = s.task_id
       JOIN projects p ON p.id = t.project_id
      WHERE s.task_id = :taskId
        AND p.org_id = :orgId
        ${keyset}
      ORDER BY s.started_at DESC, s.id DESC
      LIMIT ${String(limit)}`,
    {
      parameters: [
        uuidParam('taskId', taskId),
        uuidParam('orgId', caller.orgId),
        ...(after === undefined
          ? []
          : [textParam('afterAt', after.createdAt), uuidParam('afterId', after.id)]),
      ],
    },
  );

  const rows = (found.records ?? []).map(toSession);
  const { page: kept, meta } = pageMeta(rows, page.limit);

  // An empty page is not a missing Task. Distinguishing them would need a
  // separate existence query whose only product is a 404, and Chapter 4.8 §3's
  // scoping already means an out-of-org Task returns nothing here — so an empty
  // list is the honest answer to both, and the same answer A-186 would give.
  if (kept.length === 0) {
    return { data: [], meta };
  }

  const counts = await chunkStatusCounts(kept.map((s) => s.id));
  return {
    data: kept.map((session) => ({
      ...render(session),
      chunk_status: counts.get(session.id) ?? {},
    })),
    meta,
  };
});

/**
 * Counts chunks by status for each session on the page.
 *
 * `= ANY(...)` over a parameter list rather than an interpolated `IN (...)`:
 * the ids come from the database rather than from the caller, so this is not
 * about injection — it is that a query whose *text* changes with the page size
 * cannot be plan-cached, and Chapter 4.6 §1's limit is caller-controlled.
 *
 * A session with no chunks yet is absent from the result and renders as `{}`,
 * which is a truthful "none" rather than a fabricated set of zeroes.
 */
async function chunkStatusCounts(
  sessionIds: readonly string[],
): Promise<Map<string, Record<string, number>>> {
  const placeholders = sessionIds.map((_id, index) => `:s${String(index)}`).join(', ');

  const result = await execute(
    `SELECT c.session_id, c.status, count(*) AS n
       FROM chunks c
      WHERE c.session_id = ANY (ARRAY[${placeholders}]::uuid[])
      GROUP BY c.session_id, c.status`,
    {
      parameters: sessionIds.map((id, index) => uuidParam(`s${String(index)}`, id)),
    },
  );

  const counts = new Map<string, Record<string, number>>();
  for (const row of result.records ?? []) {
    const sessionId = readString(row, 0, 'chunks.session_id');
    const status = readString(row, 1, 'chunks.status');
    const n = row[2]?.longValue ?? 0;
    const existing = counts.get(sessionId) ?? {};
    counts.set(sessionId, { ...existing, [status]: n });
  }
  return counts;
}

const routes: RouteTable = {
  [routeKey('POST', '/v1/tasks/{taskId}/sessions')]: startSession,
  [routeKey('GET', '/v1/tasks/{taskId}/sessions')]: listSessions,
};

export const handler = createRouter('sessions', routes);
