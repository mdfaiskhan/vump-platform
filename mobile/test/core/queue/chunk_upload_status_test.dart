import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/features/recording/data/chunk_record_mapper.dart';

/// Volume 5 Chapter 5.9 §1's four states, and the one string that must not
/// drift.
void main() {
  group('the vocabulary is Chapter 5.9 §1s, exactly', () {
    test('there are four states and no more', () {
      // The chapter enumerates Queued, Uploading, Failed, Complete and says
      // they are "identical to the backend's chunks.status". A fifth would be
      // a vocabulary this side invented alone.
      expect(ChunkUploadStatus.values, hasLength(4));
    });

    test('each wire name matches Volume 4s spelling', () {
      expect(ChunkUploadStatus.queued.wireName, 'queued');
      expect(ChunkUploadStatus.uploading.wireName, 'uploading');
      expect(ChunkUploadStatus.failed.wireName, 'failed');
      expect(ChunkUploadStatus.complete.wireName, 'complete');
    });

    test('no two states share a wire name', () {
      final Set<String> names = ChunkUploadStatus.values
          .map((ChunkUploadStatus s) => s.wireName)
          .toSet();

      expect(names, hasLength(ChunkUploadStatus.values.length));
    });
  });

  group('THE PIN — core/ and features/recording/ agree on "queued"', () {
    test('ChunkUploadStatus.queued matches ChunkRecordMapper.statusQueued', () {
      // ChunkRecordMapper has written this string into local_chunks.status
      // since Mission 3.7, and rows produced then exist on real devices.
      //
      // Two constants now spell the same value in two layers, because
      // changing the Mission 3 one would touch the verified capture path.
      // This test is what makes that safe: rename either and the build fails
      // here rather than silently orphaning every stored row from the queue
      // that has to read them.
      expect(ChunkUploadStatus.queued.wireName, ChunkRecordMapper.statusQueued);
    });
  });

  group('fromWireName refuses to guess', () {
    test('every known string round-trips', () {
      for (final ChunkUploadStatus status in ChunkUploadStatus.values) {
        expect(ChunkUploadStatus.fromWireName(status.wireName), status);
      }
    });

    test('an unknown string is null, not defaulted to queued', () {
      // Defaulting would hand an unrecognised row to a dispatcher as if it
      // were ready to upload — the worst available guess.
      expect(ChunkUploadStatus.fromWireName('in_progress'), isNull);
      expect(ChunkUploadStatus.fromWireName('QUEUED'), isNull);
      expect(ChunkUploadStatus.fromWireName(''), isNull);
      expect(ChunkUploadStatus.fromWireName(null), isNull);
    });

    test('a session status is not a chunk status', () {
      // local_sessions.status carries in_progress/complete. They share the
      // word "complete", which is exactly why this is worth pinning: reading
      // the session column as an upload signal is the mistake Mission 3's
      // handoff warns about.
      expect(
        ChunkUploadStatus.fromWireName(ChunkRecordMapper.sessionInProgress),
        isNull,
      );
    });
  });

  group('the two derived questions', () {
    test('only queued is claimable by a dispatcher', () {
      for (final ChunkUploadStatus status in ChunkUploadStatus.values) {
        expect(
          status.isClaimable,
          status == ChunkUploadStatus.queued,
          reason: status.name,
        );
      }
    });

    test('only failed is retryable', () {
      for (final ChunkUploadStatus status in ChunkUploadStatus.values) {
        expect(
          status.isRetryable,
          status == ChunkUploadStatus.failed,
          reason: status.name,
        );
      }
    });
  });
}
