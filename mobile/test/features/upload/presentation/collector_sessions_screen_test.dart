import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/providers/queue_ports.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/core/time/interfaces/clock.dart';
import 'package:mobile/core/time/providers/clock_provider.dart';
import 'package:mobile/features/upload/application/upload_dispatcher_status_notifier.dart';
import 'package:mobile/features/upload/domain/entities/upload_dispatcher_status.dart';
import 'package:mobile/features/upload/presentation/collector_sessions_screen.dart';

import '../../../core/time/fakes/fake_clock.dart';

/// C-11, driven through the queue it renders.
///
/// Mission 3.8.1's lesson (open item 32) is that a harness which drives a
/// notifier proves the layer it drives and assumes the layer above calls it.
/// These tests tap the real screen.
void main() {
  final DateTime start = DateTime.utc(2026, 8, 16, 9);
  final List<_FakeQueue> opened = <_FakeQueue>[];
  late FakeClock clock;

  QueuedChunk chunk(
    int seq,
    ChunkUploadStatus status, {
    DateTime? nextAttemptAt,
    String session = 's1',
  }) => QueuedChunk(
    chunkId: 'c$seq-$session',
    sessionId: session,
    sequenceIndex: seq,
    sessionStartedAt: start,
    status: status,
    fileSizeBytes: 1000,
    nextAttemptAt: nextAttemptAt,
  );

  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester,
    _FakeQueue queue, {
    bool halted = false,
  }) async {
    opened.add(queue);
    container = ProviderContainer(
      overrides: <Override>[
        chunkQueueSourceProvider.overrideWithValue(queue),
        clockProvider.overrideWithValue(clock as Clock),
      ],
    );
    addTearDown(container.dispose);
    if (halted) {
      container.read(uploadDispatcherStatusProvider.notifier).markHalted();
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CollectorSessionsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => clock = FakeClock(start: start));
  tearDown(() {
    for (final _FakeQueue queue in opened) {
      queue.dispose();
    }
    opened.clear();
  });

  testWidgets('an empty queue explains itself, never a bare list', (
    WidgetTester tester,
  ) async {
    // Chapter 2.9 §4.2 forbids a bare empty list.
    await pump(tester, _FakeQueue(<QueuedChunk>[]));

    expect(find.text('Nothing to upload yet.'), findsOneWidget);
  });

  testWidgets('renders one row per chunk, grouped under its session', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _FakeQueue(<QueuedChunk>[
        chunk(0, ChunkUploadStatus.complete),
        chunk(1, ChunkUploadStatus.uploading),
        chunk(2, ChunkUploadStatus.queued),
      ]),
    );

    expect(find.text('Chunk 1'), findsOneWidget);
    expect(find.text('Chunk 2'), findsOneWidget);
    expect(find.text('Chunk 3'), findsOneWidget);

    // Was `Session s1` until Mission 5.1.4. Chapter 2.7 asks for a heading
    // "grouped under the session name" and a session has no name, so the
    // heading is when it was recorded — the only identifying fact a Collector
    // holds. The raw id told them nothing they could match against their day.
    expect(find.textContaining('Session s1'), findsNothing);
    expect(find.textContaining('Today'), findsOneWidget);
  });

  testWidgets('every one of Chapter 5.9 §1s four states renders', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _FakeQueue(<QueuedChunk>[
        chunk(0, ChunkUploadStatus.queued),
        chunk(1, ChunkUploadStatus.uploading),
        chunk(2, ChunkUploadStatus.failed),
        chunk(3, ChunkUploadStatus.complete),
      ]),
    );

    expect(find.text('Queued'), findsOneWidget);
    expect(find.text('Uploading'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets('a failed row offers Retry Chunk and nothing else does', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _FakeQueue(<QueuedChunk>[
        chunk(0, ChunkUploadStatus.failed),
        chunk(1, ChunkUploadStatus.complete),
        chunk(2, ChunkUploadStatus.queued),
      ]),
    );

    expect(find.text('Retry Chunk'), findsOneWidget);
  });

  testWidgets('tapping Retry Chunk reaches the queue — FR-UPL-07', (
    WidgetTester tester,
  ) async {
    final _FakeQueue queue = _FakeQueue(<QueuedChunk>[
      chunk(0, ChunkUploadStatus.failed),
    ]);
    await pump(tester, queue);

    await tester.tap(find.text('Retry Chunk'));
    await tester.pump();

    expect(queue.requeued, <String>['c0-s1']);
  });

  testWidgets('a chunk in backoff shows its countdown — Ch. 2.9 §4.3', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _FakeQueue(<QueuedChunk>[
        chunk(
          0,
          ChunkUploadStatus.queued,
          nextAttemptAt: start.add(const Duration(seconds: 20)),
        ),
      ]),
    );

    expect(find.text('Retrying in 20s'), findsOneWidget);
    expect(find.text('Queued'), findsNothing);
  });

  testWidgets('an elapsed deadline reads Queued again', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _FakeQueue(<QueuedChunk>[
        chunk(
          0,
          ChunkUploadStatus.queued,
          nextAttemptAt: start.subtract(const Duration(seconds: 1)),
        ),
      ]),
    );

    expect(find.text('Queued'), findsOneWidget);
  });

  testWidgets('an uploading row draws a progress bar beneath it', (
    WidgetTester tester,
  ) async {
    // Chapter 2.7: "progress bar beneath the row, not inside the pill".
    await pump(
      tester,
      _FakeQueue(<QueuedChunk>[chunk(0, ChunkUploadStatus.uploading)]),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('a complete row is inert — no bar, no action', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _FakeQueue(<QueuedChunk>[chunk(0, ChunkUploadStatus.complete)]),
    );

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Retry Chunk'), findsNothing);
  });
  group('open item 60 — a halted dispatcher is visible, not silent', () {
    testWidgets('no banner while the dispatcher is running', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        _FakeQueue(<QueuedChunk>[chunk(0, ChunkUploadStatus.queued)]),
      );

      expect(find.textContaining("Uploads aren't running"), findsNothing);
    });

    testWidgets('a banner appears once it halts', (WidgetTester tester) async {
      await pump(
        tester,
        _FakeQueue(<QueuedChunk>[chunk(0, ChunkUploadStatus.queued)]),
        halted: true,
      );

      expect(find.text("Uploads aren't running."), findsOneWidget);
      expect(find.textContaining('Nothing is lost'), findsOneWidget);
    });

    testWidgets('the chunk keeps its own status — no fifth pill state', (
      WidgetTester tester,
    ) async {
      // The banner is a screen-level fact. Painting it onto the pill would
      // say something false about the chunk, which is queued and fine.
      await pump(
        tester,
        _FakeQueue(<QueuedChunk>[chunk(0, ChunkUploadStatus.queued)]),
        halted: true,
      );

      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets('it shows over an empty queue too', (
      WidgetTester tester,
    ) async {
      // The Collector should learn uploads are down *before* recording more,
      // not only once something is waiting.
      await pump(tester, _FakeQueue(<QueuedChunk>[]), halted: true);

      expect(find.text("Uploads aren't running."), findsOneWidget);
      expect(find.text('Nothing to upload yet.'), findsOneWidget);
    });

    testWidgets('once halted it stays halted', (WidgetTester tester) async {
      await pump(tester, _FakeQueue(<QueuedChunk>[]), halted: true);

      container.read(uploadDispatcherStatusProvider.notifier).markHalted();
      await tester.pump();

      expect(
        container.read(uploadDispatcherStatusProvider),
        UploadDispatcherStatus.halted,
      );
    });
  });
}

class _FakeQueue implements ChunkQueueSource {
  _FakeQueue(this._rows);

  final List<QueuedChunk> _rows;
  final List<String> requeued = <String>[];
  final StreamController<List<QueuedChunk>> _controller =
      StreamController<List<QueuedChunk>>.broadcast();

  @override
  Stream<List<QueuedChunk>> watchQueue() async* {
    yield _rows;
    yield* _controller.stream;
  }

  @override
  Future<List<QueuedChunk>> currentQueue() async => _rows;

  @override
  Future<void> requeue(String chunkId) async => requeued.add(chunkId);

  /// The screen never closes the source it was given, so the fake closes its
  /// own controller when the test is done with it.
  void dispose() => unawaited(_controller.close());
}
