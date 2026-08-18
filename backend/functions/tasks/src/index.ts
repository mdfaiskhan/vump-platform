/**
 * `tasks` — Tasks and their assignments. ADR-015 domain: tasks.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   GET    /v1/projects/{projectId}/tasks
 *   POST   /v1/projects/{projectId}/tasks
 *   PATCH  /v1/tasks/{taskId}
 *   POST   /v1/tasks/{taskId}/assignments
 *   DELETE /v1/tasks/{taskId}/assignments/{userId}
 *
 * ## The grants this role holds, and the one that is an exception
 *
 *   SELECT, INSERT, UPDATE on tasks
 *   SELECT, INSERT, UPDATE on task_assignments
 *   SELECT on projects            — the org check every route below performs
 *   INSERT on audit_log           — Chapter 4.2 §2's Admin trail
 *   SELECT (id, org_id, role) on users  — migration 0010, F6
 *
 * The last is **the single documented exception to Volume 8 Chapter 8.4 §1's
 * "No role but auth-verify touches users"**, it is column-level, and
 * `firebase_uid` and `email` are deliberately not among the three. Without it,
 * `POST /v1/tasks/{taskId}/assignments` could not tell a Collector from an
 * Admin, could not tell a real user from a guessed uuid, and — the reason it
 * was granted — could not stop an Admin assigning a Collector belonging to
 * **another organisation**, which is a live BR-20 hole rather than a cosmetic
 * gap.
 *
 * ## No DELETE anywhere, on purpose
 *
 * FR-ADM-04 keeps a removed assignment *"for audit rather than
 * hard-deleted"*, so `DELETE /v1/tasks/{taskId}/assignments/{userId}` is an
 * UPDATE of `removed_at`. No role in this backend holds SQL DELETE on anything.
 */
import {
  ApiError,
  createRouter,
  decodeCursor,
  execute,
  jsonParam,
  optionalString,
  optionalStringArray,
  pageMeta,
  parseBody,
  parsePageRequest,
  pathUuid,
  readString,
  readStringArray,
  requireRole,
  requiredString,
  routeKey,
  textParam,
  uuidParam,
  withEnvelope,
  withTransaction,
  type Caller,
  type Row,
  type RouteTable,
  type TransactionalExecute,
} from '@vump/shared';

/** One task on the wire — Chapter 4.4 §3's six columns, snake_case. */
interface TaskDto {
  readonly id: string;
  readonly project_id: string;
  readonly title: string;
  readonly instructions: string;
  readonly reference_examples: readonly string[];
  readonly created_at: string;
}

const COLUMNS = 't.id, t.project_id, t.title, t.instructions, t.reference_examples, t.created_at';

interface TaskRow extends TaskDto {
  readonly createdAt: string;
}

function toTask(row: Row): TaskRow {
  const createdAt = readString(row, 5, 'tasks.created_at');
  return {
    id: readString(row, 0, 'tasks.id'),
    project_id: readString(row, 1, 'tasks.project_id'),
    title: readString(row, 2, 'tasks.title'),
    instructions: readString(row, 3, 'tasks.instructions'),
    reference_examples: readStringArray(row, 4),
    created_at: createdAt,
    createdAt,
  };
}

function render(row: TaskRow): TaskDto {
  const { createdAt: _cursorKey, ...dto } = row;
  return dto;
}

/**
 * Confirms the caller may see [projectId], and returns nothing if so.
 *
 * **A project in another org is reported as absent, not as forbidden** — F13.
 * Chapter 4.8 §3 says an Admin *"can never read or write another org's data,
 * regardless of guessed IDs"*, and a 403 answers the question the guess was
 * asking: it confirms the id exists. 404 does not, and costs the caller
 * nothing they are entitled to.
 *
 * A Collector additionally has to hold a live assignment to a Task inside it —
 * BR-19, the same join `GET /v1/projects` uses.
 */
async function assertProjectVisible(
  caller: Caller,
  projectId: string,
  run: TransactionalExecute | typeof execute = execute,
): Promise<void> {
  const found =
    caller.role === 'admin'
      ? await run('SELECT 1 FROM projects WHERE id = :projectId AND org_id = :orgId', {
          parameters: [uuidParam('projectId', projectId), uuidParam('orgId', caller.orgId)],
        })
      : await run(
          `SELECT 1
             FROM projects p
             JOIN tasks t             ON t.project_id = p.id
             JOIN task_assignments ta ON ta.task_id   = t.id
            WHERE p.id = :projectId
              AND p.org_id = :orgId
              AND ta.user_id = :userId
              AND ta.removed_at IS NULL
            LIMIT 1`,
          {
            parameters: [
              uuidParam('projectId', projectId),
              uuidParam('orgId', caller.orgId),
              uuidParam('userId', caller.userId),
            ],
          },
        );

  if ((found.records ?? []).length === 0) {
    throw ApiError.notFound('That project');
  }
}

