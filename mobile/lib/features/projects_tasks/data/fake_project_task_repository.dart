import 'package:mobile/features/projects_tasks/data/in_memory_project_task_store.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/domain/repositories/project_task_repository.dart';

/// A deterministic in-memory [ProjectTaskRepository], standing in until
/// Mission 7 wires the real one.
///
/// ## Why a fake is allowed to ship right now, and exactly when it stops being
/// allowed
///
/// Volume 11 Chapter 11.1's milestone table settles this, and the ordering is
/// the whole argument:
///
/// - **M7 — UI Complete**: *"Every screen in Volume 2, Chapter 2.5's inventory
///   is built…"* — the gate Mission 5 exists to reach.
/// - **M8 — APIs Integrated**: *"Every repository reads/writes the real
///   backend — **no fake/mock repository remains wired into a release
///   build**."*
///
/// M8 comes **after** M7. Building C-03–C-06 against a real backend is not
/// possible — `backend/` is empty, no Lambda has executed, and no Volume 4
/// endpoint is deployed (M2 is not met either). So a fake bound in `main.dart`
/// for Mission 5 is what the milestone sequence sanctions, not a shortcut past
/// it.
///
/// **REMOVAL CONDITION, stated so it travels with the code:** this class and
/// its `main.dart` override are deleted when a real `ProjectTaskRepository`
/// calls Volume 4 Chapter 4.6 §3's endpoints — Mission 7, M8's gate. It must
/// not survive into a release build. Nothing else in `lib/` may depend on this
/// type: every consumer holds the interface, and the composition root is the
/// only file that names this class.
///
/// ## The seed lives in `InMemoryProjectTaskStore`, not here
///
/// It moved at Mission 5.2.1, when a write path arrived. Two independent
/// fakes would let `FakeProjectTaskAdminRepository.createProject` succeed
/// while this repository never showed the result — Projects that vanish, in a
/// way that looks like a bug in whichever screen was being built. The store's
/// own doc carries the full argument and the seed's shape.
///
/// ## It enforces no scoping, and that is correct
///
/// [fetchProjects] returns every seeded Project. BR-19's assignment filter is
/// **server-side** — Volume 4 Chapter 4.2 §3's injected
/// `WHERE task_assignments.user_id = :current_user` — so a fake that filtered
/// locally would be modelling a rule the real repository does not implement
/// either, and would hide the fact that nothing client-side enforces BR-19.
class FakeProjectTaskRepository implements ProjectTaskRepository {
  /// Creates the fake over [store].
  ///
  /// The store is supplied rather than constructed so the composition root can
  /// hand the same instance to `FakeProjectTaskAdminRepository`. It was `const`
  /// with a static seed until Mission 5.2.1; a shared mutable store cannot be.
  const FakeProjectTaskRepository({required this.store});

  /// The shared store this reads. Written by `FakeProjectTaskAdminRepository`.
  final InMemoryProjectTaskStore store;

  @override
  Future<List<Project>> fetchProjects() async =>
      List<Project>.unmodifiable(store.projects);

  @override
  Future<List<Task>> fetchTasks(String projectId) async {
    // An unknown Project returns empty rather than throwing. The real
    // repository's 404 is the backend's answer to a Project this Collector
    // cannot see (BR-19), and Chapter 4.6 §1's envelope carries that as an
    // error code — but modelling one specific status here would be inventing
    // a wire detail the fake has no basis for. Empty is the honest stand-in:
    // "no Tasks to show".
    return List<Task>.unmodifiable(store.tasks[projectId] ?? const <Task>[]);
  }
}
