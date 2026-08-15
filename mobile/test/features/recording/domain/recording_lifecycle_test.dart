import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/features/recording/domain/entities/chunk_boundary_reason.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/failed_chunk.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/domain/entities/session_end_cause.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';

/// Volume 5 Chapter 5.3 §2's diagram, as revised by Mission 3.4.5.
///
/// The machine is pure, so every transition — including the capture/processing
/// overlap this mission introduced — is asserted with no timer, no camera and
/// no widget tree.
void main() {
  final DateTime t0 = DateTime.utc(2026, 8, 15, 9);
  final DateTime t1 = t0.add(RecordingLifecycle.chunkDuration);
  final DateTime t2 = t1.add(RecordingLifecycle.chunkDuration);

  final RecordingSession session = RecordingSession(
    sessionId: 'sess_e810',
    zoomFactor: 0.5,
    startedAt: t0,
  );

  ChunkProcessingJob jobFor(int index, {String? id}) => ChunkProcessingJob(
    chunkId: id ?? 'chunk_$index',
    sequenceIndex: index,
    filePath: '/recordings/sess_e810/000$index.mp4',
    startedAt: t0,
  );

  RecordingState recordingAt(
    int index,
    DateTime at, {
    List<ChunkProcessingJob> processing = const <ChunkProcessingJob>[],
    List<FailedChunk> failed = const <FailedChunk>[],
  }) => RecordingState.recording(
    session: session,
    sequenceIndex: index,
    chunkStartedAt: at,
    processing: processing,
    failed: failed,
  );

  group('constants', () {
    test('a chunk is exactly ten minutes (BR-06)', () {
      expect(RecordingLifecycle.chunkDuration, const Duration(minutes: 10));
    });

    test('the first chunk of a session is index 0', () {
      expect(RecordingLifecycle.firstSequenceIndex, 0);
    });

    test('at most three chunks may process concurrently', () {
      // Not a defensive default: Ch. 5.4 §2's low-storage path forces a
      // boundary every 5-second poll, which is the only way jobs stack.
      expect(RecordingLifecycle.maximumConcurrentProcessing, 3);
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

    test('Ready is reachable from Idle only', () {
      for (final RecordingState from in <RecordingState>[
        RecordingState.ready(session: session),
        recordingAt(0, t0),
        RecordingState.finalizing(
          session: session,
          processing: <ChunkProcessingJob>[jobFor(0)],
          endCause: SessionEndCause.collectorStop,
        ),
      ]) {
        expect(RecordingLifecycle.onChecklistPassed(from, session), isNull);
      }
    });
  });

  group('Ready → Recording — Start', () {
    test('recording opens at the first index, nothing processing', () {
      final RecordingState? next = RecordingLifecycle.onStart(
        RecordingState.ready(session: session),
        t0,
      );

      final RecordingStateRecording rec = next! as RecordingStateRecording;
      expect(rec.sequenceIndex, RecordingLifecycle.firstSequenceIndex);
      expect(rec.chunkStartedAt, t0);
      expect(rec.processing, isEmpty);
    });

    test('Start does nothing from Idle — BR-04', () {
      expect(
        RecordingLifecycle.onStart(const RecordingState.idle(), t0),
        isNull,
      );
    });
  });

  group('capture stops — the edge Mission 3.4.5 changed', () {
    test('an automatic boundary returns to Recording, NOT Finalizing', () {
      // The whole point: capture resumes immediately, and the chunk that just
      // ended moves into the processing set rather than blocking the machine.
      final RecordingState? next = RecordingLifecycle.onCaptureStopped(
        recordingAt(0, t0),
        ChunkBoundaryReason.automaticBoundary,
        jobFor(0),
        t1,
      );

      final RecordingStateRecording rec = next! as RecordingStateRecording;
      expect(rec.sequenceIndex, 1, reason: 'chunk N+1 of the same session');
      expect(rec.session.sessionId, 'sess_e810');
      expect(rec.chunkStartedAt, t1);
      expect(rec.processing.single.chunkId, 'chunk_0');
    });

    test('a Collector stop enters Finalizing to drain', () {
      final RecordingState? next = RecordingLifecycle.onCaptureStopped(
        recordingAt(3, t0),
        ChunkBoundaryReason.collectorStop,
        jobFor(3),
        t1,
      );

      final RecordingStateFinalizing fin = next! as RecordingStateFinalizing;
      expect(fin.processing.single.sequenceIndex, 3);
    });

    test('a short final chunk is neither padded nor discarded', () {
      // Ch. 5.3 §4 and Ch. 5.6 §3 — no duration is consulted anywhere here.
      expect(
        RecordingLifecycle.onCaptureStopped(
          recordingAt(0, t0),
          ChunkBoundaryReason.collectorStop,
          jobFor(0),
          t0,
        ),
        isA<RecordingStateFinalizing>(),
      );
    });

    test('earlier jobs are preserved, not replaced', () {
      final RecordingState? next = RecordingLifecycle.onCaptureStopped(
        recordingAt(1, t0, processing: <ChunkProcessingJob>[jobFor(0)]),
        ChunkBoundaryReason.automaticBoundary,
        jobFor(1),
        t1,
      );

      expect(
        (next! as RecordingStateRecording).processing
            .map((ChunkProcessingJob j) => j.sequenceIndex)
            .toList(),
        <int>[0, 1],
      );
    });

    test('capture stop does nothing unless recording', () {
      for (final RecordingState from in <RecordingState>[
        const RecordingState.idle(),
        RecordingState.ready(session: session),
        RecordingState.finalizing(
          session: session,
          processing: <ChunkProcessingJob>[jobFor(0)],
          endCause: SessionEndCause.collectorStop,
        ),
      ]) {
        expect(
          RecordingLifecycle.onCaptureStopped(
            from,
            ChunkBoundaryReason.collectorStop,
            jobFor(9),
            t1,
          ),
          isNull,
        );
      }
    });
  });

  group('the concurrency bound', () {
    test('reaching the cap converts an automatic boundary into a stop', () {
      // If processing cannot keep up, continuing to capture makes it worse —
      // more files on a device already failing to keep up, and in the case
      // that causes it, a disk already near its limit.
      final RecordingState? next = RecordingLifecycle.onCaptureStopped(
        recordingAt(
          2,
          t0,
          processing: <ChunkProcessingJob>[jobFor(0), jobFor(1)],
        ),
        ChunkBoundaryReason.automaticBoundary,
        jobFor(2),
        t1,
      );

      expect(
        next,
        isA<RecordingStateFinalizing>(),
        reason: 'three in flight is the cap',
      );
      expect((next! as RecordingStateFinalizing).processing, hasLength(3));
    });

    test('a capacity-forced end is distinguishable from a Collector stop', () {
      // Mission 3.4.5.1's defect: both endings landed in Finalizing and the
      // state recorded neither, so nothing could tell a Collector why their
      // recording had stopped without them asking.
      final RecordingState forced = RecordingLifecycle.onCaptureStopped(
        recordingAt(
          2,
          t0,
          processing: <ChunkProcessingJob>[jobFor(0), jobFor(1)],
        ),
        ChunkBoundaryReason.automaticBoundary,
        jobFor(2),
        t1,
      )!;
      final RecordingState chosen = RecordingLifecycle.onCaptureStopped(
        recordingAt(2, t0),
        ChunkBoundaryReason.collectorStop,
        jobFor(2),
        t1,
      )!;

      expect(forced, isA<RecordingStateFinalizing>());
      expect(chosen, isA<RecordingStateFinalizing>());
      expect(forced.sessionEndCause, SessionEndCause.processingCapacityReached);
      expect(chosen.sessionEndCause, SessionEndCause.collectorStop);
      expect(forced.endedInvoluntarily, isTrue);
      expect(chosen.endedInvoluntarily, isFalse);
    });

    test('the cause survives the drain and reaches Idle', () {
      // Volume 2 Ch. 2.9 §4.3 needs a cause and a recovery action, and the
      // Collector reads it *after* draining — looking at a stopped recording.
      RecordingState state = RecordingLifecycle.onCaptureStopped(
        recordingAt(
          2,
          t0,
          processing: <ChunkProcessingJob>[jobFor(0), jobFor(1)],
        ),
        ChunkBoundaryReason.automaticBoundary,
        jobFor(2),
        t1,
      )!;
      for (final String id in <String>['chunk_0', 'chunk_1', 'chunk_2']) {
        state = RecordingLifecycle.onChunkProcessed(state, chunkId: id)!;
      }

      expect(state, isA<RecordingStateIdle>());
      expect(
        state.sessionEndCause,
        SessionEndCause.processingCapacityReached,
        reason: '3.8 must be able to explain this without guessing',
      );
      expect(state.endedInvoluntarily, isTrue);
    });

    test('a Collector stop reaches Idle reporting itself as chosen', () {
      RecordingState state = RecordingLifecycle.onCaptureStopped(
        recordingAt(0, t0),
        ChunkBoundaryReason.collectorStop,
        jobFor(0),
        t1,
      )!;
      state = RecordingLifecycle.onChunkProcessed(state, chunkId: 'chunk_0')!;

      expect(state, isA<RecordingStateIdle>());
      expect(state.sessionEndCause, SessionEndCause.collectorStop);
      expect(state.endedInvoluntarily, isFalse);
    });

    test('a fresh Idle has no end cause to explain', () {
      expect(const RecordingState.idle().sessionEndCause, isNull);
      expect(const RecordingState.idle().endedInvoluntarily, isFalse);
    });

    test('below the cap it keeps recording', () {
      final RecordingState? next = RecordingLifecycle.onCaptureStopped(
        recordingAt(1, t0, processing: <ChunkProcessingJob>[jobFor(0)]),
        ChunkBoundaryReason.automaticBoundary,
        jobFor(1),
        t1,
      );

      expect(next, isA<RecordingStateRecording>());
    });
  });

  group('a job completes — the fifth legal edge', () {
    test('while recording, the job leaves and capture continues', () {
      final RecordingState? next = RecordingLifecycle.onChunkProcessed(
        recordingAt(1, t1, processing: <ChunkProcessingJob>[jobFor(0)]),
        chunkId: 'chunk_0',
      );

      final RecordingStateRecording rec = next! as RecordingStateRecording;
      expect(rec.processing, isEmpty);
      expect(rec.sequenceIndex, 1, reason: 'capture is untouched');
      expect(rec.chunkStartedAt, t1);
    });

    test('while draining, the last job ends the session', () {
      final RecordingState? next = RecordingLifecycle.onChunkProcessed(
        RecordingState.finalizing(
          session: session,
          processing: <ChunkProcessingJob>[jobFor(4)],
          endCause: SessionEndCause.collectorStop,
        ),
        chunkId: 'chunk_4',
      );

      expect(next, isA<RecordingStateIdle>());
      expect((next! as RecordingStateIdle).lastCompletedSession, session);
      expect(next.activeSession, isNull);
    });

    test('while draining, an earlier job leaves the rest', () {
      final RecordingState? next = RecordingLifecycle.onChunkProcessed(
        RecordingState.finalizing(
          session: session,
          processing: <ChunkProcessingJob>[jobFor(4), jobFor(5)],
          endCause: SessionEndCause.collectorStop,
        ),
        chunkId: 'chunk_4',
      );

      expect(next, isA<RecordingStateFinalizing>());
      expect(
        (next! as RecordingStateFinalizing).processing.single.chunkId,
        'chunk_5',
      );
    });

    test('an unknown chunk id is ignored', () {
      // A duplicate completion, or one from a session already ended.
      expect(
        RecordingLifecycle.onChunkProcessed(
          recordingAt(1, t1, processing: <ChunkProcessingJob>[jobFor(0)]),
          chunkId: 'chunk_nope',
        ),
        isNull,
      );
    });
  });

  group('terminal failure — Ch. 5.13 §1', () {
    test('a failed chunk is recorded and recording continues', () {
      // "Terminal (device-side) ... surfaces immediately as Failed" is a
      // status on the chunk, not on the session.
      final RecordingState? next = RecordingLifecycle.onChunkProcessed(
        recordingAt(1, t1, processing: <ChunkProcessingJob>[jobFor(0)]),
        chunkId: 'chunk_0',
        cause: ErrorCode.storageNotFound,
      );

      expect(next, isA<RecordingStateRecording>());
      expect(
        next!.isCapturing,
        isTrue,
        reason: 'good footage is not thrown away',
      );
      final FailedChunk failed = next.failedChunks.single;
      expect(failed.chunkId, 'chunk_0');
      expect(failed.sequenceIndex, 0);
      expect(failed.cause, ErrorCode.storageNotFound);
    });

    test('a failed chunk still leaves the pending set, so draining ends', () {
      // Otherwise Finalizing would wait forever on a job that already failed.
      final RecordingState? next = RecordingLifecycle.onChunkProcessed(
        RecordingState.finalizing(
          session: session,
          processing: <ChunkProcessingJob>[jobFor(7)],
          endCause: SessionEndCause.collectorStop,
        ),
        chunkId: 'chunk_7',
        cause: ErrorCode.storageNotFound,
      );

      expect(next, isA<RecordingStateIdle>());
      expect(next!.failedChunks.single.sequenceIndex, 7);
    });

    test('failures accumulate across a session', () {
      RecordingState state = recordingAt(
        2,
        t1,
        processing: <ChunkProcessingJob>[jobFor(0), jobFor(1)],
      );
      state = RecordingLifecycle.onChunkProcessed(
        state,
        chunkId: 'chunk_0',
        cause: ErrorCode.storageNotFound,
      )!;
      state = RecordingLifecycle.onChunkProcessed(
        state,
        chunkId: 'chunk_1',
        cause: ErrorCode.storageWriteFailed,
      )!;

      expect(state.failedChunks, hasLength(2));
    });
  });

  group('identity is minted at capture-stop', () {
    test('nextJob takes the index of the chunk being captured', () {
      final ChunkProcessingJob? job = RecordingLifecycle.nextJob(
        recordingAt(4, t0),
        chunkId: 'chunk_abc',
        filePath: '/tmp/0004.mp4',
        now: t1,
      );

      expect(job!.sequenceIndex, 4, reason: 'not 5 — that is the next chunk');
      expect(job.chunkId, 'chunk_abc');
      expect(job.filePath, '/tmp/0004.mp4');
      expect(job.startedAt, t1);
    });

    test('nextJob refuses when not recording', () {
      expect(
        RecordingLifecycle.nextJob(
          const RecordingState.idle(),
          chunkId: 'x',
          filePath: '/tmp/x.mp4',
          now: t1,
        ),
        isNull,
      );
    });

    test('indices are contiguous and unique across a session', () {
      // The property Ch. 5.14 §1 depends on: the S3 key is UNIQUE on this
      // index. Captures are strictly serial — the plugin permits one recording
      // at a time — so one capture yields one stop yields one increment.
      RecordingState state = RecordingLifecycle.onStart(
        RecordingState.ready(session: session),
        t0,
      )!;
      final List<int> minted = <int>[];

      for (final DateTime at in <DateTime>[t1, t2]) {
        final ChunkProcessingJob job = RecordingLifecycle.nextJob(
          state,
          chunkId: 'chunk_${minted.length}',
          filePath: '/tmp/${minted.length}.mp4',
          now: at,
        )!;
        minted.add(job.sequenceIndex);
        state = RecordingLifecycle.onCaptureStopped(
          state,
          ChunkBoundaryReason.automaticBoundary,
          job,
          at,
        )!;
      }
      minted.add((state as RecordingStateRecording).sequenceIndex);

      expect(minted, <int>[0, 1, 2], reason: 'no gap, no repeat');
      expect(minted.toSet(), hasLength(minted.length));
    });

    test('completion order does not disturb the index', () {
      // Chunk 0 finishes after chunk 1 was already captured. The index is
      // derived from capture, never from completion, so nothing shifts.
      RecordingState state = recordingAt(
        2,
        t2,
        processing: <ChunkProcessingJob>[jobFor(0), jobFor(1)],
      );
      state = RecordingLifecycle.onChunkProcessed(state, chunkId: 'chunk_1')!;
      state = RecordingLifecycle.onChunkProcessed(state, chunkId: 'chunk_0')!;

      expect((state as RecordingStateRecording).sequenceIndex, 2);
      expect(state.processing, isEmpty);
    });
  });

  group('the state union itself', () {
    test('only Recording reports capturing — including across a boundary', () {
      expect(const RecordingState.idle().isCapturing, isFalse);
      expect(RecordingState.ready(session: session).isCapturing, isFalse);
      expect(
        recordingAt(
          1,
          t1,
          processing: <ChunkProcessingJob>[jobFor(0)],
        ).isCapturing,
        isTrue,
        reason: 'the camera runs while an earlier chunk is hashed',
      );
      expect(
        RecordingState.finalizing(
          session: session,
          processing: <ChunkProcessingJob>[jobFor(0)],
          endCause: SessionEndCause.collectorStop,
        ).isCapturing,
        isFalse,
      );
    });

    test('a completed session is not reported as active', () {
      final RecordingState idle = RecordingState.idle(
        lastCompletedSession: session,
      );

      expect(idle.activeSession, isNull);
      expect((idle as RecordingStateIdle).lastCompletedSession, isNotNull);
    });
  });

  group('the full transition matrix', () {
    // Mission 3.2 pinned this at four legal edges specifically to catch an
    // unplanned state addition. Mission 3.4.5 moved it deliberately: the state
    // COUNT is unchanged at four, and exactly one edge became legal —
    // onChunkProcessed from Recording, because a background job can now finish
    // while the next chunk is being captured. Nothing else moved.
    final Map<String, RecordingState> states = <String, RecordingState>{
      'idle': const RecordingState.idle(),
      'ready': RecordingState.ready(session: session),
      'recording': recordingAt(
        1,
        t1,
        processing: <ChunkProcessingJob>[jobFor(0)],
      ),
      'finalizing': RecordingState.finalizing(
        session: session,
        processing: <ChunkProcessingJob>[jobFor(0)],
        endCause: SessionEndCause.collectorStop,
      ),
    };

    final Map<String, RecordingState? Function(RecordingState)> actions =
        <String, RecordingState? Function(RecordingState)>{
          'onChecklistPassed': (RecordingState s) =>
              RecordingLifecycle.onChecklistPassed(s, session),
          'onStart': (RecordingState s) => RecordingLifecycle.onStart(s, t1),
          'onCaptureStopped': (RecordingState s) =>
              RecordingLifecycle.onCaptureStopped(
                s,
                ChunkBoundaryReason.collectorStop,
                jobFor(9),
                t2,
              ),
          'onChunkProcessed': (RecordingState s) =>
              RecordingLifecycle.onChunkProcessed(s, chunkId: 'chunk_0'),
        };

    /// Five edges. Four states, unchanged.
    const Set<String> legalEdges = <String>{
      'idle → onChecklistPassed',
      'ready → onStart',
      'recording → onCaptureStopped',
      'recording → onChunkProcessed',
      'finalizing → onChunkProcessed',
    };

    test('exactly five edges are legal; the other eleven return null', () {
      final Set<String> accepted = <String>{};

      states.forEach((String stateName, RecordingState state) {
        actions.forEach((
          String actionName,
          RecordingState? Function(RecordingState) action,
        ) {
          if (action(state) != null) {
            accepted.add('$stateName → $actionName');
          }
        });
      });

      expect(accepted, legalEdges);
    });

    test('the state count is still four', () {
      // Processing is a field, not a variant — the reason the matrix stayed
      // 4x4 while gaining an edge.
      expect(states, hasLength(4));
    });

    test('no action throws from any state', () {
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
