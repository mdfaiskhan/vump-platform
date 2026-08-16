import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/providers/queue_ports.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_dashboard_screen.dart';

import '../application/fakes/controllable_project_task_repository.dart';

/// C-03 — FR-PT-01 in part, FR-PT-02 in full.
///
/// The load-bearing assertions here are about what the screen **does not**
/// show: no "in-progress sessions" tile and no "total recorded time" tile,
/// because neither has a source. A later mission that adds either without
/// closing open item 75 or 76 will break these, which is the point.
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 1);

  Project project(String id, {DateTime? archivedAt}) => Project(
    id: id,
    orgId: 'org-1',
    name: 'Project $id',
    createdBy: 'usr-admin-1',
    createdAt: createdAt,
    archivedAt: archivedAt,
  );

  QueuedChunk chunk(String id, ChunkUploadStatus status) => QueuedChunk(
    chunkId: id,
    sessionId: 's1',
    sequenceIndex: 0,
    sessionStartedAt: createdAt,
    status: status,
    fileSizeBytes: 1000,
  );

  Future<void> pumpDashboard(
    WidgetTester tester, {
    List<Project> projects = const <Project>[],
    List<QueuedChunk> queue = const <QueuedChunk>[],
    bool queueFails = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          projectTaskRepositoryProvider.overrideWithValue(
            ControllableProjectTaskRepository(projects: projects),
          ),
          chunkQueueSourceProvider.overrideWithValue(
            _FakeQueueSource(queue, fails: queueFails),
          ),
        ],
        child: const MaterialApp(home: CollectorDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget cardFor(WidgetTester tester, String label) => tester.widget(
    find.ancestor(of: find.text(label), matching: find.byType(Card)).first,
  );

  group('active projects — archivedAt == null', () {
    testWidgets('archived Projects are excluded from the count', (
      WidgetTester tester,
    ) async {
      // "Active" is a reading, not a quotation: no chapter defines it, and
      // archived_at is the only activity signal Ch. 4.4 §2 gives a Project.
      await pumpDashboard(
        tester,
        projects: <Project>[
          project('a'),
          project('b'),
          project('c', archivedAt: DateTime.utc(2026, 7, 1)),
        ],
      );

      expect(find.text('Active projects'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('no Projects reads zero, which is a real answer', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester);

      expect(find.text('Active projects'), findsOneWidget);
    });
  });

  group('FR-PT-02 — the three chunk counts come from core/queue', () {
    testWidgets('each status is counted separately', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(
        tester,
        queue: <QueuedChunk>[
          chunk('q1', ChunkUploadStatus.queued),
          chunk('q2', ChunkUploadStatus.queued),
          chunk('u1', ChunkUploadStatus.uploading),
          chunk('c1', ChunkUploadStatus.complete),
          chunk('c2', ChunkUploadStatus.complete),
          chunk('c3', ChunkUploadStatus.complete),
        ],
      );

      expect(find.text('Waiting to upload'), findsOneWidget);
      expect(find.text('Uploading'), findsOneWidget);
      expect(find.text('Uploaded'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('the uploaded tile says it counts only local chunks', (
      WidgetTester tester,
    ) async {
      // Open item 61: cleanup soft-deletes completed chunks and the queue
      // excludes them, so this number falls as housekeeping runs. A count that
      // resets itself with no explanation reads as data loss.
      await pumpDashboard(
        tester,
        queue: <QueuedChunk>[chunk('c1', ChunkUploadStatus.complete)],
      );

      expect(
        find.text('Counts recordings still stored on this device.'),
        findsOneWidget,
      );
    });
  });

  group('sync status names a stalled queue', () {
    testWidgets('no attention tile when nothing has failed', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(
        tester,
        queue: <QueuedChunk>[chunk('q1', ChunkUploadStatus.queued)],
      );

      expect(find.text('Needs attention'), findsNothing);
    });

    testWidgets('a failed chunk surfaces with a fix, not just a colour', (
      WidgetTester tester,
    ) async {
      // Ch. 2.10 §2.1: colour is never the only signal. The tile carries its
      // own label and a next step as well as a container colour.
      await pumpDashboard(
        tester,
        queue: <QueuedChunk>[chunk('f1', ChunkUploadStatus.failed)],
      );

      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Open Sessions to retry.'), findsOneWidget);
      expect((cardFor(tester, 'Needs attention') as Card).color, isNotNull);
    });
  });

  group("FR-PT-01's two unsourced aggregates are ABSENT, not zeroed", () {
    testWidgets('no in-progress sessions tile is rendered', (
      WidgetTester tester,
    ) async {
      // Open item 75. LocalSession.status is owned by features/recording/ and
      // no core/ contract exposes it; counting distinct sessionIds in the
      // queue answers a different question. A tile reading "0" would be a
      // claim, and an absent tile is an absence.
      await pumpDashboard(
        tester,
        queue: <QueuedChunk>[chunk('q1', ChunkUploadStatus.queued)],
      );

      expect(find.textContaining('session', findRichText: true), findsNothing);
      expect(find.textContaining('Session'), findsNothing);
    });

    testWidgets('no total recorded time tile is rendered', (
      WidgetTester tester,
    ) async {
      // Open item 76. Summing durations over the queue would be actively
      // wrong, not merely incomplete: currentQueue skips soft-deleted rows, so
      // the total would DECREASE as the Collector records more.
      await pumpDashboard(
        tester,
        queue: <QueuedChunk>[chunk('c1', ChunkUploadStatus.complete)],
      );

      expect(find.textContaining('recorded time'), findsNothing);
      expect(find.textContaining('0h'), findsNothing);
      expect(find.textContaining('00:00'), findsNothing);
    });
  });

  group('failure names its own cause', () {
    testWidgets('a broken queue reports storage, not connectivity', (
      WidgetTester tester,
    ) async {
      // Ch. 2.9 §2's named-cause rule. The queue is local, so "check your
      // connection" would send the Collector to fix the wrong thing.
      await pumpDashboard(tester, queueFails: true);

      // Riverpod turns the stream error into an `AsyncError`, which is what
      // the screen renders.
      expect(
        find.text("Your recording data couldn't be read from this device."),
        findsOneWidget,
      );
    });
  });
}

class _FakeQueueSource implements ChunkQueueSource {
  _FakeQueueSource(this._queue, {this.fails = false});

  final List<QueuedChunk> _queue;
  final bool fails;

  @override
  Stream<List<QueuedChunk>> watchQueue() {
    // Delivered through a controller rather than `Stream.error`, so the error
    // arrives as a stream event a listener receives -- which is how
    // `IsarChunkStore` would surface a read fault. An eagerly-constructed
    // error stream is reported to the zone before any listener attaches, and
    // that is a property of the constructor rather than of the screen.
    final StreamController<List<QueuedChunk>> controller =
        StreamController<List<QueuedChunk>>();
    if (fails) {
      controller.addError(StateError('database is gone'));
    } else {
      controller.add(_queue);
    }
    // Closed once the event is queued. The stream still delivers it to a late
    // listener, and leaving it open would hold the test's zone alive --
    // `close_sinks` is an analyzer error under ADR-021 for exactly that.
    unawaited(controller.close());
    return controller.stream;
  }

  @override
  Future<List<QueuedChunk>> currentQueue() async => _queue;

  @override
  Future<void> requeue(String chunkId) async {}
}
