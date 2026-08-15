import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/features/recording/domain/entities/chunk_boundary_reason.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/failed_chunk.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/domain/entities/session_end_cause.dart';

/// Volume 5 Chapter 5.3 §2's transitions, as pure functions.
///
/// No timer, no camera, no file, no `await`. The notifier owns those and asks
/// this what the next state is, so the whole machine — including the overlap
/// this mission introduces — is a table test with no hardware and no clock.
///
/// ## Illegal transitions return null rather than throwing
///
/// Each method returns null when its event does not apply, because the
/// realistic causes are races: a double-tapped Stop, or a manual Stop landing
/// with the boundary timer. Chapter 5.6 §3 requires the loser be ignored, not
/// raised, and no `ErrorCode` describes "you tapped twice".
///
/// ## Five legal edges, not four
///
/// Mission 3.2 had four. [onChunkProcessed] is now legal from `Recording` as
/// well as `Finalizing`, because a background job can complete while the next
/// chunk is being captured — which is the entire point of Mission 3.4.5. See
/// amendment A-061.
abstract final class RecordingLifecycle {
  /// The chunk length BR-06 fixes.
  static const Duration chunkDuration = Duration(minutes: 10);

  /// The `sequence_index` of a session's first chunk.
  ///
  /// Zero. Chapter 5.6 §2 says *"starting at 0 (or 1, matching Volume 4's
  /// convention)"*, and Volume 4 defines the field four times without ever
  /// stating a base — so the chapter's stated default stands. Load-bearing:
  /// Chapter 5.14 §1 makes the S3 key `{sequence_index:04d}_{chunk_id}.mp4`
  /// and Volume 4 marks it UNIQUE.
  static const int firstSequenceIndex = 0;

  /// How many chunks may be processing before capture must stop.
  ///
  /// **Not a defensive default — there is a real path that stacks jobs.**
  /// Normal operation has at most one: a boundary every 600 s against roughly
  /// 12 s of processing. But Chapter 5.4 §2 forces an early boundary whenever
  /// free space is critically low, and Mission 3.3 polls that every 5 seconds.
  /// A device that stays below the threshold therefore produces a boundary
  /// every poll, each starting a job that outlives the next two boundaries.
  /// Nothing else bounds that.
  ///
  /// Three, chosen rather than transcribed — no chapter gives a number. One is
  /// normal, two is a transient hiccup, and three sustained means processing
  /// is durably behind capture. At that point continuing to capture makes the
  /// situation strictly worse: it adds files to a device already failing to
  /// keep up, on a disk already near its limit in the case that causes it.
  static const int maximumConcurrentProcessing = 3;

  /// `Idle` → `Ready`, the Checklist edge (BR-04).
  ///
  /// The only way into `Ready`, and `Ready` is the only way into `Recording`.
  /// The lifecycle performs no checklist check of its own — Chapter 5.1 §3
  /// assigns that to the Checklist and says it is *"not re-checked
  /// redundantly here"*.
  static RecordingState? onChecklistPassed(
    RecordingState state,
    RecordingSession session,
  ) {
    return state is RecordingStateIdle
        ? RecordingState.ready(session: session)
        : null;
  }

  /// `Ready` → `Recording`, the Collector tapping Start.
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

  /// Capture has stopped for the current chunk — the file is closed.
  ///
  /// **This is the edge Mission 3.4.5 changed.** It is called once
  /// `stopVideoRecording()` has returned, which per Mission 3.4.4's reading of
  /// `camera_android_camerax` means the moov atom is written, the handle is
  /// closed and `videoCapture` is unbound. The file is complete on disk and
  /// the camera is free, so there is nothing to wait for before capturing
  /// again.
  ///
  /// [job] carries the identity minted for the chunk that just ended —
  /// see [nextJob]. Where the machine goes depends only on [reason]:
  ///
  /// - [ChunkBoundaryReason.automaticBoundary] returns to `Recording` for
  ///   chunk N+1 of the same session, with [job] added to the processing set.
  ///   BR-05 is intact: the boundary was a real Stop producing a complete
  ///   file, not a slice.
  /// - [ChunkBoundaryReason.collectorStop] enters `Finalizing` to drain.
  ///
  /// **Capacity is checked here.** If adding [job] would exceed
  /// [maximumConcurrentProcessing], an automatic boundary is converted into a
  /// stop: the session drains rather than continuing to capture ahead of work
  /// it cannot finish.
  ///
  /// A short final chunk is neither padded nor discarded — Chapter 5.3 §4 and
  /// Chapter 5.6 §3 both say so, and no duration is consulted here.
  static RecordingState? onCaptureStopped(
    RecordingState state,
    ChunkBoundaryReason reason,
    ChunkProcessingJob job,
    DateTime now,
  ) {
    if (state is! RecordingStateRecording) {
      return null;
    }

    final List<ChunkProcessingJob> processing = <ChunkProcessingJob>[
      ...state.processing,
      job,
    ];

    final bool atCapacity =
        processing.length >= maximumConcurrentProcessing;
    final bool continues =
        reason == ChunkBoundaryReason.automaticBoundary && !atCapacity;

    if (!continues) {
      // Two different endings land here, and the difference matters to the
      // Collector: one they asked for, and one the device imposed on them.
      return RecordingState.finalizing(
        session: state.session,
        processing: processing,
        endCause: atCapacity && reason == ChunkBoundaryReason.automaticBoundary
            ? SessionEndCause.processingCapacityReached
            : SessionEndCause.collectorStop,
        failed: state.failed,
      );
    }

    return RecordingState.recording(
      session: state.session,
      sequenceIndex: state.sequenceIndex + 1,
      chunkStartedAt: now,
      processing: processing,
      failed: state.failed,
    );
  }

