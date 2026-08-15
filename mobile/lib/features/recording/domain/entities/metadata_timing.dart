import 'package:freezed_annotation/freezed_annotation.dart';

part 'metadata_timing.freezed.dart';

/// The `timing` group of Volume 4 Chapter 4.5's metadata schema.
///
/// Fully sourced. Chapter 5.7 §2 takes `sequence_index` from Chapter 5.6 and
/// the timestamps from the Recording Pipeline; since Mission 3.4.5 both are
/// fixed at capture-stop, before any processing runs, so they describe the
/// capture rather than when the hashing happened to finish.
@freezed
class MetadataTiming with _$MetadataTiming {
  /// Creates the timing group.
  const factory MetadataTiming({
    /// From `ChunkProcessingJob.sequenceIndex` (Mission 3.4.5).
    required int sequenceIndex,

    /// From `RecordingStateRecording.chunkStartedAt` (Mission 3.4.5).
    required DateTime startedAt,

    /// From `ChunkProcessingJob.startedAt` — the instant capture stopped.
    required DateTime endedAt,
  }) = _MetadataTiming;

  const MetadataTiming._();

  /// `duration_seconds` in the wire format — derived, never stored twice.
  ///
  /// Ch. 4.5's example shows 600 for a full chunk. Computing it rather than
  /// carrying it means it cannot disagree with the timestamps it comes from.
  int get durationSeconds => endedAt.difference(startedAt).inSeconds;
}
