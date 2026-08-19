-- 0011 — What the upload chain needs: a persisted multipart upload id, and a
-- way for a session to ever become complete.
--
-- Two unrelated-looking changes, both owed to Batch 2b and both traced in
-- Mission 7.3 Part 21.

-- ===========================================================================
-- Resumability — the multipart upload id was persisted nowhere
-- ===========================================================================
-- Volume 5 Chapter 5.13 §4 requires a retried upload to reuse "the same
-- in-progress multipart upload ID where possible", and NFR-REL-02 asks for
-- "100% of interrupted uploads resume without restarting from zero".
--
-- Neither was reachable, and the register already says why: "Nothing stores a
-- multipart upload ID or a record of which parts completed." Mission 4.4
-- recorded that as deliberately not built, because "resuming a multipart upload
-- requires the backend to return an existing uploadId and the set of parts it
-- already holds — Volume 4 territory". This is that territory.
--
-- Nullable, because a chunk row exists before `CreateMultipartUpload` has been
-- called for it in exactly one case — a re-registration after S3's 14-day
-- incomplete-upload lifecycle rule (A-004) has aborted the original. That case
-- is why the UPDATE grant below exists.
ALTER TABLE chunks ADD COLUMN upload_id text;

COMMENT ON COLUMN chunks.upload_id IS
  'S3 multipart UploadId, so a retried registration resumes rather than restarting (V5 Ch 5.13 §4, NFR-REL-02). Nullable: an aborted upload clears it and the next registration mints a new one.';

-- Column-level, deliberately. 0007 withheld row-level UPDATE from this role on
-- the grounds that "registration inserts a row and returns presigned URLs; the
-- status transitions belong to chunks-verify", and that reasoning is untouched:
-- this permits `upload_id` and nothing else, so the role still cannot reach
-- status, checksum_sha256, s3_object_key or file_size_bytes.
GRANT UPDATE (upload_id) ON chunks TO vump_chunks_upload;

-- ===========================================================================
-- FR-SES-02 — a session that can actually complete
-- ===========================================================================
-- A-188: `sessions.status` permits 'complete', Chapter 4.4 §5 says the
-- transition is "gated by stored procedure (Chapter 4.2)", and no such
-- procedure existed. `vump_sessions` holds no UPDATE either — proved live in
-- Batch 2a with a 42501 — so every session would sit at 'in_progress' forever,
-- including sessions whose chunks are all complete.
--
-- ## The rule, quoted rather than inferred
--
-- FR-SES-02: "The system shall mark a session Complete only once every one of
-- its chunks — and their metadata — is confirmed uploaded (FR-META-12)."
--
-- Two conditions, and **the second is already implied by the first**:
-- `complete_chunk()` refuses unless `chunk_metadata.verified_at IS NOT NULL`,
-- so a chunk cannot *be* 'complete' without confirmed metadata. The predicate
-- therefore collapses to "every chunk of this session is complete".
--
-- ## The zero-chunk guard, which is not in the requirement
--
-- `NOT EXISTS (... status <> 'complete')` is **vacuously true for an empty
-- set**, so a session that recorded nothing would complete the instant anything
-- asked. That is the classic way this rule ships inverted, and the guard is
-- stated as its own condition rather than hidden in a join.
--
-- ## Silent when not ready, unlike complete_chunk()
--
-- This is called after *every* chunk completion, so "not yet" is the normal
-- case rather than an error. `complete_chunk()` raises because its caller has
-- asserted the chunk is done; this one is asking a question.
CREATE FUNCTION complete_session(p_session_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_total bigint;
  v_open  bigint;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE status <> 'complete')
    INTO v_total, v_open
    FROM chunks
   WHERE session_id = p_session_id;

  IF v_total = 0 OR v_open > 0 THEN
    RETURN;
  END IF;

  -- Transaction-local, so the guard below re-arms the moment this commits.
  PERFORM set_config('vump.completing_session', 'on', true);
  UPDATE sessions
     SET status = 'complete'
   WHERE id = p_session_id
     AND status <> 'complete';
  PERFORM set_config('vump.completing_session', 'off', true);
END;
$fn$;

-- Without this, the procedure is the *intended* path rather than the only one —
-- the same distinction Chapter 4.2 §3 draws for chunks, and the same shape
-- `chunks_completion_guard` implements for it.
CREATE FUNCTION sessions_completion_guard()
  RETURNS trigger
  LANGUAGE plpgsql
AS $fn$
BEGIN
  IF NEW.status = 'complete' AND OLD.status IS DISTINCT FROM 'complete' THEN
    IF current_setting('vump.completing_session', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION
        'FR-SES-02: sessions.status may only reach ''complete'' via complete_session() (id=%)', OLD.id
        USING ERRCODE = 'restrict_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$fn$;

CREATE TRIGGER sessions_completion_guard_trg
  BEFORE UPDATE ON sessions
  FOR EACH ROW
  EXECUTE FUNCTION sessions_completion_guard();

COMMENT ON FUNCTION complete_session(uuid) IS
  'FR-SES-02 gate. The only path to sessions.status = ''complete''. Silent when the session is not yet finished, because it is called on every chunk completion.';

-- 0008's lesson, applied without waiting to be bitten again: `ALTER DEFAULT
-- PRIVILEGES ... REVOKE ALL ON FUNCTIONS FROM PUBLIC` was run in 0001 and **did
-- not take**, leaving PUBLIC with EXECUTE on complete_chunk() until 0008
-- revoked it by name. A privilege that must not exist is stated directly.
REVOKE ALL ON FUNCTION complete_session(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION sessions_completion_guard() FROM PUBLIC;

-- One role calls it: the one that completes the last chunk.
GRANT EXECUTE ON FUNCTION complete_session(uuid) TO vump_chunks_verify;

-- ---------------------------------------------------------------------------
-- What no role holds, restated because this file changed the answer
-- ---------------------------------------------------------------------------
-- * `vump_sessions` still has no UPDATE on `sessions`. Completion happens as
--   the definer, which is what lets FR-SES-02 work without widening the role
--   that creates sessions.
-- * `vump_chunks_upload` still has no row-level UPDATE on `chunks` — only the
--   single column added here.
-- * Still no DELETE on any table, by any role.
