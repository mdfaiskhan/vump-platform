import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';

/// Volume 5 Chapter 5.5 — turns a finalized recording into a trustworthy one.
///
/// ## Container finalization is not in this port, because it already happened
///
/// §1.1 defines finalization as the `.mp4`'s *"moov atom … written and the
/// file handle … closed"*. That is exactly what `stopVideoRecording` does:
/// `camera_android_camerax` awaits `VideoRecordEventFinalize` before returning
/// the file, with the comment *"wait for the video recording to be
/// finalized"*. By the time `RecordingPipeline.stopChunk` hands over a path,
/// the file is already valid and closed.
///
/// So there is no Dart finalization step to write, and none could be written —
/// amendment A-058 records that the muxer lives inside CameraX's `Recorder`
/// and is unreachable from this layer. This port covers §1.2 and §1.3 only.
///
/// ## No container validation, deliberately
///
/// It does not check whether the `.mp4` is truncated or playable. §1 stops at
/// moov-plus-close, and NFR-META-02 assigns catching *"corrupted or truncated
/// chunk uploads"* to verification at upload time against the checksum this
/// port computes. Local processing computes and stores; the backend compares.
///
/// ## Why this is a port at all
///
/// Hashing is pure computation over a file, with no third-party type in its
/// signature — it could have been a static function. It is a port because §2
/// requires the work to run *"on a background isolate/thread separate from the
/// UI"*, and an isolate is exactly the kind of platform detail `domain/` must
/// not name. The implementation owns that; callers await a result.
abstract interface class VideoProcessor {
  /// Computes the checksum and byte count for the finalized chunk at [path].
  ///
  /// Throws a `StorageException` if the file cannot be read — which at this
  /// point means it was moved or deleted between finalization and processing,
  /// since the pipeline only hands over paths the platform has already closed.
  Future<ChunkIntegrity> process(String path);
}
