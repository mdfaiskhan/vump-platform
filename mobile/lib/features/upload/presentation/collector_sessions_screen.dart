import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/app_status_colors.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/core/time/providers/clock_provider.dart';
import 'package:mobile/features/upload/application/upload_dispatcher_status_notifier.dart';
import 'package:mobile/features/upload/application/upload_progress_notifier.dart';
import 'package:mobile/features/upload/application/upload_queue_notifier.dart';
import 'package:mobile/features/upload/domain/entities/chunk_upload_progress_snapshot.dart';
import 'package:mobile/features/upload/domain/entities/upload_dispatcher_status.dart';
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
    final UploadDispatcherStatus dispatcher = ref.watch(
      uploadDispatcherStatusProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Upload status')),
      body: Column(
        children: <Widget>[
          // Above the list, never inside a row. A dispatcher that cannot run
          // is a fact about the screen, not about any one chunk - painting it
          // onto the pills would say something false about each of them.
          if (dispatcher.isHalted) const _UploadsHaltedBanner(),
          Expanded(child: _body(queue, progress, now)),
        ],
      ),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: groups.length,
      itemBuilder: (BuildContext context, int index) {
        final UploadQueueSession group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(
                top: index == 0 ? 0 : AppSpacing.xl,
                bottom: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    sessionHeading(group, now),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    sessionSummary(group),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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

/// Says that uploads are not running at all, without inventing a chunk cause.
///
/// ## What it can honestly claim, and what it cannot
///
/// The system-level fact is knowable and true: the dispatcher stopped and no
/// chunk will be attempted this launch. So the banner says exactly that, and
/// states the guarantee BR-08 and NFR-REL-04 actually make — nothing is lost,
/// the files stay on the device.
///
/// **It does not fully satisfy Chapter 2.9.** §2 principle 1 wants *"the
/// specific cause and the specific fix"* and §4.3 wants *"a single, specific
/// recovery action"*. Neither exists here: the cause is that the upload path
/// is unbuilt (open item 36) and there is nothing a Collector can do about it.
/// Naming the real cause would put `sessionRegistrarProvider` in front of a
/// Collector, which is a log line rather than copy.
///
/// So it names what is and is not working, gives the only true action
/// available — keep recording, it is safe — and stops there. Amendment A-094
/// records the shortfall rather than papering over it.
class _UploadsHaltedBanner extends StatelessWidget {
  const _UploadsHaltedBanner();

  @override
  Widget build(BuildContext context) {
    final AppStatusColors status = Theme.of(
      context,
    ).extension<AppStatusColors>()!;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        color: status.warning,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, size: 18, color: status.onWarning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Uploads aren't running.",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: status.onWarning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Nothing is lost — recorded chunks stay on this device '
                    'until uploads can start again. You can keep recording.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: status.onWarning),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
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

/// The heading Chapter 2.7 asks for: *"grouped under the session name"*.
///
/// ## A session has no name, so this is the nearest true thing
///
/// Nothing in this project gives a recording session a title. `QueuedChunk`
/// carries `sessionId` and `sessionStartedAt` and no label, and
/// `LocalSession` — which has no `core/` contract exposing it anyway (open
/// item 75) — has none either. Until a session can be named, **when it was
/// recorded is the only identifying fact a Collector actually holds**.
///
/// It replaces a raw UUID. `Session 7f3a1c2e-…` satisfied the letter of
/// "grouped under the session" and told a Collector nothing they could match
/// against their own day.
///
/// ## Relative for two days, absolute after
///
/// "Today" and "Yesterday" are what a Collector reasons in during the window
/// where an upload is still outstanding; past that, a date is more useful than
/// counting back. [now] is passed in rather than read from the system clock so
/// the boundary is testable — the same reason Chapter 5.13's schedule takes an
/// injectable clock (A-083).
///
/// Comparison is on local calendar dates, not on elapsed hours: a chunk
/// recorded at 23:50 reads "Yesterday" at 00:10, which is what a person means
/// by yesterday even though ten hours have not passed.
///
/// Month abbreviations are English, consistent with every other string in this
/// application — no localisation exists anywhere yet, and this adds a
/// dependency on none.
String sessionHeading(UploadQueueSession group, DateTime now) {
  // BOTH sides are converted before the calendar dates are taken. `now` comes
  // from `Clock.now()` and `sessionStartedAt` is stored UTC, so comparing one
  // converted value against one unconverted one would put the Today/Yesterday
  // boundary at UTC midnight rather than the Collector's — wrong by a whole
  // day for anyone far enough east or west, and invisible in a UTC test.
  final DateTime started = group.chunks.first.sessionStartedAt.toLocal();
  final DateTime local = now.toLocal();
  final DateTime today = DateTime(local.year, local.month, local.day);
  final DateTime day = DateTime(started.year, started.month, started.day);
  final int daysApart = today.difference(day).inDays;

  final String time =
      '${started.hour.toString().padLeft(2, '0')}:'
      '${started.minute.toString().padLeft(2, '0')}';

  return switch (daysApart) {
    0 => 'Today $time',
    1 => 'Yesterday $time',
    _ => '${started.day} ${_months[started.month - 1]} $time',
  };
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One line of per-session progress, under the heading.
///
/// Chapter 2.4 §2 calls Tab 4 *"upload/sync status **across all sessions**"*,
/// and until now the screen answered that only by making the reader count
/// rows. `UploadQueueSession.countOf` has existed and been unit-tested since
/// Mission 4.1 with no production consumer; this is it.
///
/// ## It counts what the queue still holds, and says so when that is all done
///
/// Chapter 5.15's cleanup soft-deletes completed chunks and the queue excludes
/// soft-deleted rows (open item 61), so a session's totals **shrink as
/// housekeeping runs** and a fully-swept session disappears from this screen
/// altogether. That is the same root cause as open items 76 and 81 and it is
/// not worked around here: the wording avoids a total the reader could take as
/// a session's true chunk count.
///
/// So this reads *"2 uploaded · 1 waiting"* rather than *"2 of 5 uploaded"*.
/// The second phrasing would state a denominator this screen cannot know.
String sessionSummary(UploadQueueSession group) {
  final int complete = group.countOf(ChunkUploadStatus.complete);
  final int uploading = group.countOf(ChunkUploadStatus.uploading);
  final int queued = group.countOf(ChunkUploadStatus.queued);
  final int failed = group.countOf(ChunkUploadStatus.failed);

  final List<String> parts = <String>[
    if (complete > 0) '$complete uploaded',
    if (uploading > 0) '$uploading uploading',
    if (queued > 0) '$queued waiting',
    // Named last and never omitted when non-zero: Chapter 2.9 §4.1 forbids a
    // failure that is not visible, and a summary that led with "3 uploaded"
    // while one chunk was stuck would be exactly that.
    if (failed > 0) '$failed needs attention',
  ];

  return parts.join(' · ');
}
