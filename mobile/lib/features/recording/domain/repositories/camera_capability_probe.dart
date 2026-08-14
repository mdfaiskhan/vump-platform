import 'package:mobile/features/recording/domain/entities/camera_capability.dart';

/// Reads what this device's rear camera can actually do.
///
/// The port between Volume 5.1 §2's ladder and the platform. `domain/` names
/// the question; `data/` owns the plugin that answers it, so the ladder can be
/// tested against every combination of answers without a device.
///
/// ## Probing is expensive, which is the whole reason for the cache
///
/// This is not a cheap property read. Answering [probe] on Android requires
/// **opening the camera**: the minimum zoom factor comes from CameraX's
/// `ZoomState`, which only exists once a camera is bound. Opening the camera
/// requires the permission Chapter 5.1 §3 assigns to the Pre-Recording
/// Checklist, and costs the user a visible shutter delay.
///
/// So this runs once per install, not once per session — Chapter 5.2 §2's
/// *"once at first launch and cached"*. `WideAngleEligibilityCache` is what
/// makes that true.
abstract interface class CameraCapabilityProbe {
  /// Reads the rear camera's capabilities.
  ///
  /// Throws a `DeviceException` if the camera exists but cannot be queried.
  /// A device with no rear camera is **not** an error — it returns
  /// [CameraCapability.noRearCamera], because absent hardware is an answer
  /// and the ladder has a rung for it.
  Future<CameraCapability> probe();
}
