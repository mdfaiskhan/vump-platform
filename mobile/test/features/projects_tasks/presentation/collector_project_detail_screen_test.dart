import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_project_detail_screen.dart';

import '../application/fakes/controllable_project_task_repository.dart';

/// C-05 — FR-PT-04.
///
/// The pair worth having here is **empty versus not-found**. A bare
/// `ListView` renders both as blank, and they mean opposite things: one is a
/// Project waiting for work, the other is a link that no longer resolves.
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 1);

  Project project(String id) => Project(
    id: id,
    orgId: 'org-1',
    name: 'Project $id',
    createdBy: 'usr-admin-1',
    createdAt: createdAt,
  );

  Task task(String id, String projectId) => Task(
    id: id,
    projectId: projectId,
    title: 'Task $id',
    instructions: 'Do the thing.',
    createdAt: createdAt,
  );

  Future<void> pump(
    WidgetTester tester, {
    required String projectId,
    List<Project> projects = const <Project>[],
    Map<String, List<Task>> tasks = const <String, List<Task>>{},
    bool fails = false,
  }) async {
    final ControllableProjectTaskRepository repo =
        ControllableProjectTaskRepository(projects: projects, tasks: tasks);
    if (fails) {
      repo.failWith();
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          projectTaskRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: CollectorProjectDetailScreen(projectId: projectId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('it lists the Project’s Tasks', () {
    testWidgets('each Task appears', (WidgetTester tester) async {
      await pump(
        tester,
        projectId: 'p1',
        projects: <Project>[project('p1')],
        tasks: <String, List<Task>>{
          'p1': <Task>[task('t1', 'p1'), task('t2', 'p1')],
        },
      );

      expect(find.text('Task t1'), findsOneWidget);
      expect(find.text('Task t2'), findsOneWidget);
    });

    testWidgets('the title is the Project name, not its id', (
      WidgetTester tester,
    ) async {
      // Chapter 4.6 §3 has no GET /v1/projects/{id}, so the name is read out
      // of projectsProvider rather than fetched. No repository method added.
      await pump(
        tester,
        projectId: 'p1',
        projects: <Project>[project('p1')],
        tasks: <String, List<Task>>{
          'p1': <Task>[task('t1', 'p1')],
        },
      );

      expect(find.text('Project p1'), findsOneWidget);
      expect(find.text('p1'), findsNothing);
    });
  });

  group('empty and not-found are told apart', () {
    testWidgets('a Project with zero Tasks says so explicitly', (
      WidgetTester tester,
    ) async {
      // 5.1.1's fake seeds prj-northgate-retired with no Tasks precisely so
      // this branch is reachable on a device as well as here.
      await pump(tester, projectId: 'p1', projects: <Project>[project('p1')]);

      expect(find.text('This Project has no Tasks yet.'), findsOneWidget);
    });

    testWidgets('an unknown Project id reports unavailability, not emptiness', (
      WidgetTester tester,
    ) async {
      // BR-19 makes "not assigned" and "does not exist" indistinguishable from
      // the client, deliberately, so the copy claims neither.
      await pump(tester, projectId: 'p-missing');

      expect(find.text("This Project isn't available to you."), findsOneWidget);
      expect(find.text('This Project has no Tasks yet.'), findsNothing);
    });

    testWidgets('a load failure is neither of the above', (
      WidgetTester tester,
    ) async {
      await pump(tester, projectId: 'p1', fails: true);

      expect(
        find.textContaining("This Project's Tasks couldn't be loaded"),
        findsOneWidget,
      );
      expect(find.text('This Project has no Tasks yet.'), findsNothing);
    });
  });
}
