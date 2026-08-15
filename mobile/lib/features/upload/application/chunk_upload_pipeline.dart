import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/core/network/network_constants.dart';
import 'package:mobile/core/network/providers/dio_provider.dart';
import 'package:mobile/core/network/vump_api.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/upload/interfaces/chunk_metadata_source.dart';
import 'package:mobile/core/upload/interfaces/chunk_upload_source.dart';
import 'package:mobile/core/upload/interfaces/session_registrar.dart';
import 'package:mobile/core/upload/metadata/chunk_metadata_document.dart';
import 'package:mobile/core/upload/providers/upload_ports.dart';
import 'package:mobile/core/upload/uploadable_chunk.dart';
import 'package:mobile/features/upload/data/chunk_upload_api_impl.dart';
import 'package:mobile/features/upload/domain/entities/chunk_registration.dart';
import 'package:mobile/features/upload/domain/entities/upload_failure_cause.dart';
import 'package:mobile/features/upload/domain/repositories/chunk_upload_api.dart';

/// Volume 5 Chapter 5.10's five steps, run once for one chunk.
///
/// | Step | What |
/// |---|---|
/// | 1 | Register — `POST /v1/sessions/{id}/chunks` → presigned URLs |
/// | 2 | Upload — the parts, direct to S3 |
/// | 3 | Confirm — `PATCH /v1/chunks/{id}/status` |
/// | 4 | Metadata — `POST /v1/chunks/{id}/metadata` |
/// | 5 | Verify — the backend's, not the device's |
///
/// ## What this class is not
///
/// **It is not a dispatcher.** It uploads one chunk when asked and returns.
/// Chapter 5.11 owns what decides to ask, how many run at once, and what
/// happens while the app is backgrounded; Chapter 5.13 owns retry timing and
/// the six-attempt budget. This class produces a named [UploadFailureCause]
/// and stops — it never schedules a second attempt, because the policy that
/// would decide the delay does not exist yet, and a hardcoded retry here would
/// be that policy written by the wrong mission.
///
/// ## Guard 1 sits before step 1, and it fires on every real chunk today
///
/// A-068's client-side guard: a chunk whose `identity` group does not name
/// real things must **not be sent** — *"not silently skipped, not silently
/// sent"*. It is checked after the claim and before any network call, and a
/// failure marks the chunk `failed` with
/// [UploadFailureCause.identityIncomplete].
///
/// Volume 8 Chapter 8.6 §2 collects identity *"to attribute footage to the
/// correct Collector/device"*, and BR-22 makes system-generated metadata
/// immutable once written — so a chunk stored with a blank `collector_id`
/// could never be corrected afterwards. Permanently unattributable evidence is
/// worse than a refused upload.
///
/// **This currently refuses 100% of chunks recorded on a device.** Four of
/// `MetadataIdentity`'s five fields carry the unsourced sentinel until
/// `features/projects_tasks/` exists, the `collector_id` inversion lands, and
/// something produces a `device_id`. That is the correct behaviour and it is
/// also the honest state of the feature.
///
/// ## Step 5 is the backend's, and `complete` is written after step 4
///
/// Chapter 5.10 §1 places `complete` at step 3's PATCH, and §1 step 5 has the
/// device observe it *"via its next sync"* — a sync mechanism that is not
/// built and is not in this mission's scope.
///
/// This writes the local `complete` after **step 4**, not step 3. Chapter 4.6
/// §4 makes `'complete'` *"gated server-side"*, so a success on step 3 is the
/// backend confirming — but BR-08 makes `complete` the point a chunk becomes
/// eligible for local deletion (Chapter 5.15), and deleting a chunk whose
/// metadata never reached the backend would be unrecoverable. Ordering the
/// local write after the metadata POST costs nothing and closes that window.
/// Recorded as amendment A-073.
class ChunkUploadPipeline {
  /// Creates a pipeline over its four collaborators.
  ChunkUploadPipeline({
    required ChunkUploadSource uploadSource,
    required ChunkMetadataSource metadataSource,
    required SessionRegistrar sessionRegistrar,
    required ChunkUploadApi uploadApi,
  }) : _source = uploadSource,
       _metadata = metadataSource,
       _registrar = sessionRegistrar,
       _api = uploadApi;

  final ChunkUploadSource _source;
  final ChunkMetadataSource _metadata;
  final SessionRegistrar _registrar;
  final ChunkUploadApi _api;

