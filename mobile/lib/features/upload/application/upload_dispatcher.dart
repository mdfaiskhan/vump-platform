import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/logging/providers/logger_provider.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/upload/application/chunk_upload_pipeline.dart';
import 'package:mobile/features/upload/application/upload_queue_notifier.dart';
import 'package:mobile/features/upload/domain/entities/upload_batch_progress.dart';
import 'package:mobile/features/upload/domain/repositories/upload_service_host.dart';

/// Uploads one chunk and reports what happened, or null if none was claimable.
///
/// The dispatcher's seam onto Chapter 5.10. It is a function rather than a
/// `ChunkUploadPipeline` for a reason that is not stylistic:
/// `sessionRegistrarProvider` throws until `features/projects_tasks/` exists
/// (open item 36), so *constructing* the pipeline throws. Holding the pipeline
/// as a field would move that throw to app startup, where an unbuilt feature
/// would crash a launch. Behind a function, the seam is touched only when
/// there is actually a chunk to send.
typedef UploadOneChunk = Future<UploadOutcome?> Function();

/// Volume 5 Chapter 5.11's Background Upload dispatcher.
///
/// Chapter 5.11 §3 scopes the chapter tightly — it *"only owns keeping the OS
/// from killing the attempt outright while a connection exists"*. So this
/// class decides **when** to upload, **how many at once**, and **when the
/// foreground service runs**. It does not transfer bytes (Chapter 5.10), does
/// not schedule retries (Chapter 5.13), and does not watch connectivity
/// (Chapter 5.12).
///
/// ## The upload runs in the main isolate — ADR-042
///
/// `flutter_foreground_task` runs its `TaskHandler` in a separate isolate, and
/// the pipeline cannot go there: ADR-040 requires one `IsarChunkStore`
/// instance behind C-11, the finalizer and the pipeline, and `firebase_auth`
/// does not serve tokens to a background isolate. The Android foreground
/// service keeps the process alive, which keeps this isolate alive, which is
/// all Chapter 5.11 §3 actually asks for.
///
/// ## Concurrency is two, and two is provisional
///
/// §3 requires *"limited concurrency (a small fixed number in parallel, not
/// all at once) to avoid saturating a constrained field connection and
/// starving the Recording Pipeline (Ch.5.4) of CPU/network priority"* — and
/// names no number. Nothing in any Volume does.
///
/// Two is the smallest number that is still parallel, so it satisfies §3's
/// requirement while conceding the least to a field connection nobody has
/// measured. It is **not derived**, and it is deliberately not borrowed from
/// A-061's three: that number comes from a 600 s chunk boundary against ~12 s
/// of processing plus Chapter 5.4 §2's 5 s low-storage poll, a ratio that says
/// nothing about upload bandwidth. Amendment A-078 records it as provisional
/// and owed a pilot measurement.
///
/// ## Manual upload mode is not implemented
///
/// Chapter 5.9 §4 makes this dispatcher's behaviour conditional: on a device
/// *"configured for manual upload"* it *"does not automatically claim"* and
/// waits for a Collector action instead. Nothing in this application holds
/// that setting — there is no source for it and FR-UPL-02 has no surface yet.
/// This dispatcher therefore always claims automatically, which is Chapter 5.9
/// §4's other branch. Amendment A-080 records the reading and the gap.
class UploadDispatcher {
  /// Creates a dispatcher over the queue, the service and Chapter 5.10's seam.
  UploadDispatcher({
    required this._queue,
    required UploadServiceHost serviceHost,
    required this._uploadNext,
    required this._logger,
    int concurrency = defaultConcurrency,
  }) : _host = serviceHost,
       _concurrency = concurrency,
       assert(concurrency > 0, 'A dispatcher that runs nothing is not a bound');

  /// §3's *"small fixed number in parallel"*. Provisional — see A-078.
  static const int defaultConcurrency = 2;

  /// The notification's first line.
  ///
  /// Deliberately does not name the product: `app/config/` is granted to
  /// `core/` and `shared/` by ADR-022, not to a feature, and reaching for it
  /// here to render one string would be the wrong trade.
  static const String notificationTitle = 'Upload in progress';

  final ChunkQueueSource _queue;
  final UploadServiceHost _host;
  final UploadOneChunk _uploadNext;
  final AppLogger _logger;
  final int _concurrency;

  StreamSubscription<List<QueuedChunk>>? _subscription;
  int _inFlight = 0;
  bool _shutDown = false;

  UploadBatchProgress _batch = UploadBatchProgress.idle;
  bool _sawQueued = false;
  bool _sawUploading = false;

  // Service calls are serialised through this chain. Start, update and stop
  // are asynchronous platform calls, and two of them interleaving would let a
  // stop overtake a start and leave a service running with nothing driving it.
  Future<void> _serviceCalls = Future<void>.value();
  bool _serviceRunning = false;
  bool _serviceStartRefused = false;

