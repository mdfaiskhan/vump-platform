import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/features/recording/application/finalize_chunk_use_case.dart';
import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/cleanable_chunk.dart';
import 'package:mobile/features/recording/domain/entities/collector_authored.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';
import 'package:mobile/features/recording/domain/entities/metadata_device_context.dart';
import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';
import 'package:mobile/features/recording/domain/entities/metadata_timing.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_store.dart';
import 'package:mobile/features/recording/domain/repositories/metadata_generator.dart';
import 'package:mobile/features/recording/domain/repositories/video_processor.dart';

/// The three chapters joined — Ch. 5.5, Ch. 5.7 and Ch. 5.8.
///
/// What is only observable here is the **composition**: the order the ports
/// run in, that each one's output reaches the next, and that a failure is not
/// swallowed. The pieces themselves are tested in their own files.
void main() {
  final DateTime chunkStartedAt = DateTime.utc(2026, 8, 15, 9);
  final DateTime captureEndedAt = chunkStartedAt.add(
    const Duration(minutes: 10),
  );

  final RecordingSession session = RecordingSession(
    sessionId: 'sess_1',
    zoomFactor: 0.6,
    startedAt: chunkStartedAt,
  );
  final ChunkProcessingJob job = ChunkProcessingJob(
    chunkId: 'chk_1',
    sequenceIndex: 0,
    filePath: '/plugin/cache/REC_1.mp4',
    startedAt: captureEndedAt,
  );

  const ChunkIntegrity integrity = ChunkIntegrity(
    checksumSha256:
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    byteCount: 512000000,
  );

  test('the ports run in Ch. 5.5 -> 5.7 -> 5.8 order', () async {
    // The order is forced, not chosen: integrity is one of Ch. 4.5's seven
    // groups, and the store needs the metadata to pair with the chunk row.
    final List<String> calls = <String>[];
    final _RecordingProcessor processor = _RecordingProcessor(calls, integrity);
    final _RecordingGenerator generator = _RecordingGenerator(calls);
    final _RecordingStore store = _RecordingStore(calls);

    await FinalizeChunkUseCase(
      videoProcessor: processor,
      metadataGenerator: generator,
      chunkStore: store,
    ).finalizeChunk(session: session, job: job, chunkStartedAt: chunkStartedAt);

    expect(calls, <String>['process', 'generate', 'save']);
  });

  test('the checksum reaches the generator', () async {
    final _RecordingGenerator generator = _RecordingGenerator(<String>[]);

    await FinalizeChunkUseCase(
      videoProcessor: _RecordingProcessor(<String>[], integrity),
      metadataGenerator: generator,
      chunkStore: _RecordingStore(<String>[]),
    ).finalizeChunk(session: session, job: job, chunkStartedAt: chunkStartedAt);

    expect(generator.received?.checksumSha256, integrity.checksumSha256);
    expect(generator.received?.byteCount, 512000000);
  });

  test('the file processed is the one the job names', () async {
    final _RecordingProcessor processor = _RecordingProcessor(
      <String>[],
      integrity,
    );

    await FinalizeChunkUseCase(
      videoProcessor: processor,
      metadataGenerator: _RecordingGenerator(<String>[]),
      chunkStore: _RecordingStore(<String>[]),
    ).finalizeChunk(session: session, job: job, chunkStartedAt: chunkStartedAt);

    // Since Mission 3.4.5 this runs while the *next* chunk may be recording,
    // so the pipeline can no longer be asked which file is meant.
    expect(processor.path, '/plugin/cache/REC_1.mp4');
  });

  group('chunkStartedAt is capture-start, not the jobs own timestamp', () {
    test('the generator receives the chunks real start', () async {
      final _RecordingGenerator generator = _RecordingGenerator(<String>[]);

      await FinalizeChunkUseCase(
        videoProcessor: _RecordingProcessor(<String>[], integrity),
        metadataGenerator: generator,
        chunkStore: _RecordingStore(<String>[]),
      ).finalizeChunk(
        session: session,
        job: job,
        chunkStartedAt: chunkStartedAt,
      );

      expect(generator.startedAt, chunkStartedAt);
    });

    test('passing the jobs timestamp instead would report zero seconds', () {
      // The defect this parameter exists to prevent, stated as an assertion so
      // nobody re-collapses the two. `job.startedAt` is when capture STOPPED.
      final MetadataTiming wrong = MetadataTiming(
        sequenceIndex: 0,
        startedAt: job.startedAt,
        endedAt: job.startedAt,
      );
      final MetadataTiming right = MetadataTiming(
        sequenceIndex: 0,
        startedAt: chunkStartedAt,
        endedAt: job.startedAt,
      );

      expect(wrong.durationSeconds, 0);
      expect(right.durationSeconds, 600);
    });
  });

  group('failures propagate — the notifier owns the response', () {
    test('a checksum failure reaches the caller and skips the store', () async {
      final _RecordingStore store = _RecordingStore(<String>[]);

      await expectLater(
        FinalizeChunkUseCase(
          videoProcessor: _ThrowingProcessor(),
          metadataGenerator: _RecordingGenerator(<String>[]),
          chunkStore: store,
        ).finalizeChunk(
          session: session,
          job: job,
          chunkStartedAt: chunkStartedAt,
        ),
        throwsA(isA<StorageException>()),
      );

      // FR-META-09 in the negative: nothing is written when the metadata that
      // must accompany it could not be produced.
      expect(store.saved, 0);
    });

    test('a store failure is not swallowed', () async {
      await expectLater(
        FinalizeChunkUseCase(
          videoProcessor: _RecordingProcessor(<String>[], integrity),
          metadataGenerator: _RecordingGenerator(<String>[]),
          chunkStore: _ThrowingStore(),
        ).finalizeChunk(
          session: session,
          job: job,
          chunkStartedAt: chunkStartedAt,
        ),
        throwsA(
          isA<StorageException>().having(
            (StorageException e) => e.errorCode,
            'errorCode',
            ErrorCode.storageWriteFailed,
          ),
        ),
      );
    });
  });
}

