import 'dart:async';
import 'dart:io';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/network/s3_transfer_client.dart';
import 'package:mobile/core/network/transfer_handle.dart';
import 'package:mobile/core/network/vump_api.dart';
import 'package:mobile/features/upload/domain/entities/chunk_registration.dart';
import 'package:mobile/features/upload/domain/repositories/chunk_upload_api.dart';

/// Volume 5 Chapter 5.10 §1's four calls, against Volume 4 Chapter 4.6.
///
/// ## Two clients, and the split is the security boundary
///
/// Steps 1, 3 and 4 go to the Vump backend through [VumpApi], which sits on
/// `DioClient` and so carries the Firebase ID token Chapter 4.6 §1 requires on
/// *"every request"*.
///
/// Step 2 goes to S3 through [S3TransferClient], which **has no token source
/// at all**. A presigned URL carries its own SigV4 authorisation in its query
/// string, and S3 rejects a request that also presents a conflicting
/// `Authorization` header — so this is not a preference, it is the only shape
/// that works. Volume 4 Chapter 4.10 §2: the parts go *"directly to S3 …  the
/// mobile app never holds a raw AWS credential"*.
///
/// ## This file imports no `package:dio`
///
/// Deliberately, and it is checked. `dio` is confined to `core/network/`, so
/// both clients are consumed through surfaces that publish no Dio type —
/// [VumpApi] returns plain maps, [S3TransferClient] returns a `String?`, and
/// cancellation arrives as a bare `Future`. See ADR-041.
class ChunkUploadApiImpl implements ChunkUploadApi {
  /// Creates the implementation over both clients.
  ChunkUploadApiImpl({
    required VumpApi backend,
    required S3TransferClient transfer,
  }) : _api = backend,
       _s3 = transfer;

  final VumpApi _api;
  final S3TransferClient _s3;

  @override
  Future<ChunkRegistration> registerChunk({
    required String remoteSessionId,
    required String chunkId,
    required int sequenceIndex,
    required int fileSizeBytes,
    required String checksumSha256,
  }) async {
    final Map<String, Object?> data = await _api.post(
      '/sessions/$remoteSessionId/chunks',
      what: 'chunk registration',
      // Chapter 4.6 §5's three fields **plus `chunk_id`** — Mission 7.3, F2.
      //
      // The chapter's sample body omits it, and the backend requires it: the id
      // is minted on this device the moment a chunk begins finalizing (Ch. 5.14
      // §3) and every retry must reuse *"the exact same chunk_id"* (Ch. 5.13
      // §4). Migration 0010 dropped `chunks.id`'s server-side default precisely
      // so a registration that omits it fails loudly rather than minting a
      // second identity this client would then reject in the echo check below.
      //
      // Still no org_id, project_id or task_id: the Lambda composes the S3 key
      // (Ch. 4.10 §2 step 1) and returns it, so the client never assembles one.
      // A-071 corrected the register's earlier belief that it did. `chunk_id`
      // is not a key component the client is supplying — it is the client's own
      // identity for the chunk, which is why it belongs here and they do not.
      body: <String, Object?>{
        'chunk_id': chunkId,
        'sequence_index': sequenceIndex,
        'file_size_bytes': fileSizeBytes,
        'checksum_sha256': checksumSha256,
      },
    );

    final Object? returnedId = data['chunk_id'];
    final Object? key = data['s3_object_key'];
    final Object? urls = data['upload_urls'];

    if (key is! String || key.isEmpty) {
      throw _malformed('Chunk registration returned no s3_object_key.');
    }
    if (urls is! List || urls.isEmpty) {
      throw _malformed('Chunk registration returned no upload_urls.');
    }

    // Chapter 5.14 §3 mints chunk_id locally and Chapter 5.13 §4 requires
    // every retry reuse it. An echoed id that differs would mean steps 3 and
    // 4 — both keyed by {id} — address a different chunk than the one whose
    // bytes step 2 uploaded.
    if (returnedId is String && returnedId != chunkId) {
      throw _malformed(
        'Chunk registration echoed a different chunk_id than the one sent.',
      );
    }

    return ChunkRegistration(
      chunkId: chunkId,
      s3ObjectKey: key,
      uploadUrls: <String>[
        for (final Object? url in urls)
          if (url is String) url,
      ],
    );
  }

