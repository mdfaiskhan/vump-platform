import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
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

/// The notifier driving Chapter 5.3's machine — timer, races and failure.
///
/// The transitions themselves are a pure table in
/// `recording_lifecycle_test.dart`. What is only observable here is what the
/// notifier owns: arming and cancelling the BR-06 boundary, Chapter 5.6 §3's
/// double-finalize race, and what happens when finalization fails.
///
/// The boundary timer is driven through an injected factory rather than fake
/// time, so `fire()` below *is* the ten-minute boundary arriving.
void main() {
  final DateTime t0 = DateTime.utc(2026, 8, 15, 9);

  _Harness build({
    Exception? finalizerThrows,
    Completer<void>? gate,
    int freeBytes = 50 * 1000 * 1000 * 1000,
    Exception? freeSpaceThrows,
    String? outputDirectory = '/data/user/0/com.example.mobile/files',
  }) {
    final _FakeFinalizer finalizer = _FakeFinalizer(
      throws: finalizerThrows,
      gate: gate,
    );
    final _FakeStore store = _FakeStore();
    final _FakeTimers timers = _FakeTimers();
    final _FakeStorageTimers storageTimers = _FakeStorageTimers();
    final _FakeFreeSpace freeSpace = _FakeFreeSpace(
      bytes: freeBytes,
      throws: freeSpaceThrows,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        chunkFinalizerProvider.overrideWithValue(finalizer),
        sessionIdGeneratorProvider.overrideWithValue(_FixedIds()),
        chunkIdGeneratorProvider.overrideWithValue(_FixedChunkIds()),
        boundaryTimerFactoryProvider.overrideWithValue(timers.create),
        recordingPipelineProvider.overrideWithValue(
          _FakePipeline(outputDirectory),
        ),
        freeSpaceReaderProvider.overrideWithValue(freeSpace),
        storageTimerFactoryProvider.overrideWithValue(storageTimers.create),
        chunkStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return _Harness(
      container: container,
      finalizer: finalizer,
      timers: timers,
      storageTimers: storageTimers,
      freeSpace: freeSpace,
      store: store,
    );
  }

  RecordingNotifier notifierOf(ProviderContainer c) =>
      c.read(recordingNotifierProvider.notifier);
  RecordingState stateOf(ProviderContainer c) =>
      c.read(recordingNotifierProvider);

  group('the machine starts idle', () {
    test('a fresh notifier is Idle with no session', () {
      final ProviderContainer c = build().container;

      expect(stateOf(c), isA<RecordingStateIdle>());
      expect(stateOf(c).activeSession, isNull);
    });
  });

  group('session identity', () {
    test('the session id is generated once, at Checklist-passed', () async {
      final ProviderContainer c = build().container;

      await notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0);

      final RecordingSession? session = stateOf(c).activeSession;
      expect(session!.sessionId, 'sess_0001');
      expect(session.zoomFactor, 0.5);
      expect(session.startedAt, t0);
    });

    test('the zoom factor is fixed for the session, not re-read', () async {
      // Ch. 5.2 §1: "fixed for the whole session, never changed
      // mid-recording". Carried across a boundary so a per-chunk re-read
      // would surface as a changed value.
      final ProviderContainer c = build().container;
      await notifierOf(c).checklistPassed(zoomFactor: 0.6, now: t0);
      await notifierOf(c).start(now: t0);

      await notifierOf(c).stop(now: t0);
      await pumpEventQueue();

      expect(
        (stateOf(c) as RecordingStateIdle).lastCompletedSession!.zoomFactor,
        0.6,
      );
    });
  });

  group('BR-04 — Recording is unreachable without the Checklist', () {
    test('Start from Idle is refused and changes nothing', () async {
      final ProviderContainer c = build().container;

      expect(await notifierOf(c).start(now: t0), isNull);
      expect(stateOf(c), isA<RecordingStateIdle>());
    });

    test('a second Checklist pass does not mint a second session', () async {
      final ProviderContainer c = build().container;
      await notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0);

      expect(stateOf(c).activeSession!.sessionId, 'sess_0001');
      expect(stateOf(c).activeSession!.sessionId, 'sess_0001');
    });
  });

  group('the BR-06 boundary produces an internal Stop', () {
    test('the timer is armed for ten minutes when recording starts', () async {
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);

      expect(f.timers.armed, isEmpty, reason: 'Ready does not capture yet');

      await notifierOf(f.container).start(now: t0);

      expect(f.timers.armed, <Duration>[RecordingLifecycle.chunkDuration]);
    });

    test('the boundary finalizes and resumes, same session, next '
        'index', () async {
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);
      final RecordingState opened = stateOf(f.container);
      expect((opened as RecordingStateRecording).sequenceIndex, 0);

      await f.timers.fire();

      final RecordingStateRecording resumed =
          stateOf(f.container) as RecordingStateRecording;
      expect(resumed.sequenceIndex, 1, reason: 'chunk N+1, not back to Idle');
      expect(
        resumed.session.sessionId,
        'sess_0001',
        reason: 'Ch. 5.6 §2: chunking never creates a new session_id',
      );
    });

    test('it re-arms for each chunk, so boundaries keep coming', () async {
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      for (int i = 0; i < 3; i++) {
        await f.timers.fire();
      }

      final RecordingState third = stateOf(f.container);
      expect((third as RecordingStateRecording).sequenceIndex, 3);
      expect(f.finalizer.indices, <int>[0, 1, 2]);
    });
  });

  group('Ch. 5.6 §3 — a chunk is never double-finalized', () {
    test('a manual Stop cancels the pending boundary timer', () async {
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await notifierOf(f.container).stop(now: t0);
      await pumpEventQueue();

      expect(
        f.timers.cancelled,
        1,
        reason: 'cancelled the instant finalization begins',
      );
      expect(f.finalizer.calls, 1);
      expect(stateOf(f.container), isA<RecordingStateIdle>());
    });

    test('a boundary that fires after a Stop finalizes nothing', () async {
      // The race Ch. 5.6 §3 names: the timer's callback was already scheduled
      // when the Collector tapped Stop. Cancellation cannot un-schedule it, so
      // the state guard has to catch it.
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await notifierOf(f.container).stop(now: t0);
      await pumpEventQueue();
      await f.timers.fireLatestRegardlessOfCancellation();

      expect(f.finalizer.calls, 1, reason: 'the second Stop found no chunk');
      expect(stateOf(f.container), isA<RecordingStateIdle>());
    });

    test('a second Stop during an in-flight finalization is ignored', () async {
      final Completer<void> gate = Completer<void>();
      final _Harness f = build(gate: gate);
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      final Future<Failure?> first = notifierOf(f.container).stop(now: t0);
      await pumpEventQueue();
      expect(stateOf(f.container), isA<RecordingStateFinalizing>());

      final Failure? second = await notifierOf(f.container).stop(now: t0);
      expect(second, isNull, reason: 'ignored, not an error');

      gate.complete();
      await first;

      expect(f.finalizer.calls, 1);
    });
  });

  group('Ch. 5.4 §2 — low storage forces an early boundary', () {
    // The chapter says the pipeline "forces an early chunk boundary (treated
    // exactly like the automatic 10-minute boundary, Chapter 5.3)". So the
    // assertions below are that it reuses 3.2's existing Stop pattern — same
    // reason, same edge, same finalization — not a parallel mechanism.

    test(
      'the watch is armed at the poll interval when recording starts',
      () async {
        final _Harness f = build();
        await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
        expect(
          f.storageTimers.armed,
          isEmpty,
          reason: 'Ready is not capturing',
        );

        await notifierOf(f.container).start(now: t0);

        expect(f.storageTimers.armed, <Duration>[
          RecordingNotifier.storagePollInterval,
        ]);
      },
    );

    test('it reads the directory the pipeline is writing to', () async {
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await f.storageTimers.tick();

      expect(f.freeSpace.paths, <String>[
        '/data/user/0/com.example.mobile/files',
      ]);
    });

    test('ample space changes nothing', () async {
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await f.storageTimers.tick();

      expect(f.finalizer.calls, 0);
      expect(stateOf(f.container), isA<RecordingStateRecording>());
    });

    test('space below one chunk forces a boundary and continues the '
        'session', () async {
      // The key assertion: this is an *early boundary*, not a stop. The
      // session survives and chunk N+1 opens, exactly as the 10-minute
      // boundary behaves.
      final _Harness f = build(freeBytes: 100 * 1000 * 1000);
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await f.storageTimers.tick();

      expect(f.finalizer.calls, 1);
      final RecordingState after = stateOf(f.container);
      expect(after, isA<RecordingStateRecording>());
      expect((after as RecordingStateRecording).sequenceIndex, 1);
      expect(after.session.sessionId, 'sess_0001');
    });

    test('the threshold is one full chunk at spec bitrate', () async {
      // Derived from FR-CHK-02's "at least one full chunk", not invented:
      // (8000 + 128) kbps / 8 * 600s = 609.6 MB. Just above passes, just
      // below trips — asserted as a pair so the boundary is pinned.
      //
      // Reads RecordingLifecycle.oneChunkBytes rather than the literal it was
      // written with. Mission 3.8 made that constant the single source for
      // both this threshold and FR-CHK-02's Checklist row, and A-064 §4b
      // records that it is likely to change — a measured chunk came in 4%
      // above the derivation. Against a literal, this test would keep passing
      // while no longer testing the threshold it names.
      final _Harness ample = build(
        freeBytes: RecordingLifecycle.oneChunkBytes,
      );
      await notifierOf(
        ample.container,
      ).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(ample.container).start(now: t0);
      await ample.storageTimers.tick();
      expect(ample.finalizer.calls, 0, reason: 'exactly at the threshold');

      final _Harness scarce = build(
        freeBytes: RecordingLifecycle.oneChunkBytes - 1,
      );
      await notifierOf(
        scarce.container,
      ).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(scarce.container).start(now: t0);
      await scarce.storageTimers.tick();
      expect(scarce.finalizer.calls, 1, reason: 'one byte under');
    });

    test('a failed reading is ignored, not escalated', () async {
      // Aborting a recording because one syscall failed destroys footage to
      // avoid a risk that may not exist. The next tick tries again.
      final _Harness f = build(
        freeSpaceThrows: const StorageException(
          errorCode: ErrorCode.storageUnavailable,
          message: 'statfs failed',
        ),
      );
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await f.storageTimers.tick();

      expect(f.finalizer.calls, 0);
      expect(stateOf(f.container), isA<RecordingStateRecording>());
    });

    test('the watch stops when the session ends', () async {
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await notifierOf(f.container).stop(now: t0);
      await pumpEventQueue();

      expect(f.storageTimers.cancelled, 1);
      expect(f.storageTimers.isArmed, isFalse);
    });

    test('the watch survives a chunk boundary within the session', () async {
      // Storage pressure does not reset at a boundary, so re-arming per chunk
      // would leave a gap across the finalization it most needs to cover.
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await f.timers.fire();

      expect(f.storageTimers.cancelled, 0);
      expect(f.storageTimers.isArmed, isTrue);
    });

    test('nothing is polled once the machine leaves Recording', () async {
      final _Harness f = build(freeBytes: 1);
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);
      await notifierOf(f.container).stop(now: t0);
      await pumpEventQueue();

      // A tick that raced the stop must not finalize anything.
      f.freeSpace.calls = 0;
      await f.storageTimers.tickRegardlessOfCancellation();

      expect(f.freeSpace.calls, 0, reason: 'guarded on Recording');
      expect(f.finalizer.calls, 1, reason: 'only the manual Stop');
    });
  });

  group('when finalization fails', () {
    StorageException diskFull() => const StorageException(
      errorCode: ErrorCode.storageWriteFailed,
      message: 'disk full',
    );

    test('a failed chunk does NOT stop a live recording', () async {
      // The behaviour Mission 3.4.5 changed, and the reason it changed.
      // Ch. 5.13 §1 classifies "Local file missing/corrupted, disk full" as
      // Terminal (device-side) — "not retried automatically ... surfaces
      // immediately as Failed with a specific, named cause". That is a status
      // on the chunk, not on the session: a Failed chunk waits for the
      // Collector's Retry (C-11), it does not end their recording.
      final _Harness f = build(finalizerThrows: diskFull());
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await f.timers.fire();

      final RecordingState after = stateOf(f.container);
      expect(after, isA<RecordingStateRecording>());
      expect(
        after.isCapturing,
        isTrue,
        reason: 'good footage is not discarded',
      );
      expect((after as RecordingStateRecording).sequenceIndex, 1);
      expect(after.failedChunks.single.cause, ErrorCode.storageWriteFailed);
      expect(after.processingJobs, isEmpty, reason: 'the job left the set');
    });

    test('a failed chunk still lets the session end', () async {
      // Mission 3.2's parked-Finalizing dead end, deliberately removed. It
      // asserted that a failed finalization left the machine with no way out,
      // and said in its own comment that it was "expected to change when that
      // lands". It has: a terminal failure now marks the chunk and releases
      // the job, so draining completes and Idle is reached.
      final ProviderContainer c = build(finalizerThrows: diskFull()).container;
      await notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(c).start(now: t0);

      await notifierOf(c).stop(now: t0);
      await pumpEventQueue();

      expect(
        stateOf(c),
        isA<RecordingStateIdle>(),
        reason: 'no longer parked — the dead end is gone',
      );
      expect(stateOf(c).failedChunks.single.sequenceIndex, 0);
      expect(stateOf(c).processingJobs, isEmpty);
    });

    test('a new session can start after a failed one', () async {
      // The practical consequence of removing the dead end: the Collector is
      // not locked out of recording by one bad checksum.
      final ProviderContainer c = build(finalizerThrows: diskFull()).container;
      await notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(c).start(now: t0);
      await notifierOf(c).stop(now: t0);
      await pumpEventQueue();

      expect(
        await notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0),
        isNull,
      );
      expect(stateOf(c), isA<RecordingStateReady>());
      expect(stateOf(c).activeSession!.sessionId, 'sess_0002');
    });

    // REMOVED by Mission 3.4.5: 'a failed boundary does not resume recording'.
    //
    // It asserted the old serialised design, where a failed finalization
    // parked the machine. That behaviour is deliberately gone — Ch. 5.13 §1
    // puts a terminal device-side failure on the chunk, not the session — and
    // 'a failed chunk does NOT stop a live recording' above asserts the
    // replacement. Leaving both would have left two tests demanding opposite
    // outcomes from the same event.
  });

  group('what the finalizer is asked for', () {
    test('each chunk is finalized once, with its own index', () async {
      final _Harness f = build();
      await notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      await notifierOf(f.container).start(now: t0);

      await f.timers.fire();
      await f.timers.fire();
      await notifierOf(f.container).stop(now: t0);
      await pumpEventQueue();

      expect(f.finalizer.indices, <int>[0, 1, 2]);
      expect(
        f.finalizer.sessionIds.toSet(),
        <String>{'sess_0001'},
        reason: 'one session across every boundary',
      );
    });
  });
}

