import 'package:mobile/features/recording/domain/entities/chunk_boundary_reason.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';

/// Volume 5 Chapter 5.3 §2's transitions, as pure functions.
///
/// Every edge in the diagram is one method here, and nothing else is. There is
/// no timer, no camera, no file and no `await` — the notifier owns those and
/// asks this what the next state is. That keeps the whole machine, including
/// the internal-Stop pattern that is the chapter's key design point, testable
/// as a table with no hardware and no clock.
///
/// ## Illegal transitions return null rather than throwing
///
/// Each method returns null when its event does not apply to the state it is
/// given — Start while already recording, Stop while already finalizing.
///
/// Null rather than an exception because **the realistic causes are races, not
/// defects**: a double-tapped Stop button, or a manual Stop landing in the same
/// frame as the 10-minute timer. Chapter 5.6 §3 names that second case
/// specifically and says the outcome must be that *"a chunk is never
/// accidentally double-finalized"* — which is a requirement to ignore the
/// loser, not to crash on it. Throwing would convert a normal UI race into an
/// error surface, and no `ErrorCode` describes "you tapped twice".
///
/// The notifier ignores a null and leaves state untouched, so ignoring is the
/// specified behaviour rather than a swallowed failure.
abstract final class RecordingLifecycle {
  /// The chunk length BR-06 fixes: *"Each chunk shall be exactly 10 minutes
  /// in length, except for the final chunk"*.
  static const Duration chunkDuration = Duration(minutes: 10);

  /// The `sequence_index` of a session's first chunk.
  ///
  /// **Zero, decided by the project owner rather than by the volumes.**
  /// Chapter 5.6 §2 says the index starts *"at 0 (or 1, matching Volume 4's
  /// convention)"*, but Volume 4 defines `sequence_index` four times — the
  /// chunks table, the metadata JSON, the chunk-registration request and the
  /// S3 key pattern — and never states a base, so the parenthetical defers to
  /// a convention that does not exist. The chapter's stated default therefore
  /// stands.
  ///
  /// This is load-bearing well beyond this file: Chapter 5.14 §1 makes the S3
  /// object key `{sequence_index:04d}_{chunk_id}.mp4` and Volume 4 marks it
  /// UNIQUE, so an off-by-one here renames every object in the system and
  /// changes what BR-11's "never a duplicate object" is asserting about.
  static const int firstSequenceIndex = 0;

  /// `Idle` → `Ready`, the Checklist edge (BR-04).
  ///
  /// [session] carries the `session_id` generated once at session start
  /// (Chapter 5.6 §2) and the zoom factor the Checklist resolved from Chapter
  /// 5.1's ladder.
  ///
  /// **This method is the BR-04 gate.** It is the only way into `Ready`, and
  /// `Ready` is the only way into `Recording`. The lifecycle performs no
  /// checklist check of its own, because Chapter 5.1 §3 assigns that to the
  /// Checklist and says it is *"not re-checked redundantly here"*.
  static RecordingState? onChecklistPassed(
    RecordingState state,
    RecordingSession session,
  ) {
    return state is RecordingStateIdle
        ? RecordingState.ready(session: session)
        : null;
  }

  /// `Ready` → `Recording`, the Collector tapping Start.
  ///
  /// Opens the session's first chunk at [firstSequenceIndex].
  static RecordingState? onStart(RecordingState state, DateTime now) {
    if (state is! RecordingStateReady) {
      return null;
    }
    return RecordingState.recording(
      session: state.session,
      sequenceIndex: firstSequenceIndex,
      chunkStartedAt: now,
    );
  }

  /// `Recording` → `Finalizing`, by either kind of Stop.
  ///
  /// One method for both edges, because §1 defines the automatic boundary as
  /// *"identical in every way to a manual Stop"* and §3 confirms the
  /// finalization path is shared. [reason] records only which branch the
  /// finalization returns to, which is the sole difference between them.
  ///
  /// The final chunk of a session may be far shorter than 10 minutes and that
  /// is valid — §4 states the lifecycle *"does not pad or discard a short
  /// final chunk"*, and Chapter 5.6 §3 adds that *"there is no minimum chunk
  /// duration below which footage is discarded"*. So no duration is checked
  /// here, deliberately.
  static RecordingState? onStop(
    RecordingState state,
    ChunkBoundaryReason reason,
  ) {
    if (state is! RecordingStateRecording) {
      return null;
    }
    return RecordingState.finalizing(
      session: state.session,
      sequenceIndex: state.sequenceIndex,
      reason: reason,
    );
  }

  /// `Finalizing` → `Recording` (chunk N+1) or `Idle`, once BR-07 is met.
  ///
  /// The edge the chapter's key design point turns on. The chunk has been
  /// persisted and queued, and where the machine goes now is the *only* thing
  /// that distinguishes an automatic boundary from a manual Stop:
  ///
  /// - [ChunkBoundaryReason.automaticBoundary] re-enters `Recording` with the
  ///   **same session** and the next sequence index, which is what makes
  ///   chunking seamless without ever slicing mid-stream (BR-05).
  /// - [ChunkBoundaryReason.collectorStop] returns to `Idle`, carrying the
  ///   session that just ended as the diagram's *"Complete-pending"*.
  ///
  /// §4 assigns the increment here and only here: *"the Recording Lifecycle is
  /// what actually increments that index, once per Finalizing transition."*
  static RecordingState? onChunkPersisted(RecordingState state, DateTime now) {
    if (state is! RecordingStateFinalizing) {
      return null;
    }

    return switch (state.reason) {
      ChunkBoundaryReason.automaticBoundary => RecordingState.recording(
        session: state.session,
        sequenceIndex: state.sequenceIndex + 1,
        chunkStartedAt: now,
      ),
      ChunkBoundaryReason.collectorStop => RecordingState.idle(
        lastCompletedSession: state.session,
      ),
    };
  }
}
