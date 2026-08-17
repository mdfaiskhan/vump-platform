/// Opens the capture pipeline for a session, and drives one chunk at a time.
///
/// Volume 5 Chapter 5.4 §1's stages — encoder, muxer, buffered writer,
/// filesystem — sit behind this port rather than in front of it. **They are
/// CameraX's `Recorder` internals, not this project's code**; amendment A-058
/// records why, and what that costs in verifiability.
///
/// ## The zoom factor is applied here, once
///
/// [openSession] is the only place it is set. Volume 5.2 §1: the factor is
/// *"selected once at session start via Chapter 5.1's capability ladder; fixed
/// for the whole session, never changed mid-recording."* Chunk boundaries
/// reuse the same open session, so nothing re-applies it per chunk.
///
/// ## What this port deliberately does not do
///
/// It does not name a file path, compute a checksum, or write a metadata
/// record — Chapters 5.14, 5.5 and 5.7 own those, and none of them exists yet.
/// [stopChunk] returns the path the platform wrote to and stops there.
abstract interface class RecordingPipeline {
  /// Opens the camera for a session and locks the wide-angle factor.
  ///
  /// [zoomFactor] is the ladder's verdict — 0.5 or 0.6 — already decided by
  /// the Checklist. Throws a `DeviceException` if the camera cannot be opened
  /// or configured.
  Future<void> openSession({required double zoomFactor});

  /// Begins capturing one chunk.
  Future<void> startChunk();

  /// Ends the current chunk and returns the file the platform wrote.
  Future<String> stopChunk();

  /// Releases the camera at the end of a session.
  Future<void> closeSession();

  /// The directory chunks are being written to, for the free-space check.
  ///
  /// Null before [openSession]. Free space is a property of a volume, and this
  /// is the volume that matters.
  String? get outputDirectory;
}
