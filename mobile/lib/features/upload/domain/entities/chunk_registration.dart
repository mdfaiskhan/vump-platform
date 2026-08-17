/// What Volume 4 Chapter 4.6 §5's chunk registration returns.
///
/// ```text
/// POST /v1/sessions/{id}/chunks
/// { "sequence_index": 3, "file_size_bytes": 512000000,
///   "checksum_sha256": "..." }
/// → 201
/// { "data": { "chunk_id": "uuid", "s3_object_key": "...",
///             "upload_urls": ["presigned-part-1", "..."] },
///   "error": null }
/// ```
///
/// ## The part count is the backend's decision, not this app's
///
/// [uploadUrls] arrives as a list whose length the Lambda chose. Volume 4
/// Chapter 4.10 §2 step 1 confirms it generates the set. So part size is
/// `fileSizeBytes / uploadUrls.length` — a runtime value, different per chunk,
/// which is one of the two reasons `NetworkConstants.uploadSendTimeout` cannot
/// be a compile-time duration.
///
/// ## Pure Dart, by requirement
///
/// ADR-022 permits `domain/` to import nothing outside itself but
/// `core/errors/`, so this names no `core/` type, no Dio type and no Freezed
/// annotation it does not need. It is small enough that hand-writing equality
/// costs less than a generated file.
class ChunkRegistration {
  /// Creates a registration result.
  const ChunkRegistration({
    required this.chunkId,
    required this.s3ObjectKey,
    required this.uploadUrls,
  });

  /// The chunk id the backend echoed.
  ///
  /// Expected to equal the id the client sent, since Chapter 5.14 §3 mints it
  /// locally *"the moment a chunk begins finalizing"* and Chapter 5.13 §4
  /// requires every retry reuse it. The pipeline compares the two rather than
  /// assuming, because a mismatch would mean the rest of the flow — the status
  /// PATCH and the metadata POST, both keyed by `{id}` — addressed a different
  /// chunk than the one whose bytes were uploaded.
  final String chunkId;

  /// The deterministic key from Chapter 5.14 §1, **computed by the Lambda**.
  final String s3ObjectKey;

  /// One presigned URL per multipart part, in part order.
  ///
  /// Each is a bearer credential: it carries its own SigV4 signature in the
  /// query string, so anyone holding it can write that part until it expires.
  /// Never logged — see `S3TransferClient.redactUrl`.
  final List<String> uploadUrls;

  /// Whether the backend returned anything to upload to.
  ///
  /// An empty list is a malformed response rather than a zero-part upload: a
  /// finalized chunk always has bytes, so there is always at least one part.
  bool get hasParts => uploadUrls.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChunkRegistration &&
          other.chunkId == chunkId &&
          other.s3ObjectKey == s3ObjectKey &&
          _sameUrls(other.uploadUrls);

  bool _sameUrls(List<String> other) {
    if (other.length != uploadUrls.length) {
      return false;
    }
    for (int i = 0; i < uploadUrls.length; i++) {
      if (other[i] != uploadUrls[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(chunkId, s3ObjectKey, Object.hashAll(uploadUrls));

  /// Names the chunk, its key and its part count — **never the URLs**.
  ///
  /// Printing the list would put every presigned signature into whatever log
  /// or test failure rendered this object.
  @override
  String toString() =>
      'ChunkRegistration($chunkId, key: $s3ObjectKey, '
      '${uploadUrls.length} parts)';
}
