/// Reports how much of a body has been sent.
///
/// Volume 5 Chapter 5.10 §2 requires that *"Dio's native upload-progress
/// callback … feeds directly into the per-chunk percentage shown on C-11
/// (Chapter 2.7) — no separate progress-tracking mechanism is built; the same
/// callback that drives the network call also drives the UI."*
///
/// **This typedef is how that callback reaches C-11 without Dio reaching it
/// too.** `dio` is confined to `core/network/`, so `features/upload/` cannot
/// name `ProgressCallback` — and widening the confinement to let it would
/// undo the property the rule protects. Declaring the shape here instead
/// costs one line and keeps the package where ADR-007 put it.
///
/// The signature is Dio's, deliberately: an adapter that reordered or renamed
/// the parameters would be a second thing to get wrong for no gain. What is
/// *not* Dio's is the type — nothing above `core/network/` learns which client
/// produced the numbers, so replacing Dio would not reach a single caller.
///
/// [totalBytes] is `-1` when the length is unknown, which is Dio's convention
/// and is why this is not `(int, int)` with a non-negative contract. A
/// consumer computing a percentage must check for it; every caller in this
/// project supplies a known length, because a chunk's size is stored on its
/// row before any upload begins.
typedef TransferProgress = void Function(int sentBytes, int totalBytes);
