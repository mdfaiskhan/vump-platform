import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/upload/application/upload_queue_notifier.dart';
import 'package:mobile/features/upload/presentation/collector_sessions_screen.dart';

/// C-11's two session-level strings, tested as pure functions.
///
/// They are top-level rather than private methods so the Today/Yesterday
/// boundary and the summary's wording can be asserted without pumping a widget
/// — the boundary is arithmetic and deserves arithmetic's test, not a render.
void main() {
  QueuedChunk chunk(
    ChunkUploadStatus status, {
    required DateTime startedAt,
    int seq = 0,
  }) => QueuedChunk(
    chunkId: 'c$seq-$status',
    sessionId: 's1',
    sequenceIndex: seq,
    sessionStartedAt: startedAt,
    status: status,
    fileSizeBytes: 1000,
  );

  UploadQueueSession sessionOf(
    List<ChunkUploadStatus> statuses, {
    DateTime? startedAt,
  }) {
    final DateTime start = startedAt ?? DateTime(2026, 8, 16, 9, 5);
    return UploadQueueSession(
      sessionId: 's1',
      chunks: <QueuedChunk>[
        for (int i = 0; i < statuses.length; i++)
          chunk(statuses[i], startedAt: start, seq: i),
      ],
    );
  }

  group('sessionHeading — when, not which UUID', () {
    test('a session recorded today reads Today and the time', () {
      final DateTime now = DateTime(2026, 8, 16, 18);
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.queued,
      ], startedAt: DateTime(2026, 8, 16, 9, 5));

      expect(sessionHeading(session, now), 'Today 09:05');
    });

    test('the previous calendar day reads Yesterday', () {
      final DateTime now = DateTime(2026, 8, 16, 9);
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.queued,
      ], startedAt: DateTime(2026, 8, 15, 14, 30));

      expect(sessionHeading(session, now), 'Yesterday 14:30');
    });

    test('Yesterday is a calendar boundary, not a 24-hour window', () {
      // Recorded at 23:50, read at 00:10 the next day: twenty minutes apart,
      // and a person calls that yesterday. Counting elapsed hours would call
      // it today for another 23 hours.
      final DateTime now = DateTime(2026, 8, 16, 0, 10);
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.queued,
      ], startedAt: DateTime(2026, 8, 15, 23, 50));

      expect(sessionHeading(session, now), 'Yesterday 23:50');
    });

    test('older than that reads an absolute date', () {
      final DateTime now = DateTime(2026, 8, 16, 9);
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.queued,
      ], startedAt: DateTime(2026, 8, 3, 7, 15));

      expect(sessionHeading(session, now), '3 Aug 07:15');
    });

    test('times are zero-padded on both halves', () {
      final DateTime now = DateTime(2026, 8, 16, 23);
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.queued,
      ], startedAt: DateTime(2026, 8, 16, 6, 4));

      expect(sessionHeading(session, now), 'Today 06:04');
    });

    test('the boundary is the local day on BOTH sides', () {
      // The bug this guards was in the first draft: `sessionStartedAt` was
      // converted with toLocal() and `now` was not, which put the boundary at
      // UTC midnight instead of the Collector's. Invisible in a UTC-only test
      // and wrong by a whole day for anyone far enough east or west.
      //
      // Passing a UTC instant and its own local rendering must agree, because
      // they are the same moment.
      final DateTime utcNow = DateTime.utc(2026, 8, 16, 9);
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.queued,
      ], startedAt: DateTime.utc(2026, 8, 16, 9));

      expect(sessionHeading(session, utcNow), startsWith('Today '));
      expect(
        sessionHeading(session, utcNow),
        sessionHeading(session, utcNow.toLocal()),
      );
    });
  });

  group('sessionSummary — counts, with no invented denominator', () {
    test('it names each non-zero state', () {
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.complete,
        ChunkUploadStatus.complete,
        ChunkUploadStatus.uploading,
        ChunkUploadStatus.queued,
      ]);

      expect(session.summaryOrNull, '2 uploaded · 1 uploading · 1 waiting');
    });

    test('zero states are omitted rather than printed as 0', () {
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.queued,
      ]);

      expect(session.summaryOrNull, '1 waiting');
    });

    test('it states no total, because the queue does not know one', () {
      // Cleanup soft-deletes completed chunks and the queue excludes them
      // (open item 61), so a session's rows shrink as housekeeping runs.
      // "2 of 5 uploaded" would state a denominator this screen cannot know.
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.complete,
        ChunkUploadStatus.queued,
      ]);

      expect(session.summaryOrNull, isNot(contains(' of ')));
      expect(session.summaryOrNull, '1 uploaded · 1 waiting');
    });

    test('a failure is always named, and named last', () {
      // Ch. 2.9 §4.1 forbids a failure that is not visible. A summary reading
      // only "3 uploaded" while a chunk was stuck would be exactly that.
      final UploadQueueSession session = sessionOf(<ChunkUploadStatus>[
        ChunkUploadStatus.complete,
        ChunkUploadStatus.complete,
        ChunkUploadStatus.complete,
        ChunkUploadStatus.failed,
      ]);

      expect(session.summaryOrNull, '3 uploaded · 1 needs attention');
      expect(session.summaryOrNull, endsWith('needs attention'));
    });
  });
}

extension on UploadQueueSession {
  /// Reads through to the screen's pure helper, for brevity in assertions.
  String get summaryOrNull => sessionSummary(this);
}
