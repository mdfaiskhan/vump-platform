import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/core/identity/providers/identity_ports.dart';
import 'package:mobile/core/identity/selected_task.dart';
import 'package:mobile/features/recording/domain/entities/chunk_boundary_reason.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_finalizer.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_id_generator.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_store.dart';
import 'package:mobile/features/recording/domain/repositories/free_space_reader.dart';
import 'package:mobile/features/recording/domain/repositories/recording_pipeline.dart';
import 'package:mobile/features/recording/domain/repositories/session_id_generator.dart';

/// The chunk finalizer, overridden at the composition root.
///
/// Unimplemented rather than defaulted, for the reason ADR-022 gives and
/// `authRepositoryProvider` already follows: a default would have to name a
/// concrete class in `data/`, which is the import `application/` may not make.
final Provider<ChunkFinalizer> chunkFinalizerProvider =
    Provider<ChunkFinalizer>(
      (Ref ref) => throw UnimplementedError(
        'chunkFinalizerProvider must be overridden with a ChunkFinalizer. '
        "Its implementation is Volume 3 Ch. 3.9 §4's FinalizeChunkUseCase, "
        'which arrives with Chapters 5.5, 5.7 and 5.9.',
      ),
    );

/// The local store, overridden at the composition root.
///
/// Read here only to write FR-SES-02's session status when a session drains.
/// Every chunk write goes through [chunkFinalizerProvider] instead, so this
/// notifier never persists a chunk itself.
final Provider<ChunkStore> chunkStoreProvider = Provider<ChunkStore>(
  (Ref ref) => throw UnimplementedError(
    'chunkStoreProvider must be overridden with a ChunkStore. '
    'features/recording/data/ provides IsarChunkStore.',
  ),
);

/// Schedules the BR-06 chunk boundary.
///
/// Matches `Timer`'s own constructor, so the production binding is the
/// constructor itself and nothing wraps it.
typedef BoundaryTimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// The timer used for the 10-minute boundary.
///
/// Injected so the boundary can be driven directly in tests. The project has
/// no `fake_async` dependency and adding one to control `Timer` would be a
/// dependency admission (ADR-030) in service of a test — inverting it costs a
/// typedef, and it is the same substitution `CameraCapabilityProbeImpl` uses
/// for `availableCameras` (Mission 3.1).
final Provider<BoundaryTimerFactory> boundaryTimerFactoryProvider =
    Provider<BoundaryTimerFactory>((Ref ref) => Timer.new);

/// The capture pipeline, overridden at the composition root.
final Provider<RecordingPipeline> recordingPipelineProvider =
    Provider<RecordingPipeline>(
      (Ref ref) => throw UnimplementedError(
        'recordingPipelineProvider must be overridden with a '
        'RecordingPipeline. features/recording/data/ provides '
        'CameraRecordingPipeline.',
      ),
    );

/// The free-space reader, overridden at the composition root.
final Provider<FreeSpaceReader> freeSpaceReaderProvider =
    Provider<FreeSpaceReader>(
      (Ref ref) => throw UnimplementedError(
        'freeSpaceReaderProvider must be overridden with a FreeSpaceReader. '
        'features/recording/data/ provides FreeSpaceChannel.',
      ),
    );

/// The timer used to poll free space. Injected for the same reason as
/// [boundaryTimerFactoryProvider].
final Provider<PeriodicTimerFactory> storageTimerFactoryProvider =
    Provider<PeriodicTimerFactory>((Ref ref) => Timer.periodic);

/// Schedules the repeating free-space check.
typedef PeriodicTimerFactory =
    Timer Function(Duration interval, void Function(Timer timer) callback);

/// The chunk-id source, overridden at the composition root.
///
/// A port rather than a package: `uuid` is not in this project's dependency
/// tree at all, and adding it would be a full ADR-030 admission. Same
/// inversion Mission 3.2 used for session ids after the same check.
final Provider<ChunkIdGenerator> chunkIdGeneratorProvider =
    Provider<ChunkIdGenerator>(
      (Ref ref) => throw UnimplementedError(
        'chunkIdGeneratorProvider must be overridden with a '
        'ChunkIdGenerator. See Volume 5 Ch. 5.14 §3 for the UUID '
        'requirement, and Ch. 5.13 §4 for why it is never recomputed.',
      ),
    );

