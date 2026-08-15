import 'package:freezed_annotation/freezed_annotation.dart';

part 'chunk_processing_job.freezed.dart';

/// One chunk being processed in the background, after its capture has ended.
///
/// Created at the moment capture stops for a chunk — when
/// `stopVideoRecording()` has returned, the `.mp4` is closed and complete on
/// disk, and the camera is free again. Everything Chapter 5.5 does to that
/// file (checksum, byte count) and everything Chapters 5.7 and 5.9 will do
/// after it happens while this job is in flight.
///
/// ## Why this exists at all
///
/// Mission 3.2 treated finalization as something the state machine waited
/// through, so the camera sat idle for the whole of it. Mission 3.4.4 measured
/// that wait at roughly twelve seconds and found it was **not** a hardware
/// constraint: `stopVideoRecording` returns only after
/// `VideoRecordEventFinalize`, so the file is already persisted and the camera
/// already free before any of the processing begins. Amendment A-061 records
/// the correction.
///
/// Separating the two turns "finalizing" from a state the machine occupies
/// into work the machine tracks. This is the thing being tracked.
///
/// ## The identity fields are minted once, here
///
/// [sequenceIndex] and [chunkId] are both fixed when the job is created and
/// never recomputed. Chapter 5.13 §4 requires exactly that of `chunk_id`:
/// *"Every retry — automatic or manual — reuses the exact same `chunk_id`, the
/// exact same deterministic S3 key … there is structurally no code path that
/// generates a new key for the same chunk."* A value minted at completion, or
/// recomputed on retry, would break that by construction.
@freezed
class ChunkProcessingJob with _$ChunkProcessingJob {
  /// Creates a job for a chunk whose capture has just ended.
  const factory ChunkProcessingJob({
    /// The UUID identifying this chunk for its whole life (Ch. 5.14 §3).
    required String chunkId,

    /// Its position within the session (Ch. 5.6 §2), fixed at capture-stop.
    required int sequenceIndex,

    /// The closed `.mp4` the platform wrote.
    required String filePath,

    /// When capture stopped and processing became possible.
    required DateTime startedAt,
  }) = _ChunkProcessingJob;
}
