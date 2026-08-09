import 'package:flutter/material.dart';

/// Typography shared by the light and dark themes.
///
/// Declares metrics only — size, weight, line height and letter spacing.
/// Colour is applied by [ThemeData] from the active [ColorScheme], so no
/// [Color] appears here.
///
/// The scale departs from the Material 3 baseline in two deliberate ways.
/// Display and headline roles carry negative letter spacing that tightens as
/// size grows, which reads as composed rather than airy at large sizes. Titles
/// and labels sit at weight 600 instead of 400/500, giving interface chrome a
/// firmer voice while body text stays at 400 for long-form legibility.
abstract final class AppTextTheme {
  static const TextTheme textTheme = TextTheme(
    // Display — reserved for marketing surfaces and empty states.
    displayLarge: TextStyle(
      fontSize: 57,
      height: 1.12,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.5,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      height: 1.16,
      fontWeight: FontWeight.w600,
      letterSpacing: -1,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      height: 1.22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),

    // Headline — page and section headings.
    headlineLarge: TextStyle(
      fontSize: 32,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.29,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.33,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),

    // Title — app bars, cards and list headers.
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.27,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),

    // Body — running text.
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.33,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
    ),

    // Label — buttons, chips and metadata.
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.33,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.45,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
  );
}
