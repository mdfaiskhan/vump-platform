-- 0014 — TEMPORARY: a task may be marked visible to every Collector in its org.
--
-- ## Why this exists
--
-- BR-19 scopes a Collector to Projects with an assigned Task, and Chapter 4.8
-- §3 scopes them to "their own task_assignments rows". Three queries enforce
-- it: GET /v1/projects' Collector branch, GET /v1/projects/{id}/tasks'
-- Collector branch, and assertProjectVisible, which gates the second.
--
-- The consequence is correct and inconvenient: a Collector with no
-- task_assignments row sees an empty Projects list, no error, nothing to act
-- on. A new tester signing in with a valid invite for the right org gets
-- exactly that, and nothing in the product lets them out of it — the only
-- route that creates an assignment, POST /v1/tasks/{taskId}/assignments, is
-- Admin-only and no Admin account exists.
--
-- ## THIS IS TEMPORARY
--
-- Open items 89 and 92 — real Task assignment — supersede it. When they ship,
-- delete all of this:
--
--   1. this column, `tasks.shared_with_org`
--   2. the `OR t.shared_with_org` clause in all THREE queries named above
--   3. the register row that tracks this
--
-- It is a scoped, reversible exception to an existing rule, not a new rule.
-- The data model's meaning is unchanged and so is the authorization pattern:
-- a Collector still sees a Task because something says they may, and this adds
-- one more thing that can say so.
--
-- ## What it deliberately does NOT relax
--
-- **The org check stays.** Every one of the three queries keeps
-- `p.org_id = :orgId`, so a task flagged in one organisation is invisible to
-- every other. BR-20's isolation is untouched, and that is the property worth
-- being careful about here — a flag that leaked across tenants would be a far
-- worse defect than the empty list it fixes.
--
-- **Admins are unaffected.** Their branches never joined task_assignments.
--
-- ## The default is false, and the flag is opt-in per row
--
-- Adding the column cannot change what anyone sees. Only the UPDATE below
-- does, and it touches exactly one row.
ALTER TABLE tasks
  ADD COLUMN shared_with_org boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN tasks.shared_with_org IS
  'TEMPORARY (migration 0014): visible to every Collector in the org, '
  'bypassing BR-19''s task_assignments requirement. Superseded by open items '
  '89/92. Drop this column and the OR clauses in the projects and tasks '
  'routes when real assignment ships.';

-- The task this project has recorded against throughout Missions 7 and 8,
-- inside the "Checkpoint Project" seeded for the device checkpoint.
--
-- **A no-op in any environment that does not hold this row**, which is the
-- honest shape for environment-specific data in a forward-only migration: the
-- MECHANISM above is identical everywhere, and which row carries the flag is
-- not, because seeded data is not. An environment wanting a shared task sets
-- the flag on one of its own rows; nothing here is dev-only.
--
-- Scoped by project as well as by id so a uuid collision cannot flag a row in
-- some other project by accident.
UPDATE tasks
   SET shared_with_org = true
 WHERE id         = 'f4a31a7f-9d7b-4671-a53b-661327328db2'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;
