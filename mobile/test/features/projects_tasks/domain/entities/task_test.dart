import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// `Task` against Volume 4 Chapter 4.4 §3's `tasks` table.
///
/// The assertions that matter here are about the one column that was
/// *reshaped* (`reference_examples`, nullable jsonb collapsed to a
/// non-nullable empty list) and the one requirement noun that was
/// *deliberately omitted* (`requirements`, FR-PT-05).
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 1);

  Task task({List<String>? examples}) => Task(
    id: 'tsk-1',
    projectId: 'prj-1',
    title: 'East embankment, north to south',
    instructions: 'Walk the embankment path at a steady pace.',
    createdAt: createdAt,
    referenceExamples: examples ?? const <String>[],
  );

  group('the field list is Chapter 4.4 §3, exactly', () {
    test('all six columns are carried', () {
      final Task subject = task(examples: const <String>['a.mp4']);

      expect(subject.id, 'tsk-1');
      expect(subject.projectId, 'prj-1');
      expect(subject.title, 'East embankment, north to south');
      expect(
        subject.instructions,
        'Walk the embankment path at a steady pace.',
      );
      expect(subject.createdAt, createdAt);
      expect(subject.referenceExamples, <String>['a.mp4']);
    });

    test('instructions is required, because the column is NOT NULL', () {
      // Chapter 4.4 §3 marks `instructions` non-null and notes it is "shown to
      // Collector (C-06) and Admin (A-05)". A Task that cannot say what to
      // record is not a Task, so this is required rather than defaulted to ''.
      final Task subject = task();

      expect(subject.instructions, isNotEmpty);
    });
  });

  group('referenceExamples collapses null to empty', () {
    test('it defaults to an empty list, never null', () {
      // The column is nullable jsonb. A null array and an empty array carry
      // the same fact — this Task has no reference examples — and no chapter
      // distinguishes them, so C-06 renders one shape rather than branching.
      final Task subject = Task(
        id: 'tsk-2',
        projectId: 'prj-1',
        title: 'Bridge underside inspection',
        instructions: 'One continuous pass per span.',
        createdAt: createdAt,
      );

      expect(subject.referenceExamples, isEmpty);
      expect(subject.referenceExamples, isA<List<String>>());
    });

    test('it holds multiple URLs in the order given', () {
      // Chapter 4.4 §3's five-word description is "Array of reference media
      // URLs" — a list of strings, with no element structure invented, and no
      // sort imposed on top of what the backend sent.
      final Task subject = task(
        examples: const <String>['pace.mp4', 'framing.jpg', 'crossing.jpg'],
      );

      expect(subject.referenceExamples, <String>[
        'pace.mp4',
        'framing.jpg',
        'crossing.jpg',
      ]);
    });

    test('an empty list and a populated one make Tasks unequal', () {
      expect(task(), isNot(task(examples: const <String>['a.mp4'])));
    });
  });

  group('FR-PT-05 renders incompletely, on purpose', () {
    test('the entity exposes exactly six members and no requirements', () {
      // FR-PT-05 asks for "instructions, reference examples, and
      // requirements". Chapter 4.4 §3 has no `requirements` column, so the
      // field is omitted rather than invented or folded into `instructions`.
      //
      // This asserts the omission is DELIBERATE and stays visible: if a later
      // mission adds `requirements` without the product answer, this fails and
      // points at the open item rather than letting the field appear quietly.
      final Task subject = task();
      final String json = subject.toString();

      expect(json, contains('instructions'));
      expect(json, contains('referenceExamples'));
      expect(json, isNot(contains('requirements')));
    });
  });

  group('it is a value', () {
    test('two Tasks with identical fields are equal', () {
      expect(task(), task());
      expect(task().hashCode, task().hashCode);
    });

    test('a differing project_id makes two Tasks unequal', () {
      expect(task(), isNot(task().copyWith(projectId: 'prj-other')));
    });
  });
}
