-- 0010 — What the thirteen Chapter 4.6 routes actually need, which is more
-- than 0007 gave them.
--
-- ## Why this file exists
--
-- 0007 was written against Chapter 4.6's *route list*. It was not written
-- against Chapter 4.8 §3's *scope filters*, and that is the gap. A scope filter
-- is a join — BR-19 is `projects ⋈ tasks ⋈ task_assignments`, BR-20 is
-- `… ⋈ projects.org_id` — and a join needs SELECT on every table in it. Eight
-- of the thirteen stubbed routes could not be implemented at all on 0007's
-- grants: not narrowly, not with a workaround, not at all.
--
-- Mission 7.3 Part 1 traced each one. This file is the answer, and like 0007 it
-- states a reason per grant rather than a reason per file. Every widening below
-- names the route that forces it and the chapter that forces the route.
--
-- ## Why a new file rather than an edit to 0007
--
-- 0007 is applied and checksummed. ADR-046: "an applied migration whose file
-- has changed is a hard error, not a re-run". History is appended to.
--
-- ## What this file deliberately does NOT do
--
-- No DELETE is granted to any of the seven function roles. 0007's closing
-- section states that absence as deliberate and it stays deliberate — the one
-- delete-capable path added here is a SECURITY DEFINER function that cannot
-- reach production data, and it belongs to an eighth role that no Lambda uses.

-- ===========================================================================
-- F2 — chunk_id is the client's, and the schema now insists on it
-- ===========================================================================
-- Volume 5 Chapter 5.14 §3: chunk_id is "a UUID generated locally the moment a
-- chunk begins finalizing". Chapter 5.13 §4 requires every retry reuse "the
-- exact same chunk_id". Mission 3.4.5 built exactly that, and the id has been
-- minted on-device ever since.
--
-- Volume 4 Chapter 4.6 §5's request body does not carry it, and 0004 gave
-- chunks.id a `DEFAULT gen_random_uuid()`. Between them, a registration would
-- have minted a *second* id server-side and echoed it back — and
-- `ChunkUploadApiImpl.registerChunk` compares the echoed id against the local
-- one and throws when they differ. Every upload the platform has never yet
-- performed would have failed on that comparison.
--
-- F2 resolves it in the client's favour: the id arrives in the request body,
-- is inserted explicitly, and is echoed back unchanged. Zero mobile changes.
--
-- The DEFAULT is dropped rather than left in place. Left in place it is a
-- silent fallback: a handler that forgot to bind :id would get a server-minted
-- uuid and reintroduce the exact defect, invisibly. Dropped, the same omission
-- is a NOT NULL violation on the first call. The same reasoning 0006 applies to
-- BR-21 — make the wrong path impossible rather than merely unintended.
--
-- BR-11's no-duplicate guarantee gains something here too. With a
-- client-supplied primary key, a re-registration is a primary-key conflict on a
-- value the client controls, which is what makes CHUNK_ALREADY_REGISTERED
-- detectable at all. 0004's UNIQUE on s3_object_key remains the structural
-- guarantee; this makes the *named refusal* possible rather than a raw
-- constraint violation surfacing as INTERNAL_ERROR.
ALTER TABLE chunks ALTER COLUMN id DROP DEFAULT;

COMMENT ON COLUMN chunks.id IS
  'The client-minted chunk_id (V5 Ch 5.14 §3), supplied in the POST /v1/sessions/{id}/chunks body and echoed back unchanged. No DEFAULT, on purpose: a server-minted id would fail the client echo check (F2, Mission 7.3).';

-- ===========================================================================
-- F5 — a session the client can name, so registration is idempotent
-- ===========================================================================
-- `SessionRegistrar`'s contract calls itself "idempotent by contract", and says
-- why: "a chunk pipeline that runs once per chunk will ask for the same
-- session's id many times — an implementation that created a session per call
-- would fragment one recording across many backend sessions."
--
-- Chapter 4.6 gives POST /v1/tasks/{taskId}/sessions no request body and
-- 0004's `sessions` has no column the client controls, so there was nothing to
-- deduplicate on. F5 adds one, on F2's pattern: the client supplies the
-- session UUID it already minted at session start (Chapter 5.3), and a repeat
-- call resolves to the same row through ON CONFLICT rather than creating a
-- second.
--
-- ## Why the constraint is (collector_id, client_session_id) and not the id alone
--
-- Chapter 5.14 §3 argues the client id is globally unique by construction —
-- "two Collectors, or the same Collector on two devices, can never produce the
-- same session_id" — so a bare UNIQUE would be sound *if every client were
-- honest*. It is not a uniqueness question, it is a scope question: with a
-- global constraint, a caller who guessed or replayed another Collector's
-- client_session_id would have `ON CONFLICT DO NOTHING` resolve to that
-- Collector's row and hand them its backend id.
--
-- Scoping the constraint to the collector closes it structurally rather than
-- by asking the handler to re-check ownership after the fact. Two Collectors
-- supplying the same value get two rows, each their own, which is the correct
-- outcome and not a collision.
--
-- NOT NULL is safe because `sessions` is empty: POST /v1/tasks/{taskId}/sessions
-- has been stubbed since Mission 6.2 and nothing else writes the table. If that
-- is somehow untrue this statement fails, the whole migration rolls back
-- (ADR-046: one transaction per migration), and the assumption is corrected
-- rather than silently worked around.
ALTER TABLE sessions
  ADD COLUMN client_session_id uuid NOT NULL;