/**
 * Confirms an Admin caller may act on [taskId], via its project's org.
 *
 * Admin-only by construction: every route that uses it calls `requireRole`
 * first. Same 404-not-403 rule as above.
 */
async function assertTaskInOrg(
  caller: Caller,
  taskId: string,
  run: TransactionalExecute | typeof execute = execute,
): Promise<void> {
  const found = await run(
    `SELECT 1
       FROM tasks t
       JOIN projects p ON p.id = t.project_id
      WHERE t.id = :taskId AND p.org_id = :orgId`,
    { parameters: [uuidParam('taskId', taskId), uuidParam('orgId', caller.orgId)] },
  );

  if ((found.records ?? []).length === 0) {
    throw ApiError.notFound('That task');
  }
}

/** Chapter 4.6 §3 — *"the Constitution's own naming example, verbatim"*. Both roles. */
const listTasks = withEnvelope('GET /v1/projects/{projectId}/tasks', async (event, caller) => {
  const projectId = pathUuid(event.pathParameters, 'projectId');
  await assertProjectVisible(caller, projectId);

  const page = parsePageRequest(event.queryStringParameters);
  const after = page.cursor === undefined ? undefined : decodeCursor(page.cursor);
  const limit = page.limit + 1;

  const keyset =
    after === undefined ? '' : 'AND (t.created_at, t.id) < (:afterAt::timestamptz, :afterId)';

  const shared = [
    uuidParam('projectId', projectId),
    ...(after === undefined
      ? []
      : [textParam('afterAt', after.createdAt), uuidParam('afterId', after.id)]),
  ];

  // The Collector branch re-applies BR-19 at Task level rather than trusting
  // the project-level check above. Being assigned to one Task in a Project does
  // not make every Task in it visible — Chapter 4.8 §3 scopes a Collector to
  // "their own task_assignments rows", not to the Projects those imply.
  const result =
    caller.role === 'admin'
      ? await execute(
          `SELECT ${COLUMNS}
             FROM tasks t
            WHERE t.project_id = :projectId
              ${keyset}
            ORDER BY t.created_at DESC, t.id DESC
            LIMIT ${String(limit)}`,
          { parameters: shared },
        )
      : await execute(
          `SELECT DISTINCT ${COLUMNS}
             FROM tasks t
             JOIN task_assignments ta ON ta.task_id = t.id
            WHERE t.project_id = :projectId
              AND ta.user_id = :userId
              AND ta.removed_at IS NULL
              ${keyset}
            ORDER BY t.created_at DESC, t.id DESC
            LIMIT ${String(limit)}`,
          { parameters: [...shared, uuidParam('userId', caller.userId)] },
        );

  const rows = (result.records ?? []).map(toTask);
  const { page: kept, meta } = pageMeta(rows, page.limit);
  return { data: kept.map(render), meta };
});

/**
 * FR-ADM-02's create half — Admin only.
 *
 * **No `requirements` field**, and that is a recorded gap rather than an
 * omission: FR-PT-05 names *"instructions, reference examples, and
 * requirements"*, Chapter 4.4 §3's `tasks` table has six columns and none of
 * them is `requirements`, and the mobile `Task` entity leaves it out for the
 * same reason. Accepting a field with no column would be inventing schema.
 */
const createTask = withEnvelope('POST /v1/projects/{projectId}/tasks', async (event, caller) => {
  requireRole(caller, 'admin');
  const projectId = pathUuid(event.pathParameters, 'projectId');

  const body = parseBody(event.body);
  const title = requiredString(body, 'title', 200);
  const instructions = requiredString(body, 'instructions', 20_000);
  const referenceExamples = optionalStringArray(body, 'reference_examples');

  const created = await withTransaction(async (run) => {
    // Inside the transaction, so the visibility check and the insert see one
    // consistent snapshot. Outside it, a project archived between the two would
    // let the insert land anyway.
    await assertProjectVisible(caller, projectId, run);

    const inserted = await run(
      `INSERT INTO tasks (project_id, title, instructions, reference_examples)
            VALUES (:projectId, :title, :instructions, :referenceExamples)
         RETURNING id, project_id, title, instructions, reference_examples, created_at`,
      {
        parameters: [
          uuidParam('projectId', projectId),
          textParam('title', title),
          textParam('instructions', instructions),
          jsonParam('referenceExamples', referenceExamples),
        ],
      },
    );

    const row = inserted.records?.[0];
    if (row === undefined) {
      throw new Error('INSERT INTO tasks returned no row.');
    }
    const task = toTask(row);

    await run(
      `INSERT INTO audit_log (actor_id, action, target_table, target_id)
            VALUES (:actorId, 'task.create', 'tasks', :targetId)`,
      { parameters: [uuidParam('actorId', caller.userId), uuidParam('targetId', task.id)] },
    );

    return task;
  });

  return { data: render(created), status: 201 };
});

