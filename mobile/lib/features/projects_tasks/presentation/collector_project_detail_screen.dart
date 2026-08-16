import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';
import 'package:mobile/features/projects_tasks/application/tasks_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// C-05 — Project Detail. FR-PT-04.
///
/// Volume 2 Chapter 2.5: *"Task List within the selected Project."*
///
/// ## The title comes from a provider, not from a second endpoint
///
/// The route carries only `:projectId`, and Volume 4 Chapter 4.6 §3 has no
/// `GET /v1/projects/{id}`. The Project's name is therefore read out of
/// `projectsProvider`, which C-04 has usually already resolved and which
/// fetches on first read when this route is entered cold. **No repository
/// method was added**, which is the same constraint that shaped
/// `ProjectTaskRepository` in 5.1.1: a port method the backend cannot serve is
/// a rework waiting for Mission 7.
///
/// ## Two absences are distinct and both are stated
///
/// A Project with **no Tasks** and a Project that **does not exist** are
/// different answers, and a bare empty list would render them identically.
/// 5.1.1's fake seeds `prj-northgate-retired` with zero Tasks precisely so the
/// first is reachable; the second happens on a stale link.
class CollectorProjectDetailScreen extends ConsumerWidget {
  /// Creates the detail screen for [projectId].
  const CollectorProjectDetailScreen({required this.projectId, super.key});

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
        AsyncData<List<Task>>(:final List<Task> value) => _TaskList(
          projectId: projectId,
          project: project,
          tasks: value,
        ),
        AsyncError<List<Task>>() => const _DetailMessage(
          message:
              "This Project's Tasks couldn't be loaded. Check your "
              'connection and try again.',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.projectId,
    required this.project,
    required this.tasks,
  });

  final String projectId;
  final Project? project;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    // Tasks resolved and the Project is not in the list: the id names nothing
    // this Collector can see. BR-19 makes "not assigned" and "does not exist"
    // indistinguishable from the client, deliberately, so the copy claims
    // neither.
    if (project == null) {
      return const _DetailMessage(
        message: "This Project isn't available to you.",
      );
    }

    if (tasks.isEmpty) {
      return const _DetailMessage(message: 'This Project has no Tasks yet.');
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
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.go('/collector/projects/$projectId/tasks/${task.id}'),
          ),
        );
      },
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message});

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
