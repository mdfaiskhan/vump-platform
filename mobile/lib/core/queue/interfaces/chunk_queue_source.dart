import 'package:mobile/core/queue/queued_chunk.dart';

/// Supplies Volume 5 Chapter 5.9's queue rows to whoever renders or drives
/// them.
///
/// **Declared in `core/` because both sides of it are features.** The rows are
/// written by `features/recording/` at finalization and read by
/// `features/upload/`, and ADR-022 R3 forbids those two importing each other
/// *"at any layer, in either direction"*. Stating the contract on neutral
/// ground is what lets both satisfy it: recording implements this, upload
/// depends on it, and the composition root introduces them.
///
/// This is the same dependency inversion `AuthTokenSource` uses, applied one
/// step further out. There, `core/network/` declares a requirement that
/// `features/auth/data/` satisfies — `core/` to one feature. Here neither
/// party is `core/` at all; `core/` holds the contract so that two features
/// can share data without either one naming the other. ADR-040 records the
/// pattern.
///
/// ## Why a stream, not a poll
///
/// Chapter 5.9 §3: the queue *"is not an in-memory list — it is a live view
/// (Riverpod StreamNotifier, Chapter 3.9) over `local_chunks.status`"*, and
/// that is *"what satisfies NFR-REL-04 directly: an app kill loses nothing,
/// because the queue's actual state was never only in memory to begin with.
/// On relaunch, the queue simply resumes reading the same rows."*
///
/// That reasoning used to end here, with *"no re-queue step at launch and no
/// separate recovery pass — the rows already say what they are"*. **ADR-052
/// corrects it.** The rows do survive, but surviving is not resuming: a row
/// left at `uploading` by a process death describes a transfer that no longer
/// exists, `claimNext` selects only `queued`, and every transition out of
/// `uploading` is made by the pipeline that died with the process. Such a row
/// is stranded permanently — open item 137, and NFR-REL-04 violated in exactly
/// the scenario Chapter 5.9 §3 cites it to protect.
///
/// So `UploadDispatcher` does run a recovery pass at startup. It is safe there
/// and nowhere else: a freshly launched process cannot hold a transfer, so no
/// row it finds at `uploading` can be live.
///
/// ## What this contract deliberately does not expose
///
/// No file path, no checksum, no local database type. A consumer that needed
/// those would be doing Chapter 5.10's job, not Chapter 5.9's, and would be
/// reaching through the queue into the recording feature's storage.
///
/// It also exposes no transition to `uploading` or `complete`. Chapter 5.9 §5
/// defers *"what actually moves a chunk from Queued to Uploading to
/// Complete"* to Chapters 5.10 and 5.11, so those writes belong to the
/// mission that builds them — adding the methods now would invite a caller
/// before there is a pipeline behind them.
abstract interface class ChunkQueueSource {
  /// Chapter 5.9 §3's live view, ordered per §2.
  ///
  /// Emits the current queue immediately on subscription, then again whenever
  /// the underlying rows change. Every emission is fully ordered: session
  /// start time, then sequence index.
  ///
  /// Includes **all four** of Chapter 5.9 §1's states, not only `queued` —
  /// C-11 renders a pill for each, so filtering here would hide the states
  /// the screen exists to show. Rows soft-deleted per BR-08 are excluded.
  Stream<List<QueuedChunk>> watchQueue();

  /// One ordered snapshot, for a caller that does not want a subscription.
  ///
  /// Same contents and same ordering as [watchQueue]'s first emission.
  Future<List<QueuedChunk>> currentQueue();

  /// FR-UPL-07's manual retry — moves a chunk from `failed` back to `queued`.
  ///
  /// Chapter 5.9 §2 requires the chunk *"re-enters the queue at its original
  /// position, not pushed to the back"*, and that falls out of
  /// [QueuedChunk.compareTo] deriving order from the session's start time and
  /// the sequence index. Nothing here records a position, so nothing can put
  /// one back wrongly.
  ///
  /// Ignores a chunk that is not currently `failed`. A retry racing the
  /// dispatcher must not drag an `uploading` chunk backwards, and re-queueing
  /// an already-`complete` chunk would contradict BR-12.
  ///
  /// Throws a `StorageException` if the write fails.
  Future<void> requeue(String chunkId);
}
