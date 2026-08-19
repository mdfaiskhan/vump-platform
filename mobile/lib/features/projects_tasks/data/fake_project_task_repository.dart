import 'package:mobile/features/projects_tasks/data/in_memory_project_task_store.dart';
import 'package:mobile/features/projects_tasks/domain/entities/paged_result.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/domain/repositories/project_task_repository.dart';

/// A deterministic in-memory [ProjectTaskRepository], for tests.
///
/// ## IT IS NO LONGER WIRED INTO A BUILD — Mission 7.4 step 4
///
/// `ProjectTaskRepositoryImpl` calls Volume 4 Chapter 4.6 §3's real endpoints,
/// and `main.dart` binds that. The removal condition below was met and the
/// binding is gone, which is what Volume 11 Chapter 11.1's M8 gate required:
/// *"no fake/mock repository remains wired into a release build"*.
///
/// **The class survives on purpose, and only as a test double.** Seven test
/// files drive screens through it — both accessibility sweeps among them — and
/// a fake that no build depends on is not what M8 forbids. What M8 forbids is a
/// release path that reaches one, and no release path does: `main.dart` and
/// `main_cleanup_probe.dart` are the only composition roots, and neither names
/// this type any more. That is checkable in one `grep`, which is the point of
/// stating it here rather than trusting it.
///
/// ## Why a fake was allowed to ship, and the gate that ended it
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
/// **REMOVAL CONDITION, as it was written and as it was actually met:** the
/// condition said *"this class and its `main.dart` override are deleted when a
/// real `ProjectTaskRepository` calls Chapter 4.6 §3's endpoints"*. The
/// override is deleted. The class is not, because deleting it would take seven
/// test files with it for no gain that M8 asks for — the gate is about builds,
/// not about the existence of a test double.
///
/// It is rewritten rather than quietly reinterpreted, because the original
/// wording is the kind that gets read later as unmet.
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

  /// Every seeded Project, as a single last page.
  ///
  /// **It paginates nothing**, and ignores [cursor] and [limit]. The seed is
  /// three Projects; slicing it would model the mechanism without exercising
  /// anything, and a test that needs paging behaviour needs a double that can
  /// be told what to return — which is what
  /// `ControllableProjectTaskRepository` is for.
  @override
  Future<PagedResult<Project>> fetchProjects({
    String? cursor,
    int? limit,
  }) async =>
      PagedResult<Project>.last(List<Project>.unmodifiable(store.projects));

  @override
  Future<PagedResult<Task>> fetchTasks(
    String projectId, {
    String? cursor,
    int? limit,
  }) async {
    // An unknown Project returns empty rather than throwing, and that is now
    // a KNOWN DIVERGENCE rather than a lack of basis. The real repository
    // raises RESOURCE_NOT_FOUND (A-186), because a Project the Collector
    // cannot see is reported absent rather than forbidden. This fake keeps the
    // empty answer so the screen tests that predate the real repository still
    // describe what they were written to describe; the 404 path is covered
    // against `ControllableProjectTaskRepository` instead. Divergence named,
    // not hidden:
    // "no Tasks to show".
    return PagedResult<Task>.last(
      List<Task>.unmodifiable(store.tasks[projectId] ?? const <Task>[]),
    );
  }
}
