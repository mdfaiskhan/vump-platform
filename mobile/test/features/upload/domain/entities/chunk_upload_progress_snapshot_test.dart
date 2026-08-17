import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/upload/domain/entities/chunk_upload_progress_snapshot.dart';

/// C-11's live percentage, and the honesty rules around it.
void main() {
  ChunkUploadProgressSnapshot snap(int sent, int total) =>
      ChunkUploadProgressSnapshot(sentBytes: sent, totalBytes: total);

  group('a known total gives a determinate percentage', () {
    test('reports the fraction and the whole percent', () {
      final ChunkUploadProgressSnapshot s = snap(250, 1000);

      expect(s.isDeterminate, isTrue);
      expect(s.fraction, 0.25);
      expect(s.percent, 25);
    });

    test('floors rather than rounds', () {
      // Chapter 2.9 §2 principle 2: the Collector "should never have to wonder
      // if it worked". A bar reading 100% while bytes are still moving is the
      // small lie that principle exists to prevent.
      expect(snap(999, 1000).percent, 99);
      expect(snap(1, 1000).percent, 0);
    });

    test('reaches 100 only when it is actually done', () {
      expect(snap(1000, 1000).percent, 100);
    });

    test('clamps a total that was under-reported', () {
      // Dio can report more sent than expected on a retried part.
      expect(snap(1200, 1000).fraction, 1.0);
      expect(snap(1200, 1000).percent, 100);
    });
  });

  group('an unknown total is indeterminate, never zero', () {
    test('a negative total reports no percentage', () {
      // Dio uses -1 for a stream whose length it cannot determine. Treating
      // that as 0% would claim progress information the transfer does not have.
      final ChunkUploadProgressSnapshot s = snap(500, -1);

      expect(s.isDeterminate, isFalse);
      expect(s.fraction, isNull);
      expect(s.percent, isNull);
    });

    test('a zero total is also unknown, not complete', () {
      final ChunkUploadProgressSnapshot s = snap(0, 0);

      expect(s.isDeterminate, isFalse);
      expect(s.percent, isNull);
    });
  });

  group('value semantics', () {
    test('equal snapshots compare equal, so a repeat is not a change', () {
      expect(snap(10, 100), snap(10, 100));
      expect(snap(10, 100).hashCode, snap(10, 100).hashCode);
    });

    test('a different byte count is a different value', () {
      expect(snap(10, 100), isNot(snap(11, 100)));
    });

    test('toString names both counters', () {
      expect(snap(10, 100).toString(), contains('10/100'));
    });
  });
}
