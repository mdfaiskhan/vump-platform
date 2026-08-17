import 'package:mobile/features/upload/domain/entities/chunk_registration.dart';

/// Reports how much of a chunk part has been sent.
///
/// Volume 5 Chapter 5.10 §2's progress callback, declared as a bare function
/// type so this file imports nothing. `core/network/`'s `TransferProgress` has
/// the identical shape and is what `data/` adapts this to — but ADR-022
/// forbids `domain/` importing `core/`, and that rule is worth more than the
/// deduplication of one typedef.
typedef ChunkUploadProgress = void Function(int sentBytes, int totalBytes);

/// The four backend calls Volume 5 Chapter 5.10 §1 makes.
///
/// | Step | Call |
/// |---|---|
/// | 1 Register | `POST /v1/sessions/{id}/chunks` → presigned multipart URLs |
/// | 2 Upload | the parts, **direct to S3**, never through this backend |
/// | 3 Confirm | `PATCH /v1/chunks/{id}/status` |
/// | 4 Metadata | `POST /v1/chunks/{id}/metadata` |
///
/// ## Why this port names no `core/` type
///
/// ADR-022's domain-purity rule permits `domain/` exactly two `core/` imports,
/// `failure.dart` and `error_codes.dart`. So this file cannot name
/// `UploadableChunk`, `ChunkUploadStatus`, `ChunkMetadataDocument`,
/// `TransferHandle` or `TransferProgress` — and does not need to. It takes
/// primitives, one domain entity, a bare function type and a plain `Future`.
/// `features/upload/data/` is where those adapt to the `core/` types, which
/// ADR-022 permits.
///
/// The alternative was widening ADR-022's exception list, which would be an
/// architectural change requiring its own ADR for a convenience this design
/// does not need.
///
/// ## Cancellation is a `Future`, not a token
///
/// `cancelSignal` completing means stop. That is the whole contract, it needs
/// no type, and `data/` wires it to `core/network/`'s `TransferHandle` in one
/// line. Chapter 5.10 §4's *"pause cleanly mid-multipart-transfer"* is what it
/// serves; §4's cited "ADR-004" is a Volume-side citation collision and the
/// real record is ADR-007 (A-069, open item 34).
///
/// A cancelled transfer is **not** a failure. Chapter 5.13 §1 does not list
/// cancellation among its failure types, so the pipeline releases the chunk
/// back to `queued` rather than consuming one of §2's six attempts.
abstract interface class ChunkUploadApi {
  /// Step 1. Registers a finalized chunk and gets somewhere to put it.
  ///
  /// [remoteSessionId] is the backend's session id, not the local UUID —
  /// `SessionRegistrar` is what produces it.
  ///
  /// The request body is exactly Chapter 4.6 §5's three fields. It carries no
  /// `org_id`, `project_id` or `task_id`: the Lambda composes the S3 key
  /// itself (Volume 4 Chapter 4.10 §2) and returns it.
  ///
  /// Safe to repeat. Chapter 5.10 §3: registration *"always returns the same
  /// deterministic S3 key for a given `chunk_id`"*, so a retry after a dropped
  /// response is not a duplicate.
  ///
  /// Throws a `NetworkException`.
  Future<ChunkRegistration> registerChunk({
    required String remoteSessionId,
    required String chunkId,
    required int sequenceIndex,
    required int fileSizeBytes,
    required String checksumSha256,
  });

  /// Step 2. Streams the file at [localFilePath] to S3 in parts.
  ///
  /// **Does not pass through the Vump backend.** Volume 4 Chapter 4.10 §2:
  /// the parts go *"directly to S3 using those presigned URLs — the mobile app
  /// never holds a raw AWS credential"*, and no Vump credential is attached
  /// either, since S3 rejects a presigned request carrying a conflicting
  /// `Authorization` header.
  ///
  /// Splits the file into `registration.uploadUrls.length` parts — the count
  /// the backend chose — and re-`PUT`s are safe: Chapter 5.10 §3 notes S3
  /// *"overwrites that part rather than duplicating it"*.
  ///
  /// [onProgress] reports cumulative bytes across the whole chunk, not per
  /// part, because that is what C-11's percentage means.
  ///
  /// Throws a `NetworkException`, with `ErrorCode.networkCancelled` when
  /// [cancelSignal] completed first.
  Future<void> uploadObject({
    required ChunkRegistration registration,
    required String localFilePath,
    required int fileSizeBytes,
    ChunkUploadProgress? onProgress,
    Future<void>? cancelSignal,
  });

  /// Step 3. `PATCH /v1/chunks/{id}/status`.
  ///
  /// [status] is the wire vocabulary Volume 4 Chapter 4.4 fixes and
  /// `ChunkUploadStatus.wireName` produces — passed as a string because
  /// `domain/` may not name that `core/` type. `data/` does not reinterpret
  /// it.
  ///
  /// Idempotent by Chapter 5.10 §3: *"PATCH .../status to 'complete' is a
  /// no-op if the chunk is already Complete."*
  ///
  /// Throws a `NetworkException`.
  Future<void> confirmStatus({required String chunkId, required String status});

  /// Step 4. `POST /v1/chunks/{id}/metadata` — Chapter 4.5 §2's object.
  ///
  /// [document] is that JSON, already shaped. Taking a map rather than a typed
  /// object is what keeps this file free of a `core/` import; the type exists
  /// and is `ChunkMetadataDocument`, one layer out.
  ///
  /// Sent *"as-is"* (Chapter 5.10 §1 step 4) and never recomputed — Chapter
  /// 5.7 §4 requires the identical object on every retry, *"since
  /// `capture_conditions` like battery % and GPS are only meaningful as of the
  /// actual capture moment"*.
  ///
  /// Throws a `NetworkException`.
  Future<void> postMetadata({
    required String chunkId,
    required Map<String, Object?> document,
  });
}
