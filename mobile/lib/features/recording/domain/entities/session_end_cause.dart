/// Why a recording session stopped.
///
/// Deliberately **not** named `reason`, and deliberately not the same type as
/// `ChunkBoundaryReason`. That enum answers *"why did this chunk end"* and has
/// a value — `automaticBoundary` — that does not end a session at all. This
/// one answers *"why did the session end"*, and every value here is terminal.
/// Conflating them is what let Mission 3.4.5 ship a `Finalizing` that could be
/// reached two ways without recording which.
///
/// ## This exists to satisfy Volume 2 Chapter 2.9's pairing rule
///
/// §4.3 requires that *"every error state pairs a plain-language cause with a
/// single, specific recovery action ... never an error with no action
/// attached"*. A session that ends without the Collector asking is exactly
/// such a state, and until this type existed the machine could not tell anyone
/// which of two very different things had happened.
///
/// The copy and the action are **not** here — that is `presentation/`'s job,
/// the way `AuthErrorCopy` maps `ErrorCode` to what a person reads. What the
/// domain owes Mission 3.8 is a value it can branch on without
/// reverse-engineering intent, and that is what this is.
enum SessionEndCause {
  /// The Collector tapped Stop. Expected, and needs no explanation.
  ///
  /// This is the value Volume 2's C-10 Local Processing state is shown for
  /// (amendment A-059) — the only case where anyone is waiting.
  collectorStop,

  /// The device could not process chunks as fast as it was capturing them,
  /// and recording was stopped rather than continued.
  ///
  /// Reached only through Chapter 5.4 §2's low-storage path: that forces a
  /// boundary on every 5-second poll while free space stays below the
  /// threshold, so jobs accumulate until
  /// `RecordingLifecycle.maximumConcurrentProcessing` is hit.
  ///
  /// **The session ends involuntarily.** A Collector mid-walkthrough sees
  /// recording stop without having asked, which is precisely why this value
  /// has to reach the UI rather than being inferred from an empty `Idle`.
  processingCapacityReached,
}
