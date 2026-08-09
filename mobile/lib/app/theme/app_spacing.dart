/// The spacing scale used for all padding, margins and gaps.
///
/// A 4dp base grid. No layout may declare a spacing literal; every value
/// comes from this scale so rhythm stays consistent across screens.
abstract final class AppSpacing {
  /// 2dp — hairline separation inside a single component.
  static const double xxs = 2;

  /// 4dp — gap between tightly related elements, e.g. an icon and its label.
  static const double xs = 4;

  /// 8dp — gap between elements within a group.
  static const double sm = 8;

  /// 12dp — internal padding of compact components.
  static const double md = 12;

  /// 16dp — default screen and card padding.
  static const double lg = 16;

  /// 24dp — gap between distinct groups of content.
  static const double xl = 24;

  /// 32dp — gap between major sections.
  static const double xxl = 32;

  /// 48dp — leading or trailing whitespace around a page's content.
  static const double xxxl = 48;
}
