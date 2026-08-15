import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/failure.dart';

/// Turns a recording [Failure] into the sentence a Collector reads.
///
/// Same position and same rules as `AuthErrorCopy`: `presentation/` matches on
/// `code`, never on a message string, because `Failure.message` is a
/// developer-facing description and may be null. Volume 2 Chapter 2.9 §2 makes
/// a generic message a defect rather than a fallback, and §4.3 requires every
/// error to pair a cause with one specific action.
abstract final class RecordingErrorCopy {
  /// The message to show for [failure].
  ///
  /// Total over `ErrorCode`. The fallback still names a cause and an action —
  /// it is the line to add a case above, not the line to leave generic.
  static String forFailure(Failure failure) => switch (failure.code) {
    ErrorCode.devicePermissionCameraDenied =>
      'Camera access is needed to record. Enable it in Settings to continue.',

    ErrorCode.devicePermissionMicrophoneDenied =>
      'Microphone access is needed to record. Enable it in Settings to '
          'continue.',

    ErrorCode.deviceRearCameraAbsent =>
      'This device has no rear camera, so it cannot record for this project. '
          'Use a different device.',

    ErrorCode.deviceWideAngleUnsupported =>
      "This device can't record at the wide-angle view this project "
          'requires. Use a different device to record this Task.',

    ErrorCode.deviceCameraUnavailable =>
      'The camera could not be opened. Close any other app using it, then try '
          'again.',

    // Ch. 5.13 §1 classifies a full disk as terminal and device-side, so the
    // action is the Collector's rather than a retry.
    ErrorCode.storageWriteFailed || ErrorCode.storageUnavailable =>
      'This recording could not be saved. Free up storage space on the device, '
          'then try again.',

    ErrorCode.storagePermissionDenied =>
      'Storage access is needed to save recordings. Enable it in Settings to '
          'continue.',

    _ =>
      'Recording could not start on this device. Run the checks again, and if '
          'it keeps failing, restart the app.',
  };
}
