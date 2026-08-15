import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app/config/app_environment.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/upload/application/chunk_upload_pipeline.dart';
import 'package:mobile/features/upload/application/upload_dispatcher.dart';
import 'package:mobile/features/upload/domain/entities/upload_failure_cause.dart';
import 'package:mobile/features/upload/domain/repositories/upload_service_host.dart';

/// Volume 5 Chapter 5.11's dispatcher, driven through its three seams.
///
/// Every assertion here is a sentence from Chapter 5.11 §1 or §3. The chapter
/// owns *when* an upload runs and *when the service runs*, so those are what
/// is tested — no bytes move in this file, and none should: Chapter 5.10's
/// pipeline is tested in `chunk_upload_pipeline_test.dart`.
void main() {
  final DateTime startedAt = DateTime.utc(2026, 8, 16, 10);

  QueuedChunk chunk(String id, ChunkUploadStatus status) => QueuedChunk(
    chunkId: id,
    sessionId: 'session-1',
    sequenceIndex: int.parse(id.split('-').last),
    sessionStartedAt: startedAt,
    status: status,
    fileSizeBytes: 1000,
  );

  List<QueuedChunk> queued(int count) => <QueuedChunk>[
    for (int i = 0; i < count; i++) chunk('chunk-$i', ChunkUploadStatus.queued),
  ];

  late _FakeQueue queue;
  late _FakeServiceHost host;
  late _FakeUploads uploads;

  UploadDispatcher build({
    int concurrency = UploadDispatcher.defaultConcurrency,
  }) {
    return UploadDispatcher(
      queue: queue,
      serviceHost: host,
      uploadNext: uploads.next,
      logger: AppLogger(environment: AppEnvironment.production),
      concurrency: concurrency,
    );
  }

  setUp(() {
    queue = _FakeQueue();
    host = _FakeServiceHost();
    uploads = _FakeUploads();
  });

  group('concurrency — Ch. 5.11 §3', () {
    test('never runs more than the bound at once', () async {
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(queued(5));
      await pumpEventQueue();

      expect(uploads.calls, 2, reason: 'five queued, two slots');
      expect(dispatcher.inFlight, 2);
    });

    test('a finished upload frees exactly one slot', () async {
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(queued(5));
      await pumpEventQueue();

      uploads.complete(const UploadOutcome.complete(chunkId: 'chunk-0'));
      await pumpEventQueue();

      expect(uploads.calls, 3);
      expect(dispatcher.inFlight, 2, reason: 'the bound still holds');
    });

    test('the bound is configurable and one is a legal bound', () async {
      final UploadDispatcher dispatcher = build(concurrency: 1);
      dispatcher.start();

      queue.push(queued(4));
      await pumpEventQueue();

      expect(uploads.calls, 1);
    });

    test('a dispatcher that runs nothing is rejected', () {
      expect(() => build(concurrency: 0), throwsA(isA<AssertionError>()));
    });
  });

  group('service lifecycle — Ch. 5.11 §1', () {
    test(
      'does not start the service while everything is merely queued',
      () async {
        // §1: the service starts "the moment any chunk enters Uploading", which
        // is a claim actually having happened — not a row waiting to be
        // claimed.
        final UploadDispatcher dispatcher = build();
        dispatcher.start();

        queue.push(queued(3));
        await pumpEventQueue();

        expect(host.starts, 0);
      },
    );

    test('starts the service once a chunk reaches uploading', () async {
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(queued(3));
      await pumpEventQueue();
      queue.push(<QueuedChunk>[
        chunk('chunk-0', ChunkUploadStatus.uploading),
        chunk('chunk-1', ChunkUploadStatus.queued),
        chunk('chunk-2', ChunkUploadStatus.queued),
      ]);
      await pumpEventQueue();

      expect(host.starts, 1);
      expect(host.lastText, 'Uploading 1 of 3 chunks.');
    });

    test(
      "is NOT restarted per chunk — §1's notification-flicker rule",
      () async {
        final UploadDispatcher dispatcher = build();
        dispatcher.start();

        queue.push(queued(3));
        await pumpEventQueue();

        // Three chunks move through uploading, one after another.
        for (int done = 0; done < 3; done++) {
          queue.push(<QueuedChunk>[
            for (int i = 0; i < done; i++)
              chunk('chunk-$i', ChunkUploadStatus.complete),
            for (int i = done; i < 3; i++)
              chunk('chunk-$i', ChunkUploadStatus.uploading),
          ]);
          await pumpEventQueue();
        }

        expect(host.starts, 1, reason: 'one service for the whole batch');
        expect(host.stops, 0);
        expect(host.updates, greaterThan(0), reason: 'the text is rewritten');
      },
    );

    test('the notification text tracks the aggregate', () async {
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(<QueuedChunk>[
        chunk('chunk-0', ChunkUploadStatus.uploading),
        chunk('chunk-1', ChunkUploadStatus.queued),
        chunk('chunk-2', ChunkUploadStatus.queued),
      ]);
      await pumpEventQueue();
      expect(host.lastText, 'Uploading 1 of 3 chunks.');

      queue.push(<QueuedChunk>[
        chunk('chunk-0', ChunkUploadStatus.complete),
        chunk('chunk-1', ChunkUploadStatus.uploading),
        chunk('chunk-2', ChunkUploadStatus.queued),
      ]);
      await pumpEventQueue();
      expect(host.lastText, 'Uploading 2 of 3 chunks.');
    });

    test('stops the service when the queue drains', () async {
      final UploadDispatcher dispatcher = build(concurrency: 1);
      dispatcher.start();

      queue.push(queued(1));
      await pumpEventQueue();
      queue.push(<QueuedChunk>[chunk('chunk-0', ChunkUploadStatus.uploading)]);
      await pumpEventQueue();
      expect(host.starts, 1);

      uploads.complete(const UploadOutcome.complete(chunkId: 'chunk-0'));
      queue.push(<QueuedChunk>[chunk('chunk-0', ChunkUploadStatus.complete)]);
      await pumpEventQueue();

      expect(host.stops, 1);
      expect(host.running, isFalse);
    });

    test(
      "stops when every remaining item is Failed — §1's second condition",
      () async {
        final UploadDispatcher dispatcher = build();
        dispatcher.start();

        queue.push(queued(2));
        await pumpEventQueue();
        queue.push(<QueuedChunk>[
          chunk('chunk-0', ChunkUploadStatus.uploading),
          chunk('chunk-1', ChunkUploadStatus.uploading),
        ]);
        await pumpEventQueue();
        expect(host.starts, 1);

        uploads.completeAll(
          const UploadOutcome.failed(
            chunkId: 'chunk-0',
            cause: UploadFailureCause.rejectedByBackend,
            detail: 'refused',
          ),
        );
        queue.push(<QueuedChunk>[
          chunk('chunk-0', ChunkUploadStatus.failed),
          chunk('chunk-1', ChunkUploadStatus.failed),
        ]);
        await pumpEventQueue();

        expect(
          host.stops,
          1,
          reason: 'a batch awaiting manual retry is a finished batch',
        );
      },
    );

    test('a second batch after a drain starts the service again', () async {
      final UploadDispatcher dispatcher = build(concurrency: 1);
      dispatcher.start();

      queue.push(queued(1));
      await pumpEventQueue();
      queue.push(<QueuedChunk>[chunk('chunk-0', ChunkUploadStatus.uploading)]);
      await pumpEventQueue();
      uploads.complete(const UploadOutcome.complete(chunkId: 'chunk-0'));
      queue.push(<QueuedChunk>[chunk('chunk-0', ChunkUploadStatus.complete)]);
      await pumpEventQueue();
      expect(host.stops, 1);

      queue.push(<QueuedChunk>[
        chunk('chunk-0', ChunkUploadStatus.complete),
        chunk('chunk-9', ChunkUploadStatus.queued),
      ]);
      await pumpEventQueue();
      queue.push(<QueuedChunk>[
        chunk('chunk-0', ChunkUploadStatus.complete),
        chunk('chunk-9', ChunkUploadStatus.uploading),
      ]);
      await pumpEventQueue();

      expect(host.starts, 2);
      expect(
        host.lastText,
        'Uploading 1 chunk.',
        reason: 'the new batch counts only its own work',
      );
    });

    test('a completed chunk from an earlier batch is not counted', () async {
      // `complete` rows persist until Ch. 5.15's cleanup runs, so a
      // denominator read off the raw rows would grow forever.
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(<QueuedChunk>[
        for (int i = 0; i < 20; i++)
          chunk('chunk-$i', ChunkUploadStatus.complete),
        chunk('chunk-99', ChunkUploadStatus.uploading),
      ]);
      await pumpEventQueue();

      expect(host.lastText, 'Uploading 1 chunk.');
    });
  });

  group('the notification is visibility, not a precondition', () {
    test('uploading continues when the service cannot start', () async {
      host.startResult = false;
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(queued(3));
      await pumpEventQueue();

      expect(uploads.calls, 2, reason: 'chunks already recorded still go');
    });

    test('a refused start is not retried within the batch', () async {
      // Each attempt can raise a permission prompt; prompting per chunk would
      // be worse than showing no notification at all.
      host.startResult = false;
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      for (int i = 0; i < 4; i++) {
        queue.push(<QueuedChunk>[
          chunk('chunk-0', ChunkUploadStatus.uploading),
          chunk('chunk-1', ChunkUploadStatus.queued),
        ]);
        await pumpEventQueue();
      }

      expect(host.starts, 1);
    });

    test('a refusal is reconsidered once the queue drains', () async {
      host.startResult = false;
      final UploadDispatcher dispatcher = build(concurrency: 1);
      dispatcher.start();

      queue.push(queued(1));
      await pumpEventQueue();
      queue.push(<QueuedChunk>[chunk('chunk-0', ChunkUploadStatus.uploading)]);
      await pumpEventQueue();
      expect(host.starts, 1);

      uploads.complete(const UploadOutcome.complete(chunkId: 'chunk-0'));
      queue.push(<QueuedChunk>[chunk('chunk-0', ChunkUploadStatus.complete)]);
      await pumpEventQueue();

      host.startResult = true;
      queue.push(<QueuedChunk>[
        chunk('chunk-0', ChunkUploadStatus.complete),
        chunk('chunk-1', ChunkUploadStatus.queued),
      ]);
      await pumpEventQueue();
      queue.push(<QueuedChunk>[
        chunk('chunk-0', ChunkUploadStatus.complete),
        chunk('chunk-1', ChunkUploadStatus.uploading),
      ]);
      await pumpEventQueue();

      expect(host.starts, 2, reason: 'permission may have been granted since');
    });

    test('a throwing service host does not stop the upload', () async {
      host.throwOnStart = true;
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(queued(2));
      await pumpEventQueue();

      expect(uploads.calls, 2);
    });
  });

  group('failure handling', () {
    test('a wiring fault stops the dispatcher rather than spinning', () async {
      // `sessionRegistrarProvider` throws until features/projects_tasks/
      // exists (open item 36). ChunkUploadPipeline documents that it never
      // throws for an upload failure, so a throw means the wiring is wrong and
      // no amount of retrying changes it.
      uploads.throwOnCall = true;
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(queued(5));
      await pumpEventQueue();

      final int callsAfterFault = uploads.calls;

      queue.push(queued(5));
      await pumpEventQueue();

      expect(uploads.calls, callsAfterFault, reason: 'it does not retry');
      expect(dispatcher.inFlight, 0);
      expect(queue.cancelled, isTrue);
    });

    test('claiming nothing retires the runner without spinning', () async {
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(queued(2));
      await pumpEventQueue();
      final int launched = uploads.calls;

      // Both runners find the queue already emptied by someone else.
      uploads.completeAll(null);
      await pumpEventQueue();

      expect(
        uploads.calls,
        launched,
        reason: 'a null result re-launches nothing',
      );
      expect(dispatcher.inFlight, 0);
      expect(host.starts, 0);
    });

    test('a broken queue stream shuts the dispatcher down loudly', () async {
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.fail(StateError('the watch died'));
      await pumpEventQueue();

      queue.push(queued(3));
      await pumpEventQueue();

      expect(uploads.calls, 0);
      expect(dispatcher.inFlight, 0);
    });
  });

  group('lifecycle', () {
    test('start is idempotent — one subscription, not two', () {
      final UploadDispatcher dispatcher = build()..start();
      dispatcher.start();

      expect(queue.watchCalls, 1);
    });

    test('shutDown cancels the subscription and stops the service', () async {
      final UploadDispatcher dispatcher = build();
      dispatcher.start();

      queue.push(<QueuedChunk>[chunk('chunk-0', ChunkUploadStatus.uploading)]);
      await pumpEventQueue();
      expect(host.starts, 1);

      await dispatcher.shutDown();

      expect(queue.cancelled, isTrue);
      expect(host.stops, 1);
    });

    test('a shut-down dispatcher does not restart on a new emission', () async {
      final UploadDispatcher dispatcher = build();
      dispatcher.start();
      await dispatcher.shutDown();

      dispatcher.start();
      queue.push(queued(3));
      await pumpEventQueue();

      expect(uploads.calls, 0);
    });
  });
}