  /// The aggregate currently shown on §1's notification.
  UploadBatchProgress get batch => _batch;

  /// How many uploads are running right now.
  int get inFlight => _inFlight;

  /// Subscribes to the queue and begins claiming work.
  ///
  /// Chapter 5.9 §3 makes the queue *"a live view … over
  /// `local_chunks.status`"* whose rows survive an app kill, so there is no
  /// recovery pass here and none is needed: the rows already say `queued`, and
  /// a new subscription reads them. Calling this twice is a no-op.
  void start() {
    if (_subscription != null || _shutDown) {
      return;
    }
    _subscription = _queue.watchQueue().listen(
      _onQueueChanged,
      onError: (Object error, StackTrace stackTrace) {
        // The queue is the only thing that wakes this dispatcher. If its
        // stream breaks, nothing will drive an upload again, so this must be
        // loud rather than swallowed.
        _logger.error(
          'The upload queue stream failed. No further chunks will be '
          'dispatched until the app is restarted.',
          error: error,
          stackTrace: stackTrace,
        );
        unawaited(shutDown());
      },
    );
  }

  /// Stops dispatching and takes the foreground service down with it.
  ///
  /// Chunks already in flight are left to finish — they hold claimed rows, and
  /// abandoning them here would strand those rows in `uploading` with nothing
  /// left to release them.
  Future<void> shutDown() async {
    if (_shutDown) {
      return;
    }
    _shutDown = true;
    await _subscription?.cancel();
    _subscription = null;
    _sawQueued = false;
    _sawUploading = false;
    await _syncService();
  }

  void _onQueueChanged(List<QueuedChunk> rows) {
    if (_shutDown) {
      return;
    }

    int outstanding = 0;
    bool queued = false;
    bool uploading = false;
    for (final QueuedChunk chunk in rows) {
      switch (chunk.status) {
        case ChunkUploadStatus.queued:
          queued = true;
          outstanding++;
        case ChunkUploadStatus.uploading:
          uploading = true;
          outstanding++;
        case ChunkUploadStatus.failed:
        case ChunkUploadStatus.complete:
          // Terminal. §1 lets the batch end while items sit Failed awaiting
          // manual retry, so neither counts as outstanding work.
          break;
      }
    }

    _sawQueued = queued;
    _sawUploading = uploading;
    _batch = _batch.observe(outstanding);

    _launch();
    unawaited(_syncService());
  }

  /// Fills the free concurrency slots, synchronously.
  ///
  /// This method does not await, and that is what makes it safe. Dart runs it
  /// to completion without interleaving, so `_inFlight` cannot be read by two
  /// callers between the check and the increment — the bound in §3 holds by
  /// construction rather than by a lock.
  ///
  /// It may launch a runner that finds nothing: the snapshot it acts on can be
  /// a moment behind the rows. That costs one `claimNext` returning null, and
  /// is cheaper than trying to reconcile a stale count — `claimNext` is
  /// atomic, so a wasted call cannot claim a chunk twice.
  void _launch() {
    if (_shutDown || !_sawQueued) {
      return;
    }
    while (_inFlight < _concurrency) {
      _inFlight++;
      unawaited(_runOne());
    }
  }

  Future<void> _runOne() async {
    UploadOutcome? outcome;
    Object? failure;
    StackTrace? trace;

    try {
      outcome = await _uploadNext();
    } on Object catch (error, stackTrace) {
      failure = error;
      trace = stackTrace;
    }

    _inFlight--;

    if (failure != null) {
      // `ChunkUploadPipeline` documents that it never throws for a failure of
      // the upload itself — every such path ends in a status write and an
      // `UploadOutcome`. So a throw here is the wiring being wrong, not a
      // chunk being unluckily. Today the usual cause is
      // `sessionRegistrarProvider`, which throws because
      // `features/projects_tasks/` is unbuilt (open item 36).
      //
      // Retrying that in a loop would spin forever against a condition no
      // amount of retrying changes, so the dispatcher stops.
      _logger.error(
        "The upload dispatcher stopped: Chapter 5.10's pipeline could not "
        'run. This is a wiring fault rather than an upload failure, and '
        'retrying it would not change the outcome.',
        error: failure,
        stackTrace: trace,
      );
      await shutDown();
      return;
    }

    if (outcome == null) {
      // Nothing was claimable. Deliberately does not re-launch: the snapshot
      // that said there was work is stale, and only a new emission is honest
      // evidence that there is more. Re-launching on null is an unbounded
      // spin against an empty queue.
      _sawQueued = false;
      await _syncService();
      return;
    }

    _report(outcome);

    // A finished run wrote a status, so an emission is coming — but it may
    // already have been delivered while `_inFlight` was still counted, in
    // which case `_launch` declined and nothing else would wake this slot.
    // Filling it here closes that window; `_launch` is bounded, so the extra
    // call cannot exceed §3's concurrency.
    _launch();
    await _syncService();
  }

