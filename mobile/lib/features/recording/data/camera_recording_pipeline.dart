import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import 'package:mobile/features/recording/data/camera_error_mapper.dart';
import 'package:mobile/features/recording/data/capture_orientation_wire_name.dart';
import 'package:mobile/features/recording/domain/entities/camera_specification.dart';
import 'package:mobile/features/recording/domain/entities/preview_frame.dart';
import 'package:mobile/features/recording/domain/repositories/recording_pipeline.dart';

/// Opens a camera. Injected so the pipeline is testable without hardware.
typedef CameraOpener =
    Future<CameraController> Function(CameraDescription camera);

/// Lists the device's cameras. Defaults to the plugin's `availableCameras`.
typedef PipelineCameraLister = Future<List<CameraDescription>> Function();

/// Volume 5 Chapter 5.4's pipeline, as far as the `camera` plugin exposes it.
///
/// ## What this class is, honestly
///
/// Chapter 5.4 §1 describes a chain: hardware encoder, real-time muxer,
/// buffered writer, filesystem. **None of those stages is built here, and none
/// can be.** The plugin exposes `startVideoRecording` and
/// `stopVideoRecording` and nothing between them — its controller has no
/// flush, buffer, segment or split control of any kind. Every stage of the
/// chain is inside CameraX's `Recorder`.
///
/// Amendment **A-058** corrects the chapter to say so, on the grounds that
/// Volume 3 Chapter 3.1 chose this plugin over a hand-rolled native pipeline
/// and that decision outranks a Draft chapter's implementation detail. It also
/// records what the correction costs, and neither cost is resolved:
///
/// - **"Never a software encoder" is unverifiable, and may not always hold.**
///   CameraX selects the encoder; it can fall back to software on some devices
///   and configurations, and nothing in the Dart API reports which was used.
///   For a dataset business this is a silent quality risk, not a cosmetic one.
/// - **The flush interval is unobservable and unconfigurable.** Chapter 5.4 §1
///   promises a crash loses "at most the last buffer interval". CameraX does
///   write incrementally, so the shape of the promise holds, but its size is
///   not ours to set or measure.
///
/// Both are on the Volume 9 device-matrix follow-up rather than presented as
/// satisfied.
///
/// ## Capture parameters
///
/// Chapter 5.2 §1's values are passed to the controller at construction —
/// resolution, frame rate, video and audio bitrate. Verified accepted on a
/// CPH2707: `veryHigh` with `fps: 30`, `videoBitrate: 8000k`,
/// `audioBitrate: 128k` initialises without complaint.
class CameraRecordingPipeline implements RecordingPipeline {
  /// Creates a pipeline over the plugin, or over injected doubles for tests.
  CameraRecordingPipeline({
    required String outputDirectoryPath,
    PipelineCameraLister? cameraLister,
    CameraOpener? cameraOpener,
  }) : _outputDirectory = outputDirectoryPath,
       _listCameras = cameraLister ?? availableCameras,
       _openCamera = cameraOpener ?? _defaultOpen;

  final String _outputDirectory;
  final PipelineCameraLister _listCameras;
  final CameraOpener _openCamera;

  CameraController? _controller;

  /// ADR-053. Broadcast so more than one widget may watch; never closed while
  /// the pipeline lives, because a session can be reopened.
  final StreamController<PreviewFrame?> _previewChanges =
      StreamController<PreviewFrame?>.broadcast();
  PreviewFrame? _currentPreview;

  @override
  String? get outputDirectory => _controller == null ? null : _outputDirectory;

