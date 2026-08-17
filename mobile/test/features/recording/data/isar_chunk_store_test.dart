import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/data/isar_chunk_store.dart';

/// Volume 5 Chapter 5.8 §2's file layout.
///
/// ## What is covered here, and what is not
///
/// The naming and directory rules are covered, because they are the part of
/// Chapter 5.8 §2 that is a stated requirement rather than an implementation
/// detail — the zero-padding is shared with Chapter 5.14 §1's S3 key, so a
/// drift here would show up as a mismatched remote object name.
///
/// The transaction is **not** covered by a unit test. Isar 3 needs its native
/// core, which `flutter test` does not load and which
/// `Isar.initializeIsarCore(download: true)` would fetch over the network on
/// every run — a test that needs the internet is not a test the build can
/// depend on. Atomicity is Isar's own guarantee, exercised by the mapper tests
/// on the way in and by device runs on the way out. Stated rather than
/// silently skipped.
void main() {
  group('chunkFileName — Ch. 5.8 §2s {sequence_index:04d}.mp4', () {
    test('pads to four digits', () {
      expect(IsarChunkStore.chunkFileName(0), '0000.mp4');
      expect(IsarChunkStore.chunkFileName(3), '0003.mp4');
      expect(IsarChunkStore.chunkFileName(42), '0042.mp4');
      expect(IsarChunkStore.chunkFileName(999), '0999.mp4');
    });

    test('the first chunk is 0000, matching a zero-based sequence', () {
      // Ch. 5.6 §2 and RecordingLifecycle.firstSequenceIndex both start at 0.
      // A file named 0001.mp4 for the first chunk would misalign the local
      // name from the S3 key that embeds the same index.
      expect(IsarChunkStore.chunkFileName(0), startsWith('0000'));
    });

    test('past 9999 the name grows rather than truncating', () {
      // A collision would be worse than a wider name: two chunks sharing a
      // path is data loss, an odd sort order is not. About 69 days of
      // ten-minute chunks to reach it.
      expect(IsarChunkStore.chunkFileName(10000), '10000.mp4');
    });

    test('the padding width is the one the S3 key depends on', () {
      expect(IsarChunkStore.sequenceIndexWidth, 4);
    });
  });

  group('sessionDirectoryPath', () {
    test('is <app-documents>/recordings/{session_id}', () {
      expect(
        IsarChunkStore.sessionDirectoryPath(
          documentsPath: '/data/user/0/app/files',
          sessionId: 'sess_e810',
        ),
        '/data/user/0/app/files/recordings/sess_e810',
      );
    });

    test('separates sessions, so one session cannot overwrite another', () {
      // Both sessions have a chunk 0. Only the directory keeps them apart —
      // the filename carries no session component.
      final String first = IsarChunkStore.sessionDirectoryPath(
        documentsPath: '/docs',
        sessionId: 'sess_a',
      );
      final String second = IsarChunkStore.sessionDirectoryPath(
        documentsPath: '/docs',
        sessionId: 'sess_b',
      );

      expect(first, isNot(second));
      expect(
        '$first/${IsarChunkStore.chunkFileName(0)}',
        isNot('$second/${IsarChunkStore.chunkFileName(0)}'),
      );
    });

    test('uses the directory name Ch. 5.8 §2 states', () {
      expect(IsarChunkStore.recordingsDirectory, 'recordings');
    });
  });
}
