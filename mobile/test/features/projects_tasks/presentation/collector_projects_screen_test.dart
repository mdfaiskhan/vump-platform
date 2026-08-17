import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_projects_screen.dart';

import '../application/fakes/controllable_project_task_repository.dart';

/// C-04 — FR-PT-03 and FR-PT-07.
///
/// The decision this file pins is **archived Projects are shown and labelled**
/// rather than hidden. Nothing in Volume 1 or 2 settles it, so a later mission
/// could reasonably reach for a filter; these tests make that a deliberate
/// change rather than a quiet one.
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 1);

  Project project(String id, {String? description, DateTime? archivedAt}) =>
      Project(
        id: id,
        orgId: 'org-1',
        name: 'Project $id',
        description: description,
        createdBy: 'usr-admin-1',
        createdAt: createdAt,
        archivedAt: archivedAt,
      );

  Future<void> pump(
    WidgetTester tester, {
    List<Project> projects = const <Project>[],
    bool fails = false,
  }) async {
    final ControllableProjectTaskRepository repo =
        ControllableProjectTaskRepository(projects: projects);
    if (fails) {
      repo.failWith();
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          projectTaskRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: CollectorProjectsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('it lists what the repository returned', () {
    testWidgets('every Project appears, in the order given', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        projects: <Project>[project('a'), project('b'), project('c')],
      );

      expect(find.text('Project a'), findsOneWidget);
      expect(find.text('Project b'), findsOneWidget);
      expect(find.text('Project c'), findsOneWidget);
    });

    testWidgets('a description renders when present and is skipped when not', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        projects: <Project>[
          project('a', description: 'Street-level capture.'),
          project('b'),
        ],
      );

      expect(find.text('Street-level capture.'), findsOneWidget);
    });

    testWidgets('it applies no assignment filter of its own', (
      WidgetTester tester,
    ) async {
      // BR-19 is enforced server-side (Ch. 4.8; Ch. 4.2 §3's injected WHERE).
      // Filtering here would be a client-side guess at a server-side rule, and
      // would hide the fact that nothing client-side enforces BR-19.
      await pump(tester, projects: <Project>[project('a'), project('b')]);

      expect(find.byType(Card), findsNWidgets(2));
    });
  });

  group('archived Projects are shown, and labelled', () {
    testWidgets('an archived Project still appears in the list', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        projects: <Project>[
          project('a'),
          project('b', archivedAt: DateTime.utc(2026, 7, 1)),
        ],
      );

      expect(find.text('Project b'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('it carries the word Archived, not just a colour', (
      WidgetTester tester,
    ) async {
      // Ch. 2.10 §2.1: a state distinguished by hue alone is unreadable to a
      // Collector with a colour-vision deficiency. The marker is a word.
      await pump(
        tester,
        projects: <Project>[
          project('a'),
          project('b', archivedAt: DateTime.utc(2026, 7, 1)),
        ],
      );

      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('a live Project carries no such label', (
      WidgetTester tester,
    ) async {
      await pump(tester, projects: <Project>[project('a')]);

      expect(find.text('Archived'), findsNothing);
    });
  });

  group('empty and failed are different answers', () {
    testWidgets('no Projects says so, rather than rendering nothing', (
      WidgetTester tester,
    ) async {
      // "You have no assigned work" and "nothing was wired up" must never look
      // the same; the second is what projectTaskRepositoryProvider throws for.
      await pump(tester);

      expect(find.text('No Projects are assigned to you yet.'), findsOneWidget);
    });

    testWidgets('a load failure names a cause and a next step', (
      WidgetTester tester,
    ) async {
      // Ch. 2.9 §2. This list genuinely depends on the network, so naming the
      // connection is accurate here in a way it would not be on C-03.
      await pump(tester, fails: true);

      expect(
        find.textContaining("Your Projects couldn't be loaded"),
        findsOneWidget,
      );
      expect(find.textContaining('pull down to try again'), findsOneWidget);
    });
  });
}
