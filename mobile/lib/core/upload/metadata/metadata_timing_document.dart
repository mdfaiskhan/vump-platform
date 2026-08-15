/// The `timing` group of Volume 4 Chapter 4.5 §2's wire shape.
class MetadataTimingDocument {
  /// Creates the timing group.
  const MetadataTimingDocument({
    this.sequenceIndex,
    this.startedAt,
    this.endedAt,
  });

  /// `timing.sequence_index`.
  final int? sequenceIndex;

  /// `timing.started_at` — when capture of this chunk began.
  final DateTime? startedAt;

  /// `timing.ended_at` — when it ended.
  final DateTime? endedAt;

  /// `timing.duration_seconds`, **derived rather than stored**.
  ///
  /// `ChunkRecordMapper` deliberately does not persist it: *"the domain
  /// derives it from the two timestamps, and a stored copy could disagree with
  /// them."* Chapter 4.5 §2 nonetheless requires the field on the wire, so it
  /// is computed here, at the one boundary that needs it.
  ///
  /// Null when either endpoint is missing — an invented zero would read as a
  /// chunk of no length, which is a claim rather than an absence.
  int? get durationSeconds {
    final DateTime? start = startedAt;
    final DateTime? end = endedAt;
    if (start == null || end == null) {
      return null;
    }
    return end.difference(start).inSeconds;
  }

  /// Chapter 4.5 §2's `timing` object.
  ///
  /// Timestamps are ISO-8601 in UTC. `toIso8601String` on a local `DateTime`
  /// emits no offset at all, which a backend would have to guess at; `toUtc`
  /// first makes the `Z` explicit.
  Map<String, Object?> toJson() => <String, Object?>{
    'sequence_index': sequenceIndex,
    'started_at': startedAt?.toUtc().toIso8601String(),
    'ended_at': endedAt?.toUtc().toIso8601String(),
    'duration_seconds': durationSeconds,
  };
}
