/// Opacity levels applied to colours drawn from the colour scheme.
///
/// Multipliers only. Applying one to a scheme colour keeps the palette in
/// `app_colors.dart` as the sole owner of every colour value.
abstract final class AppOpacity {
  /// Applied to a disabled control.
  static const double disabled = 0.38;

  /// Applied to secondary or supporting content.
  static const double muted = 0.6;

  /// Applied to the scrim behind a modal surface.
  static const double scrim = 0.32;
}
