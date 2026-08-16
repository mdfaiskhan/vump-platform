import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/projects_tasks/data/fake_project_task_repository.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// The fake's seed is a contract, not decoration.
///
/// Mission 5.1.2's screens are built against exactly this data, so each seeded
/// property below exists to exercise a specific rendering requirement. A later
/// mission that "tidies" the seed — one Project, no archived row, every Task
/// with examples — would silently delete the only coverage C-05's empty state
/// and C-06's absent-examples branch ever had. These tests are what make that
/// deletion fail loudly.
void main() {
  const FakeProjectTaskRepository repository = FakeProjectTaskRepository();

  group('fetchProjects — the seed FR-PT-03 and FR-PT-07 need', () {
    test('it returns three Projects, not one', () async {
      // FR-PT-07: "a Collector being assigned to more than one Project at a
      // time". A single-Project seed cannot exercise C-04 as a list at all.
      expect(await repository.fetchProjects(), hasLength(3));
    });

    test('exactly one Project is archived', () async {
      final List<Project> projects = await repository.fetchProjects();

      final Iterable<Project> archived = projects.where(
        (Project p) => p.archivedAt != null,
      );

      expect(archived, hasLength(1));
      expect(archived.single.id, 'prj-northgate-retired');
    });

    test('both a null and a non-null description are present', () async {
      // Chapter 4.4 §2 makes `description` nullable, so C-04 must render both
      // and the seed must contain both.
      final List<Project> projects = await repository.fetchProjects();

      expect(projects.any((Project p) => p.description == null), isTrue);
      expect(projects.any((Project p) => p.description != null), isTrue);
    });

    test('every Project carries the same org — BR-20 scoping', () async {
      final List<Project> projects = await repository.fetchProjects();

      expect(projects.map((Project p) => p.orgId).toSet(), <String>{
        'org-vump-demo',
      });
    });

    test('it applies no BR-19 filtering, deliberately', () async {
      // BR-19's assignment scope is server-side (Ch. 4.2 §3's injected WHERE
      // clause). A fake that filtered locally would model a rule the real
      // repository does not implement either, and would hide that nothing
      // client-side enforces BR-19. Every seeded Project comes back, including
      // the archived one.
      final List<Project> projects = await repository.fetchProjects();

      expect(projects.map((Project p) => p.id), <String>[
        'prj-riverside-survey',
        'prj-depot-inventory',
        'prj-northgate-retired',
      ]);
    });
  });

  group('fetchTasks — the seed FR-PT-04 and FR-PT-05 need', () {
    test('a known Project returns its Tasks', () async {
      final List<Task> tasks = await repository.fetchTasks(
        'prj-riverside-survey',
      );

      expect(tasks.map((Task t) => t.id), <String>[
        'tsk-riverside-embankment',
        'tsk-riverside-bridge',
      ]);
    });

    test('every returned Task names the Project it was asked for', () async {
      final List<Task> tasks = await repository.fetchTasks(
        'prj-depot-inventory',
      );

      expect(
        tasks.every((Task t) => t.projectId == 'prj-depot-inventory'),
        isTrue,
      );
    });

    test('one Project is seeded with no Tasks at all — C-05 empty', () async {
      // The empty state a one-Project seed never reaches.
      expect(await repository.fetchTasks('prj-northgate-retired'), isEmpty);
    });

    test('an unknown Project id returns empty rather than throwing', () async {
      // The real repository answers a 404 here, because BR-19 makes an
      // unassigned Project invisible rather than absent. Modelling a specific
      // status in the fake would be inventing a wire detail; empty is the
      // honest stand-in for "no Tasks to show".
      expect(await repository.fetchTasks('prj-does-not-exist'), isEmpty);
    });

    test('one Task carries three reference examples — C-06 list', () async {
      final List<Task> tasks = await repository.fetchTasks(
        'prj-riverside-survey',
      );

      final Task withExamples = tasks.firstWhere(
        (Task t) => t.id == 'tsk-riverside-embankment',
      );

      expect(withExamples.referenceExamples, hasLength(3));
    });

    test('another Task carries none — C-06 absent branch', () async {
      final List<Task> tasks = await repository.fetchTasks(
        'prj-riverside-survey',
      );

      final Task withoutExamples = tasks.firstWhere(
        (Task t) => t.id == 'tsk-riverside-bridge',
      );

      expect(withoutExamples.referenceExamples, isEmpty);
    });

    test('every seeded Task has non-empty instructions', () async {
      // Chapter 4.4 §3 marks the column NOT NULL and C-06 renders it. A seed
      // with a blank instruction would make C-06 look correct while showing a
      // Collector nothing to do.
      for (final String projectId in <String>[
        'prj-riverside-survey',
        'prj-depot-inventory',
      ]) {
        for (final Task task in await repository.fetchTasks(projectId)) {
          expect(task.instructions, isNotEmpty, reason: task.id);
        }
      }
    });
  });

  group('it is deterministic and immutable', () {
    test('two reads return equal data', () async {
      // No randomness and no wall-clock derivation — a fake that varies
      // between runs makes a widget test flaky for reasons that have nothing
      // to do with the widget (Mission 4.4's injectable-clock reasoning).
      expect(
        await repository.fetchProjects(),
        await repository.fetchProjects(),
      );
      expect(
        await repository.fetchTasks('prj-riverside-survey'),
        await repository.fetchTasks('prj-riverside-survey'),
      );
    });

    test('timestamps are fixed literals, not derived from now', () async {
      final List<Project> projects = await repository.fetchProjects();

      expect(projects.map((Project p) => p.createdAt).toSet(), <DateTime>{
        DateTime.utc(2026, 8, 1),
      });
    });

    test('a returned Projects list cannot be mutated by a caller', () async {
      // One shared seed behind every read. Handing out a mutable view would
      // let one screen's edit change what the next screen sees.
      final List<Project> projects = await repository.fetchProjects();

      expect(projects.clear, throwsUnsupportedError);
    });

    test('a returned Tasks list cannot be mutated by a caller', () async {
      final List<Task> tasks = await repository.fetchTasks(
        'prj-riverside-survey',
      );

      expect(tasks.clear, throwsUnsupportedError);
    });
  });
}
