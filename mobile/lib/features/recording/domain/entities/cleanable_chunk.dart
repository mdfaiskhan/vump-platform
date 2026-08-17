/// A chunk whose local file Volume 5 Chapter 5.15 §2 allows to be deleted.
///
/// Produced by `ChunkStore.cleanableChunks`, which applies §2's eligibility
/// rule; this type carries only what deleting the file needs. It deliberately
/// does not carry the status — a chunk that reached this list already
/// satisfied the rule, and re-checking it in the caller would put the same
/// decision in two places.
///
/// ## `fileSizeBytes` is the recorded size, not a fresh `stat`
///
/// It is what the row said when the chunk was finalized, so a sweep can report
/// how much space it reclaimed without a second filesystem round-trip per
/// file. If the file on disk has since changed size — which nothing in this
/// application does — the reported figure is the recorded one. It is a
/// diagnostic number, not an accounting one.
final class CleanableChunk {
  /// Creates an eligible chunk.
  const CleanableChunk({
    required this.chunkId,
    required this.localFilePath,
    required this.fileSizeBytes,
  });

  /// The chunk's stable UUID (Ch. 5.14 §3).
  final String chunkId;

  /// Where the `.mp4` is, per Chapter 5.14 §2's layout.
  final String localFilePath;

  /// The size recorded at finalization.
  final int fileSizeBytes;

  @override
  String toString() => 'CleanableChunk($chunkId, $fileSizeBytes bytes)';
}
