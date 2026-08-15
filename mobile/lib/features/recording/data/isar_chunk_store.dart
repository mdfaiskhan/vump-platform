import 'dart:io';

import 'package:isar/isar.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/features/recording/data/chunk_record_mapper.dart';
import 'package:mobile/features/recording/data/collections/local_chunk.dart';
import 'package:mobile/features/recording/data/collections/local_chunk_metadata.dart';
import 'package:mobile/features/recording/data/collections/local_session.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
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
class IsarChunkStore implements ChunkStore {
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
        .where((LocalChunk row) => !File(row.localFilePath).existsSync())
        .map((LocalChunk row) => row.chunkId)
        .toList();
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
