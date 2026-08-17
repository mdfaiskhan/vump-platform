-- 0003 — projects, tasks and task_assignments.

CREATE TABLE projects (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      uuid        NOT NULL REFERENCES orgs (id),
  name        text        NOT NULL,
  description text,
  -- Chapter 4.4: "must be role='admin', enforced at the API layer, Chapter
  -- 4.8". Left to the API layer deliberately — a CHECK cannot read another
  -- table, and a trigger enforcing it would duplicate Chapter 4.8's rule in a
  -- second place that could disagree with it.
  created_by  uuid        NOT NULL REFERENCES users (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz
);

CREATE INDEX projects_org_id_idx ON projects (org_id);

CREATE TABLE tasks (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id         uuid        NOT NULL REFERENCES projects (id),
  title              text        NOT NULL,
  instructions       text        NOT NULL,
  reference_examples jsonb,
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX tasks_project_id_idx ON tasks (project_id);

CREATE TABLE task_assignments (
  task_id     uuid        NOT NULL REFERENCES tasks (id),
  user_id     uuid        NOT NULL REFERENCES users (id),
  assigned_by uuid        NOT NULL REFERENCES users (id),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  -- FR-ADM-04: "kept for audit rather than hard-deleted."
  removed_at  timestamptz,

  PRIMARY KEY (task_id, user_id)
);

-- BR-19's scoping clause, quoted by Chapter 4.2 §3, reads
-- `WHERE task_assignments.user_id = :current_user` — a lookup by user, which
-- the composite primary key (task_id, user_id) does not serve.
CREATE INDEX task_assignments_user_id_idx ON task_assignments (user_id);
