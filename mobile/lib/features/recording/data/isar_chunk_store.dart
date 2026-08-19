import 'dart:io';

import 'package:isar/isar.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/core/upload/interfaces/chunk_metadata_source.dart';
import 'package:mobile/core/upload/interfaces/chunk_upload_source.dart';
import 'package:mobile/core/upload/metadata/chunk_metadata_document.dart';
import 'package:mobile/core/upload/uploadable_chunk.dart';
import 'package:mobile/features/recording/data/chunk_metadata_document_mapper.dart';
import 'package:mobile/features/recording/data/chunk_record_mapper.dart';
import 'package:mobile/features/recording/data/collections/local_chunk.dart';
import 'package:mobile/features/recording/data/collections/local_chunk_metadata.dart';
import 'package:mobile/features/recording/data/collections/local_session.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/cleanable_chunk.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_store.dart';

/// Persists chunks and metadata to Isar, atomically.
///
/// ## The transaction is the requirement
///
/// Chapter 5.7 §3 asks for *"the same transaction … both succeed or both fail
/// together"*. Isar provides that directly as `writeTxn`, which commits only
/// if its callback completes. All three puts — session, chunk, metadata — are
/// inside one, so FR-META-09's guarantee that *"a chunk file can never exist
/// locally without its metadata already alongside it"* holds by construction
/// rather than by ordering discipline.
///
/// ## The file is moved before the transaction, deliberately
///
/// The camera plugin writes wherever it likes; Chapter 5.8 §2 fixes the layout
/// as `<app-documents>/recordings/{session_id}/{sequence_index:04d}.mp4`. The
/// move happens first so that a committed row always names a file already in
/// place. Committing first and moving after would leave a window where a row
/// points at a path nothing has written.
///
/// If the transaction then fails, the file has moved and no row exists. That
/// residue is recoverable — an unreferenced file in a known directory — and is
/// strictly better than the alternative, a row referencing a file that is not
/// there and cannot be produced.
///
/// ## The session row is written once, not once per chunk
///
/// A session produces many chunks and every one of them arrives here with the
/// same [RecordingSession]. Writing the row unconditionally would overwrite it
/// on each chunk, discarding anything another path had put there —
/// specifically `task_id` and `collector_id`, which are null today only
/// because their sources are unbuilt (A-062) and are stored nullable
/// precisely so they can be back-filled. So the row is inserted only if
/// absent.
///
/// **`status` therefore stays `in_progress` forever**, which is a real gap and
/// is not papered over: nothing in the chunk-save path knows a session has
/// ended, and the transition to `complete` that FR-SES-02 requires belongs to
/// the lifecycle's return to `Idle`. Amendment A-063 records it.
///
/// ## Crash recovery: what this can and cannot do
///
/// **Achievable, and implemented.** Any chunk whose `stopChunk()` returned
/// before the crash has a committed row, a file at a deterministic path, and
/// its metadata beside it. It is fully identifiable and can be re-queued on
/// the next launch — [recoverableChunkIds]. This is the part of Chapter 5.3
/// §5 that survives.
///
/// **Not achievable, and not faked.** A chunk still recording when the process
/// dies is unrecoverable. Chapter 5.8 §2 proposes the mechanism —
/// *"`{sequence_index:04d}.mp4.tmp` … on app relaunch, any `.tmp` file is
/// either completed or deleted"* — and it cannot be built here: the plugin
/// chooses the in-progress path and filename, `VideoCaptureOptions` exposes no
/// way to influence either, and the partial file is left in the plugin's own
/// temp directory under a name that carries no session or sequence. There is
/// nothing to scan for and nothing to link a found file back to.
///
/// **So no `.tmp` scan is implemented**, because it would search for files
/// that cannot exist in this application's tree. This is a structural limit of
/// the plugin choice, in the same category as A-058's software-encoder
/// guarantee, and is recorded in amendment A-063.
class IsarChunkStore
    implements
        ChunkStore,
        ChunkQueueSource,
        ChunkUploadSource,
        ChunkMetadataSource {
  /// Creates a store over [database], writing files beneath the documents
  /// directory at [documentsDirectoryPath].
  const IsarChunkStore({
    required Isar database,
    required String documentsDirectoryPath,
  }) : _isar = database,
       _documentsPath = documentsDirectoryPath;

  final Isar _isar;
  final String _documentsPath;

  /// The directory chunks live in, below the app documents directory.
  ///
  /// Chapter 5.8 §2: `<app-documents>/recordings/{session_id}/`.
  static const String recordingsDirectory = 'recordings';

  /// Width of the zero-padded sequence index in a filename.
  ///
  /// Chapter 5.8 §2 and Chapter 5.14 §1 both write `{sequence_index:04d}`, and
  /// the S3 key depends on the same padding — so the local name and the remote
  /// key stay legibly the same number.
  static const int sequenceIndexWidth = 4;

  /// The filename Chapter 5.8 §2 specifies — `{sequence_index:04d}.mp4`.
  ///
  /// Public because the naming rule is the requirement, and a rule expressed
  /// only inside a private method of a class that needs a live database is a
  /// rule nothing can check.
  ///
  /// Indices past 9999 stop being padded rather than being truncated. A
  /// session would need to run about 69 days at ten-minute chunks to reach
  /// one, and a longer name sorts oddly where a truncated one would collide.
  static String chunkFileName(int sequenceIndex) {
    return '${sequenceIndex.toString().padLeft(sequenceIndexWidth, '0')}.mp4';
  }

  /// The directory Chapter 5.8 §2 gives one session —
  /// `<app-documents>/recordings/{session_id}/`.
  static String sessionDirectoryPath({
    required String documentsPath,
    required String sessionId,
  }) {
    return '$documentsPath/$recordingsDirectory/$sessionId';
  }

  @override
  Future<void> saveChunk({
    required RecordingSession session,
    required ChunkProcessingJob job,
    required ChunkMetadata metadata,
  }) async {
    final String finalPath = await _placeFile(
      sourcePath: job.filePath,
      sessionId: session.sessionId,
      sequenceIndex: job.sequenceIndex,
    );

    try {
      await _isar.writeTxn(() async {
        final LocalSession? existing = await _isar.localSessions.getBySessionId(
          session.sessionId,
        );
        if (existing == null) {
          await _isar.localSessions.putBySessionId(
            ChunkRecordMapper.toLocalSession(session),
          );
        }

        await _isar.localChunks.putByChunkId(
          ChunkRecordMapper.toLocalChunk(
            job: job,
            session: session,
            metadata: metadata,
            localFilePath: finalPath,
          ),
        );
        await _isar.localChunkMetadatas.putByChunkId(
          ChunkRecordMapper.toLocalMetadata(metadata),
        );
      });
      // Caught untyped on purpose. Isar reports failures as `IsarError`, which
      // extends `Error` rather than `Exception`, so `on Exception` would let
      // every real transaction failure through — and a failed write here must
      // surface as a `StorageException`, because the file has already moved
      // and the caller has to know no row was committed for it.
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageWriteFailed,
        message: 'The chunk and its metadata could not be saved together.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> markSessionComplete(String sessionId) async {
    try {
      await _isar.writeTxn(() async {
        final LocalSession? row = await _isar.localSessions.getBySessionId(
          sessionId,
        );
        if (row == null) {
          // A session that produced no chunk never got a row. Creating one
          // here would record a completed session that captured nothing.
          return;
        }
        row.status = ChunkRecordMapper.sessionComplete;
        await _isar.localSessions.putBySessionId(row);
      });
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageWriteFailed,
        message: 'The session could not be marked complete.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<String>> recoverableChunkIds() async {
    final List<LocalChunk> rows = await _isar.localChunks
        .filter()
        .statusEqualTo(ChunkRecordMapper.statusQueued)
        .findAll();

    final List<String> recoverable = <String>[];
    for (final LocalChunk row in rows) {
      if (File(row.localFilePath).existsSync()) {
        recoverable.add(row.chunkId);
      }
    }
    return recoverable;
  }

  @override
  Future<List<String>> orphanedChunkIds() async {
    final List<LocalChunk> rows = await _isar.localChunks.where().findAll();
    return rows
        // Chapter 5.15's sweep deliberately removes files and records the
        // removal on the row. Without this exclusion every successful cleanup
        // would report itself as an orphan, and the one signal that means
        // "something deleted a file behind our back" would be buried under
        // the deletions this application performed on purpose.
        .where((LocalChunk row) => row.localDeletedAt == null)
        .where((LocalChunk row) => !File(row.localFilePath).existsSync())
        .map((LocalChunk row) => row.chunkId)
        .toList();
  }

  @override
  Future<List<CleanableChunk>> cleanableChunks({required int limit}) async {
    try {
      final List<LocalChunk> rows = await _isar.localChunks
          .filter()
          .statusEqualTo(ChunkUploadStatus.complete.wireName)
          .localDeletedAtIsNull()
          .findAll();

      // Chapter 5.9 §2's order, so a backlog drains in the order it built up.
      // Session start times live on the session rows; Isar has no joins, so
      // they are resolved here exactly as claimNext does.
      final List<LocalSession> sessions = await _isar.localSessions
          .where()
          .findAll();
      final Map<String, DateTime> startedAt = <String, DateTime>{
        for (final LocalSession session in sessions)
          session.sessionId: session.startedAt,
      };

      rows.sort((LocalChunk a, LocalChunk b) {
        final DateTime? aStart = startedAt[a.sessionId];
        final DateTime? bStart = startedAt[b.sessionId];
        if (aStart != null && bStart != null) {
          final int bySession = aStart.compareTo(bStart);
          if (bySession != 0) {
            return bySession;
          }
        }
        return a.sequenceIndex.compareTo(b.sequenceIndex);
      });

      return rows
          .take(limit)
          .map(
            (LocalChunk row) => CleanableChunk(
              chunkId: row.chunkId,
              localFilePath: row.localFilePath,
              fileSizeBytes: row.fileSizeBytes,
            ),
          )
          .toList();
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageReadFailed,
        message: 'The chunks eligible for cleanup could not be read.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<bool> deleteChunkFile(String chunkId) async {
    final LocalChunk? row = await _isar.localChunks.getByChunkId(chunkId);

    // BR-08, enforced at the last possible moment rather than trusted from the
    // caller. Chapter 5.15 §5: never on age, never on disk pressure, never on
    // any heuristic that is not backend-confirmed Complete. A caller that
    // passed the wrong id gets a no-op, not a deleted file.
    if (row == null ||
        row.status != ChunkUploadStatus.complete.wireName ||
        row.localDeletedAt != null) {
      return false;
    }

    // The file goes first, and the row is marked only if that succeeded.
    //
    // The other order would be worse in the way that matters. A row marked
    // deleted whose file survived is a permanent leak: nothing looks at that
    // file again, because `cleanableChunks` excludes soft-deleted rows and
    // `orphanedChunkIds` now excludes them too. A file deleted whose row was
    // not marked is picked up by the next sweep and marked then — the failure
    // costs one retry rather than one orphaned 610 MB file.
    final File file = File(row.localFilePath);
    try {
      // existsSync rather than exists: `avoid_slow_async_io` (ADR-021) and
      // `orphanedChunkIds` above already takes the same route.
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageWriteFailed,
        message: 'The chunk file could not be deleted.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    await _write(chunkId, 'The chunk could not be marked cleaned.', (
      LocalChunk target,
    ) {
      // Chapter 5.15 §2 removes "the raw video file (and its local_chunks
      // row's file reference)". localFilePath is left as written and
      // localDeletedAt is the authoritative marker — blanking the path would
      // put an empty-string sentinel in a column that is otherwise always a
      // real path, which is the ambiguity A-068 exists to condemn. A-087.
      target.localDeletedAt = DateTime.now();
    });
    return true;
  }

  // ---------------------------------------------------------------------
  // ChunkQueueSource — Volume 5 Chapter 5.9's queue view.
  //
  // Added by Mission 4.1 and entirely additive: nothing above this line
  // changed. The capture and finalize path Mission 3 verified on hardware -
  // saveChunk, markSessionComplete, _placeFile - is untouched.
  //
  // This class implements two interfaces because it is the one object that
  // already holds the Isar instance. ADR-040 explains why the *contract* sits
  // in core/ rather than here: features/upload/ must read these rows without
  // importing features/recording/.
  // ---------------------------------------------------------------------

  @override
  Stream<List<QueuedChunk>> watchQueue() async* {
    yield await currentQueue();
    // fireImmediately is false because the line above already emitted, and
    // Isar would otherwise deliver a duplicate first event.
    await for (final void _ in _isar.localChunks.watchLazy()) {
      yield await currentQueue();
    }
  }

  @override
  Future<List<QueuedChunk>> currentQueue() async {
    // Two reads and a join in Dart, per Mission 4.1's decision not to
    // denormalise the session's start time onto LocalChunk. Isar has no
    // joins, and adding a column to a Mission 3 collection for query
    // convenience would mean a schema change and a migration to the one
    // collection that already holds real footage on real devices.
    final List<LocalChunk> rows = await _isar.localChunks.where().findAll();
    final List<LocalSession> sessions = await _isar.localSessions
        .where()
        .findAll();

    final Map<String, DateTime> startedAt = <String, DateTime>{
      for (final LocalSession session in sessions)
        session.sessionId: session.startedAt,
    };

    // Mission 7.4 F17. No extra query: the session rows are already loaded for
    // the join above, so the Task ride-along costs one more map over the same
    // list. Nullable at source and left nullable here — see QueuedChunk.taskId.
    final Map<String, String?> taskOf = <String, String?>{
      for (final LocalSession session in sessions)
        session.sessionId: session.taskId,
    };

    final List<QueuedChunk> queue = <QueuedChunk>[];
    for (final LocalChunk row in rows) {
      // BR-08 and Chapter 5.15: a chunk cleared after a confirmed upload is
      // gone from the queue, not shown as a lingering entry.
      if (row.localDeletedAt != null) {
        continue;
      }
      final ChunkUploadStatus? status = ChunkUploadStatus.fromWireName(
        row.status,
      );
      final DateTime? sessionStart = startedAt[row.sessionId];
      // A row whose status is unrecognised, or whose session row is missing,
      // is skipped rather than guessed at. Either would mean the database
      // disagrees with itself, and inventing a status or a timestamp would
      // put a chunk in the queue at a position nothing chose.
      if (status == null || sessionStart == null) {
        continue;
      }
      queue.add(
        QueuedChunk(
          chunkId: row.chunkId,
          sessionId: row.sessionId,
          taskId: taskOf[row.sessionId],
          sequenceIndex: row.sequenceIndex,
          sessionStartedAt: sessionStart,
          status: status,
          fileSizeBytes: row.fileSizeBytes,
          attemptCount: row.uploadAttemptCount,
          nextAttemptAt: row.nextAttemptAt,
        ),
      );
    }

    queue.sort();
    return queue;
  }

  @override
  Future<void> requeue(String chunkId) async {
    try {
      await _isar.writeTxn(() async {
        final LocalChunk? row = await _isar.localChunks.getByChunkId(chunkId);
        // Only a failed chunk is retryable. Dragging an `uploading` chunk
        // backwards would race Chapter 5.11's dispatcher, and re-queueing a
        // `complete` one would contradict BR-12.
        if (row == null || row.status != ChunkUploadStatus.failed.wireName) {
          return;
        }
        row.status = ChunkUploadStatus.queued.wireName;
        // Chapter 5.13 §3: tapping Retry Chunk "resets the attempt counter and
        // immediately tries again, regardless of how long the chunk has been
        // Failed — this is a deliberate Collector override of the automatic
        // backoff schedule". Clearing the deadline is what makes "immediately"
        // true; leaving the counter would give the override one attempt rather
        // than a fresh six.
        //
        // It is not an override of §1's terminal classification. A chunk that
        // failed on a 4xx will fail again on the next attempt, with the same
        // named cause — which §3 states outright and C-11 then shows again.
        row.uploadAttemptCount = 0;
        row.nextAttemptAt = null;
        await _isar.localChunks.putByChunkId(row);
      });
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageWriteFailed,
        message: 'The chunk could not be returned to the queue.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ---------------------------------------------------------------------
  // ChunkUploadSource — Chapter 5.10's pipeline view of the same rows
  // ---------------------------------------------------------------------

  @override
  Future<UploadableChunk?> claimNext({required DateTime now}) async {
    try {
      return await _isar.writeTxn(() async {
        // Read and write inside one transaction. This is what makes the claim
        // atomic: Chapter 5.11's dispatcher will run several of these
        // concurrently, and a chunk claimed twice would be uploaded twice —
        // the one duplication S3's same-key semantics cannot undo, because
        // both attempts would be legitimate.
        final List<LocalChunk> all = await _isar.localChunks
            .filter()
            .statusEqualTo(ChunkUploadStatus.queued.wireName)
            .findAll();

        // Chapter 5.13 §2's backoff window. A chunk waiting out its delay is
        // legitimately `queued` — §1 forbids surfacing a transient failure as
        // Failed before the attempts are exhausted — but it is not claimable
        // yet. Filtering here rather than in the caller keeps the ordering and
        // the eligibility rule in one transaction, so a chunk cannot become
        // eligible between the two.
        final List<LocalChunk> rows = all
            .where(
              (LocalChunk row) =>
                  row.nextAttemptAt == null || !row.nextAttemptAt!.isAfter(now),
            )
            .toList();
        if (rows.isEmpty) {
          return null;
        }

        final List<LocalSession> sessions = await _isar.localSessions
            .where()
            .findAll();
        final Map<String, DateTime> startedAt = <String, DateTime>{
          for (final LocalSession session in sessions)
            session.sessionId: session.startedAt,
        };
        // The claim path's half of F17 — B3. The same map `currentQueue`
        // builds, from the same rows already loaded, so the Task costs one
        // more lookup and no additional read.
        final Map<String, String?> taskOf = <String, String?>{
          for (final LocalSession session in sessions)
            session.sessionId: session.taskId,
        };

        // Same skips as currentQueue, for the same reasons: a soft-deleted
        // row is gone (BR-08), and a row whose session is missing has no
        // position, so claiming it would upload out of the order Chapter 5.9
        // §2 fixes.
        LocalChunk? best;
        DateTime? bestStart;
        for (final LocalChunk row in rows) {
          if (row.localDeletedAt != null) {
            continue;
          }
          final DateTime? sessionStart = startedAt[row.sessionId];
          if (sessionStart == null) {
            continue;
          }
          if (best == null || _precedes(sessionStart, row, bestStart!, best)) {
            best = row;
            bestStart = sessionStart;
          }
        }

        if (best == null || bestStart == null) {
          return null;
        }

        best.status = ChunkUploadStatus.uploading.wireName;
        await _isar.localChunks.putByChunkId(best);

        return UploadableChunk(
          chunkId: best.chunkId,
          sessionId: best.sessionId,
          taskId: taskOf[best.sessionId],
          sequenceIndex: best.sequenceIndex,
          sessionStartedAt: bestStart,
          localFilePath: best.localFilePath,
          fileSizeBytes: best.fileSizeBytes,
          checksumSha256: best.checksumSha256,
          s3ObjectKey: best.s3ObjectKey,
          attemptCount: best.uploadAttemptCount,
        );
      });
    } on StorageException {
      rethrow;
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageWriteFailed,
        message: 'The next chunk could not be claimed for upload.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Chapter 5.9 §2's order, as a comparison between two candidate rows.
  ///
  /// Identical to `QueuedChunk.compareTo` — session start, then sequence
  /// index, then chunk id. Written out rather than built through
  /// `UploadableChunk` so the scan does not allocate a projection per row
  /// while looking for one.
  static bool _precedes(
    DateTime candidateStart,
    LocalChunk candidate,
    DateTime bestStart,
    LocalChunk best,
  ) {
    final int bySession = candidateStart.compareTo(bestStart);
    if (bySession != 0) {
      return bySession < 0;
    }
    final int bySequence = candidate.sequenceIndex.compareTo(
      best.sequenceIndex,
    );
    if (bySequence != 0) {
      return bySequence < 0;
    }
    return candidate.chunkId.compareTo(best.chunkId) < 0;
  }

  @override
  Future<void> recordObjectKey({
    required String chunkId,
    required String s3ObjectKey,
  }) => _write(
    chunkId,
    "The chunk's object key could not be stored.",
    (LocalChunk row) => row.s3ObjectKey = s3ObjectKey,
  );

  @override
  Future<void> release(String chunkId) => _transition(
    chunkId,
    to: ChunkUploadStatus.queued,
    failureMessage: 'The chunk could not be released back to the queue.',
  );

  @override
  Future<void> markFailed(String chunkId) => _transition(
    chunkId,
    to: ChunkUploadStatus.failed,
    failureMessage: 'The chunk could not be marked failed.',
  );

  @override
  Future<void> deferAttempt({
    required String chunkId,
    required int attemptCount,
    required DateTime nextAttemptAt,
  }) => _write(chunkId, 'The chunk could not be rescheduled.', (
    LocalChunk row,
  ) {
    // Same precondition as the three transitions above: only a claimed chunk
    // can be deferred. Without it, a deferral racing a manual retry could
    // push a chunk the Collector just re-queued back into a backoff window.
    if (row.status != ChunkUploadStatus.uploading.wireName) {
      return;
    }
    row.status = ChunkUploadStatus.queued.wireName;
    row.uploadAttemptCount = attemptCount;
    row.nextAttemptAt = nextAttemptAt;
  });

  @override
  Future<void> clearBackoff() async {
    try {
      await _isar.writeTxn(() async {
        final List<LocalChunk> rows = await _isar.localChunks
            .filter()
            .statusEqualTo(ChunkUploadStatus.queued.wireName)
            .findAll();
        final List<LocalChunk> pending = rows
            .where((LocalChunk row) => row.nextAttemptAt != null)
            .toList();
        if (pending.isEmpty) {
          // No write at all when nothing is deferred. The queue is a live
          // Isar watch, and putting unchanged rows would emit a queue event
          // on every reconnection — waking the dispatcher for no reason.
          return;
        }
        for (final LocalChunk row in pending) {
          row.nextAttemptAt = null;
        }
        await _isar.localChunks.putAllByChunkId(pending);
      });
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageWriteFailed,
        message: 'The backoff deadlines could not be cleared.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> markComplete(String chunkId) => _transition(
    chunkId,
    to: ChunkUploadStatus.complete,
    failureMessage: 'The chunk could not be marked complete.',
  );

  /// Moves a chunk out of `uploading`.
  ///
  /// All three transitions guard on the same precondition, and that guard is
  /// the point: only a claimed chunk can be released, failed or completed. A
  /// `queued` chunk moved to `complete` was never uploaded, and a `complete`
  /// one moved back would contradict BR-12. Ignoring the call rather than
  /// throwing makes a duplicate — a retry after a dropped response — a no-op,
  /// which is what Chapter 5.10 §3's idempotency argument assumes.
  Future<void> _transition(
    String chunkId, {
    required ChunkUploadStatus to,
    required String failureMessage,
  }) => _write(chunkId, failureMessage, (LocalChunk row) {
    if (row.status != ChunkUploadStatus.uploading.wireName) {
      return;
    }
    row.status = to.wireName;
  });

  /// Applies [mutate] to one chunk row inside a transaction.
  ///
  /// A missing row is ignored rather than raised: it means the chunk was
  /// cleaned up or never existed, and neither is a storage failure. Only a
  /// failure of the write itself becomes a [StorageException].
  Future<void> _write(
    String chunkId,
    String failureMessage,
    void Function(LocalChunk row) mutate,
  ) async {
    try {
      await _isar.writeTxn(() async {
        final LocalChunk? row = await _isar.localChunks.getByChunkId(chunkId);
        if (row == null) {
          return;
        }
        mutate(row);
        await _isar.localChunks.putByChunkId(row);
      });
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageWriteFailed,
        message: failureMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ---------------------------------------------------------------------
  // ChunkMetadataSource — Chapter 5.10 §1 step 4's document
  // ---------------------------------------------------------------------

  @override
  Future<ChunkMetadataDocument?> metadataDocument(String chunkId) async {
    try {
      final LocalChunkMetadata? row = await _isar.localChunkMetadatas
          .getByChunkId(chunkId);
      return row == null ? null : ChunkMetadataDocumentMapper.fromLocal(row);
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageReadFailed,
        message: "The chunk's metadata could not be read.",
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Moves the plugin's output into Chapter 5.8 §2's layout.
  ///
  /// `rename` first, because within one filesystem it is atomic and free. It
  /// fails across devices — the plugin's cache directory and the documents
  /// directory need not share a mount — so a copy-then-delete fallback
  /// follows. The copy is not atomic, which is why the row is written after
  /// it rather than before.
  Future<String> _placeFile({
    required String sourcePath,
    required String sessionId,
    required int sequenceIndex,
  }) async {
    final Directory target = Directory(
      sessionDirectoryPath(documentsPath: _documentsPath, sessionId: sessionId),
    );
    final String finalPath = '${target.path}/${chunkFileName(sequenceIndex)}';

    try {
      await target.create(recursive: true);
      final File source = File(sourcePath);
      try {
        await source.rename(finalPath);
      } on FileSystemException {
        await source.copy(finalPath);
        await source.delete();
      }
      return finalPath;
    } on FileSystemException catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageWriteFailed,
        message: 'The finalized chunk could not be moved into place.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
