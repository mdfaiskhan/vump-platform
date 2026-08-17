-- 0004 — sessions, chunks and chunk_metadata.

CREATE TABLE sessions (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id      uuid        NOT NULL REFERENCES tasks (id),
  collector_id uuid        NOT NULL REFERENCES users (id),
  started_at   timestamptz NOT NULL DEFAULT now(),
  status       text        NOT NULL DEFAULT 'in_progress',
  -- Phase 2 (FR-SEC-01). Nullable, and nothing writes it yet.
  notes        text,

  CONSTRAINT sessions_status_check CHECK (status IN ('in_progress', 'complete'))
);

CREATE INDEX sessions_task_id_idx ON sessions (task_id);
CREATE INDEX sessions_collector_id_idx ON sessions (collector_id);

CREATE TABLE chunks (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id       uuid        NOT NULL REFERENCES sessions (id),
  sequence_index   integer     NOT NULL,
  -- BR-11's "never a duplicate object" guarantee. Volume 4 Chapter 4.10 §2
  -- step 4 calls the uniqueness "structural, not just a hope", and this is
  -- where it is structural. The key already contains the sequence index
  -- (Volume 5 Ch 5.14), so this also makes (session_id, sequence_index) unique
  -- transitively — no second constraint is needed.
  s3_object_key    text        NOT NULL UNIQUE,
  status           text        NOT NULL DEFAULT 'queued',
  checksum_sha256  text        NOT NULL,
  file_size_bytes  bigint      NOT NULL,
  local_deleted_at timestamptz,

  CONSTRAINT chunks_status_check
    CHECK (status IN ('queued', 'uploading', 'failed', 'complete')),

  -- BR-08: "no chunk deleted before S3 confirms". Chapter 4.2 §3 states it as
  -- "local_deleted_at can only be set once chunks.status = 'complete'", which
  -- is expressible as a row constraint and therefore is one.
  CONSTRAINT chunks_local_delete_requires_complete
    CHECK (local_deleted_at IS NULL OR status = 'complete'),

  CONSTRAINT chunks_sequence_index_non_negative CHECK (sequence_index >= 0),
  CONSTRAINT chunks_file_size_positive CHECK (file_size_bytes > 0)
);

CREATE INDEX chunks_session_id_idx ON chunks (session_id);

CREATE TABLE chunk_metadata (
  -- Chapter 4.3: 1:1 with chunks, "ON DELETE RESTRICT — a chunk row is never
  -- hard-deleted while its metadata must outlive it per BR-23".
  chunk_id          uuid        PRIMARY KEY REFERENCES chunks (id) ON DELETE RESTRICT,

  -- FR-META-02
  captured_start_at timestamptz NOT NULL,
  captured_end_at   timestamptz NOT NULL,

  -- FR-META-03. `bitrate_kbps` rather than Chapter 4.4's `bitrate`: Chapter 4.5
  -- §2's canonical wire shape names it `bitrate_kbps` and gives 8000, so the
  -- unit is kbps and only one of the two chapters says so (A-155).
  -- `camera` has no column in Chapter 4.4 and is required by Chapter 4.5 §2.
  resolution        text        NOT NULL,
  frame_rate        integer     NOT NULL,
  bitrate_kbps      integer     NOT NULL,
  codec             text        NOT NULL,
  zoom_factor       numeric     NOT NULL,
  camera            text        NOT NULL,

  -- FR-META-04. `device_id` is Chapter 4.5 §2's `identity.device_id`, which
  -- Chapter 4.4 also has no column for. The other identity fields are
  -- reachable by joining chunks → sessions → tasks → projects and are
  -- deliberately not duplicated here.
  device_model      text        NOT NULL,
  os_version        text        NOT NULL,
  app_version       text        NOT NULL,
  device_id         text        NOT NULL,

  -- FR-META-05 — nullable "where permission/condition dependent".
  gps_lat           numeric,
  gps_lng           numeric,
  battery_pct       integer,
  network_type      text,

  -- FR-META-07, BR-22: the one Collector-editable field.
  notes_tags        jsonb,

  -- FR-META-12: set once the backend confirms the checksum matches.
  verified_at       timestamptz,

  CONSTRAINT chunk_metadata_capture_window CHECK (captured_end_at >= captured_start_at),
  CONSTRAINT chunk_metadata_battery_range
    CHECK (battery_pct IS NULL OR (battery_pct BETWEEN 0 AND 100))
);

COMMENT ON COLUMN chunk_metadata.notes_tags IS
  'The only column BR-22 permits to change after insert. Enforced by the trigger in 0006.';
