import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/recording/presentation/record_shortcut_screen.dart';

/// The Record tab after Mission 5.1.3 removed the debug button.
///
/// The assertion that matters most is the negative one: **no route to
/// `/checklist/…` originates here any more**. The temporary button that did so
/// carried a hardcoded fake Task id, and its stated removal condition was a
/// real Task picker existing. C-04/C-05/C-06 are that picker, so this screen
/// now points at them instead of jumping the queue.
void main() {
  Future<String?> pump(WidgetTester tester) async {
    String? navigatedTo;
    final GoRouter router = GoRouter(
      initialLocation: '/collector/record',
      routes: <RouteBase>[
        GoRoute(
          path: '/collector/record',
          builder: (_, _) => const RecordShortcutScreen(),
        ),
        GoRoute(
          path: '/collector/projects',
          builder: (BuildContext context, GoRouterState state) {
            navigatedTo = state.uri.toString();
            return const Scaffold(body: Text('projects'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return navigatedTo;
  }

  testWidgets('the debug button is gone', (WidgetTester tester) async {
    await pump(tester);

    expect(find.textContaining('DEBUG'), findsNothing);
    expect(find.textContaining('debug-test-task'), findsNothing);
  });

  testWidgets('it prompts Task selection — Chapter 2.4 §2’s second half', (
    WidgetTester tester,
  ) async {
    // "jumps into the most relevant in-progress Task's checklist, OR prompts
    // Task selection if none is obviously in progress". The first half needs
    // LocalSession.status, which no core/ contract exposes (open item 75), so
    // "none is obviously in progress" is true by construction today.
    await pump(tester);

    expect(find.text('Choose a Task to record'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Browse Projects'),
      findsOneWidget,
    );
  });

  testWidgets('Browse Projects goes to the Projects tab', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Browse Projects'));
    await tester.pumpAndSettle();

    expect(find.text('projects'), findsOneWidget);
  });

  testWidgets('nothing here routes into the checklist any more', (
    WidgetTester tester,
  ) async {
    // The router above declares no /checklist route at all. If this screen
    // still tried to reach one, the tap test above would have failed to find
    // its destination -- and this asserts the affordance itself is absent.
    await pump(tester);

    expect(find.textContaining('Checklist'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
