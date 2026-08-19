import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';
import 'package:mobile/features/projects_tasks/application/read_failure.dart';
import 'package:mobile/features/projects_tasks/application/tasks_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/presentation/load_more_tile.dart';

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
/// ## Three answers are distinct and all three are stated
///
/// A Project with **no Tasks**, a Project **not visible to this Collector**,
/// and a Project whose Tasks **could not be fetched** are different answers,
/// and a bare empty list would render the first two identically.
///
/// The middle one changed shape in Mission 7.4. Against the fake it arrived as
/// an empty list and was inferred from the Project's absence from
/// `projectsProvider`; the real backend answers `404 RESOURCE_NOT_FOUND`
/// (A-186), which now reaches the error branch. Both paths render the same
/// sentence, deliberately: BR-19 makes *"not assigned to you"* and *"does not
/// exist"* indistinguishable from the client, so the copy claims neither.
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
        // Two failures, two answers — F28. Against the fake there was only
        // one: an unknown Project came back as an empty list. The real
        // repository raises 404 RESOURCE_NOT_FOUND for a Project this caller
        // cannot see (A-186), and telling them to check their connection over
        // a stale link points them at something that is not broken.
        AsyncError<List<Task>>(:final Object error) =>
          switch (classifyReadFailure(error)) {
            // BR-19 makes "not assigned" and "does not exist" deliberately
            // indistinguishable, so this claims neither — the same wording
            // the missing-Project branch below already uses.
            ProjectTaskReadFailure.notVisible => const _DetailMessage(
              message: "This Project isn't available to you.",
            ),
            ProjectTaskReadFailure.unavailable => const _DetailMessage(
              message:
                  "This Project's Tasks couldn't be loaded. Check your "
                  'connection and try again.',
            ),
          },
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({
    required this.projectId,
    required this.project,
    required this.tasks,
  });

  final String projectId;
  final Project? project;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      // One extra row when another page exists. `hasMore` is the notifier's
      // narrow getter — F25 keeps the cursor off the state, so this list is
      // still List<Task> and only this builder had to learn about paging.
      itemCount:
          tasks.length +
          (ref.read(tasksProvider(projectId).notifier).hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        if (index >= tasks.length) {
          return LoadMoreTile(
            label: 'Tasks',
            onLoad: () =>
                ref.read(tasksProvider(projectId).notifier).loadMore(),
          );
        }
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