/// The session-id source, overridden at the composition root.
final Provider<SessionIdGenerator> sessionIdGeneratorProvider =
    Provider<SessionIdGenerator>(
      (Ref ref) => throw UnimplementedError(
        'sessionIdGeneratorProvider must be overridden with a '
        'SessionIdGenerator. See Volume 5 Ch. 5.14 §3 for the UUID '
        'requirement.',
      ),
    );

/// Volume 3 Chapter 3.9's `RecordingNotifier` — Chapter 5.3's state machine,
/// driven.
///
/// Chapter 3.9 §4 traces a Stop and puts this class in the State layer:
/// *"the `RecordingNotifier` receives the stop intent and updates its own
/// state to 'finalizing' so the UI can show the brief Local Processing state
/// (C-10)"*, with the actual work below it. That division is exactly what this
/// class implements — it owns the transitions and the timer, and delegates the
/// work to [ChunkFinalizer].
///
/// ## Why `Notifier` and not `AsyncNotifier`
///
/// `AuthNotifier` is an `AsyncNotifier` because a session has to be restored
/// before anything is known — there is a genuine loading state. A recording
/// session has none: the machine starts `Idle` synchronously and every
/// subsequent state is a fact, not a pending answer. `Finalizing` already *is*
/// the "work in progress" state Chapter 5.3 names, so wrapping the machine in
/// `AsyncValue` would give the UI two ways to spell one thing — the mistake
/// `AuthState` avoided by declining to carry `Session.unknown`.
///
/// ## Failure is returned, not pushed into state
///
/// [stop] and the internal boundary return a [Failure] rather than writing an
/// error state, matching `AuthNotifier`. A chunk that fails to finalize is the
/// outcome of one operation; it is not a new lifecycle state, and Chapter 5.3
/// §2's diagram has no error box. Keeping the union to the chapter's four
/// states is the point.
class RecordingNotifier extends Notifier<RecordingState> {
  Timer? _boundaryTimer;
  Timer? _storageTimer;

  /// True while a chunk's capture is being handed over, so a second attempt
  /// cannot start one.
  ///
  /// Chapter 5.6 §3 requires that *"a chunk is never accidentally
  /// double-finalized"* when a manual Stop and the automatic boundary land
  /// together. Cancelling the timer closes most of that race; this closes the
  /// rest, where the timer's callback had already been scheduled.
  ///
  /// It guards the **capture handover only**, not background processing —
  /// since Mission 3.4.5 several chunks may legitimately be processing at
  /// once, bounded by [RecordingLifecycle.maximumConcurrentProcessing].
  bool _endingChunk = false;

  ChunkFinalizer get _finalizer => ref.read(chunkFinalizerProvider);
  RecordingPipeline get _pipeline => ref.read(recordingPipelineProvider);

  @override
  RecordingState build() {
    ref.onDispose(() {
      _cancelBoundaryTimer();
      _cancelStorageTimer();
    });
    return const RecordingState.idle();
  }

  /// How often free space is checked while recording.
  ///
  /// Volume 5 Chapter 5.4 §2 asks the buffered writer to check *"on every
  /// flush"*. The `camera` plugin exposes no flush — its controller has no
  /// flush, buffer, segment or split API at all — so the check is driven by a
  /// timer instead, which A-058 records as a deviation from the chapter's
  /// mechanism rather than its intent.
  ///
  /// Five seconds. At Chapter 5.2 §1's bitrate — 8,000 kbps video plus 128
  /// kbps audio, about 1.02 MB/s — that is roughly 5 MB written between
  /// checks, negligible against [_lowStorageThresholdBytes]. `StatFs` is one
  /// syscall, so there is no reason to poll less often, and nothing to gain by
  /// polling more.
  static const Duration storagePollInterval = Duration(seconds: 5);

