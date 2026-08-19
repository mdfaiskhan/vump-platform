import 'dart:io' show Platform;

import 'package:mobile/core/identity/interfaces/device_context.dart';
import 'package:mobile/core/identity/interfaces/task_context.dart';
import 'package:mobile/features/recording/data/codec_wire_name.dart';
import 'package:mobile/features/recording/domain/entities/camera_specification.dart';
import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';
import 'package:mobile/features/recording/domain/entities/metadata_device_context.dart';
import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';
import 'package:mobile/features/recording/domain/entities/metadata_timing.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/repositories/capture_conditions_reader.dart';
import 'package:mobile/features/recording/domain/repositories/metadata_generator.dart';

/// Builds Chapter 4.5's metadata object from the sources Chapter 5.7 §2 names.
///
/// ## Every field, and where it comes from
///
/// ```text
/// chunk_id                    ChunkProcessingJob.chunkId          3.4.5
/// identity.session_id         RecordingSession.sessionId          3.2
/// identity.project_id         TaskContext                         port
/// identity.task_id            TaskContext                         port
/// identity.collector_id       DeviceContext                       port
/// identity.device_id          DeviceContext                       port
/// timing.sequence_index       ChunkProcessingJob.sequenceIndex    3.4.5
/// timing.started_at           chunkStartedAt (Recording state)    3.4.5
/// timing.ended_at             ChunkProcessingJob.startedAt        3.4.5
/// timing.duration_seconds     derived from the two above
/// capture.resolution          CameraSpecification w x h           3.1
/// capture.frame_rate          CameraSpecification.frameRate       3.1
/// capture.bitrate_kbps        CameraSpecification target bitrate  3.1
/// capture.codec               CodecWireName, H.264 -> h264        3.6
/// capture.zoom_factor         RecordingSession.zoomFactor         3.1/3.2
/// capture.camera              rear-wide, from BR-01 and BR-02
/// device_context.device_model DeviceContext                       port
/// device_context.os_version   Platform.operatingSystemVersion
/// device_context.app_version  DeviceContext, AppInfo inverted     port
/// capture_conditions.*        CaptureConditionsReader             port
/// integrity.*                 ChunkIntegrity                      3.4
/// collector_authored          empty, per Ch. 5.7 §2
/// ```
///
/// Twelve of the twenty-one are sourced today. The rest arrive through ports
/// with no implementation, so this assembles a **structurally complete and
/// factually incomplete** object — which [ChunkMetadata.isComplete] reports
/// rather than leaving to inspection.
class ChunkMetadataAssembler implements MetadataGenerator {
  /// Creates an assembler over its context ports.
  const ChunkMetadataAssembler({
    required TaskContext taskContext,
    required DeviceContext deviceContext,
    required CaptureConditionsReader conditionsReader,
  }) : _task = taskContext,
       _device = deviceContext,
       _conditions = conditionsReader;

  final TaskContext _task;
  final DeviceContext _device;
  final CaptureConditionsReader _conditions;

  /// `capture.camera` — constant for every chunk this application produces.
  ///
  /// BR-01 fixes the rear camera and BR-02 the wide-angle field of view, so
  /// there is no device on which this could be anything else.
  static const String cameraDescriptor = 'rear-wide';

  @override
  Future<ChunkMetadata> generate({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkIntegrity integrity,
    required DateTime chunkStartedAt,
  }) async {
    // Read first: Ch. 5.7 §2 wants these "at the moment of chunk
    // finalization", which is now — not whenever the object is handed on.
    final MetadataCaptureConditions conditions = await _conditions.read();

    return ChunkMetadata(
      chunkId: job.chunkId,
      identity: MetadataIdentity(
        sessionId: session.sessionId,
        projectId: _task.projectId,
        taskId: _task.taskId,
        collectorId: _device.collectorId,
        deviceId: _device.deviceId,
      ),
      timing: MetadataTiming(
        sequenceIndex: job.sequenceIndex,
        startedAt: chunkStartedAt,
        endedAt: job.startedAt,
      ),
      capture: MetadataCapture(
        resolution:
            '${CameraSpecification.widthPixels}x'
            '${CameraSpecification.heightPixels}',
        frameRate: CameraSpecification.frameRate,
        bitrateKbps: CameraSpecification.targetVideoBitrateKbps,
        codec: CodecWireName.forSpecification(CameraSpecification.videoCodec),
        zoomFactor: session.zoomFactor,
        camera: cameraDescriptor,
      ),
      deviceContext: MetadataDeviceContext(
        deviceModel: _device.deviceModel,
        osVersion: Platform.operatingSystemVersion,
        appVersion: _device.appVersion,
      ),
      captureConditions: conditions,
      integrity: integrity,
    );
  }
}
