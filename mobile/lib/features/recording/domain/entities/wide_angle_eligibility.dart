import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:mobile/features/recording/domain/entities/wide_angle_tier.dart';

part 'wide_angle_eligibility.freezed.dart';

/// The outcome of Volume 5.1 §2's capability ladder for one device.
///
/// **A union rather than a bool, because the three outcomes are not two.**
/// A bare `bool canRecord` would collapse Tier 1 and Tier 2 into one value and
/// throw away the zoom factor the pipeline needs and the metadata block
/// records (FR-META-03, Volume 4 Chapter 4.5). It would also give a blocked
/// device no place to carry *why*, and Tier 3's whole point is that the
/// failure is named rather than silent.
///
/// ## The zoom factor rides on the verdict
///
/// Both eligible cases carry the factor that was actually achieved, so no
/// caller has to re-derive it or assume 0.5x. BR-02 permits exactly 0.5x or
/// 0.6x and Chapter 5.2 §2 fixes the choice per device for the life of the
/// install — carrying it here is what makes that fixity checkable.
///
/// ## Optical and hybrid are distinct, even though capture is identical
///
/// A Tier 2 device records at the same factor as a Tier 1 device, so the
/// footage is equally compliant. They are kept apart because the metadata
/// block records how the field of view was reached, and because a Tier 2
/// verdict on Android is currently *also* what a Tier 1 device reports — see
/// `WideAngleLadder` and amendment A-057.
@freezed
sealed class WideAngleEligibility with _$WideAngleEligibility {
  /// Tier 1 — a dedicated ultra-wide lens was found.
  const factory WideAngleEligibility.optical({
    required double zoomFactor,
  }) = WideAngleEligibilityOptical;

  /// Tier 2 — the primary sensor reaches the required factor by zooming out.
  const factory WideAngleEligibility.hybrid({
    required double zoomFactor,
  }) = WideAngleEligibilityHybrid;

  /// Tier 3 — neither path is available, and recording must be blocked.
  const factory WideAngleEligibility.ineligible({
    required WideAngleIneligibleReason reason,
  }) = WideAngleEligibilityIneligible;

  const WideAngleEligibility._();

  /// The ladder rung this outcome represents.
  WideAngleTier get tier => switch (this) {
    WideAngleEligibilityOptical() => WideAngleTier.opticalDedicated,
    WideAngleEligibilityHybrid() => WideAngleTier.primarySensorZoom,
    WideAngleEligibilityIneligible() => WideAngleTier.unsupported,
  };

  /// Whether recording may proceed.
  ///
  /// Convenience for the Checklist, which needs the boolean and the reason
  /// separately. It does not replace the union — the reason and the factor
  /// are both still only reachable by matching.
  bool get isEligible => this is! WideAngleEligibilityIneligible;

  /// The achieved zoom factor, or null when recording is blocked.
  double? get zoomFactorOrNull => switch (this) {
    WideAngleEligibilityOptical(:final double zoomFactor) => zoomFactor,
    WideAngleEligibilityHybrid(:final double zoomFactor) => zoomFactor,
    WideAngleEligibilityIneligible() => null,
  };
}

/// Why a device cannot reach the required field of view.
///
/// Separate from the [WideAngleTier] because Tier 3 has more than one cause
/// and the Checklist says different things about them: a phone with no rear
/// camera is a different message from a phone whose rear camera will not zoom
/// out far enough.
enum WideAngleIneligibleReason {
  /// No rear-facing camera exists, so BR-01 cannot be satisfied at all.
  noRearCamera,

  /// A rear camera exists but reaches neither Tier 1 nor Tier 2.
  ///
  /// The message Volume 5.1 §2 names for this case: *"This device doesn't
  /// support the required wide-angle capture"*.
  noWideAngleCapability,
}
