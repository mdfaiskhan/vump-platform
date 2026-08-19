import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/projects_tasks/application/page_size.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/domain/entities/paged_result.dart';
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
/// ## Pagination, and why the page size is the backend's maximum
///
/// Same arrangement as `ProjectsNotifier` — the cursor is private, the state
/// stays `List<Task>`, F25 — and the page size matters more here than there.
/// C-06 selects its Task out of this list because there is no
/// `GET /v1/tasks/{id}`, so at the backend's default of 50 the 51st Task in a
/// Project would render *"This Task isn't available to you"*. `page_size.dart`
/// carries the full argument and the residual gap above 200.
class TasksNotifier extends FamilyAsyncNotifier<List<Task>, String> {
  String? _nextCursor;
  bool _loadingMore = false;

  @override
  Future<List<Task>> build(String projectId) async {
    final PagedResult<Task> page = await ref
        .watch(projectTaskRepositoryProvider)
        .fetchTasks(projectId, limit: projectTaskPageSize);
    _nextCursor = page.nextCursor;
    return page.items;
  }

  /// Whether a further page of this Project's Tasks exists.
  bool get hasMore => _nextCursor != null;

  /// Appends the next page, if there is one. Returns true when it did.
  ///
  /// Neither enters the loading state nor publishes a failure, for the reasons
  /// `ProjectsNotifier.loadMore` records: the Tasks already on screen are still
  /// valid, and replacing them would discard good data because more of it could
  /// not be fetched.
  Future<bool> loadMore() async {
    final String? cursor = _nextCursor;
    if (cursor == null || _loadingMore) {
      return false;
    }

    _loadingMore = true;
    try {
      final PagedResult<Task> page = await ref
          .read(projectTaskRepositoryProvider)
          .fetchTasks(arg, cursor: cursor, limit: projectTaskPageSize);
      _nextCursor = page.nextCursor;
      state = AsyncValue<List<Task>>.data(<Task>[
        ...state.valueOrNull ?? const <Task>[],
        ...page.items,
      ]);
      return true;
    } on Object {
      return false;
    } finally {
      _loadingMore = false;
    }
  }

  /// Re-reads this Project's Tasks from the first page.
  ///
  /// `AsyncValue.guard` for the same reason `ProjectsNotifier.refresh` uses it
  /// — error-handling.md §26 makes `application/` the last layer that may hold
  /// an `AppException`.
  Future<void> refresh() async {
    _nextCursor = null;
    state = const AsyncValue<List<Task>>.loading();
    state = await AsyncValue.guard(() async {
      final PagedResult<Task> page = await ref
          .read(projectTaskRepositoryProvider)
          .fetchTasks(arg, limit: projectTaskPageSize);
      _nextCursor = page.nextCursor;
      return page.items;
    });
  }
}

/// Live Tasks state for C-05, keyed by the owning Project's id.
final AsyncNotifierProviderFamily<TasksNotifier, List<Task>, String>
tasksProvider = AsyncNotifierProviderFamily<TasksNotifier, List<Task>, String>(
  TasksNotifier.new,
);
