import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/providers/queue_ports.dart';
import 'package:mobile/core/queue/queued_chunk.dart';

/// What C-03 can actually show — FR-PT-01 in part, FR-PT-02 in full.
///
/// ## THREE of FR-PT-01's four aggregates are ABSENT, deliberately
///
/// FR-PT-01 asks for *"active projects, in-progress sessions, total recorded
/// time, and sync status"*. This type carries **only the last**. The other
/// three have no source this feature can reach, and **an absent tile was
/// chosen over a wrong number**: `0h 0m` is a claim about how much the
/// Collector has recorded, and it would be a false one.
///
/// - **Active projects.** It was here until Mission 7.4 step 4, counting the
///   Projects `projectsProvider` held. F20 made that provider **paginated**,
///   and `projectsProvider` now holds however many pages have been *loaded* —
///   one, until a Collector scrolls C-04 and presses "Load more". So the count
///   silently became *"active projects on the pages fetched so far"*, capping
///   at `projectTaskPageSize`.
///
///   There is no cheap honest fix. A count needs a total, `GET /v1/projects`
///   returns a page and no `?count=` or total exists in Chapter 4.6 §1's
///   envelope, and walking every page to count them would issue an unbounded
///   number of requests to render one tile. Rendering "200+" would invent a
///   third display convention for a screen that already has exactly one rule
///   for an unanswerable aggregate — omit it — so the tile is dropped on that
///   existing precedent rather than kept as a number that is quietly wrong.
///   Open item 111, and A-200.
///
/// - **In-progress sessions.** FR-SES-02's session status lives on
///   `LocalSession.status`, owned by `features/recording/`, and no `core/`
///   contract exposes it. Counting distinct `sessionId`s in the queue would
///   answer a different question — sessions with surviving chunk rows — and
///   Mission 4.9 warns in terms against reading the session column as an
///   upload signal. Closing it needs a new `core/` contract, ADR-040's
///   pattern. Open item 75.
///
/// - **Total recorded time.** A per-chunk duration exists —
///   `MetadataTimingDocument.durationSeconds`, derived from `startedAt` and
///   `endedAt` — but only one chunk at a time, through
///   `ChunkMetadataSource.metadataDocument`. There is no aggregate, and
///   summing the queue would be **actively wrong rather than merely
///   incomplete**: `IsarChunkStore.currentQueue` skips every row with
///   `localDeletedAt != null`, and Chapter 5.15's cleanup soft-deletes rows as
///   chunks complete (open item 61). The total would *decrease* as the
///   Collector records more. Open item 76.
class DashboardSummary {
  /// Creates a summary.
  const DashboardSummary({
    required this.queuedChunks,
    required this.uploadingChunks,
    required this.failedChunks,
    required this.completeChunks,
  });

  /// FR-PT-02's *"pending"* count — Chapter 5.9 §1's `queued`.
  final int queuedChunks;

  /// FR-PT-02's *"uploading"* count.
  final int uploadingChunks;

  /// Chunks that exhausted Chapter 5.13 §2's six attempts.
  ///
  /// Not named by FR-PT-02, which lists three counts. It is carried because
  /// FR-PT-01's *"sync status"* cannot be honest without it: a dashboard
  /// showing only pending/uploading/complete would report a stalled queue as
  /// idle, which is the invisible-failure Chapter 2.9 §4.1 forbids.
  final int failedChunks;

  /// FR-PT-02's *"completed"* count, among rows the queue still holds.
  ///
  /// **Undercounts over time, and cannot do otherwise.** Cleanup soft-deletes
  /// completed chunks and the queue excludes soft-deleted rows (open item 61),
  /// so this is "completed and not yet swept" rather than "completed ever".
  /// The same limit that makes total recorded time unbuildable — stated here
  /// because a count that quietly resets looks like data loss.
  final int completeChunks;

  /// Whether anything is waiting, moving or stuck — FR-PT-01's sync status.
  bool get hasPendingWork =>
      queuedChunks > 0 || uploadingChunks > 0 || failedChunks > 0;
}

/// C-03's summary, recomputed as the queue changes.
///
/// A `StreamProvider` rather than a notifier: it holds no state and takes no
/// action, so there is nothing for a notifier to own. Chapter 5.9 §3's queue
/// is already *"a live view, not a list"*, and this derives from it without
/// adding a second copy.
/// It maps the queue's stream rather than looping over it in an `async*`
/// generator, and that is a correctness choice rather than a style one. A
/// generator that `await for`s a foreign stream **re-throws that stream's
/// error out of the generator**, so a queue read fault is both captured by
/// Riverpod as an `AsyncError` *and* reported again as an uncaught error.
/// `map` passes errors through untouched, leaving exactly one handler.
final StreamProvider<DashboardSummary> dashboardSummaryProvider =
    StreamProvider<DashboardSummary>((Ref ref) {
      // `projectsProvider` is deliberately NOT watched any more. It was read
      // for the active-projects count, which F20's pagination made
      // unanswerable — see the class comment. Watching it now would rebuild
      // this stream every time a Collector loaded another page of C-04, to
      // change nothing.
      return ref
          .watch(chunkQueueSourceProvider)
          .watchQueue()
          .map(
            (List<QueuedChunk> queue) => DashboardSummary(
              queuedChunks: _countOf(queue, ChunkUploadStatus.queued),
              uploadingChunks: _countOf(queue, ChunkUploadStatus.uploading),
              failedChunks: _countOf(queue, ChunkUploadStatus.failed),
              completeChunks: _countOf(queue, ChunkUploadStatus.complete),
            ),
          );
    });

int _countOf(List<QueuedChunk> queue, ChunkUploadStatus status) =>
    queue.where((QueuedChunk c) => c.status == status).length;
