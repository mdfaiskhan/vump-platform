import 'package:mobile/core/upload/metadata/chunk_metadata_document.dart';

/// Supplies Chapter 5.10 §1 step 4's metadata document for a chunk.
///
/// Separate from `ChunkUploadSource` because the two are read at different
/// moments and one of them is expensive. A claim happens per chunk and reads a
/// single row; the metadata document is seven embedded objects, and only the
/// last step and the guard need it. Bundling it onto `UploadableChunk` would
/// load it on every claim, including claims that fail at registration.
///
/// ## The read-back `ChunkRecordMapper` declined to write
///
/// `ChunkRecordMapper` states plainly that there is no `fromLocal*` and that
/// this is a decision: a reverse mapper *"would have to substitute empty
/// strings, and an empty `collector_id` that reached an upload would be
/// indistinguishable from a real one"*. It names the Upload Queue as the
/// consumer that would need one, and leaves it *"unwritten rather than written
/// wrong"*.
///
/// This contract is what makes it writable. It returns a
/// [ChunkMetadataDocument], whose identity fields are **nullable** — so
/// nothing is substituted, a stored blank stays blank, and
/// `isIdentityComplete` is what refuses it. The hazard that deferred the
/// mapper is answered rather than accepted.
abstract interface class ChunkMetadataSource {
  /// The stored metadata for [chunkId], or null if no row exists.
  ///
  /// Null should be unreachable: FR-META-09 requires the chunk and its
  /// metadata be written in one transaction, so *"a chunk file can never exist
  /// locally without its metadata already alongside it"*. It is reported
  /// rather than asserted because the guarantee is about what this application
  /// writes, not about what a corrupted or externally modified database
  /// contains — and a pipeline that crashed on the difference would lose the
  /// chunk instead of failing it with a cause.
  ///
  /// Throws a `StorageException` if the read fails.
  Future<ChunkMetadataDocument?> metadataDocument(String chunkId);
}
