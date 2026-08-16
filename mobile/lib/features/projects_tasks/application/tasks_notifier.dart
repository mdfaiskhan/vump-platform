import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// The Tasks inside one Project — FR-PT-04, rendered by C-05.
///
/// A family keyed by `project_id`, because Volume 4 Chapter 4.6 §3's route is
/// `GET /v1/projects/{id}/tasks` and there is no route that returns Tasks
/// across Projects. Riverpod keeps one instance per Project, so navigating
/// back to a Project already visited does not refetch it.
///
/// ## C-06's Task Detail reads from here, not from a by-id fetch
///
/// There is no `GET /v1/tasks/{id}` in Chapter 4.6 §3 — `ProjectTaskRepository`
/// records that in full. A Task Detail screen therefore selects its Task out of
/// this list rather than asking for one, and the deep-link case (a `taskId`
/// with no Project in hand) is a known gap owed to Mission 5.1.2.
class TasksNotifier extends FamilyAsyncNotifier<List<Task>, String> {
  @override
  Future<List<Task>> build(String projectId) {
    return ref.watch(projectTaskRepositoryProvider).fetchTasks(projectId);
  }

  /// Re-reads this Project's Tasks.
  ///
  /// `AsyncValue.guard` for the same reason `ProjectsNotifier.refresh` uses it
  /// — error-handling.md §26 makes `application/` the last layer that may hold
  /// an `AppException`.
  Future<void> refresh() async {
    state = const AsyncValue<List<Task>>.loading();
    state = await AsyncValue.guard(
      () => ref.read(projectTaskRepositoryProvider).fetchTasks(arg),
    );
  }
}

/// Live Tasks state for C-05, keyed by the owning Project's id.
final AsyncNotifierProviderFamily<TasksNotifier, List<Task>, String>
tasksProvider = AsyncNotifierProviderFamily<TasksNotifier, List<Task>, String>(
  TasksNotifier.new,
);
