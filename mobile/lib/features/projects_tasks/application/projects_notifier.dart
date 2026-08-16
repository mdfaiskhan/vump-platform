import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';

/// The Collector's assigned Projects — FR-PT-03, rendered by C-04.
///
/// Volume 3 Chapter 3.9 §3 fixes the shape and §2 fixes why: `AsyncValue` is
/// the one pattern for anything that can be loading, present or failed, so a
/// screen handles all three branches or does not compile.
///
/// ## Why this holds no filter and no sort
///
/// BR-19's assignment scope is applied by the backend from the bearer token
/// (Volume 4 Chapter 4.8; Chapter 4.2 §3's injected `WHERE` clause), and no
/// chapter specifies an ordering for C-04. A sort invented here would be a
/// product decision taken by a notifier.
///
/// ## `refresh` exists because a pull-to-refresh has nowhere else to live
///
/// FR-PT-06 makes offline browsing a *Should Have* and no cache is built yet
/// (`local_task_cache` is assigned to this feature by ADR-039 §3 and
/// deliberately not implemented — open item 2), so today every read is a live
/// one and [refresh] is the only way a Collector gets newer data than the one
/// fetched at build.
class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() {
    return ref.watch(projectTaskRepositoryProvider).fetchProjects();
  }

  /// Re-reads the Projects, showing the loading state while it does.
  ///
  /// `AsyncValue.guard` is what puts a thrown `NetworkException` into
  /// [state] as an `AsyncError` rather than letting it escape an
  /// `application/` method — error-handling.md §26's *"must not let an
  /// exception reach `presentation/`"*.
  Future<void> refresh() async {
    state = const AsyncValue<List<Project>>.loading();
    state = await AsyncValue.guard(
      () => ref.read(projectTaskRepositoryProvider).fetchProjects(),
    );
  }
}

/// Live Projects state for C-03's dashboard and C-04's list.
final AsyncNotifierProvider<ProjectsNotifier, List<Project>> projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
      ProjectsNotifier.new,
    );
