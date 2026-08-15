import 'package:camera/camera.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';

/// Converts `camera` plugin failures into the application error taxonomy.
///
/// The conversion boundary ADR-025 §7 requires of every new package and
/// error-handling.md §26 places at `data/`. **No `CameraException` leaves this
/// layer**, which is what lets `application/` and `presentation/` stay unaware
/// that a camera plugin exists at all.
///
/// ## The plugin's error shape, read rather than assumed
///
/// `CameraException` carries a `String code` and a `String? description`, and
/// the codes are not a documented closed set — the platform implementations
/// pass through their own strings alongside the plugin's own. The switch below
/// therefore names the codes worth distinguishing and sends everything else to
/// [ErrorCode.deviceCameraUnavailable] rather than pretending to be
/// exhaustive.
///
/// ## Permission codes map to "unavailable", and that is not an oversight
///
/// `CameraAccessDenied` is mapped like any other failure to open the camera,
/// and **no permission handling happens here**. Volume 5.1 §3 puts camera and
/// microphone permission (BR-03) with the Pre-Recording Checklist and states
/// it is *"not re-checked redundantly here"* — the Camera Module *"never
/// attempts to initialize without both permissions already confirmed
/// granted"*.
///
/// So this code arriving at all means the Checklist's guarantee was broken
/// upstream. Handling it here would build the redundant re-check the chapter
/// forbids, and would quietly make this module a second place permission
/// policy lives.
abstract final class CameraErrorMapper {
  /// Wraps [error] as a [DeviceException] in the taxonomy.
  static DeviceException toDeviceException(
    CameraException error,
    StackTrace stackTrace, {
    required String description,
  }) {
    return DeviceException(
      errorCode: mapCode(error.code),
      message:
          'The camera could not $description '
          '(plugin code: ${error.code}).',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Maps a `CameraException.code` onto the taxonomy.
  ///
  /// Every unrecognised code becomes [ErrorCode.deviceCameraUnavailable]:
  /// whatever went wrong, the camera is not usable, and that is the only
  /// thing a caller can act on.
  static ErrorCode mapCode(String code) {
    return switch (code) {
      // The plugin could not find a camera to open at all.
      'cameraNotFound' ||
      'noCameraAvailable' => ErrorCode.deviceRearCameraAbsent,

      // Zoom could not be queried, which is the Tier 2 probe failing. Not a
      // wide-angle verdict — the ladder decides that — just an unusable read.
      'zoomStateNotSet' ||
      'setZoomLevelFailed' ||
      'ZoomLevelInvalid' => ErrorCode.deviceCameraUnavailable,

      // Permission refusals, distinguished by Mission 3.8. The class comment
      // above still holds — nothing here *requests* a permission, which is
      // Volume 5.1 §3's assignment to the Checklist. What changed is that the
      // Checklist now exists and FR-CHK-05 requires it to name which grant is
      // missing, so the two refusals are no longer flattened into "the camera
      // could not be opened".
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' ||
      'CameraAccessRestricted' => ErrorCode.devicePermissionCameraDenied,
      'AudioAccessDenied' ||
      'AudioAccessDeniedWithoutPrompt' ||
      'AudioAccessRestricted' => ErrorCode.devicePermissionMicrophoneDenied,
      _ => ErrorCode.deviceCameraUnavailable,
    };
  }
}
