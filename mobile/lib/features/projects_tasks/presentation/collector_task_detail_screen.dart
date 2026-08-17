import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/projects_tasks/application/tasks_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// C-06 — Task Detail. FR-PT-05, and Chapter 2.3 §5's sole path toward
/// capture.
///
/// ## It renders TWO of the three things Volume 2 names
///
/// FR-PT-05 and Chapter 2.5's C-06 row both ask for *"instructions, reference
/// examples, **and requirements**"*. This screen shows **instructions and
/// reference examples**. There is no requirements section, no empty slot
/// implying one is coming, and `instructions` has not been relabelled
/// "Instructions & Requirements" to cover the gap.
///
/// Volume 4 Chapter 4.4 §3's `tasks` table has six columns and none of them is
/// `requirements`. Whether it is prose already inside `instructions` or a
/// column the Data Dictionary omits is a product question, recorded as open
/// item 69 and deliberately not answered by a screen (A-098). **So FR-PT-05 is
/// partially satisfied, and the shortfall is visible here rather than hidden.**
///
/// ## Reference examples are plain text, and that is a real shortfall too
///
/// Chapter 4.4 §3 describes the column as *"Array of reference media URLs"*.
/// They are rendered as selectable text and **nothing opens them**: a tappable
/// link needs `url_launcher`, which is a new dependency and an ADR-030
/// decision, and inline previews need the Chapter 2.8 component library that
/// is not in this repository (open item 74).
///
/// An unopenable URL is close to useless to a Collector standing in a field,
/// so FR-PT-05's *"reference examples"* is not honestly met by printing a
/// string. Open item 80 says so rather than letting the section look finished.
///
/// ## Start Recording is a route, and the Checklist is the gate
///
/// Chapter 2.3 §5: *"The Recording Screen is reachable only through the
/// Pre-Recording Checklist — there is no direct path to it from the Dashboard
/// or Task List."* So this navigates to `/checklist/:taskId` and never to
/// `/recording/`. `RecordingGuard` enforces the same rule at the router, so
/// the button is the affordance and the guard is the gate.
///
/// **The `taskId` handed over is not used by anything downstream.**
/// `PreRecordingChecklistScreen` declares the parameter and reads it nowhere,
/// and neither does `ChecklistNotifier`, `RecordingNotifier` or
/// `RecordingGuard`. A recording started here is still attributed to nothing,
/// because `TaskContext` is bound to `UnsourcedTaskContext` — open items 1 and
/// 79. **This screen being a real Task picker does not change that**, and the
/// doc says so because the proximity invites exactly the opposite assumption.
class CollectorTaskDetailScreen extends ConsumerWidget {
  /// Creates the screen for [taskId] inside [projectId].
  const CollectorTaskDetailScreen({
    required this.projectId,
    required this.taskId,
    super.key,
  });

  /// The owning Project, from the route path.
  ///
  /// Required rather than nullable: every route that reaches this screen nests
  /// it under `:projectId`, and accepting null would invite a second route
  /// that does not — which is the shape that made open item 70 a problem.
  final String projectId;

  /// Identifier supplied by the route path.
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> tasks = ref.watch(tasksProvider(projectId));

    // Selected from the Project's list rather than fetched by id, because
    // Chapter 4.6 §3 has no `GET /v1/tasks/{id}` and `ProjectTaskRepository`
    // therefore declares no by-id method. Open item 70's narrow half closed in
    // 5.1.2, when this screen started reading the `projectId` its route
    // already carried.
    final Task? task = tasks.valueOrNull
        ?.where((Task t) => t.id == taskId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(task?.title ?? 'Task')),
      body: switch (tasks) {
        AsyncData<List<Task>>() when task == null => const _TaskMessage(
          // BR-19 makes "not assigned" and "does not exist" indistinguishable
          // from the client, deliberately, so the copy claims neither.
          message: "This Task isn't available to you.",
        ),
        AsyncData<List<Task>>() => _TaskBody(task: task!),
        AsyncError<List<Task>>() => const _TaskMessage(
          message:
              "This Task couldn't be loaded. Check your connection and try "
              'again.',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: task == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeightLg,
                  child: FilledButton(
                    onPressed: () => context.go('/checklist/$taskId'),
                    child: const Text('Start Recording'),
                  ),
                ),
              ),
            ),
    );
  }
}

class _TaskBody extends StatelessWidget {
  const _TaskBody({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('Instructions', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(task.instructions, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        Text('Reference examples', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (task.referenceExamples.isEmpty)
          Text(
            'This Task has no reference examples.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final String example in task.referenceExamples)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SelectableText(example, style: theme.textTheme.bodyMedium),
            ),
      ],
    );
  }
}

class _TaskMessage extends StatelessWidget {
  const _TaskMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
