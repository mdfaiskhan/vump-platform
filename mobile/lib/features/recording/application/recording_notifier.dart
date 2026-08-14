import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/recording/domain/entities/chunk_boundary_reason.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_finalizer.dart';
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

  /// True while a finalization is in flight, so a second one cannot start.
  ///
  /// Chapter 5.6 §3 requires that *"a chunk is never accidentally
  /// double-finalized"* when a manual Stop and the automatic boundary land
  /// together. Cancelling the timer closes most of that race; this closes the
  /// rest, where the timer's callback had already been scheduled.
  bool _finalizing = false;

  ChunkFinalizer get _finalizer => ref.read(chunkFinalizerProvider);

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
  /// One chunk at spec bitrate: (8,000 + 128) kbps ÷ 8 = 1,016 kB/s, times
  /// 600 seconds, is 609.6 MB. Rounded to 610 MB.
  static const int _lowStorageThresholdBytes = 610 * 1000 * 1000;

  /// The Checklist passed (BR-04) — generate the session and become `Ready`.
  ///
  /// [zoomFactor] is the factor resolved from Chapter 5.1's ladder, already
  /// decided by the Checklist. The lifecycle takes the number and does not
  /// revisit the verdict (Chapter 5.1 §3).
  ///
  /// Returns false if the machine was not `Idle`, in which case nothing
  /// changed.
  bool checklistPassed({required double zoomFactor, required DateTime now}) {
    final RecordingSession session = RecordingSession(
      sessionId: ref.read(sessionIdGeneratorProvider).newSessionId(),
      zoomFactor: zoomFactor,
      startedAt: now,
    );

    final RecordingState? next = RecordingLifecycle.onChecklistPassed(
      state,
      session,
    );
    if (next == null) {
      return false;
    }
    state = next;
    return true;
  }

  /// The Collector tapped Start.
  ///
  /// Begins chunk [RecordingLifecycle.firstSequenceIndex] and starts the
  /// 10-minute timer that produces the internal Stop.
  bool start({required DateTime now}) {
    final RecordingState? next = RecordingLifecycle.onStart(state, now);
    if (next == null) {
      return false;
    }
    state = next;
    _startBoundaryTimer();
    _startStorageWatch();
    return true;
  }

  /// The Collector tapped Stop — finalize this chunk and end the session.
  ///
  /// Returns null on success, or the [Failure] to render.
  Future<Failure?> stop({required DateTime now}) {
    return _finalizeCurrentChunk(ChunkBoundaryReason.collectorStop, now);
  }

  /// Runs one finalization and takes the edge out the other side.
  ///
  /// The single path for both kinds of Stop, because Chapter 5.3 §3 says
  /// finalization is *"the same finalization path whether triggered
  /// automatically or manually"*. Only [reason] differs, and it is consulted
  /// once, at the end, by [RecordingLifecycle.onChunkPersisted].
  Future<Failure?> _finalizeCurrentChunk(
    ChunkBoundaryReason reason,
    DateTime now,
  ) async {
    if (_finalizing) {
      return null;
    }

    final RecordingState? finalizing = RecordingLifecycle.onStop(state, reason);
    if (finalizing == null) {
      // Not recording — a double tap, or a timer that fired as the state was
      // already leaving Recording. Ignoring is the specified outcome.
      return null;
    }

    // Cancelled before the await, not after: Chapter 5.6 §3 requires the timer
    // to stop "the instant a manual Stop begins finalization", and the instant
    // it begins is here, not when it completes.
    _cancelBoundaryTimer();
    _finalizing = true;
    state = finalizing;

    final RecordingStateFinalizing current = finalizing
        as RecordingStateFinalizing;

    try {
      await _finalizer.finalizeChunk(
        session: current.session,
        sequenceIndex: current.sequenceIndex,
      );
    } on AppException catch (exception) {
      // The chunk did not reach disk, so BR-07's precondition for advancing is
      // unmet and the machine must not take the edge. It stays in Finalizing:
      // the alternative is resuming Recording over a chunk that was never
      // persisted, which is the exact failure BR-07 exists to prevent.
      //
      // Recovering from here — retry, or discard and continue — is Chapter
      // 5.13's retry strategy and Chapter 5.3 §5's crash-recovery rule, both
      // of which need the local storage layer that does not exist yet.
      _finalizing = false;
      return Failure.fromException(exception);
    }

    _finalizing = false;

    final RecordingState? next = RecordingLifecycle.onChunkPersisted(
      state,
      now,
    );
    if (next != null) {
      state = next;
      if (next is RecordingStateRecording) {
        // Chunk N+1 of the same session — re-arm the chunk timer. The
        // storage watch is session-scoped and left running.
        _startBoundaryTimer();
      } else {
        // The session ended; nothing is writing to the volume now.
        _cancelStorageTimer();
      }
    }
    return null;
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
          _finalizeCurrentChunk(
            ChunkBoundaryReason.automaticBoundary,
            DateTime.now(),
          ),
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
    final String? directory = ref.read(recordingPipelineProvider)
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
      available = await ref.read(freeSpaceReaderProvider).availableBytes(
        directory,
      );
    } on AppException {
      return;
    }

    if (available >= _lowStorageThresholdBytes) {
      return;
    }
    await _finalizeCurrentChunk(
      ChunkBoundaryReason.automaticBoundary,
      DateTime.now(),
    );
  }

  void _cancelStorageTimer() {
    _storageTimer?.cancel();
    _storageTimer = null;
  }
}

/// The live recording lifecycle.
final NotifierProvider<RecordingNotifier, RecordingState>
recordingNotifierProvider =
    NotifierProvider<RecordingNotifier, RecordingState>(RecordingNotifier.new);
