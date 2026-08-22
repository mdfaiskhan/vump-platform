import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/data/camera_permission_probe_impl.dart';

CameraDescription _camera(String name, CameraLensDirection direction) =>
    CameraDescription(
      name: name,
      lensDirection: direction,
      sensorOrientation: 90,
    );

/// The probe that infers camera and microphone grants by opening a camera.
///
/// It takes both of its collaborators as typedefs, so no mock is needed — the
/// injected closures ARE the doubles, and they record what the probe asked for
/// as well as what it was told. That matters here: the failure this class can
/// have is opening the wrong camera, which no assertion about the exception
/// would catch.
void main() {
  test('opens a rear camera, not whichever the platform lists first', () async {
    late CameraDescription opened;
    final CameraPermissionProbeImpl probe = CameraPermissionProbeImpl(
      cameraLister: () async => <CameraDescription>[
        _camera('front', CameraLensDirection.front),
        _camera('rear-wide', CameraLensDirection.back),
        _camera('external', CameraLensDirection.external),
      ],
      cameraOpener: (CameraDescription camera) async => opened = camera,
    );

    await probe.verify();

    expect(opened.name, 'rear-wide');
    expect(opened.lensDirection, CameraLensDirection.back);
  });

  test('no rear camera is reported as absent, not as a refusal', () async {
    // BR-01. The file's comment is explicit that this is *"not a permission
    // answer"* — a device with no rear camera has nothing to grant, and
    // reporting it as a denial would send the Collector to app settings to
    // fix something settings cannot fix.
    final CameraPermissionProbeImpl probe = CameraPermissionProbeImpl(
      cameraLister: () async => <CameraDescription>[
        _camera('front', CameraLensDirection.front),
      ],
      cameraOpener: (CameraDescription camera) async =>
          fail('no camera should be opened'),
    );

    await expectLater(
      probe.verify,
      throwsA(
        isA<DeviceException>().having(
          (DeviceException e) => e.errorCode,
          'errorCode',
          ErrorCode.deviceRearCameraAbsent,
        ),
      ),
    );
  });

  test('an empty camera list is the same answer', () async {
    final CameraPermissionProbeImpl probe = CameraPermissionProbeImpl(
      cameraLister: () async => <CameraDescription>[],
      cameraOpener: (CameraDescription camera) async =>
          fail('no camera should be opened'),
    );

    await expectLater(
      probe.verify,
      throwsA(
        isA<DeviceException>().having(
          (DeviceException e) => e.errorCode,
          'errorCode',
          ErrorCode.deviceRearCameraAbsent,
        ),
      ),
    );
  });

  group('the two refusals stay distinguishable', () {
    Future<void> expectMapped(String pluginCode, ErrorCode expected) async {
      final CameraPermissionProbeImpl probe = CameraPermissionProbeImpl(
        cameraLister: () async => <CameraDescription>[
          _camera('rear', CameraLensDirection.back),
        ],
        cameraOpener: (CameraDescription camera) async =>
            throw CameraException(pluginCode, 'refused'),
      );

      await expectLater(
        probe.verify,
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.errorCode,
            'errorCode',
            expected,
          ),
        ),
      );
    }

    // Mission 3.8 distinguished these so C-08 can name WHICH grant is missing.
    // Collapsing them would make the checklist tell a Collector to grant the
    // permission they already granted.
    test('a camera refusal maps to devicePermissionCameraDenied', () async {
      await expectMapped(
        'CameraAccessDenied',
        ErrorCode.devicePermissionCameraDenied,
      );
    });

    test('an audio refusal maps to devicePermissionMicrophoneDenied', () async {
      await expectMapped(
        'AudioAccessDenied',
        ErrorCode.devicePermissionMicrophoneDenied,
      );
    });

    test(
      'an unrecognised plugin code falls back to cameraUnavailable',
      () async {
        await expectMapped('somethingNew', ErrorCode.deviceCameraUnavailable);
      },
    );
  });

  test(
    'the failure message carries the probe description and plugin code',
    () async {
      final CameraPermissionProbeImpl probe = CameraPermissionProbeImpl(
        cameraLister: () async => <CameraDescription>[
          _camera('rear', CameraLensDirection.back),
        ],
        cameraOpener: (CameraDescription camera) async =>
            throw CameraException('CameraAccessDenied', 'refused'),
      );

      try {
        await probe.verify();
        fail('verify should have thrown');
      } on DeviceException catch (error) {
        expect(error.message, contains('confirm camera and microphone access'));
        expect(error.message, contains('CameraAccessDenied'));
      }
    },
  );
}
