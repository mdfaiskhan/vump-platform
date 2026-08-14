import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_fingerprint.freezed.dart';

/// The two values that decide whether a cached eligibility verdict is stale.
///
/// Volume 5.2 §2 fixes the zoom-factor decision *"once at first launch and
/// cached — not re-negotiated every session"*, and this is what "still the
/// same situation" means in practice.
///
/// ## Why exactly these two, and nothing else
///
/// **The app version** changes when this code changes. A new ladder, a new
/// threshold, or the Android platform channel landing all arrive as a new
/// build, and all three can turn yesterday's verdict into the wrong answer.
///
/// **The OS version** changes when the platform's own answers change. Camera2
/// and CameraX gain and lose capabilities across Android releases; a device
/// that could not zoom out on one version may on the next.
///
/// A device model identifier is deliberately **not** here. The cache is
/// per-install and an install does not move between devices, so the model
/// cannot change without the store also changing. Adding it would read as
/// though it could.
///
/// **Nothing here identifies a person.** Two version strings, both already
/// known to every app on the device.
@freezed
class DeviceFingerprint with _$DeviceFingerprint {
  /// Creates a fingerprint.
  const factory DeviceFingerprint({
    /// The application's version, as `AppInfo.fullVersion` reports it.
    required String appVersion,

    /// The platform's version, as `Platform.operatingSystemVersion` reports.
    required String osVersion,
  }) = _DeviceFingerprint;
}
