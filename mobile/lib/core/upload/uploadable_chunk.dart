import 'package:mobile/core/queue/queued_chunk.dart';

/// A chunk claimed for Volume 5 Chapter 5.10's pipeline, with what it needs to
/// run.
///
/// ## Why this is not [QueuedChunk] widened
///
/// ADR-040's argument for `QueuedChunk` is that a contract carrying the
/// storage type would relocate the coupling rather than remove it, so the
/// projection carries only what its audience needs. C-11 renders a status
/// pill, a percentage and a retry button; it has no use for a file path or a
/// checksum, and giving it those would make the queue's contract a
/// pass-through to `local_chunks` by degrees.
///
/// The pipeline's needs are genuinely different. It has to open a file, state
/// a byte count and a checksum at registration (Volume 4 Chapter 4.6 §5), and
/// remember the key the backend returned. Three of those six fields are ones
/// `QueuedChunk` withholds on purpose.
///
/// So: two audiences, two projections, one owner. The same rows back both, and
/// `IsarChunkStore` implements both contracts.
///
/// ## What it still does not carry
///
/// No metadata. Chapter 5.10 §1 step 4 posts Chapter 4.5's document, which is
/// a separate contract (`ChunkMetadataSource`) for the same reason this is
/// separate from `QueuedChunk` — a different consumer needing a different
/// shape. Bundling it here would make every claim load a metadata row that
/// only the last step reads.
///
/// No attempt counter, no backoff deadline, no `uploadId`. Chapter 5.10 §5
/// defers failure handling to Chapter 5.13 and backgrounding to Chapter 5.11;
/// fields for those belong to the missions that build them.
class UploadableChunk implements Comparable<UploadableChunk> {
  /// Creates a claimed chunk.
  const UploadableChunk({
    required this.chunkId,
    required this.sessionId,
    this.taskId,
    required this.sequenceIndex,
    required this.sessionStartedAt,
    required this.localFilePath,
    required this.fileSizeBytes,
    required this.checksumSha256,
    this.s3ObjectKey,
    this.attemptCount = 0,
  });

  /// The chunk's UUID, minted at capture-stop and never regenerated.
  ///
  /// Chapter 5.13 §4: every retry reuses *"the exact same `chunk_id`"*, which
  /// is what makes BR-11's no-duplicate guarantee structural.
  final String chunkId;

  /// The owning session's local UUID.
  ///
  /// **Not the backend's session id.** Chapter 5.10 §1 step 1's URL needs that
  /// one, and `SessionRegistrar` is what turns this into it.
  final String sessionId;

  /// The Task the session records against — Mission 7.4, F17 and B3.
  ///
  /// ## Why it rides on the claim as well as on the queue
  ///
  /// F17 put `taskId` on `QueuedChunk`, which is the **watch** view C-11
  /// renders. `ChunkUploadPipeline` consumes this type, from `claimNext`, and
  /// `SessionRegistrar` needs the Task to call
  /// `POST /v1/tasks/{taskId}/sessions`. The field was on the view nobody
  /// uploads from, so the pipe existed and led nowhere.
  ///
  /// Both views read it from the same `LocalSession` row, which is where Task
  /// context is durable (F38) — so this survives every process death between
  /// the recording and the upload, which may be days.
  ///
  /// ## Nullable, and the null is terminal rather than a defect
  ///
  /// Null for every session recorded before Mission 7.4 step 5, and for any
  /// session started without a Task selected. `SessionRegistrar` throws a
  /// `ValidationException` on it, which Chapter 5.13 §1 classes as **terminal
  /// and device-side** — surfaced immediately, never retried, because nothing
  /// about the stored row will change. Substituting a placeholder is the
  /// mistake `ChunkRecordMapper` refused: an invented Task id would upload
  /// real footage against somebody else's work.
  final String? taskId;

  /// Zero-based order within the session — Chapter 4.6 §5's `sequence_index`.
  final int sequenceIndex;

  /// When the session began, for Chapter 5.9 §2's ordering.
  ///
  /// Carried even though the source already orders claims by it, so a caller
  /// holding several chunks can reproduce the same order without asking again.
  final DateTime sessionStartedAt;

