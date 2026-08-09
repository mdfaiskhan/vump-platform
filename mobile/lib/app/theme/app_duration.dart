import 'package:flutter/material.dart';

/// Motion timings and easing curves.
///
/// Every animation, transition and debounce reads its timing from here so
/// motion feels uniform and can be tuned in one place.
abstract final class AppDuration {
  /// 100ms — state changes that must feel instantaneous, e.g. ripples.
  static const Duration instant = Duration(milliseconds: 100);

  /// 150ms — small element fades and colour changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// 250ms — the default transition length.
  static const Duration normal = Duration(milliseconds: 250);

  /// 400ms — sheets, dialogs and other large surface movement.
  static const Duration slow = Duration(milliseconds: 400);

  /// 4s — how long a transient message stays on screen.
  static const Duration snackBar = Duration(seconds: 4);

  /// Easing for elements entering and leaving together.
  static const Curve standardCurve = Curves.easeInOut;

  /// Easing for elements entering the screen.
  static const Curve enterCurve = Curves.easeOut;

  /// Easing for elements leaving the screen.
  static const Curve exitCurve = Curves.easeIn;
}
