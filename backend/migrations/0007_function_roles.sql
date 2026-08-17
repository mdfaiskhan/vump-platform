-- 0007 — one database role per Lambda function, and the GRANTs that make
-- Volume 8 Chapter 8.4 §1's per-function table restrictions real.
--
-- ## Why this is here and not in IAM
--
-- ADR-044 records that `rds-data` actions scope to the *cluster*, so V8.4 §1's
-- table-level intent "is not enforceable at that layer at all". This file is
-- the enforcement point. A-150 flagged it for this mission; this is it.
--
-- ## Roles are created NOLOGIN here, on purpose
--
-- Migrations are committed to git. A `CREATE ROLE … LOGIN PASSWORD '…'` in one
-- would be a credential in source control, which ADR-016 forbids permanently:
-- "a committed secret is disclosed permanently". So the roles are created
-- without the ability to log in, and `npm run db:bootstrap` generates each
-- password, sets it, and writes it to that function's Secrets Manager secret —
-- never passing through this file, a shell history, or Terraform state.
--
-- ## What V8.4 §1 does and does not say
--
-- V8.4 §1 tabulates four functions; ADR-015 and A-143 give us seven. The four
-- it names are honoured exactly. The three it does not — `sessions`,
-- `chunks-verify`, and the read half of `metadata` — are granted the minimum
-- their Chapter 4.6 routes require, and each is justified in a comment below.
-- A-158 records every widening and every tightening against the chapter.

CREATE ROLE vump_auth_verify   NOLOGIN;
CREATE ROLE vump_projects      NOLOGIN;
CREATE ROLE vump_tasks         NOLOGIN;
CREATE ROLE vump_sessions      NOLOGIN;
CREATE ROLE vump_chunks_upload NOLOGIN;
CREATE ROLE vump_chunks_verify NOLOGIN;
CREATE ROLE vump_metadata      NOLOGIN;

GRANT USAGE ON SCHEMA public TO
  vump_auth_verify, vump_projects, vump_tasks, vump_sessions,
  vump_chunks_upload, vump_chunks_verify, vump_metadata;

-- ---------------------------------------------------------------------------
-- auth-verify — A-150
-- ---------------------------------------------------------------------------
-- V8.4 §1: "No database write access — read-only lookup on users by
-- firebase_uid … Cannot modify any table". Chapter 4.7 §1 step 4: "looks up
-- (or creates, on first login) the matching users row".
--
-- A-150 resolves that narrowly: no UPDATE, no DELETE; INSERT of the caller's
-- own row on first login is permitted. The threat V8.4 §1 names is a
-- compromised verification path "leveraged into a data-write path", and
-- inserting a row keyed by a firebase_uid just verified does not serve it.
GRANT SELECT, INSERT ON users TO vump_auth_verify;

-- ---------------------------------------------------------------------------
-- projects
-- ---------------------------------------------------------------------------
-- V8.4 §1's `projects-tasks` row covers projects, tasks and task_assignments.
-- Split across two functions here, each getting only its own resource — which
-- is tighter than the chapter, not looser.
--
-- No UPDATE: Chapter 4.6 lists no PATCH for a project. `archived_at` exists for
-- a soft-delete that has no route yet, so the grant waits for the route.
GRANT SELECT, INSERT ON projects TO vump_projects;
GRANT INSERT ON audit_log TO vump_projects;

-- ---------------------------------------------------------------------------
-- tasks
-- ---------------------------------------------------------------------------
-- PATCH /v1/tasks/{taskId} needs UPDATE. DELETE
-- /v1/tasks/{taskId}/assignments/{userId} is a soft removal — FR-ADM-04 keeps
-- the row "for audit rather than hard-deleted" — so it is an UPDATE of
-- removed_at, and no DELETE is granted anywhere.
--
-- SELECT on projects is required by GET /v1/projects/{projectId}/tasks, which
-- must scope to a project the caller may see.
GRANT SELECT, INSERT, UPDATE ON tasks TO vump_tasks;
GRANT SELECT, INSERT, UPDATE ON task_assignments TO vump_tasks;
GRANT SELECT ON projects TO vump_tasks;
GRANT INSERT ON audit_log TO vump_tasks;

