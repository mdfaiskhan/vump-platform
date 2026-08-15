import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';

/// Persists a finalized chunk and its metadata together.
///
/// Volume 5 Chapter 5.7 §3 states the contract this port exists for: the
/// metadata object is written *"in the same transaction as the chunk's own
/// local record — both succeed or both fail together, so a chunk file can
/// never exist locally without its metadata already alongside it"*. That is
/// FR-META-09, and it is why [saveChunk] takes both and returns nothing
/// partial.
///
/// ## What it also does, because it must happen atomically with the record
///
/// The `.mp4` is moved from wherever the camera plugin wrote it into Chapter
/// 5.8 §2's layout before the transaction commits, so a committed row always
/// names a file that is already in place. The reverse order would allow a
/// record pointing at a path nothing had written yet.
abstract interface class ChunkStore {
  /// Saves the session, chunk and metadata for one finalized chunk.
  ///
  /// Throws a `StorageException` if the file cannot be placed or the
  /// transaction cannot commit. On failure nothing is written — no row, and
  /// the source file is left where it was.
  Future<void> saveChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkMetadata metadata,
  });

  /// Marks a session `complete` — FR-SES-02's other half.
  ///
  /// **This closes amendment A-063's first open gap.** `saveChunk` is called
  /// per chunk and cannot tell the last one from a middle one, so the session
  /// row is written `in_progress` and left alone. The end of a session is
  /// known in exactly one place — the lifecycle's return to `Idle` after
  /// draining — and this is what that place calls.
  ///
  /// Idempotent, and a no-op for a session with no rows: a session that ended
  /// before producing a chunk never reached storage, and inventing a row for
  /// it here would record a session that captured nothing.
  Future<void> markSessionComplete(String sessionId);

  /// Chunks that survived a crash and can still be uploaded.
  ///
  /// Volume 5 Chapter 5.3 §5's crash recovery, as far as it is achievable —
  /// see `IsarChunkStore` for what is not.
  Future<List<String>> recoverableChunkIds();

  /// Chunk ids whose row survived but whose file did not.
  ///
  /// A row is only committed after its file is in place, so this should be
  /// empty. It is reported rather than assumed because storage cleanup,
  /// external deletion and OS eviction all act on the file without telling
  /// this application.
  Future<List<String>> orphanedChunkIds();
}