ALTER TABLE sessions
  ADD CONSTRAINT sessions_client_session_id_key UNIQUE (collector_id, client_session_id);

COMMENT ON COLUMN sessions.client_session_id IS
  'The device-minted session UUID (V5 Ch 5.3). Unique per collector, so a repeated SessionRegistrar call resolves to one row instead of fragmenting a recording (F5, Mission 7.3).';

-- ===========================================================================
-- F1 — the eight route-scope widenings
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- projects — BR-19 for GET /v1/projects
-- ---------------------------------------------------------------------------
-- Chapter 4.6 §3's own row: "Admin: all Projects in their org. Collector: only
-- Projects with an assigned Task (BR-19)." The Admin half is served by 0007's
-- SELECT on projects. The Collector half is a two-hop join this role could not
-- make, so A-119's server-side scope difference — recorded as "real and
-- untestable until Mission 7" — was in fact unimplementable, not merely
-- untested.
--
-- Read-only, and narrower than the `tasks` role's own grants: this role can see
-- that a Task exists and who is assigned to it, and can write neither.
GRANT SELECT ON tasks TO vump_projects;
GRANT SELECT ON task_assignments TO vump_projects;

-- ---------------------------------------------------------------------------
-- tasks — F6, and it is a documented exception to V8.4 §1
-- ---------------------------------------------------------------------------
-- 0007's closing section says it plainly: "No role but auth-verify touches
-- users." This is the exception, it is scoped to three columns, and it is
-- recorded rather than taken quietly.
--
-- ## What forces it
--
-- Chapter 4.4 §4 types task_assignments.user_id as "FK → users.id
-- (role='collector')", and UC-07's exception flow requires that assigning a
-- Collector who has no account or is deactivated is *blocked with an
-- explanation*. Without a read of `users`, POST /v1/tasks/{taskId}/assignments
-- can do none of that:
--
--   * a bad user_id surfaces as a raw foreign-key violation, which
--     `toEnvelopeError` maps to INTERNAL_ERROR — the opposite of Chapter 4.6
--     §1's named-cause rule;
--   * nothing checks role='collector', so an Admin can be assigned to a Task;
--   * and nothing checks the assignee's org, so an Admin can assign a
--     Collector belonging to **another organisation**. That is a live BR-20
--     tenant-isolation hole, not a cosmetic gap.
--
-- ## Why three columns and not the row
--
-- The grant is column-level so the exception cannot quietly widen. `SELECT *`
-- on users fails for this role; only these three resolve.
--
--   id      — the FK target being validated.
--   org_id  — BR-20. This is the whole point.
--   role    — Chapter 4.4 §4's 'collector' restriction.
--
-- Deliberately withheld, and each absence is load-bearing:
--
--   firebase_uid — the join key to Firebase Authentication (Chapter 4.7).
--                  Withholding it means a compromised `tasks` function cannot
--                  correlate an Aurora row to an identity-provider account,
--                  which is the specific leverage V8.4 §1's restriction exists
--                  to deny.
--   email        — PII, and nothing in Chapter 4.6 §3 returns it.
--   display_name — needed by A-06's Collector picker, which has no route
--                  (open item 89). The grant waits for the route, exactly as
--                  0007 made projects' UPDATE wait for a PATCH.
--   created_at   — no route reads it.
GRANT SELECT (id, org_id, role) ON users TO vump_tasks;