-- ---------------------------------------------------------------------------
-- sessions — not in V8.4 §1
-- ---------------------------------------------------------------------------
-- POST and GET /v1/tasks/{taskId}/sessions.
--
-- SELECT on task_assignments is BR-19, quoted verbatim by Chapter 4.2 §3:
-- "every query from a Collector's token is scoped by a WHERE
-- task_assignments.user_id = :current_user clause the API layer always
-- injects". The API layer cannot inject a clause against a table it cannot
-- read.
--
-- Deliberately NOT granted SELECT on tasks: a foreign key check does not
-- require SELECT on the referenced table, so INSERT works without it. This is
-- tighter than the first draft of this file.
GRANT SELECT, INSERT ON sessions TO vump_sessions;
GRANT SELECT ON task_assignments TO vump_sessions;

-- ---------------------------------------------------------------------------
-- chunks-upload — V8.4 §1's `chunk-registration`
-- ---------------------------------------------------------------------------
-- "rds-data:ExecuteStatement on chunks/sessions tables". No UPDATE on chunks:
-- registration inserts a row and returns presigned URLs; the status transitions
-- belong to chunks-verify.
GRANT SELECT, INSERT ON chunks TO vump_chunks_upload;
GRANT SELECT ON sessions TO vump_chunks_upload;

-- ---------------------------------------------------------------------------
-- chunks-verify — not in V8.4 §1
-- ---------------------------------------------------------------------------
-- PATCH /v1/chunks/{chunkId}/status.
--
-- Note what is absent: **no UPDATE on chunks at all.** Completion goes through
-- complete_chunk(), which is SECURITY DEFINER, so this role needs EXECUTE and
-- nothing more. The queued → uploading → failed transitions are granted as a
-- column-level UPDATE, so this role cannot touch s3_object_key, checksum or
-- file_size even on a row it may transition.
--
-- verified_at is a column-level grant for the same reason: FR-META-12 requires
-- this function to set it and nothing else in that table.
GRANT SELECT ON chunks TO vump_chunks_verify;
GRANT UPDATE (status) ON chunks TO vump_chunks_verify;
GRANT SELECT ON chunk_metadata TO vump_chunks_verify;
GRANT UPDATE (verified_at) ON chunk_metadata TO vump_chunks_verify;
GRANT EXECUTE ON FUNCTION complete_chunk(uuid) TO vump_chunks_verify;

-- ---------------------------------------------------------------------------
-- metadata — V8.4 §1's `metadata-write`, plus the read half
-- ---------------------------------------------------------------------------
-- V8.4 §1: "rds-data:ExecuteStatement on chunk_metadata only … No S3
-- permissions at all."
--
-- One widening, and it is Chapter 4.5 §5's doing: GET /v1/chunks/{id}/metadata
-- "returns the same JSON shape above plus verified_at and **the chunk's current
-- status**". The status lives on `chunks`, so the read half cannot be served
-- from chunk_metadata alone. Granted as SELECT only, and recorded in A-158
-- rather than taken quietly.
--
-- No UPDATE: FR-META-07's collector-editable notes/tags has no route in Chapter
-- 4.6 (A-158 flags the missing PATCH), so the grant waits for the route.
GRANT SELECT, INSERT ON chunk_metadata TO vump_metadata;
GRANT SELECT ON chunks TO vump_metadata;

-- ---------------------------------------------------------------------------
-- What no role holds, stated so the absences are deliberate
-- ---------------------------------------------------------------------------
-- * No DELETE on any table, by any role.
-- * No UPDATE or DELETE on audit_log — Chapter 4.2 §2's "append-only".
-- * No grant of any kind on orgs: nothing in Chapter 4.6 reads or writes it.
-- * No role but auth-verify touches users. Chapter 4.7 §1 step 4's caller
--   lookup therefore cannot be performed by the other six, which is the open
--   architectural gap A-159 records — org_id becomes a Firebase custom claim,
--   decided but not implemented, and resolveCaller stays stubbed until it is.
