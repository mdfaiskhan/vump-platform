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
/// ## The seed data, and why it is shaped this way
///
/// Three Projects and five Tasks, fixed at construction, no randomness and no
/// artificial delay — a fake that varies between runs makes a widget test
/// flaky for reasons that have nothing to do with the widget.
///
/// The shape is chosen to exercise the requirements 5.1.2's screens must
/// satisfy, rather than to look plausible in a screenshot:
///
/// - **Three Projects, not one** — FR-PT-07, a Collector assigned to more
///   than one Project at a time.
/// - **A Project with no Tasks** — C-05's empty state, which a single-Project
///   seed never reaches.
/// - **A Task with no reference examples, and one with three** — C-06 has to
///   render both an absent list and a multi-item one.
/// - **An archived Project** — so `archivedAt` is non-null somewhere and no
///   consumer quietly assumes it never is.
/// - **A null and a non-null `description`** — Chapter 4.4 §2 makes that
///   column nullable, so C-04 must handle both.
///
/// Timestamps are fixed literals rather than `DateTime.now()` offsets, for the
/// reason Mission 4.4's injectable clock records: a value derived from the
/// wall clock makes a golden test's output depend on when it ran.
///
/// ## It enforces no scoping, and that is correct
///
/// [fetchProjects] returns every seeded Project. BR-19's assignment filter is
/// **server-side** — Volume 4 Chapter 4.2 §3's injected
/// `WHERE task_assignments.user_id = :current_user` — so a fake that filtered
/// locally would be modelling a rule the real repository does not implement
/// either, and would hide the fact that nothing client-side enforces BR-19.
class FakeProjectTaskRepository implements ProjectTaskRepository {
  /// Creates the fake over its fixed seed.
  const FakeProjectTaskRepository();

  static final DateTime _createdAt = DateTime.utc(2026, 8, 1);

  static final List<Project> _projects = <Project>[
    Project(
      id: 'prj-riverside-survey',
      orgId: 'org-vump-demo',
      name: 'Riverside Corridor Survey',
      description: 'Street-level capture along the eastern river corridor.',
      createdBy: 'usr-admin-demo',
      createdAt: _createdAt,
    ),
    Project(
      id: 'prj-depot-inventory',
      orgId: 'org-vump-demo',
      name: 'Depot Inventory Walkthrough',
      createdBy: 'usr-admin-demo',
      createdAt: _createdAt,
    ),
    Project(
      id: 'prj-northgate-retired',
      orgId: 'org-vump-demo',
      name: 'Northgate Pilot',
      description: 'Completed pilot, retained for reference.',
      createdBy: 'usr-admin-demo',
      createdAt: _createdAt,
      archivedAt: DateTime.utc(2026, 7, 15),
    ),
  ];

  static final Map<String, List<Task>> _tasksByProject = <String, List<Task>>{
    'prj-riverside-survey': <Task>[
      Task(
        id: 'tsk-riverside-embankment',
        projectId: 'prj-riverside-survey',
        title: 'East embankment, north to south',
        instructions:
            'Walk the embankment path at a steady pace. Keep the water line '
            'in frame throughout. Do not stop recording at crossings.',
        createdAt: _createdAt,
        referenceExamples: const <String>[
          'https://example.invalid/reference/embankment-pace.mp4',
          'https://example.invalid/reference/embankment-framing.jpg',
          'https://example.invalid/reference/embankment-crossing.jpg',
        ],
      ),
      Task(
        id: 'tsk-riverside-bridge',
        projectId: 'prj-riverside-survey',
        title: 'Bridge underside inspection',
        instructions:
            'Capture the underside of each of the three spans. One continuous '
            'pass per span.',
        createdAt: _createdAt,
      ),
    ],
    'prj-depot-inventory': <Task>[
      Task(
        id: 'tsk-depot-bay-a',
        projectId: 'prj-depot-inventory',
        title: 'Bay A shelving, floor to ceiling',
        instructions:
            'Start at the aisle entrance. Pan up each shelving unit in turn.',
        createdAt: _createdAt,
        referenceExamples: const <String>[
          'https://example.invalid/reference/bay-pan.mp4',
        ],
      ),
      Task(
        id: 'tsk-depot-loading',
        projectId: 'prj-depot-inventory',
        title: 'Loading dock approach',
        instructions: 'Single pass from the gate to the dock door.',
        createdAt: _createdAt,
      ),
    ],
    // Seeded empty on purpose — C-05 needs a Project that lists no Tasks.
    'prj-northgate-retired': <Task>[],
  };

  @override
  Future<List<Project>> fetchProjects() async =>
      List<Project>.unmodifiable(_projects);

  @override
  Future<List<Task>> fetchTasks(String projectId) async {
    // An unknown Project returns empty rather than throwing. The real
    // repository's 404 is the backend's answer to a Project this Collector
    // cannot see (BR-19), and Chapter 4.6 §1's envelope carries that as an
    // error code — but modelling one specific status here would be inventing
    // a wire detail the fake has no basis for. Empty is the honest stand-in:
    // "no Tasks to show".
    return List<Task>.unmodifiable(
      _tasksByProject[projectId] ?? const <Task>[],
    );
  }
}
