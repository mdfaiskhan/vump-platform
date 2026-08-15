/// The application's source of "now", and of scheduled delays.
///
/// Volume 9 Chapter 9.6 §2 requires this and says why: *"A fake, injectable
/// clock (never `DateTime.now()` called directly inside a use-case) is what
/// makes a 10-minute business rule testable in milliseconds rather than
/// requiring an actual 10-minute test run."*
///
/// Chapter 5.13 §2 is that rule exactly — a backoff of 5 s, 10 s, 20 s and
/// 40 s. Without this port the only honest test of the retry schedule would
/// take over a minute per case, so in practice it would not be tested at all.
///
/// ## The chapter it is cited to does not contain it
///
/// Chapter 9.6 §2 attributes the rule to Volume 3 Chapter 3.7 as a coding
/// standard. Volume 3 Chapter 3.7 has nine sections and **none of them
/// mentions a clock, `DateTime.now()`, time injection or determinism** —
/// amendment A-045, still open. The requirement stands on Chapter 9.6 §2's own
/// authority; only its cross-reference is wrong.
///
/// ## Why `delay` lives here rather than in a separate scheduler
///
/// A retry needs both halves — a deadline written to storage, and something
/// that waits until it arrives. Splitting them across two ports would let a
/// test fake one and not the other, which is how a suite ends up with a real
/// 40-second sleep in it.
abstract interface class Clock {
  /// The current wall-clock instant.
  DateTime now();

  /// Completes after [duration].
  ///
  /// Returns a cancellable handle rather than a bare `Future`: Chapter 5.12
  /// §4 requires a reconnection to claim the queue *"immediately — no polling
  /// delay"*, so a chunk sitting in a 40-second backoff has to be woken early
  /// rather than waited out. A timer that could only be awaited would make
  /// NFR-AVL-02's 30-second target unreachable by construction whenever the
  /// backoff exceeded it.
  ScheduledDelay delay(Duration duration, void Function() onElapsed);
}

/// A pending [Clock.delay] that has not fired yet.
abstract interface class ScheduledDelay {
  /// Abandons the delay. [Clock.delay]'s callback will not run.
  ///
  /// Idempotent — cancelling an already-fired or already-cancelled delay is a
  /// no-op, because the caller cannot know which happened first.
  void cancel();
}