-- ---------------------------------------------------------------------------
-- sessions — BR-20 and A-07 for GET /v1/tasks/{taskId}/sessions
-- ---------------------------------------------------------------------------
-- 0007 granted this role what POST needs and nothing GET needs. The GET is
-- Admin (Chapter 4.6 §4), so BR-20 applies: "every Project/Task/Assignment/
-- Metadata query is filtered WHERE org_id = :admin_org_id". org_id lives on
-- `projects`, two hops from `sessions`.
--
-- `chunks` is the second widening and Chapter 4.6 §4's purpose column is what
-- forces it: "A-07 — session/chunk status across a Task". A route that returns
-- session status alone does not serve the screen the chapter names it for.
-- SELECT only — this role transitions nothing.
GRANT SELECT ON tasks TO vump_sessions;
GRANT SELECT ON projects TO vump_sessions;
GRANT SELECT ON chunks TO vump_sessions;

-- ---------------------------------------------------------------------------
-- chunks-upload — the deterministic key, which it could not compute
-- ---------------------------------------------------------------------------
-- Volume 5 Chapter 5.14 §1 fixes the key as
--
--   {org_id}/{project_id}/{task_id}/{session_id}/{sequence_index:04d}_{chunk_id}.mp4
--
-- and Chapter 4.10 §2 step 1 makes computing it this function's job: "the
-- Lambda computes the deterministic key (Volume 5.14) and returns" it. 0007
-- gave it SELECT on `sessions`, which yields task_id and stops there. It could
-- reach neither project_id nor org_id — so the single most load-bearing value
-- in the upload path was not computable by the role assigned to compute it.
--
-- This is the blocker under every upload the platform has ever attempted
-- (open item 36, A-100), and it is two SELECTs.
--
-- task_assignments is BR-19, quoted verbatim by Chapter 4.2 §3 — "every query
-- from a Collector's token is scoped by a WHERE task_assignments.user_id =
-- :current_user clause the API layer always injects, never left optional".
-- Session ownership (sessions.collector_id) is not a substitute: Chapter 4.8 §3
-- requires that a removed assignment "immediately excludes that Task from all
-- future queries", and a Collector removed mid-session still owns the session
-- row.
GRANT SELECT ON tasks TO vump_chunks_upload;
GRANT SELECT ON projects TO vump_chunks_upload;
GRANT SELECT ON task_assignments TO vump_chunks_upload;

-- ---------------------------------------------------------------------------
-- chunks-verify — it could not identify the caller at all
-- ---------------------------------------------------------------------------
-- PATCH /v1/chunks/{chunkId}/status is Collector-scoped (Chapter 4.6 §4). The
-- caller's link to the chunk runs chunks → sessions.collector_id, and 0007
-- granted no SELECT on sessions. So this role could transition the status of
-- any chunk id it was handed, by any authenticated Collector — the scope check
-- Chapter 4.8 §2 step 3 requires had no data to run against.
--
-- Note what is still absent: no SELECT on tasks or projects. This route needs
-- to identify the caller, not to scope by org, and 'complete' still goes
-- through complete_chunk() with no UPDATE on chunks beyond the status column.
GRANT SELECT ON sessions TO vump_chunks_verify;
GRANT SELECT ON task_assignments TO vump_chunks_verify;

