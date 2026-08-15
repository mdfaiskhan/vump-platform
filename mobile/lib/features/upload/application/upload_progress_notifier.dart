import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/upload/domain/entities/chunk_upload_progress_snapshot.dart';

/// Live per-chunk transfer progress for C-11, held in memory only.
///
/// Chapter 2.7's C-11 row needs a *"live percentage"* and a progress bar. That
/// number arrives from Dio's send-progress callback many times a second and is
/// meaningless the moment the process restarts, so it is kept here rather than
/// on `QueuedChunk` — which is a projection of stored rows and carries only
/// what survives a restart. A-092.
///
/// Entries are removed when a chunk stops uploading, so a completed or failed
/// chunk never leaves a stale percentage behind for the next attempt to
/// inherit.
class UploadProgressNotifier
    extends Notifier<Map<String, ChunkUploadProgressSnapshot>> {
  @override
  Map<String, ChunkUploadProgressSnapshot> build() =>
      <String, ChunkUploadProgressSnapshot>{};

  /// Records progress for [chunkId].
  ///
  /// Ignores a report that would move a chunk backwards. Dio can emit an
  /// out-of-order callback when a retry re-sends earlier parts, and a bar that
  /// jumps back looks like a fault rather than a retry.
  void report({
    required String chunkId,
    required int sentBytes,
    required int totalBytes,
  }) {
    final ChunkUploadProgressSnapshot? current = state[chunkId];
    if (current != null && sentBytes < current.sentBytes) {
      return;
    }
    state = <String, ChunkUploadProgressSnapshot>{
      ...state,
      chunkId: ChunkUploadProgressSnapshot(
        sentBytes: sentBytes,
        totalBytes: totalBytes,
      ),
    };
  }

  /// Drops [chunkId]'s progress once it is no longer uploading.
  void clear(String chunkId) {
    if (!state.containsKey(chunkId)) {
      return;
    }
    state = <String, ChunkUploadProgressSnapshot>{...state}..remove(chunkId);
  }

  /// Drops everything. Used when the dispatcher shuts down.
  void clearAll() {
    if (state.isEmpty) {
      return;
    }
    state = <String, ChunkUploadProgressSnapshot>{};
  }
}

/// C-11's live progress, by chunk id.
final NotifierProvider<
  UploadProgressNotifier,
  Map<String, ChunkUploadProgressSnapshot>
>
uploadProgressNotifierProvider =
    NotifierProvider<
      UploadProgressNotifier,
      Map<String, ChunkUploadProgressSnapshot>
    >(UploadProgressNotifier.new);
