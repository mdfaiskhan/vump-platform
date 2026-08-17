import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/upload/domain/entities/upload_batch_progress.dart';

void main() {
  group('UploadBatchProgress', () {
    test('starts idle, with nothing to show', () {
      const UploadBatchProgress batch = UploadBatchProgress.idle;

      expect(batch.total, 0);
      expect(batch.remaining, 0);
      expect(batch.done, 0);
      expect(batch.isIdle, isTrue);
    });

    test('the first observation fixes the denominator', () {
      final UploadBatchProgress batch = UploadBatchProgress.idle.observe(5);

      expect(batch.total, 5);
      expect(batch.remaining, 5);
      expect(batch.position, 1);
      expect(batch.notificationText, 'Uploading 1 of 5 chunks.');
    });

    test('the denominator holds steady while chunks finish — Ch. 5.11 §1', () {
      // The whole reason this type carries memory. A Collector must see
      // "1 of 5" become "2 of 5", never "1 of 5" become "1 of 4".
      UploadBatchProgress batch = UploadBatchProgress.idle.observe(5);
      final List<String> shown = <String>[batch.notificationText];

      for (final int outstanding in <int>[4, 3, 2, 1]) {
        batch = batch.observe(outstanding);
        shown.add(batch.notificationText);
      }

      expect(shown, <String>[
        'Uploading 1 of 5 chunks.',
        'Uploading 2 of 5 chunks.',
        'Uploading 3 of 5 chunks.',
        'Uploading 4 of 5 chunks.',
        'Uploading 5 of 5 chunks.',
      ]);
    });

    test('a chunk arriving mid-batch joins it rather than starting one', () {
      // FR-UPL-04 lets a later session record while an earlier one uploads, so
      // this is the normal case, not an edge one.
      UploadBatchProgress batch = UploadBatchProgress.idle.observe(5);
      batch = batch.observe(4);
      expect(batch.notificationText, 'Uploading 2 of 5 chunks.');

      batch = batch.observe(5);

      expect(batch.total, 6, reason: 'the new chunk widens the batch');
      expect(batch.notificationText, 'Uploading 2 of 6 chunks.');
    });

    test('draining returns to idle, which is what ends the batch', () {
      UploadBatchProgress batch = UploadBatchProgress.idle.observe(3);
      batch = batch.observe(0);

      expect(batch, same(UploadBatchProgress.idle));
      expect(batch.isIdle, isTrue);
    });

    test('a new batch after a drain starts its own count', () {
      UploadBatchProgress batch = UploadBatchProgress.idle.observe(5);
      batch = batch.observe(0);
      batch = batch.observe(2);

      expect(batch.total, 2, reason: 'the previous batch does not carry over');
      expect(batch.notificationText, 'Uploading 1 of 2 chunks.');
    });

    test('a single chunk is not announced as "1 of 1 chunks"', () {
      // Ch. 2.9 §3 requires copy a Collector does not have to decode.
      final UploadBatchProgress batch = UploadBatchProgress.idle.observe(1);

      expect(batch.notificationText, 'Uploading 1 chunk.');
    });

    test('idle names the state rather than showing a bare zero', () {
      expect(
        UploadBatchProgress.idle.notificationText,
        'No chunks are waiting to upload.',
      );
    });

    test('position never exceeds the total', () {
      // A drained batch must not claim to be working on a chunk that is done.
      final UploadBatchProgress batch = UploadBatchProgress.idle
          .observe(2)
          .observe(0);

      expect(batch.position, lessThanOrEqualTo(batch.total));
    });

    test('a negative observation is treated as drained, not as work', () {
      expect(UploadBatchProgress.idle.observe(-1), UploadBatchProgress.idle);
    });

    test('equality is by value, so a repeated emission is not a change', () {
      // The dispatcher pushes this onto a notification. Two equal batches must
      // compare equal or every emission would look like new progress.
      expect(
        UploadBatchProgress.idle.observe(4),
        UploadBatchProgress.idle.observe(4),
      );
      expect(
        UploadBatchProgress.idle.observe(4).hashCode,
        UploadBatchProgress.idle.observe(4).hashCode,
      );
    });
  });
}
