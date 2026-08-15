import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_finalizer.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_store.dart';
import 'package:mobile/features/recording/domain/repositories/metadata_generator.dart';
import 'package:mobile/features/recording/domain/repositories/video_processor.dart';

/// Volume 3 Chapter 3.9 §4's `FinalizeChunkUseCase` — the three chapters
/// joined.
///
/// Missions 3.4, 3.6 and 3.7 each built one piece and each stopped at its own
/// boundary. Nothing composed them, so `chunkFinalizerProvider` had no
/// implementation and the first chunk boundary would have thrown an
/// `UnimplementedError` out of an unawaited future. This is that composition,
/// and it is the whole of it.
///
/// ```text
/// stopChunk() returns a closed .mp4
///        │
///        ▼
///   VideoProcessor      Ch. 5.5 — SHA-256 + byte count, off the UI isolate
///        │
///        ▼
///   MetadataGenerator   Ch. 5.7 — Volume 4 Ch. 4.5's object
///        │
///        ▼
///   ChunkStore          Ch. 5.8 — one writeTxn, file moved into place first
/// ```
///
/// ## The order is forced, not chosen
///
/// The checksum must exist before metadata, because `integrity` is one of
/// Chapter 4.5's seven groups. Metadata must exist before the store, because
/// Chapter 5.7 §3 requires the chunk row and its metadata be written in **one
/// transaction** — FR-META-09's *"a chunk file can never exist locally without
/// its metadata already alongside it"*. There is no rearrangement of these
/// three that still satisfies both.
///
/// ## No error handling here, deliberately
///
/// Every step throws an `AppException` on failure and this adds no `try`.
/// `RecordingNotifier._processChunk` already catches, records the
/// `ErrorCode` on the chunk, and leaves the session alone — Chapter 5.13 §1's
/// treatment of a device-side terminal failure as *"a status on the chunk, not
/// on the recording"*. Catching here would either duplicate that or, worse,
/// swallow a failure the state machine needs to see.
///
/// **What that means concretely:** a chunk whose checksum fails is marked
/// failed and the camera keeps recording. Ending a live capture because an
/// earlier chunk could not be hashed would destroy footage that is being
/// recorded correctly.
///
/// ## `chunkStartedAt` is a parameter because the job does not carry it
///
/// `ChunkProcessingJob.startedAt` is the instant capture **stopped** — Mission
/// 3.4.5 named it for when *processing* became possible. Chapter 5.7 §2 wants
/// the instant capture **began**, which lives on `RecordingStateRecording`.
/// Composing these three ports for the first time is what exposed the gap:
/// passing the job's own timestamp would have set `timing.started_at` equal to
/// `timing.ended_at` and reported every chunk as zero seconds long, in a field
/// Chapter 4.5 derives `duration_seconds` from. The state machine holds the
/// right value, so it passes it.
class FinalizeChunkUseCase implements ChunkFinalizer {
  /// Creates the use case over the three ports it composes.
  const FinalizeChunkUseCase({
    required VideoProcessor videoProcessor,
    required MetadataGenerator metadataGenerator,
    required ChunkStore chunkStore,
  }) : _processor = videoProcessor,
       _metadata = metadataGenerator,
       _store = chunkStore;

  final VideoProcessor _processor;
  final MetadataGenerator _metadata;
  final ChunkStore _store;

  @override
  Future<void> finalizeChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required DateTime chunkStartedAt,
  }) async {
    final ChunkIntegrity integrity = await _processor.process(job.filePath);

    final ChunkMetadata metadata = await _metadata.generate(
      session: session,
      job: job,
      integrity: integrity,
      chunkStartedAt: chunkStartedAt,
    );

    await _store.saveChunk(session: session, job: job, metadata: metadata);
  }
}
