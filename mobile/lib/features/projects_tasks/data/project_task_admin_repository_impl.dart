import 'package:mobile/core/network/vump_api.dart';
import 'package:mobile/features/projects_tasks/data/project_task_dto.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/domain/repositories/project_task_admin_repository.dart';

/// The Admin's write path, against Chapter 4.6 §3's five write routes.
///
/// The other half of A-099's split. This holds no read method, and
/// `ProjectTaskRepositoryImpl` holds no write method — which is what keeps
/// FR-ADM-07 a compile-time guarantee rather than a role check.
///
/// ## Three of these five have no caller in the app
///
/// [updateTask], [assignCollector] and [unassignCollector] are implemented and
/// unreached: nothing in `lib/` calls them. Chapter 2.7's A-06 (Assign
/// Collectors) and the Task edit form are not built. They are implemented
/// anyway because the interface declares them and a `NOT_IMPLEMENTED` stub in a
/// shipped `data/` class is the same defect the backend spent Mission 7.3
/// removing — but their correctness rests on unit tests alone, which is stated
/// here rather than discovered later.
///
/// ## Nothing sends `org_id` or `created_by`
///
/// Chapter 4.8 §1: *"No authorization decision is ever trusted from the mobile
/// client."* The backend derives both from the authorizer context and would
/// ignore either if sent; a body carrying one would be proposing its own
/// tenant, which is the exact shape of BR-20 failure the rule prevents.
///
/// ## The two assignment routes answer 204
///
/// Both return an envelope with a null `data`, which [VumpApi] reads as an
/// empty map — the same path a `PATCH` with nothing to say already takes. Both
/// are idempotent on the backend (`ON CONFLICT … DO UPDATE` on assign,
/// `removed_at IS NULL` in the unassign predicate), which is what the interface
/// promises and what A-06 needs in order to save a whole checkbox set without a
/// read endpoint to diff against.
class ProjectTaskAdminRepositoryImpl implements ProjectTaskAdminRepository {
  /// Creates the repository over [backend].
  const ProjectTaskAdminRepositoryImpl({required VumpApi backend})
    : _api = backend;

  final VumpApi _api;

  @override
  Future<Project> createProject({
    required String name,
    String? description,
  }) async {
    final Map<String, Object?> data = await _api.post(
      '/projects',
      what: 'the new Project',
      body: <String, Object?>{'name': name, 'description': ?description},
    );

    return projectFromJson(data);
  }

  @override
  Future<Task> createTask({
    required String projectId,
    required String title,
    required String instructions,
    List<String> referenceExamples = const <String>[],
  }) async {
    final Map<String, Object?> data = await _api.post(
      '/projects/$projectId/tasks',
      what: 'the new Task',
      body: <String, Object?>{
        'title': title,
        'instructions': instructions,
        'reference_examples': referenceExamples,
      },
    );

    return taskFromJson(data);
  }

  @override
  Future<Task> updateTask({
    required String taskId,
    String? title,
    String? instructions,
    List<String>? referenceExamples,
  }) async {
    // Null means "leave unchanged", so a null field is absent from the body
    // rather than sent as null — `PATCH` distinguishes the two and the backend
    // reads an absent field as untouched. Sending all three as null would be
    // rejected with REQUEST_INVALID, which is the backend refusing the no-op
    // write the interface already tells callers not to make.
    final Map<String, Object?> data = await _api.patch(
      '/tasks/$taskId',
      what: 'the Task',
      body: <String, Object?>{
        'title': ?title,
        'instructions': ?instructions,
        'reference_examples': ?referenceExamples,
      },
    );

    return taskFromJson(data);
  }

  @override
  Future<void> assignCollector({
    required String taskId,
    required String collectorId,
  }) async {
    await _api.post(
      '/tasks/$taskId/assignments',
      what: 'the assignment',
      body: <String, Object?>{'collector_id': collectorId},
    );
  }

  @override
  Future<void> unassignCollector({
    required String taskId,
    required String collectorId,
  }) async {
    await _api.delete(
      '/tasks/$taskId/assignments/$collectorId',
      what: 'the unassignment',
    );
  }
}
