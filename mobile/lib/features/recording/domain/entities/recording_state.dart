import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:mobile/features/recording/domain/entities/chunk_boundary_reason.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';

part 'recording_state.freezed.dart';

/// The four states of Volume 5 Chapter 5.3 §2's diagram, and nothing else.
///
/// ```text
/// Idle
///   │  Checklist passes (BR-04)
///   ▼
/// Ready
///   │  Collector taps Start
///   ▼
/// Recording ──────────────────────────────┐
///   │  10-minute boundary (BR-06)         │  Collector taps Stop
///   ▼  (internal, automatic Stop)         ▼
/// Finalizing (chunk N)                  Finalizing (final chunk)
///   │  chunk persisted + queued (BR-07)   │
///   ▼                                     ▼
/// Recording (chunk N+1, same session)   Idle (session Complete-pending)
/// ```
///
/// **A union rather than an enum plus flags.** The states carry different
/// data — `Idle` has no session, `Recording` has a sequence index and a chunk
/// start time, `Finalizing` additionally knows which branch it will take — and
/// an enum would force every one of those onto a single flat object where
/// three quarters of the fields are null at any moment. It would also let
/// `Idle` be paired with a sequence index, which is not a state this machine
/// has. Consistent with `WideAngleEligibility` from Mission 3.1.
///
/// **The two `Finalizing` boxes in the diagram are one state, not two.**
/// Chapter 5.3 §3 says finalization is *"the same finalization path whether
/// triggered automatically or manually"*; what differs is only where it goes
/// next. That difference is [RecordingStateFinalizing.reason], so the shared
/// path stays shared and the branch stays explicit.
@freezed
sealed class RecordingState with _$RecordingState {
  /// No active session — *"the Collector is anywhere in the Task/Project
  /// navigation"* (§3).
  ///
  /// [lastCompletedSession] is the diagram's *"Idle (session
  /// Complete-pending)"* parenthetical: after a Collector-initiated Stop
  /// finishes finalizing, this is the session that just ended. It is a field
  /// on `Idle` and **not a fifth state** — the diagram names four, and
  /// "Complete-pending" describes the session's status, not the machine's.
  /// Null on a cold start, when no session has run yet.
  const factory RecordingState.idle({
    RecordingSession? lastCompletedSession,
  }) = RecordingStateIdle;

  /// *"Checklist (C-07) has passed; camera is initialized (Chapter 5.1) but
  /// not yet recording."* (§3)
  ///
  /// Reaching this state is the whole of the lifecycle's BR-04 guarantee.
  /// Chapter 5.1 §3: *"the Recording Lifecycle never transitions into an
  /// active camera session unless the full Checklist has already passed."*
  /// That is enforced structurally — `Recording` is reachable only from here,
  /// and here is reachable only from the Checklist edge — rather than by a
  /// re-check, which §3 of that chapter explicitly does not want.
  const factory RecordingState.ready({
    required RecordingSession session,
  }) = RecordingStateReady;

  /// *"Actively capturing; a 10-minute internal timer runs alongside the
  /// Collector's ability to tap Stop at any time."* (§3)
  const factory RecordingState.recording({
    required RecordingSession session,

    /// The index this chunk will be stamped with (Volume 4 Chapter 4.4).
    required int sequenceIndex,

    /// When this chunk began — the 10-minute timer's origin.
    required DateTime chunkStartedAt,
  }) = RecordingStateRecording;

  /// *"The brief Local Processing state (C-10) — video is finalized (Chapter
  /// 5.5), metadata is generated (Chapter 5.7), and the chunk enters the
  /// Upload Queue (Chapter 5.9)."* (§3)
  const factory RecordingState.finalizing({
    required RecordingSession session,

    /// The index of the chunk being finalized.
    required int sequenceIndex,

    /// Which branch of §2's diagram this finalization returns to.
    required ChunkBoundaryReason reason,
  }) = RecordingStateFinalizing;

  const RecordingState._();

  /// The session in flight, or null when [RecordingStateIdle].
  ///
  /// `Idle.lastCompletedSession` is deliberately **not** reported here: it is
  /// a session that has ended, and a caller asking "what is recording now"
  /// must not be handed one that is not.
  RecordingSession? get activeSession => switch (this) {
    RecordingStateIdle() => null,
    RecordingStateReady(:final RecordingSession session) => session,
    RecordingStateRecording(:final RecordingSession session) => session,
    RecordingStateFinalizing(:final RecordingSession session) => session,
  };

  /// Whether the camera is capturing right now.
  ///
  /// False during `Finalizing` — capture has stopped and the file is being
  /// closed. C-10's Local Processing surface is shown then, not the preview.
  bool get isCapturing => this is RecordingStateRecording;
}
