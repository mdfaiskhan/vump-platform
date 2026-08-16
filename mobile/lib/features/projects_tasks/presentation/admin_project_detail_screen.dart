import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';
import 'package:mobile/features/projects_tasks/application/tasks_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// A-03 — Project Detail (Admin).
///
/// Chapter 2.5: *"Task list within the Project; entry points to create/edit
/// and to Collector assignment."*
///
/// ## ONE of its two specified entry points is built
///
/// **Built — "+ New Task"**, per Chapter 2.7 §5's *"Admin-only action buttons
/// … added per FR-ADM-01/02"*. It reaches A-05's create half.
///
/// **Absent — Collector assignment.** A-06 cannot be built: Chapter 2.7
/// requires its checkboxes to *"reflect current assignment state on load"* and
/// **no endpoint returns assignments** — Chapter 4.6 §3 has only `POST` and
/// `DELETE` on `/v1/tasks/{id}/assignments`. Nothing returns the org's
/// Collectors either; Chapter 4.6 §2 has `GET /v1/users/me` and nothing else.
/// Two missing reads, one screen — open item 89.
///
/// So there is **no assignment button, not a disabled one**. A greyed control
/// implies a capability that is temporarily off; nothing here is off, because
/// nothing exists. Mission 5.1.5 took the same decision for C-12 and Mission
/// 5.2.2 takes it again for A-04's edit half.
///
/// Editing a Task is likewise absent, for a different reason — Chapter 2.9
/// contradicts itself about whether an edit confirms before saving (open item
/// 90). `AdminCreateTaskScreen`'s doc carries both sentences.
class AdminProjectDetailScreen extends ConsumerWidget {
  /// Creates the Admin detail screen for [projectId].
  const AdminProjectDetailScreen({required this.projectId, super.key});

  /// Identifier supplied by the route path.
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> projects = ref.watch(projectsProvider);
    final AsyncValue<List<Task>> tasks = ref.watch(tasksProvider(projectId));

    final Project? project = projects.valueOrNull
        ?.where((Project p) => p.id == projectId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(project?.name ?? 'Project')),
      body: switch (tasks) {
        AsyncData<List<Task>>(:final List<Task> value) => _AdminTaskList(
          projectId: projectId,
          project: project,
          tasks: value,
        ),
        AsyncError<List<Task>>() => const _AdminDetailMessage(
          message:
              "This Project's Tasks couldn't be loaded. Check your connection "
              'and try again.',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: project == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  context.go('/admin/projects/$projectId/tasks/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Task'),
            ),
    );
  }
}

class _AdminTaskList extends StatelessWidget {
  const _AdminTaskList({
    required this.projectId,
    required this.project,
    required this.tasks,
  });

  final String projectId;
  final Project? project;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    if (project == null) {
      // BR-20 scopes an Admin to their own org, and that scope is enforced
      // server-side, so "outside your scope" and "does not exist" are
      // indistinguishable from here. The copy claims neither.
      return const _AdminDetailMessage(
        message: "This Project isn't available to you.",
      );
    }

    if (tasks.isEmpty) {
      // An Admin's empty Task list has the same obvious next step Chapter 2.9
      // §4.2 gives their empty Projects list, and the "+ New Task" button is
      // already on screen — so this states the situation and points at it
      // rather than repeating the action.
      return const _AdminDetailMessage(
        message: 'No Tasks yet. Add one for your Collectors to record.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        final Task task = tasks[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            title: Text(
              task.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                task.instructions,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            // No trailing chevron and no onTap: the two things a row would
            // lead to -- edit (item 90) and assignment (item 89) -- are both
            // unbuilt, so a tap target would promise a destination that does
            // not exist.
          ),
        );
      },
    );
  }
}

class _AdminDetailMessage extends StatelessWidget {
  const _AdminDetailMessage({required this.message});

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
