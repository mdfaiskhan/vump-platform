-- 0006 — the rules Chapter 4.2 §3 requires the database to enforce itself.
--
-- Everything here exists because Chapter 4.2 §3 says these are "not left to
-- application code discipline alone". Each is enforced where it cannot be
-- forgotten by a handler.

-- ---------------------------------------------------------------------------
-- BR-22 — system-generated metadata is immutable
-- ---------------------------------------------------------------------------
-- Chapter 4.2 §3: "a BEFORE UPDATE trigger on chunk_metadata rejects any change
-- to a system-generated column, allowing only the notes/tags column to change."
--
-- Read literally that also blocks `verified_at`, which Chapter 4.5 §3 requires
-- the backend to set after insert — so the two chapters cannot both be
-- satisfied by the literal reading. Resolved the same way A-150 resolved the
-- auth-verify contradiction: narrowly, by the threat each rule protects
-- against. BR-22 protects the *captured* record from being rewritten;
-- `verified_at` is the backend's own attestation, not part of the capture.
--
-- So `verified_at` may transition NULL → a value exactly once, and never
-- change again. `notes_tags` is free. Everything else is frozen. A-157.
CREATE FUNCTION chunk_metadata_immutable()
  RETURNS trigger
  LANGUAGE plpgsql
AS $fn$
BEGIN
  IF NEW.chunk_id          IS DISTINCT FROM OLD.chunk_id
  OR NEW.captured_start_at IS DISTINCT FROM OLD.captured_start_at
  OR NEW.captured_end_at   IS DISTINCT FROM OLD.captured_end_at
  OR NEW.resolution        IS DISTINCT FROM OLD.resolution
  OR NEW.frame_rate        IS DISTINCT FROM OLD.frame_rate
  OR NEW.bitrate_kbps      IS DISTINCT FROM OLD.bitrate_kbps
  OR NEW.codec             IS DISTINCT FROM OLD.codec
  OR NEW.zoom_factor       IS DISTINCT FROM OLD.zoom_factor
  OR NEW.camera            IS DISTINCT FROM OLD.camera
  OR NEW.device_model      IS DISTINCT FROM OLD.device_model
  OR NEW.os_version        IS DISTINCT FROM OLD.os_version
  OR NEW.app_version       IS DISTINCT FROM OLD.app_version
  OR NEW.device_id         IS DISTINCT FROM OLD.device_id
  OR NEW.gps_lat           IS DISTINCT FROM OLD.gps_lat
  OR NEW.gps_lng           IS DISTINCT FROM OLD.gps_lng
  OR NEW.battery_pct       IS DISTINCT FROM OLD.battery_pct
  OR NEW.network_type      IS DISTINCT FROM OLD.network_type
  THEN
    RAISE EXCEPTION
      'BR-22: system-generated chunk metadata is immutable (chunk_id=%)', OLD.chunk_id
      USING ERRCODE = 'restrict_violation';
  END IF;

  IF OLD.verified_at IS NOT NULL AND NEW.verified_at IS DISTINCT FROM OLD.verified_at THEN
    RAISE EXCEPTION
      'BR-22: verified_at is set once and never changed (chunk_id=%)', OLD.chunk_id
      USING ERRCODE = 'restrict_violation';
  END IF;

  RETURN NEW;
END;
$fn$;

CREATE TRIGGER chunk_metadata_immutable_trg
  BEFORE UPDATE ON chunk_metadata
  FOR EACH ROW
  EXECUTE FUNCTION chunk_metadata_immutable();

-- ---------------------------------------------------------------------------
-- BR-21 — a chunk is not Complete until its metadata is confirmed
-- ---------------------------------------------------------------------------
-- Chapter 4.2 §3: "chunks.status can only transition to 'complete' via a stored
-- procedure that first checks a matching, non-null chunk_metadata row exists".
-- Chapter 4.5 §3 adds the second half: the backend sets
-- `chunk_metadata.verified_at` "and allowing chunks.status → 'complete'", so
-- completion requires the verification to have happened, not merely a row to
-- exist.
--
-- The guard below is what makes "only via the procedure" true. Without it the
-- procedure would be the *intended* path rather than the only one, which is
-- the distinction Chapter 4.2 §3 is drawing.
CREATE FUNCTION chunks_completion_guard()
  RETURNS trigger
  LANGUAGE plpgsql
AS $fn$
BEGIN
  IF NEW.status = 'complete' AND OLD.status IS DISTINCT FROM 'complete' THEN
    IF current_setting('vump.completing', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION
        'BR-21: chunks.status may only reach ''complete'' via complete_chunk() (id=%)', OLD.id
        USING ERRCODE = 'restrict_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$fn$;

CREATE TRIGGER chunks_completion_guard_trg
  BEFORE UPDATE ON chunks
  FOR EACH ROW
  EXECUTE FUNCTION chunks_completion_guard();

-- SECURITY DEFINER so the caller needs EXECUTE on this and nothing else — it
-- does not need UPDATE on chunks. That is what keeps the completion path
-- narrow: the only role that can complete a chunk is the one granted EXECUTE,
-- and it can do nothing else to the row.
--
-- `SET search_path` is not optional on a SECURITY DEFINER function: without it
-- a caller can put a schema of their own in front of `public` and have the
-- function resolve to their table instead.
CREATE FUNCTION complete_chunk(p_chunk_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_verified timestamptz;
  v_status   text;
BEGIN
  SELECT c.status, m.verified_at
    INTO v_status, v_verified
    FROM chunks c
    LEFT JOIN chunk_metadata m ON m.chunk_id = c.id
   WHERE c.id = p_chunk_id
     FOR UPDATE OF c;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'BR-21: no such chunk (id=%)', p_chunk_id
      USING ERRCODE = 'no_data_found';
  END IF;

  IF v_verified IS NULL THEN
    RAISE EXCEPTION
      'BR-21: chunk % has no verified metadata; cannot complete', p_chunk_id
      USING ERRCODE = 'restrict_violation';
  END IF;

  IF v_status = 'complete' THEN
    -- Idempotent by design. Volume 5 Chapter 5.10 §3 requires a PATCH to
    -- 'complete' to be "a no-op if the chunk is already Complete", so a
    -- retried request after a dropped response must not fail.
    RETURN;
  END IF;

  -- Transaction-local, so the guard above re-arms the moment this commits.
  PERFORM set_config('vump.completing', 'on', true);
  UPDATE chunks SET status = 'complete' WHERE id = p_chunk_id;
  PERFORM set_config('vump.completing', 'off', true);
END;
$fn$;

COMMENT ON FUNCTION complete_chunk(uuid) IS
  'BR-21 gate. The only path to chunks.status = ''complete''. Idempotent (V5 Ch 5.10 §3).';
