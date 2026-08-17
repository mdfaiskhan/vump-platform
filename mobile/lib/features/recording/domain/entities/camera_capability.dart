import 'package:freezed_annotation/freezed_annotation.dart';

part 'camera_capability.freezed.dart';

/// What the platform actually reported about this device's rear camera.
///
/// The raw input to Volume 5.1 §2's ladder, kept separate from the verdict so
/// that the ladder is a pure function of data rather than of a plugin. Every
/// field is what a probe observed; no field is a conclusion.
///
/// ## `hasDedicatedUltraWide` is deliberately nullable
///
/// It is a **tri-state**, and that is the single most important thing about
/// this class. `true` means an ultra-wide lens was found; `false` means the
/// platform enumerated its lenses and none was ultra-wide; **`null` means the
/// platform cannot answer.**
///
/// Null is not a theoretical case. As of `camera_android_camerax 0.7.4+5`,
/// `availableCameras()` builds every `CameraDescription` without a
/// `lensType`, so the field defaults to `CameraLensType.unknown` on **every**
/// Android device regardless of its hardware. Tier 1 is therefore
/// unanswerable on Android through the plugin alone — the platform-channel
/// extension Volume 3 Chapter 3.1 flagged as an open engineering risk. iOS
/// answers it correctly, because `camera_avfoundation` maps AVFoundation's
/// `builtInUltraWideCamera` through.
///
/// Collapsing null into `false` would report "this device has no ultra-wide
/// lens" on hardware that plainly does. Amendment **A-057** records how the
/// ladder treats the difference.
@freezed
class CameraCapability with _$CameraCapability {
  /// Creates a capability reading.
  const factory CameraCapability({
    /// Whether any rear-facing camera exists. BR-01 requires one.
    required bool hasRearCamera,

    /// Tri-state: true, false, or null for "the platform cannot say".
    required bool? hasDedicatedUltraWide,

    /// The smallest zoom factor the rear camera reports, or null if unknown.
    ///
    /// Below 1.0 means the sensor zooms out past its native field of view,
    /// which is the Tier 2 signal. Null where no camera could be opened to
    /// ask — on Android this value requires a bound camera, which is why it
    /// cannot be read before the Checklist grants permission.
    required double? minimumZoomFactor,
  }) = _CameraCapability;

  const CameraCapability._();

  /// A reading from a device with no rear camera at all.
  ///
  /// Named rather than constructed inline so the Tier 3 test for BR-01 reads
  /// as the business rule it is.
  static const CameraCapability noRearCamera = CameraCapability(
    hasRearCamera: false,
    hasDedicatedUltraWide: null,
    minimumZoomFactor: null,
  );

  /// True when the platform could not determine whether a dedicated
  /// ultra-wide lens exists.
  bool get ultraWideIsIndeterminate => hasDedicatedUltraWide == null;
}
