/// Produces the `chunk_id` that identifies one chunk for its whole life.
///
/// Volume 5 Chapter 5.14 §3 fixes the shape and the moment: *"a UUID generated
/// locally the moment a chunk begins finalizing — never reused, never
/// predictable, never assigned by a counter that could collide across
/// devices."*
///
/// ## Why this port exists rather than a `uuid` dependency
///
/// `uuid` is **not in this project's dependency tree at all** — not direct,
/// not transitive, confirmed against `pubspec.lock`. Adding it would be a full
/// ADR-030 admission: checklist, confinement entry, inventory row, conversion
/// boundary.
///
/// Inverting it costs one interface, and it is exactly what Mission 3.2 did
/// for `SessionIdGenerator` after the same check. The composition root
/// supplies both.
///
/// It also keeps the lifecycle deterministic under test: a fake returning
/// `chunk_0001` makes assertions about chunk identity readable, where a real
/// UUID would force every test to match a pattern.
///
/// ## Chapter 5.14 says "begins finalizing"; this project mints it at
/// capture-stop
///
/// The same instant, under Mission 3.4.5's design. "Begins finalizing" is the
/// moment `stopVideoRecording()` returns and the file is closed — which is now
/// also the moment capture restarts and the processing job is created. The
/// chapter's wording predates the split and is unaffected by it.
///
/// Minted once, never recomputed: Chapter 5.13 §4 requires every retry to
/// reuse *"the exact same `chunk_id`"*, so a value regenerated later would
/// break duplicate prevention (BR-11) by construction.
abstract interface class ChunkIdGenerator {
  /// Returns a fresh UUID for a chunk whose capture has just ended.
  String newChunkId();
}
