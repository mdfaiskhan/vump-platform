import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/connectivity/connectivity_status.dart';
import 'package:mobile/core/connectivity/interfaces/connectivity_source.dart';
import 'package:mobile/core/connectivity/providers/connectivity_ports.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/logging/providers/logger_provider.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/providers/queue_ports.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/core/time/interfaces/clock.dart';
import 'package:mobile/core/time/providers/clock_provider.dart';
import 'package:mobile/core/upload/interfaces/chunk_upload_source.dart';
import 'package:mobile/core/upload/providers/upload_ports.dart';
import 'package:mobile/features/upload/application/chunk_upload_pipeline.dart';
import 'package:mobile/features/upload/application/upload_dispatcher_status_notifier.dart';
import 'package:mobile/features/upload/application/upload_progress_notifier.dart';
import 'package:mobile/features/upload/domain/entities/retry_schedule.dart';
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
    required this._source,
    this.onHalted,
    required this._connectivity,
    required this._clock,
    RetrySchedule? schedule,
    int concurrency = defaultConcurrency,
  }) : _host = serviceHost,
       _schedule = schedule ?? RetrySchedule(),
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

  /// Called when the dispatcher stops on a **fault**, so something can tell
  /// the Collector uploads are not running.
  ///
  /// Deliberately not called by [shutDown], which is also how the app tears
  /// down normally — a banner on every dispose would be noise, and worse, it
  /// would teach the Collector to ignore it. Only the two unrecoverable paths
  /// report: a pipeline that cannot be constructed, and a broken queue stream.
  ///
  /// Open item 60: before this existed the dispatcher stopped silently and a
  /// real chunk showed an amber "Queued" pill indefinitely.
  final void Function()? onHalted;

  final ChunkQueueSource _queue;
  final ChunkUploadSource _source;
  final ConnectivitySource _connectivity;
  final Clock _clock;
  final RetrySchedule _schedule;
  final UploadServiceHost _host;
  final UploadOneChunk _uploadNext;
  final AppLogger _logger;
  final int _concurrency;

  StreamSubscription<List<QueuedChunk>>? _subscription;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  ScheduledDelay? _wake;
  DateTime? _wakeAt;
  int _inFlight = 0;
  bool _shutDown = false;

  /// Whether ADR-052's startup reconciliation has finished.
  ///
  /// [_launch] holds off while this is false. The ordering is load-bearing:
  /// reconciliation reads one snapshot of the queue, and a chunk this process
  /// claimed before that read would appear in it as `uploading` and be
  /// requeued underneath a transfer that is genuinely running — the double
  /// upload `claimNext` calls unrecoverable.
  bool _reconciled = false;

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

  /// Subscribes to the queue, reconciles stranded rows, then claims work.
  ///
  /// Chapter 5.9 §3 makes the queue *"a live view … over
  /// `local_chunks.status`"* whose rows survive an app kill, and this method
  /// used to conclude there was *"no recovery pass here and none is needed"*.
  /// **ADR-052 corrects that.** The rows survive; a row reading `uploading`
  /// after a process death is still not resumable, because `claimNext` selects
  /// only `queued` and everything that could move it died with its pipeline.
  ///
  /// So [_reconcileStranded] runs here and [_launch] waits for it. Calling
  /// this twice is a no-op.
  void start() {
    if (_subscription != null || _shutDown) {
      return;
    }

    // ADR-052. Started before the subscription so its snapshot cannot contain
    // a row this process itself claimed; `_launch` waits on it regardless.
    unawaited(_reconcileStranded());
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
        if (!_shutDown) {
          onHalted?.call();
        }
        unawaited(shutDown());
      },
    );

    // Chapter 5.12 §2: the dispatcher "listens to" ConnectivityService rather
    // than polling it. The stream emits its current status immediately, so a
    // dispatcher started while already online is not waiting for a transition
    // that may never arrive.
    _connectivitySubscription = _connectivity.watch().listen(
      _onConnectivityChanged,
      onError: (Object error, StackTrace stackTrace) {
        // Losing the signal degrades rather than breaks: chunks still upload
        // when claimed, and Chapter 5.13's backoff still fires on its own
        // timer. What is lost is §4's immediate resume, so NFR-AVL-02 is no
        // longer guaranteed — which is worth a line in the log rather than
        // silence.
        _logger.error(
          'The connectivity signal failed. Uploads will still retry on '
          "Chapter 5.13's backoff, but will not resume immediately when the "
          'network returns.',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// Chapter 5.12 §4's reconnection behaviour.
  ///
  /// *"Signal: ConnectivityService fires an online transition the moment the
  /// OS reports connectivity restored. Action: the Background Upload
  /// dispatcher immediately claims the front of the queue — no polling delay,
  /// no Collector action required."*
  ///
  /// Clearing the backoff deadlines is what makes "immediately" true. A batch
  /// that lost connectivity together is sitting on Chapter 5.13 §2 delays of
  /// up to 160 seconds, and honouring those would put the resume outside
  /// NFR-AVL-02's 30-second target for no benefit — the delays exist to space
  /// out retries against a backend, and the reason they were set has just
  /// stopped applying.
  ///
  /// Going offline is deliberately not acted on. There is nothing to do: an
  /// in-flight transfer fails on its own and becomes a transient failure,
  /// which §1 already routes into the backoff. Cancelling it here would be
  /// this chapter taking a decision Chapter 5.13 owns.
  void _onConnectivityChanged(ConnectivityStatus status) {
    if (_shutDown || !status.isOnline) {
      return;
    }
    unawaited(_resumeAfterReconnect());
  }

  Future<void> _resumeAfterReconnect() async {
    try {
      await _source.clearBackoff();
    } on Object catch (error, stackTrace) {
      _logger.error(
        'Backoff deadlines could not be cleared on reconnection. Chunks will '
        'resume on their own schedule instead.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    _logger.info('Network restored — claiming the queue.');
    // The clear is a write, so the queue re-emits and `_onQueueChanged` will
    // launch. Launching here as well closes the case where nothing was
    // deferred and therefore nothing was written.
    _sawQueued = true;
    _launch();
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
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _wake?.cancel();
    _wake = null;
    _wakeAt = null;
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

  /// ADR-052's startup reconciliation — returns stranded rows to the queue.
  ///
  /// A row still reading `uploading` when this process starts was claimed by a
  /// process that is gone. That inference is sound here and nowhere else: the
  /// Android foreground service declares no `android:process` and runs in the
  /// main process, and Android does not run two instances of one app process,
  /// so a freshly launched process cannot hold a transfer.
  ///
  /// **A death spends an attempt.** Chapter 5.13 §2's budget is applied here
  /// rather than left to [_settleTransient], which never sees this case — it
  /// needs an `UploadOutcome`, and a killed process produces none. Without the
  /// check the counter would climb past six forever, because `claimNext`
  /// filters on status and the deadline and never reads it.
  ///
  /// A failure is logged and swallowed. Reconciliation that could not run must
  /// not stop everything else from uploading, and the rows it did not reach
  /// are no worse off than before — they are retried on the next launch.
  Future<void> _reconcileStranded() async {
    try {
      final List<QueuedChunk> rows = await _queue.currentQueue();
      for (final QueuedChunk row in rows) {
        if (row.status != ChunkUploadStatus.uploading) {
          continue;
        }
        final int attempts = row.attemptCount + 1;
        if (_schedule.hasAttemptsLeft(attempts)) {
          await _source.releaseStranded(
            chunkId: row.chunkId,
            attemptCount: attempts,
          );
          _logger.warning(
            'Chunk ${row.chunkId} was left uploading by a process that did '
            'not finish. Returned to the queue as attempt $attempts of '
            '${RetrySchedule.maxAttempts}.',
          );
        } else {
          await _source.markFailed(row.chunkId);
          _logger.warning(
            'Chunk ${row.chunkId} was left uploading and has spent all '
            '${RetrySchedule.maxAttempts} attempts. It now waits for a '
            'manual retry.',
          );
        }
      }
    } on Object catch (error, stackTrace) {
      _logger.error(
        'Stranded chunks could not be reconciled. Uploads continue, and any '
        'row still left at uploading is reconciled on the next launch.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Set even on failure: leaving it false would block every upload for the
    // life of the process, which is a far worse outcome than a chunk staying
    // stranded one launch longer. Deliberately not in a `finally`, so a throw
    // from the wake below cannot mask the reconciliation error above it.
    _reconciled = true;

    // Not via the subscription: reconciliation's own write can land before
    // watchQueue()'s generator attaches its watchLazy listener, and no
    // emission is ever produced for it. Verified on a CPH2707, 2026-08-23.
    await _wakeFromQueue();
  }

  /// Brings this dispatcher's own view up to date from a fresh read.
  ///
  /// `watchQueue()` yields its first snapshot and only then subscribes to
  /// `watchLazy()`, which reports writes made *after* it attaches. A write
  /// landing in that gap produces no emission at all — so a dispatcher that
  /// waited for one would hold whatever state its first read gave it, forever.
  /// Only `_onQueueChanged` and a connectivity change ever call [_launch],
  /// and neither would fire again.
  ///
  /// **That is not hypothetical.** Mission 8.2 reproduced it on a CPH2707:
  /// reconciliation moved a 369 MB chunk from `uploading` to `queued`, the UI
  /// read the row correctly through its own separate subscription, and this
  /// dispatcher sat idle for eight minutes believing a transfer was still
  /// running. The chunk uploaded the moment an unrelated write finally
  /// produced an emission.
  ///
  /// So the reconciliation wakes the dispatcher itself. [_onQueueChanged] is
  /// reused rather than reimplemented: it recomputes both flags from a whole
  /// snapshot and folds the batch, and a second copy of that would be a second
  /// place for the rule to drift.
  ///
  /// **Safe against the subscription also delivering an event.** [_launch] is
  /// bounded by `_inFlight < _concurrency` and runs without an await, so extra
  /// calls cannot exceed Chapter 5.11 §3's limit; `claimNext` is atomic, so a
  /// duplicate runner cannot claim a row twice; `UploadBatchProgress.observe`
  /// is idempotent for a repeated count; and `_syncService` is serialised.
  /// `_runOne` already calls [_launch] directly for the same reason.
  ///
  /// A read that fails falls back to a bare [_launch], which leaves the
  /// dispatcher exactly where it stood before rather than worse.
  Future<void> _wakeFromQueue() async {
    try {
      _onQueueChanged(await _queue.currentQueue());
    } on Object catch (error, stackTrace) {
      _logger.error(
        'The queue could not be read after reconciliation. Any chunk it '
        'returned to the queue waits for the next queue event or the next '
        'launch.',
        error: error,
        stackTrace: stackTrace,
      );
      _launch();
    }
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
    if (_shutDown || !_reconciled || !_sawQueued) {
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
      // Guarded on `_shutDown` so a fault that both in-flight runners hit
      // reports once rather than once each. The notifier behind this is
      // idempotent, but a system-level signal firing per runner is a shape
      // that misleads whoever reads it next.
      if (!_shutDown) {
        onHalted?.call();
      }
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

    // Chapter 5.13 §1's transient row. The pipeline left the chunk
    // `uploading` rather than `failed`, because whether the budget is spent is
    // this class's question, not its own.
    if (outcome.isRetryable && outcome.chunkId != null) {
      await _settleTransient(outcome);
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

  /// Applies Chapter 5.13 §2's budget and backoff to a transient failure.
  ///
  /// Either the chunk goes back to `queued` behind a deadline, or — on the
  /// sixth attempt — it becomes `failed` and waits for connectivity to change
  /// (Chapter 5.12) or for FR-UPL-07's manual retry.
  ///
  /// §1 is what forbids the shortcut of marking it `failed` on the first
  /// transient failure: it is *"never surfaced to the Collector as Failed
  /// until attempts are exhausted"*.
  Future<void> _settleTransient(UploadOutcome outcome) async {
    final String chunkId = outcome.chunkId!;
    try {
      if (!_schedule.hasAttemptsLeft(outcome.attemptCount)) {
        await _source.markFailed(chunkId);
        _logger.warning(
          'Chunk $chunkId failed after ${outcome.attemptCount} attempts '
          '(${outcome.cause?.name}). It now waits for a manual retry or for '
          'the network to change.',
        );
        return;
      }

      final Duration delay = _schedule.delayFor(outcome.attemptCount);
      await _source.deferAttempt(
        chunkId: chunkId,
        attemptCount: outcome.attemptCount,
        nextAttemptAt: _clock.now().add(delay),
      );
      _logger.info(
        'Chunk $chunkId will retry in ${delay.inSeconds}s (attempt '
        '${outcome.attemptCount + 1} of ${RetrySchedule.maxAttempts}).',
      );
      _scheduleWake(delay);
    } on Object catch (error, stackTrace) {
      // The row is still `uploading` and nothing else will move it. Loud,
      // because this is the one path that can strand a chunk.
      _logger.error(
        'Chunk $chunkId could not be rescheduled after a transient failure.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Wakes the dispatcher when the earliest pending backoff deadline arrives.
  ///
  /// One timer, not one per chunk. Chapter 5.13 §2's jitter means a batch's
  /// deadlines are spread, and the earliest one is the only one that matters:
  /// when it fires, `claimNext` re-evaluates every row against the clock and
  /// takes whichever are eligible. A timer per chunk would be the same
  /// information held N times.
  ///
  /// An existing earlier wake is left alone rather than replaced, so a long
  /// delay scheduled second cannot postpone a short one scheduled first.
  void _scheduleWake(Duration delay) {
    final DateTime at = _clock.now().add(delay);
    if (_wake != null && _wakeAt != null && !_wakeAt!.isAfter(at)) {
      return;
    }
    _wake?.cancel();
    _wakeAt = at;
    _wake = _clock.delay(delay, () {
      _wake = null;
      _wakeAt = null;
      if (_shutDown) {
        return;
      }
      // The deadline passing is itself the evidence that a queued chunk became
      // eligible; the queue emits nothing when a clock advances.
      _sawQueued = true;
      _launch();
    });
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
        source: ref.watch(chunkUploadSourceProvider),
        // Bridges the dispatcher's own knowledge to something C-11 can watch.
        // The class stays framework-free; this closure owns the seam, exactly
        // as it does for progress reporting below.
        onHalted: () =>
            ref.read(uploadDispatcherStatusProvider.notifier).markHalted(),
        connectivity: ref.watch(connectivitySourceProvider),
        clock: ref.watch(clockProvider),
        serviceHost: ref.watch(uploadServiceHostProvider),
        logger: ref.watch(loggerProvider),
        // C-11's live percentage is bound here rather than inside the
        // dispatcher, which has no business knowing a UI exists: the closure
        // already owns the seam onto Chapter 5.10, so it owns reporting too.
        // Progress is cleared when the chunk stops uploading, so a completed
        // or failed row never leaves a stale percentage for the next attempt.
        uploadNext: () async {
          final UploadProgressNotifier progress = ref.read(
            uploadProgressNotifierProvider.notifier,
          );
          final UploadOutcome? outcome = await ref
              .read(chunkUploadPipelineProvider)
              .uploadNext(
                onChunkProgress:
                    (String chunkId, int sentBytes, int totalBytes) =>
                        progress.report(
                          chunkId: chunkId,
                          sentBytes: sentBytes,
                          totalBytes: totalBytes,
                        ),
              );
          final String? finished = outcome?.chunkId;
          if (finished != null) {
            progress.clear(finished);
          }
          return outcome;
        },
      ),
    );
