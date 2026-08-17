-- 0005 — audit_log.
--
-- Chapter 4.2 §2 scopes it precisely: "Append-only record of Admin actions on
-- Projects/Tasks/Assignments". That sentence is what decides which functions
-- get an INSERT grant in 0007 — `projects` and `tasks`, and nothing else.
-- Nothing in the recording or upload path performs an Admin action on those
-- three resources.

CREATE TABLE audit_log (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id     uuid        NOT NULL REFERENCES users (id),
  action       text        NOT NULL,
  target_table text        NOT NULL,
  target_id    uuid        NOT NULL,
  occurred_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_log_target_idx ON audit_log (target_table, target_id);
CREATE INDEX audit_log_actor_idx ON audit_log (actor_id, occurred_at DESC);

-- "Append-only" is enforced by withholding UPDATE and DELETE in 0007 rather
-- than by a trigger. A grant that was never issued cannot be bypassed by a
-- session variable, and there is no privileged path that needs to edit history.
COMMENT ON TABLE audit_log IS
  'Append-only (Ch 4.2 §2). No role holds UPDATE or DELETE — see 0007.';
