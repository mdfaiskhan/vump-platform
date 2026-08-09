/// Fixed component dimensions and layout breakpoints.
///
/// Values that describe how large a thing is, as opposed to how much space
/// sits around it — that belongs in the spacing scale.
abstract final class AppSizes {
  /// 16dp — icon inside dense components.
  static const double iconXs = 16;

  /// 20dp — icon inside a compact button.
  static const double iconSm = 20;

  /// 24dp — the default icon size.
  static const double iconMd = 24;

  /// 32dp — prominent icon.
  static const double iconLg = 32;

  /// 48dp — feature or empty-state icon.
  static const double iconXl = 48;

  /// 48dp — the minimum interactive area required for accessibility.
  static const double minTouchTarget = 48;

  /// 40dp — height of a compact button.
  static const double buttonHeightSm = 40;

  /// 48dp — height of a standard button.
  static const double buttonHeightMd = 48;

  /// 56dp — height of a primary call-to-action button.
  static const double buttonHeightLg = 56;

  /// 56dp — height of a text input field.
  static const double inputHeight = 56;

  /// 56dp — height of the top app bar.
  static const double appBarHeight = 56;

  /// 80dp — height of the bottom navigation bar.
  static const double bottomNavHeight = 80;

  /// 1dp — thickness of dividers and borders.
  static const double borderWidth = 1;

  /// 2dp — thickness of a focused or selected border.
  static const double borderWidthFocused = 2;

  /// 32dp — compact avatar diameter.
  static const double avatarSm = 32;

  /// 40dp — default avatar diameter.
  static const double avatarMd = 40;

  /// 64dp — profile-scale avatar diameter.
  static const double avatarLg = 64;

  /// 600dp — the width at which layout shifts from compact to medium.
  static const double breakpointTablet = 600;

  /// 1024dp — the width at which layout shifts from medium to expanded.
  static const double breakpointDesktop = 1024;

  /// 720dp — the widest a text column may grow on large screens.
  static const double maxContentWidth = 720;
}