class _RecordingProcessor implements VideoProcessor {
  _RecordingProcessor(this.calls, this.result);

  final List<String> calls;
  final ChunkIntegrity result;
  String? path;

  @override
  Future<ChunkIntegrity> process(String path) async {
    calls.add('process');
    this.path = path;
    return result;
  }
}

class _ThrowingProcessor implements VideoProcessor {
  @override
  Future<ChunkIntegrity> process(String path) async =>
      throw const StorageException(
        errorCode: ErrorCode.storageReadFailed,
        message: 'unreadable',
      );
}

class _RecordingGenerator implements MetadataGenerator {
  _RecordingGenerator(this.calls);

  final List<String> calls;
  ChunkIntegrity? received;
  DateTime? startedAt;

  @override
  Future<ChunkMetadata> generate({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkIntegrity integrity,
    required DateTime chunkStartedAt,
  }) async {
    calls.add('generate');
    received = integrity;
    startedAt = chunkStartedAt;
    return ChunkMetadata(
      chunkId: job.chunkId,
      identity: const MetadataIdentity(
        sessionId: 'sess_1',
        projectId: MetadataIdentity.unsourced,
        taskId: MetadataIdentity.unsourced,
        collectorId: MetadataIdentity.unsourced,
        deviceId: MetadataIdentity.unsourced,
      ),
      timing: MetadataTiming(
        sequenceIndex: job.sequenceIndex,
        startedAt: chunkStartedAt,
        endedAt: job.startedAt,
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
        deviceModel: MetadataIdentity.unsourced,
        osVersion: 'Android 16',
        appVersion: '0.1.0+1',
      ),
      captureConditions: MetadataCaptureConditions.unavailable,
      integrity: integrity,
      collectorAuthored: CollectorAuthored.empty,
    );
  }
}

class _RecordingStore implements ChunkStore {
  _RecordingStore(this.calls);

  final List<String> calls;
  int saved = 0;

  @override
  Future<void> saveChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkMetadata metadata,
  }) async {
    calls.add('save');
    saved += 1;
  }

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

class _ThrowingStore implements ChunkStore {
  @override
  Future<void> saveChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkMetadata metadata,
  }) async => throw const StorageException(
    errorCode: ErrorCode.storageWriteFailed,
    message: 'disk full',
  );

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
