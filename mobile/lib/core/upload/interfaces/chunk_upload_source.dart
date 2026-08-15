import 'package:mobile/core/upload/uploadable_chunk.dart';

/// The pipeline's view of the same rows `ChunkQueueSource` shows C-11.
///
/// Volume 5 Chapter 5.9 §5 defers *"what actually moves a chunk from Queued to
/// Uploading to Complete"* to Chapters 5.10 and 5.11. `ChunkQueueSource`
/// therefore exposes no transition at all, and its own doc says why: *"adding
/// the methods now would invite a caller before there is a pipeline behind
/// them."* This is that pipeline, and this is where those methods live.
///
/// ## Two contracts over one table, on purpose
///
/// `IsarChunkStore` implements both. Splitting them is not filing — it is what
/// stops C-11 from being able to move a chunk and stops the pipeline from
/// being able to read a file path it has no business knowing about through the
/// screen's contract. Each caller can reach exactly what its chapter gives it.
///
/// ## Why `claimNext` takes no argument
///
/// Ordering is Chapter 5.9 §2's, and it belongs to the source. A method taking
/// a chunk id would let a caller upload out of order by accident — and FIFO by
/// session start time is not a preference here, it is what stops *"an earlier
/// session's chunks … being starved by a later session's"*.
///
/// ## What is deliberately absent
///
/// No attempt counter, no backoff deadline, no multipart upload id. Chapter
/// 5.13 owns retry timing and Chapter 5.11 owns backgrounding; fields for
/// either would be state with no policy behind it, which is the same mistake
/// this contract exists to avoid.
abstract interface class ChunkUploadSource {
  /// Claims the next `queued` chunk, moving it to `uploading`.
  ///
  /// Returns the chunk in Chapter 5.9 §2's order — earliest session first,
  /// then lowest sequence index. Returns null when nothing is claimable.
  ///
  /// **Atomic.** Two concurrent callers never receive the same chunk: the read
  /// and the status write happen in one transaction, so a chunk observed as
  /// `queued` cannot be claimed twice. Chapter 5.11's dispatcher will run
  /// several of these at once, and a chunk uploaded twice would defeat BR-11's
  /// duplicate prevention at the one point S3's own semantics cannot help.
  ///
  /// Skips soft-deleted rows (BR-08) and rows whose stored status is not one
  /// this application recognises.
  ///
  /// Throws a `StorageException` if the transaction fails.
  Future<UploadableChunk?> claimNext();

  /// Stores the key the backend returned at registration.
  ///
  /// Volume 4 Chapter 4.10 §2 step 1: the Lambda computes the deterministic
  /// key and returns it. Recorded locally so a resumed attempt after a dropped
  /// response can reuse it, which is half of Chapter 5.13 §4's *"the exact
  /// same deterministic S3 key"* guarantee — the other half being that the
  /// backend recomputes the same key anyway.
  ///
  /// Throws a `StorageException` if the write fails.
  Future<void> recordObjectKey({
    required String chunkId,
    required String s3ObjectKey,
  });

  /// Returns a claimed chunk to `queued` without failing it.
  ///
  /// For an attempt abandoned rather than lost: a cancellation (Chapter 5.10
  /// §4), a pause, or an app teardown mid-transfer. Chapter 5.13 §1 does not
  /// list cancellation among its failure types, so a paused chunk must not
  /// consume one of §2's six automatic attempts.
  ///
  /// The chunk returns to its original position by construction — order is
  /// derived from the session start time and the sequence index, and neither
  /// changed.
  ///
  /// Ignores a chunk that is not currently `uploading`.
  Future<void> release(String chunkId);

  /// Moves a chunk to `failed`.
  ///
  /// Chapter 5.13 §1's two terminal classes, and a transient failure whose
  /// attempts are exhausted. Surfaces C-11's Retry Chunk action (FR-UPL-07),
  /// which re-enters through `ChunkQueueSource.requeue`.
  ///
  /// Ignores a chunk that is not currently `uploading`.
  Future<void> markFailed(String chunkId);

  /// Moves a chunk to `complete`.
  ///
  /// **Called after Chapter 5.10 §1 step 4, not step 3.** The chapter places
  /// `complete` at step 3's `PATCH`, and this deliberately diverges — see
  /// `ChunkUploadPipeline` and amendment A-073. In short: BR-08 makes
  /// `complete` the point a chunk becomes eligible for local deletion (Chapter
  /// 5.15), and deleting a chunk whose metadata never reached the backend
  /// would be unrecoverable. Ordering the local write after the metadata POST
  /// costs nothing and closes that window.
  ///
  /// Ignores a chunk that is not currently `uploading`, so a duplicate call
  /// after a dropped response is a no-op rather than a contradiction of BR-12.
  Future<void> markComplete(String chunkId);
}
