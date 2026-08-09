import 'package:flutter/material.dart';

/// The single source of truth for colour literals in the application.
///
/// No other file may declare a [Color]. Widgets read colours from the active
/// [ColorScheme] via `Theme.of(context)`, or from `AppSemanticColors` for the
/// status colours Material 3 does not model.
///
/// The palette is explicit rather than seed-generated: a finalised design
/// language needs colours that are chosen, not derived, so that light and dark
/// stay in deliberate correspondence rather than drifting with the tonal
/// algorithm. Surfaces are near-neutral with a faint cool cast, which keeps the
/// brand blue as the only saturated element on screen.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Brand — light
  // ---------------------------------------------------------------------------

  /// Primary brand blue. Used for primary actions and active states.
  static const Color primaryLight = Color(0xFF2D5BE3);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFFDCE4FF);
  static const Color onPrimaryContainerLight = Color(0xFF00174B);

  /// Secondary teal. Used for supporting emphasis and data accents.
  static const Color secondaryLight = Color(0xFF0F8F8D);
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color secondaryContainerLight = Color(0xFFB8F2EF);
  static const Color onSecondaryContainerLight = Color(0xFF00201F);

  /// Tertiary violet. Reserved for AI-specific affordances and highlights.
  static const Color tertiaryLight = Color(0xFF6D4AE0);
  static const Color onTertiaryLight = Color(0xFFFFFFFF);
  static const Color tertiaryContainerLight = Color(0xFFE7DEFF);
  static const Color onTertiaryContainerLight = Color(0xFF21005E);

  // ---------------------------------------------------------------------------
  // Brand — dark
  // ---------------------------------------------------------------------------

  static const Color primaryDark = Color(0xFFB4C5FF);
  static const Color onPrimaryDark = Color(0xFF002A78);
  static const Color primaryContainerDark = Color(0xFF0842A9);
  static const Color onPrimaryContainerDark = Color(0xFFDCE4FF);

  static const Color secondaryDark = Color(0xFF4CD9D5);
  static const Color onSecondaryDark = Color(0xFF003736);
  static const Color secondaryContainerDark = Color(0xFF00504E);
  static const Color onSecondaryContainerDark = Color(0xFFB8F2EF);

  static const Color tertiaryDark = Color(0xFFC9BDFF);
  static const Color onTertiaryDark = Color(0xFF3A1D8F);
  static const Color tertiaryContainerDark = Color(0xFF5435C4);
  static const Color onTertiaryContainerDark = Color(0xFFE7DEFF);

  // ---------------------------------------------------------------------------
  // Status — error
  // ---------------------------------------------------------------------------

  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color errorContainerLight = Color(0xFFFFDAD6);
  static const Color onErrorContainerLight = Color(0xFF410002);

  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color onErrorDark = Color(0xFF690005);
  static const Color errorContainerDark = Color(0xFF93000A);
  static const Color onErrorContainerDark = Color(0xFFFFDAD6);

  // ---------------------------------------------------------------------------
  // Status — success
  // ---------------------------------------------------------------------------

  static const Color successLight = Color(0xFF1B7F4B);
  static const Color onSuccessLight = Color(0xFFFFFFFF);
  static const Color successContainerLight = Color(0xFFC7F1D8);
  static const Color onSuccessContainerLight = Color(0xFF00210F);

  static const Color successDark = Color(0xFF7ADFA4);
  static const Color onSuccessDark = Color(0xFF00391D);
  static const Color successContainerDark = Color(0xFF00522C);
  static const Color onSuccessContainerDark = Color(0xFFC7F1D8);

  // ---------------------------------------------------------------------------
  // Status — warning
  // ---------------------------------------------------------------------------

  static const Color warningLight = Color(0xFF8A5A00);
  static const Color onWarningLight = Color(0xFFFFFFFF);
  static const Color warningContainerLight = Color(0xFFFFE7B8);
  static const Color onWarningContainerLight = Color(0xFF2B1D00);

  static const Color warningDark = Color(0xFFF5C264);
  static const Color onWarningDark = Color(0xFF472A00);
  static const Color warningContainerDark = Color(0xFF674000);
  static const Color onWarningContainerDark = Color(0xFFFFE7B8);

  // ---------------------------------------------------------------------------
  // Neutrals — light
  // ---------------------------------------------------------------------------

  static const Color surfaceLight = Color(0xFFFBFBFD);
  static const Color onSurfaceLight = Color(0xFF191C20);
  static const Color surfaceContainerLowestLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowLight = Color(0xFFF5F6F9);
  static const Color surfaceContainerLight = Color(0xFFEFF1F5);
  static const Color surfaceContainerHighLight = Color(0xFFE9EBF0);
  static const Color surfaceContainerHighestLight = Color(0xFFE3E6EC);
  static const Color onSurfaceVariantLight = Color(0xFF44474E);
  static const Color outlineLight = Color(0xFF74777F);
  static const Color outlineVariantLight = Color(0xFFC4C6CF);
  static const Color inverseSurfaceLight = Color(0xFF2E3135);
  static const Color onInverseSurfaceLight = Color(0xFFF0F1F7);
  static const Color inversePrimaryLight = Color(0xFFB4C5FF);

  // ---------------------------------------------------------------------------
  // Neutrals — dark
  // ---------------------------------------------------------------------------

  static const Color surfaceDark = Color(0xFF101317);
  static const Color onSurfaceDark = Color(0xFFE1E2E9);
  static const Color surfaceContainerLowestDark = Color(0xFF0B0E12);
  static const Color surfaceContainerLowDark = Color(0xFF191C20);
  static const Color surfaceContainerDark = Color(0xFF1D2024);
  static const Color surfaceContainerHighDark = Color(0xFF272A2F);
  static const Color surfaceContainerHighestDark = Color(0xFF32353A);
  static const Color onSurfaceVariantDark = Color(0xFFC4C6CF);
  static const Color outlineDark = Color(0xFF8E9099);
  static const Color outlineVariantDark = Color(0xFF44474E);
  static const Color inverseSurfaceDark = Color(0xFFE1E2E9);
  static const Color onInverseSurfaceDark = Color(0xFF2E3135);
  static const Color inversePrimaryDark = Color(0xFF2D5BE3);

  // ---------------------------------------------------------------------------
  // Shared
  // ---------------------------------------------------------------------------

  static const Color shadow = Color(0xFF000000);
  static const Color scrim = Color(0xFF000000);

  // ---------------------------------------------------------------------------
  // Schemes
  // ---------------------------------------------------------------------------

  /// Colour scheme applied when the resolved brightness is light.
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: primaryLight,
    onPrimary: onPrimaryLight,
    primaryContainer: primaryContainerLight,
    onPrimaryContainer: onPrimaryContainerLight,
    secondary: secondaryLight,
    onSecondary: onSecondaryLight,
    secondaryContainer: secondaryContainerLight,
    onSecondaryContainer: onSecondaryContainerLight,
    tertiary: tertiaryLight,
    onTertiary: onTertiaryLight,
    tertiaryContainer: tertiaryContainerLight,
    onTertiaryContainer: onTertiaryContainerLight,
    error: errorLight,
    onError: onErrorLight,
    errorContainer: errorContainerLight,
    onErrorContainer: onErrorContainerLight,
    surface: surfaceLight,
    onSurface: onSurfaceLight,
    surfaceContainerLowest: surfaceContainerLowestLight,
    surfaceContainerLow: surfaceContainerLowLight,
    surfaceContainer: surfaceContainerLight,
    surfaceContainerHigh: surfaceContainerHighLight,
    surfaceContainerHighest: surfaceContainerHighestLight,
    onSurfaceVariant: onSurfaceVariantLight,
    outline: outlineLight,
    outlineVariant: outlineVariantLight,
    inverseSurface: inverseSurfaceLight,
    onInverseSurface: onInverseSurfaceLight,
    inversePrimary: inversePrimaryLight,
    shadow: shadow,
    scrim: scrim,
  );

  /// Colour scheme applied when the resolved brightness is dark.
  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryDark,
    onPrimary: onPrimaryDark,
    primaryContainer: primaryContainerDark,
    onPrimaryContainer: onPrimaryContainerDark,
    secondary: secondaryDark,
    onSecondary: onSecondaryDark,
    secondaryContainer: secondaryContainerDark,
    onSecondaryContainer: onSecondaryContainerDark,
    tertiary: tertiaryDark,
    onTertiary: onTertiaryDark,
    tertiaryContainer: tertiaryContainerDark,
    onTertiaryContainer: onTertiaryContainerDark,
    error: errorDark,
    onError: onErrorDark,
    errorContainer: errorContainerDark,
    onErrorContainer: onErrorContainerDark,
    surface: surfaceDark,
    onSurface: onSurfaceDark,
    surfaceContainerLowest: surfaceContainerLowestDark,
    surfaceContainerLow: surfaceContainerLowDark,
    surfaceContainer: surfaceContainerDark,
    surfaceContainerHigh: surfaceContainerHighDark,
    surfaceContainerHighest: surfaceContainerHighestDark,
    onSurfaceVariant: onSurfaceVariantDark,
    outline: outlineDark,
    outlineVariant: outlineVariantDark,
    inverseSurface: inverseSurfaceDark,
    onInverseSurface: onInverseSurfaceDark,
    inversePrimary: inversePrimaryDark,
    shadow: shadow,
    scrim: scrim,
  );
}