  /// Free space below which an early chunk boundary is forced.
  ///
  /// **Derived, not invented.** FR-CHK-02 gates recording on *"sufficient free
  /// local storage for at least one full chunk"*, so one full chunk is the
  /// unit the product already reasons in, and the mid-recording rule uses the
  /// same one — the pipeline never allows less headroom than the Checklist
  /// demanded before it started.
  ///
  /// The derivation moved to [RecordingLifecycle.oneChunkBytes] at Mission
  /// 3.8, when the Checklist needed the same number. One constant, two
  /// callers — the pipeline can no longer allow less headroom than the
  /// Checklist demanded, because they read the same field.
  static const int _lowStorageThresholdBytes = RecordingLifecycle.oneChunkBytes;

  /// The Checklist passed (BR-04) — generate the session and become `Ready`.
  ///
  /// [zoomFactor] is the factor resolved from Chapter 5.1's ladder, already
  /// decided by the Checklist. The lifecycle takes the number and does not
  /// revisit the verdict (Chapter 5.1 §3).
  ///
  /// Opens the camera as part of the transition, because Chapter 5.3 §3
  /// defines `Ready` as *"Checklist (C-07) has passed; **camera is
  /// initialized** (Chapter 5.1) but not yet recording"*. Asynchronous since
  /// Mission 3.4.5 for that reason.
  ///
  /// Returns null on success, or the [Failure] to render. The machine stays
  /// `Idle` if the camera cannot be opened — a `Ready` whose camera is not
  /// open would be a claim the rest of the machine trusts and acts on.
  Future<Failure?> checklistPassed({
    required double zoomFactor,
    required DateTime now,
  }) async {
    // Read ONCE, here, and carried on the session — F38. Reading it again at
    // each chunk boundary would let a selection that changed mid-recording
    // attribute two chunks of one session to two different Tasks, which is
    // worse than an unattributed chunk: it is attributed and wrong.
    //
    // Null when nothing was selected. `PlatformTaskContext` then reports both
    // ids as `MetadataIdentity.unsourced` and A-068's Guard 1 refuses the
    // chunk at upload, which is the correct outcome rather than a guess.
    final SelectedTask? selection = ref.read(selectedTaskProvider);

    final RecordingSession session = RecordingSession(
      sessionId: ref.read(sessionIdGeneratorProvider).newSessionId(),
      taskId: selection?.taskId,
      projectId: selection?.projectId,
      zoomFactor: zoomFactor,
      startedAt: now,
    );

    final RecordingState? next = RecordingLifecycle.onChecklistPassed(
      state,
      session,
    );
    if (next == null) {
      return null;
    }

    try {
      await _pipeline.openSession(zoomFactor: zoomFactor);
    } on AppException catch (exception) {
      return Failure.fromException(exception);
    }
    state = next;
    return null;
  }

  /// The Collector tapped Start.
  ///
  /// Begins chunk [RecordingLifecycle.firstSequenceIndex] and starts the
  /// 10-minute timer that produces the internal Stop.
  Future<Failure?> start({required DateTime now}) async {
    final RecordingState? next = RecordingLifecycle.onStart(state, now);
    if (next == null) {
      return null;
    }

    try {
      await _pipeline.startChunk();
    } on AppException catch (exception) {
      return Failure.fromException(exception);
    }
    state = next;
    _startBoundaryTimer();
    _startStorageWatch();
    return null;
  }

  /// The Collector tapped Stop — finalize this chunk and end the session.
  ///
  /// Returns null on success, or the [Failure] to render.
  Future<Failure?> stop({required DateTime now}) {
    return _endChunk(ChunkBoundaryReason.collectorStop, now);
  }