/// A queue whose emissions the test drives.
///
/// Single-subscription rather than broadcast, for the reason
/// `upload_queue_notifier_test.dart` already recorded: a broadcast stream
/// drops events added before a listener attaches, and the ordering a real Isar
/// watch gives is what these tests depend on.
class _FakeQueue implements ChunkQueueSource {
  final StreamController<List<QueuedChunk>> _controller =
      StreamController<List<QueuedChunk>>(onCancel: () {});

  int watchCalls = 0;
  bool cancelled = false;

  void push(List<QueuedChunk> rows) {
    if (!_controller.isClosed) {
      _controller.add(rows);
    }
  }

  void fail(Object error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }

  @override
  Stream<List<QueuedChunk>> watchQueue() {
    watchCalls += 1;
    _controller.onCancel = () => cancelled = true;
    return _controller.stream;
  }

  @override
  Future<List<QueuedChunk>> currentQueue() async => <QueuedChunk>[];

  @override
  Future<void> requeue(String chunkId) async {}
}

/// Records what Chapter 5.11 §1 asked the service to do.
class _FakeServiceHost implements UploadServiceHost {
  int starts = 0;
  int updates = 0;
  int stops = 0;
  bool running = false;
  bool startResult = true;
  bool throwOnStart = false;
  String? lastText;

