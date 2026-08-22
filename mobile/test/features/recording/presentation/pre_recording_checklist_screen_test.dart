import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/recording/application/checklist_notifier.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/presentation/pre_recording_checklist_screen.dart';

import '../fakes/checklist_fakes.dart';

/// The Checklist screen's Start action, driven through a real tap.
///
/// ## Why this file exists, and why a notifier test could not replace it
///
/// Mission 3.8 wired `Idle → Ready` and never wired `Ready → Recording`:
/// nothing in `lib/` called `RecordingNotifier.start()`. The machine sat in
/// `Ready`, `isCapturing` stayed false, and C-09's Stop control — which reads
/// exactly that — rendered disabled and silently swallowed every tap.
///
/// **Every existing test passed.** `recording_notifier_test.dart` calls
/// `start()` itself, so it proves the transition works when invoked; it cannot
/// prove anything invokes it. Mission 3.8.1's device harness did the same and
/// reached `RESULT pass` twice on real hardware. The defect lived in the one
/// seam neither could see — the UI's call into the notifier — and only a
/// person tapping the real button found it.
///
/// So this test taps the button. Amendment A-070 records the finding.
void main() {
  Widget harness(ProviderContainer container) {
    final GoRouter router = GoRouter(
      initialLocation: '/checklist/task-1',
      routes: <RouteBase>[
        GoRoute(
          path: '/checklist/:taskId',
          builder: (BuildContext context, GoRouterState state) =>
              PreRecordingChecklistScreen(
                taskId: state.pathParameters['taskId'] ?? '',
              ),
        ),
        GoRoute(
          path: '/recording/:sessionId',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('recording-screen')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  ProviderContainer build({FakePipeline? pipeline, Completer<void>? gate}) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        cameraPermissionProbeProvider.overrideWithValue(
          FakePermissionProbe(gate),
        ),
        freeSpaceReaderProvider.overrideWithValue(const FakeFreeSpace()),
        recordingsDirectoryProvider.overrideWithValue('/files'),
        batteryReaderProvider.overrideWithValue(const FakeBattery()),
        networkReaderProvider.overrideWithValue(const FakeNetwork()),
        wideAngleEligibilityCacheProvider.overrideWithValue(const FakeCache()),
        cameraCapabilityProbeProvider.overrideWithValue(const FakeProbe()),
        recordingPipelineProvider.overrideWithValue(pipeline ?? FakePipeline()),
        sessionIdGeneratorProvider.overrideWithValue(const FixedIds()),
        chunkIdGeneratorProvider.overrideWithValue(const FixedIds()),
        chunkFinalizerProvider.overrideWithValue(const FakeFinalizer()),
        chunkStoreProvider.overrideWithValue(const FakeStore()),

        // A successful start arms BR-06's ten-minute boundary, which the test
        // binding then reports as a pending timer after the tree is disposed.
        // Mission 3.2 declared these factories as an injection seam for
        // exactly this; nothing here needs the boundary to fire.
        boundaryTimerFactoryProvider.overrideWithValue(
          (Duration duration, void Function() callback) => NoopTimer(),
        ),
        storageTimerFactoryProvider.overrideWithValue(
          (Duration interval, void Function(Timer) callback) => NoopTimer(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settleChecklist(WidgetTester tester) async {
    // runAll() is kicked off in a post-frame callback and awaits five async
    // reads, so the button is disabled until they land.
    await tester.pumpAndSettle();
  }

  testWidgets('an unmeasured row says it is being checked — Ch. 2.10 §4', (
    WidgetTester tester,
  ) async {
    // §4 names "checklist re-run" as a progress indicator that must expose its
    // state rather than being "purely an animated visual".
    //
    // The pass and fail icons carried `semanticLabel` from Mission 3; the
    // spinner between them carried nothing, so a row still being checked and a
    // row with no result at all sounded identical to a screen reader.
    final SemanticsHandle handle = tester.ensureSemantics();
    final Completer<void> gate = Completer<void>();
    final ProviderContainer c = build(gate: gate);

    await tester.pumpWidget(harness(c));
    await tester.pump();

    // Matched as a PATTERN, not a string: `ListTile` merges its descendants
    // into one semantics node, so the icon's label arrives concatenated with
    // the row's title rather than standing alone. An exact match silently
    // finds nothing here, which is how this assertion first failed.
    //
    // Held mid-probe by the gate: the permission row cannot have a verdict yet.
    expect(find.bySemanticsLabel(RegExp('Checking')), findsWidgets);

    gate.complete();
    await settleChecklist(tester);

    // And it is genuinely transient — once measured, the word is gone and the
    // verdict has replaced it. Without this half the assertion above would
    // also pass on a label that never goes away.
    expect(find.bySemanticsLabel(RegExp('Checking')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Passed')), findsWidgets);
    handle.dispose();
  });

  testWidgets('tapping Start Recording reaches Recording, not just Ready', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = build();
    await tester.pumpWidget(harness(c));
    await settleChecklist(tester);

    expect(
      c.read(recordingNotifierProvider),
      isA<RecordingStateIdle>(),
      reason: 'nothing has happened yet',
    );

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    // The assertion this whole file exists for. Before A-070 this was
    // RecordingStateReady and the Stop control on the next screen was dead.
    expect(c.read(recordingNotifierProvider), isA<RecordingStateRecording>());
    expect(c.read(recordingNotifierProvider).isCapturing, isTrue);
  });

  testWidgets('the pipeline is actually told to start a chunk', (
    WidgetTester tester,
  ) async {
    // isCapturing could be satisfied by a state change alone. This pins that
    // the camera was told to record, in order, after the session opened.
    final FakePipeline pipeline = FakePipeline();
    final ProviderContainer c = build(pipeline: pipeline);
    await tester.pumpWidget(harness(c));
    await settleChecklist(tester);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    expect(pipeline.calls, <String>['openSession', 'startChunk']);
  });

  testWidgets('it navigates to the recording screen once capturing', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = build();
    await tester.pumpWidget(harness(c));
    await settleChecklist(tester);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    expect(find.text('recording-screen'), findsOneWidget);
  });

  testWidgets('a failure to start capture keeps the Collector here', (
    WidgetTester tester,
  ) async {
    // The session exists and the camera is open, but capture did not begin.
    // Sending the Collector to a screen whose only control acts on a
    // recording that never started is what produced the original defect's
    // symptom, so this asserts the opposite.
    final ProviderContainer c = build(
      pipeline: FakePipeline(failStartChunk: true),
    );
    await tester.pumpWidget(harness(c));
    await settleChecklist(tester);

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    expect(find.text('recording-screen'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Start Recording is disabled until every row passes', (
    WidgetTester tester,
  ) async {
    // BR-04 at the button. The guard is the other half and is tested in
    // recording_guard_test.dart.
    //
    // The permission probe is gated on a Completer so the checklist is
    // genuinely mid-run at the first pump. Without it every fake resolves in
    // one microtask and there is no observable pending state to assert.
    final Completer<void> gate = Completer<void>();
    final ProviderContainer c = build(gate: gate);
    await tester.pumpWidget(harness(c));
    await tester.pump();

    final Finder button = find.widgetWithText(FilledButton, 'Start Recording');
    expect(
      tester.widget<FilledButton>(button).onPressed,
      isNull,
      reason: 'the first row has not answered yet',
    );

    gate.complete();
    await settleChecklist(tester);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });
}
