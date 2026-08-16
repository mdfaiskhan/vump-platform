import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/providers/queue_ports.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';

/// What C-03 can actually show — FR-PT-01 in part, FR-PT-02 in full.
///
/// ## Two of FR-PT-01's four aggregates are ABSENT, deliberately
///
/// FR-PT-01 asks for *"active projects, in-progress sessions, total recorded
/// time, and sync status"*. This type carries the first and the last. The
/// other two have no source this feature can reach, and **an absent tile was
/// chosen over a zero**: `0h 0m` is a claim about how much the Collector has
/// recorded, and it would be a false one.
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
    required this.activeProjectCount,
    required this.queuedChunks,
    required this.uploadingChunks,
    required this.failedChunks,
    required this.completeChunks,
  });

  /// FR-PT-01's *"active projects"*.
  ///
  /// **"Active" means not archived**, and that is a reading rather than a
  /// quotation. No chapter defines the word; `archived_at` is the only
  /// activity signal Volume 4 Chapter 4.4 §2 gives a Project, and Chapter 4.2
  /// §1 introduces soft-delete precisely so archived rows stay queryable and
  /// distinguishable. The alternative reading — "has an assigned Task in
  /// progress" — needs the session data that is not reachable. Recorded as an
  /// amendment rather than left implicit.
  final int activeProjectCount;

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
      final AsyncValue<List<Project>> projects = ref.watch(projectsProvider);

      // Projects resolve once; the queue is continuous. While projects are
      // still loading the count reads zero rather than blocking the chunk
      // counts, which are the half of this screen that updates live.
      final int activeProjects =
          projects.valueOrNull
              ?.where((Project p) => p.archivedAt == null)
              .length ??
          0;

      return ref
          .watch(chunkQueueSourceProvider)
          .watchQueue()
          .map(
            (List<QueuedChunk> queue) => DashboardSummary(
              activeProjectCount: activeProjects,
              queuedChunks: _countOf(queue, ChunkUploadStatus.queued),
              uploadingChunks: _countOf(queue, ChunkUploadStatus.uploading),
              failedChunks: _countOf(queue, ChunkUploadStatus.failed),
              completeChunks: _countOf(queue, ChunkUploadStatus.complete),
            ),
          );
    });

int _countOf(List<QueuedChunk> queue, ChunkUploadStatus status) =>
    queue.where((QueuedChunk c) => c.status == status).length;
