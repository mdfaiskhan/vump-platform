import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/upload/application/upload_queue_notifier.dart';

/// Volume 5 Chapter 5.9's queue, driven through its port.
///
/// The notifier owns no ordering of its own — that lives in
/// `QueuedChunk.compareTo` and is tested in `queued_chunk_test.dart`. What is
/// only observable here is the wiring: that it subscribes rather than polls,
/// that retry reaches the source, and that grouping preserves the order it
/// was given rather than re-deriving it.
void main() {
  final DateTime earlier = DateTime.utc(2026, 8, 15, 9);
  final DateTime later = DateTime.utc(2026, 8, 15, 11);

  QueuedChunk chunk({
    required String id,
    required String session,
    required int seq,
    required DateTime startedAt,
    ChunkUploadStatus status = ChunkUploadStatus.queued,
  }) => QueuedChunk(
    chunkId: id,
    sessionId: session,
    sequenceIndex: seq,
    sessionStartedAt: startedAt,
    status: status,
    fileSizeBytes: 1000,
  );

  ProviderContainer build(_FakeQueueSource source) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        chunkQueueSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('it is a live view, not a list', () {
    test('it emits what the source emits, in the order given', () async {
      final _FakeQueueSource source = _FakeQueueSource(<QueuedChunk>[
        chunk(id: 'e0', session: 's1', seq: 0, startedAt: earlier),
        chunk(id: 'e1', session: 's1', seq: 1, startedAt: earlier),
        chunk(id: 'l0', session: 's2', seq: 0, startedAt: later),
      ]);
      final ProviderContainer c = build(source);

      final List<QueuedChunk> queue = await c.read(
        uploadQueueNotifierProvider.future,
      );

      expect(
        queue.map((QueuedChunk q) => q.chunkId),
        <String>['e0', 'e1', 'l0'],
      );
    });

    test('a later push is observed without any polling', () async {
      // Ch. 5.9 §3: "the queue simply resumes reading the same rows". Nothing
      // here asks for a refresh.
      final _FakeQueueSource source = _FakeQueueSource(<QueuedChunk>[]);
      final ProviderContainer c = build(source);

      expect(await c.read(uploadQueueNotifierProvider.future), isEmpty);

      source.push(<QueuedChunk>[
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
      ]);
      await pumpEventQueue();

      expect(c.read(uploadQueueNotifierProvider).value, hasLength(1));
    });

    test('it subscribes exactly once', () async {
      final _FakeQueueSource source = _FakeQueueSource(<QueuedChunk>[]);
      final ProviderContainer c = build(source);

      await c.read(uploadQueueNotifierProvider.future);
      c.read(uploadQueueNotifierProvider);
      c.read(uploadQueueNotifierProvider);

      expect(source.watchCalls, 1);
    });
  });

  group('all four states are present — C-11 renders a pill for each', () {
    test('nothing is filtered out of the view', () async {
      final _FakeQueueSource source = _FakeQueueSource(<QueuedChunk>[
        for (int i = 0; i < ChunkUploadStatus.values.length; i++)
          chunk(
            id: 'c$i',
            session: 's1',
            seq: i,
            startedAt: earlier,
            status: ChunkUploadStatus.values[i],
          ),
      ]);
      final ProviderContainer c = build(source);

      final List<QueuedChunk> queue = await c.read(
        uploadQueueNotifierProvider.future,
      );

      expect(
        queue.map((QueuedChunk q) => q.status).toSet(),
        ChunkUploadStatus.values.toSet(),
      );
    });
  });

  group('FR-UPL-07 — manual retry', () {
    test('retry reaches the source with the chunk id', () async {
      final _FakeQueueSource source = _FakeQueueSource(<QueuedChunk>[
        chunk(
          id: 'b',
          session: 's1',
          seq: 1,
          startedAt: earlier,
          status: ChunkUploadStatus.failed,
        ),
      ]);
      final ProviderContainer c = build(source);
      await c.read(uploadQueueNotifierProvider.future);

      await c.read(uploadQueueNotifierProvider.notifier).retry('b');

      expect(source.requeued, <String>['b']);
    });

    test('the retried chunk reappears in its original slot', () async {
      // The source re-emits with the row back in `queued`; position is
      // derived, so it lands between its neighbours again.
      final List<QueuedChunk> withFailed = <QueuedChunk>[
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
        chunk(
          id: 'b',
          session: 's1',
          seq: 1,
          startedAt: earlier,
          status: ChunkUploadStatus.failed,
        ),
        chunk(id: 'c', session: 's1', seq: 2, startedAt: earlier),
      ];
      final _FakeQueueSource source = _FakeQueueSource(withFailed);
      final ProviderContainer c = build(source);
      await c.read(uploadQueueNotifierProvider.future);

      await c.read(uploadQueueNotifierProvider.notifier).retry('b');
      source.push(<QueuedChunk>[
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
        chunk(id: 'b', session: 's1', seq: 1, startedAt: earlier),
        chunk(id: 'c', session: 's1', seq: 2, startedAt: earlier),
      ]);
      await pumpEventQueue();

      final List<QueuedChunk> queue =
          c.read(uploadQueueNotifierProvider).value!;
      expect(queue.map((QueuedChunk q) => q.chunkId), <String>['a', 'b', 'c']);
      expect(queue[1].status, ChunkUploadStatus.queued);
    });
  });

  group('manual upload mode — Ch. 5.9 §4', () {
    test('the queue model is identical; nothing here claims a chunk', () async {
      // "chunks still enter the queue in the Queued state immediately at
      // finalization - the only difference is that Chapter 5.11's dispatcher
      // does not automatically claim them". This notifier has no claim path
      // at all, in either mode, which is what makes the models identical.
      final _FakeQueueSource source = _FakeQueueSource(<QueuedChunk>[
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
      ]);
      final ProviderContainer c = build(source);

      final List<QueuedChunk> queue = await c.read(
        uploadQueueNotifierProvider.future,
      );

      expect(queue.single.status, ChunkUploadStatus.queued);
      expect(queue.single.status.isClaimable, isTrue);
      expect(
        source.claimed,
        isEmpty,
        reason: '4.1 models the queue; it never claims from it',
      );
    });
  });

  group('uploadQueueBySessionProvider — the grouped view C-11 reads', () {
    test('it groups the live queue', () async {
      final _FakeQueueSource source = _FakeQueueSource(<QueuedChunk>[
        chunk(id: 'e0', session: 's1', seq: 0, startedAt: earlier),
        chunk(id: 'e1', session: 's1', seq: 1, startedAt: earlier),
        chunk(id: 'l0', session: 's2', seq: 0, startedAt: later),
      ]);
      final ProviderContainer c = build(source);
      await c.read(uploadQueueNotifierProvider.future);

      final List<UploadQueueSession> groups = c.read(
        uploadQueueBySessionProvider,
      );

      expect(groups.map((UploadQueueSession g) => g.sessionId), <String>[
        's1',
        's2',
      ]);
    });

    test('before the first emission it is empty, not an error', () {
      // The stream has not produced anything yet. C-11 should render an empty
      // list rather than a crash or a null.
      final ProviderContainer c = build(_FakeQueueSource(<QueuedChunk>[]));

      expect(c.read(uploadQueueBySessionProvider), isEmpty);
    });
  });

  group('grouping for C-11', () {
    test('sessions come out in queue order, chunks in sequence order', () {
      final List<UploadQueueSession> groups = UploadQueueSession.group(
        <QueuedChunk>[
          chunk(id: 'e0', session: 's1', seq: 0, startedAt: earlier),
          chunk(id: 'e1', session: 's1', seq: 1, startedAt: earlier),
          chunk(id: 'l0', session: 's2', seq: 0, startedAt: later),
        ],
      );

      expect(groups.map((UploadQueueSession g) => g.sessionId), <String>[
        's1',
        's2',
      ]);
      expect(groups.first.chunks, hasLength(2));
      expect(groups.last.chunks, hasLength(1));
    });

    test('an empty queue groups to nothing', () {
      expect(UploadQueueSession.group(<QueuedChunk>[]), isEmpty);
    });

    test('it counts per status for the session header', () {
      final UploadQueueSession group = UploadQueueSession.group(<QueuedChunk>[
        chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
        chunk(
          id: 'b',
          session: 's1',
          seq: 1,
          startedAt: earlier,
          status: ChunkUploadStatus.complete,
        ),
        chunk(
          id: 'c',
          session: 's1',
          seq: 2,
          startedAt: earlier,
          status: ChunkUploadStatus.complete,
        ),
      ]).single;

      expect(group.countOf(ChunkUploadStatus.complete), 2);
      expect(group.countOf(ChunkUploadStatus.queued), 1);
      expect(group.countOf(ChunkUploadStatus.failed), 0);
    });

    test('it does not re-sort what it was given', () {
      // Re-deriving order here would be a second place for it to be wrong.
      // Given a deliberately unsorted list, grouping preserves it verbatim.
      final List<UploadQueueSession> groups = UploadQueueSession.group(
        <QueuedChunk>[
          chunk(id: 'l0', session: 's2', seq: 0, startedAt: later),
          chunk(id: 'e0', session: 's1', seq: 0, startedAt: earlier),
        ],
      );

      expect(groups.map((UploadQueueSession g) => g.sessionId), <String>[
        's2',
        's1',
      ]);
    });

    test('a session interleaved in the input becomes two groups', () {
      // Honest about the implementation: grouping is a single pass over an
      // already-ordered list, so a caller handing it interleaved rows gets
      // adjacent runs, not a merge. That is correct for the ordered input it
      // is documented to take, and this pins the behaviour rather than
      // leaving it to be discovered.
      final List<UploadQueueSession> groups = UploadQueueSession.group(
        <QueuedChunk>[
          chunk(id: 'a', session: 's1', seq: 0, startedAt: earlier),
          chunk(id: 'b', session: 's2', seq: 0, startedAt: later),
          chunk(id: 'c', session: 's1', seq: 1, startedAt: earlier),
        ],
      );

      expect(groups, hasLength(3));
    });
  });
}

/// A queue source driven by a controller, so a test can push a new state.
///
/// Single-subscription rather than broadcast, deliberately: a broadcast
/// stream drops any event added before a listener attaches, which made a
/// push land in the gap between the first emission and the generator
/// subscribing. A buffering controller keeps the ordering a real Isar watch
/// would give.
class _FakeQueueSource implements ChunkQueueSource {
  _FakeQueueSource(this._initial) {
    _controller.add(_initial);
  }

  final List<QueuedChunk> _initial;
  final StreamController<List<QueuedChunk>> _controller =
      StreamController<List<QueuedChunk>>();

  final List<String> requeued = <String>[];

  /// Never written by this mission — 4.1 models the queue, it does not claim.
  final List<String> claimed = <String>[];

  int watchCalls = 0;

  void push(List<QueuedChunk> queue) => _controller.add(queue);

  @override
  Stream<List<QueuedChunk>> watchQueue() {
    watchCalls += 1;
    return _controller.stream;
  }

  @override
  Future<List<QueuedChunk>> currentQueue() async => _initial;

  @override
  Future<void> requeue(String chunkId) async => requeued.add(chunkId);
}
