/**
 * `projects` — Projects. ADR-015 domain: projects.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   GET  /v1/projects
 *   POST /v1/projects
 *
 * ## Both routes run as `vump_projects`, which holds four grants
 *
 *   SELECT, INSERT on projects   — this function's own resource
 *   INSERT on audit_log          — Chapter 4.2 §2's Admin trail
 *   SELECT on tasks              — BR-19, added by migration 0010
 *   SELECT on task_assignments   — BR-19, added by migration 0010
 *
 * The last two are why `GET /v1/projects` can serve a Collector at all. Until
 * 0010 this role could read `projects` and nothing else, so Chapter 4.6 §3's
 * *"Collector: only Projects with an assigned Task (BR-19)"* was not merely
 * unimplemented — it was unimplementable, and A-119 recorded the scope
 * difference as *"real and untestable until Mission 7"* without knowing that.
 *
 * There is deliberately no UPDATE and no DELETE: Chapter 4.6 lists no PATCH for
 * a project, and `archived_at` has no route yet, so the grant waits for one.
 */
import {
  createRouter,
  decodeCursor,
  execute,
  optionalString,
  optionalTextParam,
  pageMeta,
  parseBody,
  parsePageRequest,
  readOptionalString,
  readString,
  requireRole,
  requiredString,
  routeKey,
  textParam,
  uuidParam,
  withEnvelope,
  withTransaction,
  type Row,
  type RouteTable,
} from '@vump/shared';

/**
 * One project on the wire — Chapter 4.4 §2's seven columns, snake_case.
 *
 * Chapter 4.6 §6 defers full field types to a generated OpenAPI artifact that
 * does not exist, so Chapter 4.4's Data Dictionary is the authority on shape.
 * This is also exactly the field list the mobile `Project` entity declares —
 * A-097 traced it from the same table — so the two halves agree by construction
 * rather than by coincidence.
 */
interface ProjectDto {
  readonly id: string;
  readonly org_id: string;
  readonly name: string;
  readonly description: string | null;
  readonly created_by: string;
  readonly created_at: string;
  readonly archived_at: string | null;
}

/** The column list every project query selects, in the order the reader expects. */
const COLUMNS = 'p.id, p.org_id, p.name, p.description, p.created_by, p.created_at, p.archived_at';

/** A project plus the sort key `pageMeta` needs. `createdAt` never reaches the wire. */
interface ProjectRow extends ProjectDto {
  readonly createdAt: string;
}

function toProject(row: Row): ProjectRow {
  const createdAt = readString(row, 5, 'projects.created_at');
  return {
    id: readString(row, 0, 'projects.id'),
    org_id: readString(row, 1, 'projects.org_id'),
    name: readString(row, 2, 'projects.name'),
    description: readOptionalString(row, 3),
    created_by: readString(row, 4, 'projects.created_by'),
    created_at: createdAt,
    archived_at: readOptionalString(row, 6),
    createdAt,
  };
}

/** Drops the cursor-only field before the row is returned. */
function render(row: ProjectRow): ProjectDto {
  const { createdAt: _cursorKey, ...dto } = row;
  return dto;
}

/**
 * Chapter 4.6 §3: *"Admin: all Projects in their org. Collector: only Projects
 * with an assigned Task (BR-19)."*
 *
 * One route, two queries, and **the branch is chosen by the role the authorizer
 * resolved from the `users` table** — never by anything the caller sent. That
 * is A-119's whole point: a client-supplied scope on a server-enforced rule is
 * redundant at best, and at worst a value some call site passes wrongly while
 * the backend ignores it.
 *
 * ## Why the Collector query joins rather than filters
 *
 * Chapter 4.2 §3 quotes BR-19's mechanism verbatim — *"every query from a
 * Collector's token is scoped by a WHERE task_assignments.user_id =
 * :current_user clause the API layer always injects, never left optional"*.
 * `removed_at IS NULL` is the other half, from Chapter 4.8 §3: a removed
 * assignment *"immediately excludes that Task from all future queries, even if
 * the mobile app's local cache hasn't refreshed yet"*.
 *
 * `DISTINCT` because a Project with three assigned Tasks is still one Project.
 *
 * `p.org_id = :orgId` is redundant in that branch — a Collector's assignments
 * are necessarily inside their own org — and is kept anyway. It costs nothing,
 * and it means BR-20 is stated in both branches rather than being an emergent
 * property of one of them.
 *
 * ## Archived projects are excluded, and that is a decision, not a reading
 *
 * No chapter says whether an archived Project leaves either list. The mobile
 * `Project` entity carries `archivedAt` and explicitly *"decides nothing about
 * it"*. Excluding matches what archiving is for; the timestamp is still on
 * every row, so a later `?include_archived=` can widen this without a `/v2`
 * under Chapter 4.6 §1's rule. **There is no such parameter today.**
 */
