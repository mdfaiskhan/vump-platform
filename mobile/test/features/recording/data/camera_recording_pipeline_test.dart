import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/data/camera_recording_pipeline.dart';
import 'package:mobile/features/recording/domain/entities/preview_frame.dart';

/// The pipeline's own responsibilities: opening once, locking the zoom once,
/// and converting failures.
///
/// The encoder, muxer and writer are CameraX's (A-058), so there is nothing
/// here to test about them — which is the point of the amendment, and why
/// these tests are about the seams rather than the chain.
void main() {
  CameraDescription camera({
    CameraLensDirection direction = CameraLensDirection.back,
    String name = 'cam',
  }) => CameraDescription(
    name: name,
    lensDirection: direction,
    sensorOrientation: 90,
  );

  CameraRecordingPipeline build({
    List<CameraDescription>? cameras,
    _FakeController? controller,
    Exception? openThrows,
  }) {
    return CameraRecordingPipeline(
      outputDirectoryPath: '/documents/recordings',
      cameraLister: () async => cameras ?? <CameraDescription>[camera()],
      cameraOpener: (CameraDescription _) async {
        if (openThrows != null) {
          throw openThrows;
        }
        return controller ?? _FakeController();
      },
    );
  }

  group('the zoom factor is applied once per session', () {
    test('the verdict is sent when it is at or above the platform '
        'floor', () async {
      final _FakeController controller = _FakeController(minZoom: 0.5);

      await build(controller: controller).openSession(zoomFactor: 0.5);

      expect(controller.zoomCalls, <double>[0.5]);
    });

    test('a clamped verdict is NOT lowered to the device floor', () async {
      // A device that reaches 0.25 was deliberately clamped to 0.5 by the
      // ladder, because fleet comparability is BR-02's stated rationale.
      // Sending the floor here would hand it back the extra reach and break
      // BR-02.
      final _FakeController controller = _FakeController(minZoom: 0.25);

      await build(controller: controller).openSession(zoomFactor: 0.5);

      expect(controller.zoomCalls, <double>[0.5]);
    });

    test('float32 widening is absorbed by the defensive floor', () async {
      // The A-057 case: the platform reports 0.6f as 0.6000000238418579, so
      // the verdict's 0.6 is fractionally *below* the device's own floor.
      // max() sends the platform's own number, which cannot be out of range.
      //
      // Belt-and-braces, not load-bearing: measured on a CPH2707,
      // setZoomLevel accepted 0.6, the raw minimum, and even 0.3 — that
      // platform performs no range validation at all. iOS does clamp, so the
      // guard protects a device that validates.
      final _FakeController controller = _FakeController(
        minZoom: 0.6000000238418579,
      );

      await build(controller: controller).openSession(zoomFactor: 0.6);

      expect(controller.zoomCalls, <double>[0.6000000238418579]);
    });

    test('it is set once, not again per chunk', () async {
      // Ch. 5.2 §1: "fixed for the whole session, never changed
      // mid-recording". Three chunks over one open session.
      final _FakeController controller = _FakeController(minZoom: 0.5);
      final CameraRecordingPipeline pipeline = build(controller: controller);

      await pipeline.openSession(zoomFactor: 0.5);
      for (int i = 0; i < 3; i++) {
        await pipeline.startChunk();
        await pipeline.stopChunk();
      }

      expect(controller.zoomCalls, hasLength(1));
    });
  });

  group('quarterTurns follows deviceOrientation, and MUST keep doing so', () {
    // **This is a pinned invariant, not a preference. Read item 157 before
    // changing it.**
    //
    // `camera_android_camerax`'s preview delegate subtracts
    // getPreAppliedQuarterTurnsRotationFromDeviceOrientation(deviceOrientation)
    // from its own rotation, expecting the widget to add exactly that back.
    // Both sides read the SAME platform stream — camera_controller.dart:338 and
    // android_camera_camerax.dart:1006 — so the two terms cancel and the net
    // rotation is the delegate's display rotation, whether or not
    // `deviceOrientation` is stale.
    //
    // Sourcing this from the window instead breaks the cancellation and lands
    // the preview a quarter turn out. That has been proposed twice and is wrong
    // both times.
    Future<PreviewFrame?> frameFor(DeviceOrientation orientation) async {
      final _FakeController controller = _FakeController()
        ..initialised = true
        ..deviceOrientation = orientation;
      final CameraRecordingPipeline pipeline = build(controller: controller);
      await pipeline.openSession(zoomFactor: 0.6);
      return pipeline.currentPreview;
    }

    test('each orientation maps to the plugin s own turn table', () async {
      // Identical to getPreAppliedQuarterTurnsRotationFromDeviceOrientation.
      expect((await frameFor(DeviceOrientation.portraitUp))?.quarterTurns, 0);
      expect(
        (await frameFor(DeviceOrientation.landscapeRight))?.quarterTurns,
        1,
      );
      expect((await frameFor(DeviceOrientation.portraitDown))?.quarterTurns, 2);
      expect(
        (await frameFor(DeviceOrientation.landscapeLeft))?.quarterTurns,
        3,
      );
    });

    test('the LOCKED capture orientation does not move it', () async {
      // ADR-054 locks capture to landscapeLeft. If quarterTurns followed the
      // lock it would be a constant 3 and the preview would never rotate —
      // the freeze ADR-054 decision 2 exists to prevent.
      final _FakeController controller = _FakeController()
        ..initialised = true
        ..deviceOrientation = DeviceOrientation.portraitUp
        ..lockedCaptureOrientation = DeviceOrientation.landscapeLeft;
      final CameraRecordingPipeline pipeline = build(controller: controller);

      await pipeline.openSession(zoomFactor: 0.6);

      // portraitUp's turn, not landscapeLeft's.
      expect(pipeline.currentPreview?.quarterTurns, 0);
    });

    test(
      'a STALE deviceOrientation is reported faithfully, not corrected',
      () async {
        // The exact configuration measured on a CPH2707: window landscape,
        // handset still, so the sensor never fired and deviceOrientation is
        // portraitUp. The frame must report 0 — the plugin subtracts 0 too, and
        // the pair cancels. "Correcting" this to match the window is the bug.
        final PreviewFrame? frame = await frameFor(
          DeviceOrientation.portraitUp,
        );

        expect(frame?.quarterTurns, 0);
        // And the ratio stays the camera's native one; the window flip lives in
        // CameraPreviewSurface, not here.
        expect(frame?.aspectRatio, closeTo(16 / 9, 0.0001));
      },
    );
  });

  group('ADR-054 — capture orientation is locked once, to landscapeLeft', () {
    test(
      'the lock is landscapeLeft, the constant the device verified',
      () async {
        // Not interchangeable with landscapeRight. Locked to that one on a
        // CPH2707, every clip came back with a 180-degree tkhd rotation —
        // upside-down — at display rotations 0, 1 and 3. This pins the half of
        // ADR-054 that measurement decided rather than reasoning.
        final _FakeController controller = _FakeController();
        final CameraRecordingPipeline pipeline = build(controller: controller);

        await pipeline.openSession(zoomFactor: 0.6);

        expect(controller.lockCalls, <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
        ]);
      },
    );

    test('it is locked once per session, not again per chunk', () async {
      // Chapter 5.2 §1's treatment of the zoom factor, extended: "fixed for
      // the whole session, never changed mid-recording".
      final _FakeController controller = _FakeController();
      final CameraRecordingPipeline pipeline = build(controller: controller);

      await pipeline.openSession(zoomFactor: 0.6);
      await pipeline.startChunk();
      await pipeline.stopChunk();
      await pipeline.startChunk();

      expect(controller.lockCalls, hasLength(1));
    });
  });

  group('chunk capture', () {
    test('start and stop drive the controller and return its path', () async {
      final _FakeController controller = _FakeController();
      final CameraRecordingPipeline pipeline = build(controller: controller);
      await pipeline.openSession(zoomFactor: 0.5);

      await pipeline.startChunk();
      final String path = await pipeline.stopChunk();

      expect(controller.started, 1);
      expect(controller.stopped, 1);
      expect(path, '/tmp/chunk.mp4');
    });

    test('the output directory is null until a session is open', () async {
      final CameraRecordingPipeline pipeline = build();
      expect(pipeline.outputDirectory, isNull);

      await pipeline.openSession(zoomFactor: 0.5);
      expect(pipeline.outputDirectory, '/documents/recordings');

      await pipeline.closeSession();
      expect(pipeline.outputDirectory, isNull);
    });

    test('closing disposes the controller', () async {
      final _FakeController controller = _FakeController();
      final CameraRecordingPipeline pipeline = build(controller: controller);
      await pipeline.openSession(zoomFactor: 0.5);

      await pipeline.closeSession();

      expect(controller.disposed, 1);
    });
  });

  group('the conversion boundary', () {
    test('no rear camera becomes a DeviceException', () async {
      await expectLater(
        build(cameras: <CameraDescription>[]).openSession(zoomFactor: 0.5),
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.errorCode,
            'errorCode',
            ErrorCode.deviceRearCameraAbsent,
          ),
        ),
      );
    });

    test('a failure to open converts, and no CameraException '
        'escapes', () async {
      Object? caught;
      try {
        await build(
          openThrows: CameraException('CameraAccessDenied', 'denied'),
        ).openSession(zoomFactor: 0.5);
      } on Object catch (error) {
        caught = error;
      }

      expect(caught, isA<DeviceException>());
      expect(caught, isNot(isA<CameraException>()));
    });

    test('capturing before openSession is refused, not a null crash', () async {
      await expectLater(build().startChunk(), throwsA(isA<DeviceException>()));
    });
  });
}

