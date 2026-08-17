import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/recording_guard.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/domain/entities/session_end_cause.dart';

/// BR-04, as a pure redirect rule.
///
/// This is the half of BR-04 that a disabled button cannot deliver. The
/// Checklist screen stops a tap; this stops a deep link, a restored route, and
/// a `context.go` written by someone later who did not read Chapter 2.3 §5.
void main() {
  final RecordingSession session = RecordingSession(
    sessionId: 'sess_1',
    zoomFactor: 0.6,
    startedAt: DateTime.utc(2026, 8, 15, 9),
  );

  String recordingRoute(String id) => '/recording/$id';

  group('BR-04 — /recording is unreachable without a live session', () {
    test('a cold Idle machine is turned away', () {
      expect(
        RecordingGuard.redirect(
          state: const RecordingState.idle(),
          location: recordingRoute('sess_1'),
        ),
        RecordingGuard.fallbackRoute,
      );
    });

    test('Ready is allowed — that is the state the Checklist hands over', () {
      // Ch. 5.3 §3: Ready means the Checklist passed and the camera is open.
      // Refusing it would make the screen unreachable through its own route.
      expect(
        RecordingGuard.redirect(
          state: RecordingState.ready(session: session),
          location: recordingRoute('sess_1'),
        ),
        isNull,
      );
    });

    test('Recording is allowed', () {
      expect(
        RecordingGuard.redirect(
          state: RecordingState.recording(
            session: session,
            sequenceIndex: 0,
            chunkStartedAt: session.startedAt,
          ),
          location: recordingRoute('sess_1'),
        ),
        isNull,
      );
    });

    test('Finalizing is turned away — capture has already ended', () {
      // C-10 owns the screen from Stop onward, and a capture surface with no
      // capture behind it is exactly the ambiguous state Ch. 2.9 warns about.
      expect(
        RecordingGuard.redirect(
          state: RecordingState.finalizing(
            session: session,
            processing: const <Never>[],
            endCause: SessionEndCause.collectorStop,
          ),
          location: recordingRoute('sess_1'),
        ),
        RecordingGuard.fallbackRoute,
      );
    });

    test('a stale session id is refused even while recording', () {
      // The dangerous case: a live session exists, so a naive "is anything
      // recording" check would allow this, and the screen's Stop would end a
      // session the URL does not name.
      expect(
        RecordingGuard.redirect(
          state: RecordingState.recording(
            session: session,
            sequenceIndex: 0,
            chunkStartedAt: session.startedAt,
          ),
          location: recordingRoute('sess_from_history'),
        ),
        RecordingGuard.fallbackRoute,
      );
    });
  });

  group('/processing is reachable while draining and just after', () {
    test('Finalizing is allowed', () {
      expect(
        RecordingGuard.redirect(
          state: RecordingState.finalizing(
            session: session,
            processing: const <Never>[],
            endCause: SessionEndCause.collectorStop,
          ),
          location: '/processing/sess_1',
        ),
        isNull,
      );
    });

    test('Idle carrying the completed session is allowed', () {
      // The screen's final state reads `lastCompletedSession`, so the moment
      // after the drain finishes must still render.
      expect(
        RecordingGuard.redirect(
          state: RecordingState.idle(
            lastCompletedSession: session,
            endCause: SessionEndCause.collectorStop,
          ),
          location: '/processing/sess_1',
        ),
        isNull,
      );
    });

    test('a cold start has nothing to show and is turned away', () {
      expect(
        RecordingGuard.redirect(
          state: const RecordingState.idle(),
          location: '/processing/sess_1',
        ),
        RecordingGuard.fallbackRoute,
      );
    });
  });

  group('it governs only its own routes', () {
    test('every other location is untouched, whatever the state', () {
      // A guard that redirected from anywhere else would fight AuthGuard.
      for (final String location in <String>[
        '/collector/dashboard',
        '/collector/projects/p1/tasks/t1',
        '/checklist/t1',
        '/login',
        '/admin/settings',
      ]) {
        expect(
          RecordingGuard.redirect(
            state: const RecordingState.idle(),
            location: location,
          ),
          isNull,
          reason: location,
        );
      }
    });

    test('the checklist itself is never guarded', () {
      // It is the route BR-04 requires people to pass through. Guarding it on
      // recording state would make capture unreachable.
      expect(
        RecordingGuard.redirect(
          state: const RecordingState.idle(),
          location: '/checklist/task_1',
        ),
        isNull,
      );
    });
  });
}
