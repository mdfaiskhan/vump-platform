import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/data/fake_project_task_admin_repository.dart';
import 'package:mobile/features/projects_tasks/data/fake_project_task_repository.dart';
import 'package:mobile/features/projects_tasks/data/in_memory_project_task_store.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_create_project_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_create_task_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_project_detail_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_projects_screen.dart';

import '../../../core/time/fakes/fake_clock.dart';

/// A-02, A-03 and the create halves of A-04 and A-05.
///
/// The assertions doing real work are the ones about **absence** — no edit
/// affordance on A-04, no assignment entry point on A-03, no `requirements`
/// field on A-05 — and the **round trip**: a Project created through the form
/// must appear in the list, which is what the shared store exists for.
void main() {
  late InMemoryProjectTaskStore store;

  ({GoRouter router, Widget app}) build(String initial, {bool empty = false}) {
    store = empty
        ? InMemoryProjectTaskStore.empty()
        : InMemoryProjectTaskStore();

    final GoRouter router = GoRouter(
      initialLocation: initial,
      routes: <RouteBase>[
        GoRoute(
          path: '/admin/projects',
          builder: (_, _) => const AdminProjectsScreen(),
        ),
        GoRoute(
          path: '/admin/projects/new',
          builder: (_, _) => const AdminCreateProjectScreen(),
        ),
        GoRoute(
          path: '/admin/projects/:projectId',
          builder: (BuildContext c, GoRouterState s) =>
              AdminProjectDetailScreen(
                projectId: s.pathParameters['projectId'] ?? '',
              ),
        ),
        GoRoute(
          path: '/admin/projects/:projectId/tasks/new',
          builder: (BuildContext c, GoRouterState s) => AdminCreateTaskScreen(
            projectId: s.pathParameters['projectId'] ?? '',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    return (
      router: router,
      app: ProviderScope(
        overrides: <Override>[
          projectTaskRepositoryProvider.overrideWithValue(
            FakeProjectTaskRepository(store: store),
          ),
          projectTaskAdminRepositoryProvider.overrideWithValue(
            FakeProjectTaskAdminRepository(
              store: store,
              clock: FakeClock(start: DateTime.utc(2026, 9, 1, 10)),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    String initial, {
    bool empty = false,
  }) async {
    await tester.pumpWidget(build(initial, empty: empty).app);
    await tester.pumpAndSettle();
  }

  group('A-02 — Projects List (Admin)', () {
    testWidgets('it lists Projects and offers + New Project', (
      WidgetTester tester,
    ) async {
      // Ch. 2.7 §5: the Collector's pattern "with Admin-only action buttons
      // ('+ New Project', '+ New Task') added per FR-ADM-01/02".
      await pump(tester, '/admin/projects');

      expect(find.text('Riverside Corridor Survey'), findsOneWidget);
      expect(find.text('New Project'), findsOneWidget);
    });

    testWidgets('the empty state leads INTO the action, unlike C-04s', (
      WidgetTester tester,
    ) async {
      // Ch. 2.9 §4.2 specifies the two separately: a Collector "sees a
      // plain-language explanation", an Admin's list "leads directly into the
      // '+ New Project' action, since that empty state has an obvious, single
      // next step". C-04 says wait; this says do this.
      await pump(tester, '/admin/projects', empty: true);

      expect(find.text('No Projects yet'), findsOneWidget);
      expect(find.text('No Projects are assigned to you yet.'), findsNothing);
      // The action itself is present in the empty state, not only in the FAB.
      expect(find.widgetWithText(FilledButton, 'New Project'), findsOneWidget);
    });

    testWidgets('an archived Project is marked with a word', (
      WidgetTester tester,
    ) async {
      // A-109, the same marker C-04 uses. Ch. 2.10 §2.1: never colour alone.
      await pump(tester, '/admin/projects');

      expect(find.text('Archived'), findsOneWidget);
    });
  });

  group('A-03 — Project Detail (Admin)', () {
    testWidgets('it lists Tasks and offers + New Task', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/admin/projects/prj-riverside-survey');

      expect(find.text('East embankment, north to south'), findsOneWidget);
      expect(find.text('New Task'), findsOneWidget);
    });

    testWidgets('there is NO Collector-assignment entry point', (
      WidgetTester tester,
    ) async {
      // Ch. 2.5 promises "entry points to create/edit and to Collector
      // assignment". A-06 cannot be built -- no endpoint returns current
      // assignments, and none returns the org's Collectors (open item 89) --
      // so there is no button rather than a disabled one. A greyed control
      // implies a capability that is temporarily off; nothing is off.
      await pump(tester, '/admin/projects/prj-riverside-survey');

      expect(find.textContaining('Assign'), findsNothing);
      expect(find.textContaining('Collector'), findsNothing);
    });

    testWidgets('a Task row is not tappable, because it leads nowhere', (
      WidgetTester tester,
    ) async {
      // Edit (item 90) and assignment (item 89) are both unbuilt, so a tap
      // target would promise a destination that does not exist.
      await pump(tester, '/admin/projects/prj-riverside-survey');

      final ListTile row = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Bridge underside inspection'),
      );
      expect(row.onTap, isNull);
      expect(row.trailing, isNull);
    });

    testWidgets('an empty Project says so and keeps the action available', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/admin/projects/prj-northgate-retired');

      expect(find.textContaining('No Tasks yet'), findsOneWidget);
      expect(find.text('New Task'), findsOneWidget);
    });

    testWidgets('an unknown Project reports unavailability', (
      WidgetTester tester,
    ) async {
      // BR-20 scopes an Admin server-side, so "outside your scope" and "does
      // not exist" are indistinguishable here. The copy claims neither.
      await pump(tester, '/admin/projects/prj-nope');

      expect(find.text("This Project isn't available to you."), findsOneWidget);
      expect(find.text('New Task'), findsNothing);
    });
  });

  group('A-04 — Create Project, and only create', () {
    testWidgets('it renders name and description', (WidgetTester tester) async {
      await pump(tester, '/admin/projects/new');

      expect(find.text('Project name'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('there is NO edit affordance, disabled or otherwise', (
      WidgetTester tester,
    ) async {
      // Item 87: no PATCH /v1/projects/{id} and no FR either -- FR-ADM-01 is
      // create-only. A greyed Edit button would imply a capability that is
      // temporarily off. Mission 5.1.5's C-12 decision, applied again.
      await pump(tester, '/admin/projects/new');

      expect(find.textContaining('Edit'), findsNothing);
      expect(find.text('New Project'), findsOneWidget);
    });

    testWidgets('"Project-level settings" is absent, with no placeholder', (
      WidgetTester tester,
    ) async {
      // Ch. 2.5's A-04 names three things and the third appears exactly once
      // in all of Volume 2 -- in that row. No column, no field, no definition.
      // Open item 91. An empty "Settings" section would imply it is coming.
      await pump(tester, '/admin/projects/new');

      expect(find.textContaining('ettings'), findsNothing);
    });

    testWidgets('a blank name is refused inline, naming the fix', (
      WidgetTester tester,
    ) async {
      // Ch. 2.9 §2 principle 1: name the specific cause and the specific fix;
      // a generic "Something went wrong" is a defect. Ch. 2.10 §4: announced,
      // not just shown -- TextFormField attaches errorText to the field's
      // semantics, so it is read with the label.
      await pump(tester, '/admin/projects/new');

      await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a name for this Project.'), findsOneWidget);
      // Nothing was written.
      expect(store.projects, hasLength(3));
    });

    testWidgets('creating returns to the list, where the Project appears', (
      WidgetTester tester,
    ) async {
      // The round trip the shared store exists for (A-117). Ch. 2.9 §2
      // principle 2 wants an unambiguous confirmation, and seeing the thing
      // you made is a stronger one than a toast.
      await pump(tester, '/admin/projects/new');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Project name'),
        'Harbour Survey',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
      await tester.pumpAndSettle();

      expect(find.text('Harbour Survey'), findsOneWidget);
      expect(
        find.widgetWithText(FloatingActionButton, 'New Project'),
        findsOneWidget,
      );
      expect(store.projects, hasLength(4));
    });

    testWidgets('an empty description is stored as absent, not blank', (
      WidgetTester tester,
    ) async {
      // Ch. 4.4 §2 makes the column nullable precisely so "no description" and
      // "an empty one" are distinguishable; a stored "" renders as a blank
      // line on C-04 rather than as absence.
      await pump(tester, '/admin/projects/new');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Project name'),
        'Harbour',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
      await tester.pumpAndSettle();

      final Project created = store.projects.last;
      expect(created.description, isNull);
    });
  });

  group('A-05 — Create Task, and only create', () {
    testWidgets('it renders title and instructions', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/admin/projects/prj-depot-inventory/tasks/new');

      expect(find.text('Task title'), findsOneWidget);
      expect(find.text('Instructions'), findsOneWidget);
    });

    testWidgets('there is NO requirements field — open item 69', (
      WidgetTester tester,
    ) async {
      // Ch. 2.5's A-05 names "instructions, reference examples, requirements".
      // Ch. 4.4 §3's tasks table has no such column and `createTask` takes no
      // such parameter (5.2.1). C-06 omits it on the read side (A-110); this
      // is the write side of the same gap.
      await pump(tester, '/admin/projects/prj-depot-inventory/tasks/new');

      expect(find.textContaining('equirement'), findsNothing);
    });

    testWidgets('reference examples are absent, blocked on a component', (
      WidgetTester tester,
    ) async {
      // A real column that `createTask` accepts -- but entering a list of
      // media URLs needs a repeating field Ch. 2.8 would specify, and Ch. 2.8
      // is not in this repository (open item 74).
      await pump(tester, '/admin/projects/prj-depot-inventory/tasks/new');

      expect(find.textContaining('Reference'), findsNothing);
    });

    testWidgets('both required fields are refused blank, each naming its fix', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/admin/projects/prj-depot-inventory/tasks/new');

      await tester.tap(find.widgetWithText(FilledButton, 'Create Task'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a title for this Task.'), findsOneWidget);
      expect(
        find.text('Enter the instructions the Collector should follow.'),
        findsOneWidget,
      );
      expect(store.tasks['prj-depot-inventory'], hasLength(2));
    });

    testWidgets('creating returns to the Project, where the Task appears', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/admin/projects/prj-depot-inventory/tasks/new');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Task title'),
        'Bay C shelving',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Instructions'),
        'Pan up each unit in turn.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Task'));
      await tester.pumpAndSettle();

      expect(find.text('Bay C shelving'), findsOneWidget);
      expect(store.tasks['prj-depot-inventory'], hasLength(3));
      final Task created = store.tasks['prj-depot-inventory']!.last;
      expect(created.referenceExamples, isEmpty);
    });
  });
}