  /// A background job finished — successfully, or terminally failed.
  ///
  /// Legal from both `Recording` and `Finalizing`, which is the fifth edge.
  /// The job leaves the processing set either way; [cause] non-null records a
  /// terminal failure per Chapter 5.13 §1's *"Terminal (device-side)"* class,
  /// which is *"not retried automatically"* and *"surfaces immediately as
  /// Failed with a specific, named cause"*.
  ///
  /// **A failure does not stop a live recording.** Chapter 5.13 §1 puts the
  /// outcome on the chunk, not the session: a Failed chunk waits for the
  /// Collector's Retry (C-11, FR-UPL-07). Ending a capture that is still
  /// working because an earlier chunk's hash failed would destroy good footage
  /// to report a bad one.
  ///
  /// From `Finalizing`, emptying the set ends the session.
  static RecordingState? onChunkProcessed(
    RecordingState state, {
    required String chunkId,
    ErrorCode? cause,
  }) {
    final List<ChunkProcessingJob> before = state.processingJobs;
    final bool known = before.any(
      (ChunkProcessingJob j) => j.chunkId == chunkId,
    );
    if (!known) {
      // Not a job this state is waiting on — a duplicate completion, or one
      // belonging to a session that has already ended. Ignored, like every
      // other race in this machine.
      return null;
    }

    final ChunkProcessingJob done = before.firstWhere(
      (ChunkProcessingJob j) => j.chunkId == chunkId,
    );
    final List<ChunkProcessingJob> remaining = before
        .where((ChunkProcessingJob j) => j.chunkId != chunkId)
        .toList();
    final List<FailedChunk> failed = cause == null
        ? state.failedChunks
        : <FailedChunk>[
            ...state.failedChunks,
            FailedChunk(
              chunkId: done.chunkId,
              sequenceIndex: done.sequenceIndex,
              cause: cause,
            ),
          ];

    return switch (state) {
      RecordingStateRecording() => RecordingState.recording(
        session: state.session,
        sequenceIndex: state.sequenceIndex,
        chunkStartedAt: state.chunkStartedAt,
        processing: remaining,
        failed: failed,
      ),
      // The cause survives the drain. It is needed *after* Idle is reached,
      // which is when the Collector is looking at a stopped recording.
      RecordingStateFinalizing() when remaining.isEmpty =>
        RecordingState.idle(
          lastCompletedSession: state.session,
          endCause: state.endCause,
          failed: failed,
        ),
      RecordingStateFinalizing() => RecordingState.finalizing(
        session: state.session,
        processing: remaining,
        endCause: state.endCause,
        failed: failed,
      ),
      _ => null,
    };
  }

  /// Mints the identity for the chunk currently being captured.
  ///
  /// Called at capture-stop, alongside [onCaptureStopped], so both identity
  /// fields are fixed at the same instant and neither depends on when
  /// processing finishes.
  ///
  /// **`sequence_index` cannot collide or skip**, and the reason is
  /// structural rather than defended. It is read from the `Recording` state,
  /// which exists once per captured chunk: the plugin permits exactly one
  /// recording at a time — `startVideoCapturing` returns early while
  /// `recording != null`, and `stopVideoRecording` clears it only after
  /// finalization — so captures are strictly serial. One capture, one stop,
  /// one increment, in order. Completion order may differ from start order and
  /// that changes nothing, because the index is never derived from completion.
  static ChunkProcessingJob? nextJob(
    RecordingState state, {
    required String chunkId,
    required String filePath,
    required DateTime now,
  }) {
    if (state is! RecordingStateRecording) {
      return null;
    }
    return ChunkProcessingJob(
      chunkId: chunkId,
      sequenceIndex: state.sequenceIndex,
      filePath: filePath,
      startedAt: now,
    );
  }
}
