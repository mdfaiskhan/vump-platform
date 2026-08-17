@Tags(<String>['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/features/upload/presentation/widgets/chunk_status_pill.dart';

/// Volume 9 Chapter 9.7 §2's visual regression, for the project's first
/// Design System components.
///
/// §2: *"Every reusable Design System component … has a golden test capturing
/// its rendered output in both light and dark theme"*, and *"a golden test
/// failing on an unintentional pixel diff is a hard CI gate"*.
///
/// ## Why these run on CI only
///
/// Flutter renders text differently on different hosts. A baseline captured on
/// Windows does not match one rendered on `ubuntu-latest`, so goldens
/// committed from a developer machine would fail on their first CI run and
/// every run after — a gate that goes red for a reason unrelated to what it
/// guards.
///
/// This project already carries three checks that were hollow or misleading
/// for structurally similar reasons (open items 41, 50, 51), so the decision
/// was to generate and verify against the real CI target only. Locally these
/// report as **skipped**, which is visible in the runner output rather than
/// quietly absent. A-095.
///
/// `golden_toolkit` is not used and is not needed — it is discontinued
/// (A-027), and `matchesGoldenFile` is built into `flutter_test`.
void main() {
  final bool onCi = Platform.environment.containsKey('GITHUB_ACTIONS');

  Future<void> capture(
    WidgetTester tester, {
    required ThemeData theme,
    required String name,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final ChunkUploadStatus status in ChunkUploadStatus.values)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ChunkStatusPill(
                      status: status,
                      percent: status == ChunkUploadStatus.uploading
                          ? 42
                          : null,
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: ChunkStatusPill(
                    status: ChunkUploadStatus.queued,
                    retryIn: Duration(seconds: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets(
    'status pills — light',
    (WidgetTester tester) =>
        capture(tester, theme: AppTheme.light, name: 'chunk_status_pill_light'),
    skip: !onCi,
  );

  testWidgets(
    'status pills — dark',
    (WidgetTester tester) =>
        capture(tester, theme: AppTheme.dark, name: 'chunk_status_pill_dark'),
    skip: !onCi,
  );
}
