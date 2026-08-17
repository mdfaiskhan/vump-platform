import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/upload/metadata/chunk_metadata_document.dart';
import 'package:mobile/features/recording/data/chunk_metadata_document_mapper.dart';
import 'package:mobile/features/recording/data/chunk_record_mapper.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_capture.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_capture_conditions.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_collector_authored.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_device_context.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_gps_fix.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_identity.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_integrity.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_timing.dart';
import 'package:mobile/features/recording/data/collections/local_chunk_metadata.dart';

/// The read-back `ChunkRecordMapper` declined to write, and why it is safe.
///
/// That class left `fromLocal*` unwritten because a reverse mapper *"would
/// have to substitute empty strings, and an empty `collector_id` that reached
/// an upload would be indistinguishable from a real one"*. These tests are the
/// evidence that this mapper substitutes nothing.
void main() {
  LocalChunkMetadata row({
    String chunkId = 'chk_1',
    EmbeddedIdentity? identity,
    bool withGroups = true,
  }) {
    final LocalChunkMetadata record = LocalChunkMetadata()..chunkId = chunkId;
    if (!withGroups) {
      return record;
    }
    return record
      ..identity =
          identity ??
          (EmbeddedIdentity()
            ..sessionId = 'sess_e810'
            ..projectId = 'proj_4a1'
            ..taskId = 'task_7c3'
            ..collectorId = 'user_22b'
            ..deviceId = 'dev_5f0')
      ..timing = (EmbeddedTiming()
        ..sequenceIndex = 3
        ..startedAt = DateTime.utc(2026, 8, 15, 9)
        ..endedAt = DateTime.utc(2026, 8, 15, 9, 10))
      ..capture = (EmbeddedCapture()
        ..resolution = '1920x1080'
        ..frameRate = 30
        ..bitrateKbps = 8000
        ..codec = 'h264'
        ..zoomFactor = 0.6
        ..camera = 'rear-wide')
      ..deviceContext = (EmbeddedDeviceContext()
        ..deviceModel = 'Pixel 6a'
        ..osVersion = 'Android 15'
        ..appVersion = '1.0.0+1')
      ..captureConditions = (EmbeddedCaptureConditions()
        ..gps = EmbeddedGpsFix()
        ..batteryPercent = null
        ..networkType = null)
      ..integrity = (EmbeddedIntegrity()
        ..byteCount = 512000000
        ..checksumSha256 = 'abc123')
      ..collectorAuthored = (EmbeddedCollectorAuthored()..tags = <String>[]);
  }

  group('nothing is substituted', () {
    test('a blank identity field stays blank, and fails the guard', () {
      // ChunkRecordMapper writes MetadataIdentity.unsourced — the empty string
      // — not null. This is the shape of every chunk on a real device.
      final ChunkMetadataDocument document =
          ChunkMetadataDocumentMapper.fromLocal(
            row(
              identity: EmbeddedIdentity()
                ..sessionId = 'sess_e810'
                ..projectId = ''
                ..taskId = ''
                ..collectorId = ''
                ..deviceId = '',
            ),
          );

      expect(document.identity.collectorId, '');
      expect(document.isIdentityComplete, isFalse);
      expect(document.identity.missingFields, <String>[
        'project_id',
        'task_id',
        'collector_id',
        'device_id',
      ]);
    });

    test('a null identity field stays null, and fails the guard', () {
      final ChunkMetadataDocument document =
          ChunkMetadataDocumentMapper.fromLocal(
            row(identity: EmbeddedIdentity()..sessionId = 'sess_e810'),
          );

      expect(document.identity.collectorId, isNull);
      expect(document.isIdentityComplete, isFalse);
    });

    test('a wholly missing group produces nulls, not defaults or a throw', () {
      final ChunkMetadataDocument document =
          ChunkMetadataDocumentMapper.fromLocal(row(withGroups: false));

      expect(document.chunkId, 'chk_1');
      expect(document.identity.sessionId, isNull);
      expect(document.timing.sequenceIndex, isNull);
      expect(document.integrity.checksumSha256, isNull);
      expect(document.collectorAuthored.tags, isEmpty);
      expect(document.isIdentityComplete, isFalse);
    });
  });

  group('every group round-trips', () {
    test('a complete row maps to a complete document', () {
      final ChunkMetadataDocument document =
          ChunkMetadataDocumentMapper.fromLocal(row());

      expect(document.isIdentityComplete, isTrue);
      expect(document.timing.sequenceIndex, 3);
      expect(document.timing.durationSeconds, 600);
      expect(document.capture.zoomFactor, 0.6);
      expect(document.deviceContext.deviceModel, 'Pixel 6a');
      expect(document.integrity.fileSizeBytes, 512000000);
      expect(document.integrity.checksumSha256, 'abc123');
    });

    test('byteCount maps onto file_size_bytes', () {
      // The stored column and the wire field have different names; Volume 4
      // Chapter 4.5 §2 fixes the wire one.
      final Map<String, Object?> json = ChunkMetadataDocumentMapper.fromLocal(
        row(),
      ).toJson();

      expect(
        (json['integrity']! as Map<String, Object?>)['file_size_bytes'],
        512000000,
      );
    });

    test('a stored GPS object with null coordinates reads as no fix', () {
      // Isar cannot represent an absent embedded object, so ChunkRecordMapper
      // writes a present EmbeddedGpsFix with both coordinates null. Reading
      // back, "the object exists" says nothing — only the coordinates do.
      final ChunkMetadataDocument document =
          ChunkMetadataDocumentMapper.fromLocal(row());

      expect(document.captureConditions.hasFix, isFalse);
      expect(document.captureConditions.latitude, isNull);
    });

    test('a stored fix reads back as one', () {
      final LocalChunkMetadata record = row()
        ..captureConditions = (EmbeddedCaptureConditions()
          ..gps = (EmbeddedGpsFix()
            ..latitude = 12.5
            ..longitude = -3.25)
          ..batteryPercent = 82
          ..networkType = 'wifi');

      final ChunkMetadataDocument document =
          ChunkMetadataDocumentMapper.fromLocal(record);

      expect(document.captureConditions.hasFix, isTrue);
      expect(document.captureConditions.latitude, 12.5);
      expect(document.captureConditions.batteryPercent, 82);
    });

    test('the tag list is copied, not aliased', () {
      // The row is a mutable Isar object; the document is meant to be a stable
      // snapshot of what will be sent.
      final EmbeddedCollectorAuthored group = EmbeddedCollectorAuthored()
        ..tags = <String>['one'];
      final ChunkMetadataDocument document =
          ChunkMetadataDocumentMapper.fromLocal(
            row()..collectorAuthored = group,
          );

      group.tags.add('two');

      expect(document.collectorAuthored.tags, <String>['one']);
    });
  });

  test(
    'the status constant Mission 3.7 writes is still the queue vocabulary',
    () {
      // Two constants, one string. A rename in either would orphan stored rows
      // from the pipeline that has to claim them.
      expect(ChunkRecordMapper.statusQueued, 'queued');
    },
  );
}
