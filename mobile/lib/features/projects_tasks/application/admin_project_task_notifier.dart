import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';
import 'package:mobile/features/projects_tasks/application/tasks_notifier.dart';

/// The Admin's write actions — FR-ADM-01 and FR-ADM-02's create half.
///
/// ## Why a notifier rather than a screen reading the repository
///
/// A form could read `projectTaskAdminRepositoryProvider` directly — it is
/// declared in `application/` and typed as the domain interface, so no layer
/// rule forbids it. **The conversion is what forbids it.** error-handling.md
/// §26 makes `application/` *"the last layer that may"* catch an
/// `AppException`, and `Failure.fromException` the single sanctioned
/// conversion. A screen catching the exception itself would put that
/// conversion in `presentation/`, where the same table says no exception may
/// arrive at all.
///
/// So these methods return a `Failure?` — null on success — exactly as
/// `AuthNotifier`'s sign-in actions have since Mission 2.2, and for the same
/// reason: an action's outcome is not the feature's state, and pushing a
/// failed create through an `AsyncError` would replace a perfectly good list
/// with an error.
///
/// ## It invalidates rather than inserting
///
/// A successful create invalidates the affected read provider instead of
/// appending to it. Both fakes share one store (A-117), and the real
/// repositories will share a backend — in either case the list's source is
/// authoritative and a locally-inserted copy is a second one that can
/// silently disagree. Re-reading costs a rebuild and cannot drift.
///
/// This notifier holds no state of its own. `build` returns nothing because
/// there is nothing to hold: the Projects and Tasks lists are
/// `ProjectsNotifier`'s and `TasksNotifier`'s, and duplicating them here would
/// be the second source of truth the paragraph above rejects.
class AdminProjectTaskNotifier extends Notifier<void> {
  @override
  void build() {}

  /// FR-ADM-01. Returns null on success, or the failure to render.
  ///
  /// [name] is required by Volume 4 Chapter 4.4 §2's `NOT NULL`; the form
  /// checks it before calling, so a blank one reaching the repository means a
  /// caller skipped validation rather than a Collector typed nothing. The
  /// repository's own check stays as the backstop it is.
  Future<Failure?> createProject({required String name, String? description}) {
    return _attempt(() async {
      await ref
          .read(projectTaskAdminRepositoryProvider)
          .createProject(name: name, description: description);
      ref.invalidate(projectsProvider);
    });
  }

  /// FR-ADM-02's create half. Returns null on success.
  ///
  /// Invalidates only the owning Project's Task list — `tasksProvider` is a
  /// family, so invalidating the whole family would refetch every Project a
  /// screen happened to have visited.
  Future<Failure?> createTask({
    required String projectId,
    required String title,
    required String instructions,
  }) {
    return _attempt(() async {
      await ref
          .read(projectTaskAdminRepositoryProvider)
          .createTask(
            projectId: projectId,
            title: title,
            instructions: instructions,
          );
      ref.invalidate(tasksProvider(projectId));
    });
  }

  /// Runs a write, converting failure exactly once.
  ///
  /// The same helper `AuthNotifier._attempt` uses, for the same reason: one
  /// place where an `AppException` becomes a `Failure`, so no call site can
  /// forget and no exception can reach `presentation/`.
  Future<Failure?> _attempt(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on AppException catch (exception) {
      return Failure.fromException(exception);
    }
  }
}

/// The Admin's write actions, for A-04 and A-05's create forms.
final NotifierProvider<AdminProjectTaskNotifier, void>
adminProjectTaskProvider = NotifierProvider<AdminProjectTaskNotifier, void>(
  AdminProjectTaskNotifier.new,
);
