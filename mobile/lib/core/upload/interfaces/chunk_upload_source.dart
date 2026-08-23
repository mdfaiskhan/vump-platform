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
/// ## What was deliberately absent, and what arrived with its policy
///
/// This contract originally carried *"no attempt counter, no backoff deadline,
/// no multipart upload id"*, on the ground that Chapter 5.13 owned retry
/// timing and fields without a policy behind them are the mistake this
/// contract exists to avoid.
///
/// **Mission 4.4 is that policy**, so the first two arrived with it:
/// [deferAttempt] records both, and [claimNext] honours the deadline. The
/// reasoning is unchanged — they are here now because Chapter 5.13 §2's
/// schedule is implemented, not because a field looked useful.
///
/// **The multipart upload id is still absent, and still deliberately.**
/// Chapter 5.13 §4 wants a retry to reuse *"where possible the same
/// in-progress multipart upload ID"*, which needs the backend to hand one back
/// — `SessionRegistrar` has no implementation and open item 36 blocks it. A
/// field for it now would be exactly the state-without-policy this paragraph
/// warns about. NFR-REL-02's *"resume without restarting from zero"* is
/// therefore not satisfied; A-084 records that plainly rather than leaving it
/// to be discovered.
abstract interface class ChunkUploadSource {
  /// Claims the next eligible `queued` chunk, moving it to `uploading`.
  ///
  /// Returns the chunk in Chapter 5.9 §2's order — earliest session first,
  /// then lowest sequence index. Returns null when nothing is claimable.
  ///
  /// **Skips chunks still inside Chapter 5.13 §2's backoff window** — a row
  /// whose `nextAttemptAt` is after [now] is not eligible, however far forward
  /// in the queue it sits. Chapter 5.13 §1 requires a transient failure to be
  /// retried on a schedule rather than immediately, and a chunk that stayed
  /// claimable would be retried in a tight loop and burn its six attempts in
  /// milliseconds.
  ///
  /// [now] is supplied by the caller rather than read here, because the caller
  /// holds the `Clock` (Volume 9 Chapter 9.6 §2, A-045) and a store that read
  /// the wall clock itself would put an untestable branch inside a
  /// transaction.
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
  Future<UploadableChunk?> claimNext({required DateTime now});

  /// Returns a chunk to `queued` after a transient failure, on a schedule.
  ///
  /// Chapter 5.13 §1 is explicit that a transient failure is *"never surfaced
  /// to the Collector as Failed until attempts are exhausted"*, so this is
  /// **not** [markFailed]: the chunk goes back to `queued` and C-11 keeps
  /// showing it as waiting, which is the honest description of what it is.
  ///
  /// [attemptCount] is the number of attempts made **including** the one that
  /// just failed, so the sixth call carries 6 and exhausts §2's budget.
  /// [nextAttemptAt] is when [claimNext] may consider it again.
  ///
  /// Ignores a chunk that is not currently `uploading`, for the same reason
  /// the other transitions do: only a claimed chunk can be deferred.
  ///
  /// Throws a `StorageException` if the write fails.
  Future<void> deferAttempt({
    required String chunkId,
    required int attemptCount,
    required DateTime nextAttemptAt,
  });

  /// Clears every pending backoff deadline, making queued chunks claimable.
  ///
  /// Chapter 5.12 §4's reconnection behaviour, and the only way NFR-AVL-02 is
  /// reachable. On an online transition the dispatcher must claim the front of
  /// the queue *"immediately — no polling delay, no Collector action
  /// required"*, and the target is *"< 30 seconds after network restoration"*.
  /// A batch that went offline together will be sitting on Chapter 5.13 §2
  /// deadlines of up to 160 seconds; honouring those after connectivity
  /// returns would miss the target by construction.
  ///
  /// **Clears deadlines, not attempt counts.** §2's budget of six still
  /// applies — this makes a chunk eligible again, it does not forgive the
  /// attempts it already spent. A device flapping on and off a marginal
  /// connection therefore still converges on `failed` rather than retrying
  /// forever.
  ///
  /// **Touches `queued` rows only.** §2 says an exhausted chunk waits for
  /// *"connectivity/context to change … or a manual retry"*, which reads as
  /// connectivity also reviving a `failed` chunk. That is not done here,
  /// because reviving one would need to know whether it failed transiently or
  /// terminally, and no failure cause is stored on the row — a terminal 4xx
  /// would be retried on every reconnection, against §1. Recorded as A-085.
  ///
  /// Throws a `StorageException` if the write fails.
  Future<void> clearBackoff();

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

  /// Returns a chunk stranded at `uploading` by a process death, spending one
  /// of Chapter 5.13 §2's attempts.
  ///
  /// **ADR-052.** This is deliberately not [release], which exists for an
  /// attempt *abandoned* — a cancellation or a pause — and must not consume an
  /// attempt. A process that died mid-transfer did not abandon anything: the
  /// attempt was made and lost, counting it is the honest accounting, and it
  /// is what bounds the loop. An app that dies during upload repeatedly walks
  /// the chunk through the budget and lands it at `failed`, a visible state
  /// with a working manual remedy, instead of retrying forever in silence.
  ///
  /// [attemptCount] is the number of attempts made **including** the one the
  /// death consumed, matching [deferAttempt]'s counting exactly.
  ///
  /// Clears `nextAttemptAt` rather than setting a backoff deadline. A relaunch
  /// is already a rate limiter, and the budget now binds on this path, so a
  /// delay would postpone the recovery without preventing anything.
  ///
  /// Ignores a chunk that is not currently `uploading`.
  ///
  /// Throws a `StorageException` if the write fails.
  Future<void> releaseStranded({
    required String chunkId,
    required int attemptCount,
  });

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