/// Captures scheduled boundaries so a test can fire one on demand.
class _FakeTimers {
  final List<Duration> armed = <Duration>[];
  final List<_FakeTimer> _timers = <_FakeTimer>[];
  int cancelled = 0;

  Timer create(Duration duration, void Function() callback) {
    armed.add(duration);
    final _FakeTimer timer = _FakeTimer(callback, () => cancelled += 1);
    _timers.add(timer);
    return timer;
  }

  /// Fires the newest live timer — the ten-minute boundary arriving.
  Future<void> fire() async {
    final _FakeTimer timer = _timers.lastWhere((_FakeTimer t) => t.isActive);
    timer.run();
    await pumpEventQueue();
  }

  /// Fires the newest timer even if it was cancelled, reproducing a callback
  /// already scheduled when cancellation landed.
  Future<void> fireLatestRegardlessOfCancellation() async {
    _timers.last.run();
    await pumpEventQueue();
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this._callback, this._onCancel);

  final void Function() _callback;
  final void Function() _onCancel;
  bool _active = true;

  void run() => _callback();

  @override
  void cancel() {
    if (_active) {
      _onCancel();
    }
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// The collaborators one test needs, named rather than a five-field record.
class _Harness {
  _Harness({
    required this.container,
    required this.finalizer,
    required this.timers,
    required this.storageTimers,
    required this.freeSpace,
    required this.store,
  });

  final ProviderContainer container;
  final _FakeFinalizer finalizer;
  final _FakeTimers timers;
  final _FakeStorageTimers storageTimers;
  final _FakeFreeSpace freeSpace;
  final _FakeStore store;
}

/// Records FR-SES-02's session-completion writes, and nothing else.
///
/// Only [markSessionComplete] is exercised here: every chunk write goes
/// through the finalizer, which this test suite already fakes.
class _FakeStore implements ChunkStore {
  final List<String> completed = <String>[];

  /// Set to make the write fail, so the notifier's tolerance is observable.
  Exception? throws;

  @override
  Future<void> markSessionComplete(String sessionId) async {
    if (throws != null) {
      throw throws!;
    }
    completed.add(sessionId);
  }

  @override
  Future<void> saveChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkMetadata metadata,
  }) async => throw UnimplementedError();