  /// Uploads the next queued chunk, or reports why it could not.
  ///
  /// Returns null when there was nothing to claim — an empty queue is not an
  /// outcome, and reporting one would make "idle" indistinguishable from
  /// "finished".
  ///
  /// Never throws for a failure of the upload itself: every failure path ends
  /// in a status write and an [UploadOutcome]. A `StorageException` raised
  /// while *recording* a failure is allowed to escape, because at that point
  /// the local database is not answering and there is nowhere left to record
  /// anything.
  Future<UploadOutcome?> uploadNext({
    ChunkUploadProgress? onProgress,
    Future<void>? cancelSignal,
  }) async {
    final UploadableChunk? chunk;
    try {
      chunk = await _source.claimNext();
    } on StorageException {
      // Nothing was claimed, so there is no chunk to mark failed. Reported
      // rather than swallowed: a dispatcher needs to know the difference
      // between "queue empty" and "storage unavailable".
      return const UploadOutcome.failed(
        chunkId: null,
        cause: UploadFailureCause.storageFailure,
        detail: 'The queue could not be read.',
      );
    }

    if (chunk == null) {
      return null;
    }

    return _run(chunk, onProgress: onProgress, cancelSignal: cancelSignal);
  }

  Future<UploadOutcome> _run(
    UploadableChunk chunk, {
    ChunkUploadProgress? onProgress,
    Future<void>? cancelSignal,
  }) async {
    // ---- Guard 1 -------------------------------------------------------
    // Before step 1, before any network call. A-068.
    final ChunkMetadataDocument? document;
    try {
      document = await _metadata.metadataDocument(chunk.chunkId);
    } on StorageException catch (error) {
      return _fail(chunk, UploadFailureCause.storageFailure, error.message);
    }

    if (document == null) {
      return _fail(
        chunk,
        UploadFailureCause.metadataMissing,
        'No metadata row exists for this chunk.',
      );
    }

    if (!document.isIdentityComplete) {
      // Ch. 2.9 §2 forbids a failure that does not name its cause, so the
      // missing fields are named individually rather than as "identity
      // incomplete".
      return _fail(
        chunk,
        UploadFailureCause.identityIncomplete,
        'The chunk cannot be attributed: '
        '${document.identity.missingFields.join(', ')} '
        '${document.identity.missingFields.length == 1 ? 'is' : 'are'} '
        'missing.',
      );
    }

    // ---- Step 1 — Register ---------------------------------------------
    final ChunkRegistration registration;
    try {
      final String remoteSessionId = await _registrar.remoteSessionId(
        chunk.sessionId,
      );
      registration = await _api.registerChunk(
        remoteSessionId: remoteSessionId,
        chunkId: chunk.chunkId,
        sequenceIndex: chunk.sequenceIndex,
        fileSizeBytes: chunk.fileSizeBytes,
        checksumSha256: chunk.checksumSha256,
      );
      await _source.recordObjectKey(
        chunkId: chunk.chunkId,
        s3ObjectKey: registration.s3ObjectKey,
      );
    } on AppException catch (error) {
      return _fail(chunk, _classify(error), error.message);
    }

    // ---- Step 2 — Upload, direct to S3 ---------------------------------
    try {
      await _api.uploadObject(
        registration: registration,
        localFilePath: chunk.localFilePath,
        fileSizeBytes: chunk.fileSizeBytes,
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      );
    } on NetworkException catch (error) {
      if (error.errorCode == ErrorCode.networkCancelled) {
        // Not a failure. Chapter 5.13 §1 does not list cancellation among its
        // failure types, so the chunk returns to `queued` and consumes none
        // of §2's six automatic attempts.
        await _source.release(chunk.chunkId);
        return UploadOutcome.cancelled(chunkId: chunk.chunkId);
      }
      return _fail(chunk, _classify(error), error.message);
    } on AppException catch (error) {
      return _fail(chunk, _classify(error), error.message);
    }

    // ---- Steps 3 and 4 — Confirm, then metadata ------------------------
    try {
      await _api.confirmStatus(
        chunkId: chunk.chunkId,
        status: ChunkUploadStatus.complete.wireName,
      );
      await _api.postMetadata(
        chunkId: chunk.chunkId,
        document: document.toJson(),
      );
    } on AppException catch (error) {
      return _fail(chunk, _classify(error), error.message);
    }

    // Step 5 is the backend's. The local row follows step 4 rather than step
    // 3 — see the class comment and A-073.
    await _source.markComplete(chunk.chunkId);
    return UploadOutcome.complete(chunkId: chunk.chunkId);
  }

  /// Records a failure and describes it.
  Future<UploadOutcome> _fail(
    UploadableChunk chunk,
    UploadFailureCause cause,
    String detail,
  ) async {
    await _source.markFailed(chunk.chunkId);
    return UploadOutcome.failed(
      chunkId: chunk.chunkId,
      cause: cause,
      detail: detail,
    );
  }

