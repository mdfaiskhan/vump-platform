import 'package:flutter/material.dart';

/// Corner radius scale for surfaces, cards, fields and buttons.
///
/// Exposes both the scalar values and ready-made [BorderRadius] constants so
/// call sites never construct a radius literal.
abstract final class AppRadius {
  /// 0dp — square corners.
  static const double none = 0;

  /// 4dp — chips, badges and other small surfaces.
  static const double xs = 4;

  /// 8dp — input fields and compact buttons.
  static const double sm = 8;

  /// 12dp — the default surface radius.
  static const double md = 12;

  /// 16dp — cards and elevated containers.
  static const double lg = 16;

  /// 24dp — bottom sheets and dialogs.
  static const double xl = 24;

  /// 999dp — fully rounded, for pills and circular avatars.
  static const double pill = 999;

  static const BorderRadius borderXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderPill =
      BorderRadius.all(Radius.circular(pill));
}
