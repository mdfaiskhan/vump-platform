import 'package:mobile/features/recording/domain/entities/camera_capability.dart';
import 'package:mobile/features/recording/domain/entities/camera_specification.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_eligibility.dart';

/// Volume 5.1 §2's device capability ladder, as a pure function.
///
/// The chapter's table has three rows tried in order at initialization, and
/// this is that table and nothing else:
///
/// **Tier 1** — query physical camera IDs for a lens with the required
/// focal-length metadata and select it directly. *True optical wide-angle,
/// matching BR-02 exactly.*
///
/// **Tier 2** — if no dedicated ultra-wide sensor exists, use the primary
/// rear sensor's own zoom-out capability down to 0.5x/0.6x, if the device
/// reports support for it. *Optical or hybrid wide-angle at the correct
/// factor.*
///
/// **Tier 3** — if neither is available, block recording entirely with a
/// Checklist-style named failure. *Consistent, honest failure — never a
/// silent BR-02 violation.*
///
/// ## Pure, and deliberately so
///
/// It touches no plugin, no channel and no `await`. The whole ladder is
/// therefore a table test with no device, no permission and no widget tree —
/// which matters more here than usual, because the alternative is verifying a
/// three-way branch by hand on physical hardware.
///
/// ## BR-01 is the first gate, ahead of the ladder
///
/// The chapter's ladder is about *which* rear lens; BR-01 is about there
/// being one. A device with no rear camera fails before Tier 1 is asked, and
/// reports [WideAngleIneligibleReason.noRearCamera] rather than the
/// wide-angle message, because telling someone their phone lacks wide-angle
/// when it lacks a rear camera entirely is a misleading true statement.
///
/// ## What this ladder does NOT do
///
/// It does not open, configure or lock the camera, and it does not check
/// permissions. Chapter 5.1 §3 puts camera and microphone permission (BR-03)
/// with the Pre-Recording Checklist and says it is *"not re-checked
/// redundantly here"*. This function is given a reading and returns a verdict.
abstract final class WideAngleLadder {
  /// Resolves [capability] to a verdict.
  static WideAngleEligibility resolve(CameraCapability capability) {
    // BR-01, ahead of the ladder proper.
    if (!capability.hasRearCamera) {
      return const WideAngleEligibility.ineligible(
        reason: WideAngleIneligibleReason.noRearCamera,
      );
    }

    // Tier 1 — a dedicated ultra-wide lens, selected directly.
    if (capability.hasDedicatedUltraWide ?? false) {
      return const WideAngleEligibility.optical(
        zoomFactor: CameraSpecification.zoomFactorOptical,
      );
    }

    // Tier 2 — the primary sensor's own zoom-out capability.
    //
    // Reached in two different situations that must not be conflated:
    //
    //   (a) Tier 1 answered `false` — the device genuinely has no ultra-wide
    //       lens, and this is the fallback the chapter describes.
    //   (b) Tier 1 answered `null` — the platform could not say. On Android
    //       this is *every* device (see CameraCapability), so a real
    //       ultra-wide phone arrives here too and is reported as hybrid.
    //
    // Case (b) mislabels the tier. It does not misrecord the footage: the
    // achieved zoom factor is measured, not assumed, so BR-02 holds either
    // way and only the metadata's account of *how* is imprecise. Amendment
    // A-057 records this as an accepted, temporary loss of fidelity that the
    // Android platform channel closes.
    final double? minimum = capability.minimumZoomFactor;
    if (minimum != null &&
        minimum <= CameraSpecification.maximumAcceptableZoomFactor) {
      return WideAngleEligibility.hybrid(
        zoomFactor: _snapToPermittedFactor(minimum),
      );
    }

    // Tier 3 — blocked.
    //
    // Reached only on a *positive* Tier 2 failure: the device reported a
    // minimum zoom factor and it was not wide enough. An indeterminate Tier 1
    // never lands here on its own, because "we could not look" is not
    // evidence of absence and a wrong hard block stops a Collector working.
    return const WideAngleEligibility.ineligible(
      reason: WideAngleIneligibleReason.noWideAngleCapability,
    );
  }

  /// Rounds a reported minimum to the nearer of BR-02's two permitted values.
  ///
  /// BR-02 allows *"exactly 0.5x or 0.6x"* and nothing else, but a device
  /// reports whatever its hardware does — 0.55, or 0.5000001. Recording at
  /// the reported value would violate BR-02 on its face; snapping to the
  /// nearer permitted value keeps the footage inside the rule.
  ///
  /// A device that reports wider than 0.5 is clamped to 0.5 rather than
  /// allowed its extra reach: comparability across the fleet is BR-02's
  /// stated purpose, and a single unusually wide device defeats it.
  ///
  /// **The exact midpoint resolves to 0.5, and does so deterministically.**
  /// A device reporting 0.55 is equidistant, and comparing the two raw
  /// distances lets binary floating point decide: `0.55 - 0.5` evaluates to
  /// 0.05000000000000004 while `0.6 - 0.55` evaluates to 0.049999999999999996,
  /// so the naive comparison picks 0.6 for a value it should treat as a tie.
  /// [_tieTolerance] absorbs that representation error so the rule is the one
  /// written here rather than an artefact of the arithmetic — which matters
  /// because two devices reporting the same figure must be given the same
  /// factor, permanently, for footage to stay comparable.
  static double _snapToPermittedFactor(double reportedMinimum) {
    if (reportedMinimum <= CameraSpecification.zoomFactorOptical) {
      return CameraSpecification.zoomFactorOptical;
    }
    final double toOptical =
        (reportedMinimum - CameraSpecification.zoomFactorOptical).abs();
    final double toFallback =
        (reportedMinimum - CameraSpecification.zoomFactorFallback).abs();

    // Strictly nearer the fallback, by more than representation error.
    return (toOptical - toFallback) > _tieTolerance
        ? CameraSpecification.zoomFactorFallback
        : CameraSpecification.zoomFactorOptical;
  }

  /// Slack absorbing binary floating-point representation error.
  ///
  /// Nine orders of magnitude below the 0.1 gap between the two permitted
  /// factors, so it can only ever decide a tie — never move a value that is
  /// genuinely nearer one of them.
  static const double _tieTolerance = 1e-9;
}
