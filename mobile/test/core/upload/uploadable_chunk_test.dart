import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/core/upload/uploadable_chunk.dart';

/// The pipeline's projection, and the one property it must share with C-11's.
void main() {
  final DateTime earlier = DateTime.utc(2026, 8, 15, 9);
  final DateTime later = DateTime.utc(2026, 8, 15, 11);

  UploadableChunk chunk({
    required String id,
    required String session,
    required int seq,
    required DateTime startedAt,
    String? key,
  }) => UploadableChunk(
    chunkId: id,
    sessionId: session,
    sequenceIndex: seq,
    sessionStartedAt: startedAt,
    localFilePath:
        '/docs/recordings/$session/${seq.toString().padLeft(4, '0')}.mp4',
    fileSizeBytes: 1000,
    checksumSha256: 'abc',
    s3ObjectKey: key,
  );

  group('ordering matches QueuedChunk exactly', () {
    test('session start dominates sequence index', () {
      expect(
        chunk(
          id: 'a',
          session: 's1',
          seq: 9,
          startedAt: earlier,
        ).compareTo(chunk(id: 'b', session: 's2', seq: 0, startedAt: later)),
        lessThan(0),
      );
    });

    test('within a session, recording order holds', () {
      final List<UploadableChunk> queue = <UploadableChunk>[
        chunk(id: 'c', session: 's1', seq: 2, startedAt: earlier),
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
        chunk(id: 'b', session: 's1', seq: 1, startedAt: earlier),
      ]..sort();

      expect(queue.map((UploadableChunk c) => c.sequenceIndex), <int>[0, 1, 2]);
    });

    test('the chunk id tiebreak makes the order total', () {
      final UploadableChunk a = chunk(
        id: 'aaa',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );
      final UploadableChunk b = chunk(
        id: 'bbb',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );

      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(a), 0);
    });

    test('it agrees with QueuedChunk on the same rows', () {
      // Two projections over one table. If they disagreed, the chunk C-11
      // shows at the top of the queue would not be the one claimNext picks —
      // and Chapter 5.9 §2's ordering is a promise to the Collector, not an
      // internal detail.
      final List<UploadableChunk> uploadOrder = <UploadableChunk>[
        chunk(id: 'l0', session: 's2', seq: 0, startedAt: later),
        chunk(id: 'e1', session: 's1', seq: 1, startedAt: earlier),
        chunk(id: 'e0', session: 's1', seq: 0, startedAt: earlier),
      ]..sort();

      final List<QueuedChunk> queueOrder = <QueuedChunk>[
        QueuedChunk(
          chunkId: 'l0',
          sessionId: 's2',
          sequenceIndex: 0,
          sessionStartedAt: later,
          status: ChunkUploadStatus.queued,
          fileSizeBytes: 1000,
        ),
        QueuedChunk(
          chunkId: 'e1',
          sessionId: 's1',
          sequenceIndex: 1,
          sessionStartedAt: earlier,
          status: ChunkUploadStatus.queued,
          fileSizeBytes: 1000,
        ),
        QueuedChunk(
          chunkId: 'e0',
          sessionId: 's1',
          sequenceIndex: 0,
          sessionStartedAt: earlier,
          status: ChunkUploadStatus.queued,
          fileSizeBytes: 1000,
        ),
      ]..sort();

      expect(
        uploadOrder.map((UploadableChunk c) => c.chunkId),
        queueOrder.map((QueuedChunk c) => c.chunkId),
      );
    });
  });

  group('withObjectKey', () {
    test('carries the key and changes nothing else', () {
      final UploadableChunk before = chunk(
        id: 'a',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );
      final UploadableChunk after = before.withObjectKey('org/proj/key.mp4');

      expect(before.s3ObjectKey, isNull);
      expect(after.s3ObjectKey, 'org/proj/key.mp4');
      expect(after.chunkId, before.chunkId);
      expect(after.localFilePath, before.localFilePath);
      expect(after.checksumSha256, before.checksumSha256);
      expect(after.compareTo(before), 0);
    });
  });

  group('value semantics', () {
    test('same fields are equal and share a hashCode', () {
      final UploadableChunk a = chunk(
        id: 'a',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );
      final UploadableChunk b = chunk(
        id: 'a',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(<UploadableChunk>{a, b}, hasLength(1));
    });

    test('the object key is part of identity', () {
      expect(
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
        isNot(
          chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier, key: 'k'),
        ),
      );
    });

    test('toString omits the file path and the checksum', () {
      // Read in log lines. The path is long and says nothing a session id and
      // sequence index do not.
      final String text = chunk(
        id: 'chk_1',
        session: 's1',
        seq: 3,
        startedAt: earlier,
      ).toString();

      expect(text, contains('chk_1'));
      expect(text, contains('seq: 3'));
      expect(text, isNot(contains('/docs/')));
      expect(text, isNot(contains('abc')));
    });
  });

  group('taskId — F17 and B3', () {
    test('defaults to null, because most stored sessions have none', () {
      // Every session recorded before Mission 7.4 step 5, and any started
      // without a Task selected. SessionRegistrar turns that null into a
      // TERMINAL device-side failure rather than retrying it — nothing about
      // the stored row will change.
      expect(
        chunk(id: 'chk_1', session: 's1', seq: 0, startedAt: earlier).taskId,
        isNull,
      );
    });

    test('is carried when the session has one', () {
      expect(
        UploadableChunk(
          chunkId: 'chk_1',
          sessionId: 's1',
          taskId: 'tsk-1',
          sequenceIndex: 0,
          sessionStartedAt: earlier,
          localFilePath: '/docs/a.mp4',
          fileSizeBytes: 1,
          checksumSha256: 'abc',
        ).taskId,
        'tsk-1',
      );
    });
  });
}
