/// Volume 5 Chapter 5.9 §1's four queue states.
///
/// The chapter is explicit that this vocabulary is shared rather than
/// reinvented: the states are *"identical to the backend's `chunks.status`
/// (Volume 4, Chapter 4.4) and the Chapter 2.8 status palette — the mobile
/// queue and the backend never invent two different vocabularies for the same
/// concept."*
///
/// That sentence is why this enum lives in `core/` rather than inside either
/// feature. `features/recording/` writes the value at finalization and
/// `features/upload/` reads it; if each owned its own spelling, the two would
/// drift and the chapter's rule would be satisfied only by discipline.
///
/// ## The wire spelling is the same string the database already stores
///
/// `ChunkRecordMapper.statusQueued` in `features/recording/data/` has written
/// `'queued'` into `local_chunks.status` since Mission 3.7, and rows produced
/// then are on real devices now. [wireName] therefore matches those strings
/// exactly rather than introducing a second encoding — a test pins the two
/// together so a rename in either place fails the build rather than silently
/// orphaning existing rows.
enum ChunkUploadStatus {
  /// Waiting to upload.
  ///
  /// Chapter 5.9 §1: entered when the chunk is finalized (Ch. 5.6/5.7), and
  /// held while there is no connectivity or while earlier chunks are ahead in
  /// line. This is the state BR-07 hands to the queue, and the only state
  /// this project currently writes.
  queued('queued'),

  /// Actively transferring.
  ///
  /// Entered when Chapter 5.11's Background Upload has claimed the chunk and
  /// Chapter 5.10's pipeline is running. **Nothing writes this yet** — no
  /// upload path exists.
  uploading('uploading'),

  /// Attempts exhausted for now.
  ///
  /// Chapter 5.13's retry strategy gives up on the current attempt and C-11
  /// surfaces the Retry Chunk action. **Nothing writes this yet.**
  failed('failed'),

  /// Backend-confirmed and checksum-verified.
  ///
  /// Volume 4 Chapter 4.5's `verified_at` is set and reflected back to the
  /// device. **Nothing writes this yet**, and nothing should until the
  /// backend actually confirms — BR-12 makes "complete" mean the data is safe
  /// in cloud storage, not merely that the device finished its part.
  complete('complete');

  const ChunkUploadStatus(this.wireName);

  /// The exact string stored in `local_chunks.status`.
  final String wireName;

  /// Resolves a stored string, or null if it matches no known state.
  ///
  /// Returns null rather than defaulting to [queued]: a row carrying an
  /// unrecognised status is a fact worth surfacing, and silently treating it
  /// as ready to upload would be the worst available guess.
  static ChunkUploadStatus? fromWireName(String? value) {
    for (final ChunkUploadStatus status in ChunkUploadStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return null;
  }

  /// Whether this chunk is waiting for a dispatcher to claim it.
  ///
  /// Chapter 5.9 §4: in manual upload mode chunks still enter [queued]
  /// exactly as they do automatically — *"the queue's own model is identical
  /// in both modes"* — and only the dispatcher's behaviour differs. So this
  /// asks about the chunk, never about the mode.
  bool get isClaimable => this == queued;

  /// Whether Chapter 5.9 §1's Retry Chunk action applies.
  bool get isRetryable => this == failed;
}