/**
 * FR-ADM-02's edit half — Admin only. A-118.
 *
 * ## `title` is accepted, and that is a judgement rather than a transcription
 *
 * Chapter 4.6 §3's purpose column reads *"Edit instructions/reference
 * examples"* and names two fields. A-118 reads that as descriptive prose, not
 * an exhaustive list, on two grounds that still hold against the applied
 * schema: Chapter 4.4 §3 makes `title` a column of the very row this route
 * patches, and Chapter 4.6 §6 disclaims itself as the authority on fields,
 * deferring them to an OpenAPI artifact that does not exist. The mobile
 * `updateTask` already sends all three.
 *
 * ## Absent and null are different, and the schema is why
 *
 * `tasks.title` and `tasks.instructions` are `NOT NULL`. "Leave unchanged" and
 * "set to null" therefore cannot be the same request, so `optionalString`
 * rejects an explicit null rather than treating it as absent — otherwise a
 * PATCH meaning to clear a field would arrive as a no-op and report success.
 *
 * A body with no patchable field is refused rather than issuing an empty
 * UPDATE. Chapter 2.7's A-06 applies the same rule at the other end, disabling
 * its confirm button *"to avoid a no-op write and a false 'saved'
 * confirmation"*.
 */
const updateTask = withEnvelope('PATCH /v1/tasks/{taskId}', async (event, caller) => {
  requireRole(caller, 'admin');
  const taskId = pathUuid(event.pathParameters, 'taskId');

  const body = parseBody(event.body);
  const title = optionalString(body, 'title', 200);
  const instructions = optionalString(body, 'instructions', 20_000);
  const referenceExamples = optionalStringArray(body, 'reference_examples');

  if (title === undefined && instructions === undefined && referenceExamples === undefined) {
    throw ApiError.invalidRequest(
      'Supply at least one of title, instructions or reference_examples.',
    );
  }

  const assignments: string[] = [];
  const parameters = [uuidParam('taskId', taskId)];
  if (title !== undefined) {
    assignments.push('title = :title');
    parameters.push(textParam('title', title));
  }
  if (instructions !== undefined) {
    assignments.push('instructions = :instructions');
    parameters.push(textParam('instructions', instructions));
  }
  if (referenceExamples !== undefined) {
    assignments.push('reference_examples = :referenceExamples');
    parameters.push(jsonParam('referenceExamples', referenceExamples));
  }

  const updated = await withTransaction(async (run) => {
    await assertTaskInOrg(caller, taskId, run);

    const result = await run(
      `UPDATE tasks SET ${assignments.join(', ')}
        WHERE id = :taskId
    RETURNING id, project_id, title, instructions, reference_examples, created_at`,
      { parameters },
    );

    const row = result.records?.[0];
    if (row === undefined) {
      // The org check passed a moment ago inside this transaction, so an absent
      // row here is a disagreement between statement and schema, not a 404.
      throw new Error('UPDATE tasks returned no row.');
    }
    const task = toTask(row);

    await run(
      `INSERT INTO audit_log (actor_id, action, target_table, target_id)
            VALUES (:actorId, 'task.update', 'tasks', :targetId)`,
      { parameters: [uuidParam('actorId', caller.userId), uuidParam('targetId', task.id)] },
    );

    return task;
  });

  return { data: render(updated) };
});

/**
 * FR-ADM-03 — assign a Collector. Admin only.
 *
 * ## A re-assignment is a resurrection, because the key leaves no alternative
 *
 * `task_assignments` is `PRIMARY KEY (task_id, user_id)`, so a Collector who
 * was removed and is assigned again **cannot** get a second row — A-181. The
 * only expressible form is `ON CONFLICT … DO UPDATE SET removed_at = NULL`,
 * and 0007's `UPDATE ON task_assignments` grant is what makes it legal.
 *
 * Idempotent by contract, which the client depends on: Chapter 2.7's A-06
 * saves a whole checkbox set at once and cannot know which boxes changed,
 * because Chapter 4.6 §3 has no route that reads an assignment back (open item
 * 89). So assigning an already-assigned Collector must succeed quietly.
 *
 * **The audit consequence, stated because the trail is the thing being
 * written:** a resurrection overwrites `assigned_by` and `assigned_at`, so who
 * first assigned this Collector is gone. `audit_log` is what preserves it, and
 * is a second reason this row is not optional.
 *
 * ## The assignee check is the reason `users` was granted at all
 *
 * UC-07's exception flow requires that assigning a Collector who has no account
 * or is deactivated is *blocked with an explanation*. Three separate refusals,
 * all 404 rather than 403 per F13 — an Admin has no business learning that a
 * uuid names a real user in another tenant.
 */
