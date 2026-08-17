import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/features/recording/domain/entities/checklist_check.dart';
import 'package:mobile/features/recording/domain/entities/checklist_outcome.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_eligibility.dart';

/// The words on Volume 2 Chapter 2.7's C-07 and C-08.
///
/// Same position as `AuthErrorCopy`: `presentation/` receives a domain value
/// and turns it into a sentence, and the domain never carries copy. Chapter
/// 2.9 §3 fixes the voice with a table of examples, and the pairs below follow
/// its shape exactly — *"Battery: 14% — charge to at least 20% before
/// recording"*, cause then the one thing to do.
///
/// ## Every failing row has a remedy, with no fallback that lacks one
///
/// Chapter 2.9 §2 makes a generic message a defect rather than a fallback, and
/// §4.3 requires *"a plain-language cause with a single, specific recovery
/// action ... never an error with no action attached"*. Both [label] and
/// [remedy] are total over their inputs for that reason.
abstract final class ChecklistCopy {
  /// The row's name — short, because the value carries the detail.
  static String label(ChecklistCheck check) => switch (check) {
    ChecklistCheck.cameraAndMicrophone => 'Camera & microphone',
    ChecklistCheck.freeStorage => 'Storage',
    ChecklistCheck.batteryLevel => 'Battery',
    ChecklistCheck.network => 'Network',
    ChecklistCheck.wideAngleCapability => 'Wide-angle capture',
  };

  /// The measured value shown beside the label.
  ///
  /// Chapter 2.7's C-07 requires *"icon + short label + current value (e.g.
  /// 'Battery: 82%'), never a bare icon"* — Chapter 2.10's colour-not-alone
  /// rule. A row that has not answered yet says so rather than showing an
  /// empty value that reads as zero.
  static String value(ChecklistCheck check, ChecklistOutcome outcome) {
    if (!outcome.isMeasured(check)) {
      return 'Checking…';
    }
    return switch (check) {
      ChecklistCheck.cameraAndMicrophone =>
        (outcome.permissionsGranted ?? false) ? 'Allowed' : 'Not allowed',
      ChecklistCheck.freeStorage => _gigabytes(outcome.availableBytes ?? 0),
      ChecklistCheck.batteryLevel => '${outcome.batteryPercent}%',
      ChecklistCheck.network => _network(outcome.network),
      ChecklistCheck.wideAngleCapability => _wideAngle(outcome.wideAngle),
    };
  }

  /// The one-sentence fix for a failing row — C-08's remedy card.
  static String remedy(ChecklistCheck check, ChecklistOutcome outcome) {
    return switch (check) {
      ChecklistCheck.cameraAndMicrophone => _permissionRemedy(
        outcome.permissionFailure,
      ),

      ChecklistCheck.freeStorage =>
        'Free up space until at least '
            '${_gigabytes(ChecklistOutcome.minimumFreeBytes)} is available — '
            'that is room for one full 10-minute chunk.',

      ChecklistCheck.batteryLevel =>
        'Charge to at least ${ChecklistOutcome.minimumBatteryPercent}% before '
            'recording.',

      // Unreachable in practice: FR-CHK-04 never fails a row, because Chapter
      // 2.9 §5 makes recording independent of connectivity. Written anyway so
      // the function is total and no row can reach the screen without a fix.
      ChecklistCheck.network =>
        'Connect to Wi-Fi or mobile data if you want uploads to start right '
            'away. Recording works either way.',

      ChecklistCheck.wideAngleCapability =>
        "This device can't record at the wide-angle view this project "
            'requires. Use a different device to record this Task.',
    };
  }

  /// What the network row tells the Collector will happen to their uploads.
  ///
  /// FR-CHK-04's actual obligation — *"inform the Collector whether upload
  /// will start immediately or be queued"* — which is a sentence about the
  /// future, not a status word. Shown on the row whether it passes or not,
  /// because it always passes.
  static String uploadExpectation(NetworkType? network) => switch (network) {
    null => '',
    NetworkType.wifi => 'Uploads will start right away.',
    NetworkType.cellular => 'Uploads will start right away, over mobile data.',
    NetworkType.none => 'Uploads will queue until you are back online.',
  };

  static String _permissionRemedy(ErrorCode? failure) => switch (failure) {
    ErrorCode.devicePermissionCameraDenied =>
      'Camera access is needed to record. Enable it in Settings to continue.',
    ErrorCode.devicePermissionMicrophoneDenied =>
      'Microphone access is needed to record. Enable it in Settings to '
          'continue.',
    ErrorCode.deviceRearCameraAbsent =>
      'This device has no rear camera, so it cannot record for this project. '
          'Use a different device.',
    // Every other device code, including a camera held by another app.
    _ =>
      'The camera could not be opened. Close any other app using it, then '
          'run this check again.',
  };

  static String _network(NetworkType? network) => switch (network) {
    null => 'Checking…',
    NetworkType.wifi => 'Wi-Fi',
    NetworkType.cellular => 'Mobile data',
    NetworkType.none => 'Offline',
  };

  static String _wideAngle(WideAngleEligibility? eligibility) =>
      switch (eligibility) {
        null => 'Checking…',
        WideAngleEligibilityOptical(:final double zoomFactor) =>
          '${zoomFactor}x ultra-wide lens',
        WideAngleEligibilityHybrid(:final double zoomFactor) =>
          '${zoomFactor}x wide',
        WideAngleEligibilityIneligible() => 'Not supported',
      };

  /// Bytes as the Collector reads them.
  ///
  /// Decimal GB, not GiB: the number beside it on a phone's own storage screen
  /// is decimal, and a checklist that disagreed with Settings by 7 % would
  /// look wrong to the person reading both.
  static String _gigabytes(int bytes) {
    final double gb = bytes / (1000 * 1000 * 1000);
    return '${gb.toStringAsFixed(1)} GB';
  }
}
