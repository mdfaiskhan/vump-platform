import 'package:flutter/material.dart';

/// Volume 2 Chapter 2.10 §2.2's four validated status colours.
///
/// > *"The four status colors (good #0CA30C, warning #FAB219, info/accent
/// > #2A78D6, critical #D03B3B) were checked against color-vision-deficiency
/// > separation and contrast requirements before being adopted into the Design
/// > System."*
///
/// These are **transcribed, not chosen**, and they are deliberately separate
/// from `AppSemanticColors` and from the Material 3 scheme.
///
/// ## Why these are not the existing `success` / `warning` / `error` tokens
///
/// Every one of the four differs from the token that looks like its
/// counterpart — `successLight` is `#1B7F4B` against good's `#0CA30C`,
/// `warningLight` is `#8A5A00` against warning's `#FAB219`, `primaryLight` is
/// `#2D5BE3` against accent's `#2A78D6`, `errorLight` is `#BA1A1A` against
/// critical's `#D03B3B`.
///
/// The existing values come from ADR-005's Material 3 tonal palette, chosen
/// before anyone read Chapter 2.10 §2.2. They were **not** overwritten,
/// because these four are a *status palette* for Chapter 2.8 §6's pills rather
/// than the application's colour scheme: repainting `primary` and `error`
/// app-wide would change every existing screen and re-open ADR-005 to satisfy
/// a pill. Amendment A-089 records the split.
///
/// ## What Chapter 2.10 §2.2 does not say, and this file decides
///
/// It gives four hex values and nothing else — **no light/dark variants, and
/// no statement of whether the hue is the pill's fill, its text, or its
/// border.** That rule lives in Chapter 2.8's `design_system.html`, which is
/// not in this repository (A-090).
///
/// So the following is **filling a gap, not reading a spec**, and is marked as
/// such rather than dressed up as a citation:
///
/// - The hue is used as the pill's **fill** in light mode, with a foreground
///   chosen for AA contrast against it — Chapter 2.10 §2.3 requires at least
///   4.5:1 for body text in both themes.
/// - In dark mode the same hue is used at reduced luminance as a **container**
///   with a light foreground, because the four hexes were validated against a
///   light surface and §2.3 asks for a *"validated second pass against the
///   dark surface colour, never an automatic filter applied to the light"*.
///   A genuine second validation needs the design system; this is the honest
///   approximation until it exists.
///
/// The hues themselves are never altered — a Collector comparing two devices
/// sees the same four colours, which is the property §2.2's CVD check bought.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  /// Creates a status palette.
  const AppStatusColors({
    required this.good,
    required this.onGood,
    required this.warning,
    required this.onWarning,
    required this.accent,
    required this.onAccent,
    required this.critical,
    required this.onCritical,
  });

  /// `#0CA30C` — Chapter 5.9 §1's `complete`.
  static const Color goodHue = Color(0xFF0CA30C);

  /// `#FAB219` — Chapter 5.9 §1's `queued`.
  static const Color warningHue = Color(0xFFFAB219);

  /// `#2A78D6` — Chapter 5.9 §1's `uploading`.
  static const Color accentHue = Color(0xFF2A78D6);

  /// `#D03B3B` — Chapter 5.9 §1's `failed`.
  static const Color criticalHue = Color(0xFFD03B3B);

  /// Fill for a complete pill.
  final Color good;

  /// Foreground on [good].
  final Color onGood;

  /// Fill for a queued pill.
  final Color warning;

  /// Foreground on [warning].
  final Color onWarning;

  /// Fill for an uploading pill, and the progress fill.
  final Color accent;

  /// Foreground on [accent].
  final Color onAccent;

  /// Fill for a failed pill, and the failed row's border.
  final Color critical;

  /// Foreground on [critical].
  final Color onCritical;

  /// Light theme — the four hues at full strength.
  ///
  /// **Only one of the four carries white text at AA.** Measured, not judged:
  ///
  /// | Hue | vs white | Foreground used |
  /// |---|---|---|
  /// | `#0CA30C` good | 3.35:1 ✗ | near-black green |
  /// | `#FAB219` warning | 1.79:1 ✗ | near-black amber |
  /// | `#2A78D6` accent | 4.42:1 ✗ | **pure black**, 4.76:1 |
  /// | `#D03B3B` critical | 4.62:1 ✓ | white |
  ///
  /// The accent is the awkward one: at 4.42:1 white just misses, and every
  /// tinted near-black tried lands *below* 4.5 as well — `#000B18` gives 4.48.
  /// Pure black is the only foreground that clears it, so that is what it
  /// takes, even though the other three use hue-family tints.
  ///
  /// **This is evidence for A-090, not a defect in the hues.** Chapter 2.10
  /// §2.2 says the four were *"checked against … contrast requirements"*, and
  /// three of them cannot carry white body text as a fill — so the check they
  /// passed was plainly for some other application, most likely as text or as
  /// an accent **on** a light surface rather than as the surface itself. The
  /// rule that would have said which lives in the missing
  /// `design_system.html`. The hues are used exactly as published regardless;
  /// only the foregrounds are derived here.
  static const AppStatusColors light = AppStatusColors(
    good: goodHue,
    onGood: Color(0xFF042104),
    warning: warningHue,
    onWarning: Color(0xFF231A00),
    accent: accentHue,
    onAccent: Color(0xFF000000),
    critical: criticalHue,
    onCritical: Color(0xFFFFFFFF),
  );

  /// Dark theme — the same hues as containers, with light foregrounds.
  ///
  /// The hue is preserved and the surrounding luminance moves, rather than the
  /// hue being filtered. §2.3 forbids *"an automatic filter applied to the
  /// light-theme"* palette, and shifting a validated hue would discard §2.2's
  /// CVD separation.
  static const AppStatusColors dark = AppStatusColors(
    good: Color(0xFF0A7A0A),
    onGood: Color(0xFFEAFBEA),
    warning: Color(0xFFC98C0A),
    onWarning: Color(0xFF231A00),
    accent: Color(0xFF215FAB),
    onAccent: Color(0xFFE8F1FC),
    critical: Color(0xFFA62F2F),
    onCritical: Color(0xFFFDECEC),
  );

  @override
  AppStatusColors copyWith({
    Color? good,
    Color? onGood,
    Color? warning,
    Color? onWarning,
    Color? accent,
    Color? onAccent,
    Color? critical,
    Color? onCritical,
  }) => AppStatusColors(
    good: good ?? this.good,
    onGood: onGood ?? this.onGood,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    critical: critical ?? this.critical,
    onCritical: onCritical ?? this.onCritical,
  );

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) {
      return this;
    }
    return AppStatusColors(
      good: Color.lerp(good, other.good, t)!,
      onGood: Color.lerp(onGood, other.onGood, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      onCritical: Color.lerp(onCritical, other.onCritical, t)!,
    );
  }
}
