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

  group('permission is not handled here, deliberately', () {
    test('CameraAccessDenied maps to unavailable like any other failure', () {
      // Volume 5.1 §3 puts BR-03 with the Pre-Recording Checklist and says it
      // is "not re-checked redundantly here". This code arriving means the
      // Checklist's guarantee was broken upstream; handling it would build
      // the redundant re-check the chapter forbids.
      expect(
        CameraErrorMapper.mapCode('CameraAccessDenied'),
        ErrorCode.deviceCameraUnavailable,
      );
    });

    test('no error code in the taxonomy names camera permission', () {
      // Guards the decision above from being quietly reversed by adding a
      // code for it.
      final Iterable<String> codes = ErrorCode.values.map(
        (ErrorCode e) => e.code,
      );

      expect(codes, isNot(contains('DEVICE_CAMERA_PERMISSION_DENIED')));
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
