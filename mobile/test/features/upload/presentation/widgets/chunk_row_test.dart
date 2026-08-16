import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/upload/domain/entities/chunk_upload_progress_snapshot.dart';
import 'package:mobile/features/upload/presentation/widgets/chunk_row.dart';

/// C-11's progress bar, and Chapter 2.10 §4's value rule.
///
/// > *"Progress indicators (upload progress, checklist re-run) expose their
/// > state as a value a screen reader can read (e.g. \"62 percent\"), not purely
/// > as an animated visual."*
///
/// **A bare `LinearProgressIndicator` exposes nothing at all.** Before Mission
/// 5.5 an uploading chunk and a stalled one were indistinguishable to a screen
/// reader: the bar animated and said nothing, on C-11 — one of the six screens
/// Chapter 2.10 §8 names for its TalkBack pass.
///
/// The indeterminate case is asserted as deliberately as the determinate one.
/// Dio reports `-1` for a stream whose length it cannot determine, and
/// reporting "0 percent" there would announce a stall that is not happening.
void main() {
  final DateTime start = DateTime.utc(2026, 9, 1, 10);

  QueuedChunk uploading() => QueuedChunk(
    chunkId: 'c0',
    sessionId: 's1',
    sequenceIndex: 0,
    sessionStartedAt: start,
    status: ChunkUploadStatus.uploading,
    fileSizeBytes: 1000,
  );

  Widget app(ChunkUploadProgressSnapshot? progress) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ChunkRow(chunk: uploading(), now: start, progress: progress),
    ),
  );

  testWidgets('a determinate bar reads its percentage aloud', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        const ChunkUploadProgressSnapshot(sentBytes: 620, totalBytes: 1000),
      ),
    );
    await tester.pumpAndSettle();

    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Upload progress'),
    );
    // §4's own example string, and the reason `label` is carried alongside:
    // "62 percent" on its own does not say 62 percent of what.
    expect(node.value, '62 percent');
    handle.dispose();
  });

  testWidgets('an indeterminate bar reports no percentage at all', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(const ChunkUploadProgressSnapshot(sentBytes: 620, totalBytes: -1)),
    );
    // `pump`, not `pumpAndSettle`: an indeterminate bar animates forever, so
    // settling never happens and the test would time out rather than fail on
    // its assertion.
    await tester.pump();

    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Upload progress'),
    );
    // Empty, not "0 percent". An unknown total is unknown, and announcing a
    // number would be inventing one.
    expect(node.value, isEmpty);
    handle.dispose();
  });
}