  @override
  Future<void> uploadObject({
    required ChunkRegistration registration,
    required String localFilePath,
    required int fileSizeBytes,
    ChunkUploadProgress? onProgress,
    Future<void>? cancelSignal,
  }) async {
    if (!registration.hasParts) {
      throw _malformed('Chunk registration returned no upload URLs.');
    }

    final File file = File(localFilePath);
    if (!file.existsSync()) {
      // Chapter 5.13 §1's "Local file missing/corrupted" — terminal,
      // device-side. Nothing was transmitted, so this is not a transport
      // failure and must not be retried as one.
      throw const NetworkException(
        errorCode: ErrorCode.storageNotFound,
        message: 'The chunk file is missing and cannot be uploaded.',
      );
    }

    // One handle for the whole chunk. Cancelling stops the part in flight and
    // the loop stops before the next — Chapter 5.10 §4's "pause cleanly
    // mid-multipart-transfer", leaving the parts S3 already acknowledged in
    // place rather than restarting from byte zero.
    final TransferHandle handle = TransferHandle();
    final StreamSubscription<void>? cancelWatch = cancelSignal
        ?.asStream()
        .listen((void _) => handle.cancel('paused'));

    try {
      final int parts = registration.uploadUrls.length;
      // The backend chose the part count, so part size follows from it rather
      // than from a constant this app picks. Ceiling division, so the last
      // part carries the remainder instead of the file being truncated.
      final int partSize = (fileSizeBytes + parts - 1) ~/ parts;
      int sent = 0;

      for (int index = 0; index < parts; index++) {
        if (handle.isCancelled) {
          throw NetworkException(
            errorCode: ErrorCode.networkCancelled,
            message: 'The upload was cancelled before part ${index + 1}.',
          );
        }

        final int start = index * partSize;
        final int end = (start + partSize) > fileSizeBytes
            ? fileSizeBytes
            : start + partSize;
        if (start >= end) {
          // More URLs than the file has bytes for. Stopping is correct:
          // sending an empty part would register a zero-length byte range
          // against a part number S3 expects content for.
          break;
        }

        final List<int> bytes = await _readRange(file, start, end);
        final int completedBefore = sent;

        await _s3.uploadPart(
          presignedUrl: Uri.parse(registration.uploadUrls[index]),
          bytes: bytes,
          handle: handle,
          // Cumulative across the chunk, not per part: C-11 shows one
          // percentage for the chunk, and a per-part callback would reset it
          // to zero once per part.
          onProgress: onProgress == null
              ? null
              : (int partSent, int _) =>
                    onProgress(completedBefore + partSent, fileSizeBytes),
        );

        sent = end;
        onProgress?.call(sent, fileSizeBytes);
      }
    } finally {
      await cancelWatch?.cancel();
    }
  }

  @override
  Future<void> confirmStatus({
    required String chunkId,
    required String status,
  }) async {
    // Chapter 5.10 §3: a PATCH to 'complete' "is a no-op if the chunk is
    // already Complete", so re-sending after a dropped response is safe and
    // needs no guard here.
    await _api.patch(
      '/chunks/$chunkId/status',
      what: 'the chunk status update',
      body: <String, Object?>{'status': status},
    );
  }

  @override
  Future<void> postMetadata({
    required String chunkId,
    required Map<String, Object?> document,
  }) async {
    // Chapter 5.10 §1 step 4 — "Ch.5.7's object, sent as-is". Nothing is
    // reshaped here; the document arrives already in Chapter 4.5 §2's form.
    await _api.post(
      '/chunks/$chunkId/metadata',
      what: 'the chunk metadata',
      body: document,
    );
  }

  /// Reads bytes `[start, end)` of [file].
  ///
  /// Ranged rather than whole-file: a chunk measured 633 MB (A-064 §4b), and
  /// holding one in memory would risk the OOM kill Volume 9 Chapter 9.4 §1's
  /// memory ceiling forbids.
  Future<List<int>> _readRange(File file, int start, int end) async {
    final RandomAccessFile handle = await file.open();
    try {
      await handle.setPosition(start);
      return await handle.read(end - start);
    } on FileSystemException catch (error, stackTrace) {
      throw NetworkException(
        errorCode: ErrorCode.storageReadFailed,
        message: 'The chunk file could not be read for upload.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      await handle.close();
    }
  }

  NetworkException _malformed(String message) => NetworkException(
    errorCode: ErrorCode.networkSerialization,
    message: message,
  );
}
