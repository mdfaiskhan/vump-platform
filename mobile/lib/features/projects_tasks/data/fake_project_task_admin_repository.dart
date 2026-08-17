import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/validation_exception.dart';
import 'package:mobile/core/time/interfaces/clock.dart';
import 'package:mobile/features/projects_tasks/data/in_memory_project_task_store.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/domain/repositories/project_task_admin_repository.dart';

/// A deterministic in-memory [ProjectTaskAdminRepository], standing in until
/// Mission 7 wires the real one.
///
/// **REMOVAL CONDITION, stated so it travels with the code:** this class, its
/// `main.dart` override, `FakeProjectTaskRepository` and
/// `InMemoryProjectTaskStore` are all deleted together when real repositories
/// call Volume 4 Chapter 4.6 §3's endpoints — Mission 7, and Volume 11 Chapter
/// 11.2's **M8** gate makes removing them mandatory rather than optional. The
/// same condition `FakeProjectTaskRepository` already carries.
///
/// ## It writes to the store the read fake reads
///
/// That is the whole point of `InMemoryProjectTaskStore`: a Project created
/// here appears in `fetchProjects` immediately, so Mission 5.2.2's CRUD
/// screens are exercised against something that behaves like a backend rather
/// than against two fakes that disagree.
///
/// ## Ids and timestamps are minted deterministically
///
/// Ids are a prefix and a counter — `prj-4`, `tsk-6` — not UUIDs. A fake that
/// produced random ids would make a widget test's golden output vary between
/// runs, which is the flakiness Mission 4.4's injectable clock exists to
/// prevent, arriving through a different door.
///
/// Timestamps come from the injected [Clock] for the same reason, and it is
/// the port A-083 and Volume 9 Chapter 9.6 §2 already require: *"a fake,
/// injectable clock (never `DateTime.now()` called directly inside a
/// use-case)"*. `SystemClock` is the production default, so this is real time
/// in a build and controlled time in a test.
///
/// ## What it validates, and what it deliberately does not
///
/// It rejects a blank name, a blank title and a blank instruction, because
/// Chapter 4.4 §2 and §3 mark those columns `NOT NULL` and a blank string is
/// the empty-sentinel problem `MetadataIdentity` already has: a value that
/// looks real and is not.
///
/// It does **not** validate that a `collectorId` names a real, active user.
/// UC-07's exception flow requires that check and it is the backend's —
/// Chapter 4.8 re-derives identity from the token and this client holds no
/// user directory. A fake that invented the rule would be modelling a
/// guarantee the real repository does not make here.
class FakeProjectTaskAdminRepository implements ProjectTaskAdminRepository {
  /// Creates the fake over [store] and [clock].
  FakeProjectTaskAdminRepository({required this.store, required this.clock});

  /// The shared store this writes. Read by `FakeProjectTaskRepository`.
  final InMemoryProjectTaskStore store;

  /// Supplies `created_at` for new rows.
  final Clock clock;

  int _projectCounter = 0;
  int _taskCounter = 0;

  @override
  Future<Project> createProject({
    required String name,
    String? description,
  }) async {
    _require(name, 'name');

    final Project project = Project(
      id: 'prj-${++_projectCounter}',
      // Server-assigned in the real repository — Chapter 4.8 derives both from
      // the verified token, so the client never sends them and the fake stands
      // in for what the backend would fill.
      orgId: InMemoryProjectTaskStore.seedOrgId,
      name: name,
      description: description,
      createdBy: InMemoryProjectTaskStore.seedCreatedBy,
      createdAt: clock.now(),
    );

    store.projects.add(project);
    // A new Project has no Tasks and must list as empty rather than as absent,
    // which is the distinction C-05 renders as two different messages.
    store.tasks[project.id] = <Task>[];
    return project;
  }

  @override
  Future<Task> createTask({
    required String projectId,
    required String title,
    required String instructions,
    List<String> referenceExamples = const <String>[],
  }) async {
    _require(title, 'title');
    _require(instructions, 'instructions');
    _requireProject(projectId);

    final Task task = Task(
      id: 'tsk-${++_taskCounter}',
      projectId: projectId,
      title: title,
      instructions: instructions,
      createdAt: clock.now(),
      referenceExamples: referenceExamples,
    );

    store.tasks.putIfAbsent(projectId, () => <Task>[]).add(task);
    return task;
  }

  @override
  Future<Task> updateTask({
    required String taskId,
    String? title,
    String? instructions,
    List<String>? referenceExamples,
  }) async {
    if (title != null) {
      _require(title, 'title');
    }
    if (instructions != null) {
      _require(instructions, 'instructions');
    }

    for (final MapEntry<String, List<Task>> entry in store.tasks.entries) {
      final int index = entry.value.indexWhere((Task t) => t.id == taskId);
      if (index == -1) {
        continue;
      }
      // Null means "leave unchanged", which is what PATCH means. `copyWith`
      // with a null argument does exactly that, so the three optionals map
      // onto it without a branch each.
      final Task updated = entry.value[index].copyWith(
        title: title ?? entry.value[index].title,
        instructions: instructions ?? entry.value[index].instructions,
        referenceExamples:
            referenceExamples ?? entry.value[index].referenceExamples,
      );
      entry.value[index] = updated;
      return updated;
    }

    throw ValidationException(
      errorCode: ErrorCode.validationRequiredField,
      message: 'No Task with id $taskId.',
    );
  }

  @override
  Future<void> assignCollector({
    required String taskId,
    required String collectorId,
  }) async {
    _require(collectorId, 'collectorId');
    _requireTask(taskId);
    // A Set, so assigning twice is the no-op the contract promises.
    store.assignments.putIfAbsent(taskId, () => <String>{}).add(collectorId);
  }

  @override
  Future<void> unassignCollector({
    required String taskId,
    required String collectorId,
  }) async {
    _requireTask(taskId);
    // Removing an absent id is a no-op rather than an error, matching
    // Chapter 4.4 §4's soft removal: the row is marked, not deleted, so a
    // second removal changes nothing either way.
    store.assignments[taskId]?.remove(collectorId);
  }

  void _require(String value, String field) {
    if (value.trim().isEmpty) {
      throw ValidationException(
        errorCode: ErrorCode.validationRequiredField,
        message: '$field must not be blank.',
      );
    }
  }

  void _requireProject(String projectId) {
    if (!store.projects.any((Project p) => p.id == projectId)) {
      throw ValidationException(
        errorCode: ErrorCode.validationRequiredField,
        message: 'No Project with id $projectId.',
      );
    }
  }

  void _requireTask(String taskId) {
    final bool exists = store.tasks.values.any(
      (List<Task> tasks) => tasks.any((Task t) => t.id == taskId),
    );
    if (!exists) {
      throw ValidationException(
        errorCode: ErrorCode.validationRequiredField,
        message: 'No Task with id $taskId.',
      );
    }
  }
}
