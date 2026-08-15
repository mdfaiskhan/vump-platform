import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/features/recording/domain/entities/checklist_check.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_eligibility.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';

part 'checklist_outcome.freezed.dart';

/// What the Pre-Recording Checklist measured, and what it therefore permits.
///
/// One object for all five rows rather than a list of row objects, because
/// each row measures a different kind of thing and a shared row type would
/// have to erase that into a string. Every field is nullable, and null means
/// **not measured yet** — the screen renders a pending row for it rather than
/// a failure.
///
/// ## The verdict is derived, never stored
///
/// [passes] and [allPassed] are computed from the readings. Storing a verdict
/// beside the values it comes from would let the two disagree, and Volume 2
/// Chapter 2.7's C-07 requires the button to *"re-evaluate live if a value
/// changes (e.g. battery drains) while the screen is open"* — which is only
/// safe if the verdict is a function of the current readings.
///
/// ## Copy is not here
///
/// Chapter 2.7's C-08 wants a plain-language remedy per failing row, and
/// Chapter 2.9 §3 fixes its voice. That is `presentation/`'s job, the way
/// `AuthErrorCopy` maps an `ErrorCode` to what a person reads. What this owes
/// the screen is a value it can render and a verdict it can trust.
@freezed
class ChecklistOutcome with _$ChecklistOutcome {
  /// Creates an outcome. Every field defaults to unmeasured.
  const factory ChecklistOutcome({
    /// FR-CHK-01. Null until probed; an [ErrorCode] names *which* grant is
    /// missing, which is what C-08's per-row remedy needs.
    bool? permissionsGranted,

    /// Why [permissionsGranted] is false, when it is.
    ErrorCode? permissionFailure,

    /// FR-CHK-02 — bytes free on the volume recordings are written to.
    int? availableBytes,

    /// FR-CHK-03 — charge percentage, 0–100.
    int? batteryPercent,

    /// FR-CHK-04 — the connection kind. Never blocks (Ch. 2.9 §5).
    NetworkType? network,

    /// A-057's verdict, from cache when the fingerprint still matches.
    WideAngleEligibility? wideAngle,
  }) = _ChecklistOutcome;

  const ChecklistOutcome._();

  /// Nothing measured yet — what the screen shows on first frame.
  static const ChecklistOutcome pending = ChecklistOutcome();

  /// The battery percentage FR-CHK-03's *"configured minimum threshold"*
  /// resolves to.
  ///
  /// **20, taken from the volumes rather than chosen here.** FR-CHK-03 names a
  /// threshold without a number, and 20 % is the value every worked example
  /// uses: Volume 1's UC-05 remedy — *"Charge your device to at least 20%
  /// before recording"* — and Volume 2 Chapter 2.7's C-08 and Chapter 2.9 §3
  /// both repeat it. Three independent statements of the same number are a
  /// specification in everything but placement.
  static const int minimumBatteryPercent = 20;

  /// The free space FR-CHK-02's *"at least one full chunk"* resolves to.
  ///
  /// Delegated to [RecordingLifecycle.oneChunkBytes] rather than restated, so
  /// the Checklist's floor and the mid-recording backpressure floor cannot
  /// drift apart — the pipeline must never allow less headroom than the
  /// Checklist demanded before it started.
  static int get minimumFreeBytes => RecordingLifecycle.oneChunkBytes;

  /// Whether one row currently passes.
  ///
  /// A row that has not been measured returns false: the button stays disabled
  /// until every row has actually answered, which is stricter than treating an
  /// unmeasured row as benign.
  bool passes(ChecklistCheck check) => switch (check) {
    ChecklistCheck.cameraAndMicrophone => permissionsGranted ?? false,
    ChecklistCheck.freeStorage =>
      availableBytes != null && availableBytes! >= minimumFreeBytes,
    ChecklistCheck.batteryLevel =>
      batteryPercent != null && batteryPercent! >= minimumBatteryPercent,
    // Reported, not gating — Chapter 2.9 §5. A measured `none` still passes,
    // because recording in the field must not depend on connectivity.
    ChecklistCheck.network => network != null,
    ChecklistCheck.wideAngleCapability => wideAngle?.isEligible ?? false,
  };

  /// Whether a row has produced a reading at all.
  bool isMeasured(ChecklistCheck check) => switch (check) {
    ChecklistCheck.cameraAndMicrophone => permissionsGranted != null,
    ChecklistCheck.freeStorage => availableBytes != null,
    ChecklistCheck.batteryLevel => batteryPercent != null,
    ChecklistCheck.network => network != null,
    ChecklistCheck.wideAngleCapability => wideAngle != null,
  };

  /// BR-04's gate. Every row measured and passing.
  bool get allPassed => ChecklistCheck.values.every(passes);

  /// The rows that have answered and answered badly — C-08's failing rows.
  ///
  /// Excludes rows still pending, so a checklist mid-run does not render as a
  /// wall of failures before it has looked.
  List<ChecklistCheck> get failures => ChecklistCheck.values
      .where((ChecklistCheck c) => isMeasured(c) && !passes(c))
      .toList();

  /// The zoom factor to hand the lifecycle, or null if not eligible.
  ///
  /// Volume 5 Chapter 5.1 §3 makes resolving the verdict to a factor the
  /// Checklist's job, and Chapter 5.2 §1 fixes it for the whole session.
  double? get resolvedZoomFactor => wideAngle?.zoomFactorOrNull;
}
