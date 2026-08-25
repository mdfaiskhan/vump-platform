-- 0017 — two things about how a chunk was captured that nothing recorded.
--
-- ## Why one migration and not two
--
-- The two columns belong to different metadata groups — `capture` and
-- `capture_conditions` — and have different nullability reasoning, which is a
-- real argument for splitting them. They are together anyway because **the
-- metadata Lambda's INSERT is a single statement naming every column**. Split
-- across 0017 and 0018, a half-applied pair leaves that INSERT referring to a
-- column that does not exist, so the two would have to be applied together to
-- be useful. A migration boundary that can never be crossed independently is
-- not a boundary; it is two files pretending to be separable.
--
-- ## `capture_orientation` (ADR-054 §6)
--
-- ADR-054 fixes capture orientation to landscape, which every chunk before it
-- did not have. The pixels and the resolution string are identical either way —
-- both are 1920x1080 — and **only the container's rotation tag differs**, so
-- footage from before and after the change is otherwise indistinguishable.
--
-- ADR-054 §6 states the consequence: *"a dataset that changes a capture
-- parameter without recording it loses the ability to tell its own footage
-- apart."* This column is what keeps them apart.
--
-- **Nullable, with no default, and no backfill.** A NULL means "recorded before
-- anything wrote this", which is the truth for every existing row. Inventing a
-- value for chunks nobody measured would make an unmeasured property look
-- measured — the failure open item 152 warns about and that
-- `MetadataCaptureConditions` was deliberately designed to avoid: *"a
-- plausible-looking wrong value is harder to catch than an obvious empty one."*
--
-- The value is a wire spelling — `landscape-left`, `portrait-up` — following
-- `codec`'s precedent of storing the wire name rather than a platform enum.
-- **It records what the device actually did**, not what the build intends: it
-- is read from the pipeline per session, so a build without ADR-054's lock
-- honestly reports whatever orientation the handset produced.
--
-- ## `thermal_state`
--
-- Android's `PowerManager.getCurrentThermalStatus()`, 0 (`THERMAL_STATUS_NONE`)
-- through 6 (`THERMAL_STATUS_SHUTDOWN`), read at chunk finalization alongside
-- the other capture conditions per Chapter 5.7 §2.
--
-- Stored as the platform's own integer rather than translated to a name, so
-- there is no mapping layer between what the OS reported and what the row says.
-- The CHECK is what documents the range to a reader of the schema alone.
--
-- Mission 8.2 scenario 3 measured a 25-minute session climbing monotonically
-- through the thermal levels with no throttle event. That was read through
-- `adb`, from outside the app, by a human — **nothing the app ships could
-- report it**. A chunk recorded at status 3 is plausibly different footage from
-- one recorded at 0, and until now the difference was unrecoverable.
--
-- **Nullable for the same reason `battery_pct` is**: Chapter 4.4 §7's
-- "nullable where permission/condition dependent". A platform that cannot
-- report thermal status records NULL rather than a guess.
--
-- iOS reports a four-level `ProcessInfo.thermalState` on a different scale.
-- Mapping the two is a real question and is **not** answered here — this
-- project ships Android, and inventing a cross-platform scale before the second
-- platform exists is the kind of early abstraction ADR-011 declined to make.
ALTER TABLE chunk_metadata
  ADD COLUMN capture_orientation text,
  ADD COLUMN thermal_state       integer;

ALTER TABLE chunk_metadata
  ADD CONSTRAINT chunk_metadata_thermal_state_range
  CHECK (thermal_state IS NULL OR thermal_state BETWEEN 0 AND 6);

COMMENT ON COLUMN chunk_metadata.capture_orientation IS
  'Wire spelling of the orientation the chunk was captured at, e.g. '
  '"landscape-left". NULL for chunks recorded before ADR-054. Read from the '
  'pipeline, so it reports what the device did rather than what the build '
  'intends.';

COMMENT ON COLUMN chunk_metadata.thermal_state IS
  'Android PowerManager.getCurrentThermalStatus() at chunk finalization, 0 '
  '(NONE) to 6 (SHUTDOWN). NULL where the platform cannot report it.';
