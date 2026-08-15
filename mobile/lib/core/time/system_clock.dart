import 'dart:async';

import 'package:mobile/core/time/interfaces/clock.dart';

/// The real clock, over `DateTime.now()` and `Timer`.
///
/// The only place in `lib/` that reads wall-clock time for Chapter 5.13's
/// schedule. Volume 9 Chapter 9.6 §2 bans `DateTime.now()` inside a use case
/// precisely so this class can be swapped for a fake; keeping the call here
/// is what makes that swap total rather than partial.
///
/// Lives in `core/` rather than behind a feature's `data/` layer because it
/// wraps `dart:async`, not a platform plugin. There is no confinement rule to
/// satisfy and no platform channel to own — ADR-030's argument for confining a
/// package does not apply to the SDK.
class SystemClock implements Clock {
  /// Creates the real clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  ScheduledDelay delay(Duration duration, void Function() onElapsed) =>
      _TimerDelay(Timer(duration, onElapsed));
}

class _TimerDelay implements ScheduledDelay {
  _TimerDelay(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