const assignCollector = withEnvelope(
  'POST /v1/tasks/{taskId}/assignments',
  async (event, caller) => {
    requireRole(caller, 'admin');
    const taskId = pathUuid(event.pathParameters, 'taskId');

    const body = parseBody(event.body);
    const collectorId = requiredString(body, 'collector_id', 64);
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(collectorId)) {
      throw new ApiError('REQUEST_MALFORMED_ID', 'collector_id must be a uuid.', 400);
    }

    await withTransaction(async (run) => {
      await assertTaskInOrg(caller, taskId, run);

      // The three-column read F6 granted. `SELECT *` would fail for this role,
      // which is the column-level grant doing its job.
      const assignee = await run('SELECT id, org_id, role FROM users WHERE id = :collectorId', {
        parameters: [uuidParam('collectorId', collectorId)],
      });
      const row = assignee.records?.[0];
      if (row === undefined) {
        throw ApiError.notFound('That collector');
      }
      if (readString(row, 1, 'users.org_id') !== caller.orgId) {
        // BR-20. Reported as absent, not as forbidden: an Admin must not be able
        // to probe another tenant's user ids.
        throw ApiError.notFound('That collector');
      }
      if (readString(row, 2, 'users.role') !== 'collector') {
        throw ApiError.invalidRequest('That user is not a Collector.');
      }

      await run(
        `INSERT INTO task_assignments (task_id, user_id, assigned_by)
            VALUES (:taskId, :collectorId, :actorId)
       ON CONFLICT (task_id, user_id) DO UPDATE
              SET removed_at = NULL,
                  assigned_by = EXCLUDED.assigned_by,
                  assigned_at = now()`,
        {
          parameters: [
            uuidParam('taskId', taskId),
            uuidParam('collectorId', collectorId),
            uuidParam('actorId', caller.userId),
          ],
        },
      );

      await run(
        `INSERT INTO audit_log (actor_id, action, target_table, target_id)
            VALUES (:actorId, 'collector.assign', 'task_assignments', :targetId)`,
        { parameters: [uuidParam('actorId', caller.userId), uuidParam('targetId', taskId)] },
      );
    });

    return { data: null, status: 204 };
  },
);

/**
 * FR-ADM-04 — remove or reassign. Admin only.
 *
 * A soft removal: Chapter 4.4 §4 keeps the row *"for audit rather than
 * hard-deleted"*, and no role in this backend holds SQL DELETE. Idempotent for
 * the same reason as the assign route, so removing an already-removed
 * assignment succeeds rather than 404s — `removed_at IS NULL` in the predicate
 * makes a repeat a no-op instead of resetting the timestamp, which would
 * falsify when the removal happened.
 *
 * **Reassignment is this call plus an assign, not a third route.** UC-07's
 * alternate flow describes exactly that, and Chapter 4.6 §3 labels this row
 * *"remove/reassign"*.
 */
const unassignCollector = withEnvelope(
  'DELETE /v1/tasks/{taskId}/assignments/{userId}',
  async (event, caller) => {
    requireRole(caller, 'admin');
    const taskId = pathUuid(event.pathParameters, 'taskId');
    const userId = pathUuid(event.pathParameters, 'userId');

    await withTransaction(async (run) => {
      await assertTaskInOrg(caller, taskId, run);

      await run(
        `UPDATE task_assignments
            SET removed_at = now()
          WHERE task_id = :taskId
            AND user_id = :userId
            AND removed_at IS NULL`,
        { parameters: [uuidParam('taskId', taskId), uuidParam('userId', userId)] },
      );

      await run(
        `INSERT INTO audit_log (actor_id, action, target_table, target_id)
              VALUES (:actorId, 'collector.unassign', 'task_assignments', :targetId)`,
        { parameters: [uuidParam('actorId', caller.userId), uuidParam('targetId', taskId)] },
      );
    });

    return { data: null, status: 204 };
  },
);

const routes: RouteTable = {
  [routeKey('GET', '/v1/projects/{projectId}/tasks')]: listTasks,
  [routeKey('POST', '/v1/projects/{projectId}/tasks')]: createTask,
  [routeKey('PATCH', '/v1/tasks/{taskId}')]: updateTask,
  [routeKey('POST', '/v1/tasks/{taskId}/assignments')]: assignCollector,
  [routeKey('DELETE', '/v1/tasks/{taskId}/assignments/{userId}')]: unassignCollector,
};

export const handler = createRouter('tasks', routes);