  /// Where the finalized `.mp4` is — Chapter 5.8 §2's layout.
  final String localFilePath;

  /// Chapter 4.6 §5's `file_size_bytes`, from Mission 3.4's `ChunkIntegrity`.
  final int fileSizeBytes;

  /// Chapter 4.6 §5's `checksum_sha256`, computed at finalization.
  ///
  /// Sent at registration so the backend can verify the uploaded object
  /// against it (Chapter 4.5 §3 step 3, FR-META-12) before allowing
  /// `complete`. Never recomputed here — Chapter 5.7 §4 requires the same
  /// values be resent on every retry.
  final String checksumSha256;

  /// The key the backend returned at registration, or null before it has.
  ///
  /// **Received, not composed.** Volume 4 Chapter 4.10 §2 step 1: *"the Lambda
  /// computes the deterministic key (Volume 5.14) and returns"* it. Chapter
  /// 5.14 §1's pattern is authoritative for both sides, but the client's use
  /// of it is §2's *local* path, which omits org/project/task entirely.
  ///
  /// Non-null on a chunk whose registration already succeeded — a resumed
  /// attempt after a dropped response, where re-registering is safe (§3) but
  /// unnecessary.
  final String? s3ObjectKey;

  /// How many automatic attempts this chunk has already consumed.
  ///
  /// Chapter 5.13 §2 allows *"up to 6 automatic attempts per chunk"*, and this
  /// is what the dispatcher counts against that budget. Zero for a chunk that
  /// has never been attempted, and reset to zero by FR-UPL-07's manual retry
  /// — §3 makes that reset explicit: tapping Retry Chunk *"resets the attempt
  /// counter and immediately tries again"*.
  ///
  /// Persisted rather than held in memory, so the budget survives the app
  /// being killed. NFR-REL-04 already requires the queue itself to, and a
  /// counter that reset on relaunch would silently grant six fresh attempts
  /// after every restart — which on a crash-looping device is an unbounded
  /// retry loop wearing a bounded one's clothes.
  final int attemptCount;

  /// Chapter 5.9 §2's order, identical to [QueuedChunk.compareTo].
  ///
  /// Session start time, then sequence index, then chunk id. The last is a
  /// tiebreak that makes the order total, so a re-sort cannot reorder two rows
  /// that compare equal. Status is not part of it — that is what lets a
  /// retried chunk return to its original position.
  @override
  int compareTo(UploadableChunk other) {
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

  /// A copy carrying [key] as its [s3ObjectKey].
  ///
  /// Used once, after registration returns, so the later steps work from one
  /// object rather than a chunk plus a loose string.
  UploadableChunk withObjectKey(String key) => UploadableChunk(
    chunkId: chunkId,
    sessionId: sessionId,
    sequenceIndex: sequenceIndex,
    sessionStartedAt: sessionStartedAt,
    localFilePath: localFilePath,
    fileSizeBytes: fileSizeBytes,
    checksumSha256: checksumSha256,
    s3ObjectKey: key,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadableChunk &&
          other.chunkId == chunkId &&
          other.sessionId == sessionId &&
          other.sequenceIndex == sequenceIndex &&
          other.sessionStartedAt == sessionStartedAt &&
          other.localFilePath == localFilePath &&
          other.fileSizeBytes == fileSizeBytes &&
          other.checksumSha256 == checksumSha256 &&
          other.s3ObjectKey == s3ObjectKey;

  @override
  int get hashCode => Object.hash(
    chunkId,
    sessionId,
    sequenceIndex,
    sessionStartedAt,
    localFilePath,
    fileSizeBytes,
    checksumSha256,
    s3ObjectKey,
  );

  /// Names the chunk, its position and its size — never its checksum or path.
  ///
  /// Read in log lines. The path is omitted because it is long and adds
  /// nothing a session id and sequence index do not already say.
  @override
  String toString() =>
      'UploadableChunk($chunkId, session: $sessionId, '
      'seq: $sequenceIndex, $fileSizeBytes bytes)';
}
