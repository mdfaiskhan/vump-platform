import 'package:camera/camera.dart';

import 'package:mobile/features/recording/data/camera_error_mapper.dart';
import 'package:mobile/features/recording/domain/entities/camera_capability.dart';
import 'package:mobile/features/recording/domain/repositories/camera_capability_probe.dart';

/// Lists the device's cameras. Defaults to the plugin's `availableCameras`.
typedef CameraLister = Future<List<CameraDescription>> Function();

/// Reads the minimum zoom factor of one camera, opening it if it must.
typedef MinimumZoomReader = Future<double> Function(CameraDescription camera);

/// Reads rear-camera capability through the `camera` plugin.
///
/// The only file in this feature that imports `camera`, and the only one that
/// can see a `CameraException` — [CameraErrorMapper] converts every failure
/// before it leaves.
///
/// ## Tier 1 is answerable on iOS and not on Android
///
/// This is the engineering risk Volume 3 Chapter 3.1 flagged, confirmed by
/// reading the platform packages rather than inferred:
///
/// - **iOS** — `camera_avfoundation` includes `.builtInUltraWideCamera` in its
///   discovery session and maps it to [CameraLensType.ultraWide]. Tier 1 is a
///   real answer.
/// - **Android** — `camera_android_camerax 0.7.4+5` builds every
///   `CameraDescription` without a `lensType`, so the field is
///   [CameraLensType.unknown] on every device whatever its hardware. Tier 1
///   cannot be answered here at all.
///
/// [_hasDedicatedUltraWide] returns **null** rather than false in that case,
/// and the distinction is load-bearing — see [CameraCapability] and amendment
/// A-057. Closing it needs the Camera2 platform channel Chapter 3.1
/// anticipated, which is not this mission's scope.
///
/// ## Reading the minimum zoom factor costs a camera open
///
/// Android's `getMinZoomLevel` reads CameraX's `ZoomState`, which exists only
/// once a camera is bound. The default [MinimumZoomReader] therefore opens the
/// camera, reads, and disposes — and this is why the result is cached for the
/// life of the install rather than re-read per session (Volume 5.2 §2).
///
/// It also means this must not run before the Pre-Recording Checklist has
/// confirmed camera permission (Volume 5.1 §3, BR-03). This class does not
/// check that and by design cannot: the Checklist owns it.
class CameraCapabilityProbeImpl implements CameraCapabilityProbe {
  /// Creates a probe over the plugin, or over injected readers for tests.
  CameraCapabilityProbeImpl({
    CameraLister? cameraLister,
    MinimumZoomReader? minimumZoomReader,
  }) : _listCameras = cameraLister ?? availableCameras,
       _readMinimumZoom = minimumZoomReader ?? _openAndReadMinimumZoom;

  final CameraLister _listCameras;
  final MinimumZoomReader _readMinimumZoom;

  @override
  Future<CameraCapability> probe() async {
    final List<CameraDescription> rearCameras;
    try {
      final List<CameraDescription> all = await _listCameras();
      rearCameras = all
          .where(
            (CameraDescription c) =>
                c.lensDirection == CameraLensDirection.back,
          )
          .toList();
    } on CameraException catch (error, stackTrace) {
      throw CameraErrorMapper.toDeviceException(
        error,
        stackTrace,
        description: 'list the available cameras',
      );
    }

    // BR-01 — absent hardware is an answer, not a failure. The ladder has a
    // rung for it, so this returns rather than throws.
    if (rearCameras.isEmpty) {
      return CameraCapability.noRearCamera;
    }

    final bool? hasDedicatedUltraWide = _hasDedicatedUltraWide(rearCameras);

    // Tier 2's reading costs a camera open, so it is not taken when Tier 1
    // has already settled the question. On iPhone 11 and later the lens type
    // answers Tier 1 outright, and `availableCameras()` needs no camera
    // authorisation to say so — reading the zoom range anyway would force an
    // open, and a shutter delay, for a value the ladder then discards at its
    // first branch.
    //
    // Skipped rather than absent: a null `minimumZoomFactor` already means
    // "not known", which is exactly true here, and the ladder never consults
    // it once Tier 1 is affirmative.
    final double? minimumZoom = hasDedicatedUltraWide ?? false
        ? null
        : await _minimumZoomOrNull(rearCameras.first);

    return CameraCapability(
      hasRearCamera: true,
      hasDedicatedUltraWide: hasDedicatedUltraWide,
      minimumZoomFactor: minimumZoom,
    );
  }

  /// Tri-state Tier 1: true, false, or null for "the platform cannot say".
  ///
  /// Null when **every** rear camera reports [CameraLensType.unknown], which
  /// is the Android case described on this class. If any camera reports a
  /// real lens type, the platform is answering the question, and the absence
  /// of an ultra-wide among the answers is then a genuine `false`.
  static bool? _hasDedicatedUltraWide(List<CameraDescription> rearCameras) {
    final bool anyUltraWide = rearCameras.any(
      (CameraDescription c) => c.lensType == CameraLensType.ultraWide,
    );
    if (anyUltraWide) {
      return true;
    }

    final bool platformAnswers = rearCameras.any(
      (CameraDescription c) => c.lensType != CameraLensType.unknown,
    );
    return platformAnswers ? false : null;
  }

  /// The camera's minimum zoom, or null if it could not be read.
  ///
  /// A failure here is **not** propagated as a `DeviceException`. An
  /// unreadable zoom factor is a missing Tier 2 answer, and the ladder
  /// already treats a null minimum as "Tier 2 did not report support" — which
  /// is the correct reading. Throwing instead would turn one unanswerable
  /// probe into a hard failure of the whole capability read, on a device that
  /// may well have a dedicated ultra-wide lens and never needed Tier 2.
  Future<double?> _minimumZoomOrNull(CameraDescription camera) async {
    try {
      return await _readMinimumZoom(camera);
    } on CameraException {
      return null;
    }
  }

  /// Opens [camera] purely to read its minimum zoom factor, then closes it.
  ///
  /// Disposed in a `finally` so a throw between initialize and read does not
  /// strand the camera held open — which on Android denies every later
  /// attempt, including the recording this probe exists to enable.
  static Future<double> _openAndReadMinimumZoom(
    CameraDescription camera,
  ) async {
    final CameraController controller = CameraController(
      camera,
      // The lowest preset that exists. This controller never records — it is
      // opened to ask one question — so requesting the capture resolution
      // would allocate buffers for footage nobody wants. The capture
      // resolution is CameraSpecification's, applied by Chapter 5.4.
      ResolutionPreset.low,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      return await controller.getMinZoomLevel();
    } finally {
      await controller.dispose();
    }
  }
}
