import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';

/// `Project` against Volume 4 Chapter 4.4 §2's `projects` table.
///
/// What is worth asserting on a freezed data class is not that freezed works.
/// It is that **this entity's shape still matches the table it was traced
/// from** — that the two nullable columns are optional here and the five
/// non-null ones are required, because the moment that drifts, Mission 7's
/// real repository has to reshape data rather than map it.
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 1);

  group('the field list is Chapter 4.4 §2, exactly', () {
    test('all seven columns are carried', () {
      final Project project = Project(
        id: 'prj-1',
        orgId: 'org-1',
        name: 'Riverside Corridor Survey',
        description: 'Street-level capture.',
        createdBy: 'usr-admin-1',
        createdAt: createdAt,
        archivedAt: DateTime.utc(2026, 7, 15),
      );

      expect(project.id, 'prj-1');
      expect(project.orgId, 'org-1');
      expect(project.name, 'Riverside Corridor Survey');
      expect(project.description, 'Street-level capture.');
      expect(project.createdBy, 'usr-admin-1');
      expect(project.createdAt, createdAt);
      expect(project.archivedAt, DateTime.utc(2026, 7, 15));
    });

    test('the two nullable columns are optional and default to null', () {
      // `description` and `archived_at` are the only two columns Chapter 4.4
      // §2 marks nullable. Constructing without them must compile and must
      // leave them null rather than blank — a blank description would be a
      // description the Admin never wrote.
      final Project project = Project(
        id: 'prj-2',
        orgId: 'org-1',
        name: 'Depot Inventory Walkthrough',
        createdBy: 'usr-admin-1',
        createdAt: createdAt,
      );

      expect(project.description, isNull);
      expect(project.archivedAt, isNull);
    });
  });

  group('archiving is a timestamp, not a flag', () {
    test('a live Project has a null archivedAt', () {
      final Project project = Project(
        id: 'prj-3',
        orgId: 'org-1',
        name: 'Live',
        createdBy: 'usr-admin-1',
        createdAt: createdAt,
      );

      expect(project.archivedAt, isNull);
    });

    test('archiving records when, and changes nothing else', () {
      // Chapter 4.2 §1 makes soft-delete a timestamp deliberately so archived
      // data stays queryable. Narrowing it to a boolean would discard *when*.
      final Project live = Project(
        id: 'prj-3',
        orgId: 'org-1',
        name: 'Northgate Pilot',
        createdBy: 'usr-admin-1',
        createdAt: createdAt,
      );
      final DateTime archivedAt = DateTime.utc(2026, 7, 15);

      final Project archived = live.copyWith(archivedAt: archivedAt);

      expect(archived.archivedAt, archivedAt);
      expect(archived.id, live.id);
      expect(archived.name, live.name);
      expect(archived.createdAt, live.createdAt);
    });
  });

  group('it is a value', () {
    test('two Projects with identical fields are equal', () {
      Project make() => Project(
        id: 'prj-1',
        orgId: 'org-1',
        name: 'Same',
        createdBy: 'usr-admin-1',
        createdAt: createdAt,
      );

      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('a differing org_id makes two Projects unequal', () {
      // BR-20 scopes every Admin query by org. Two Projects that differ only
      // by org must never compare equal, or a cross-tenant leak looks like a
      // cache hit.
      final Project a = Project(
        id: 'prj-1',
        orgId: 'org-1',
        name: 'Same',
        createdBy: 'usr-admin-1',
        createdAt: createdAt,
      );
      final Project b = a.copyWith(orgId: 'org-2');

      expect(a, isNot(b));
    });
  });
}
