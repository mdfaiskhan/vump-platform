import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app/config/app_environment.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/features/recording/application/storage_cleanup_sweep.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/cleanable_chunk.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/storage_sweep_result.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_store.dart';

import '../../../core/time/fakes/fake_clock.dart';

/// Volume 5 Chapter 5.15's sweep, driven through its store.
///
/// This file tests the sweep's **policy** — when it runs, how much it takes,
/// what it reports. It cannot test the deletion itself: `IsarChunkStore` needs
/// a native Isar the test host does not have, so the file-unlink half is
/// verified on a device instead (open item 58).
void main() {
  late _FakeChunkStore store;
  late FakeClock clock;

  StorageCleanupSweep build({int batchSize = 10}) => StorageCleanupSweep(
    store: store,
    clock: clock,
    logger: AppLogger(environment: AppEnvironment.production),
    batchSize: batchSize,
  );

  setUp(() {
    store = _FakeChunkStore();
    clock = FakeClock();
  });

  group('the interval is derived from the chunk period', () {
    test('defaults to one chunk boundary', () {
      // Not a chosen number: a completion cannot arrive faster than a chunk is
      // produced, so one sweep per chunk period keeps pace by construction.
      expect(
        StorageCleanupSweep.defaultInterval,
        RecordingLifecycle.chunkDuration,
      );
    });

    test('sweeps once at startup, before any tick', () async {
      store.eligible = <CleanableChunk>[_chunk('a')];

      build().start();
      await pumpEventQueue();

      expect(store.deleted, <String>['a']);
    });

    test('and again on every interval', () async {
      final StorageCleanupSweep sweep = build();
      sweep.start();
      await pumpEventQueue();

      store.eligible = <CleanableChunk>[_chunk('b')];
      clock.advance(RecordingLifecycle.chunkDuration);
      await pumpEventQueue();

      expect(store.deleted, <String>['b']);
    });

    test('stop() ends the schedule', () async {
      final StorageCleanupSweep sweep = build();
      sweep.start();
      await pumpEventQueue();
      await sweep.stop();

      store.eligible = <CleanableChunk>[_chunk('c')];
      clock.advance(RecordingLifecycle.chunkDuration * 3);
      await pumpEventQueue();

      expect(store.deleted, isEmpty);
    });

    test('start is idempotent', () async {
      final StorageCleanupSweep sweep = build()..start();
      sweep.start();
      await pumpEventQueue();

      expect(store.readCalls, 1);
    });
  });

  group('batching — §2 avoids competing with the Recording Pipeline', () {
    test('takes at most the batch size', () async {
      store.eligible = <CleanableChunk>[
        for (int i = 0; i < 25; i++) _chunk('c$i'),
      ];

      await build(batchSize: 10).sweep();

      expect(store.deleted, hasLength(10));
    });

    test('asks for one more than the batch, to see if work remains', () async {
      store.eligible = <CleanableChunk>[
        for (int i = 0; i < 25; i++) _chunk('c$i'),
      ];

      final StorageSweepResult result = await build(batchSize: 10).sweep();

      expect(store.lastLimit, 11, reason: 'batch + 1, not a second query');
      expect(result.moreRemaining, isTrue);
    });

    test('reports no more remaining when the batch was not filled', () async {
      store.eligible = <CleanableChunk>[_chunk('a'), _chunk('b')];

      final StorageSweepResult result = await build(batchSize: 10).sweep();

      expect(result.moreRemaining, isFalse);
      expect(result.filesDeleted, 2);
    });

    test('a batch of zero is rejected', () {
      expect(() => build(batchSize: 0), throwsA(isA<AssertionError>()));
    });
  });

  group('reporting', () {
    test('sums the recorded sizes of what it deleted', () async {
      store.eligible = <CleanableChunk>[
        _chunk('a', bytes: 100),
        _chunk('b', bytes: 250),
      ];

      final StorageSweepResult result = await build().sweep();

      expect(result.filesDeleted, 2);
      expect(result.bytesReclaimed, 350);
    });

    test('an empty queue is idle, and does no work', () async {
      final StorageSweepResult result = await build().sweep();

      expect(result, StorageSweepResult.idle);
      expect(result.didWork, isFalse);
    });

    test('a chunk that was no longer eligible counts as an orphan', () async {
      store.eligible = <CleanableChunk>[_chunk('a'), _chunk('gone')];
      store.refuse.add('gone');

      final StorageSweepResult result = await build().sweep();

      expect(result.filesDeleted, 1);
      expect(result.orphansFound, 1);
    });
  });

  group('failure isolation — BR-08 fails safe', () {
    test('one failing chunk does not strand the rest of the batch', () async {
      store.eligible = <CleanableChunk>[
        _chunk('a'),
        _chunk('bad'),
        _chunk('c'),
      ];
      store.throwOn.add('bad');

      final StorageSweepResult result = await build().sweep();

      expect(store.deleted, <String>['a', 'c']);
      expect(result.failures, 1);
      expect(result.filesDeleted, 2);
    });

    test('a store that cannot be read leaves everything alone', () async {
      store.throwOnRead = true;

      final StorageSweepResult result = await build().sweep();

      expect(result, StorageSweepResult.idle);
      expect(store.deleted, isEmpty);
    });

    test('a read failure does not stop later sweeps', () async {
      final StorageCleanupSweep sweep = build();
      store.throwOnRead = true;
      sweep.start();
      await pumpEventQueue();

      store
        ..throwOnRead = false
        ..eligible = <CleanableChunk>[_chunk('a')];
      clock.advance(RecordingLifecycle.chunkDuration);
      await pumpEventQueue();

      expect(store.deleted, <String>['a']);
    });
  });

  group('a second sweep over cleaned rows', () {
    test('deletes nothing and reports nothing — no double count', () async {
      // The device probe checks the same property against real files; this is
      // the policy half of it.
      store.eligible = <CleanableChunk>[_chunk('a'), _chunk('b')];
      final StorageSweepResult first = await build().sweep();

      final StorageSweepResult second = await build().sweep();

      expect(first.filesDeleted, 2);
      expect(second, StorageSweepResult.idle);
      expect(store.deleted, <String>['a', 'b'], reason: 'each deleted once');
    });
  });
}