  /// Maps an exception onto Chapter 5.13 §1's classification.
  ///
  /// The chapter's own table, not a new vocabulary: a 4xx is *"Backend rejects
  /// … a repeated identical request would fail identically"* — terminal,
  /// server-side. A 5xx, a dropped connection or a timeout is transient. A
  /// local storage or file fault is terminal, device-side.
  static UploadFailureCause _classify(AppException error) {
    if (error is StorageException) {
      return UploadFailureCause.storageFailure;
    }
    if (error is! NetworkException) {
      // A ValidationException from SessionRegistrar — no task to register
      // under. Terminal: nothing about the stored row changes on a retry.
      return UploadFailureCause.sessionUnregisterable;
    }

    switch (error.errorCode) {
      case ErrorCode.storageNotFound:
      case ErrorCode.storageReadFailed:
        return UploadFailureCause.fileUnavailable;
      case ErrorCode.networkSerialization:
        return UploadFailureCause.malformedResponse;
      case ErrorCode.networkTimeout:
      case ErrorCode.networkUnavailable:
        return UploadFailureCause.transportFailure;
      default:
        break;
    }

    final int? status = error.statusCode;
    if (status != null && status >= NetworkConstants.internalServerError) {
      // "S3 5xx" — Chapter 5.13 §1's transient row, verbatim.
      return UploadFailureCause.transportFailure;
    }
    if (status != null && status >= NetworkConstants.clientErrorFloor) {
      return UploadFailureCause.rejectedByBackend;
    }
    return UploadFailureCause.transportFailure;
  }
}

/// What one run of [ChunkUploadPipeline] did.
///
/// Three outcomes, not two: **cancelled is not failed**. Chapter 5.13 §1's
/// table has no row for a deliberate pause, and collapsing it into `failed`
/// would consume one of §2's six automatic attempts every time a Collector
/// paused an upload.
class UploadOutcome {
  /// The chunk reached `complete` — all four steps succeeded.
  const UploadOutcome.complete({required this.chunkId})
    : cause = null,
      detail = null,
      isComplete = true,
      isCancelled = false;

  /// The chunk was released back to `queued` (FR-UPL-08).
  const UploadOutcome.cancelled({required this.chunkId})
    : cause = null,
      detail = null,
      isComplete = false,
      isCancelled = true;

  /// The chunk reached `failed`, for [cause].
  const UploadOutcome.failed({
    required this.chunkId,
    required this.cause,
    required this.detail,
  }) : isComplete = false,
       isCancelled = false;

  /// The chunk this describes, or null if none was ever claimed.
  final String? chunkId;

  /// Why it failed, or null if it did not.
  final UploadFailureCause? cause;

  /// A specific, human-readable reason — Chapter 2.9 §2's *"name the specific
  /// cause"*, in the form C-11 will render.
  final String? detail;

  /// Whether all four steps succeeded.
  final bool isComplete;

  /// Whether it stopped because it was asked to.
  final bool isCancelled;

  /// Whether Chapter 5.13 §2's automatic backoff applies to a retry.
  bool get isRetryable => cause?.isTransient ?? false;

  @override
  String toString() {
    if (isComplete) {
      return 'UploadOutcome.complete($chunkId)';
    }
    if (isCancelled) {
      return 'UploadOutcome.cancelled($chunkId)';
    }
    return 'UploadOutcome.failed($chunkId, ${cause?.name}: $detail)';
  }
}

/// The Vump backend, for `features/upload/`.
final Provider<VumpApi> vumpApiProvider = Provider<VumpApi>(
  (Ref ref) => VumpApi(client: ref.watch(dioClientProvider)),
);

/// Chapter 5.10 §1's four calls, wired to the real clients.
///
/// Real, not fake. The base URLs are still IANA-reserved `.example`
/// placeholders (ADR-007's own Implementation Status), so this throws a
/// `NetworkException` against any real invocation — which is the honest state
/// of the backend, and better than a fake that reports success. Volume 11's
/// M12 gate makes a fake wired into a build a defect in its own right; the
/// fakes live in `test/`.
final Provider<ChunkUploadApi> chunkUploadApiProvider =
    Provider<ChunkUploadApi>(
      (Ref ref) => ChunkUploadApiImpl(
        backend: ref.watch(vumpApiProvider),
        transfer: ref.watch(s3TransferClientProvider),
      ),
    );

/// Chapter 5.10's pipeline, ready to run one chunk.
final Provider<ChunkUploadPipeline> chunkUploadPipelineProvider =
    Provider<ChunkUploadPipeline>(
      (Ref ref) => ChunkUploadPipeline(
        uploadSource: ref.watch(chunkUploadSourceProvider),
        metadataSource: ref.watch(chunkMetadataSourceProvider),
        sessionRegistrar: ref.watch(sessionRegistrarProvider),
        uploadApi: ref.watch(chunkUploadApiProvider),
      ),
    );
