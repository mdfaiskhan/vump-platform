import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/failed_chunk.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/session_end_cause.dart';

part 'recording_state.freezed.dart';

/// Volume 5 Chapter 5.3 §2's four states, with processing tracked alongside.
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
///   ▼  capture restarts immediately       ▼
/// Recording (chunk N+1, same session)   Finalizing — draining
///   with chunk N added to `processing`     │  last job completes
///                                          ▼
///                                        Idle (session Complete-pending)
/// ```
///
/// ## Still four states — processing is a field, not a variant
///
/// Mission 3.4.5 had to express *"recording chunk N+1 while chunk N is still
/// processing"*, and the obvious move is a fifth state. It is the wrong one.
///
/// **Capture and processing are orthogonal.** What the camera is doing and how
/// many closed files are being hashed are independent facts, so encoding their
/// combination as variants multiplies them: `recordingWithOnePending`,
/// `recordingWithTwoPending`, and so on. Making processing a *field* on the
/// states that can carry it says the same thing without the product.
///
/// The union therefore keeps Chapter 5.3 §2's four names, and the exhaustive
/// transition matrix stays a 4×4 table. **What did change is the number of
/// legal edges, from four to five** — `onChunkProcessed` is now legal from
/// `Recording` as well as from `Finalizing`, because a background job can
/// finish at any time, including while the next chunk is being captured. That
/// test was written to catch an unplanned state addition and it did its job
/// here: the count moved deliberately, and only that one edge moved.
///
/// ## What `Finalizing` means now
///
/// It no longer means "waiting for this chunk". It means **the Collector has
/// stopped and the session is draining** — capture has ended and the machine
/// is waiting for outstanding jobs before declaring the session over. An
/// automatic boundary never enters it; it goes straight back to `Recording`.
///
/// That is also why C-10 is shown only for a Collector-initiated stop
/// (A-059): under this design it is the only time anyone waits.
@freezed
sealed class RecordingState with _$RecordingState {
  /// No active session.
  ///
  /// [lastCompletedSession] is the diagram's *"Idle (session
  /// Complete-pending)"* parenthetical — the session that just ended, not a
  /// fifth state. [failed] carries any chunk that failed terminally during it,
  /// so a failure is not lost when its job leaves the pending set.
  const factory RecordingState.idle({
    RecordingSession? lastCompletedSession,
    @Default(<FailedChunk>[]) List<FailedChunk> failed,

    /// Why the last session ended, or null on a cold start.
    ///
    /// Carried here and not only on `Finalizing` because the explanation is
    /// needed **after** draining completes, which is when the Collector is
    /// looking at a stopped recording and wondering why. Volume 2 Ch. 2.9 §4.3
    /// requires a cause and a recovery action; this is the half the domain
    /// owes, and Mission 3.8 maps it to the other half.
    SessionEndCause? endCause,
  }) = RecordingStateIdle;

  /// Checklist passed, camera initialized, not yet recording.
  const factory RecordingState.ready({
    required RecordingSession session,
  }) = RecordingStateReady;

  /// Actively capturing, with any earlier chunks still being processed.
  const factory RecordingState.recording({
    required RecordingSession session,

    /// The index of the chunk being captured now.
    required int sequenceIndex,

    /// When this chunk began — the BR-06 timer's origin.
    required DateTime chunkStartedAt,

    /// Chunks whose capture has ended and whose processing is in flight.
    @Default(<ChunkProcessingJob>[]) List<ChunkProcessingJob> processing,

    /// Chunks that failed terminally earlier in this session.
    @Default(<FailedChunk>[]) List<FailedChunk> failed,
  }) = RecordingStateRecording;

  /// The Collector has stopped; the session is draining before it ends.
  ///
  /// This is C-10's Local Processing state (Volume 2). Capture has already
  /// ended — the camera is released — and what remains is the outstanding
  /// work in [processing].
  const factory RecordingState.finalizing({
    required RecordingSession session,

    /// Jobs still in flight. `Idle` is reached when this empties.
    required List<ChunkProcessingJob> processing,

    /// Why capture ended — carried through to [RecordingStateIdle].
    ///
    /// `Finalizing` is reachable two ways: a Collector-initiated stop, and a
    /// capacity-forced end. They look identical without this, which is the
    /// defect Mission 3.4.5.1 found. It is also the field amendment A-059's
    /// C-10 rule branches on.
    required SessionEndCause endCause,

    /// Chunks that failed terminally during this session.
    @Default(<FailedChunk>[]) List<FailedChunk> failed,
  }) = RecordingStateFinalizing;

  const RecordingState._();

  /// The session in flight, or null when [RecordingStateIdle].
  RecordingSession? get activeSession => switch (this) {
    RecordingStateIdle() => null,
    RecordingStateReady(:final RecordingSession session) => session,
    RecordingStateRecording(:final RecordingSession session) => session,
    RecordingStateFinalizing(:final RecordingSession session) => session,
  };

  /// Whether the camera is capturing right now.
  ///
  /// **True across an automatic chunk boundary**, which is the point of this
  /// mission: the only pause is one use-case bind cycle, not the duration of
  /// the previous chunk's checksum.
  bool get isCapturing => this is RecordingStateRecording;

  /// Chunks whose processing is in flight, in the order capture ended.
  List<ChunkProcessingJob> get processingJobs => switch (this) {
    RecordingStateIdle() => const <ChunkProcessingJob>[],
    RecordingStateReady() => const <ChunkProcessingJob>[],
    RecordingStateRecording(:final List<ChunkProcessingJob> processing) =>
      processing,
    RecordingStateFinalizing(:final List<ChunkProcessingJob> processing) =>
      processing,
  };

  /// Whether the session ended without the Collector asking it to.
  ///
  /// The condition Volume 2 Ch. 2.9 §4.3 requires an explanation for. False
  /// while recording, and false for a stop the Collector chose.
  bool get endedInvoluntarily =>
      sessionEndCause == SessionEndCause.processingCapacityReached;

  /// Why the session ended, or null if none has.
  SessionEndCause? get sessionEndCause => switch (this) {
    RecordingStateIdle(:final SessionEndCause? endCause) => endCause,
    RecordingStateReady() => null,
    RecordingStateRecording() => null,
    RecordingStateFinalizing(:final SessionEndCause endCause) => endCause,
  };

  /// Chunks that failed terminally in this session (Ch. 5.13 §1).
  List<FailedChunk> get failedChunks => switch (this) {
    RecordingStateIdle(:final List<FailedChunk> failed) => failed,
    RecordingStateReady() => const <FailedChunk>[],
    RecordingStateRecording(:final List<FailedChunk> failed) => failed,
    RecordingStateFinalizing(:final List<FailedChunk> failed) => failed,
  };
}