  @override
  Future<List<String>> recoverableChunkIds() async => <String>[];

  @override
  Future<List<String>> orphanedChunkIds() async => <String>[];
}

/// Stands in for the capture pipeline; only its output directory is read here.
class _FakePipeline implements RecordingPipeline {
  _FakePipeline(this._outputDirectory);

  final String? _outputDirectory;

  @override
  String? get outputDirectory => _outputDirectory;

  @override
  Future<void> openSession({required double zoomFactor}) async {}

  @override
  Future<void> startChunk() async {}

  @override
  Future<String> stopChunk() async => '/chunk.mp4';

  @override
  Future<void> closeSession() async {}
}

/// Reports a fixed free-space figure, or fails on demand.
class _FakeFreeSpace implements FreeSpaceReader {
  _FakeFreeSpace({required this.bytes, this.throws});

  int bytes;
  final Exception? throws;
  int calls = 0;
  final List<String> paths = <String>[];

  @override
  Future<int> availableBytes(String path) async {
    calls += 1;
    paths.add(path);
    if (throws != null) {
      throw throws!;
    }
    return bytes;
  }
}

/// Captures the periodic storage timer so a test can tick it on demand.
class _FakeStorageTimers {
  final List<Duration> armed = <Duration>[];
  final List<_FakePeriodicTimer> _timers = <_FakePeriodicTimer>[];
  int cancelled = 0;

