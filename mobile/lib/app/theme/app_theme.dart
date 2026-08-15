import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_colors.dart';
import 'package:mobile/app/theme/app_elevation.dart';
import 'package:mobile/app/theme/app_radius.dart';
import 'package:mobile/app/theme/app_semantic_colors.dart';
import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/app_status_colors.dart';
import 'package:mobile/app/theme/app_text_theme.dart';

/// Material 3 [ThemeData] for each supported brightness.
///
/// Both brightnesses are produced by a single [_build], so the two themes can
/// differ only in their [ColorScheme] and status colours. Everything
/// structural — shape, density, typography, elevation — is shared by
/// construction and cannot drift.
abstract final class AppTheme {
  /// Theme applied when the resolved brightness is light.
  static ThemeData get light =>
      _build(AppColors.light, AppSemanticColors.light, AppStatusColors.light);

  /// Theme applied when the resolved brightness is dark.
  static ThemeData get dark =>
      _build(AppColors.dark, AppSemanticColors.dark, AppStatusColors.dark);

  static ThemeData _build(
    ColorScheme colorScheme,
    AppSemanticColors semanticColors,
    AppStatusColors statusColors,
  ) {
    const TextTheme textTheme = AppTextTheme.textTheme;

    return ThemeData(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      extensions: <ThemeExtension<dynamic>>[semanticColors, statusColors],

      // Flat chrome. Depth comes from surface tone rather than shadow, which
      // is what keeps the interface reading as calm at rest.
      appBarTheme: AppBarThemeData(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.none,
        toolbarHeight: AppSizes.appBarHeight,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.none,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: AppSizes.borderWidth,
        space: AppSizes.borderWidth,
      ),

      iconTheme: IconThemeData(
        size: AppSizes.iconMd,
        color: colorScheme.onSurfaceVariant,
      ),

      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(textTheme)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(textTheme),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(textTheme),
      ),
      textButtonTheme: TextButtonThemeData(style: _buttonStyle(textTheme)),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: _inputBorder(colorScheme.outlineVariant),
        enabledBorder: _inputBorder(colorScheme.outlineVariant),
        focusedBorder: _inputBorder(
          colorScheme.primary,
          width: AppSizes.borderWidthFocused,
        ),
        errorBorder: _inputBorder(colorScheme.error),
        focusedErrorBorder: _inputBorder(
          colorScheme.error,
          width: AppSizes.borderWidthFocused,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
      ),
    );
  }

  /// Shared geometry for every button variant, so a filled and an outlined
  /// button are the same size and shape.
  static ButtonStyle _buttonStyle(TextTheme textTheme) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(0, AppSizes.buttonHeightMd),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelLarge),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(
    Color color, {
    double width = AppSizes.borderWidth,
  }) {
    return OutlineInputBorder(
      borderRadius: AppRadius.borderSm,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
