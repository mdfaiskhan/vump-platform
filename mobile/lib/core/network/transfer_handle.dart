import 'package:dio/dio.dart';

/// Cancels an in-progress transfer, without exposing how.
///
/// Volume 5 Chapter 5.10 §4: *"Dio's cancellation tokens … allow an
/// in-progress upload to pause cleanly mid-multipart-transfer; resuming
/// re-uses the same upload ID and re-sends only the parts not yet acknowledged
/// by S3, rather than restarting from byte zero — this is the mechanism behind
/// NFR-REL-02's 'resumable after any interruption'."*
///
/// The chapter cites "ADR-004" for this. That is a Volume-side citation and
/// **not** this repository's ADR-004, which is GoRouter; the real record is
/// ADR-007 (network configuration). Amendment A-069 covers the collision
/// generally and open item 34 tracks the sweep.
///
/// ## Why this type exists
///
/// `dio` is confined to `core/network/` by the `Architecture boundaries` CI
/// job, so `features/upload/` cannot name `CancelToken`. This wraps one and
/// publishes only what a caller actually needs: cancel it, and ask whether it
/// was cancelled.
///
/// **This is the third instance of the same inversion.** ADR-035 had
/// `core/network/` declare `AuthTokenSource` for a feature to satisfy;
/// ADR-040 had `core/queue/` hold a contract between two features. Here
/// `core/network/` publishes a type that *stands in for* a third-party one, so
/// the package stays where ADR-007 put it. ADR-041 records it.
///
/// ## Cancelling is not failing
///
/// A cancelled transfer surfaces as `ErrorCode.networkCancelled`, which
/// Chapter 5.13 §1 does not list among its failure types at all — a paused
/// upload is not a failed one. The pipeline releases the chunk back to
/// `queued` rather than marking it `failed`, so a pause does not consume one
/// of §2's six automatic attempts.
///
/// ## Single use
///
/// A cancelled handle stays cancelled; `CancelToken` cannot be reset, and
/// pretending otherwise here would produce a handle that silently cancels the
/// next transfer the instant it starts. Resuming means a new handle.
class TransferHandle {
  /// Creates a handle over a fresh, uncancelled token.
  TransferHandle();

  final CancelToken _token = CancelToken();

  /// The wrapped token. **For `core/network/` only.**
  ///
  /// It is public because Dart has no package-private, and `@internal` is not
  /// available here: that annotation is only valid inside a package's private
  /// API — a `src/` directory — and this project does not use one.
  ///
  /// The confinement rule enforces what the annotation would have. A caller
  /// outside `core/network/` cannot *use* this value without naming
  /// `CancelToken`, which means importing `package:dio`, which the
  /// `Architecture boundaries` CI job fails. The guarantee is the same; it is
  /// checked in CI rather than by the analyzer.
  CancelToken get token => _token;

  /// Whether [cancel] has been called.
  bool get isCancelled => _token.isCancelled;

  /// Stops the transfer this handle was passed to.
  ///
  /// Idempotent — a second call is ignored rather than throwing, because the
  /// caller that cancels is often racing the one that completes and neither
  /// can know which won.
  ///
  /// [reason] is carried into the resulting error for diagnosis. It must not
  /// contain a URL: see `S3TransferClient` for why a presigned URL is a
  /// credential.
  void cancel([String? reason]) {
    if (_token.isCancelled) {
      return;
    }
    _token.cancel(reason);
  }
}
