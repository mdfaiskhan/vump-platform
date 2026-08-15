import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/logging/providers/logger_provider.dart';
import 'package:mobile/core/time/interfaces/clock.dart';
import 'package:mobile/core/time/providers/clock_provider.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/cleanable_chunk.dart';
import 'package:mobile/features/recording/domain/entities/storage_sweep_result.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_store.dart';

/// Volume 5 Chapter 5.15's cleanup sweep.
///
/// §1 states the rule everything else follows: *"BR-08: a chunk shall not be
/// deleted from local storage until its upload to S3 is confirmed. Every
/// mechanism in this chapter exists only to decide when that condition is
/// safely true — never to work around it."*
///
/// This class decides **when** to look. It does not decide **whether** a chunk
/// is eligible — `ChunkStore.cleanableChunks` applies §2's rule and
/// `deleteChunkFile` re-checks it immediately before unlinking, so a bug here
/// can delay a deletion but cannot cause one.
///
/// ## What "backend-confirmed" actually means today, stated plainly
///
/// §2 makes a chunk eligible when its status reaches Complete, *"i.e. the
/// backend has confirmed both the S3 object and its metadata (Volume 4,
/// Chapter 4.5's `verified_at`)"*.
///
/// **This device never observes `verified_at`.** It writes `complete` itself,
/// after Chapter 5.10 §1 step 4, on the strength of step 3's
/// `PATCH /v1/chunks/{id}/status` having returned success. Volume 4 Chapter
/// 4.6 §4 gates that transition server-side — the backend sets `verified_at`
/// and only then allows `chunks.status` to become `'complete'` — so a
/// successful PATCH does imply verification happened.
///
/// So this sweep trusts the backend's response rather than an independently
/// observed verification. That is the assumption future backend work must
/// honour: **a 2xx on that PATCH is taken as permission to delete the only
/// local copy.** Amendment A-086 records it, because it is the one place
/// correct-looking client code could violate BR-08.
///
/// Nothing is at risk today: `sessionRegistrarProvider` throws (open item 36),
/// so no chunk has ever reached `complete` on a device and this sweep has
/// never had anything to do.
///
/// ## Not synchronous with eligibility, per §2
///
/// §2 asks for *"a low-priority background sweep, not synchronously at the
/// moment of eligibility — deleting a large video file is not time-critical,
/// and batching it avoids competing with an active Recording Pipeline
/// (Chapter 5.4) for I/O"*.
///
/// So the sweep runs once at startup — clearing anything a previous session
/// left eligible — and then on a timer.
class StorageCleanupSweep {
  /// Creates a sweep over one chunk store, driven by an injectable clock.
  StorageCleanupSweep({
    required this._store,
    required this._clock,
    required AppLogger logger,
    Duration? interval,
    int batchSize = defaultBatchSize,
  }) : _log = logger,
       _interval = interval ?? defaultInterval,
       _batchSize = batchSize,
       assert(batchSize > 0, 'A sweep that deletes nothing is not a batch');

  /// How often the sweep runs.
  ///
  /// **Derived, not chosen.** Chapter 5.15 §2 gives no interval, but the
  /// sweep's job is to keep pace with completions, and a completion cannot
  /// arrive faster than a chunk is produced — one per
  /// [RecordingLifecycle.chunkDuration]. One sweep per chunk-boundary period
  /// therefore keeps pace by construction, and §2's *"low-priority"* rules out
  /// running it more often to do nothing.
  ///
  /// Delegated rather than restated, the way
  /// `ChecklistOutcome.minimumFreeBytes` delegates to
  /// `RecordingLifecycle.oneChunkBytes`: if the chunk period ever
  /// changes, the sweep follows it instead of drifting away from it.
  static const Duration defaultInterval = RecordingLifecycle.chunkDuration;

  /// How many chunks one sweep will delete.
  ///
  /// **Chosen, not derived — provisional.** §2 requires batching *"to avoid
  /// competing with an active Recording Pipeline (Ch.5.4) for I/O"* and names
  /// no size. NFR-SCL-01 fixes the depth the system must absorb — *"queue
  /// depth of 50+ pending chunks without UI slowdown"* — and ten clears a
  /// fifty-chunk backlog in five sweeps while keeping each write short.
  ///
  /// Ten is a fraction of fifty rather than a consequence of it. A file unlink
  /// is a directory-metadata operation whatever the 610 MB behind it, so the
  /// bound is precautionary rather than measured. Amendment A-088 and its open
  /// item record that, in the same shape A-078 used for §3's concurrency.
  static const int defaultBatchSize = 10;

