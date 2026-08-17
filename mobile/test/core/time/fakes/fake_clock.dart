import 'package:mobile/core/time/interfaces/clock.dart';

/// A clock a test drives by hand.
///
/// Volume 9 Chapter 9.6 §2 asks for exactly this: *"a fake, injectable clock …
/// is what makes a 10-minute business rule testable in milliseconds rather
/// than requiring an actual 10-minute test run"*. Chapter 5.13 §2's backoff
/// runs to 160 seconds across six attempts, so without this the retry suite
/// would take minutes of real time and, in practice, would not exist.
///
/// [advance] fires every delay whose deadline has passed, in deadline order,
/// which is what lets a test assert that the *earliest* pending wake is the
/// one that runs.
class FakeClock implements Clock {
  /// Creates a clock reading [start].
  FakeClock({DateTime? start}) : _now = start ?? DateTime.utc(2026, 8, 16, 12);

  DateTime _now;
  final List<_FakeDelay> _pending = <_FakeDelay>[];

  /// Delays scheduled and not yet fired or cancelled.
  int get pendingDelays => _pending.where((_FakeDelay d) => d.live).length;

  /// Every duration ever scheduled, in order.
  final List<Duration> scheduled = <Duration>[];

  @override
  DateTime now() => _now;

  @override
  ScheduledDelay delay(Duration duration, void Function() onElapsed) {
    scheduled.add(duration);
    final _FakeDelay entry = _FakeDelay(_now.add(duration), onElapsed);
    _pending.add(entry);
    return entry;
  }

  /// Moves time forward and fires whatever became due.
  void advance(Duration by) {
    _now = _now.add(by);
    final List<_FakeDelay> due =
        _pending.where((_FakeDelay d) => d.live && !d.at.isAfter(_now)).toList()
          ..sort((_FakeDelay a, _FakeDelay b) => a.at.compareTo(b.at));
    for (final _FakeDelay entry in due) {
      entry.live = false;
      _pending.remove(entry);
      entry.onElapsed();
    }
  }
}

class _FakeDelay implements ScheduledDelay {
  _FakeDelay(this.at, this.onElapsed);

  final DateTime at;
  final void Function() onElapsed;
  bool live = true;

  @override
  void cancel() => live = false;
}
