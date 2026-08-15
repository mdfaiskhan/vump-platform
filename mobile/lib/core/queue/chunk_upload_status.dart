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

  /// Backend-confirmed.
  ///
  /// ## What actually writes this, corrected at Mission 4.5
  ///
  /// This doc used to say *"nothing writes this yet, and nothing should until
  /// the backend actually confirms"*. Mission 4.2 then wrote it, and the
  /// sentence was never updated — a contradiction Mission 4.5 found while
  /// tracing Chapter 5.15, whose file deletion keys off exactly this value.
  ///
  /// `ChunkUploadPipeline` writes it after Chapter 5.10 §1 **step 4**, not
  /// step 3, and that ordering is a deliberate divergence recorded as A-073:
  /// BR-08 makes `complete` the point a chunk becomes eligible for local
  /// deletion, and deleting a chunk whose metadata never reached the backend
  /// would be unrecoverable.
  ///
  /// ## The device does not observe `verified_at`
  ///
  /// Volume 4 Chapter 4.5's `verified_at` is set by the backend, and Chapter
  /// 4.6 §4 gates the status transition on it — so a successful
  /// `PATCH /v1/chunks/{id}/status` implies verification happened. But the
  /// device never reads `verified_at` back: Chapter 5.10 §1 step 5 has it
  /// observed *"via its next sync"*, and no sync mechanism exists.
  ///
  /// So this value means **the backend accepted the transition**, not *the
  /// device saw the verification*. Chapter 5.15's cleanup deletes the only
  /// local copy on the strength of it, which A-086 records as the assumption
  /// future backend work must honour.
  ///
  /// **No chunk has reached this state on a device.** `SessionRegistrar` has
  /// no implementation (open item 36), so the pipeline cannot run at all.
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
