import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/features/projects_tasks/data/project_task_dto.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// The wire → entity mapping, against the shapes the backend actually emits.
///
/// The row maps below are not invented. They are the field names
/// `functions/projects/src/index.ts`'s `ProjectDto` and
/// `functions/tasks/src/index.ts`'s `TaskDto` declare, with the timestamp
/// format the Data API returns — `2026-08-19 10:00:00+00`, which is the literal
/// string those functions' own tests assert on.
void main() {
  Map<String, Object?> projectRow({
    Object? description = 'The riverside embankment survey.',
    Object? archivedAt,
  }) {
    return <String, Object?>{
      'id': 'a3f1c2d4-0000-4000-8000-000000000001',
      'org_id': 'a3f1c2d4-0000-4000-8000-0000000000ff',
      'name': 'Riverside Survey',
      'description': description,
      'created_by': 'a3f1c2d4-0000-4000-8000-0000000000aa',
      'created_at': '2026-08-19 10:00:00+00',
      'archived_at': archivedAt,
    };
  }

  Map<String, Object?> taskRow({Object? referenceExamples}) {
    return <String, Object?>{
      'id': 'b3f1c2d4-0000-4000-8000-000000000001',
      'project_id': 'a3f1c2d4-0000-4000-8000-000000000001',
      'title': 'Embankment north face',
      'instructions': 'Record the full north face at walking pace.',
      'reference_examples': referenceExamples,
      'created_at': '2026-08-19 10:00:00+00',
    };
  }

  group('Project', () {
    test('every snake_case column reaches its camelCase field', () {
      final Project project = projectFromJson(projectRow());

      expect(project.id, 'a3f1c2d4-0000-4000-8000-000000000001');
      expect(project.orgId, 'a3f1c2d4-0000-4000-8000-0000000000ff');
      expect(project.name, 'Riverside Survey');
      expect(project.description, 'The riverside embankment survey.');
      expect(project.createdBy, 'a3f1c2d4-0000-4000-8000-0000000000aa');
      expect(project.archivedAt, isNull);
    });

    test('the Data API timestamp format parses, and parses as UTC', () {
      // `2026-08-19 10:00:00+00` is a SPACE separator and a two-digit offset —
      // not ISO-8601. If this ever stops holding, every created_at in the app
      // shifts by the device's timezone offset and nothing else reports it.
      final Project project = projectFromJson(projectRow());

      expect(project.createdAt.isUtc, isTrue);
      expect(project.createdAt, DateTime.utc(2026, 8, 19, 10));
    });

    test('a null description stays null — Chapter 4.4 §2 allows it', () {
      expect(
        projectFromJson(projectRow(description: null)).description,
        isNull,
      );
    });

    test('archived_at is carried as a timestamp, not narrowed', () {
      // A-097: narrowing it to a bool would discard *when*, and no chapter says
      // the Collector's list filters archived Projects.
      final Project project = projectFromJson(
        projectRow(archivedAt: '2026-07-01 09:30:00+00'),
      );

      expect(project.archivedAt, DateTime.utc(2026, 7, 1, 9, 30));
    });

    test('a missing NOT NULL column is raised, not defaulted', () {
      // The alternative is a Project named '' rendering in C-04 as though it
      // were real.
      final Map<String, Object?> row = projectRow()..remove('name');

      expect(
        () => projectFromJson(row),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.errorCode,
            'errorCode',
            ErrorCode.networkSerialization,
          ),
        ),
      );
    });

    test('an unparseable timestamp is raised', () {
      final Map<String, Object?> row = projectRow()
        ..['created_at'] = 'the day before yesterday';

      expect(() => projectFromJson(row), throwsA(isA<NetworkException>()));
    });
  });

  group('Task', () {
    test('every column reaches its field', () {
      final Task task = taskFromJson(
        taskRow(referenceExamples: <Object?>['https://example.test/a.mp4']),
      );

      expect(task.id, 'b3f1c2d4-0000-4000-8000-000000000001');
      expect(task.projectId, 'a3f1c2d4-0000-4000-8000-000000000001');
      expect(task.title, 'Embankment north face');
      expect(task.instructions, 'Record the full north face at walking pace.');
      expect(task.referenceExamples, <String>['https://example.test/a.mp4']);
      expect(task.createdAt, DateTime.utc(2026, 8, 19, 10));
    });

    test('a null reference_examples collapses to empty — A-097', () {
      // "A null array and an empty array carry the same fact", so C-05 and
      // C-06 render one shape rather than branching on a difference that means
      // nothing.
      expect(
        taskFromJson(taskRow(referenceExamples: null)).referenceExamples,
        isEmpty,
      );
    });

    test('an absent reference_examples collapses to empty as well', () {
      final Map<String, Object?> row = taskRow()..remove('reference_examples');

      expect(taskFromJson(row).referenceExamples, isEmpty);
    });

    test('a non-string element is dropped, not raised', () {
      // Chapter 4.4 §3 gives the elements no structure beyond "media URLs", so
      // one unreadable entry is not grounds to refuse the whole Task.
      final Task task = taskFromJson(
        taskRow(referenceExamples: <Object?>['a', 7, null, 'b']),
      );

      expect(task.referenceExamples, <String>['a', 'b']);
    });

    test('a missing instructions is raised', () {
      final Map<String, Object?> row = taskRow()..remove('instructions');

      expect(() => taskFromJson(row), throwsA(isA<NetworkException>()));
    });
  });
}
