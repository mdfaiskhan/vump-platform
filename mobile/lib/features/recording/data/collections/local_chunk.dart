import 'package:isar/isar.dart';

part 'local_chunk.g.dart';

/// Volume 5 Chapter 5.8 §1's `local_chunks` table.
///
/// Mirrors Volume 4's `chunks` (Chapter 4.4 §6) — id, session_id,
/// sequence_index, s3_object_key, status, checksum_sha256, file_size_bytes,
/// local_deleted_at — and adds the one column Chapter 5.8 §1 says has *"no
/// backend equivalent"*: [localFilePath].
///
/// ## What this mission does and does not decide about `status`
///
/// The four values come from Volume 4: `queued`, `uploading`, `failed`,
/// `complete`. Chapter 5.8 §4 defers *"the queue semantics built on top of
/// `local_chunks.status`"* to Chapter 5.9, so this stores the value and
/// asserts nothing about transitions between them. A chunk written by this
/// mission is `queued`, which is what BR-07 means by a chunk having reached
/// local storage.
///
/// `local_deleted_at` is likewise stored and unused: BR-08 forbids deleting a
/// chunk before its upload confirms, and Chapter 5.15 owns when that happens.
@collection
class LocalChunk {
  /// Creates a stored chunk.
  LocalChunk();

  /// Isar's surrogate key.
  Id id = Isar.autoIncrement;

  /// The chunk UUID minted at capture-stop (Ch. 5.14 §3, Mission 3.4.5).
  ///
  /// Unique because Chapter 5.13 §4 requires every retry to reuse *"the exact
  /// same `chunk_id`"*, so a second row for one chunk would break the
  /// duplicate prevention BR-11 depends on.
  @Index(unique: true, replace: true)
  late String chunkId;

  /// The owning session's UUID — Volume 4's `chunks.session_id`.
  @Index()
  late String sessionId;

  /// Order within the session (Ch. 5.6 §2), zero-based.
  late int sequenceIndex;

  /// The deterministic S3 key from Chapter 5.14 §1.
  ///
  /// Null until the identity fields it needs exist: the key is
  /// `{org_id}/{project_id}/{task_id}/{session_id}/{sequence_index:04d}_{chunk_id}.mp4`
  /// and three of those five come from ports Mission 3.6 left unimplemented.
  /// Volume 4 marks the column UNIQUE and NOT NULL; storing null locally until
  /// it can be computed is the honest alternative to composing a key from
  /// placeholder ids.
  String? s3ObjectKey;

  /// `queued` | `uploading` | `failed` | `complete` — Volume 4's vocabulary.
  late String status;

  /// From Mission 3.4's `ChunkIntegrity`.
  late String checksumSha256;

  /// From Mission 3.4's `ChunkIntegrity`.
  late int fileSizeBytes;

  /// Where the finalized `.mp4` actually is.
  ///
  /// Chapter 5.8 §1: the column with *"no backend equivalent"*. Chapter 5.8 §2
  /// fixes the layout as
  /// `<app-documents>/recordings/{session_id}/{sequence_index:04d}.mp4`.
  late String localFilePath;

  /// BR-08 — set only once `status` is `complete`. Chapter 5.15 owns it.
  DateTime? localDeletedAt;

  /// Automatic attempts consumed against Chapter 5.13 §2's budget of six.
  ///
  /// Reset to zero by FR-UPL-07's manual retry (§3). Defaulted rather than
  /// `late` so that rows written before Mission 4.4 read back as 0 — Isar
  /// supplies the default for a property absent from an existing record.
  int uploadAttemptCount = 0;

  /// When Chapter 5.13 §2's backoff allows the next attempt, or null.
  ///
  /// Null means "eligible now": a chunk that has never failed, or one a manual
  /// retry has cleared. `ChunkUploadSource.claimNext` skips any row whose
  /// value is still in the future.
  DateTime? nextAttemptAt;
}

// NOTE — no schemaVersion bump accompanies these two fields, and that is the
// documented rule rather than an oversight. `DatabaseConstants.schemaVersion`
// says to increment "only when a change requires existing data to be
// transformed. Adding a collection or a nullable property does not qualify —
// Isar handles those implicitly." Both additions are of that kind: the
// `DateTime?` is nullable, and the `int` carries a default that Isar returns
// for records written before it existed.
//
// Mission 4.4 considered bumping to 2 with a migration and rejected it. There
// are no `Migration` implementations in this project yet, so the first one
// would have been a no-op written to satisfy a version number, and it would
// have run against real chunk rows already on a verified device. Amendment
// A-082 records the reasoning.
