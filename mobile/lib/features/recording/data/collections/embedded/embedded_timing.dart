import 'package:isar/isar.dart';

part 'embedded_timing.g.dart';

/// The `timing` group on disk.
///
/// `duration_seconds` is deliberately absent: the domain derives it from the
/// two timestamps, and storing it would let a row disagree with itself.
@embedded
class EmbeddedTiming {
  /// Creates a stored EmbeddedTiming.
  EmbeddedTiming();

  /// Order within the session (Ch. 5.6 §2), zero-based.
  int? sequenceIndex;

  /// When capture of this chunk began.
  DateTime? startedAt;

  /// When capture stopped — the instant the file was closed.
  DateTime? endedAt;
}
