import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/queued_chunk.dart';

/// Volume 5 Chapter 5.9 §2's ordering, as a comparator.
///
/// The assertion this file exists for is the one about **retry**: the chapter
/// requires a retried chunk to re-enter at its original position, and that is
/// only true for free if position is derived rather than stored. These tests
/// are what pin that.
void main() {
  final DateTime earlier = DateTime.utc(2026, 8, 15, 9);
  final DateTime later = DateTime.utc(2026, 8, 15, 11);

  QueuedChunk chunk({
    required String id,
    required String session,
    required int seq,
    required DateTime startedAt,
    ChunkUploadStatus status = ChunkUploadStatus.queued,
  }) => QueuedChunk(
    chunkId: id,
    sessionId: session,
    sequenceIndex: seq,
    sessionStartedAt: startedAt,
    status: status,
    fileSizeBytes: 1000,
  );

  group('FIFO by session start time, then sequence index', () {
    test('an earlier session sorts ahead of a later one', () {
      // "an earlier session's chunks are not starved by a later session's"
      final QueuedChunk first = chunk(
        id: 'a',
        session: 's1',
        seq: 9,
        startedAt: earlier,
      );
      final QueuedChunk second = chunk(
        id: 'b',
        session: 's2',
        seq: 0,
        startedAt: later,
      );

      expect(first.compareTo(second), lessThan(0));
      // Note the sequence indices: 9 before 0. Session time dominates.
    });

    test('within one session, recording order holds', () {
      final List<QueuedChunk> queue = <QueuedChunk>[
        chunk(id: 'c', session: 's1', seq: 2, startedAt: earlier),
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
        chunk(id: 'b', session: 's1', seq: 1, startedAt: earlier),
      ]..sort();

      expect(
        queue.map((QueuedChunk c) => c.sequenceIndex),
        <int>[0, 1, 2],
      );
    });

    test('a full two-session queue sorts as the chapter describes', () {
      final List<QueuedChunk> queue = <QueuedChunk>[
        chunk(id: 'l1', session: 's2', seq: 1, startedAt: later),
        chunk(id: 'e0', session: 's1', seq: 0, startedAt: earlier),
        chunk(id: 'l0', session: 's2', seq: 0, startedAt: later),
        chunk(id: 'e1', session: 's1', seq: 1, startedAt: earlier),
      ]..sort();

      expect(
        queue.map((QueuedChunk c) => c.chunkId),
        <String>['e0', 'e1', 'l0', 'l1'],
      );
    });

    test('the order is total, so sorting is stable across emissions', () {
      // Without the chunkId tiebreak two rows could compare equal, and a
      // re-sort could then reorder the list between stream emissions for no
      // visible reason.
      final QueuedChunk a = chunk(
        id: 'aaa',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );
      final QueuedChunk b = chunk(
        id: 'bbb',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );

      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(a), 0);
    });
  });

  group('FR-UPL-07 — a retried chunk keeps its position', () {
    test('changing status does not change where it sorts', () {
      // The chapter: "re-enters the queue at its original position, not
      // pushed to the back". Nothing stores a position, so nothing can put
      // one back wrongly - status is simply not part of the comparison.
      final QueuedChunk queued = chunk(
        id: 'b',
        session: 's1',
        seq: 1,
        startedAt: earlier,
      );
      final QueuedChunk failed = chunk(
        id: 'b',
        session: 's1',
        seq: 1,
        startedAt: earlier,
        status: ChunkUploadStatus.failed,
      );

      final List<QueuedChunk> others = <QueuedChunk>[
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
        chunk(id: 'c', session: 's1', seq: 2, startedAt: earlier),
      ];

      final List<QueuedChunk> withQueued = <QueuedChunk>[...others, queued]
        ..sort();
      final List<QueuedChunk> withFailed = <QueuedChunk>[...others, failed]
        ..sort();

      expect(withQueued.indexOf(queued), 1);
      expect(withFailed.indexOf(failed), 1, reason: 'same slot, any status');
    });

    test('every status sorts identically', () {
      final List<int> positions = <int>[];
      for (final ChunkUploadStatus status in ChunkUploadStatus.values) {
        final QueuedChunk subject = chunk(
          id: 'b',
          session: 's1',
          seq: 1,
          startedAt: earlier,
          status: status,
        );
        final List<QueuedChunk> queue = <QueuedChunk>[
          chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
          subject,
          chunk(id: 'c', session: 's1', seq: 2, startedAt: earlier),
        ]..sort();
        positions.add(queue.indexOf(subject));
      }

      expect(positions, everyElement(1));
    });
  });

  group('value semantics', () {
    test('two rows with the same fields are equal', () {
      expect(
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
      );
    });

    test('equal values share a hashCode', () {
      // Equality is load-bearing: the stream emits whole lists, and a
      // consumer deduplicating on value needs hashCode to agree with ==.
      final QueuedChunk a = chunk(
        id: 'a',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );
      final QueuedChunk b = chunk(
        id: 'a',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );

      expect(a.hashCode, b.hashCode);
      expect(<QueuedChunk>{a, b}, hasLength(1));
    });

    test('a differing field changes the hashCode', () {
      final QueuedChunk a = chunk(
        id: 'a',
        session: 's1',
        seq: 0,
        startedAt: earlier,
      );
      final QueuedChunk b = chunk(
        id: 'a',
        session: 's1',
        seq: 1,
        startedAt: earlier,
      );

      expect(a.hashCode, isNot(b.hashCode));
    });

    test('toString names the chunk, its position and its state', () {
      // Read in test failures and log lines; a bare Instance of would make
      // an ordering failure unreadable.
      final String text = chunk(
        id: 'chk_1',
        session: 's1',
        seq: 3,
        startedAt: earlier,
      ).toString();

      expect(text, contains('chk_1'));
      expect(text, contains('3'));
      expect(text, contains('queued'));
    });

    test('a status change makes it a different value', () {
      // The stream emits whole lists; without this, a status-only change
      // could compare equal and be dropped as "no change".
      expect(
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
        isNot(
          chunk(
            id: 'a',
            session: 's1',
            seq: 0,
            startedAt: earlier,
            status: ChunkUploadStatus.failed,
          ),
        ),
      );
    });
  });
}