  /// Chapter 2.9 §2's *"never fail silently"*, at the dispatcher's level.
  void _report(UploadOutcome outcome) {
    if (outcome.isComplete) {
      _logger.info('Chunk ${outcome.chunkId} uploaded.');
      return;
    }
    if (outcome.isCancelled) {
      _logger.info('Chunk ${outcome.chunkId} was released back to the queue.');
      return;
    }
    _logger.warning(
      'Chunk ${outcome.chunkId} failed to upload '
      '(${outcome.cause?.name}): ${outcome.detail}',
    );
  }

  /// Brings the foreground service into line with §1's two conditions.
  ///
  /// Chained rather than called directly so that a start and a stop raised by
  /// two nearby events cannot overlap on the platform channel.
  Future<void> _syncService() {
    // Two different conditions, deliberately.
    //
    // STARTING is §1's literal trigger — "the moment any chunk enters
    // Uploading". That means a row observed in `uploading`, not a runner that
    // has been launched and may yet claim nothing. Starting on a launch would
    // put a notification on screen for the length of one `claimNext` every
    // time the queue was already empty, or every time the pipeline could not
    // be constructed at all — which is exactly today (open item 36), and
    // exactly the flicker §1 exists to prevent.
    //
    // KEEPING it alive is wider: a runner still in flight holds a claimed row
    // even in the window before the queue re-emits, and stopping the service
    // under it would hand the OS permission to kill the transfer.
    final bool live = !_shutDown && (_sawUploading || _inFlight > 0);
    final bool startable = !_shutDown && _sawUploading;
    final UploadBatchProgress batch = _batch;
    _serviceCalls = _serviceCalls.then(
      (_) => _applyService(live: live, startable: startable, batch: batch),
    );
    return _serviceCalls;
  }

  Future<void> _applyService({
    required bool live,
    required bool startable,
    required UploadBatchProgress batch,
  }) async {
    try {
      if (!live) {
        if (_serviceRunning) {
          await _host.stop();
        }
        _serviceRunning = false;
        // A refusal is reconsidered once the queue drains, so a Collector who
        // grants notification permission later gets a notification on the next
        // batch rather than never again.
        _serviceStartRefused = false;
        return;
      }

      if (_serviceRunning) {
        await _host.update(
          title: notificationTitle,
          text: batch.notificationText,
        );
        return;
      }

      if (_serviceStartRefused || !startable) {
        return;
      }

      _serviceRunning = await _host.start(
        title: notificationTitle,
        text: batch.notificationText,
      );
      if (!_serviceRunning) {
        // Uploading continues. §1's notification is how the work stays
        // visible (Ch. 2.9 §2 principle 3), and losing visibility is not a
        // reason to stop transferring chunks the Collector already recorded.
        // Not retried within this batch: each attempt can raise a permission
        // prompt, and prompting per chunk would be worse than no notification.
        _serviceStartRefused = true;
        _logger.warning(
          'The upload service could not be started, so background upload '
          'progress will not be shown. Uploading continues.',
        );
      }
    } on Object catch (error, stackTrace) {
      _logger.error(
        'The upload service could not be updated.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// The Android foreground service, overridden at the composition root.
///
/// Unimplemented rather than defaulted, for the reason every other port in
/// this project follows: a default would have to name a concrete class living
/// in `data/`, which `application/` may not import (ADR-022 §5.3).
final Provider<UploadServiceHost> uploadServiceHostProvider =
    Provider<UploadServiceHost>(
      (Ref ref) => throw UnimplementedError(
        'uploadServiceHostProvider must be overridden with an '
        'UploadServiceHost. features/upload/data/ provides '
        'ForegroundUploadServiceHost, which implements it. See ADR-042.',
      ),
    );

/// Chapter 5.11's dispatcher, wired to the queue and the service.
///
/// `chunkUploadPipelineProvider` is read lazily inside the callback rather
/// than watched here. Watching it would construct the pipeline when this
/// provider is first read, and constructing it throws while
/// `sessionRegistrarProvider` has no implementation — turning an unbuilt
/// feature into a startup crash. See [UploadOneChunk].
final Provider<UploadDispatcher> uploadDispatcherProvider =
    Provider<UploadDispatcher>(
      (Ref ref) => UploadDispatcher(
        queue: ref.watch(chunkQueueSourceProvider),
        serviceHost: ref.watch(uploadServiceHostProvider),
        logger: ref.watch(loggerProvider),
        uploadNext: () => ref.read(chunkUploadPipelineProvider).uploadNext(),
      ),
    );