  /// Ends the current chunk's capture and, if the session continues, starts
  /// the next one immediately.
  ///
  /// **This is the method Mission 3.4.5 rewrote.** Mission 3.2 awaited the
  /// whole of finalization here before resuming, which left the camera idle
  /// for its duration — roughly twelve seconds of checksum, measured in
  /// Mission 3.4. Mission 3.4.4 established that the wait was never a hardware
  /// constraint: `stopVideoRecording()` returns only after
  /// `VideoRecordEventFinalize`, so the `.mp4` is closed and complete and the
  /// camera is free before any processing starts. BR-07 requires persistence
  /// before **upload**, not before the next recording.
  ///
  /// So the order here is: stop capture, mint the chunk's identity, restart
  /// capture, and only then hand the closed file to background processing. The
  /// gap a Collector loses is one use-case bind cycle rather than a checksum.
  Future<Failure?> _endChunk(ChunkBoundaryReason reason, DateTime now) async {
    if (_endingChunk) {
      return null;
    }
    final RecordingState current = state;
    if (current is! RecordingStateRecording) {
      // Not recording — a double tap, or a timer that fired as the state was
      // already leaving Recording. Ignoring is the specified outcome
      // (Chapter 5.6 §3).
      return null;
    }

    // Cancelled before the first await: Chapter 5.6 §3 requires the timer stop
    // "the instant a manual Stop begins finalization", and that instant is
    // here, not when the work completes.
    _cancelBoundaryTimer();
    _endingChunk = true;

    final String filePath;
    try {
      filePath = await _pipeline.stopChunk();
    } on AppException catch (exception) {
      _endingChunk = false;
      return Failure.fromException(exception);
    }

    final ChunkProcessingJob? job = RecordingLifecycle.nextJob(
      current,
      chunkId: ref.read(chunkIdGeneratorProvider).newChunkId(),
      filePath: filePath,
      now: now,
    );
    final RecordingState? next = job == null
        ? null
        : RecordingLifecycle.onCaptureStopped(current, reason, job, now);

    if (job == null || next == null) {
      _endingChunk = false;
      return null;
    }
    state = next;

    Failure? failure;
    if (next is RecordingStateRecording) {
      // Chunk N+1 of the same session, starting now rather than in twelve
      // seconds. The storage watch is session-scoped and left running.
      try {
        await _pipeline.startChunk();
        _startBoundaryTimer();
      } on AppException catch (exception) {
        failure = Failure.fromException(exception);
      }
    } else {
      // The session is draining. Capture has ended, so the camera is released
      // and nothing is writing to the volume.
      _cancelStorageTimer();
      try {
        await _pipeline.closeSession();
      } on AppException catch (exception) {
        failure = Failure.fromException(exception);
      }
    }

    _endingChunk = false;

    // Deliberately unawaited — this is the whole point of the mission. The
    // caller's chunk is closed and the next one is already recording.
    //
    // `current.chunkStartedAt` is read from the state *before* the transition,
    // which is the only place the start of the chunk that just ended still
    // exists — `next` already carries the next chunk's start.
    unawaited(
      _processChunk(
        next.activeSession ?? current.session,
        job,
        current.chunkStartedAt,
      ),
    );
    return failure;
  }

  /// Processes one closed chunk, off the capture path.
  ///
  /// A terminal failure marks the chunk and leaves the session alone. Chapter
  /// 5.13 §1 classifies *"Local file missing/corrupted, disk full"* as
  /// **Terminal (device-side)** — *"not retried automatically … surfaces
  /// immediately as Failed with a specific, named cause"* — which is a status
  /// on the chunk, not on the recording. Ending a live capture because an
  /// earlier chunk's checksum failed would destroy footage that is still being
  /// recorded correctly.
  Future<void> _processChunk(
    RecordingSession session,
    ChunkProcessingJob job,
    DateTime chunkStartedAt,
  ) async {
    ErrorCode? cause;
    try {
      await _finalizer.finalizeChunk(
        session: session,
        job: job,
        chunkStartedAt: chunkStartedAt,
      );
    } on AppException catch (exception) {
      cause = exception.errorCode;
    }

    final RecordingState? next = RecordingLifecycle.onChunkProcessed(
      state,
      chunkId: job.chunkId,
      cause: cause,
    );
    if (next == null) {
      return;
    }
    state = next;

    // The drain completed — this is the one instant the end of a session is
    // known, and therefore the only place FR-SES-02's `complete` can be
    // written. Amendment A-063 recorded the gap and named this as its closing
    // point; `ChunkStore.markSessionComplete` is the other half.
    if (next is RecordingStateIdle) {
      await _markSessionComplete(session);
      // The selection belonged to the session that just ended. Leaving it set
      // would let a later recording started by a path that forgot to select
      // inherit this Task — attributed and wrong, rather than refused.
      ref.read(selectedTaskProvider.notifier).clear();
    }
  }

