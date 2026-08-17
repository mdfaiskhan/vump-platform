import 'package:camera/camera.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/data/camera_error_mapper.dart';
import 'package:mobile/features/recording/domain/repositories/camera_permission_probe.dart';

/// Opens a camera and closes it again, to prove FR-CHK-01's two grants.
///
/// ## `enableAudio: true` is the whole point
///
/// `CameraCapabilityProbeImpl` opens with audio **disabled**, because it is
/// asking about zoom and audio buffers would be waste. That makes it useless
/// for FR-CHK-01: BR-03 requires both grants, and a camera opened without
/// audio never touches the microphone permission. This probe exists because
/// the two questions need two different opens.
///
/// ## The lowest preset, and released immediately
///
/// Nothing is recorded. The controller is initialized and disposed in the same
/// call, so the shutter is held for as short a time as the platform allows.
/// `ResolutionPreset.low` keeps the allocation small — the capture resolution
/// is `CameraSpecification`'s and belongs to the session's own controller.
class CameraPermissionProbeImpl implements CameraPermissionProbe {
  /// Creates a probe, or one over injected doubles for tests.
  CameraPermissionProbeImpl({
    PermissionCameraLister? cameraLister,
    PermissionCameraOpener? cameraOpener,
  }) : _listCameras = cameraLister ?? availableCameras,
       _openCamera = cameraOpener ?? _defaultOpen;

  final PermissionCameraLister _listCameras;
  final PermissionCameraOpener _openCamera;

  @override
  Future<void> verify() async {
    try {
      final List<CameraDescription> rear = (await _listCameras())
          .where(
            (CameraDescription c) =>
                c.lensDirection == CameraLensDirection.back,
          )
          .toList();

      if (rear.isEmpty) {
        // BR-01. Not a permission answer, and reported as itself rather than
        // as a refusal — a device with no rear camera has nothing to grant.
        throw const DeviceException(
          errorCode: ErrorCode.deviceRearCameraAbsent,
          message: 'This device has no rear-facing camera.',
        );
      }

      await _openCamera(rear.first);
    } on CameraException catch (error, stackTrace) {
      // CameraErrorMapper distinguishes the two refusals as of Mission 3.8,
      // which is what lets C-08 name which grant is missing.
      throw CameraErrorMapper.toDeviceException(
        error,
        stackTrace,
        description: 'confirm camera and microphone access',
      );
    }
  }

  static Future<void> _defaultOpen(CameraDescription camera) async {
    final CameraController controller = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: true,
    );
    try {
      await controller.initialize();
    } finally {
      await controller.dispose();
    }
  }
}

/// Lists the cameras the platform reports.
typedef PermissionCameraLister = Future<List<CameraDescription>> Function();

/// Opens and releases one camera with audio enabled.
typedef PermissionCameraOpener =
    Future<void> Function(CameraDescription camera);
