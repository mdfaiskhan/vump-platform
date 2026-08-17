import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/cleanable_chunk.dart';
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
  /// empty. It is reported rather than assumed because external deletion and
  /// OS eviction both act on the file without telling this application.
  ///
  /// **Excludes chunks Chapter 5.15's sweep has already cleaned.** A cleaned
  /// row is a row whose file is deliberately gone, which is what this method
  /// looks for — so before Mission 4.5 added the exclusion, every successful
  /// cleanup would have reported itself as an orphan. Soft-deleted rows are
  /// therefore skipped, and the remaining answers are genuine surprises.
  Future<List<String>> orphanedChunkIds();

  /// Chunks whose local file Chapter 5.15 §2 allows to be deleted.
  ///
  /// §2's rule, and nothing wider: a chunk becomes eligible *"the instant the
  /// Upload Queue (Chapter 5.9) observes its status reach Complete"*, and
  /// rows already cleaned are excluded so a sweep cannot delete twice.
  ///
  /// **BR-08 is the whole of the filter.** §5 forbids deleting *"based on age
  /// alone, disk pressure alone, or any heuristic that isn't
  /// 'backend-confirmed Complete'"*, and BR-08 *"has no exception clause"*.
  /// There is deliberately no age parameter, no size parameter and no
  /// low-space override on this method, because a caller holding one would be
  /// holding the ability to violate the rule.
  ///
  /// [limit] bounds the batch. §2 wants the sweep batched *"to avoid
  /// competing with an active Recording Pipeline (Ch.5.4) for I/O"*; asking
  /// for one more than the batch needs is how the caller learns whether more
  /// work remains, without a second query.
  ///
  /// Returns them oldest-first by session start then sequence index, so a
  /// backlog drains in the order it accumulated.
  ///
  /// Throws a `StorageException` if the read fails.
  Future<List<CleanableChunk>> cleanableChunks({required int limit});

  /// Deletes one chunk's local file and records that it is gone.
  ///
  /// Chapter 5.15 §2: *"Only the raw video file (and its `local_chunks` row's
  /// file reference) is removed."* The `local_chunk_metadata` row is never
  /// touched — §3, FR-META-14 and BR-23 keep metadata queryable after its
  /// video is gone.
  ///
  /// **`localFilePath` is left as written, and `localDeletedAt` is the
  /// authoritative marker.** Blanking the path would put an empty-string
  /// sentinel in a column that is otherwise always a real path, which is the
  /// ambiguity A-068 exists to condemn; making it nullable is a schema change
  /// for no gain. The path is kept as a record of where the file *was*.
  ///
  /// Idempotent. A chunk already cleaned, already missing, or never eligible
  /// is a no-op rather than an error — a second sweep over the same rows must
  /// neither fail nor double-count.
  ///
  /// Returns true when this call deleted a file, false when there was nothing
  /// to delete.
  ///
  /// Throws a `StorageException` if the file could not be removed or the row
  /// could not be updated. The caller decides whether one failure abandons the
  /// batch; this method does not.
  Future<bool> deleteChunkFile(String chunkId);
}
