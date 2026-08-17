/// Why a chunk stopped recording and entered finalization.
///
/// **Both are a Stop.** Volume 5 Chapter 5.3 §1 is the design point: the
/// automatic 10-minute boundary is *"an internal, system-triggered Stop —
/// identical in every way to a manual Stop, except it is immediately followed
/// by a new Recording state rather than returning to Idle."* Neither is a
/// mid-stream slice, which is what BR-05 forbids and what would risk a
/// corrupted encode.
///
/// So this enum does **not** select a finalization path — Chapter 5.3 §3 says
/// finalization is *"the same finalization path whether triggered
/// automatically or manually"*. It selects only what happens *after*
/// finalization succeeds, which is the single difference between the two.
enum ChunkBoundaryReason {
  /// The 10-minute timer elapsed (BR-06). The session continues.
  ///
  /// Finalization is followed by `Recording` for chunk N+1 of the same
  /// session, per Chapter 5.3 §2's left-hand branch.
  automaticBoundary,

  /// The Collector tapped Stop. This chunk is the session's last.
  ///
  /// Finalization is followed by `Idle`. Chapter 5.6 §3 adds the rule that
  /// makes the two reasons mutually exclusive: *"the automatic 10-minute timer
  /// is cancelled the instant a manual Stop begins finalization, so a chunk is
  /// never accidentally double-finalized."*
  collectorStop,
}