  /// Records FR-SES-02's terminal status, without disturbing the machine.
  ///
  /// A failure here is logged into the returned nothing and deliberately not
  /// escalated: the session is over, every chunk is already persisted with its
  /// metadata, and a status column that still reads `in_progress` misreports
  /// history rather than risking data. Chapter 5.9 reads
  /// `local_chunks.status`, never the session's, so nothing downstream stalls.
  Future<void> _markSessionComplete(RecordingSession session) async {
    try {
      await ref.read(chunkStoreProvider).markSessionComplete(session.sessionId);
    } on AppException {
      return;
    }
  }

  /// Arms the BR-06 timer for the chunk that just began.
  void _startBoundaryTimer() {
    _cancelBoundaryTimer();
    _boundaryTimer = ref.read(boundaryTimerFactoryProvider)(
      RecordingLifecycle.chunkDuration,
      () {
        // The internal, system-triggered Stop of Chapter 5.3 §1. Deliberately
        // unawaited: a Timer callback cannot be awaited by anyone, and the
        // failure is already reported through the return value rather than by
        // throwing out of a callback nobody can catch.
        unawaited(
          _endChunk(ChunkBoundaryReason.automaticBoundary, DateTime.now()),
        );
      },
    );
  }

  void _cancelBoundaryTimer() {
    _boundaryTimer?.cancel();
    _boundaryTimer = null;
  }

  /// Starts watching free space for the duration of the session.
  ///
  /// Armed once per session rather than per chunk: storage pressure does not
  /// reset at a chunk boundary, and re-arming would leave a gap across the
  /// finalization it most needs to cover.
  void _startStorageWatch() {
    _cancelStorageTimer();
    final String? directory = ref
        .read(recordingPipelineProvider)
        .outputDirectory;
    if (directory == null) {
      return;
    }
    _storageTimer = ref.read(storageTimerFactoryProvider)(
      storagePollInterval,
      (Timer _) => unawaited(_checkFreeSpace(directory)),
    );
  }

  /// Forces an early boundary if space has become critically low.
  ///
  /// Chapter 5.4 §2: *"if space becomes critically low mid-chunk, the pipeline
  /// forces an early chunk boundary (**treated exactly like the automatic
  /// 10-minute boundary, Chapter 5.3**)"*. So this reuses Mission 3.2's
  /// internal-Stop pattern unchanged — same [ChunkBoundaryReason], same edge,
  /// same finalization — rather than introducing a parallel mechanism. The
  /// chapter's own words make that the specified behaviour, not a convenience.
  ///
  /// A failed reading is ignored rather than escalated. The pipeline is
  /// mid-chunk and the alternative — aborting a recording because a free-space
  /// syscall failed once — destroys footage to avoid a risk that may not
  /// exist. The next tick tries again five seconds later.
  Future<void> _checkFreeSpace(String directory) async {
    if (state is! RecordingStateRecording) {
      return;
    }
    final int available;
    try {
      available = await ref
          .read(freeSpaceReaderProvider)
          .availableBytes(directory);
    } on AppException {
      return;
    }

    if (available >= _lowStorageThresholdBytes) {
      return;
    }
    await _endChunk(ChunkBoundaryReason.automaticBoundary, DateTime.now());
  }

  void _cancelStorageTimer() {
    _storageTimer?.cancel();
    _storageTimer = null;
  }
}

/// The live recording lifecycle.
final NotifierProvider<RecordingNotifier, RecordingState>
recordingNotifierProvider = NotifierProvider<RecordingNotifier, RecordingState>(
  RecordingNotifier.new,
);
