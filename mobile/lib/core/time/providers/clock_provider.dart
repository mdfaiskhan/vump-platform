/// The application's clock, overridable in tests.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/time/interfaces/clock.dart';
import 'package:mobile/core/time/system_clock.dart';

/// The real clock.
///
/// Unlike this project's other ports, this one **has a default**, and the
/// difference is deliberate. The others throw because their only
/// implementation lives in a feature's `data/` layer that the declaring layer
/// may not import (ADR-022 §5.3). [SystemClock] wraps `dart:async` and lives
/// in `core/` beside this file, so naming it here breaks no rule.
///
/// A default is also the safer behaviour here. An unoverridden clock that
/// threw would take down Chapter 5.13's retry schedule at the first transient
/// failure — turning a recoverable upload error into a dead dispatcher, which
/// is precisely the failure mode the retry strategy exists to prevent.
final Provider<Clock> clockProvider = Provider<Clock>(
  (Ref ref) => const SystemClock(),
);