  @override
  String? get captureOrientation {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }
    // `lockedCaptureOrientation` first, because that is what a locked session
    // will actually encode at. Falling through to `deviceOrientation` is not a
    // fallback for a missing value — on a build without ADR-054's lock it is
    // the whole answer, and reporting it honestly is what lets a chunk say
    // which régime it was recorded under.
    return CaptureOrientationWireName.of(
      controller.value.lockedCaptureOrientation ??
          controller.value.deviceOrientation,
    );
  }

  @override
  Stream<PreviewFrame?> get previewChanges => _previewChanges.stream;

  @override
  PreviewFrame? get currentPreview => _currentPreview;

  @override
  Future<void> openSession({required double zoomFactor}) async {
    try {
      final List<CameraDescription> rear = (await _listCameras())
          .where(
            (CameraDescription c) =>
                c.lensDirection == CameraLensDirection.back,
          )
          .toList();

      if (rear.isEmpty) {
        // BR-01. Unreachable in practice — the Checklist has already refused a
        // device with no rear camera — but the pipeline does not assume it.
        throw CameraException(
          'cameraNotFound',
          'No rear-facing camera is available.',
        );
      }

      final CameraController controller = await _openCamera(rear.first);
      _controller = controller;
      await _applyZoomOnce(controller, zoomFactor);
      // ADR-053. The controller is a ValueNotifier<CameraValue>; listening is
      // how orientation and readiness changes reach the screen. The listener
      // is the only thing outside this class that learns anything about the
      // controller, and what it learns is three numbers.
      controller.addListener(_onCameraValueChanged);
      _publish(_frameOf(controller));
    } on CameraException catch (error, stackTrace) {
      throw CameraErrorMapper.toDeviceException(
        error,
        stackTrace,
        description: 'open the camera for this session',
      );
    }
  }

  /// Locks the wide-angle factor for the whole session.
  ///
  /// ## The defensive floor, and why it is belt-and-braces
  ///
  /// The value sent is `max(verdict, platformMinimum)`, where the minimum is
  /// read from **this** controller's own binding rather than from the cached
  /// eligibility verdict. Two different situations are covered by one
  /// expression:
  ///
  /// - The verdict is 0.5 on a device whose floor is 0.25 — the ladder clamped
  ///   deliberately, because fleet comparability is BR-02's stated rationale.
  ///   `max` keeps 0.5 and does not hand the device its extra reach.
  /// - The verdict is 0.6 on a device whose floor reads 0.6000000238418579 —
  ///   the float32 widening corrected in A-057. `max` sends the platform's own
  ///   number, which cannot be below its own floor.
  ///
  /// **Measured on a CPH2707, this guard changes nothing.** `setZoomLevel`
  /// accepted 0.6, accepted the raw minimum, and also accepted 0.3 — half the
  /// reported floor — so that platform performs no range validation at all.
  /// The guard is therefore belt-and-braces rather than load-bearing here.
  ///
  /// It is kept for two reasons. iOS *does* clamp `videoZoomFactor` to its
  /// available range, so a device that validates is protected. And the absence
  /// of range checking on Android is itself the risk: a wrong value produces
  /// no error, just silently wrong footage, so the only defence is not
  /// computing one.
  Future<void> _applyZoomOnce(
    CameraController controller,
    double verdictFactor,
  ) async {
    final double platformMinimum = await controller.getMinZoomLevel();
    final double toApply = verdictFactor > platformMinimum
        ? verdictFactor
        : platformMinimum;
    await controller.setZoomLevel(toApply);
  }

  @override
  Future<void> startChunk() async {
    final CameraController controller = _requireOpenSession('start a chunk');
    try {
      await controller.startVideoRecording();
    } on CameraException catch (error, stackTrace) {
      throw CameraErrorMapper.toDeviceException(
        error,
        stackTrace,
        description: 'start recording a chunk',
      );
    }
  }

  @override
  Future<String> stopChunk() async {
    final CameraController controller = _requireOpenSession('stop a chunk');
    try {
      final XFile file = await controller.stopVideoRecording();
      return file.path;
    } on CameraException catch (error, stackTrace) {
      throw CameraErrorMapper.toDeviceException(
        error,
        stackTrace,
        description: 'finish recording a chunk',
      );
    }
  }

  @override
  Future<void> closeSession() async {
    final CameraController? controller = _controller;
    _controller = null;
    controller?.removeListener(_onCameraValueChanged);
    // Before dispose, so nothing is drawing a texture that is about to go.
    _publish(null);
    await controller?.dispose();
  }

  void _onCameraValueChanged() {
    final CameraController? controller = _controller;
    _publish(controller == null ? null : _frameOf(controller));
  }

  /// Publishes only on a real change.
  ///
  /// `CameraValue` notifies for things a preview does not care about — a
  /// recording flag flipping, an exposure point moving. [PreviewFrame] has
  /// value equality, so filtering here keeps a listening widget from
  /// rebuilding on every notification during a 25-minute session.
  void _publish(PreviewFrame? frame) {
    if (frame == _currentPreview) {
      return;
    }
    _currentPreview = frame;
    if (!_previewChanges.isClosed) {
      _previewChanges.add(frame);
    }
  }

  /// Reads a [PreviewFrame] out of the controller's current value.
  ///
  /// Reproduces what `CameraPreview` does internally, because that widget
  /// cannot be used without handing it the controller. The aspect ratio is
  /// flipped for portrait exactly as it flips it, and the orientation-to-turns
  /// mapping is its table.
  static PreviewFrame? _frameOf(CameraController controller) {
    final CameraValue value = controller.value;
    if (!value.isInitialized) {
      return null;
    }
    final DeviceOrientation orientation = value.isRecordingVideo
        ? (value.recordingOrientation ?? value.deviceOrientation)
        : (value.previewPauseOrientation ??
              value.lockedCaptureOrientation ??
              value.deviceOrientation);
    const Map<DeviceOrientation, int> turns = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeRight: 1,
      DeviceOrientation.portraitDown: 2,
      DeviceOrientation.landscapeLeft: 3,
    };
    final bool isLandscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    return PreviewFrame(
      textureId: controller.cameraId,
      aspectRatio: isLandscape ? value.aspectRatio : 1 / value.aspectRatio,
      quarterTurns: turns[orientation] ?? 0,
    );
  }

  CameraController _requireOpenSession(String action) {
    final CameraController? controller = _controller;
    if (controller == null) {
      throw CameraErrorMapper.toDeviceException(
        CameraException(
          'sessionNotOpen',
          'openSession must be called before attempting to $action.',
        ),
        StackTrace.current,
        description: action,
      );
    }
    return controller;
  }

  /// Opens a controller at Chapter 5.2 §1's parameters.
  static Future<CameraController> _defaultOpen(CameraDescription camera) async {
    final CameraController controller = CameraController(
      camera,
      // veryHigh is the plugin's 1080p preset — CameraSpecification's
      // 1920x1080. The preset enum has no exact-dimensions variant, so the
      // resolution is requested by name here and by number there.
      ResolutionPreset.veryHigh,
      fps: CameraSpecification.frameRate,
      videoBitrate: CameraSpecification.targetVideoBitrateKbps * 1000,
      audioBitrate: CameraSpecification.audioBitrateKbps * 1000,
    );
    await controller.initialize();
    return controller;
  }
}
