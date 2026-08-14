import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_finalizer.dart';
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

  ({
    ProviderContainer container,
    _FakeFinalizer finalizer,
    _FakeTimers timers,
  })
  build({Exception? finalizerThrows, Completer<void>? gate}) {
    final _FakeFinalizer finalizer = _FakeFinalizer(
      throws: finalizerThrows,
      gate: gate,
    );
    final _FakeTimers timers = _FakeTimers();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        chunkFinalizerProvider.overrideWithValue(finalizer),
        sessionIdGeneratorProvider.overrideWithValue(_FixedIds()),
        boundaryTimerFactoryProvider.overrideWithValue(timers.create),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, finalizer: finalizer, timers: timers);
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
    test('the session id is generated once, at Checklist-passed', () {
      final ProviderContainer c = build().container;

      notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0);

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
      notifierOf(c).checklistPassed(zoomFactor: 0.6, now: t0);
      notifierOf(c).start(now: t0);

      await notifierOf(c).stop(now: t0);

      expect(
        (stateOf(c) as RecordingStateIdle).lastCompletedSession!.zoomFactor,
        0.6,
      );
    });
  });

  group('BR-04 — Recording is unreachable without the Checklist', () {
    test('Start from Idle is refused and changes nothing', () {
      final ProviderContainer c = build().container;

      expect(notifierOf(c).start(now: t0), isFalse);
      expect(stateOf(c), isA<RecordingStateIdle>());
    });

    test('a second Checklist pass does not mint a second session', () {
      final ProviderContainer c = build().container;
      notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0);

      expect(notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0), isFalse);
      expect(stateOf(c).activeSession!.sessionId, 'sess_0001');
    });
  });

  group('the BR-06 boundary produces an internal Stop', () {
    test('the timer is armed for ten minutes when recording starts', () {
      final ({
        ProviderContainer container,
        _FakeFinalizer finalizer,
        _FakeTimers timers,
      })
      f = build();
      notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);

      expect(f.timers.armed, isEmpty, reason: 'Ready does not capture yet');

      notifierOf(f.container).start(now: t0);

      expect(f.timers.armed, <Duration>[RecordingLifecycle.chunkDuration]);
    });

    test('the boundary finalizes and resumes, same session, next '
        'index', () async {
      final ({
        ProviderContainer container,
        _FakeFinalizer finalizer,
        _FakeTimers timers,
      })
      f = build();
      notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(f.container).start(now: t0);
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
      final ({
        ProviderContainer container,
        _FakeFinalizer finalizer,
        _FakeTimers timers,
      })
      f = build();
      notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(f.container).start(now: t0);

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
      final ({
        ProviderContainer container,
        _FakeFinalizer finalizer,
        _FakeTimers timers,
      })
      f = build();
      notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(f.container).start(now: t0);

      await notifierOf(f.container).stop(now: t0);

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
      final ({
        ProviderContainer container,
        _FakeFinalizer finalizer,
        _FakeTimers timers,
      })
      f = build();
      notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(f.container).start(now: t0);

      await notifierOf(f.container).stop(now: t0);
      await f.timers.fireLatestRegardlessOfCancellation();

      expect(f.finalizer.calls, 1, reason: 'the second Stop found no chunk');
      expect(stateOf(f.container), isA<RecordingStateIdle>());
    });

    test('a second Stop during an in-flight finalization is ignored', () async {
      final Completer<void> gate = Completer<void>();
      final ({
        ProviderContainer container,
        _FakeFinalizer finalizer,
        _FakeTimers timers,
      })
      f = build(gate: gate);
      notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(f.container).start(now: t0);

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

  group('when finalization fails', () {
    StorageException diskFull() => const StorageException(
      errorCode: ErrorCode.storageWriteFailed,
      message: 'disk full',
    );

    test('the failure is returned, not pushed into the state union', () async {
      // Ch. 5.3 §2's diagram has no error box, and the union carries the
      // chapter's four states only. A failed chunk is the outcome of one
      // operation — the shape AuthNotifier already uses.
      final ProviderContainer c = build(finalizerThrows: diskFull()).container;
      notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(c).start(now: t0);

      final Failure? failure = await notifierOf(c).stop(now: t0);

      expect(failure, isNotNull);
      expect(failure!.code, ErrorCode.storageWriteFailed);
    });

    test('the machine stays in Finalizing rather than advancing', () async {
      // BR-07: a chunk is persisted before anything proceeds. Resuming
      // Recording over a chunk that never reached disk is the exact failure
      // that rule exists to prevent, so parking is correct here. Recovering
      // is Ch. 5.13's retry strategy, which needs 3.7's storage layer.
      final ProviderContainer c = build(finalizerThrows: diskFull()).container;
      notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(c).start(now: t0);

      await notifierOf(c).stop(now: t0);

      expect(stateOf(c), isA<RecordingStateFinalizing>());
      expect(
        (stateOf(c) as RecordingStateFinalizing).sequenceIndex,
        0,
        reason: 'the index must not advance over an unpersisted chunk',
      );
    });

    test('a parked Finalizing has no way out through the public API', () async {
      // The dead-end reported at the end of Mission 3.2, asserted rather than
      // described. `RecordingLifecycle.onChunkPersisted` *is* a legal edge out
      // of Finalizing — that is how a successful chunk advances — but nothing
      // the notifier exposes calls it once finalization has failed, so the
      // machine is stuck until Ch. 5.13's retry and Ch. 5.3 §5's crash rule
      // arrive with 3.7's storage layer.
      //
      // This test is expected to change when that lands. It exists so the
      // change is deliberate and visible, instead of a limitation that
      // quietly stops being true.
      final ProviderContainer c = build(finalizerThrows: diskFull()).container;
      notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(c).start(now: t0);
      await notifierOf(c).stop(now: t0);

      final RecordingState parked = stateOf(c);
      expect(parked, isA<RecordingStateFinalizing>());

      expect(
        notifierOf(c).checklistPassed(zoomFactor: 0.5, now: t0),
        isFalse,
        reason: 'a new session must not start over an unpersisted chunk',
      );
      expect(notifierOf(c).start(now: t0), isFalse);
      expect(
        await notifierOf(c).stop(now: t0),
        isNull,
        reason: 'ignored as a repeat, not reported as a new failure',
      );

      expect(stateOf(c), parked, reason: 'nothing moved the machine');
    });

    test('a failed boundary does not resume recording', () async {
      final ({
        ProviderContainer container,
        _FakeFinalizer finalizer,
        _FakeTimers timers,
      })
      f = build(finalizerThrows: diskFull());
      notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(f.container).start(now: t0);

      await f.timers.fire();

      expect(stateOf(f.container), isA<RecordingStateFinalizing>());
    });
  });

  group('what the finalizer is asked for', () {
    test('each chunk is finalized once, with its own index', () async {
      final ({
        ProviderContainer container,
        _FakeFinalizer finalizer,
        _FakeTimers timers,
      })
      f = build();
      notifierOf(f.container).checklistPassed(zoomFactor: 0.5, now: t0);
      notifierOf(f.container).start(now: t0);

      await f.timers.fire();
      await f.timers.fire();
      await notifierOf(f.container).stop(now: t0);

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

/// Records what it was asked to finalize, and optionally stalls or fails.
class _FakeFinalizer implements ChunkFinalizer {
  _FakeFinalizer({this.throws, this.gate});

  final Exception? throws;
  final Completer<void>? gate;

  int calls = 0;
  final List<int> indices = <int>[];
  final List<String> sessionIds = <String>[];

  @override
  Future<void> finalizeChunk({
    required RecordingSession session,
    required int sequenceIndex,
  }) async {
    calls += 1;
    indices.add(sequenceIndex);
    sessionIds.add(session.sessionId);
    if (gate != null) {
      await gate!.future;
    }
    if (throws != null) {
      throw throws!;
    }
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
