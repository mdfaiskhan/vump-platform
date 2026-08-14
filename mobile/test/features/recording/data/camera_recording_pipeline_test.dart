import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/data/camera_recording_pipeline.dart';

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
      await expectLater(
        build().startChunk(),
        throwsA(isA<DeviceException>()),
      );
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

  // The controller surface is large and this pipeline touches five methods.
  // Implementing the rest would be noise; anything unexpected being called is
  // a failure worth seeing loudly.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
