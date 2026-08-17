import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/recording/domain/entities/storage_sweep_result.dart';

/// What one Chapter 5.15 sweep reports, and why it reports at all.
void main() {
  group('idle', () {
    test('is the normal outcome and did no work', () {
      expect(StorageSweepResult.idle.filesDeleted, 0);
      expect(StorageSweepResult.idle.bytesReclaimed, 0);
      expect(StorageSweepResult.idle.orphansFound, 0);
      expect(StorageSweepResult.idle.failures, 0);
      expect(StorageSweepResult.idle.moreRemaining, isFalse);
      expect(StorageSweepResult.idle.didWork, isFalse);
    });
  });

  group('didWork separates "nothing to do" from "nothing happened"', () {
    test('a deletion is work', () {
      const StorageSweepResult r = StorageSweepResult(filesDeleted: 1);

      expect(r.didWork, isTrue);
    });

    test('a failure is also work — it is the case worth logging', () {
      // BR-08 makes the two failure modes asymmetric: space not reclaimed is
      // a leak, space reclaimed early is data loss. A sweep that tried and
      // failed must not look like a sweep that found nothing.
      const StorageSweepResult r = StorageSweepResult(failures: 1);

      expect(r.didWork, isTrue);
    });

    test('an orphan alone is not work — nothing was deleted', () {
      const StorageSweepResult r = StorageSweepResult(orphansFound: 3);

      expect(r.didWork, isFalse);
    });
  });

  group('value semantics', () {
    test('equal results compare equal', () {
      const StorageSweepResult a = StorageSweepResult(
        filesDeleted: 2,
        bytesReclaimed: 100,
        moreRemaining: true,
      );
      const StorageSweepResult b = StorageSweepResult(
        filesDeleted: 2,
        bytesReclaimed: 100,
        moreRemaining: true,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('every field participates in equality', () {
      const StorageSweepResult base = StorageSweepResult(filesDeleted: 1);

      expect(base, isNot(const StorageSweepResult(filesDeleted: 2)));
      expect(
        base,
        isNot(const StorageSweepResult(filesDeleted: 1, bytesReclaimed: 1)),
      );
      expect(
        base,
        isNot(const StorageSweepResult(filesDeleted: 1, orphansFound: 1)),
      );
      expect(
        base,
        isNot(const StorageSweepResult(filesDeleted: 1, failures: 1)),
      );
      expect(
        base,
        isNot(const StorageSweepResult(filesDeleted: 1, moreRemaining: true)),
      );
    });

    test('toString carries every counter a log line needs', () {
      const StorageSweepResult r = StorageSweepResult(
        filesDeleted: 2,
        bytesReclaimed: 350,
        orphansFound: 1,
        failures: 1,
        moreRemaining: true,
      );
      final String text = r.toString();

      for (final String part in <String>['2', '350', '1', 'true']) {
        expect(text, contains(part));
      }
    });
  });
}
