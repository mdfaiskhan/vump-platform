import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/recording/application/checklist_notifier.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/checklist_check.dart';
import 'package:mobile/features/recording/domain/entities/checklist_outcome.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/presentation/checklist_copy.dart';
import 'package:mobile/features/recording/presentation/recording_error_copy.dart';

/// Volume 2 Chapter 2.7's C-07 and C-08, in one screen.
///
/// The chapter presents them as two screens — *"Any-fail → button disabled,
/// screen transitions to C-08"* — and this renders them as one list whose
/// failing rows expand in place. C-08's own layout is what argues for it:
/// *"Same list as C-07, with the failing row expanded into an error state; a
/// remedy card beneath it."* Two screens that differ only by an expanded row
/// are one screen with an expanded row, and keeping it as one means the
/// passing rows stay visible while a Collector fixes the failing one.
///
/// ## BR-04 lives here
///
/// This is the only route toward capture (Chapter 2.3 §5), and Start Recording
/// is disabled until `ChecklistOutcome.allPassed`. That is necessary and not
/// sufficient — a disabled button stops a tap, not a deep link — so
/// `RecordingGuard` refuses `/recording/:sessionId` for anyone who did not
/// arrive through the lifecycle. Both are required; neither alone is BR-04.
class PreRecordingChecklistScreen extends ConsumerStatefulWidget {
  /// Creates the checklist for [taskId].
  const PreRecordingChecklistScreen({required this.taskId, super.key});

  /// Identifier supplied by the route path.
  ///
  /// Carried and shown, not yet used to fetch anything —
  /// `features/projects_tasks/` is unbuilt, so there is no Task to load.
  final String taskId;

  @override
  ConsumerState<PreRecordingChecklistScreen> createState() =>
      _PreRecordingChecklistScreenState();
}

class _PreRecordingChecklistScreenState
    extends ConsumerState<PreRecordingChecklistScreen> {
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    // Runs after the first frame rather than during it: `runAll` writes
    // provider state, and mutating a provider inside `build`/`initState` while
    // the tree is being constructed is the Riverpod misuse that surfaces as a
    // "modified during build" assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(checklistNotifierProvider.notifier).runAll());
    });
  }

  @override
  Widget build(BuildContext context) {
    final ChecklistOutcome outcome = ref.watch(checklistNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Before you record')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Column(
                children: <Widget>[
                  for (final ChecklistCheck check in ChecklistCheck.values)
                    _ChecklistRow(
                      check: check,
                      outcome: outcome,
                      onRerun: () => unawaited(
                        ref
                            .read(checklistNotifierProvider.notifier)
                            .rerun(check),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Chapter 2.7: "primary action fixed to the bottom of the screen".
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: outcome.allPassed && !_starting ? _start : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(_starting ? 'Preparing camera…' : 'Start Recording'),
          ),
        ),
      ),
    );
  }

  /// BR-04's transition: the Checklist passed, so the session may begin.
  ///
  /// The zoom factor comes from the wide-angle row's verdict, already resolved
  /// — Chapter 5.1 §3 makes resolving it the Checklist's job and Chapter 5.2
  /// §1 fixes it for the whole session. The lifecycle takes the number and
  /// does not revisit the decision.
  Future<void> _start() async {
    final ChecklistOutcome outcome = ref.read(checklistNotifierProvider);
    final double? zoomFactor = outcome.resolvedZoomFactor;
    if (zoomFactor == null) {
      return;
    }

    setState(() => _starting = true);
    final RecordingNotifier notifier = ref.read(
      recordingNotifierProvider.notifier,
    );

    // Ready first: mints the session and opens the camera (Ch. 5.3 §3).
    final Failure? readyFailure = await notifier.checklistPassed(
      zoomFactor: zoomFactor,
      now: DateTime.now(),
    );
    if (!mounted) {
      return;
    }
    if (readyFailure != null) {
      // Volume 2 Ch. 2.2 step 8: a camera error on the way in returns to Task
      // Detail "without a partial session". The machine has stayed Idle, so
      // there is no session to discard — only a message to show.
      setState(() => _starting = false);
      _showFailure(readyFailure);
      return;
    }

    // Then Recording. **This tap is Chapter 2.2 step 8's "Record tapped".**
    //
    // C-09 lists Stop as "the only interactive element on screen", so there is
    // no Record control there to press — which left `Idle → Ready → Recording`
    // broken at its second edge until amendment A-070: the Checklist reached
    // `Ready` and navigated, and the machine never left it. The Stop control
    // reads `isCapturing`, which is false in `Ready`, so it rendered disabled
    // and swallowed every tap.
    //
    // One tap, both edges. The Collector presses Start Recording once and the
    // camera is genuinely recording before the chrome-free screen appears.
    final Failure? startFailure = await notifier.start(now: DateTime.now());
    if (!mounted) {
      return;
    }
    setState(() => _starting = false);

    if (startFailure != null) {
      // Capture could not begin. The session exists and the camera is open,
      // so this is not the same "no partial session" case as above — but the
      // Collector stays here rather than being sent to a screen whose only
      // control acts on a recording that never started.
      _showFailure(startFailure);
      return;
    }

    final RecordingState state = ref.read(recordingNotifierProvider);
    final String? sessionId = state.activeSession?.sessionId;
    if (sessionId != null && mounted) {
      context.go('/recording/$sessionId');
    }
  }

  void _showFailure(Failure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(RecordingErrorCopy.forFailure(failure))),
    );
  }
}

/// One C-07 row, expanding into C-08's error state when it fails.
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.check,
    required this.outcome,
    required this.onRerun,
  });

  final ChecklistCheck check;
  final ChecklistOutcome outcome;
  final VoidCallback onRerun;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool measured = outcome.isMeasured(check);
    final bool passed = outcome.passes(check);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          leading: _StatusIcon(measured: measured, passed: passed),
          title: Text(ChecklistCopy.label(check)),
          // Chapter 2.10's colour-not-alone rule: the value is always written
          // out, so the row never depends on the icon's hue to be readable.
          subtitle: Text(ChecklistCopy.value(check, outcome)),
          trailing: check == ChecklistCheck.network && measured
              ? null
              : (measured && !passed
                    ? TextButton(
                        onPressed: onRerun,
                        child: const Text('Re-run'),
                      )
                    : null),
        ),
        if (check == ChecklistCheck.network && measured)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Text(
              ChecklistCopy.uploadExpectation(outcome.network),
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (measured && !passed)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              border: Border(
                left: BorderSide(color: theme.colorScheme.error, width: 4),
              ),
            ),
            child: Text(
              ChecklistCopy.remedy(check, outcome),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }
}

/// Pass, fail, or still looking.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.measured, required this.passed});

  final bool measured;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (!measured) {
      return const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(
      passed ? Icons.check_circle : Icons.cancel,
      color: passed ? colors.primary : colors.error,
      // Read by a screen reader in place of the colour, per Chapter 2.10.
      semanticLabel: passed ? 'Passed' : 'Failed',
    );
  }
}