  final ChunkStore _store;
  final Clock _clock;
  final AppLogger _log;
  final Duration _interval;
  final int _batchSize;

  ScheduledDelay? _tick;
  bool _running = false;
  bool _stopped = false;

  /// Whether a sweep is in flight.
  bool get isSweeping => _running;

  /// Runs a sweep now, then every interval.
  ///
  /// The startup pass matters: a device that was killed with eligible chunks
  /// on disk would otherwise hold them for a full interval after relaunch, and
  /// Chapter 5.15 §4's storage-pressure argument assumes cleanup is keeping
  /// up. Calling this twice is a no-op.
  void start() {
    if (_tick != null || _stopped || _running) {
      return;
    }
    unawaited(_sweepThenSchedule());
  }

  /// Stops the timer. A sweep already in flight finishes.
  Future<void> stop() async {
    _stopped = true;
    _tick?.cancel();
    _tick = null;
  }

  Future<void> _sweepThenSchedule() async {
    await sweep();
    if (_stopped) {
      return;
    }
    _tick = _clock.delay(_interval, () {
      _tick = null;
      if (!_stopped) {
        unawaited(_sweepThenSchedule());
      }
    });
  }

  /// One pass. Public so the device probe and the tests can drive it directly.
  ///
  /// Never throws. A sweep that cannot read the queue, or that fails on one
  /// chunk, reports the fact and leaves everything else alone — Chapter 5.15
  /// is about reclaiming space, and failing to reclaim space is not worth
  /// taking anything else down for.
  Future<StorageSweepResult> sweep() async {
    if (_running) {
      // A previous sweep is still going. Overlapping them would let two
      // passes claim the same chunk, and the second `deleteChunkFile` would
      // be a no-op anyway — but the batch accounting would double-count.
      return StorageSweepResult.idle;
    }
    _running = true;
    try {
      return await _sweepOnce();
    } on Object catch (error, stackTrace) {
      _log.error(
        'The storage cleanup sweep failed. Local files that are eligible for '
        'deletion are still on disk; nothing has been lost.',
        error: error,
        stackTrace: stackTrace,
      );
      return StorageSweepResult.idle;
    } finally {
      _running = false;
    }
  }

  Future<StorageSweepResult> _sweepOnce() async {
    // One more than the batch, so truncation is observable without a second
    // query: if the extra row came back, more work remains.
    final List<CleanableChunk> found = await _store.cleanableChunks(
      limit: _batchSize + 1,
    );
    final bool moreRemaining = found.length > _batchSize;
    final List<CleanableChunk> batch = found.take(_batchSize).toList();

    if (batch.isEmpty) {
      return StorageSweepResult.idle;
    }

    int deleted = 0;
    int reclaimed = 0;
    int orphans = 0;
    int failures = 0;

    for (final CleanableChunk chunk in batch) {
      try {
        final bool removed = await _store.deleteChunkFile(chunk.chunkId);
        if (removed) {
          deleted += 1;
          reclaimed += chunk.fileSizeBytes;
        } else {
          // Eligible a moment ago and not now: already cleaned by an
          // overlapping pass, or the row moved. Neither is an error.
          orphans += 1;
        }
      } on Object catch (error, stackTrace) {
        failures += 1;
        _log.warning(
          'Chunk ${chunk.chunkId} could not be cleaned up. It stays on disk '
          'and the next sweep will try again.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final StorageSweepResult result = StorageSweepResult(
      filesDeleted: deleted,
      bytesReclaimed: reclaimed,
      orphansFound: orphans,
      failures: failures,
      moreRemaining: moreRemaining,
    );

    if (result.didWork) {
      _log.info(
        'Storage cleanup: $deleted file(s) removed, '
        '${(reclaimed / (1000 * 1000)).toStringAsFixed(1)} MB reclaimed'
        '${moreRemaining ? ', more remaining' : ''}.',
      );
    }
    return result;
  }
}

/// Chapter 5.15's sweep, wired to the one chunk store.
///
/// Reads `chunkStoreProvider`, which the composition root already binds to the
/// single `IsarChunkStore` behind four other contracts (ADR-040) — so the
/// sweep deletes exactly the files the finalizer wrote and the pipeline
/// confirmed, rather than a second connection's view of them.
final Provider<StorageCleanupSweep> storageCleanupSweepProvider =
    Provider<StorageCleanupSweep>(
      (Ref ref) => StorageCleanupSweep(
        store: ref.watch(chunkStoreProvider),
        clock: ref.watch(clockProvider),
        logger: ref.watch(loggerProvider),
      ),
    );