-- ---------------------------------------------------------------------------
-- metadata — the identity group, and both routes' scope
-- ---------------------------------------------------------------------------
-- Two separate failures, one grant set.
--
-- **The write.** POST /v1/chunks/{chunkId}/metadata is Collector-scoped, and
-- the caller's link to the chunk runs chunks → sessions, which this role could
-- not read.
--
-- **The read.** Chapter 4.5 §2's canonical shape opens with an `identity` group
-- carrying session_id, project_id, task_id and collector_id. 0004's own comment
-- explains why none of them is a column: "reachable by joining chunks →
-- sessions → tasks → projects and are deliberately not duplicated here." That
-- comment is correct and it assumed a role that could perform the join. This
-- one could not, so GET /v1/chunks/{chunkId}/metadata could not return the
-- shape Chapter 4.5 §5 says it returns. The GET is also Admin-only (Chapter 4.8
-- §4's matrix: "Collector never reads back metadata, only writes it"), so BR-20
-- applies and needs projects.org_id from the same join.
--
-- 0007 already recorded one widening here for Chapter 4.5 §5's "the chunk's
-- current status", and noted it was "recorded in A-158 rather than taken
-- quietly". This is the rest of that same sentence's cost, found by tracing the
-- route instead of the table. Read-only throughout; the write half is still
-- INSERT on chunk_metadata alone, and BR-22's trigger is untouched.
GRANT SELECT ON sessions TO vump_metadata;
GRANT SELECT ON tasks TO vump_metadata;
GRANT SELECT ON projects TO vump_metadata;
GRANT SELECT ON task_assignments TO vump_metadata;

-- ===========================================================================
-- F7 — a teardown path for the behavioural proofs, railed at the database
-- ===========================================================================
-- A-173 is the blocker this closes: "Migration 0007 grants SELECT, INSERT,
-- UPDATE and one EXECUTE across the seven per-function roles. It grants DELETE
-- to none of them", so the BR-08/11/21/22 proofs "can seed and assert, and
-- cannot clean up". ADR-049 denies db-prover the master credential on
-- correctness grounds — a proof run as master bypasses every GRANT it is
-- testing — so the teardown the uncommitted scratchpad performed as master has
-- no legal successor. Gap 8 has been open on exactly this.
--
-- ## The shape chosen, and why not the other two
--
-- A-173 lists three. Rollback-only proofs are defeated by the design they test:
-- each per-function credential is a separate Data API session, so one
-- transaction cannot span the roles a cross-role proof needs. A disposable
-- database per run fights MinCapacity 0 (A-156, gap 9) and is slow.
--
-- The third — a dedicated delete-capable role — is taken here, with the rail
-- F7 requires: **no role holds DELETE on anything.** The capability lives in a
-- SECURITY DEFINER function whose scope is a hard-coded literal, and the role
-- holds EXECUTE on that function and nothing else. This is complete_chunk()'s
-- pattern (0006) applied a second time, for the same reason: "the only role
-- that can complete a chunk is the one granted EXECUTE, and it can do nothing
-- else to the row."
--
-- The rail is structural rather than procedural. The function takes **no
-- parameter**. There is no argument a caller could pass to widen its reach, so
-- a mistake in CI, a typo, or a compromised db-prover session cannot aim it at
-- real data. Discipline is not load-bearing anywhere in this design.

-- The tenant every CI fixture belongs to. Same construction as 0009's
-- Unassigned org — a valid v4 uuid, obviously reserved, deliberately not
-- random-looking — and the next value in that reserved sequence.
--
-- Inserted here because no function role holds any grant on `orgs` (0007:
-- "No grant of any kind on orgs"), so nothing else could create it, and the
-- proofs need it to exist before they seed anything.
INSERT INTO orgs (id, name)
VALUES ('00000000-0000-4000-8000-000000000002', 'CI Proof Fixtures')
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE orgs IS
  'Tenant boundary. BR-20 scopes every Admin query by org. Ninth table of Ch 4.3, defined in Mission 6.3 (A-154). Two reserved rows: ...0001 Unassigned (0009), ...0002 CI Proof Fixtures (0010) — the only tenant purge_ci_fixtures() can reach.';

CREATE ROLE vump_ci_proof NOLOGIN;

GRANT USAGE ON SCHEMA public TO vump_ci_proof;

-- Deletes every row reachable from the CI fixture organisation, and nothing
-- else.
--
-- ## Why SECURITY DEFINER and no parameter
--
-- SECURITY DEFINER so the caller needs EXECUTE and no DELETE of its own — the
-- capability is the function, not the role. No parameter so the blast radius is
-- a compile-time constant: the org id below is the only tenant any invocation
-- can ever touch, whoever calls it and however they call it.
--
-- `SET search_path` is not optional on a SECURITY DEFINER function: without it
-- a caller can put a schema of their own in front of `public` and have the
-- function resolve to their tables instead. 0006 makes the same note for the
-- same reason.
--
-- ## Reachability, in both directions
--
-- Fixtures are reachable two ways — down from the org's projects, and sideways
-- from the org's users (a session carries collector_id, an assignment carries
-- user_id and assigned_by). Both are followed, because a proof that seeds a
-- Collector and a session under someone else's task would otherwise leave the
-- session behind and the user undeletable.
--
-- ## The one failure it will not paper over
--
-- If a CI-org user ever created a row in a *real* org — a project whose
-- created_by points at them — the users DELETE fails on the foreign key and the
-- whole call raises. That is the correct outcome and it is stated here so it is
-- read as designed rather than as a bug: the alternative is a purge that
-- silently orphans or silently widens.
--
-- Row counts are returned rather than discarded so CI reports what it deleted.
-- "Prove rather than assert" applies to teardown too — a purge that says
-- nothing is indistinguishable from a purge that matched nothing.
CREATE FUNCTION purge_ci_fixtures()
  RETURNS TABLE (purged_table text, rows_deleted bigint)
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, pg_temp
AS $fn$
DECLARE
  c_ci_org CONSTANT uuid := '00000000-0000-4000-8000-000000000002';
  v_users    uuid[];
  v_projects uuid[];
  v_tasks    uuid[];
  v_sessions uuid[];
  v_chunks   uuid[];
  v_count    bigint;
