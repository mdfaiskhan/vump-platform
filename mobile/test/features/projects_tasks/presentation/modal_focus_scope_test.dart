import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/data/fake_project_task_admin_repository.dart';
import 'package:mobile/features/projects_tasks/data/fake_project_task_repository.dart';
import 'package:mobile/features/projects_tasks/data/in_memory_project_task_store.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_create_project_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_projects_screen.dart';

import '../../../core/time/fakes/fake_clock.dart';

/// Chapter 2.10 §5's modal focus rule, and the half of it this app satisfies.
///
/// > *"Modal screens (Checklist, Create/Edit forms, Metadata Detail) trap focus
/// > within the modal while open, and return focus to the triggering element on
/// > dismissal."*
///
/// ## The trap is satisfied by construction, and that needed proving, not
/// assuming
///
/// Every screen Chapter 2.4 calls a modal is a **full-screen GoRoute reached by
/// `context.go`**, which REPLACES the location rather than pushing an overlay.
/// There is no `Navigator.push` and no `showDialog` on any of these paths. So
/// the triggering screen is not merely unfocusable — it is **not in the widget
/// tree at all**, which is a stronger property than a focus trap.
///
/// **No `FocusScope` was added to satisfy §5.** Adding one would have been
/// redundant code implying the framework was not already doing this, and the
/// point of these tests is to hold the property rather than to decorate it.
/// They fail if someone converts a modal to a pushed route or an overlay
/// without revisiting focus.
///
/// ## The second half of §5 is NOT satisfied, and cannot be
///
/// *"return focus to the triggering element on dismissal"* has no meaning under
/// `go`. Dismissal navigates to a route that is rebuilt from scratch, so the
/// triggering element is a **new widget with no focus history** — there is
/// nothing to return focus to. Recorded as an open item rather than papered
/// over, because it is a consequence of the navigation model (ADR-004,
/// `context.go` everywhere), not a missing line in a form.
void main() {
  Widget build(String initial) {
    final InMemoryProjectTaskStore store = InMemoryProjectTaskStore();
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
      ],
    );
    addTearDown(router.dispose);

    return ProviderScope(
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
    );
  }

  testWidgets('the triggering screen leaves the tree entirely', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(build('/admin/projects'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminProjectsScreen), findsOneWidget);

    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();

    // Not "present but unfocusable" — absent. Nothing on the list screen can
    // take focus because nothing on it exists.
    expect(find.byType(AdminCreateProjectScreen), findsOneWidget);
    expect(find.byType(AdminProjectsScreen), findsNothing);
  });

  testWidgets('tabbing through the modal never escapes it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(build('/admin/projects/new'));
    await tester.pumpAndSettle();

    // Walk further than the modal has focusable stops, so the traversal wraps
    // rather than merely running out. A leak would surface as a focused node
    // outside this subtree.
    final Finder modal = find.byType(AdminCreateProjectScreen);
    int checked = 0;
    for (int i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final FocusNode? focused = FocusManager.instance.primaryFocus;
      if (focused == null || focused.context == null) {
        continue;
      }
      expect(
        find.ancestor(of: find.byWidget(_widgetOf(focused)), matching: modal),
        findsOneWidget,
        reason: 'focus escaped the modal on tab $i',
      );
      checked++;
    }

    // Without this the loop above passes by never asserting anything — a tab
    // that focuses nothing skips the check, and twelve of those would look
    // identical to twelve successes. This is the assertion that makes the
    // test a test.
    expect(checked, 12, reason: 'every tab must land on a real focus node');
  });
}

Widget _widgetOf(FocusNode node) => node.context!.widget;
