import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/theme/app_radius.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/failed_chunk.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/domain/entities/session_end_cause.dart';

/// C-10 — the gap between Stop and the chunks being ready.
///
/// ## Shown only for a Collector-initiated stop
///
/// Amendment A-059's corrected rule, and this screen is where it lands. Since
/// Mission 3.4.5, `Finalizing` means *the session is draining*, which an
/// automatic chunk boundary never enters — capture restarts immediately
/// instead. So the only time anyone is waiting is a stop they asked for, and
/// [SessionEndCause.collectorStop] is the value that says so.
///
/// The other cause, [SessionEndCause.processingCapacityReached], reaches this
/// screen too and is **not** shown as processing. Volume 2 Chapter 2.9 §4.3
/// requires *"a plain-language cause with a single, specific recovery
/// action"* for a session that ended without the Collector asking, so that
/// case renders an explanation instead of a progress spinner.
///
/// ## Never a frozen screen
///
/// Chapter 2.9 §4.1: Local Processing *"always shows a determinate or
/// indeterminate progress state, never a frozen screen, since chunking +
/// metadata generation is a real, occasionally-longer-than-instant
/// operation"*. Indeterminate is the honest choice — the work is a SHA-256
/// over a file whose progress the isolate does not report.
class LocalProcessingScreen extends ConsumerWidget {
  /// Creates the processing screen for [sessionId].
  const LocalProcessingScreen({required this.sessionId, super.key});

  /// Identifier supplied by the route path.
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecordingState state = ref.watch(recordingNotifierProvider);
    final int remaining = state.processingJobs.length;
    final bool done = state is RecordingStateIdle;

    return PopScope(
      // Nothing is lost by leaving — processing continues in the notifier,
      // which outlives this route — but a back gesture mid-drain would land
      // the Collector on the Recording Screen they just stopped. The way out
      // is the action below, once there is something to say.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!done) ...<Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  Text(
                    _headline(state, remaining),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _detail(state, remaining),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (state.failedChunks.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    _FailedChunks(failed: state.failedChunks),
                  ],
                  if (done) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    FilledButton(
                      // FR-SES-04: "return the Collector to the Task List or
                      // Dashboard once a session is marked Complete." This
                      // takes the Dashboard half, and stops there deliberately.
                      //
                      // The Task List half needs a projectId, and this screen
                      // does not have one. The recording path carries a
                      // sessionId; the session's taskId is never wired through
                      // to anything (open item 79), and TaskContext is still
                      // UnsourcedTaskContext, so there is no Project to return
                      // to. Guessing one would send a Collector to somebody
                      // else's work.
                      //
                      // Until Mission 5.1.3 this went to the Record tab
                      // instead, because C-05 did not exist. It does now, so
                      // the fallback is gone -- but "or Dashboard" is the half
                      // that can be satisfied honestly today.
                      onPressed: () => context.go('/collector/dashboard'),
                      child: const Text('Done'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _headline(RecordingState state, int remaining) {
    if (state.sessionEndCause == SessionEndCause.processingCapacityReached) {
      return 'Recording stopped';
    }
    return remaining == 0 ? 'Recording saved' : 'Saving your recording';
  }

  String _detail(RecordingState state, int remaining) {
    if (state.sessionEndCause == SessionEndCause.processingCapacityReached) {
      // §4.3's pairing rule: the cause, then the one thing to do about it.
      return 'This device could not keep up with saving while recording, so '
          'recording was stopped. Everything captured so far is saved. Free '
          'up storage space before recording again.';
    }
    if (remaining > 0) {
      return remaining == 1
          ? 'Finishing 1 segment. This usually takes a few seconds.'
          : 'Finishing $remaining segments. This usually takes a few seconds.';
    }
    // Deliberately not C-12's "confirmed uploaded" copy. BR-12 reserves that
    // for every chunk being backend-verified, which is Chapter 5.9's to say —
    // claiming it here would be the false confirmation FR-SES-02 guards.
    return 'Everything you recorded is saved on this device and will upload '
        'when it can.';
  }
}

/// Chapter 5.13 §1's terminal, device-side failures, named rather than hidden.
class _FailedChunks extends StatelessWidget {
  const _FailedChunks({required this.failed});

  final List<FailedChunk> failed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        failed.length == 1
            ? '1 segment could not be saved. It stays on this device; open '
                  'Sessions to retry it.'
            : '${failed.length} segments could not be saved. They stay on '
                  'this device; open Sessions to retry them.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
