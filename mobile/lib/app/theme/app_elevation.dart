/// Material 3 elevation levels.
///
/// The height a surface sits above the one behind it. Paired with the surface
/// tones in the colour scheme — most surfaces in this design language express
/// depth through tone and use [none].
abstract final class AppElevation {
  /// 0dp — flat against its parent surface.
  static const double none = 0;

  /// 1dp — a resting card.
  static const double low = 1;

  /// 3dp — a raised or hovered surface.
  static const double medium = 3;

  /// 6dp — a floating action button or menu.
  static const double high = 6;

  /// 12dp — a modal surface above all page content.
  static const double modal = 12;
}
