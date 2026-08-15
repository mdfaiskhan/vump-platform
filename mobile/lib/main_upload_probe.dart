import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/upload/application/chunk_upload_pipeline.dart';
import 'package:mobile/features/upload/application/upload_dispatcher.dart';
import 'package:mobile/features/upload/data/foreground_upload_service_host.dart';

/// Mission 4.3's on-device probe for Volume 5 Chapter 5.11 §1 and §3.
///
/// Run with:
/// ```shell
/// flutter run --target=lib/main_upload_probe.dart
/// ```
///
/// ## What this proves, and what it deliberately cannot
///
/// Chapter 5.11 §3 scopes the chapter to *"keeping the OS from killing the
/// attempt outright while a connection exists"*. This target exercises exactly
/// that, with the **real** [UploadDispatcher], the **real**
/// [ForegroundUploadServiceHost] and the **real** `UploadBatchProgress`:
///
/// - the foreground service starts when a chunk enters `uploading`
/// - one persistent notification for the whole batch, not one per chunk
/// - the aggregate text advances — "Uploading 2 of 5 chunks."
/// - at most [UploadDispatcher.defaultConcurrency] transfers at once
/// - the service stops and the notification clears when the queue drains
/// - all of it survives the app being backgrounded
///
/// **It proves nothing about S3.** No byte leaves the device. The queue and
/// the transfer are stubbed here, because the real pipeline cannot run at all:
/// `sessionRegistrarProvider` throws until `features/projects_tasks/` exists
/// (open item 36), and A-068's Guard 1 refuses every chunk a real device has
/// ever recorded (open item 37). A probe that pretended otherwise would be
/// the "checked in parts" failure open item 32 records, in a new costume.
///
/// End-to-end upload against a server belongs to Mission 4.7, which installs
/// `integration_test` and Chapter 9.7 §1's mock server (open items 20, 40).
///
/// ## It cannot become a release build
///
/// Volume 11's M12 gate makes a fake wired into a release build a defect in
/// its own right. The stubs below are reachable only from this file's `main`,
/// so the shipped entrypoint tree-shakes them away — and [main] refuses to run
/// in release mode regardless, so the rule is enforced rather than trusted.
void main() {
  if (kReleaseMode) {
    throw StateError(
      'main_upload_probe.dart is a debug-only device probe and binds stubs in '
      'place of the upload queue and the transfer. Volume 11 M12 forbids '
      'shipping it. Build lib/main.dart instead.',
    );
  }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _ProbeApp()));
}

/// How long one stubbed chunk pretends to transfer.
///
/// Long enough for a person to read the notification, switch apps, and come
/// back — which is the actual test.
const Duration _chunkDuration = Duration(seconds: 6);

class _ProbeApp extends StatelessWidget {
  const _ProbeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ch. 5.11 probe',
      theme: ThemeData(useMaterial3: true),
      home: const _ProbeScreen(),
    );
  }
}

class _ProbeScreen extends StatefulWidget {
  const _ProbeScreen();

  @override
  State<_ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<_ProbeScreen> {
  final _ProbeQueue _queue = _ProbeQueue();
  late final UploadDispatcher _dispatcher;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _dispatcher = UploadDispatcher(
      queue: _queue,
      // The real one. This is the whole point of the probe.
      serviceHost: ForegroundUploadServiceHost(),
      uploadNext: _queue.uploadNext,
      logger: AppLogger(environment: AppConfig.environment),
    )..start();

    _refresh = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    unawaited(_dispatcher.shutDown());
    _queue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<QueuedChunk> rows = _queue.rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Chapter 5.11 probe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Batch: ${_dispatcher.batch.notificationText}\n'
              'In flight: ${_dispatcher.inFlight} '
              '(bound ${UploadDispatcher.defaultConcurrency})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: () => _queue.seed(5),
                  child: const Text('Queue 5 chunks'),
                ),
                OutlinedButton(
                  onPressed: () => _queue.seed(2),
                  child: const Text('Add 2 mid-batch'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Background the app while this runs. The notification must stay, '
              'keep counting, and disappear only when the batch drains.',
            ),
            const Divider(height: 32),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (BuildContext context, int index) {
                  final QueuedChunk chunk = rows[index];
                  return ListTile(
                    dense: true,
                    title: Text(chunk.chunkId),
                    trailing: Text(chunk.status.wireName),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An in-memory stand-in for the Isar-backed queue, and for Chapter 5.10.
///
/// It mirrors the two properties the dispatcher actually depends on: a claim
/// is atomic, and every status write re-emits the whole ordered queue. Nothing
/// else about Isar matters here.
class _ProbeQueue implements ChunkQueueSource {
  final List<QueuedChunk> _rows = <QueuedChunk>[];
  final StreamController<List<QueuedChunk>> _controller =
      StreamController<List<QueuedChunk>>.broadcast();

  int _nextId = 0;

  List<QueuedChunk> get rows => List<QueuedChunk>.unmodifiable(_rows);

  void seed(int count) {
    final DateTime now = DateTime.now();
    for (int i = 0; i < count; i++) {
      _rows.add(
        QueuedChunk(
          chunkId: 'probe-${_nextId++}',
          sessionId: 'probe-session',
          sequenceIndex: _rows.length,
          sessionStartedAt: now,
          status: ChunkUploadStatus.queued,
          fileSizeBytes: 610 * 1024 * 1024,
        ),
      );
    }
    _emit();
  }

  /// Stands in for `ChunkUploadPipeline.uploadNext`.
  ///
  /// Claims atomically, holds the chunk in `uploading` for [_chunkDuration],
  /// then completes it — the same three status writes the real pipeline makes,
  /// with the network removed.
  Future<UploadOutcome?> uploadNext() async {
    final int index = _rows.indexWhere(
      (QueuedChunk c) => c.status == ChunkUploadStatus.queued,
    );
    if (index < 0) {
      return null;
    }

    final QueuedChunk claimed = _rows[index];
    _replace(index, ChunkUploadStatus.uploading);
    _emit();

    await Future<void>.delayed(_chunkDuration);

    final int settled = _rows.indexWhere(
      (QueuedChunk c) => c.chunkId == claimed.chunkId,
    );
    if (settled >= 0) {
      _replace(settled, ChunkUploadStatus.complete);
      _emit();
    }
    return UploadOutcome.complete(chunkId: claimed.chunkId);
  }

  void _replace(int index, ChunkUploadStatus status) {
    final QueuedChunk current = _rows[index];
    _rows[index] = QueuedChunk(
      chunkId: current.chunkId,
      sessionId: current.sessionId,
      sequenceIndex: current.sequenceIndex,
      sessionStartedAt: current.sessionStartedAt,
      status: status,
      fileSizeBytes: current.fileSizeBytes,
    );
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(rows);
    }
  }

  void dispose() => unawaited(_controller.close());

  @override
  Stream<List<QueuedChunk>> watchQueue() async* {
    yield rows;
    yield* _controller.stream;
  }

  @override
  Future<List<QueuedChunk>> currentQueue() async => rows;

  @override
  Future<void> requeue(String chunkId) async {
    final int index = _rows.indexWhere((QueuedChunk c) => c.chunkId == chunkId);
    if (index >= 0 && _rows[index].status == ChunkUploadStatus.failed) {
      _replace(index, ChunkUploadStatus.queued);
      _emit();
    }
  }
}
