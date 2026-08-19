import 'package:mobile/features/recording/data/collections/embedded/embedded_capture.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_capture_conditions.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_collector_authored.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_device_context.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_gps_fix.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_identity.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_integrity.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_timing.dart';
import 'package:mobile/features/recording/data/collections/local_chunk.dart';
import 'package:mobile/features/recording/data/collections/local_chunk_metadata.dart';
import 'package:mobile/features/recording/data/collections/local_session.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/gps_fix.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';

/// Converts Mission 3.6's domain objects into Chapter 5.8 §1's stored rows.
///
/// ADR-030 calls this the conversion boundary: `isar` is confined to this
/// feature's `data/` layer, and nothing above it sees a `Local*` type. Every
/// crossing happens here, in one file, so the shape difference between the two
/// sides is legible in a single place rather than distributed across a store.
///
/// ## The two sides disagree about nullability, deliberately
///
/// The domain requires what Chapter 4.5 requires — `MetadataIdentity`'s five
/// fields are all non-null, because *"a chunk that cannot say which Task it
/// belongs to or who recorded it is not a valid record"*. The stored types
/// make everything nullable, because Isar needs a default constructor and a
/// row written by an older build must still open under a newer schema.
///
/// Widening on the way in is safe. Narrowing on the way out is not, which is
/// why there is no reverse mapper here — see [ChunkRecordMapper] class docs
/// below on read-back.
///
/// ## There is no `fromLocal*`, and that is a decision
///
/// Reading a `ChunkMetadata` back would have to supply a value for each
/// required field, and today those fields are stored **null** — `project_id`,
/// `task_id`, `collector_id` and `device_id` have no source until
/// `features/projects_tasks/` and Mission 3.6's `DeviceContext` port exist
/// (A-062). A reverse mapper written now would have to substitute empty
/// strings, and an empty `collector_id` that reached an upload would be
/// indistinguishable from a real one.
///
/// The consumer that needs read-back is the Upload Queue, Chapter 5.9, which
/// is a later mission. It is left unwritten rather than written wrong.
///
/// **Discharged 2026-08-15, Mission 4.2 — and the hazard above was answered,
/// not overruled.** `ChunkMetadataDocumentMapper` now reads a stored row back,
/// but it does not produce a `ChunkMetadata`: it produces a
/// `ChunkMetadataDocument`, whose identity fields are **nullable**. So nothing
/// is substituted — a stored null arrives as null, a stored blank arrives as
/// blank — and `ChunkMetadataDocument.isIdentityComplete` (A-068 Guard 1)
/// refuses it before any network call. The narrowing that made a reverse
/// mapper unsafe never happens.
///
/// There is still no reverse mapper *here*, and there should not be. The
/// unsafe direction is the one that produces a domain object with five
/// required fields from a row with five nullable ones, and that direction is
/// still unwritten. See amendment A-071.
abstract final class ChunkRecordMapper {
  /// `local_chunks.status` for a chunk written to disk and not yet uploaded.
  ///
  /// Volume 4's vocabulary. BR-07 treats reaching local storage as the point
  /// a chunk becomes the Upload Queue's problem, and this is that point.
  static const String statusQueued = 'queued';

  /// `local_sessions.status` while a session is still recording (FR-SES-02).
  static const String sessionInProgress = 'in_progress';

  /// `local_sessions.status` once the session has ended (FR-SES-02).
  ///
  /// Defined for completeness; nothing in this mission writes it. The
  /// transition belongs to the lifecycle's return to `Idle`, and no path
  /// implements it yet — recorded in amendment A-063.
  static const String sessionComplete = 'complete';

  /// Builds the session row.
  ///
  /// `taskId` and `collectorId` are null because their sources do not exist
  /// (A-062), not because they are optional. They are stored nullable so a
  /// session recorded today can be back-filled rather than recreated.
  static LocalSession toLocalSession(RecordingSession session) {
    return LocalSession()
      ..sessionId = session.sessionId
      // Both null until Mission 7.4 step 5, and both written now. This row is
      // where Task context becomes durable — the upload queue reads `taskId`
      // from it at claim time, long after the recording and any number of
      // process deaths later. F38.
      ..taskId = session.taskId
      ..projectId = session.projectId
      ..startedAt = session.startedAt
      ..status = sessionInProgress;
  }

