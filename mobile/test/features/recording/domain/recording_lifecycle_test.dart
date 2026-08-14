import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/domain/entities/chunk_boundary_reason.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';

/// Volume 5 Chapter 5.3 §2's diagram, edge by edge.
///
/// The machine is pure, so every transition — including the internal-Stop
/// pattern that is the chapter's key design point — is asserted here with no
/// timer, no camera and no widget tree.
void main() {
  final DateTime t0 = DateTime.utc(2026, 8, 15, 9);
  final DateTime t1 = t0.add(RecordingLifecycle.chunkDuration);
  final DateTime t2 = t1.add(RecordingLifecycle.chunkDuration);

  final RecordingSession session = RecordingSession(
    sessionId: 'sess_e810',
    zoomFactor: 0.5,
    startedAt: t0,
  );

  RecordingState recordingAt(int index, DateTime at) =>
      RecordingState.recording(
        session: session,
        sequenceIndex: index,
        chunkStartedAt: at,
      );

  group('BR-06 and the first index', () {
    test('a chunk is exactly ten minutes', () {
      expect(RecordingLifecycle.chunkDuration, const Duration(minutes: 10));
    });

    test('the first chunk of a session is index 0', () {
      // Ch. 5.6 §2 defers the base to "Volume 4's convention", which does not
      // exist; the chapter's stated default stands. Pinned here because the
      // S3 object key is {sequence_index:04d} and UNIQUE — an off-by-one
      // renames every object in the system.
      expect(RecordingLifecycle.firstSequenceIndex, 0);
    });
  });

  group('Idle → Ready — the BR-04 Checklist edge', () {
    test('the Checklist passing produces Ready with the session', () {
      final RecordingState? next = RecordingLifecycle.onChecklistPassed(
        const RecordingState.idle(),
        session,
      );

      expect(next, isA<RecordingStateReady>());
      expect(next!.activeSession, session);
    });

    test('Ready is the only way in, from Idle only', () {
      // The whole of the lifecycle's BR-04 guarantee is structural: there is
      // no other edge into Ready, and no edge into Recording except from it.
      for (final RecordingState from in <RecordingState>[
        RecordingState.ready(session: session),
        recordingAt(0, t0),
        RecordingState.finalizing(
          session: session,
          sequenceIndex: 0,
          reason: ChunkBoundaryReason.automaticBoundary,
        ),
      ]) {
        expect(
          RecordingLifecycle.onChecklistPassed(from, session),
          isNull,
          reason: '$from must not re-enter Ready',
        );
      }
    });
  });

  group('Ready → Recording — the Collector taps Start', () {
    test('recording opens at the first index', () {
      final RecordingState? next = RecordingLifecycle.onStart(
        RecordingState.ready(session: session),
        t0,
      );

      expect(next, isA<RecordingStateRecording>());
      final RecordingStateRecording recording =
          next! as RecordingStateRecording;
      expect(recording.sequenceIndex, RecordingLifecycle.firstSequenceIndex);
      expect(recording.chunkStartedAt, t0);
      expect(recording.session.sessionId, 'sess_e810');
    });

    test('Start does nothing from Idle — the Checklist has not run', () {
      expect(
        RecordingLifecycle.onStart(const RecordingState.idle(), t0),
        isNull,
        reason: 'BR-04: recording is not permitted until the Checklist passes',
      );
    });

    test('Start does nothing while already recording', () {
      expect(RecordingLifecycle.onStart(recordingAt(0, t0), t1), isNull);
    });
  });

  group('Recording → Finalizing — both kinds of Stop', () {
    test('a manual Stop finalizes the current chunk', () {
      final RecordingState? next = RecordingLifecycle.onStop(
        recordingAt(3, t0),
        ChunkBoundaryReason.collectorStop,
      );

      final RecordingStateFinalizing finalizing =
          next! as RecordingStateFinalizing;
      expect(
        finalizing.sequenceIndex,
        3,
        reason: 'the index does not move yet',
      );
      expect(finalizing.reason, ChunkBoundaryReason.collectorStop);
    });

    test('an automatic boundary produces the identical state but for the '
        'reason', () {
      // §1: the boundary is "identical in every way to a manual Stop, except
      // it is immediately followed by a new Recording state". This asserts
      // the "identical in every way" half; the group below asserts the except.
      final RecordingStateFinalizing manual =
          RecordingLifecycle.onStop(
                recordingAt(3, t0),
                ChunkBoundaryReason.collectorStop,
              )!
              as RecordingStateFinalizing;
      final RecordingStateFinalizing automatic =
          RecordingLifecycle.onStop(
                recordingAt(3, t0),
                ChunkBoundaryReason.automaticBoundary,
              )!
              as RecordingStateFinalizing;

      expect(manual.session, automatic.session);
      expect(manual.sequenceIndex, automatic.sequenceIndex);
      expect(manual.reason, isNot(automatic.reason));
    });

    test('a short final chunk is neither padded nor discarded', () {
      // §4: the lifecycle "does not pad or discard a short final chunk", and
      // Ch. 5.6 §3: "there is no minimum chunk duration below which footage
      // is discarded". No duration is consulted, so a one-second chunk
      // finalizes exactly like a ten-minute one.
      final RecordingState? next = RecordingLifecycle.onStop(
        recordingAt(0, t0),
        ChunkBoundaryReason.collectorStop,
      );

      expect(next, isA<RecordingStateFinalizing>());
    });

    test('Stop does nothing unless recording', () {
      for (final RecordingState from in <RecordingState>[
        const RecordingState.idle(),
        RecordingState.ready(session: session),
        RecordingState.finalizing(
          session: session,
          sequenceIndex: 0,
          reason: ChunkBoundaryReason.collectorStop,
        ),
      ]) {
        expect(
          RecordingLifecycle.onStop(from, ChunkBoundaryReason.collectorStop),
          isNull,
          reason: '$from has no chunk to finalize',
        );
      }
    });
  });

  group('Finalizing → the two branches — the internal-Stop pattern', () {
    test('an automatic boundary re-enters Recording, same session, next '
        'index', () {
      final RecordingState? next = RecordingLifecycle.onChunkPersisted(
        RecordingState.finalizing(
          session: session,
          sequenceIndex: 0,
          reason: ChunkBoundaryReason.automaticBoundary,
        ),
        t1,
      );

      final RecordingStateRecording resumed = next! as RecordingStateRecording;
      expect(resumed.sequenceIndex, 1);
      expect(
        resumed.session.sessionId,
        'sess_e810',
        reason: 'Ch. 5.6 §2: chunking never creates a new session_id',
      );
      expect(resumed.chunkStartedAt, t1);
    });

    test('a manual Stop returns to Idle carrying the completed session', () {
      final RecordingState? next = RecordingLifecycle.onChunkPersisted(
        RecordingState.finalizing(
          session: session,
          sequenceIndex: 7,
          reason: ChunkBoundaryReason.collectorStop,
        ),
        t1,
      );

      expect(next, isA<RecordingStateIdle>());
      expect((next! as RecordingStateIdle).lastCompletedSession, session);
      expect(next.activeSession, isNull, reason: 'it is no longer active');
    });

    test('the index increments once per Finalizing transition, and only '
        'there', () {
      // §4 assigns the increment here and nowhere else. Driven across three
      // chunks so an increment in the wrong place would show as a gap or a
      // repeat.
      RecordingState state = RecordingState.ready(session: session);
      final List<int> recorded = <int>[];

      state = RecordingLifecycle.onStart(state, t0)!;
      recorded.add((state as RecordingStateRecording).sequenceIndex);

      for (final DateTime at in <DateTime>[t1, t2]) {
        state = RecordingLifecycle.onStop(
          state,
          ChunkBoundaryReason.automaticBoundary,
        )!;
        state = RecordingLifecycle.onChunkPersisted(state, at)!;
        recorded.add((state as RecordingStateRecording).sequenceIndex);
      }

      expect(recorded, <int>[0, 1, 2]);
    });

    test('nothing advances unless finalizing', () {
      for (final RecordingState from in <RecordingState>[
        const RecordingState.idle(),
        RecordingState.ready(session: session),
        recordingAt(0, t0),
      ]) {
        expect(RecordingLifecycle.onChunkPersisted(from, t1), isNull);
      }
    });
  });

  group('the state union itself', () {
    test('only Recording reports capturing', () {
      expect(const RecordingState.idle().isCapturing, isFalse);
      expect(RecordingState.ready(session: session).isCapturing, isFalse);
      expect(recordingAt(0, t0).isCapturing, isTrue);
      expect(
        RecordingState.finalizing(
          session: session,
          sequenceIndex: 0,
          reason: ChunkBoundaryReason.automaticBoundary,
        ).isCapturing,
        isFalse,
        reason: 'capture has stopped; C-10 Local Processing is showing',
      );
    });

    test('a completed session is not reported as active', () {
      // The trap this guards: Idle carries lastCompletedSession, and a caller
      // asking "what is recording now" must not be handed a session that has
      // ended.
      final RecordingState idle = RecordingState.idle(
        lastCompletedSession: session,
      );

      expect(idle.activeSession, isNull);
      expect((idle as RecordingStateIdle).lastCompletedSession, isNotNull);
    });
  });

  group('the full transition matrix', () {
    // The groups above assert each rule where it is easiest to read. This
    // asserts the *shape* of the machine: every state crossed with every
    // action, so a newly added state or action cannot slip in untested, and
    // the count of legal edges is pinned at exactly four.
    //
    // It also fixes a hole the per-rule groups left: onStart from Finalizing
    // was the one illegal pair with no assertion anywhere.
    final Map<String, RecordingState> states = <String, RecordingState>{
      'idle': const RecordingState.idle(),
      'ready': RecordingState.ready(session: session),
      'recording': recordingAt(0, t0),
      'finalizing': RecordingState.finalizing(
        session: session,
        sequenceIndex: 0,
        reason: ChunkBoundaryReason.automaticBoundary,
      ),
    };

    final Map<String, RecordingState? Function(RecordingState)> actions =
        <String, RecordingState? Function(RecordingState)>{
          'onChecklistPassed': (RecordingState s) =>
              RecordingLifecycle.onChecklistPassed(s, session),
          'onStart': (RecordingState s) => RecordingLifecycle.onStart(s, t1),
          'onStop': (RecordingState s) => RecordingLifecycle.onStop(
            s,
            ChunkBoundaryReason.collectorStop,
          ),
          'onChunkPersisted': (RecordingState s) =>
              RecordingLifecycle.onChunkPersisted(s, t1),
        };

    /// The four edges of Chapter 5.3 §2's diagram, and nothing else.
    const Set<String> legalEdges = <String>{
      'idle → onChecklistPassed',
      'ready → onStart',
      'recording → onStop',
      'finalizing → onChunkPersisted',
    };

    test('exactly four edges are legal; the other twelve return null', () {
      final Set<String> accepted = <String>{};

      states.forEach((String stateName, RecordingState state) {
        actions.forEach((
          String actionName,
          RecordingState? Function(RecordingState) action,
        ) {
          final String edge = '$stateName → $actionName';
          // Returning rather than throwing is the pattern itself: a null here
          // is the machine declining a race, not swallowing a failure. If any
          // pair threw, this call would fail the test rather than return.
          if (action(state) != null) {
            accepted.add(edge);
          }
        });
      });

      expect(accepted, legalEdges);
    });

    test('no action throws from any state', () {
      // Asserted separately so a throw reads as "the machine threw" rather
      // than as an unexpected edge count.
      states.forEach((String stateName, RecordingState state) {
        actions.forEach((
          String actionName,
          RecordingState? Function(RecordingState) action,
        ) {
          expect(
            () => action(state),
            returnsNormally,
            reason: '$stateName → $actionName',
          );
        });
      });
    });
  });
}
