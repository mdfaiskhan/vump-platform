import 'package:mobile/features/recording/domain/entities/recording_session.dart';

/// Performs the work of the `Finalizing` state, whatever that work turns out
/// to be.
///
/// Volume 5 Chapter 5.3 §3 defines the state by its contents: *"video is
/// finalized (Chapter 5.5), metadata is generated (Chapter 5.7), and the chunk
/// enters the Upload Queue (Chapter 5.9)."* All three chapters belong to later
/// sub-missions, so this is the seam between the state machine and them — the
/// lifecycle needs something to await before it can take the
/// `chunk persisted + queued (BR-07)` edge, and this is that something.
///
/// ## Why an interface here and not the use case Volume 3 names
///
/// Volume 3 Chapter 3.9 §4 traces a Stop through the layers and names
/// `FinalizeChunkUseCase` as *"the one place that knows a chunk must be
/// chunked, checksummed, and have its metadata generated together, atomically,
/// per FR-META-08"*. That class is the eventual implementation of this port;
/// it is not written here because its three collaborators do not exist yet.
///
/// Declaring the port now rather than later is what lets Chapter 5.3's machine
/// be finished and fully tested on its own, which is the whole reason the
/// chapter is separable from 5.4 and 5.5.
///
/// ## The contract is BR-07, and it is narrow on purpose
///
/// A returned future means the chunk is on disk **in full** and queued —
/// nothing weaker. BR-07: *"Every chunk shall be persisted to local storage
/// before any upload of that chunk begins"*, and Chapter 5.6 §1 restates it as
/// *"no chunk is ever uploaded 'live' while still recording."* The lifecycle
/// treats completion as permission to advance, so an implementation that
/// resolved early would let `Recording` for chunk N+1 begin over a chunk N
/// that is not yet safe.
abstract interface class ChunkFinalizer {
  /// Finalizes, records and enqueues one chunk.
  ///
  /// Throws an `AppException` if the chunk cannot be finalized. The lifecycle
  /// does not convert — this port is declared in `domain/` and its
  /// implementation lives in `data/`, which is the layer error-handling.md §26
  /// makes responsible for producing the taxonomy in the first place.
  Future<void> finalizeChunk({
    required RecordingSession session,
    required int sequenceIndex,
  });
}
