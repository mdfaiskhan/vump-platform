import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/data/chunk_record_mapper.dart';
import 'package:mobile/features/recording/data/collections/local_chunk.dart';
import 'package:mobile/features/recording/data/collections/local_chunk_metadata.dart';
import 'package:mobile/features/recording/data/collections/local_session.dart';
import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/collector_authored.dart';
import 'package:mobile/features/recording/domain/entities/gps_fix.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';
import 'package:mobile/features/recording/domain/entities/metadata_device_context.dart';
import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';
import 'package:mobile/features/recording/domain/entities/metadata_timing.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';

/// The conversion boundary ADR-030 requires: domain in, Isar rows out.
///
/// These run without a database. Constructing a collection object is plain
/// Dart — only opening one needs the native engine — so the mapping itself is
/// testable in `flutter test`, which is where the interesting assertions are:
/// that the seven groups survive as groups, that absence stays absence, and
/// that nothing is invented for a field with no source.
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
    filePath: '/plugin/cache/REC_9182.mp4',
    startedAt: endedAt,
  );

  const ChunkIntegrity integrity = ChunkIntegrity(
    checksumSha256:
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    byteCount: 512000000,
  );

  ChunkMetadata metadataWith({
    MetadataCaptureConditions conditions =
        MetadataCaptureConditions.unavailable,
    CollectorAuthored authored = CollectorAuthored.empty,
  }) => ChunkMetadata(
    chunkId: 'chk_5b2a',
    identity: const MetadataIdentity(
      sessionId: 'sess_e810',
      projectId: 'proj_1',
      taskId: 'task_1',
      collectorId: 'coll_1',
      deviceId: 'dev_1',
    ),
    timing: MetadataTiming(
      sequenceIndex: 3,
      startedAt: startedAt,
      endedAt: endedAt,
    ),
    capture: const MetadataCapture(
      resolution: '1920x1080',
      frameRate: 30,
      bitrateKbps: 8000,
      codec: 'h264',
      zoomFactor: 0.6,
      camera: 'rear-wide',
    ),
    deviceContext: const MetadataDeviceContext(
      deviceModel: 'CPH2707',
      osVersion: 'Android 15',
      appVersion: '0.1.0+1',
    ),
    captureConditions: conditions,
    integrity: integrity,
    collectorAuthored: authored,
  );

  group('the session row', () {
    test('carries the UUID, not Isars surrogate key', () {
      final LocalSession row = ChunkRecordMapper.toLocalSession(session);

      expect(row.sessionId, 'sess_e810');
      expect(row.startedAt, startedAt);
    });

    test('starts in_progress — Volume 4s vocabulary, FR-SES-02', () {
      expect(
        ChunkRecordMapper.toLocalSession(session).status,
        ChunkRecordMapper.sessionInProgress,
      );
    });

    test('task_id and project_id come from the session — F38', () {
      // This row is the DURABILITY BOUNDARY for Task context: the upload queue
      // reads taskId from it at claim time, long after the recording ended and
      // across any number of relaunches. If the mapper drops it, nothing else
      // remembers.
      final LocalSession row = ChunkRecordMapper.toLocalSession(
        session.copyWith(taskId: 'tsk-1', projectId: 'prj-1'),
      );

      expect(row.taskId, 'tsk-1');
      expect(row.projectId, 'prj-1');
    });

    test('a session with no Task writes nulls, not placeholders', () {
      // A-062's argument, unchanged: null is the honest value, and a
      // placeholder would be indexed, uploaded and indistinguishable from a
      // real id.
      final LocalSession row = ChunkRecordMapper.toLocalSession(session);

      expect(row.taskId, isNull);
      expect(row.projectId, isNull);
    });

    test('collector_id stays null, and that is not a gap', () {
      // The backend derives the collector from the verified token on every
      // route (Chapter 4.8), so nothing reads this column.
      expect(ChunkRecordMapper.toLocalSession(session).collectorId, isNull);
    });
  });

  group('the chunk row', () {
    LocalChunk chunk() => ChunkRecordMapper.toLocalChunk(
      job: job,
      session: session,
      metadata: metadataWith(),
      localFilePath: '/docs/recordings/sess_e810/0003.mp4',
    );

    test('reuses the chunk_id minted at capture-stop — Ch. 5.13 §4', () {
      // Never regenerated: BR-11s duplicate prevention depends on a retry
      // reusing the exact same id.
      expect(chunk().chunkId, job.chunkId);
    });

    test('is queued — the state BR-07 hands to the Upload Queue', () {
      expect(chunk().status, ChunkRecordMapper.statusQueued);
    });

    test('copies integrity rather than restating it', () {
      // Volume 4s chunks table carries both columns in its own right so the
      // Upload Queue can read them without loading metadata. One source,
      // two columns — they cannot disagree.
      expect(chunk().checksumSha256, integrity.checksumSha256);
      expect(chunk().fileSizeBytes, integrity.byteCount);
    });

    test('stores the placed path, not the path the plugin wrote', () {
      expect(chunk().localFilePath, '/docs/recordings/sess_e810/0003.mp4');
      expect(chunk().localFilePath, isNot(job.filePath));
    });

    test('leaves s3_object_key null rather than composing a fake one', () {
      // Ch. 5.14 §1s key needs org_id, project_id and task_id. None exist.
      expect(chunk().s3ObjectKey, isNull);
    });

    test('local_deleted_at is untouched — BR-08 is Ch. 5.15s to enforce', () {
      expect(chunk().localDeletedAt, isNull);
    });
  });

  group('the metadata row keeps Ch. 4.5s seven groups', () {
    test('every group is present and nested, not flattened', () {
      final LocalChunkMetadata row = ChunkRecordMapper.toLocalMetadata(
        metadataWith(),
      );

      expect(row.chunkId, 'chk_5b2a');
      expect(row.identity, isNotNull);
      expect(row.timing, isNotNull);
      expect(row.capture, isNotNull);
      expect(row.deviceContext, isNotNull);
      expect(row.captureConditions, isNotNull);
      expect(row.integrity, isNotNull);
      expect(row.collectorAuthored, isNotNull);
    });

    test('identity survives field for field', () {
      final LocalChunkMetadata row = ChunkRecordMapper.toLocalMetadata(
        metadataWith(),
      );

      expect(row.identity?.sessionId, 'sess_e810');
      expect(row.identity?.projectId, 'proj_1');
      expect(row.identity?.taskId, 'task_1');
      expect(row.identity?.collectorId, 'coll_1');
      expect(row.identity?.deviceId, 'dev_1');
    });

    test('duration_seconds is not stored — it is derived', () {
      // Storing it would let a row disagree with the timestamps it comes
      // from. EmbeddedTiming has no such field, and this asserts the two
      // timestamps that replace it.
      final LocalChunkMetadata row = ChunkRecordMapper.toLocalMetadata(
        metadataWith(),
      );

      expect(row.timing?.startedAt, startedAt);
      expect(row.timing?.endedAt, endedAt);
      expect(metadataWith().timing.durationSeconds, 600);
    });

    test('capture stores the wire codec spelling', () {
      final LocalChunkMetadata row = ChunkRecordMapper.toLocalMetadata(
        metadataWith(),
      );

      expect(row.capture?.codec, 'h264');
      expect(row.capture?.zoomFactor, 0.6);
    });
  });

  group('absence stays absence', () {
    test('no GPS fix stores nulls, never (0, 0)', () {
      // Isar cannot represent an absent embedded object, so the absence has
      // to live in the fields. (0, 0) is a real place in the Gulf of Guinea.
      final LocalChunkMetadata row = ChunkRecordMapper.toLocalMetadata(
        metadataWith(),
      );

      expect(row.captureConditions?.gps, isNotNull);
      expect(row.captureConditions?.gps?.latitude, isNull);
      expect(row.captureConditions?.gps?.longitude, isNull);
    });

    test('a real fix is stored as itself', () {
      final LocalChunkMetadata row = ChunkRecordMapper.toLocalMetadata(
        metadataWith(
          conditions: const MetadataCaptureConditions(
            gps: GpsFix(latitude: 12.5, longitude: -8.25),
            batteryPercent: 71,
            networkType: 'wifi',
          ),
        ),
      );

      expect(row.captureConditions?.gps?.latitude, 12.5);
      expect(row.captureConditions?.gps?.longitude, -8.25);
      expect(row.captureConditions?.batteryPercent, 71);
      expect(row.captureConditions?.networkType, 'wifi');
    });

    test('unread conditions stay null rather than defaulting', () {
      final LocalChunkMetadata row = ChunkRecordMapper.toLocalMetadata(
        metadataWith(),
      );

      expect(row.captureConditions?.batteryPercent, isNull);
      expect(row.captureConditions?.networkType, isNull);
    });

    test('collector_authored is empty at generation — Ch. 5.7 §2', () {
      final LocalChunkMetadata row = ChunkRecordMapper.toLocalMetadata(
        metadataWith(),
      );

      expect(row.collectorAuthored?.notes, isNull);
      expect(row.collectorAuthored?.tags, isEmpty);
    });

    test('its tags are copied, so the row cannot alias the domain list', () {
      // Ch. 4.5 §4 makes this the only mutable group. Phase 2 will write it,
      // and a shared list would let a later edit reach into a stored row.
      final ChunkMetadata metadata = metadataWith(
        authored: const CollectorAuthored(tags: <String>['a']),
      );
      final LocalChunkMetadata row = ChunkRecordMapper.toLocalMetadata(
        metadata,
      );

      expect(row.collectorAuthored?.tags, <String>['a']);
      expect(
        row.collectorAuthored?.tags,
        isNot(same(metadata.collectorAuthored.tags)),
      );
    });
  });
}
