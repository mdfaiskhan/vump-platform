/// Supplies the credential `AuthInterceptor` attaches to outgoing requests.
///
/// **Declared by the layer that consumes it, implemented by the layer that
/// owns the session.** `AuthInterceptor` lives in `core/network/` and the token
/// comes from `features/auth/`; ADR-022 forbids `core/` importing a feature,
/// because a `core/` module that names one feature makes that feature
/// un-replaceable and stops being `core/`.
///
/// This is ADR-001's dependency inversion applied sideways. ADR-001 has
/// `domain/` declare the repository interface `data/` implements, so the
/// dependency points against the direction of control. The same move works
/// between `core/` and a feature: `core/network/` states its requirement as a
/// type it owns, `features/auth/data/` satisfies it, and the composition root
/// introduces the two. Nothing in `core/` learns the feature's name.
///
/// `core/storage/interfaces/secure_storage_repository.dart` is the existing
/// precedent for the shape and the location.
///
/// ## Contract
///
/// **Returning `null` and throwing mean different things, and the difference
/// is load-bearing.**
///
/// - **`null` — nobody is signed in.** The request goes out with no
///   `Authorization` header and the server decides. Volume 4 Chapter 4.8 §1
///   makes the backend *"the sole arbiter"* of what an identity may do, so the
///   interceptor does not invent a local authorization policy on top.
/// - **A throw — the token could not be determined.** The platform is down or
///   was never initialised. The request fails, because sending it
///   unauthenticated would report a local fault as a server 401.
///
/// Implementations throw `AuthenticationException` and never a provider-native
/// error, per error-handling.md §26's rule for `features/*/data/`.
abstract interface class AuthTokenSource {
  /// The credential for the current session, or `null` if there is none.
  ///
  /// Implementations may return a cached value. The Firebase client SDK
  /// refreshes an ID token before its ~1-hour expiry on its own (Volume 4
  /// Chapter 4.7 §3), so the common path costs nothing.
  Future<String?> currentToken();

  /// Forces a new credential after the current one was rejected.
  ///
  /// Returns `null` when the session cannot be renewed — a revoked or expired
  /// refresh token — which the caller treats as a failed refresh rather than
  /// as an anonymous request.
  ///
  /// Called at most once per request, and at most once at a time across all
  /// in-flight requests: `AuthInterceptor` holds the in-flight future so
  /// concurrent 401s share one refresh, per error-handling.md §16.
  Future<String?> refreshToken();
}