/// A controller that records what it was told to do.
class _FakeController implements CameraController {
  _FakeController({this.minZoom = 0.5});

  final double minZoom;
  final List<double> zoomCalls = <double>[];
  int started = 0;
  int stopped = 0;
  int disposed = 0;

  @override
  Future<double> getMinZoomLevel() async => minZoom;

  @override
  Future<void> setZoomLevel(double zoom) async => zoomCalls.add(zoom);

  /// ADR-054 decision 1. Recorded rather than swallowed, so a test can assert
  /// WHICH constant was locked — the value a CPH2707 proved matters, since
  /// `landscapeRight` produced upside-down footage.
  final List<DeviceOrientation> lockCalls = <DeviceOrientation>[];

  @override
  Future<void> lockCaptureOrientation([DeviceOrientation? orientation]) async {
    if (orientation != null) {
      lockCalls.add(orientation);
    }
  }

  @override
  Future<void> startVideoRecording({
    onLatestImageAvailable? onAvailable,
    bool enablePersistentRecording = true,
  }) async => started += 1;

  @override
  Future<XFile> stopVideoRecording() async {
    stopped += 1;
    return XFile('/tmp/chunk.mp4');
  }

  @override
  Future<void> dispose() async => disposed += 1;

  // ADR-053's seam. `openSession` now listens to the controller and reads its
  // value to publish a PreviewFrame, so those members are reachable and must
  // be faked. `value` reports uninitialized, which makes `_frameOf` return
  // null — correct for a fake with no camera behind it, and it keeps these
  // tests about capture rather than about preview.
  final List<VoidCallback> listeners = <VoidCallback>[];

