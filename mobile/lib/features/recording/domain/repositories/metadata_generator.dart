import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';

/// Assembles Volume 4 Chapter 4.5's metadata object for one finalized chunk.
///
/// ## When this runs
///
/// Chapter 5.7 §1: generation begins *"the instant Chapter 5.5's Video
/// Processing completes for a chunk — not lazily on upload (FR-META-08)"*.
/// So it is called with the [ChunkIntegrity] that processing produced, after
/// it produced it — which since Mission 3.4.5 happens on a background isolate
/// while the next chunk may already be recording.
///
/// **The caller is `ChunkFinalizer`, not the notifier.** Volume 3 Chapter 3.9
/// §4 names `FinalizeChunkUseCase` as *"the one place that knows a chunk must
/// be chunked, checksummed, and have its metadata generated together,
/// atomically, per FR-META-08"*. That use case is this port's caller and does
/// not exist yet; wiring generation into `RecordingNotifier` directly would
/// duplicate the seam Mission 3.2 already declared for it.
///
/// ## What it does not do
///
/// It does not persist. Chapter 5.7 §3 requires the object be written *"in
/// the same transaction as the chunk's own local record"*, which needs
/// Mission 3.7's storage layer — and names Drift, where ADR-009 chose Isar.
/// Both are recorded in amendment A-062.
abstract interface class MetadataGenerator {
  /// Builds the metadata for [job]'s chunk.
  ///
  /// Throws a `DeviceException` if a required context value cannot be read.
  Future<ChunkMetadata> generate({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkIntegrity integrity,
    required DateTime chunkStartedAt,
  });
}
