import 'package:mobile/core/network/vump_api.dart';
import 'package:mobile/features/projects_tasks/data/project_task_dto.dart';
import 'package:mobile/features/projects_tasks/domain/entities/paged_result.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/domain/repositories/project_task_repository.dart';

/// The Collector's read path, against Volume 4 Chapter 4.6 §3's two GET routes.
///
/// **This is what closes Volume 11 Chapter 11.1's M8 gate for this feature** —
/// *"no fake/mock repository remains wired into a release build"*.
/// `FakeProjectTaskRepository` is unbound from `main.dart` in the same change
/// and survives only as a test double.
///
/// ## It sends no scope, and that is the whole of BR-19's client side
///
/// Neither method takes a collector id and neither sends one. Chapter 4.8:
/// *"every endpoint in Chapter 4.6 re-derives role and scope from the verified
/// token context"*, and `listProjects` picks its branch — every Project in the
/// org, or only Projects with a live assignment — from the role the authorizer
/// read out of the `users` table. A client-supplied scope on a server-enforced
/// rule is redundant at best and wrong at worst, and the backend would ignore
/// it either way.
///
/// The token is attached by `AuthInterceptor` one layer down (ADR-035), which
/// is why this file imports nothing from `features/auth/` — it could not, under
/// ADR-022 R3, and it has no reason to.
///
/// ## What it does not translate
///
/// Every failure is left as the `NetworkException` [VumpApi] raised, carrying
/// the envelope's code structurally since F29. In particular **a 404 on
/// [fetchTasks] is not converted into an empty list.** A-186 makes a Project
/// the caller cannot see report `RESOURCE_NOT_FOUND` rather than 403, and
/// swallowing that here would merge it with "this Project has no Tasks" — two
/// answers C-05 renders differently and deliberately.
///
/// error-handling.md §26 is the rule: `data/` throws, and the conversion to a
/// `Failure` happens exactly once, in `application/`.
class ProjectTaskRepositoryImpl implements ProjectTaskRepository {
  /// Creates the repository over [backend].
  const ProjectTaskRepositoryImpl({required VumpApi backend}) : _api = backend;

  final VumpApi _api;

  @override
  Future<PagedResult<Project>> fetchProjects({
    String? cursor,
    int? limit,
  }) async {
    final ApiPage page = await _api.getList(
      '/projects',
      what: 'the Projects list',
      cursor: cursor,
      limit: limit,
    );

    return PagedResult<Project>(
      items: page.rows.map(projectFromJson).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<PagedResult<Task>> fetchTasks(
    String projectId, {
    String? cursor,
    int? limit,
  }) async {
    final ApiPage page = await _api.getList(
      '/projects/$projectId/tasks',
      what: "this Project's Tasks",
      cursor: cursor,
      limit: limit,
    );

    return PagedResult<Task>(
      items: page.rows.map(taskFromJson).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }
}
