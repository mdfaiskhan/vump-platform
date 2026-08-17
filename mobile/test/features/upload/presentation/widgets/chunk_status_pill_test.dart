import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app/theme/app_status_colors.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/features/upload/presentation/widgets/chunk_status_pill.dart';

/// Chapter 2.10 §2.1's colour-not-alone rule, asserted per state.
void main() {
  Future<void> pump(
    WidgetTester tester,
    ChunkUploadStatus status, {
    int? percent,
    Duration? retryIn,
    ThemeData? theme,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: ChunkStatusPill(
          status: status,
          percent: percent,
          retryIn: retryIn,
        ),
      ),
    ),
  );

  group('open item 106 — a pill announces itself ONCE', () {
    // Found on a CPH2707, not by a test: `uiautomator dump` reported
    // `content-desc` read 'Queued' twice on C-11. `Semantics(label:)` does not
    // replace a child `Text`'s contribution — the two merge — so every state
    // doubled. `excludeSemantics: true` is the fix, and these are the
    // assertions that would have caught it.
    for (final (ChunkUploadStatus status, String expected)
        in <(ChunkUploadStatus, String)>[
          (ChunkUploadStatus.queued, 'Queued'),
          (ChunkUploadStatus.uploading, 'Uploading'),
          (ChunkUploadStatus.complete, 'Complete'),
        ]) {
      testWidgets('${status.wireName} is not doubled', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pump(tester, status);

        final SemanticsNode node = tester.getSemantics(
          find.byType(ChunkStatusPill),
        );
        // Equality, not `contains`: the defect was a label that CONTAINED the
        // right word twice, so a substring assertion passes on the bug.
        expect(node.label, expected);
        handle.dispose();
      });
    }

    testWidgets('the live percentage is announced once, with its number', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, ChunkUploadStatus.uploading, percent: 62);

      expect(
        tester.getSemantics(find.byType(ChunkStatusPill)).label,
        'Uploading 62%',
      );
      handle.dispose();
    });

    testWidgets('failed KEEPS its retry sentence — the label is composed, '
        'not merely deduplicated', (WidgetTester tester) async {
      // The half that makes `excludeSemantics` correct rather than lossy.
      // `_semanticLabel()` adds a sentence the visible text does not carry,
      // and excluding the child must not take that with it.
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, ChunkUploadStatus.failed);

      expect(
        tester.getSemantics(find.byType(ChunkStatusPill)).label,
        'Failed. Retry available.',
      );
      handle.dispose();
    });

    testWidgets('the visible word is still rendered', (
      WidgetTester tester,
    ) async {
      // `excludeSemantics` removes the child from the SEMANTICS tree only.
      // If it ever removed the text from the screen, every sighted Collector
      // would lose the pill's word and these other tests would not notice.
      await pump(tester, ChunkUploadStatus.queued);
      expect(find.text('Queued'), findsOneWidget);
    });
  });

  group('every state carries a colour AND an icon AND a label', () {
    for (final (ChunkUploadStatus status, String label)
        in <(ChunkUploadStatus, String)>[
          (ChunkUploadStatus.queued, 'Queued'),
          (ChunkUploadStatus.uploading, 'Uploading'),
          (ChunkUploadStatus.failed, 'Failed'),
          (ChunkUploadStatus.complete, 'Complete'),
        ]) {
      testWidgets('${status.wireName} shows its word and an icon', (
        WidgetTester tester,
      ) async {
        await pump(tester, status);

        expect(find.text(label), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
      });
    }

    testWidgets('failed and complete use different icon shapes', (
      WidgetTester tester,
    ) async {
      // §2.1 names exactly this pair: a Collector with red-green colour
      // blindness must tell them apart "from the label and icon shape alone".
      await pump(tester, ChunkUploadStatus.failed);
      final IconData failed = tester.widget<Icon>(find.byType(Icon)).icon!;

      await pump(tester, ChunkUploadStatus.complete);
      final IconData complete = tester.widget<Icon>(find.byType(Icon)).icon!;

      expect(failed, isNot(complete));
    });
  });

  group('Chapter 2.7 — the uploading pill carries the live percentage', () {
    testWidgets('shows it when known', (WidgetTester tester) async {
      await pump(tester, ChunkUploadStatus.uploading, percent: 42);

      expect(find.text('Uploading 42%'), findsOneWidget);
    });

    testWidgets('omits it rather than inventing 0%', (
      WidgetTester tester,
    ) async {
      await pump(tester, ChunkUploadStatus.uploading);

      expect(find.text('Uploading'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('Chapter 2.9 §4.3 — a pending retry is visible', () {
    testWidgets('a queued chunk in backoff says so', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        ChunkUploadStatus.queued,
        retryIn: const Duration(seconds: 18),
      );

      expect(find.text('Retrying in 18s'), findsOneWidget);
    });

    testWidgets('a queued chunk not in backoff reads Queued', (
      WidgetTester tester,
    ) async {
      await pump(tester, ChunkUploadStatus.queued);

      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets('a long wait reads in minutes', (WidgetTester tester) async {
      await pump(
        tester,
        ChunkUploadStatus.queued,
        retryIn: const Duration(seconds: 95),
      );

      expect(find.text('Retrying in 1m'), findsOneWidget);
    });
  });

  group('the palette comes from the theme, in both brightnesses', () {
    testWidgets('light uses the published hue', (WidgetTester tester) async {
      await pump(tester, ChunkUploadStatus.complete);

      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      expect((box.decoration as BoxDecoration).color, AppStatusColors.goodHue);
    });

    testWidgets('dark renders without falling back', (
      WidgetTester tester,
    ) async {
      await pump(tester, ChunkUploadStatus.failed, theme: AppTheme.dark);

      expect(find.text('Failed'), findsOneWidget);
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      expect(
        (box.decoration as BoxDecoration).color,
        AppStatusColors.dark.critical,
      );
    });
  });
}