  @override
  Future<bool> start({required String title, required String text}) async {
    starts += 1;
    if (throwOnStart) {
      throw StateError('the platform refused');
    }
    lastText = text;
    running = startResult;
    return startResult;
  }

  @override
  Future<void> update({required String title, required String text}) async {
    updates += 1;
    lastText = text;
  }

  @override
  Future<void> stop() async {
    stops += 1;
    running = false;
  }

  @override
  Future<bool> isRunning() async => running;
}

/// Chapter 5.10's seam, held open so a test controls when a chunk finishes.
class _FakeUploads {
  final List<Completer<UploadOutcome?>> _pending =
      <Completer<UploadOutcome?>>[];

  int calls = 0;
  bool throwOnCall = false;

  Future<UploadOutcome?> next() {
    calls += 1;
    if (throwOnCall) {
      return Future<UploadOutcome?>.error(
        UnimplementedError('sessionRegistrarProvider has no implementation'),
        StackTrace.current,
      );
    }
    final Completer<UploadOutcome?> completer = Completer<UploadOutcome?>();
    _pending.add(completer);
    return completer.future;
  }

  void complete(UploadOutcome? outcome) {
    _pending.removeAt(0).complete(outcome);
  }

  void completeAll(UploadOutcome? outcome) {
    final List<Completer<UploadOutcome?>> all =
        List<Completer<UploadOutcome?>>.of(_pending);
    _pending.clear();
    for (final Completer<UploadOutcome?> completer in all) {
      completer.complete(outcome);
    }
  }
}
