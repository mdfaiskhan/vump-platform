import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// The one in-memory store both fakes read and write.
///
/// ## Why one store rather than two independent fakes
///
/// Mission 5.1.1's `FakeProjectTaskRepository` held its seed in two
/// `static final` collections — correct for a read-only stand-in, and unusable
/// the moment a write path exists. Two independent fakes would mean
/// `FakeProjectTaskAdminRepository.createProject` succeeding while
/// `FakeProjectTaskRepository.fetchProjects` never showed the result, so
/// Mission 5.2.2's CRUD screens would create Projects that vanish.
///
/// **Two fakes that disagree are worse than one shared store**, and the
/// disagreement would not look like a bug in either fake — it would look like
/// a bug in whichever screen was being built at the time. So the seed moved
/// here and both fakes hold a reference to the same instance, introduced at
/// the composition root exactly as the real repositories will be.
///
/// This mirrors what `main.dart` already does for `IsarChunkStore`: one
/// instance behind four contracts, so every reader sees the same rows.
///
/// ## It is a fake's state, not a domain type
///
/// Nothing outside `data/` names this class. Both repositories expose only
/// their domain interfaces, so the shared store is invisible above this layer
/// and disappears entirely when Mission 7 swaps in the real implementations —
/// the M8 gate `FakeProjectTaskRepository` already documents.
///
/// ## Assignments are recorded and never read back through a repository
///
/// [assignments] exists because `FakeProjectTaskAdminRepository` writes to it,
/// and **no repository method reads it**, because Volume 4 Chapter 4.6 §3 has
/// no endpoint that does — only `POST` and `DELETE` on
/// `/v1/tasks/{id}/assignments`. Volume 2 Chapter 2.7's A-06 nonetheless
/// requires its checkboxes to *"reflect current assignment state on load"*,
/// which is open item 89.
///
/// Tests inspect this field directly. That is deliberate: a fake's own state
/// is a legitimate thing for a test to assert against, and inventing a domain
/// read method the backend cannot serve is the rework 5.1.1 refused when it
/// declined `fetchTask(taskId)`.
class InMemoryProjectTaskStore {
  /// Creates a store over the standard seed.
  InMemoryProjectTaskStore()
    : projects = List<Project>.from(_seedProjects),
      tasks = Map<String, List<Task>>.fromEntries(
        _seedTasks.entries.map(
          (MapEntry<String, List<Task>> e) =>
              MapEntry<String, List<Task>>(e.key, List<Task>.from(e.value)),
        ),
      );

  /// Creates an empty store, for tests that want to write from nothing.
  InMemoryProjectTaskStore.empty()
    : projects = <Project>[],
      tasks = <String, List<Task>>{};

  /// Every Project, in insertion order. Newest created is last.
  final List<Project> projects;

  /// Tasks by `project_id`, each list in insertion order.
  final Map<String, List<Task>> tasks;

  /// Collector ids by `task_id` — write-only through the repositories.
  final Map<String, Set<String>> assignments = <String, Set<String>>{};

  /// The org every seeded row belongs to, and the one new rows inherit.
  ///
  /// A create call carries no `org_id`: Volume 4 Chapter 4.8 has the backend
  /// derive it from the verified token, so the client never sends one and this
  /// stands in for what the server would assign.
  static const String seedOrgId = 'org-vump-demo';

  /// The Admin every seeded row was created by, and that new rows inherit.
  ///
  /// Same reasoning as [seedOrgId] — `created_by` is the token's subject,
  /// assigned server-side, never client-supplied.
  static const String seedCreatedBy = 'usr-admin-demo';

  static final DateTime _createdAt = DateTime.utc(2026, 8, 1);

  static final List<Project> _seedProjects = <Project>[
    Project(
      id: 'prj-riverside-survey',
      orgId: seedOrgId,
      name: 'Riverside Corridor Survey',
      description: 'Street-level capture along the eastern river corridor.',
      createdBy: seedCreatedBy,
      createdAt: _createdAt,
    ),
    Project(
      id: 'prj-depot-inventory',
      orgId: seedOrgId,
      name: 'Depot Inventory Walkthrough',
      createdBy: seedCreatedBy,
      createdAt: _createdAt,
    ),
    Project(
      id: 'prj-northgate-retired',
      orgId: seedOrgId,
      name: 'Northgate Pilot',
      description: 'Completed pilot, retained for reference.',
      createdBy: seedCreatedBy,
      createdAt: _createdAt,
      archivedAt: DateTime.utc(2026, 7, 15),
    ),
  ];

  static final Map<String, List<Task>> _seedTasks = <String, List<Task>>{
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
}