  @override
  int get cameraId => 7;

  @override
  CameraValue get value {
    if (!initialised) {
      return const CameraValue.uninitialized(
        CameraDescription(
          name: 'fake',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
      );
    }
    return CameraValue(
      isInitialized: true,
      previewSize: const Size(1920, 1080),
      isRecordingVideo: false,
      isTakingPicture: false,
      isStreamingImages: false,
      isRecordingPaused: false,
      flashMode: FlashMode.off,
      exposureMode: ExposureMode.auto,
      focusMode: FocusMode.auto,
      exposurePointSupported: false,
      focusPointSupported: false,
      deviceOrientation: deviceOrientation,
      lockedCaptureOrientation: lockedCaptureOrientation,
      description: const CameraDescription(
        name: 'fake',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 0,
      ),
    );
  }

  /// Set by the invariant tests so `_frameOf` produces a real frame.
  bool initialised = false;

  /// What the platform's orientation stream last reported. **This is the value
  /// the plugin's own preview delegate subtracts**, which is why the frame must
  /// follow it and nothing else.
  DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp;

  /// Non-null once ADR-054's lock is applied. Deliberately NOT what the frame
  /// follows.
  DeviceOrientation? lockedCaptureOrientation;

  @override
  void addListener(VoidCallback listener) => listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);

  // The controller surface is large and this pipeline touches five methods.
  // Implementing the rest would be noise; anything unexpected being called is
  // a failure worth seeing loudly.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
