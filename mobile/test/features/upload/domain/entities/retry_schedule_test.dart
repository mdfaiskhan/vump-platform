import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/upload/domain/entities/retry_schedule.dart';

/// Volume 5 Chapter 5.13 §2's backoff, asserted against the chapter's numbers.
///
/// The register records §2 under *"Confirmed correct — no amendment"*, so these
/// are tests of a transcription, not of a decision. A failure here means the
/// code drifted from the chapter, not that the chapter is wrong.
void main() {
  group('the doubling sequence — §2 verbatim', () {
    test('is 5s, 10s, 20s, 40s for the first four attempts', () {
      final RetrySchedule schedule = RetrySchedule();

      // attemptsSoFar counts failures already made, so the first failure
      // waits 5s — §2's first value, not its second.
      expect(schedule.baseDelayFor(1), const Duration(seconds: 5));
      expect(schedule.baseDelayFor(2), const Duration(seconds: 10));
      expect(schedule.baseDelayFor(3), const Duration(seconds: 20));
      expect(schedule.baseDelayFor(4), const Duration(seconds: 40));
    });

    test('continues doubling to the end of the attempt budget', () {
      final RetrySchedule schedule = RetrySchedule();

      // Six attempts have five gaps; the fifth is the last one drawn.
      expect(schedule.baseDelayFor(5), const Duration(seconds: 80));
    });

    test('the 5-minute cap is unreachable within the budget — A-083', () {
      // Not a bug, and deliberately pinned so nobody "fixes" the schedule to
      // reach the cap. The largest delay any of the six attempts can draw is
      // 80s against a 300s ceiling.
      final RetrySchedule schedule = RetrySchedule();

      final Duration largest = schedule.baseDelayFor(
        RetrySchedule.maxAttempts - 1,
      );

      expect(largest, const Duration(seconds: 80));
      expect(largest, lessThan(RetrySchedule.maxDelay));
    });

    test('the cap does bind once the sequence runs past the budget', () {
      // The clause is inert, not wrong. This is what it would do.
      final RetrySchedule schedule = RetrySchedule();

      expect(schedule.baseDelayFor(7), const Duration(minutes: 5));
      expect(schedule.baseDelayFor(20), RetrySchedule.maxDelay);
    });

    test('a very large attempt count cannot overflow into the past', () {
      // 1 << 63 wraps negative in Dart. A negative delay would schedule a
      // retry before now and spin.
      final RetrySchedule schedule = RetrySchedule();

      for (final int attempts in <int>[31, 32, 63, 64, 1000]) {
        expect(
          schedule.baseDelayFor(attempts),
          RetrySchedule.maxDelay,
          reason: 'attemptsSoFar=$attempts',
        );
      }
    });
  });

  group('the attempt budget — §2\'s "up to 6"', () {
    test('allows six attempts and refuses a seventh', () {
      final RetrySchedule schedule = RetrySchedule();

      for (int spent = 0; spent < 6; spent++) {
        expect(schedule.hasAttemptsLeft(spent), isTrue, reason: '$spent spent');
      }
      expect(schedule.hasAttemptsLeft(6), isFalse);
      expect(schedule.hasAttemptsLeft(7), isFalse);
    });
  });

  group("jitter — §2's ±20%", () {
    test('never leaves the stated band, across many draws', () {
      final RetrySchedule schedule = RetrySchedule(random: Random(20260816));

      for (int attempt = 1; attempt <= 5; attempt++) {
        final Duration base = schedule.baseDelayFor(attempt);
        final int low = (base.inMilliseconds * 0.8).round();
        final int high = (base.inMilliseconds * 1.2).round();

        for (int draw = 0; draw < 200; draw++) {
          final Duration actual = schedule.delayFor(attempt);
          expect(
            actual.inMilliseconds,
            inInclusiveRange(low, high),
            reason: 'attempt $attempt, draw $draw',
          );
        }
      }
    });

    test('two chunks asking at once get different delays', () {
      // §2's whole stated purpose: "many chunks failing at once … don't all
      // retry in the same instant and thundering-herd the backend".
      final RetrySchedule schedule = RetrySchedule(random: Random(7));

      final Set<int> draws = <int>{
        for (int i = 0; i < 50; i++) schedule.delayFor(2).inMilliseconds,
      };

      expect(
        draws.length,
        greaterThan(1),
        reason: 'a fixed delay would defeat the anti-herd purpose',
      );
    });

    test('is never zero or negative', () {
      final RetrySchedule schedule = RetrySchedule(random: Random(3));

      for (int i = 0; i < 500; i++) {
        expect(schedule.delayFor(i % 7).inMilliseconds, greaterThan(0));
      }
    });
  });
}
