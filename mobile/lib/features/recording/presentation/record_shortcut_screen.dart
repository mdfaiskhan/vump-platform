import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';

/// The Record tab, which is a shortcut rather than a destination.
///
/// Volume 2 Chapter 2.4 §2: it *"jumps into the most relevant in-progress
/// Task's checklist, **or prompts Task selection if none is obviously in
/// progress**"*.
///
/// ## It implements the second half of that sentence, and only the second
///
/// The first half needs to know which Task is *in progress*, which means
/// reading `LocalSession.status` — owned by `features/recording/` but with no
/// `core/` contract exposing it to anything that knows about Tasks. That is
/// open item 75, the same gap that leaves C-03 without an in-progress-sessions
/// tile. Until it closes, *"none is obviously in progress"* is true by
/// construction, so this screen always prompts.
///
/// **This is a deliberate subset, not an approximation.** Guessing "most
/// relevant" from the chunk queue would pick a Task from a session's chunk
/// rows, which is a different question — the same substitution A-103 rejected
/// for the dashboard.
///
/// ## It is also where `RecordingGuard` sends a Collector with no session
///
/// `RecordingGuard.fallbackRoute` is this route. Somebody deep-linking to
/// `/recording/:id` without a live session lands here, so this screen has to
/// answer *"what now"* rather than render its own name — which is what the
/// Mission 1.3 placeholder did.
///
/// ## The debug button is gone
///
/// Until Mission 5.1.3 this screen carried a temporary button navigating to
/// `/checklist/debug-test-task`, because no Task picker existed and nothing in
/// the app could reach the checklist the way Chapter 2.4 §2 intends. Its
/// stated removal condition was that picker existing. C-04, C-05 and C-06 are
/// it, and the real path — Projects → Project Detail → Task Detail → Start
/// Recording — now reaches `/checklist/:taskId` with a Task the Collector
/// actually chose.
///
/// **What that did not fix:** the checklist ignores its `taskId` argument, and
/// `TaskContext` had no source, so a recording started
/// through the real path is attributed to nothing, exactly as one started
/// through the debug button was. Open items 1 and 79.
class RecordShortcutScreen extends StatelessWidget {
  /// Creates the Record tab.
  const RecordShortcutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Record')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Choose a Task to record',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Recording starts from a Task, so its footage is filed against '
                'the right work.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeightLg,
                child: FilledButton(
                  onPressed: () => context.go('/collector/projects'),
                  child: const Text('Browse Projects'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