const listProjects = withEnvelope('GET /v1/projects', async (event, caller) => {
  const page = parsePageRequest(event.queryStringParameters);
  const after = page.cursor === undefined ? undefined : decodeCursor(page.cursor);

  // One row more than asked for, so the page knows whether it is the last
  // without a second COUNT query. `pageMeta` discards the extra.
  const limit = page.limit + 1;

  // Row-value comparison rather than an OR chain: `(a, b) < (x, y)` is exactly
  // the lexicographic predicate the ORDER BY sorts on, and Postgres can use the
  // index for it. Written by hand it is easy to get subtly wrong at the tie.
  const keyset =
    after === undefined ? '' : 'AND (p.created_at, p.id) < (:afterAt::timestamptz, :afterId)';

  const shared = [
    uuidParam('orgId', caller.orgId),
    ...(after === undefined
      ? []
      : [textParam('afterAt', after.createdAt), uuidParam('afterId', after.id)]),
  ];

  const result =
    caller.role === 'admin'
      ? await execute(
          `SELECT ${COLUMNS}
             FROM projects p
            WHERE p.org_id = :orgId
              AND p.archived_at IS NULL
              ${keyset}
            ORDER BY p.created_at DESC, p.id DESC
            LIMIT ${String(limit)}`,
          { parameters: shared },
        )
      : await execute(
          // TEMPORARY, migration 0014: `OR t.shared_with_org`. BR-19 scopes
          // a Collector to assigned Tasks, which leaves a Collector with no
          // assignment looking at an empty list and no way out — the only
          // route that creates one is Admin-only. Open items 89/92 supersede
          // this; when they ship, delete the LEFT JOIN's return to an inner
          // JOIN, this clause, and the column.
          //
          // The join became LEFT so an unassigned-but-shared Task still
          // produces a row; `ta.user_id IS NOT NULL` is what the inner join
          // used to say. **`p.org_id = :orgId` is untouched**, so a flag set
          // in one organisation cannot be seen from another.
          `SELECT DISTINCT ${COLUMNS}
             FROM projects p
             JOIN tasks t ON t.project_id = p.id
             LEFT JOIN task_assignments ta
                    ON ta.task_id    = t.id
                   AND ta.user_id    = :userId
                   AND ta.removed_at IS NULL
            WHERE (ta.user_id IS NOT NULL OR t.shared_with_org)
              AND p.org_id = :orgId
              AND p.archived_at IS NULL
              ${keyset}
            ORDER BY p.created_at DESC, p.id DESC
            LIMIT ${String(limit)}`,
          { parameters: [...shared, uuidParam('userId', caller.userId)] },
        );

  const rows = (result.records ?? []).map(toProject);
  const { page: kept, meta } = pageMeta(rows, page.limit);
  return { data: kept.map(render), meta };
});

/**
 * FR-ADM-01 — Chapter 4.6 §3, Admin only.
 *
 * `org_id` and `created_by` come from the authorizer context and are **not
 * accepted from the body**. Chapter 4.8 §1 is categorical: *"No authorization
 * decision is ever trusted from the mobile client."* A body carrying either
 * would be proposing its own tenant, which is the precise shape of BR-20
 * failure the rule exists to prevent — and the mobile
 * `ProjectTaskAdminRepository.createProject` already takes only `name` and
 * `description`, for the same stated reason.
 *
 * The project row and its `audit_log` row commit together. Chapter 4.2 §2 makes
 * that table an *"append-only record of Admin actions"*, and an action whose
 * trail can be lost independently of it is not a record of anything.
 */
const createProject = withEnvelope('POST /v1/projects', async (event, caller) => {
  requireRole(caller, 'admin');

  const body = parseBody(event.body);
  const name = requiredString(body, 'name', 200);
  const description = optionalString(body, 'description', 2000);

  const created = await withTransaction(async (run) => {
    const inserted = await run(
      `INSERT INTO projects (org_id, name, description, created_by)
            VALUES (:orgId, :name, :description, :createdBy)
         RETURNING id, org_id, name, description, created_by, created_at, archived_at`,
      {
        parameters: [
          uuidParam('orgId', caller.orgId),
          textParam('name', name),
          optionalTextParam('description', description),
          uuidParam('createdBy', caller.userId),
        ],
      },
    );

    const row = inserted.records?.[0];
    if (row === undefined) {
      // RETURNING on a successful INSERT always yields a row; no row means the
      // statement and the schema disagree, which is not a client error.
      throw new Error('INSERT INTO projects returned no row.');
    }
    const project = toProject(row);

    await run(
      `INSERT INTO audit_log (actor_id, action, target_table, target_id)
            VALUES (:actorId, 'project.create', 'projects', :targetId)`,
      { parameters: [uuidParam('actorId', caller.userId), uuidParam('targetId', project.id)] },
    );

    return project;
  });

  return { data: render(created), status: 201 };
});

const routes: RouteTable = {
  [routeKey('GET', '/v1/projects')]: listProjects,
  [routeKey('POST', '/v1/projects')]: createProject,
};

export const handler = createRouter('projects', routes);
