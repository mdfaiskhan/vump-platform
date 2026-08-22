import 'dart:math';

/// Volume 5 Chapter 5.13 §2's automatic backoff — **FR-UPL-06**, *"the
/// system shall retry failed uploads automatically using a defined backoff
/// strategy"*.
///
/// The identifier was added at Mission 8.1. This file already cited the
/// chapter and FR-UPL-07 for the manual counterpart, so the automatic half
/// was the one requirement in the pair with no requirement id on it.
///
/// **There is no BR for this rule and one should not be invented.** Volume 1's
/// upload rules cover deletion (BR-08), the default mode (BR-09), recording
/// while uploading (BR-10) and retry idempotence (BR-11) — none concerns a
/// schedule or an attempt budget. A-237 recommended a BR tag and was wrong
/// about the kind of identifier; the correction is recorded there.
///
/// Every number here is transcribed from the chapter, not chosen:
///
/// > *"Exponential backoff: 5s, 10s, 20s, 40s, capped at 5 minutes between
/// > attempts. Up to 6 automatic attempts per chunk before it transitions to
/// > Failed … A small random jitter (±20%) is added to each delay so that many
/// > chunks failing at once … don't all retry in the same instant and
/// > thundering-herd the backend the moment connectivity returns."*
///
/// `volume-amendments.md` records §2 under **Confirmed correct — no
/// amendment**, so this is implementation of an authoritative schedule rather
/// than a decision taken here. Contrast `UploadDispatcher.defaultConcurrency`,
/// which had no chapter behind it and carries A-078 saying so.
///
/// ## The 5-minute cap can never bind, and that is recorded rather than fixed
///
/// Six attempts have **five** gaps between them, so the reachable delays are
/// 5, 10, 20, 40 and 80 seconds — the chapter's own four values plus one more
/// doubling. The largest delay any chunk can draw is **80 s against a 300 s
/// cap**, so the cap is unreachable by construction.
///
/// It is implemented anyway, exactly as written. The clause is not wrong — it
/// is inert, and a schedule that grew past 6 attempts would need it. Amendment
/// A-083 records this so that a later reader who notices the dead clause does
/// not "fix" it by stretching the schedule to reach 5 minutes, which would
/// change agreed retry behaviour to satisfy an arithmetic curiosity.
class RetrySchedule {
  /// Creates a schedule, optionally over a seeded [random] for tests.
  ///
  /// The jitter is the one part of §2 that is deliberately non-deterministic,
  /// so the source of randomness is injectable for the same reason the clock
  /// is (Volume 9 Chapter 9.6 §2): a test asserting the ±20 % bound needs to
  /// pin the draw rather than sample it.
  RetrySchedule({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// §2's first delay. Each subsequent attempt doubles it.
  static const Duration baseDelay = Duration(seconds: 5);

  /// §2's ceiling — *"capped at 5 minutes between attempts"*.
  ///
  /// Unreachable within [maxAttempts]; see the class comment and A-083.
  static const Duration maxDelay = Duration(minutes: 5);

  /// §2's budget — *"up to 6 automatic attempts per chunk"*.
  static const int maxAttempts = 6;

  /// §2's *"small random jitter (±20%)"*, as a fraction.
  static const double jitterFraction = 0.2;

  /// Whether another automatic attempt is allowed after [attemptsSoFar].
  ///
  /// §2 gives six attempts, so the sixth failure exhausts the budget and the
  /// chunk becomes `Failed` — waiting for connectivity to change (Chapter
  /// 5.12) or for FR-UPL-07's manual retry.
  bool hasAttemptsLeft(int attemptsSoFar) => attemptsSoFar < maxAttempts;

  /// The un-jittered delay before attempt number [attemptsSoFar] + 1.
  ///
  /// [attemptsSoFar] counts attempts already **made**, so the first failure
  /// arrives here as 1 and waits [baseDelay] — §2's 5 s. The delay doubles per
  /// failure after that: 5, 10, 20, 40, 80 across the six-attempt budget.
  ///
  /// Exposed separately from [delayFor] so a test can assert the doubling and
  /// the cap without reasoning about the random draw.
  Duration baseDelayFor(int attemptsSoFar) {
    final int doublings = attemptsSoFar - 1;
    if (doublings <= 0) {
      return baseDelay;
    }
    // Guard the shift before it happens rather than after: 1 << 63 overflows
    // to a negative in Dart's 64-bit int, so a large attempt count would
    // produce a negative delay and schedule a retry in the past.
    if (doublings >= 32) {
      return maxDelay;
    }
    final int scaled = baseDelay.inMilliseconds * (1 << doublings);
    if (scaled >= maxDelay.inMilliseconds) {
      return maxDelay;
    }
    return Duration(milliseconds: scaled);
  }

  /// The jittered delay before the next attempt.
  ///
  /// §2's jitter exists for one stated purpose — *"many chunks failing at once
  /// (e.g. a whole batch losing connectivity together) don't all retry in the
  /// same instant"* — so it is applied per call rather than per chunk or per
  /// schedule. Two chunks asking at the same moment get different answers,
  /// which is the whole point.
  ///
  /// Never returns a negative or zero duration: at ±20 % of a 5-second floor
  /// the minimum is 4 seconds, but the clamp is stated rather than assumed so
  /// that a future change to [baseDelay] cannot schedule a retry in the past.
  Duration delayFor(int attemptsSoFar) {
    final Duration base = baseDelayFor(attemptsSoFar);
    // nextDouble() is [0,1); mapping to [-1,1) then scaling gives ±20 %.
    final double swing = (_random.nextDouble() * 2 - 1) * jitterFraction;
    final int jittered = (base.inMilliseconds * (1 + swing)).round();
    return Duration(milliseconds: max(1, jittered));
  }
}
