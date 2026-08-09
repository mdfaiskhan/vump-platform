import 'package:flutter/widgets.dart';

import 'package:mobile/app/theme/app_duration.dart';
import 'package:mobile/app/theme/app_radius.dart';
import 'package:mobile/app/theme/app_spacing.dart';

/// Application-wide defaults for motion, shape and layout.
///
/// These values are **not** redeclared here. The literals live in the design
/// token files under `app/theme/`, and this class binds names to them. A
/// duration or radius therefore has exactly one definition in the codebase:
/// change the token and every consumer follows.
///
/// What this file does add is the composite [EdgeInsets] defaults, which have
/// no equivalent in the token layer — a token is a scalar, a padding is a
/// geometry built from one.
abstract final class AppConstants {
  // ---------------------------------------------------------------------------
  // Animation durations
  // ---------------------------------------------------------------------------

  /// Default length of a transition when no other duration is specified.
  static const Duration animationDuration = AppDuration.normal;

  /// For state changes that must feel immediate.
  static const Duration animationFast = AppDuration.fast;

  /// For large surfaces entering or leaving.
  static const Duration animationSlow = AppDuration.slow;

  // ---------------------------------------------------------------------------
  // Border radius
  // ---------------------------------------------------------------------------

  /// Default corner radius for surfaces.
  static const double borderRadius = AppRadius.md;

  /// Corner radius for compact controls such as fields and buttons.
  static const double borderRadiusSmall = AppRadius.sm;

  /// Corner radius for cards and elevated containers.
  static const double borderRadiusLarge = AppRadius.lg;

  // ---------------------------------------------------------------------------
  // Padding
  // ---------------------------------------------------------------------------

  /// Default inset applied to the content of a screen.
  static const EdgeInsets defaultPadding = EdgeInsets.all(AppSpacing.lg);

  /// Inset for dense surfaces where the default would crowd the layout.
  static const EdgeInsets compactPadding = EdgeInsets.all(AppSpacing.sm);

  /// Horizontal-only inset, for content that manages its own vertical rhythm.
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
  );

  /// Vertical-only inset, the counterpart to [horizontalPadding].
  static const EdgeInsets verticalPadding = EdgeInsets.symmetric(
    vertical: AppSpacing.lg,
  );

  // ---------------------------------------------------------------------------
  // Spacing
  // ---------------------------------------------------------------------------

  /// Default gap between elements within a group.
  static const double defaultSpacing = AppSpacing.lg;

  /// Gap between tightly related elements.
  static const double smallSpacing = AppSpacing.sm;

  /// Gap between distinct groups of content.
  static const double largeSpacing = AppSpacing.xl;

  /// Gap between major sections of a screen.
  static const double sectionSpacing = AppSpacing.xxl;
}
