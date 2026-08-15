import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';
import 'package:mobile/features/recording/domain/repositories/video_processor.dart';

/// Runs a chunked SHA-256 on a background isolate.
///
/// The only file in this feature that imports `crypto`, and the only one that
/// spawns an isolate.
///
/// ## Block-wise, because the chapter says so and because 610 MB
///
/// Volume 5 Ch. 5.5 §1.2 requires the hash be *"streamed in fixed-size blocks
/// rather than loading the whole file into memory"*. `File.openRead()` yields
/// blocks and `sha256.startChunkedConversion` consumes them, so peak memory is
/// one block regardless of chunk size. Reading a 610 MB chunk into a single
/// `Uint8List` would risk an OOM on a mid-range handset for no benefit.
///
/// ## On an isolate, because the chapter says so and because it is slow
///
/// §2 requires the work run *"on a background isolate/thread separate from the
/// UI, so the brief Local Processing screen (C-10) reflects genuine progress
/// rather than blocking the main thread"*.
///
/// **Measured: pure-Dart SHA-256 runs at roughly 49 MB/s.** On this project's
/// desktop hardware, 200 MB took 4.0 s, which extrapolates to about **12.3 s
/// for a full 610 MB chunk** — and a phone will be slower, not faster. That is
/// far too long to hold the main isolate, so `Isolate.run` is load-bearing
/// here rather than a precaution.
///
/// Amendment A-059 records the consequence the chapter does not: C-10 is
/// visible for that whole time, at every automatic chunk boundary, and whether
/// that is acceptable is an open product question.
///
/// ## Why `Isolate.run` and not `compute`
///
/// `compute` is Flutter's wrapper and carries a `WidgetsBinding` dependency
/// this layer has no reason to acquire. `Isolate.run` is `dart:isolate` and
/// takes a closure directly. The closure captures only a `String` path, which
/// is trivially sendable — the `File` handle is opened inside the isolate, not
/// passed into it, because handles are not transferable.
class IsolateVideoProcessor implements VideoProcessor {
  /// Creates a processor.
  ///
  /// [runner] exists so tests can execute the work inline instead of spawning
  /// an isolate — spawning one per test is slow, and what the tests assert is
  /// the hashing, not `dart:isolate`. It defaults to the real thing, so
  /// production never takes the inline path.
  const IsolateVideoProcessor({
    Future<ChunkIntegrity> Function(Future<ChunkIntegrity> Function())? runner,
  }) : _run = runner ?? _spawnIsolate;

  final Future<ChunkIntegrity> Function(Future<ChunkIntegrity> Function()) _run;

  /// The read block size handed to the hash, in bytes.
  ///
  /// `File.openRead()` chooses its own block size and this does not override
  /// it — the constant documents the shape §1.2 asks for and gives the tests
  /// a figure to reason about. Hashing cost is dominated by the SHA-256
  /// rounds, not by block size, so tuning it buys nothing measurable.
  static const int readBlockBytes = 64 * 1024;

  static Future<ChunkIntegrity> _spawnIsolate(
    Future<ChunkIntegrity> Function() work,
  ) => Isolate.run(work);

  @override
  Future<ChunkIntegrity> process(String path) async {
    try {
      return await _run(() => _hashAndMeasure(path));
    } on StorageException {
      rethrow;
    } on FileSystemException catch (error, stackTrace) {
      // Thrown inside the isolate and re-surfaced here. The pipeline only
      // hands over paths the platform has already closed, so this means the
      // file moved or was deleted in between.
      throw StorageException(
        errorCode: ErrorCode.storageNotFound,
        message: 'The finalized chunk could not be read for checksumming.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The work itself — runs inside the isolate, so it must be self-contained.
  static Future<ChunkIntegrity> _hashAndMeasure(String path) async {
    final File file = File(path);

    // §1.3: the byte count comes "directly from the closed file handle, never
    // estimated". Read before hashing so a missing file fails here, with a
    // clear cause, rather than part-way through a stream.
    final int byteCount = await file.length();

    final _DigestSink digest = _DigestSink();
    final ByteConversionSink input = sha256.startChunkedConversion(digest);
    await for (final List<int> block in file.openRead()) {
      input.add(block);
    }
    input.close();

    return ChunkIntegrity(checksumSha256: digest.value, byteCount: byteCount);
  }
}

/// Catches the single digest `startChunkedConversion` emits on close.
class _DigestSink implements Sink<Digest> {
  String value = '';

  @override
  void add(Digest data) => value = data.toString();

  @override
  void close() {}
}
