import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/providers/queue_ports.dart';
import 'package:mobile/core/queue/queued_chunk.dart';

/// Volume 5 Chapter 5.9's Upload Queue — a live view, not a list.
///
/// Chapter 5.9 §3 is specific about the shape: the queue *"is not an
/// in-memory list — it is a live view (Riverpod StreamNotifier, Chapter 3.9)
/// over `local_chunks.status`"*, and that is *"what satisfies NFR-REL-04
/// directly: an app kill loses nothing, because the queue's actual state was
/// never only in memory to begin with. On relaunch, the queue simply resumes
/// reading the same rows."*
///
/// So this class holds no queue. It subscribes to one.
///
/// ## Why there is no launch-time recovery step
///
/// The obvious-looking omission is a re-queue pass at startup, and it would be
/// wrong. The rows already say `queued`; nothing has to put them back. A
/// recovery pass would either be a no-op or would overwrite state the
/// dispatcher owns.
///
/// `ChunkStore.recoverableChunkIds()` exists for a related but different
/// question — which queued chunks still have their file on disk — and belongs
/// to the mission that actually uploads, where a missing file is what blocks
/// the transfer. Deliberately not called here.
///
/// ## What this class does NOT do
///
/// It performs no upload and makes no network call. Chapter 5.9 §5 defers
/// *"what actually moves a chunk from Queued to Uploading to Complete"* to
/// Chapters 5.10 and 5.11. This mission models the queue; the dispatcher that
/// claims from it is a later one.
///
/// It also does not check `ChunkMetadata.isIdentityComplete` (A-068 Guard 1).
/// A chunk whose `collector_id` is the unsourced sentinel is legitimately
/// *queued* — what must never happen is it being *sent*. Gating queue entry
/// would hide such chunks from C-11 entirely, which turns a visible data gap
/// into an invisible one. The guard belongs at Chapter 5.10 §1's
/// registration, and A-068 records it as owed there.
class UploadQueueNotifier extends StreamNotifier<List<QueuedChunk>> {
  @override
  Stream<List<QueuedChunk>> build() {
    return ref.watch(chunkQueueSourceProvider).watchQueue();
  }

  /// FR-UPL-07's Retry Chunk action (C-11).
  ///
  /// Chapter 5.9 §2 requires the chunk *"re-enters the queue at its original
  /// position, not pushed to the back"*. Nothing here computes a position:
  /// ordering is derived from the session's start time and the sequence
  /// index, both immutable, so returning the row to `queued` restores its
  /// place by construction. See [QueuedChunk.compareTo].
  ///
  /// The stream re-emits on its own once the row changes, so this returns
  /// nothing and sets no state.
  Future<void> retry(String chunkId) {
    return ref.read(chunkQueueSourceProvider).requeue(chunkId);
  }
}

/// The live Upload Queue.
final StreamNotifierProvider<UploadQueueNotifier, List<QueuedChunk>>
uploadQueueNotifierProvider =
    StreamNotifierProvider<UploadQueueNotifier, List<QueuedChunk>>(
      UploadQueueNotifier.new,
    );

/// The queue as C-11 groups it: one entry per session, in queue order.
///
/// Chapter 2.7's C-11 lists *"chunk rows grouped under the session name"*, so
/// the grouping is presentation's requirement rather than the queue's. It is
/// derived here rather than in a widget so the ordering guarantee — sessions
/// in start order, chunks in sequence order within each — is stated once and
/// testable without a widget tree.
final Provider<List<UploadQueueSession>> uploadQueueBySessionProvider =
    Provider<List<UploadQueueSession>>((Ref ref) {
      final AsyncValue<List<QueuedChunk>> queue = ref.watch(
        uploadQueueNotifierProvider,
      );
      return UploadQueueSession.group(queue.valueOrNull ?? <QueuedChunk>[]);
    });

/// One session's chunks, in queue order.
final class UploadQueueSession {
  /// Creates a group.
  const UploadQueueSession({required this.sessionId, required this.chunks});

  /// The session these chunks belong to.
  final String sessionId;

  /// Its chunks, already ordered by sequence index.
  final List<QueuedChunk> chunks;

  /// Groups an ordered queue without disturbing its order.
  ///
  /// Relies on the input already satisfying Chapter 5.9 §2, so sessions come
  /// out in start-time order and chunks in sequence order within each. It
  /// does not re-sort: re-deriving the order here would be a second place for
  /// it to be wrong.
  static List<UploadQueueSession> group(List<QueuedChunk> queue) {
    final List<UploadQueueSession> groups = <UploadQueueSession>[];
    for (final QueuedChunk chunk in queue) {
      if (groups.isNotEmpty && groups.last.sessionId == chunk.sessionId) {
        groups.last.chunks.add(chunk);
      } else {
        groups.add(
          UploadQueueSession(
            sessionId: chunk.sessionId,
            chunks: <QueuedChunk>[chunk],
          ),
        );
      }
    }
    return groups;
  }

  /// How many chunks in this session sit in [status].
  int countOf(ChunkUploadStatus status) =>
      chunks.where((QueuedChunk c) => c.status == status).length;
}