BEGIN
  SELECT coalesce(array_agg(id), '{}') INTO v_users
    FROM users WHERE org_id = c_ci_org;

  SELECT coalesce(array_agg(id), '{}') INTO v_projects
    FROM projects WHERE org_id = c_ci_org;

  SELECT coalesce(array_agg(id), '{}') INTO v_tasks
    FROM tasks WHERE project_id = ANY (v_projects);

  SELECT coalesce(array_agg(id), '{}') INTO v_sessions
    FROM sessions
   WHERE task_id = ANY (v_tasks) OR collector_id = ANY (v_users);

  SELECT coalesce(array_agg(id), '{}') INTO v_chunks
    FROM chunks WHERE session_id = ANY (v_sessions);

  -- Child-first. chunk_metadata's FK is ON DELETE RESTRICT (Chapter 4.3), so
  -- it must go before chunks rather than relying on a cascade that does not
  -- exist. BR-22's trigger is BEFORE UPDATE only and does not fire here.
  DELETE FROM chunk_metadata WHERE chunk_id = ANY (v_chunks);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  purged_table := 'chunk_metadata'; rows_deleted := v_count; RETURN NEXT;

  DELETE FROM chunks WHERE id = ANY (v_chunks);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  purged_table := 'chunks'; rows_deleted := v_count; RETURN NEXT;

  DELETE FROM sessions WHERE id = ANY (v_sessions);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  purged_table := 'sessions'; rows_deleted := v_count; RETURN NEXT;

  DELETE FROM task_assignments
   WHERE task_id = ANY (v_tasks)
      OR user_id = ANY (v_users)
      OR assigned_by = ANY (v_users);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  purged_table := 'task_assignments'; rows_deleted := v_count; RETURN NEXT;

  DELETE FROM tasks WHERE id = ANY (v_tasks);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  purged_table := 'tasks'; rows_deleted := v_count; RETURN NEXT;

  -- Before users: projects.created_by references it.
  DELETE FROM projects WHERE id = ANY (v_projects);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  purged_table := 'projects'; rows_deleted := v_count; RETURN NEXT;

  -- Before users: audit_log.actor_id references it. This is the one place
  -- anything deletes from an append-only table, and it is why no *role* holds
  -- DELETE on audit_log — 0005's "append-only is enforced by withholding
  -- UPDATE and DELETE in 0007" still stands for every principal that is not
  -- this function, whose reach is one synthetic tenant.
  DELETE FROM audit_log WHERE actor_id = ANY (v_users);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  purged_table := 'audit_log'; rows_deleted := v_count; RETURN NEXT;

  DELETE FROM users WHERE id = ANY (v_users);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  purged_table := 'users'; rows_deleted := v_count; RETURN NEXT;

  RETURN;
END;
$fn$;

COMMENT ON FUNCTION purge_ci_fixtures() IS
  'F7 teardown. Deletes every row reachable from org 00000000-0000-4000-8000-000000000002 and nothing else. Takes no parameter, so its blast radius is a compile-time constant. Closes the teardown half of A-173 / gap 8.';

-- 0008's lesson, applied without waiting to be bitten by it a second time.
--
-- 0001 ran `ALTER DEFAULT PRIVILEGES … REVOKE ALL ON FUNCTIONS FROM PUBLIC` and
-- **it did not take** — pg_default_acl recorded nothing and PUBLIC held EXECUTE
-- on complete_chunk() until 0008 revoked it by name. 0008 repeated the default
-- and said outright that it "is no longer load-bearing: each existing function
-- is revoked by name. A privilege that must not exist is worth stating directly
-- rather than inferring from a default."
--
-- A delete-capable function is the last one to leave to a default that has
-- already failed once. Revoked by name, then granted to exactly one role.
REVOKE ALL ON FUNCTION purge_ci_fixtures() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION purge_ci_fixtures() TO vump_ci_proof;

-- ---------------------------------------------------------------------------
-- What no role holds, restated because this file changed the answer
-- ---------------------------------------------------------------------------
-- * Still no DELETE on any table, by any role. vump_ci_proof holds EXECUTE on
--   one function and USAGE on the schema — nothing more, not even SELECT.
-- * Still no UPDATE or DELETE on audit_log. The purge deletes CI actors' rows
--   as the definer, not as a grantee.
-- * Still no grant of any kind on orgs.
-- * `users` is no longer auth-verify's alone. vump_tasks holds SELECT on three
--   of its seven columns — F6, justified above, and the single documented
--   exception to V8.4 §1's rule. firebase_uid and email are not among them.
