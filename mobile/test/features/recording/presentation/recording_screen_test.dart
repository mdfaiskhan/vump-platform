import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/presentation/recording_screen.dart';

/// C-09's Stop control, and Chapter 2.10 §4's announcement rule.
///
/// > *"The Recording Screen's Stop control announces its state changes
/// > (\"Recording — tap to stop\" while active) so a screen-reader user always
/// > knows recording is in progress even without seeing the pulsing visual
/// > indicator."*
///
/// **The screen had no widget test at all before Mission 5.5**, which is worth
/// saying plainly: C-09 is one of the six screens Chapter 2.10 §8 names for its
/// TalkBack pass, and nothing automated rendered it. These tests cover the
/// accessible name only — the pulsing indicator, the camera preview and the
/// stop-and-finalize path remain device-verified (Mission 3) and untested here.
///
/// The label is asserted through the semantics tree rather than by finding a
/// `Text` widget, because there is no text: the control is an icon, and its
/// accessible name is the entire thing a screen reader has to work with.
void main() {
  final RecordingSession session = RecordingSession(
    sessionId: 's1',
    zoomFactor: 1,
    startedAt: _startedAt,
  );
  final RecordingState recording = RecordingState.recording(
    session: session,
    sequenceIndex: 0,
    chunkStartedAt: _startedAt,
  );

  Widget app(RecordingState state) {
    return ProviderScope(
      overrides: <Override>[
        recordingNotifierProvider.overrideWith(() => _FixedNotifier(state)),
      ],
      child: const MaterialApp(home: RecordingScreen(sessionId: 's1')),
    );
  }

  testWidgets('while capturing it says recording is in progress', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(app(recording));
    await tester.pump();

    expect(
      find.bySemanticsLabel('Recording — tap to stop'),
      findsOneWidget,
      reason: 'Chapter 2.10 §4 names this string as the active-state label',
    );
    handle.dispose();
  });

  testWidgets('when not capturing it falls back to naming the action', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(app(const RecordingState.idle()));
    await tester.pump();

    // The distinction is the whole requirement. A label that reads the same in
    // both states is what this screen had before, and it told a screen-reader
    // user nothing about whether capture was running.
    expect(find.bySemanticsLabel('Stop recording'), findsOneWidget);
    expect(find.bySemanticsLabel('Recording — tap to stop'), findsNothing);
    handle.dispose();
  });
}

/// A fixed instant, so the BR-06 timer has an origin without a real clock.
final DateTime _startedAt = DateTime.utc(2026, 9, 1, 10);

/// A notifier pinned to one state, so the screen can be rendered without a
/// camera, a pipeline or a chunk store.
class _FixedNotifier extends RecordingNotifier {
  _FixedNotifier(this._state);

  final RecordingState _state;

  @override
  RecordingState build() => _state;
}
