import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/connectivity/connectivity_status.dart';
import 'package:mobile/core/connectivity/interfaces/connectivity_source.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/core/time/system_clock.dart';
import 'package:mobile/core/upload/interfaces/chunk_upload_source.dart';
import 'package:mobile/core/upload/uploadable_chunk.dart';
import 'package:mobile/features/recording/data/connectivity_plus_connectivity_source.dart';
import 'package:mobile/features/upload/application/chunk_upload_pipeline.dart';
import 'package:mobile/features/upload/application/upload_dispatcher.dart';
import 'package:mobile/features/upload/data/foreground_upload_service_host.dart';
import 'package:mobile/features/upload/domain/entities/upload_failure_cause.dart';

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
  /// The **real** connectivity source, so airplane mode drives Chapter 5.12
  /// §4 rather than a fake standing in for it. This is the whole point of the
  /// Mission 4.4 device pass.
  final ConnectivitySource _connectivity = ConnectivityPlusConnectivitySource();
  late final _ProbeQueue _queue;
  late final UploadDispatcher _dispatcher;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _queue = _ProbeQueue(connectivity: _connectivity);
    _dispatcher = UploadDispatcher(
      queue: _queue,
      source: _queue,
      // Both real. Airplane mode reaches the dispatcher through the first,
      // and Chapter 5.13's backoff runs on real wall-clock time through the
      // second — a faked clock here would prove nothing about the device.
      connectivity: _connectivity,
      clock: const SystemClock(),
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

/// An in-memory stand-in for the Isar-backed queue and for Chapter 5.10.
///
/// It mirrors the properties the dispatcher actually depends on: a claim is
/// atomic, every status write re-emits the whole ordered queue, and a chunk
/// inside Chapter 5.13 §2's backoff window is not claimable.
///
/// ## The transfer fails while the device is offline, on purpose
///
/// That is what makes the Mission 4.4 device pass real. Airplane mode does not
/// merely pause a stub — it makes [uploadNext] report a transient failure, so
/// the chunk consumes an attempt, gets a Chapter 5.13 §2 delay, and sits.
/// Turning airplane mode off fires the real `ConnectivitySource`, which clears
/// the deadlines and resumes. NFR-AVL-02's 30-second target is then a
/// wall-clock measurement rather than an assertion.
class _ProbeQueue implements ChunkQueueSource, ChunkUploadSource {
  _ProbeQueue({required this._connectivity});

  final ConnectivitySource _connectivity;
  final List<_ProbeRow> _rows = <_ProbeRow>[];
  final StreamController<List<QueuedChunk>> _controller =
      StreamController<List<QueuedChunk>>.broadcast();

  int _nextId = 0;

  List<QueuedChunk> get rows => <QueuedChunk>[
    for (final _ProbeRow r in _rows) r.toQueued(),
  ];

  /// Attempts consumed, shown on screen so the six-attempt budget is visible.
  Map<String, int> get attempts => <String, int>{
    for (final _ProbeRow r in _rows)
      if (r.attemptCount > 0) r.chunkId: r.attemptCount,
  };

  void seed(int count) {
    final DateTime now = DateTime.now();
    for (int i = 0; i < count; i++) {
      _rows.add(
        _ProbeRow(
          chunkId: 'probe-${_nextId++}',
          sequenceIndex: _rows.length,
          startedAt: now,
        ),
      );
    }
    _emit();
  }

  /// Stands in for `ChunkUploadPipeline.uploadNext`.
  ///
  /// Claims, then either transfers for [_chunkDuration] or fails transiently
  /// because the device is offline. The failure is left `uploading` exactly as
  /// the real pipeline leaves a transient one, so `UploadDispatcher` is the
  /// thing that decides to defer or fail.
  Future<UploadOutcome?> uploadNext() async {
    final UploadableChunk? claimed = await claimNext(now: DateTime.now());
    if (claimed == null) {
      return null;
    }

    final ConnectivityStatus status = await _connectivity.current();
    if (!status.isOnline) {
      return UploadOutcome.failed(
        chunkId: claimed.chunkId,
        cause: UploadFailureCause.transportFailure,
        detail: 'The device is offline.',
        attemptCount: claimed.attemptCount + 1,
      );
    }

    await Future<void>.delayed(_chunkDuration);
    await markComplete(claimed.chunkId);
    return UploadOutcome.complete(chunkId: claimed.chunkId);
  }

  @override
  Future<UploadableChunk?> claimNext({required DateTime now}) async {
    final int index = _rows.indexWhere(
      (_ProbeRow r) =>
          r.status == ChunkUploadStatus.queued &&
          (r.nextAttemptAt == null || !r.nextAttemptAt!.isAfter(now)),
    );
    if (index < 0) {
      return null;
    }
    final _ProbeRow row = _rows[index]..status = ChunkUploadStatus.uploading;
    _emit();
    return UploadableChunk(
      chunkId: row.chunkId,
      sessionId: 'probe-session',
      sequenceIndex: row.sequenceIndex,
      sessionStartedAt: row.startedAt,
      localFilePath: '/dev/null',
      fileSizeBytes: 610 * 1024 * 1024,
      checksumSha256: 'probe',
      attemptCount: row.attemptCount,
    );
  }

  @override
  Future<void> deferAttempt({
    required String chunkId,
    required int attemptCount,
    required DateTime nextAttemptAt,
  }) async {
    final _ProbeRow? row = _find(chunkId);
    if (row == null || row.status != ChunkUploadStatus.uploading) {
      return;
    }
    row
      ..status = ChunkUploadStatus.queued
      ..attemptCount = attemptCount
      ..nextAttemptAt = nextAttemptAt;
    _emit();
  }

  @override
  Future<void> clearBackoff() async {
    final Iterable<_ProbeRow> pending = _rows.where(
      (_ProbeRow r) =>
          r.status == ChunkUploadStatus.queued && r.nextAttemptAt != null,
    );
    if (pending.isEmpty) {
      return;
    }
    for (final _ProbeRow row in pending) {
      row.nextAttemptAt = null;
    }
    _emit();
  }

  @override
  Future<void> markFailed(String chunkId) =>
      _settle(chunkId, ChunkUploadStatus.failed);

  @override
  Future<void> markComplete(String chunkId) =>
      _settle(chunkId, ChunkUploadStatus.complete);

  @override
  Future<void> release(String chunkId) =>
      _settle(chunkId, ChunkUploadStatus.queued);

  @override
  Future<void> recordObjectKey({
    required String chunkId,
    required String s3ObjectKey,
  }) async {}

  @override
  Future<void> requeue(String chunkId) async {
    final _ProbeRow? row = _find(chunkId);
    if (row == null || row.status != ChunkUploadStatus.failed) {
      return;
    }
    // Chapter 5.13 §3's manual override: counter reset, deadline cleared.
    row
      ..status = ChunkUploadStatus.queued
      ..attemptCount = 0
      ..nextAttemptAt = null;
    _emit();
  }

  @override
  Stream<List<QueuedChunk>> watchQueue() async* {
    yield rows;
    yield* _controller.stream;
  }

  @override
  Future<List<QueuedChunk>> currentQueue() async => rows;

  Future<void> _settle(String chunkId, ChunkUploadStatus to) async {
    final _ProbeRow? row = _find(chunkId);
    if (row == null || row.status != ChunkUploadStatus.uploading) {
      return;
    }
    row.status = to;
    _emit();
  }

  _ProbeRow? _find(String chunkId) {
    for (final _ProbeRow row in _rows) {
      if (row.chunkId == chunkId) {
        return row;
      }
    }
    return null;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(rows);
    }
  }

  void dispose() => unawaited(_controller.close());
}

/// One mutable probe row.
class _ProbeRow {
  _ProbeRow({
    required this.chunkId,
    required this.sequenceIndex,
    required this.startedAt,
  });

  final String chunkId;
  final int sequenceIndex;
  final DateTime startedAt;

  ChunkUploadStatus status = ChunkUploadStatus.queued;
  int attemptCount = 0;
  DateTime? nextAttemptAt;

  QueuedChunk toQueued() => QueuedChunk(
    chunkId: chunkId,
    sessionId: 'probe-session',
    sequenceIndex: sequenceIndex,
    sessionStartedAt: startedAt,
    status: status,
    fileSizeBytes: 610 * 1024 * 1024,
  );
}
