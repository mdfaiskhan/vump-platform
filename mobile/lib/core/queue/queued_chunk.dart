import 'package:mobile/core/queue/chunk_upload_status.dart';

/// One row of Volume 5 Chapter 5.9's queue, as the queue needs to see it.
///
/// ## This is a projection, not either feature's model
///
/// It is deliberately **not** `features/recording/`'s `LocalChunk`. That class
/// is an Isar collection with a surrogate key, a file path, a checksum and a
/// soft-delete column, and exposing it would teach `features/upload/` the
/// recording feature's schema — the coupling ADR-022 R3 exists to prevent.
///
/// It is equally not an `features/upload/` entity, because
/// `features/recording/data/` has to produce it and may not import a sibling
/// feature either.
///
/// So it carries exactly what Chapter 5.9 §2's ordering and Chapter 2.7's
/// C-11 rendering need, and nothing else. Either side may change its own
/// storage or its own presentation without the other noticing.
///
/// ## `sessionStartedAt` is resolved before it gets here
///
/// Chapter 5.9 §2 orders the queue *"FIFO by session start time, then by
/// `sequence_index` within a session"*. That timestamp lives on the session
/// row, not the chunk row, and Isar has no joins — so the implementation
/// resolves it while reading and hands over a flat value.
///
/// The consequence is the point: the consumer sorts without knowing that
/// sessions and chunks are separate collections, or that there is a database
/// at all.
final class QueuedChunk implements Comparable<QueuedChunk> {
  /// Creates a queue row.
  const QueuedChunk({
    required this.chunkId,
    required this.sessionId,
    required this.sequenceIndex,
    required this.sessionStartedAt,
    required this.status,
    required this.fileSizeBytes,
  });

  /// The chunk's stable UUID (Ch. 5.14 §3).
  ///
  /// Chapter 5.13 §4 requires every retry to reuse *"the exact same
  /// `chunk_id`"*, so this is the identity a retry acts on.
  final String chunkId;

  /// The owning session's UUID.
  final String sessionId;

  /// Position within the session, zero-based (Ch. 5.6 §2).
  final int sequenceIndex;

  /// When the owning session started — the primary ordering key.
  final DateTime sessionStartedAt;

  /// Where this chunk currently sits in Chapter 5.9 §1's four states.
  final ChunkUploadStatus status;

  /// The finalized file's size, for C-11's progress rendering.
  final int fileSizeBytes;

  /// Chapter 5.9 §2's ordering, expressed once.
  ///
  /// **Session start time first, then sequence index.** The chapter gives the
  /// reason for each half: an earlier session's chunks *"are not starved by a
  /// later session's"*, and within one session chunks upload *"in recording
  /// order by default"*.
  ///
  /// ## Manual retry needs no position field, and that is why
  ///
  /// Chapter 5.9 §2 also requires that a manually retried chunk *"re-enters
  /// the queue at its original position, not pushed to the back"*. Because
  /// order is **derived** from two immutable facts — when the session started
  /// and where the chunk sits in it — a chunk moving from `failed` back to
  /// `queued` returns to exactly where it was. Nothing stores a position,
  /// so nothing can corrupt one.
  ///
  /// `chunkId` breaks the final tie so the order is total rather than merely
  /// consistent: two chunks could otherwise compare equal if a session id were
  /// ever reused, and an unstable sort would then reorder the list between
  /// emissions for no visible reason.
  @override
  int compareTo(QueuedChunk other) {
    final int bySession = sessionStartedAt.compareTo(other.sessionStartedAt);
    if (bySession != 0) {
      return bySession;
    }
    final int bySequence = sequenceIndex.compareTo(other.sequenceIndex);
    if (bySequence != 0) {
      return bySequence;
    }
    return chunkId.compareTo(other.chunkId);
  }

  @override
  bool operator ==(Object other) =>
      other is QueuedChunk &&
      other.chunkId == chunkId &&
      other.sessionId == sessionId &&
      other.sequenceIndex == sequenceIndex &&
      other.sessionStartedAt == sessionStartedAt &&
      other.status == status &&
      other.fileSizeBytes == fileSizeBytes;

  @override
  int get hashCode => Object.hash(
    chunkId,
    sessionId,
    sequenceIndex,
    sessionStartedAt,
    status,
    fileSizeBytes,
  );

  @override
  String toString() =>
      'QueuedChunk($chunkId, seq $sequenceIndex, ${status.wireName})';
}
