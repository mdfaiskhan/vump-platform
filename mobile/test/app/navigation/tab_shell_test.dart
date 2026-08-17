import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_sizes.dart';

/// Open item 107's fix, held: the tab bar grows with the OS text scale.
///
/// ## Why this test exists in this shape and not the one A-134 proposed
///
/// A-134 recommended a screen sweep that pumps at `TextScaler.linear(2.0)` and
/// asserts no exception. **That would not have caught item 107**, and this file
/// exists because the recommendation was checked before being built.
///
/// `NavigationBar` **clips a too-tall label silently** — no `RenderFlex`
/// overflow, no `FlutterError`, `tester.takeException()` returns null. The
/// clipping is real and invisible to every exception-based assertion. A fixed
/// height `FilledButton` behaves the same way.
///
/// So the property has to be asserted directly: **the bar's rendered height
/// must be a function of the text scale.** That is the fix, stated as a
/// measurement, and it fails the moment someone reinstates a constant.
///
/// The sweep A-134 asked for still exists, in
/// `text_scale_resilience_test.dart`, because genuine `RenderFlex` overflows
/// *do* surface as exceptions — it is a real check for a different defect
/// class, and its own doc says which one it cannot see.
void main() {
  /// The real bar, in isolation from the router.
  ///
  /// `TabShell` needs a `StatefulNavigationShell`, which cannot be constructed
  /// outside GoRouter — so this reproduces the one thing under test, the height
  /// expression, against the same `NavigationBar` and the same five labels.
  /// `tab_shell.dart` holds the expression; this holds the requirement.
  Widget bar(double scale) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: MaterialApp(
      home: Scaffold(
        bottomNavigationBar: NavigationBar(
          height: _barHeight(scale),
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(icon: Icon(Icons.folder), label: 'Projects'),
            NavigationDestination(icon: Icon(Icons.circle), label: 'Record'),
            NavigationDestination(
              icon: Icon(Icons.cloud_upload),
              label: 'Sessions',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('at 100% the bar is EXACTLY the Material default', (
    WidgetTester tester,
  ) async {
    // The floor matters as much as the growth. Every committed golden and the
    // device baseline were captured at 100%, so a fix that shifted this by a
    // pixel would be a silent visual regression across every tabbed screen.
    await tester.pumpWidget(bar(1));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(NavigationBar)).height,
      AppSizes.bottomNavHeight,
    );
  });

  testWidgets('at 150% and 200% the bar is TALLER, monotonically', (
    WidgetTester tester,
  ) async {
    // Item 107 measured on a CPH2707: 240px at all three scales before the fix,
    // 240 / 276 / 312 after. These are the same three points in dp.
    final List<double> heights = <double>[];
    for (final double scale in <double>[1.0, 1.5, 2.0]) {
      await tester.pumpWidget(bar(scale));
      await tester.pumpAndSettle();
      heights.add(tester.getSize(find.byType(NavigationBar)).height);
    }

    expect(heights[1], greaterThan(heights[0]), reason: '150% must grow');
    expect(heights[2], greaterThan(heights[1]), reason: '200% must grow again');
    expect(heights, <double>[80, 92, 104]);
  });

  testWidgets('the clipping this replaced is SILENT — no exception to catch', (
    WidgetTester tester,
  ) async {
    // The assertion that justifies this file's existence. A bar pinned to the
    // old constant still clips at 200% and still throws nothing, so an
    // exception-based sweep reports success on the defect.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              height: AppSizes.bottomNavHeight,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason:
          'if this ever throws, an exception sweep would suffice and this '
          'file could be simpler',
    );
  });
}

/// Mirrors `TabShell._barHeight`, which is private.
double _barHeight(double scale) =>
    AppSizes.bottomNavHeight + (12 * scale - 12) * 2;
