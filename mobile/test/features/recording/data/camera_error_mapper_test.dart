import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/data/camera_error_mapper.dart';

/// The `camera` conversion boundary (ADR-025 §7, error-handling.md §26).
void main() {
  group('codes that carry a distinct meaning', () {
    test('a missing camera maps to the absent-hardware code', () {
      expect(
        CameraErrorMapper.mapCode('cameraNotFound'),
        ErrorCode.deviceRearCameraAbsent,
      );
      expect(
        CameraErrorMapper.mapCode('noCameraAvailable'),
        ErrorCode.deviceRearCameraAbsent,
      );
    });

    test('a zoom read failure is unavailable, not a wide-angle verdict', () {
      // The ladder decides eligibility. A failed read is an unusable probe,
      // and mapping it to DEVICE_WIDE_ANGLE_UNSUPPORTED would let a transient
      // platform fault hard-block a capable device.
      expect(
        CameraErrorMapper.mapCode('zoomStateNotSet'),
        ErrorCode.deviceCameraUnavailable,
      );
    });
  });

  group('permission refusals are named — changed at Mission 3.8', () {
    // Until Mission 3.8 these collapsed into deviceCameraUnavailable, and a
    // test here asserted that no code named camera permission at all. The
    // reasoning was that Volume 5.1 §3 assigns BR-03 to the Checklist, so a
    // refusal reaching the camera module meant an upstream guarantee had
    // already broken.
    //
    // That reasoning was about *requesting* permission, and it still holds —
    // nothing here requests anything. What changed is that the Checklist now
    // exists, and FR-CHK-05 requires it to name the specific failed check.
    // `CameraPermissionProbeImpl` verifies both grants by opening a camera
    // with audio, and the plugin code is the only thing that says which grant
    // is missing. Flattening it would make C-08's remedy card generic, which
    // Volume 2 Ch. 2.9 §2 calls a defect rather than a fallback.

    test('CameraAccessDenied names the camera grant', () {
      expect(
        CameraErrorMapper.mapCode('CameraAccessDenied'),
        ErrorCode.devicePermissionCameraDenied,
      );
    });

    test('AudioAccessDenied names the microphone grant, separately', () {
      // BR-03 requires both, and they are separate grants — a Collector who
      // allowed one and refused the other must be told which.
      expect(
        CameraErrorMapper.mapCode('AudioAccessDenied'),
        ErrorCode.devicePermissionMicrophoneDenied,
      );
    });

    test('the without-prompt and restricted variants map the same way', () {
      // Same remedy either way: enable it in Settings. The distinction the
      // plugin draws is about whether a prompt is still possible, which the
      // copy does not depend on.
      expect(
        CameraErrorMapper.mapCode('CameraAccessDeniedWithoutPrompt'),
        ErrorCode.devicePermissionCameraDenied,
      );
      expect(
        CameraErrorMapper.mapCode('AudioAccessRestricted'),
        ErrorCode.devicePermissionMicrophoneDenied,
      );
    });

    test('a non-permission failure is still unavailable', () {
      // The camera held by another app is not a refusal, and its remedy is
      // different — close the other app, not open Settings.
      expect(
        CameraErrorMapper.mapCode('cameraNotReadable'),
        ErrorCode.deviceCameraUnavailable,
      );
    });
  });

  group('unrecognised codes', () {
    test('anything unknown is still unavailable, never null', () {
      // The plugin's codes are not a documented closed set — the platform
      // implementations pass their own strings through.
      for (final String code in <String>[
        '',
        'someFutureAndroidCode',
        'AVFoundationErrorDomain-11800',
      ]) {
        expect(
          CameraErrorMapper.mapCode(code),
          ErrorCode.deviceCameraUnavailable,
          reason: code,
        );
      }
    });
  });

  group('the wrapped exception', () {
    test('is a DeviceException carrying the mapped code', () {
      final DeviceException result = CameraErrorMapper.toDeviceException(
        CameraException('cameraNotFound', 'none'),
        StackTrace.empty,
        description: 'open the rear camera',
      );

      expect(result.errorCode, ErrorCode.deviceRearCameraAbsent);
      expect(result.message, contains('open the rear camera'));
      expect(result.cause, isA<CameraException>());
    });

    test('the message names the plugin code but not its description', () {
      // The code is diagnostic and safe; the description is vendor text that
      // presentation must never render.
      final DeviceException result = CameraErrorMapper.toDeviceException(
        CameraException('someCode', 'internal vendor detail'),
        StackTrace.empty,
        description: 'read the zoom range',
      );

      expect(result.message, contains('someCode'));
      expect(result.message, isNot(contains('internal vendor detail')));
    });

    test('the stack trace is preserved', () {
      final StackTrace trace = StackTrace.current;
      final DeviceException result = CameraErrorMapper.toDeviceException(
        CameraException('x', 'y'),
        trace,
        description: 'probe',
      );

      expect(result.stackTrace, same(trace));
    });
  });
}
