import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/domain/repositories/project_task_repository.dart';

/// A `ProjectTaskRepository` a test can steer.
///
/// Separate from `FakeProjectTaskRepository`, and deliberately so. That one is
/// a **shipped stand-in** with a fixed seed whose shape is its contract; this
/// one is a **test instrument** whose whole purpose is to change answers
/// between calls and to fail on demand. Driving the notifier tests through the
/// shipped fake would couple every assertion to that seed and leave the
/// failure path untestable, because the shipped fake never throws.
///
/// The answer fields are public and mutable rather than hidden behind setters:
/// a test instrument's state *is* its interface, and `use_setters_to_change_
/// properties` (ADR-021) is right that a `setX` method over a plain field is
/// noise.
///
/// Hand-written, like every other fake in this repository — `mocktail` is
/// named as project tooling and has never been installed (open item 63).
class ControllableProjectTaskRepository implements ProjectTaskRepository {
  /// Creates the instrument over an initial answer set.
  ControllableProjectTaskRepository({
    this.projects = const <Project>[],
    this.tasks = const <String, List<Task>>{},
  });

  /// What [fetchProjects] answers. Reassign to change it mid-test.
  List<Project> projects;

  /// What [fetchTasks] answers, keyed by `project_id`.
  Map<String, List<Task>> tasks;

  /// Every `projectId` [fetchTasks] was called with, in call order.
  final List<String> fetchTasksCalls = <String>[];

  /// How many times [fetchProjects] was called.
  int fetchProjectsCalls = 0;

  /// When non-null, both reads throw this instead of answering.
  NetworkException? failure;

  /// Makes both reads throw, as the real repository does on a transport fault.
  void failWith({
    ErrorCode code = ErrorCode.networkTimeout,
    String message = 'the network went away',
  }) {
    failure = NetworkException(errorCode: code, message: message);
  }

  @override
  Future<List<Project>> fetchProjects() async {
    fetchProjectsCalls++;
    final NetworkException? pending = failure;
    if (pending != null) {
      throw pending;
    }
    return projects;
  }

  @override
  Future<List<Task>> fetchTasks(String projectId) async {
    fetchTasksCalls.add(projectId);
    final NetworkException? pending = failure;
    if (pending != null) {
      throw pending;
    }
    return tasks[projectId] ?? const <Task>[];
  }
}
