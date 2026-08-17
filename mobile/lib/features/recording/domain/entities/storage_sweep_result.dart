/// What one run of Volume 5 Chapter 5.15 §2's cleanup sweep did.
///
/// Reported rather than logged-and-forgotten because a sweep that silently
/// does nothing and a sweep that silently fails look identical from outside,
/// and BR-08 makes the difference between them the whole point of the chapter:
/// files that should have been reclaimed and were not are a storage leak, and
/// files that were reclaimed when they should not have been are data loss.
final class StorageSweepResult {
  /// Creates a result.
  const StorageSweepResult({
    this.filesDeleted = 0,
    this.bytesReclaimed = 0,
    this.orphansFound = 0,
    this.failures = 0,
    this.moreRemaining = false,
  });

  /// A sweep that found nothing to do.
  ///
  /// The normal outcome. Chapter 5.15 §4 notes that in normal operation the
  /// eligibility rule alone keeps storage bounded, so most sweeps are this.
  static const StorageSweepResult idle = StorageSweepResult();

  /// Files removed from disk and marked deleted on their row.
  final int filesDeleted;

  /// The sum of the recorded file sizes for those files.
  final int bytesReclaimed;

  /// Rows whose file was already gone before this sweep touched it.
  ///
  /// Not an error and not a deletion — `ChunkStore.orphanedChunkIds`' own doc
  /// says a row is only committed after its file is in place, so this should
  /// be zero. External deletion and OS eviction are the causes it names.
  /// Counted so a non-zero value is visible rather than inferred.
  final int orphansFound;

  /// Chunks whose deletion failed, leaving the file and the row untouched.
  ///
  /// A failure is per-chunk and does not abandon the batch: one unreadable
  /// file must not strand every other eligible chunk behind it.
  final int failures;

  /// Whether more eligible chunks were left for the next sweep.
  ///
  /// True when the batch limit truncated the work. Chapter 5.15 §2 wants the
  /// sweep batched *"to avoid competing with an active Recording Pipeline
  /// (Ch.5.4) for I/O"*, so truncation is the design working — but a value
  /// that stays true across many sweeps means the backlog is growing faster
  /// than the batch clears it, which is worth being able to see.
  final bool moreRemaining;

  /// Whether this sweep changed anything at all.
  bool get didWork => filesDeleted > 0 || failures > 0;

  @override
  String toString() =>
      'StorageSweepResult(deleted: $filesDeleted, '
      'reclaimed: $bytesReclaimed bytes, orphans: $orphansFound, '
      'failures: $failures, more: $moreRemaining)';

  @override
  bool operator ==(Object other) =>
      other is StorageSweepResult &&
      other.filesDeleted == filesDeleted &&
      other.bytesReclaimed == bytesReclaimed &&
      other.orphansFound == orphansFound &&
      other.failures == failures &&
      other.moreRemaining == moreRemaining;

  @override
  int get hashCode => Object.hash(
    filesDeleted,
    bytesReclaimed,
    orphansFound,
    failures,
    moreRemaining,
  );
}
