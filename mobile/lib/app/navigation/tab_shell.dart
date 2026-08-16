import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_sizes.dart';

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

  /// The label size Material's default bar height is sized around.
  ///
  /// `labelMedium`, which is what `NavigationBar` renders a destination label
  /// in. Named here because the growth below is measured against it rather
  /// than against an arbitrary constant.
  static const double _labelFontSize = 12;

  /// How many lines a scaled label is allowed to occupy before the bar stops
  /// growing. Two covers the longest label in either role — *Dashboard* — at
  /// 200%, which is the ceiling Chapter 2.10 §6 requires.
  static const double _maxLabelLines = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        // Chapter 2.10 §6: layouts "reflow vertically rather than truncating
        // or overlapping when text is scaled up to at least 200%".
        //
        // Material's NavigationBar is a FIXED 80dp and does not grow with the
        // OS text scale. That fixed height is the whole defect: at 150% and
        // again at 200%, "Dashboard" wraps to a second line, the bar does not
        // grow to hold it, and the second line is clipped by the bottom of the
        // screen. Measured on a CPH2707 — the destination's bounds were
        // byte-identical at scale 1.0, 1.5 and 2.0 while its label was not.
        //
        // So the height carries the scale instead of ignoring it. The floor is
        // Material's own value, which keeps 100% pixel-identical to every
        // committed golden; growth only ever adds.
        //
        // Labels are NOT shortened and NOT hidden. Chapter 2.4 §2 and §3 name
        // these tabs, so renaming them to fit is a specification change, and
        // `labelBehavior: onlyShowSelected` would hide information without
        // fixing anything — the selected label still wraps in the same fixed
        // space. Open item 107.
        height: _barHeight(context),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: destinations,
      ),
    );
  }

  /// Material's default bar height, plus room for however tall the OS has made
  /// the label.
  static double _barHeight(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double scaled = scaler.scale(_labelFontSize);

    // Zero at 100%, so the common case is untouched.
    final double growth = math.max(0, scaled - _labelFontSize);

    return AppSizes.bottomNavHeight + growth * _maxLabelLines;
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
