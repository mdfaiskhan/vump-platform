import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/preview_frame.dart';
import 'package:mobile/features/recording/domain/repositories/recording_pipeline.dart';
import 'package:mobile/features/recording/presentation/widgets/camera_preview_surface.dart';

/// The aspect-ratio regression, pinned.
///
/// **Nothing asserted `aspectRatio` anywhere before this file**, which is why
/// the pipeline could start handing a portrait ratio to a landscape window and
/// no test noticed. The stretch was found on a device, by a probe, after a
/// project owner looked at it — three steps further out than it should have
/// needed to travel.
///
/// `CameraPreviewSurface` cannot be pumped with a real texture in a unit test:
/// `CameraPlatform.instance.buildPreview` needs a registered platform. So these
/// read the `AspectRatio` the widget builds rather than what it renders, which
/// is the value that was wrong.
class _FakePipeline implements RecordingPipeline {
  _FakePipeline(this.frame);

  final PreviewFrame? frame;

  @override
  PreviewFrame? get currentPreview => frame;

  @override
  Stream<PreviewFrame?> get previewChanges =>
      Stream<PreviewFrame?>.value(frame);

  @override
  String? get outputDirectory => null;

  @override
  String? get captureOrientation => null;

  @override
  Future<void> openSession({required double zoomFactor}) async {}

  @override
  Future<void> startChunk() async {}

  @override
  Future<String> stopChunk() async => '';

  @override
  Future<void> closeSession() async {}
}

/// The preview's display ratio, read off the `SizedBox` that `FittedBox`
/// scales. There is no `AspectRatio` any more: Chapter 5.1 §1 wants full-bleed,
/// so the box is covered and clipped rather than contained.
Future<double?> _pumpAndReadRatio(
  WidgetTester tester, {
  required Size window,
  required PreviewFrame frame,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        recordingPipelineProvider.overrideWithValue(_FakePipeline(frame)),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: window),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: CameraPreviewSurface(),
        ),
      ),
    ),
  );
  await tester.pump();

  final Iterable<SizedBox> found = tester.widgetList<SizedBox>(
    find.descendant(
      of: find.byType(FittedBox),
      matching: find.byType(SizedBox),
    ),
  );
  if (found.isEmpty) {
    return null;
  }
  final SizedBox box = found.first;
  final double? w = box.width;
  final double? h = box.height;
  return (w == null || h == null || h == 0) ? null : w / h;
}

void main() {
  // 1920x1080. The pipeline now reports this untouched, whatever the handset
  // is doing.
  const PreviewFrame native = PreviewFrame(
    textureId: 7,
    aspectRatio: 16 / 9,
    quarterTurns: 0,
  );

  group('the ratio follows the WINDOW, not the sensor', () {
    testWidgets('a landscape window gets the native ratio', (
      WidgetTester tester,
    ) async {
      final double? built = await _pumpAndReadRatio(
        tester,
        window: const Size(793, 360),
        frame: native,
      );

      expect(built, closeTo(16 / 9, 0.0001));
    });

    testWidgets('a portrait window gets the inverted ratio', (
      WidgetTester tester,
    ) async {
      final double? built = await _pumpAndReadRatio(
        tester,
        window: const Size(360, 793),
        frame: native,
      );

      expect(built, closeTo(9 / 16, 0.0001));
    });

    testWidgets(
      'a stale portrait quarterTurns still gets the landscape ratio',
      (WidgetTester tester) async {
        // The exact regression. `deviceOrientation` updates only when the
        // accelerometer fires, so a handset lying still while `SystemChrome`
        // rotates the window reports `portraitUp` — quarterTurns 0 — in a
        // landscape window. The ratio must not follow it.
        const PreviewFrame stale = PreviewFrame(
          textureId: 7,
          aspectRatio: 16 / 9,
          quarterTurns: 0,
        );

        final double? built = await _pumpAndReadRatio(
          tester,
          window: const Size(793, 360),
          frame: stale,
        );

        expect(built, closeTo(16 / 9, 0.0001));
      },
    );
  });

  group('the preview is framed like the handset s own camera app', () {
    testWidgets('it CONTAINS — true ratio, bars on the long edges', (
      WidgetTester tester,
    ) async {
      // Matching the device camera app: the picture fills the full height and
      // keeps its ratio, with black to the left and right. `cover` was tried
      // and rejected — filling every edge crops away field of view the
      // Collector is about to record.
      await _pumpAndReadRatio(
        tester,
        window: const Size(793, 360),
        frame: native,
      );

      final FittedBox box = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(box.fit, BoxFit.contain);
    });

    testWidgets('it is clipped to its box regardless', (
      WidgetTester tester,
    ) async {
      // Cheap insurance: nothing should ever paint outside the preview box,
      // whichever fit is in force.
      await _pumpAndReadRatio(
        tester,
        window: const Size(793, 360),
        frame: native,
      );

      expect(find.byType(ClipRect), findsWidgets);
      final FittedBox box = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(box.clipBehavior, Clip.hardEdge);
    });

    testWidgets('the ratio comes from a sized box, not an AspectRatio', (
      WidgetTester tester,
    ) async {
      await _pumpAndReadRatio(
        tester,
        window: const Size(793, 360),
        frame: native,
      );

      expect(find.byType(AspectRatio), findsNothing);
    });
  });

  group('the seam still reports black for no session', () {
    testWidgets('a null frame builds no AspectRatio at all', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            recordingPipelineProvider.overrideWithValue(_FakePipeline(null)),
          ],
          child: const MediaQuery(
            data: MediaQueryData(size: Size(793, 360)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: CameraPreviewSurface(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FittedBox), findsNothing);
    });
  });
}