CleanableChunk _chunk(String id, {int bytes = 10}) => CleanableChunk(
  chunkId: id,
  localFilePath: '/tmp/$id',
  fileSizeBytes: bytes,
);

/// A store that hands out eligible chunks and records what was deleted.
///
/// It removes a chunk from [eligible] when it is deleted, so a second sweep
/// sees what a real store would.
class _FakeChunkStore implements ChunkStore {
  List<CleanableChunk> eligible = <CleanableChunk>[];
  final List<String> deleted = <String>[];
  final Set<String> throwOn = <String>{};
  final Set<String> refuse = <String>{};

  bool throwOnRead = false;
  int readCalls = 0;
  int? lastLimit;

  @override
  Future<List<CleanableChunk>> cleanableChunks({required int limit}) async {
    readCalls += 1;
    lastLimit = limit;
    if (throwOnRead) {
      throw StateError('scripted read failure');
    }
    return eligible.take(limit).toList();
  }

  @override
  Future<bool> deleteChunkFile(String chunkId) async {
    if (throwOn.contains(chunkId)) {
      throw StateError('scripted delete failure');
    }
    eligible = eligible
        .where((CleanableChunk c) => c.chunkId != chunkId)
        .toList();
    if (refuse.contains(chunkId)) {
      return false;
    }
    deleted.add(chunkId);
    return true;
  }

  @override
  Future<List<String>> orphanedChunkIds() async => <String>[];

  @override
  Future<List<String>> recoverableChunkIds() async => <String>[];

  @override
  Future<void> markSessionComplete(String sessionId) async {}

  @override
  Future<void> saveChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkMetadata metadata,
  }) async {}
}