  /// Builds the chunk row.
  ///
  /// `checksumSha256` and `fileSizeBytes` are copied out of [metadata]'s
  /// `integrity` group rather than re-derived: Volume 4's `chunks` table
  /// carries them in its own right so the Upload Queue can read them without
  /// loading metadata, and copying one source into two columns keeps them
  /// from disagreeing.
  ///
  /// `s3ObjectKey` stays null, but **not for the reason first recorded here.**
  ///
  /// ~~Chapter 5.14 §1's key is
  /// `{org_id}/{project_id}/{task_id}/{session_id}/{sequence_index:04d}_{chunk_id}.mp4`
  /// and three of those five have no source yet; composing it from
  /// placeholders would produce a key that looks deterministic and is not.~~
  ///
  /// **Corrected 2026-08-15, Mission 4.2.** That premise assumed the client
  /// composes the key. It does not. Volume 4 Chapter 4.10 §2 step 1: *"the
  /// Lambda computes the deterministic key (Volume 5.14) and returns"* it, and
  /// Chapter 4.6 §5 shows `s3_object_key` as a **response** field of chunk
  /// registration, whose request body carries only `sequence_index`,
  /// `file_size_bytes` and `checksum_sha256`. Chapter 5.14 §1 is authoritative
  /// for both sides, but the client's own use of it is §2's *local* path,
  /// which omits org/project/task entirely.
  ///
  /// So the field is null here because **registration has not happened yet**,
  /// not because the key cannot be computed.
  /// `ChunkUploadSource.recordObjectKey` fills it from the registration
  /// response. Amendment A-071 corrects the register entry that carried the
  /// same wrong premise.
  static LocalChunk toLocalChunk({
    required ChunkProcessingJob job,
    required RecordingSession session,
    required ChunkMetadata metadata,
    required String localFilePath,
  }) {
    return LocalChunk()
      ..chunkId = job.chunkId
      ..sessionId = session.sessionId
      ..sequenceIndex = job.sequenceIndex
      ..status = statusQueued
      ..checksumSha256 = metadata.integrity.checksumSha256
      ..fileSizeBytes = metadata.integrity.byteCount
      ..localFilePath = localFilePath;
  }

  /// Builds the metadata row, group by group.
  ///
  /// Chapter 5.8 §1 requires *"identical field shape to Volume 4, Chapter
  /// 4.5's JSON"*, so the seven groups are preserved as embedded objects and
  /// nothing is flattened.
  static LocalChunkMetadata toLocalMetadata(ChunkMetadata metadata) {
    return LocalChunkMetadata()
      ..chunkId = metadata.chunkId
      ..identity = _identity(metadata)
      ..timing = _timing(metadata)
      ..capture = _capture(metadata)
      ..deviceContext = _deviceContext(metadata)
      ..captureConditions = _captureConditions(metadata)
      ..integrity = _integrity(metadata)
      ..collectorAuthored = _collectorAuthored(metadata);
  }

  static EmbeddedIdentity _identity(ChunkMetadata metadata) {
    return EmbeddedIdentity()
      ..sessionId = metadata.identity.sessionId
      ..projectId = metadata.identity.projectId
      ..taskId = metadata.identity.taskId
      ..collectorId = metadata.identity.collectorId
      ..deviceId = metadata.identity.deviceId;
  }

  /// `durationSeconds` is not stored — the domain derives it from the two
  /// timestamps, and a stored copy could disagree with them.
  static EmbeddedTiming _timing(ChunkMetadata metadata) {
    return EmbeddedTiming()
      ..sequenceIndex = metadata.timing.sequenceIndex
      ..startedAt = metadata.timing.startedAt
      ..endedAt = metadata.timing.endedAt;
  }

  static EmbeddedCapture _capture(ChunkMetadata metadata) {
    return EmbeddedCapture()
      ..resolution = metadata.capture.resolution
      ..frameRate = metadata.capture.frameRate
      ..bitrateKbps = metadata.capture.bitrateKbps
      ..codec = metadata.capture.codec
      ..zoomFactor = metadata.capture.zoomFactor
      ..camera = metadata.capture.camera;
  }

  static EmbeddedDeviceContext _deviceContext(ChunkMetadata metadata) {
    return EmbeddedDeviceContext()
      ..deviceModel = metadata.deviceContext.deviceModel
      ..osVersion = metadata.deviceContext.osVersion
      ..appVersion = metadata.deviceContext.appVersion;
  }

  /// A missing fix is stored as an `EmbeddedGpsFix` with both coordinates
  /// null, not as a fix at (0, 0).
  ///
  /// Isar cannot represent an absent embedded object, so the absence has to
  /// live in the fields. `MetadataCaptureConditions` documents why zeroes were
  /// rejected: `{0.0, 0.0}` is a real place in the Gulf of Guinea, and a
  /// plausible wrong value is harder to catch than an obviously empty one.
  static EmbeddedCaptureConditions _captureConditions(ChunkMetadata metadata) {
    final GpsFix? fix = metadata.captureConditions.gps;
    return EmbeddedCaptureConditions()
      ..gps = (EmbeddedGpsFix()
        ..latitude = fix?.latitude
        ..longitude = fix?.longitude)
      ..batteryPercent = metadata.captureConditions.batteryPercent
      ..networkType = metadata.captureConditions.networkType;
  }

  static EmbeddedIntegrity _integrity(ChunkMetadata metadata) {
    return EmbeddedIntegrity()
      ..checksumSha256 = metadata.integrity.checksumSha256
      ..byteCount = metadata.integrity.byteCount;
  }

  /// Empty at generation, always — Chapter 5.7 §2. Copied rather than
  /// hard-coded so Phase 2 (C-13) has nothing to change here.
  static EmbeddedCollectorAuthored _collectorAuthored(ChunkMetadata metadata) {
    return EmbeddedCollectorAuthored()
      ..notes = metadata.collectorAuthored.notes
      ..tags = List<String>.of(metadata.collectorAuthored.tags);
  }
}
