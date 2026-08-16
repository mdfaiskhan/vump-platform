import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_task_detail_screen.dart';

import '../application/fakes/controllable_project_task_repository.dart';

/// C-06 — FR-PT-05, and Chapter 2.3 §5's sole path toward capture.
///
/// Two assertions here are about **what is deliberately missing**: there is no
/// requirements section (open item 69), and reference examples do not open
/// (open item 80). Both would be easy for a later mission to "finish" without
/// settling the question underneath, and both fail loudly if it does.
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 1);

  Task task({List<String> examples = const <String>[]}) => Task(
    id: 't1',
    projectId: 'p1',
    title: 'East embankment',
    instructions: 'Walk the embankment path at a steady pace.',
    createdAt: createdAt,
    referenceExamples: examples,
  );

  Future<String?> pump(
    WidgetTester tester, {
    String taskId = 't1',
    List<Task> tasks = const <Task>[],
    bool fails = false,
  }) async {
    final ControllableProjectTaskRepository repo =
        ControllableProjectTaskRepository(
          tasks: <String, List<Task>>{'p1': tasks},
        );
    if (fails) {
      repo.failWith();
    }

    String? navigatedTo;
    final GoRouter router = GoRouter(
      initialLocation: '/collector/projects/p1/tasks/$taskId',
      routes: <RouteBase>[
        GoRoute(
          path: '/collector/projects/:projectId/tasks/:taskId',
          builder: (BuildContext context, GoRouterState state) =>
              CollectorTaskDetailScreen(
                projectId: state.pathParameters['projectId'] ?? '',
                taskId: state.pathParameters['taskId'] ?? '',
              ),
        ),
        GoRoute(
          path: '/checklist/:taskId',
          builder: (BuildContext context, GoRouterState state) {
            navigatedTo = state.uri.toString();
            return const Scaffold(body: Text('checklist'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          projectTaskRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return navigatedTo;
  }

  group('it renders the Task', () {
    testWidgets('title and instructions appear', (WidgetTester tester) async {
      await pump(tester, tasks: <Task>[task()]);

      expect(find.text('East embankment'), findsOneWidget);
      expect(find.text('Instructions'), findsOneWidget);
      expect(
        find.text('Walk the embankment path at a steady pace.'),
        findsOneWidget,
      );
    });

    testWidgets('it selects the right Task out of the Project’s list', (
      WidgetTester tester,
    ) async {
      // No GET /v1/tasks/{id} exists, so the Task is selected from
      // tasksProvider(projectId) -- which only works because 5.1.2 made this
      // screen read the projectId its route already carried.
      final Task other = Task(
        id: 't2',
        projectId: 'p1',
        title: 'Bridge underside',
        instructions: 'One pass per span.',
        createdAt: createdAt,
      );
      await pump(tester, tasks: <Task>[other, task()]);

      expect(find.text('East embankment'), findsOneWidget);
      expect(find.text('Bridge underside'), findsNothing);
    });
  });

  group('FR-PT-05 is only partly satisfied, and visibly so', () {
    testWidgets('there is NO requirements section and no empty slot', (
      WidgetTester tester,
    ) async {
      // FR-PT-05 and Ch. 2.5's C-06 row both name three things. Ch. 4.4 §3's
      // tasks table has no `requirements` column, and whether it is prose
      // inside `instructions` or a missing column is a product question --
      // open item 69. A later mission that adds a section without settling it
      // breaks this test.
      await pump(tester, tasks: <Task>[task()]);

      expect(find.textContaining('Requirement'), findsNothing);
      expect(find.textContaining('requirement'), findsNothing);
      expect(find.text('Instructions'), findsOneWidget);
    });

    testWidgets('reference examples render as text and open nothing', (
      WidgetTester tester,
    ) async {
      // Open item 80: an unopenable URL is close to useless in the field.
      // Making them tappable needs url_launcher, an ADR-030 decision.
      await pump(
        tester,
        tasks: <Task>[
          task(
            examples: const <String>[
              'https://example.invalid/a.mp4',
              'https://example.invalid/b.jpg',
            ],
          ),
        ],
      );

      expect(find.text('Reference examples'), findsOneWidget);
      expect(find.byType(SelectableText), findsNWidgets(2));

      // Scoped to the examples themselves: the screen does have one InkWell,
      // inside Start Recording's FilledButton. What must not exist is a tap
      // target wrapping a URL, which is what would appear the moment somebody
      // reaches for url_launcher without taking the ADR-030 decision.
      expect(
        find.ancestor(
          of: find.text('https://example.invalid/a.mp4'),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('https://example.invalid/a.mp4'),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });

    testWidgets('a Task with no examples says so', (WidgetTester tester) async {
      await pump(tester, tasks: <Task>[task()]);

      expect(find.text('This Task has no reference examples.'), findsOneWidget);
    });
  });

  group('Start Recording goes to the Checklist, never to Recording', () {
    testWidgets('it routes to /checklist/:taskId', (WidgetTester tester) async {
      // Ch. 2.3 §5: "The Recording Screen is reachable only through the
      // Pre-Recording Checklist -- there is no direct path to it from the
      // Dashboard or Task List." RecordingGuard enforces the same rule; this
      // button must not try to bypass it.
      await pump(tester, tasks: <Task>[task()]);

      await tester.tap(find.widgetWithText(FilledButton, 'Start Recording'));
      await tester.pumpAndSettle();

      expect(find.text('checklist'), findsOneWidget);
    });

    testWidgets('no Start Recording button when the Task is unavailable', (
      WidgetTester tester,
    ) async {
      await pump(tester, taskId: 't-missing', tasks: <Task>[task()]);

      expect(find.text("This Task isn't available to you."), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Start Recording'),
        findsNothing,
      );
    });

    testWidgets('no Start Recording button when the load failed', (
      WidgetTester tester,
    ) async {
      await pump(tester, fails: true);

      expect(
        find.widgetWithText(FilledButton, 'Start Recording'),
        findsNothing,
      );
    });
  });
}
