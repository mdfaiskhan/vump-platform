import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/identity/interfaces/device_context.dart';
import 'package:mobile/core/identity/interfaces/task_context.dart';
import 'package:mobile/features/recording/data/chunk_metadata_assembler.dart';
import 'package:mobile/features/recording/data/codec_wire_name.dart';
import 'package:mobile/features/recording/data/platform_device_context.dart';
import 'package:mobile/features/recording/data/unsourced_task_context.dart';
import 'package:mobile/features/recording/domain/entities/camera_specification.dart';
import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/gps_fix.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/repositories/capture_conditions_reader.dart';

/// Volume 4 Chapter 4.5's schema, assembled from Chapter 5.7 §2's sources.
///
/// The assertions worth having are the ones about **incompleteness**: this
/// mission can source twelve of twenty-one fields, and the object it produces
/// must say so rather than looking finished.
void main() {
  final DateTime startedAt = DateTime.utc(2026, 8, 15, 9);
  final DateTime endedAt = startedAt.add(const Duration(minutes: 10));

  final RecordingSession session = RecordingSession(
    sessionId: 'sess_e810',
    zoomFactor: 0.6,
    startedAt: startedAt,
  );

  final ChunkProcessingJob job = ChunkProcessingJob(
    chunkId: 'chk_5b2a',
    sequenceIndex: 3,
    filePath: '/recordings/sess_e810/0003.mp4',
    startedAt: endedAt,
  );

  const ChunkIntegrity integrity = ChunkIntegrity(
    checksumSha256:
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    byteCount: 512000000,
  );

  Future<ChunkMetadata> assemble({
    MetadataCaptureConditions conditions =
        MetadataCaptureConditions.unavailable,
    TaskContext taskContext = const _FakeTask(),
    DeviceContext deviceContext = const _FakeDevice(),
  }) =>
      ChunkMetadataAssembler(
        taskContext: taskContext,
        deviceContext: deviceContext,
        conditionsReader: _FakeConditions(conditions),
      ).generate(
        session: session,
        job: job,
        integrity: integrity,
        chunkStartedAt: startedAt,
      );

  group('sourced fields — traced to Ch. 5.7 §2', () {
    test('chunk_id comes from the job, minted at capture-stop', () async {
      expect((await assemble()).chunkId, 'chk_5b2a');
    });

    test('identity.session_id comes from the session', () async {
      expect((await assemble()).identity.sessionId, 'sess_e810');
    });

    test('timing comes from capture, not from processing', () async {
      // Both timestamps are fixed at capture-stop (Mission 3.4.5), so they
      // describe the recording rather than when hashing finished.
      final ChunkMetadata m = await assemble();

      expect(m.timing.sequenceIndex, 3);
      expect(m.timing.startedAt, startedAt);
      expect(m.timing.endedAt, endedAt);
    });

    test('duration_seconds is derived, matching Ch. 4.5s example', () async {
      // The schema's worked example shows 600 for a full chunk.
      expect((await assemble()).timing.durationSeconds, 600);
    });

    test('capture mirrors CameraSpecification, not literals', () async {
      final ChunkMetadata m = await assemble();

      expect(m.capture.resolution, '1920x1080');
      expect(m.capture.frameRate, CameraSpecification.frameRate);
      expect(m.capture.bitrateKbps, CameraSpecification.targetVideoBitrateKbps);
      expect(m.capture.camera, 'rear-wide');
    });

    test(
      'capture.zoom_factor is the ladder verdict, not the default',
      () async {
        // 0.6 is what the CPH2707 actually resolved to. A metadata object that
        // reported 0.5 because that is the specification's first value would
        // misdescribe the footage.
        expect((await assemble()).capture.zoomFactor, 0.6);
        expect(
          (await assemble()).capture.zoomFactor,
          isNot(CameraSpecification.zoomFactorOptical),
        );
      },
    );

    test('integrity is Mission 3.4s object, unmodified', () async {
      final ChunkMetadata m = await assemble();

      expect(m.integrity, same(integrity));
      expect(m.integrity.byteCount, 512000000);
      expect(m.integrity.checksumSha256, hasLength(64));
    });

    test('os_version is read from the platform', () async {
      expect(
        (await assemble()).deviceContext.osVersion,
        Platform.operatingSystemVersion,
      );
    });

    test('collector_authored is empty at generation — Ch. 5.7 §2', () async {
      final ChunkMetadata m = await assemble();

      expect(m.collectorAuthored.notes, isNull);
      expect(m.collectorAuthored.tags, isEmpty);
    });
  });

  group('the codec boundary mapping', () {
    test('the spec says H.264 and the wire says h264', () async {
      // Ch. 5.2 §1 describes an encoder; Ch. 4.5 §2 fixes a JSON value. Both
      // are right for their own side, so the difference is translated here.
      expect(CameraSpecification.videoCodec, 'H.264');
      expect((await assemble()).capture.codec, 'h264');
    });

    test('an unknown codec passes through rather than failing', () {
      expect(CodecWireName.forSpecification('H.265'), 'h265');
      expect(CodecWireName.forSpecification('AV1'), 'av1');
    });
  });

  group('incompleteness is visible, not silent', () {
    test('conditions are absent today, and the object admits it', () async {
      final ChunkMetadata m = await assemble();

      expect(m.captureConditions.gps, isNull);
      expect(m.captureConditions.batteryPercent, isNull);
      expect(m.captureConditions.networkType, isNull);
      expect(m.captureConditions.isEmpty, isTrue);
      expect(
        m.isComplete,
        isFalse,
        reason: 'a consumer can detect this without inspecting fields',
      );
    });

    test('the group is present in the shape, not omitted', () async {
      // Omitting it would make an incomplete object structurally
      // indistinguishable from a complete one on the wire.
      expect((await assemble()).captureConditions, isNotNull);
    });

    test('nothing defaults to a plausible wrong value', () async {
      // {"lat": 0.0, "lng": 0.0} is a real place in the Gulf of Guinea, and
      // far harder to notice than an obvious null.
      final ChunkMetadata m = await assemble();

      expect(m.captureConditions.gps?.latitude, isNot(0.0));
      expect(m.captureConditions.batteryPercent, isNot(0));
    });

    test('a complete reading reports complete', () async {
      // Proves isComplete tracks the data rather than being hardcoded false.
      //
      // Mission 3.8 redefined isComplete as `captureConditions.isComplete &&
      // identity.isComplete`. This case satisfies BOTH halves — the fakes
      // supply real ids — so it still means what it says. The two cases below
      // pin the half it no longer covers on its own.
      final ChunkMetadata m = await assemble(
        conditions: const MetadataCaptureConditions(
          gps: GpsFix(latitude: 51.5, longitude: -0.12),
          batteryPercent: 82,
          networkType: 'wifi',
        ),
      );

      expect(m.captureConditions.isComplete, isTrue);
      expect(m.identity.isComplete, isTrue);
      expect(m.isComplete, isTrue);
    });

    test(
      'complete conditions with an unsourced identity is NOT complete',
      () async {
        // The half Mission 3.8 added, and the half the fakes hid: before 3.10
        // this file only ever varied captureConditions, so `isComplete` passed
        // on identity by accident. These are the production stand-ins, so this
        // is what the application actually assembles today.
        final ChunkMetadata m = await assemble(
          conditions: const MetadataCaptureConditions(
            gps: GpsFix(latitude: 51.5, longitude: -0.12),
            batteryPercent: 82,
            networkType: 'wifi',
          ),
          taskContext: const UnsourcedTaskContext(),
          deviceContext: const PlatformDeviceContext(appVersion: '1.0.0+1'),
        );

        expect(
          m.captureConditions.isComplete,
          isTrue,
          reason: 'one half holds',
        );
        expect(m.identity.isComplete, isFalse, reason: 'the other does not');
        expect(m.isComplete, isFalse);
        expect(m.isIdentityComplete, isFalse);
      },
    );

    test('isIdentityComplete is what must gate upload — A-064 §3', () async {
      // Ch. 5.14 §1's S3 key embeds project_id, task_id and session_id, so
      // Ch. 5.10's registration must check this before composing one. A
      // consumer asking `isComplete` alone would conflate a missing GPS fix
      // with an unattributable chunk.
      final ChunkMetadata sourced = await assemble();
      final ChunkMetadata unsourced = await assemble(
        taskContext: const UnsourcedTaskContext(),
        deviceContext: const PlatformDeviceContext(appVersion: '1.0.0+1'),
      );

      expect(sourced.isIdentityComplete, isTrue);
      expect(unsourced.isIdentityComplete, isFalse);
      expect(
        sourced.isComplete,
        isFalse,
        reason: 'still false, but for conditions — not identity',
      );
    });

    test('a partial reading is not complete', () async {
      final ChunkMetadata m = await assemble(
        conditions: const MetadataCaptureConditions(
          batteryPercent: 82,
          networkType: 'wifi',
        ),
      );

      expect(m.captureConditions.isComplete, isFalse);
      expect(m.captureConditions.isEmpty, isFalse);
    });
  });

  group('conditions are read at finalization, per Ch. 5.7 §2', () {
    test('the reader is consulted once per chunk', () async {
      final _FakeConditions reader = _FakeConditions(
        MetadataCaptureConditions.unavailable,
      );

      await ChunkMetadataAssembler(
        taskContext: const _FakeTask(),
        deviceContext: const _FakeDevice(),
        conditionsReader: reader,
      ).generate(
        session: session,
        job: job,
        integrity: integrity,
        chunkStartedAt: startedAt,
      );

      expect(reader.reads, 1);
    });
  });
}

class _FakeTask implements TaskContext {
  const _FakeTask();
  @override
  String get projectId => 'proj_4a1';
  @override
  String get taskId => 'task_7c3';
}

class _FakeDevice implements DeviceContext {
  const _FakeDevice();
  @override
  String get collectorId => 'user_9f2';
  @override
  String get deviceId => 'device_abc';
  @override
  String get deviceModel => 'CPH2707';
  @override
  String get appVersion => '1.0.0+1';
}

class _FakeConditions implements CaptureConditionsReader {
  _FakeConditions(this._value);
  final MetadataCaptureConditions _value;
  int reads = 0;

  @override
  Future<MetadataCaptureConditions> read() async {
    reads += 1;
    return _value;
  }
}
