import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The persistent bottom tab bar both role roots are built from.
///
/// Volume 2 Chapter 2.4 §5 makes one pattern serve both roles — *"Bottom tab
/// bar — Collector & Admin root-level sections — persistent, always reachable
/// except during active Recording"* — so this widget is parameterised by its
/// destinations rather than duplicated per role.
///
/// ## Why it lives in `app/`, not `shared/`
///
/// It takes a `StatefulNavigationShell`, which makes it part of the routing
/// construct rather than a reusable component. ADR-004 puts routing in `app/`,
/// and ADR-022 §2.5 scopes `shared/` to presentation used by two or more
/// *features* — this is used by the router, and by no feature at all. Placing
/// it in `shared/` would also make `shared/` depend on `go_router`.
///
/// It imports nothing from `features/`, so ADR-022 §2.2's rule that
/// `app/router.dart` is the only feature-aware file in `app/` still holds.
class TabShell extends StatelessWidget {
  const TabShell({
    required this.navigationShell,
    required this.destinations,
    super.key,
  });

  /// The branch container GoRouter supplies, one child per tab.
  final StatefulNavigationShell navigationShell;

  /// Tab affordances, in the order Chapter 2.4 lists them.
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: destinations,
      ),
    );
  }

  /// Switches branch, or resets the current branch to its root.
  ///
  /// `initialLocation` is true only when the selected tab is already current,
  /// which makes a second tap on the active tab pop that tab's stack back to
  /// its root. Chapter 2.4 §5 requires stack state to be preserved on back
  /// navigation, so switching *between* tabs must not reset either one.
  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
