import 'package:freezed_annotation/freezed_annotation.dart';

part 'chunk_integrity.freezed.dart';

/// What Volume 5 Chapter 5.5 produces for one finalized chunk.
///
/// Two facts, both from §1, and nothing else:
///
/// - **§1.2** — the SHA-256 hash, *"computed over the finalized file"*. This is
///   FR-META-10's *"compute and store an integrity checksum for every chunk at
///   creation time"*, and it is what the backend verifies against later
///   (FR-META-12, NFR-META-02).
/// - **§1.3** — the byte count, *"recorded (FR-META-06) directly from the
///   closed file handle, **never estimated**"*.
///
/// ## Where this gets stored is deliberately not decided here
///
/// Chapter 5.5 §4 defers that: *"Where the finalized file and its checksum are
/// recorded locally — Chapter 5.7 (Metadata Generation) and Chapter 5.8 (Local
/// Storage)."* Both are later sub-missions.
///
/// So this is a **value object, not a record**. It carries no id, no
/// session or sequence reference, no timestamp and no file path — every one of
/// those is a field whose shape 5.7 and 5.8 own, and inventing them here would
/// pre-empt decisions this chapter explicitly hands on. The caller already
/// knows which chunk it asked about.
///
/// ## The checksum is a lowercase hex string
///
/// Not bytes. It is written into a metadata JSON document (Volume 4 Chapter
/// 4.5 shows `"checksum_sha256": "..."`) and compared as text by the backend,
/// so text is the form it is used in at both ends. Storing bytes would mean
/// every consumer re-encoding it identically, which is a rule nothing enforces.
@freezed
class ChunkIntegrity with _$ChunkIntegrity {
  /// Creates an integrity result.
  const factory ChunkIntegrity({
    /// Lowercase hex SHA-256 of the finalized file — 64 characters.
    required String checksumSha256,

    /// The finalized file's size in bytes, read from the closed handle.
    required int byteCount,
  }) = _ChunkIntegrity;

  const ChunkIntegrity._();

  /// The digest length SHA-256 always produces, in hex characters.
  ///
  /// Named so the invariant is checkable by consumers rather than implied by
  /// a magic 64 scattered across 5.7 and the upload path.
  static const int checksumLength = 64;
}
