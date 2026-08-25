// Doubles for the pre-recording checklist and the recording pipeline behind
// it, extracted from `pre_recording_checklist_screen_test.dart` at Mission 8.1
// so a second test can drive the same screen without a second copy.
//
// **A pure move.** No behaviour changed; the classes lost their leading
// underscore because they are imported now, and nothing else.
//
// The project already keeps eleven `test/**/fakes/` files for this reason. A
// duplicated double is worse than a shared one in a specific way: the two
// drift, and the test that drifts is the one nobody was reading.

import 'dart:async';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/domain/entities/camera_capability.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/cleanable_chunk.dart';
import 'package:mobile/features/recording/domain/entities/device_fingerprint.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';
import 'package:mobile/features/recording/domain/entities/preview_frame.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_tier.dart';
import 'package:mobile/features/recording/domain/repositories/battery_reader.dart';
import 'package:mobile/features/recording/domain/repositories/camera_capability_probe.dart';
import 'package:mobile/features/recording/domain/repositories/camera_permission_probe.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_finalizer.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_id_generator.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_store.dart';
import 'package:mobile/features/recording/domain/repositories/free_space_reader.dart';
import 'package:mobile/features/recording/domain/repositories/network_reader.dart';
import 'package:mobile/features/recording/domain/repositories/recording_pipeline.dart';
import 'package:mobile/features/recording/domain/repositories/session_id_generator.dart';
import 'package:mobile/features/recording/domain/repositories/wide_angle_eligibility_cache.dart';

/// A timer that never schedules anything.
class NoopTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}

class FakePermissionProbe implements CameraPermissionProbe {
  const FakePermissionProbe([this._gate]);

  final Completer<void>? _gate;

  @override
  Future<void> verify() async {
    if (_gate != null) {
      await _gate.future;
    }
  }
}

class FakeFreeSpace implements FreeSpaceReader {
  const FakeFreeSpace();
  @override
  Future<int> availableBytes(String path) async => 50 * 1000 * 1000 * 1000;
}

class FakeBattery implements BatteryReader {
  const FakeBattery();
  @override
  Future<int> percent() async => 90;
}

class FakeNetwork implements NetworkReader {
  const FakeNetwork();
  @override
  Future<NetworkType> current() async => NetworkType.wifi;
}

class FakeCache implements WideAngleEligibilityCache {
  const FakeCache();
  @override
  Future<WideAngleTier?> read(DeviceFingerprint fingerprint) async => null;
  @override
  Future<void> write({
    required WideAngleTier tier,
    required DeviceFingerprint fingerprint,
  }) async {}
  @override
  Future<void> clear() async {}
}

class FakeProbe implements CameraCapabilityProbe {
  const FakeProbe();
  @override
  Future<CameraCapability> probe() async => const CameraCapability(
    hasRearCamera: true,
    hasDedicatedUltraWide: null,
    minimumZoomFactor: 0.6,
  );
}

/// Records the order the pipeline is driven in.
class FakePipeline implements RecordingPipeline {
  FakePipeline({this.failStartChunk = false});

  /// ADR-053's seam. Tests that care drive it with [emitPreview]; the rest
  /// never look, and a null preview is the honest default for a fake that
  /// owns no camera.
  final StreamController<PreviewFrame?> previewController =
      StreamController<PreviewFrame?>.broadcast();
  PreviewFrame? preview;

  @override
  Stream<PreviewFrame?> get previewChanges => previewController.stream;

  @override
  PreviewFrame? get currentPreview => preview;

  /// Publishes a frame and records it as current, as the real pipeline does.
  void emitPreview(PreviewFrame? frame) {
    preview = frame;
    previewController.add(frame);
  }

  final bool failStartChunk;
  final List<String> calls = <String>[];

  @override
  String? get outputDirectory => null;

  /// Migration 0017. Null: this fake owns no camera, so it has no orientation
  /// to report, and saying otherwise would make the fake claim more than the
  /// thing it stands in for.
  @override
  String? get captureOrientation => null;

  @override
  Future<void> openSession({required double zoomFactor}) async {
    calls.add('openSession');
  }

  @override
  Future<void> startChunk() async {
    calls.add('startChunk');
    if (failStartChunk) {
      throw const DeviceException(
        errorCode: ErrorCode.deviceCameraUnavailable,
        message: 'capture could not begin',
      );
    }
  }

  @override
  Future<String> stopChunk() async => '/chunk.mp4';

  @override
  Future<void> closeSession() async {}
}

class FixedIds implements SessionIdGenerator, ChunkIdGenerator {
  const FixedIds();
  @override
  String newSessionId() => 'sess_widget_1';
  @override
  String newChunkId() => 'chk_widget_1';
}

class FakeFinalizer implements ChunkFinalizer {
  const FakeFinalizer();
  @override
  Future<void> finalizeChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required DateTime chunkStartedAt,
  }) async {}
}

class FakeStore implements ChunkStore {
  const FakeStore();
  @override
  Future<void> saveChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkMetadata metadata,
  }) async {}
  @override
  Future<void> markSessionComplete(String sessionId) async {}
  @override
  Future<List<String>> recoverableChunkIds() async => <String>[];
  @override
  Future<List<String>> orphanedChunkIds() async => <String>[];

  @override
  Future<List<CleanableChunk>> cleanableChunks({required int limit}) async =>
      <CleanableChunk>[];

  @override
  Future<bool> deleteChunkFile(String chunkId) async => false;
}
