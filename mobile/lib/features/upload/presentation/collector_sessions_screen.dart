import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/core/time/providers/clock_provider.dart';
import 'package:mobile/features/upload/application/upload_progress_notifier.dart';
import 'package:mobile/features/upload/application/upload_queue_notifier.dart';
import 'package:mobile/features/upload/domain/entities/chunk_upload_progress_snapshot.dart';
import 'package:mobile/features/upload/presentation/widgets/chunk_row.dart';

/// C-11 — Upload / Sync Status.
///
/// Chapter 2.5 names it *"per-session, per-chunk status: queued / uploading /
/// failed / complete"*, and Chapter 2.7 fixes the layout as a *"vertical list
/// of chunk rows grouped under the session name; a failed row expands in place
/// to offer retry"*.
///
/// ## Three states, never one spinner
///
/// Chapter 2.9 §4.1 requires that network-dependent screens *"distinguish
/// 'loading current status' from 'no data yet' from 'you're offline' as three
/// distinct visual states, never collapsed into one spinner"*.
///
/// Two of the three are rendered here. **Offline is deliberately not a state
/// of this screen**, and that is Chapter 5.12 §3's doing rather than an
/// omission: offline *"is not a blocked state, only a waiting one"*, the queue
/// keeps its rows, and every one of them still shows its real status. A banner
/// saying "you're offline" over a list that is already accurate would add a
/// mode without adding information. Recorded as A-093.
///
/// ## The countdown ticks without the queue emitting
///
/// A chunk waiting out Chapter 5.13 §2's backoff changes nothing in the
/// database while it waits, so nothing wakes this screen. A one-second timer
/// drives the countdown instead — the only thing in this project that polls,
/// and it polls a clock rather than storage.
class CollectorSessionsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CollectorSessionsScreen({super.key});

  @override
  ConsumerState<CollectorSessionsScreen> createState() =>
      _CollectorSessionsScreenState();
}

class _CollectorSessionsScreenState
    extends ConsumerState<CollectorSessionsScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<QueuedChunk>> queue = ref.watch(
      uploadQueueNotifierProvider,
    );
    final Map<String, ChunkUploadProgressSnapshot> progress = ref.watch(
      uploadProgressNotifierProvider,
    );
    final DateTime now = ref.read(clockProvider).now();
    return Scaffold(
      appBar: AppBar(title: const Text('Upload status')),
      body: _body(queue, progress, now),
    );
  }

  Widget _body(
    AsyncValue<List<QueuedChunk>> queue,
    Map<String, ChunkUploadProgressSnapshot> progress,
    DateTime now,
  ) {
    return queue.when(
      // "loading current status" — the first read of the local queue.
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => const _Message(
        title: 'The upload queue could not be read.',
        detail: 'Recording still works. Restart the app to try again.',
      ),
      data: (List<QueuedChunk> chunks) {
        if (chunks.isEmpty) {
          // "no data yet" — Chapter 2.9 §4.2 forbids a bare empty list.
          return const _Message(
            title: 'Nothing to upload yet.',
            detail:
                'Chunks appear here as soon as you finish recording a '
                'session.',
          );
        }
        return _buildGroups(chunks, progress, now);
      },
    );
  }

  Widget _buildGroups(
    List<QueuedChunk> chunks,
    Map<String, ChunkUploadProgressSnapshot> progress,
    DateTime now,
  ) {
    final List<UploadQueueSession> groups = UploadQueueSession.group(chunks);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (BuildContext context, int index) {
        final UploadQueueSession group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 24, bottom: 8),
              child: Text(
                'Session ${group.sessionId}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final QueuedChunk chunk in group.chunks)
              ChunkRow(
                chunk: chunk,
                now: now,
                progress: progress[chunk.chunkId],
                onRetry: () => unawaited(
                  ref
                      .read(uploadQueueNotifierProvider.notifier)
                      .retry(chunk.chunkId),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// An empty or error state with a cause and a next step, per Chapter 2.9 §4.2.
class _Message extends StatelessWidget {
  const _Message({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
