import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/domain/entities/paged_result.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_dashboard_screen.dart';

import '../data/fakes/fake_project_task_repository.dart';
import '../data/fakes/in_memory_project_task_store.dart';

/// A-01 — one sourced tile and Chapter 2.2 step 2's navigation duty.
///
/// The assertions that matter are the **absences**: no Collector-activity
/// summary and no outstanding-Task count, neither rendered as a zero nor as a
/// placeholder. Both would be easy for a later mission to "complete" with an
/// invented number, and both now break a test that names the open item.
void main() {
  late InMemoryProjectTaskStore store;

  Future<String?> pump(WidgetTester tester, {bool empty = false}) async {
    store = empty
        ? InMemoryProjectTaskStore.empty()
        : InMemoryProjectTaskStore();

    String? landed;
    Widget destination(String name) => Scaffold(body: Text(name));

    final GoRouter router = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: <RouteBase>[
        GoRoute(
          path: '/admin/dashboard',
          builder: (_, _) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/projects',
          builder: (_, GoRouterState s) {
            landed = s.uri.toString();
            return destination('projects list');
          },
        ),
        GoRoute(
          path: '/admin/projects/new',
          builder: (_, GoRouterState s) {
            landed = s.uri.toString();
            return destination('create project');
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          projectTaskRepositoryProvider.overrideWithValue(
            FakeProjectTaskRepository(store: store),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return landed;
  }

  group('the one sourced tile', () {
    testWidgets('it counts every managed Project, archived included', (
      WidgetTester tester,
    ) async {
      // Chapter 1.1 §7.3 asks for "all managed Projects", not the active ones,
      // so unlike C-03 this needs no archivedAt reading (A-104). The seed has
      // three Projects, one of them archived.
      await pump(tester);

      expect(find.text('You manage 3 Projects'), findsOneWidget);
    });

    testWidgets('one Project reads in the singular', (
      WidgetTester tester,
    ) async {
      final InMemoryProjectTaskStore one = InMemoryProjectTaskStore.empty()
        ..projects.add(InMemoryProjectTaskStore().projects.first);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            projectTaskRepositoryProvider.overrideWithValue(
              FakeProjectTaskRepository(store: one),
            ),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You manage 1 Project'), findsOneWidget);
    });
  });

  group('the two unsourced tiles render NOTHING', () {
    testWidgets('there is no Collector activity summary', (
      WidgetTester tester,
    ) async {
      // No source under any reading: naming a Collector needs item 92, their
      // assignments need item 89, and org-wide session activity needs a
      // backend (item 36). C-03 set the precedent of omitting silently, and
      // Chapter 2.9 has no vocabulary for "this data has no source" (A-122),
      // so a label would say something false.
      await pump(tester);

      expect(find.textContaining('Collector'), findsNothing);
      expect(find.textContaining('ctivity'), findsNothing);
    });

    testWidgets('there is no outstanding-Task count', (
      WidgetTester tester,
    ) async {
      // "Outstanding" is undefined in Volumes 1 and 2 AND underivable:
      // Chapter 4.4 §3's tasks table has six columns and no status of any
      // kind, so nothing could compute it even once someone defined it
      // (item 94).
      await pump(tester);

      expect(find.textContaining('utstanding'), findsNothing);
      expect(find.textContaining('Task'), findsNothing);
    });

    testWidgets('neither absent tile is rendered as a zero', (
      WidgetTester tester,
    ) async {
      // The failure this guards: a later mission "finishing" the dashboard by
      // showing 0 for both. A zero is a claim about an organisation's work,
      // and it would be a false one.
      await pump(tester);

      expect(find.text('0'), findsNothing);
    });
  });

  group('Chapter 2.2 step 2 — the navigation duty', () {
    testWidgets('New Project reaches the create form', (
      WidgetTester tester,
    ) async {
      // "Selects 'New Project' or an existing Project" -- the first half.
      await pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'New Project'));
      await tester.pumpAndSettle();

      expect(find.text('create project'), findsOneWidget);
    });

    testWidgets('View all Projects reaches the list', (
      WidgetTester tester,
    ) async {
      // "...or an existing Project" -- A-02 is where existing Projects live.
      await pump(tester);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'View all Projects'),
      );
      await tester.pumpAndSettle();

      expect(find.text('projects list'), findsOneWidget);
    });

    testWidgets('no Projects prompts creation, per step 2s branch', (
      WidgetTester tester,
    ) async {
      // Chapter 2.2 step 2: "No Projects yet -> empty state prompting Project
      // creation." Same shape as A-02's empty state under Ch. 2.9 §4.2
      // (A-120): one obvious next step, so the state leads into it.
      await pump(tester, empty: true);

      expect(find.text('No Projects yet'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New Project'), findsOneWidget);
      // The count tile is absent entirely rather than reading zero.
      expect(find.textContaining('You manage'), findsNothing);
    });

    testWidgets('the empty state also reaches the create form', (
      WidgetTester tester,
    ) async {
      await pump(tester, empty: true);

      await tester.tap(find.widgetWithText(FilledButton, 'New Project'));
      await tester.pumpAndSettle();

      expect(find.text('create project'), findsOneWidget);
    });
  });

  group('failure names a cause and a next step', () {
    testWidgets('a load failure is neither empty nor a count', (
      WidgetTester tester,
    ) async {
      final InMemoryProjectTaskStore empty = InMemoryProjectTaskStore.empty();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            projectTaskRepositoryProvider.overrideWithValue(
              _FailingRepository(empty),
            ),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Your Projects couldn't be loaded"),
        findsOneWidget,
      );
      expect(find.text('No Projects yet'), findsNothing);
    });
  });
}

/// A repository whose reads fail, for the error branch.
class _FailingRepository extends FakeProjectTaskRepository {
  const _FailingRepository(InMemoryProjectTaskStore store)
    : super(store: store);

  @override
  Future<PagedResult<Project>> fetchProjects({String? cursor, int? limit}) {
    throw StateError('backend unreachable');
  }
}