  Timer create(Duration interval, void Function(Timer timer) callback) {
    armed.add(interval);
    final _FakePeriodicTimer timer = _FakePeriodicTimer(
      callback,
      () => cancelled += 1,
    );
    _timers.add(timer);
    return timer;
  }

  bool get isArmed => _timers.any((_FakePeriodicTimer t) => t.isActive);

  /// One poll interval elapsing.
  Future<void> tick() async {
    final _FakePeriodicTimer timer = _timers.lastWhere(
      (_FakePeriodicTimer t) => t.isActive,
    );
    timer.run();
    await pumpEventQueue();
  }

  /// Fires the latest timer even if cancelled, reproducing a callback
  /// already scheduled when cancellation landed.
  Future<void> tickRegardlessOfCancellation() async {
    _timers.last.run();
    await pumpEventQueue();
  }
}

class _FakePeriodicTimer implements Timer {
  _FakePeriodicTimer(this._callback, this._onCancel);

  final void Function(Timer timer) _callback;
  final void Function() _onCancel;
  bool _active = true;

  void run() => _callback(this);

  @override
  void cancel() {
    if (_active) {
      _onCancel();
    }
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// Records what it was asked to finalize, and optionally stalls or fails.
class _FakeFinalizer implements ChunkFinalizer {
  _FakeFinalizer({this.throws, this.gate});

  final Exception? throws;
  final Completer<void>? gate;

  int calls = 0;
  final List<int> indices = <int>[];
  final List<String> sessionIds = <String>[];

  /// The chunk-start instants received, in call order.
  ///
  /// Recorded so a test can assert the notifier passes the start of the chunk
  /// that ended rather than the start of the one now recording — the seam
  /// Mission 3.8 added.
  final List<DateTime> chunkStarts = <DateTime>[];

  @override
  Future<void> finalizeChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required DateTime chunkStartedAt,
  }) async {
    calls += 1;
    indices.add(job.sequenceIndex);
    sessionIds.add(session.sessionId);
    chunkStarts.add(chunkStartedAt);
    if (gate != null) {
      await gate!.future;
    }
    if (throws != null) {
      throw throws!;
    }
  }
}

/// Deterministic chunk ids, so assertions can name a chunk directly.
class _FixedChunkIds implements ChunkIdGenerator {
  int _next = 0;

  @override
  String newChunkId() {
    _next += 1;
    return 'chunk_${_next.toString().padLeft(4, '0')}';
  }
}

/// Deterministic ids, so assertions can name the session directly.
class _FixedIds implements SessionIdGenerator {
  int _next = 0;

  @override
  String newSessionId() {
    _next += 1;
    return 'sess_${_next.toString().padLeft(4, '0')}';
  }
}
