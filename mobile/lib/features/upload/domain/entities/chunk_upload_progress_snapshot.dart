/// One chunk's live transfer progress, for Chapter 2.7's C-11 row.
///
/// Chapter 2.7 specifies an *"accent-hue pill with live percentage; progress
/// bar beneath the row, not inside the pill"*, so both the number and the bar
/// read from this one value.
///
/// ## Transient by design — this is never stored
///
/// It comes from Dio's send-progress callback and changes many times a second.
/// Persisting it would be a write storm against a database whose queue is a
/// live watch, and would put a field on `QueuedChunk` that means nothing a
/// moment after it is read. `QueuedChunk` carries what survives a restart;
/// this carries what does not. A-092 records the split.
final class ChunkUploadProgressSnapshot {
  /// Creates a snapshot.
  const ChunkUploadProgressSnapshot({
    required this.sentBytes,
    required this.totalBytes,
  });

  /// Bytes handed to the socket so far.
  final int sentBytes;

  /// Bytes expected in total, or a non-positive value when unknown.
  ///
  /// Dio reports `-1` for a stream whose length it cannot determine. Treated
  /// as unknown rather than as zero, so a bar renders indeterminate instead of
  /// claiming 0%.
  final int totalBytes;

  /// Whether a percentage can honestly be shown.
  bool get isDeterminate => totalBytes > 0;

  /// Completion in `0.0`–`1.0`, or null when [totalBytes] is unknown.
  double? get fraction {
    if (!isDeterminate) {
      return null;
    }
    final double raw = sentBytes / totalBytes;
    return raw.clamp(0.0, 1.0);
  }

  /// Whole percent for Chapter 2.7's *"live percentage"*, or null.
  ///
  /// Floored rather than rounded: a bar that reads 100% while bytes are still
  /// moving is the kind of small lie Chapter 2.9 §2 principle 2 exists to
  /// prevent — the Collector *"should never have to wonder if it worked"*.
  int? get percent {
    final double? value = fraction;
    return value == null ? null : (value * 100).floor();
  }

  @override
  String toString() => 'ChunkUploadProgressSnapshot($sentBytes/$totalBytes)';

  @override
  bool operator ==(Object other) =>
      other is ChunkUploadProgressSnapshot &&
      other.sentBytes == sentBytes &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(sentBytes, totalBytes);
}
