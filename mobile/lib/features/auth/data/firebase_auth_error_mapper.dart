import 'package:firebase_auth/firebase_auth.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';

/// Converts `firebase_auth` failures into the application error taxonomy.
///
/// **The conversion boundary for `firebase_auth`.** error-handling.md §7 gives
/// the rule this file exists to satisfy: a Firebase error is caught where it
/// arises and rethrown as an `AppException` subclass, so no layer above
/// `features/auth/data/` ever sees a `FirebaseAuthException`. The same
/// guarantee `DioClient` makes for `DioException` and `SecureStorageService`
/// makes for `PlatformException`.
///
/// **Static, so the mapping is testable without a live Firebase project.**
/// This is the shape error-handling.md §8 established for
/// `ErrorInterceptor.mapToNetworkException`, and §28 requires "a test per
/// mapped code" — which is only possible if the mapping is reachable without
/// authenticating against a real project.
///
/// ## The code strings were read, not recalled
///
/// Every string in [mapCode] was taken from the doc comments of
/// `firebase_auth 6.5.7` in the pub cache, not from memory. That check changed
/// the mapping in one way worth stating: **`wrong-password` and
/// `user-not-found` are deprecated and are not returned by a current project.**
/// Firebase enables email enumeration protection by default for projects
/// created since September 2023, and it collapses both into
/// `invalid-credential` precisely so a caller cannot learn whether an account
/// exists. A mapping written from memory would name the two dead codes and
/// miss the live one.
///
/// `INVALID_LOGIN_CREDENTIALS` is the same condition again, in the shape the
/// Firebase emulator reports it. It is mapped so behaviour does not change
/// between the emulator and a real project.
abstract final class FirebaseAuthErrorMapper {
  /// Wraps [error] as an [AuthenticationException] in the taxonomy.
  ///
  /// [description] names the operation that failed, for the log — "sign in
  /// with email and password", not "signInWithEmailPassword". [stackTrace] is
  /// the trace captured at the `catch`, so the record points at the origin
  /// rather than at the rethrow.
  ///
  /// ## Deliberate deviation, recorded at the deviation
  ///
  /// `cause` holds the original [FirebaseAuthException], which exposes `email`
  /// and `credential`. error-handling.md §7 requires `cause` to be passed at
  /// every boundary; `authentication_exception.dart` states that the type
  /// "carries no credential, token or identifier". Both cannot hold here.
  ///
  /// `cause` is passed, because dropping the origin error would leave a
  /// failure undiagnosable, and because §7's rule is unconditional. **The
  /// consequence is that `cause` must never be logged verbatim for this type**
  /// — `AppLogger` has no redaction for it today (ADR-027 declined defensive
  /// redaction). The generated `message` is safe on its own: it carries the
  /// Firebase code and nothing else.
  ///
  /// This conflict is not resolved here. It is recorded so it is findable.
  static AuthenticationException toAuthenticationException(
    FirebaseAuthException error,
    StackTrace stackTrace, {
    required String description,
  }) {
    return AuthenticationException(
      errorCode: mapCode(error.code),
      message:
          'Firebase Authentication could not $description '
          '(firebase code: ${error.code}).',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Maps a `FirebaseAuthException.code` onto the application's [ErrorCode].
  ///
  /// Total by construction: an unrecognised code returns [ErrorCode.unknown]
  /// rather than throwing, so a Firebase SDK upgrade that introduces a code
  /// degrades to an unclassified failure instead of an untranslated one.
  static ErrorCode mapCode(String code) {
    return switch (code) {
      // The live code for a rejected email/password pair. `wrong-password`
      // and `user-not-found` are the pre-2023 spellings, retained because a
      // project with email enumeration protection disabled still emits them.
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-password' ||
      'invalid-email' ||
      'custom-token-mismatch' ||
      'invalid-custom-token' => ErrorCode.authInvalidCredentials,

      // Volume 8 §8.5 §3: a departing user's account is disabled rather than
      // deleted, to preserve audit_log integrity. This is the code that
      // surfaces on their next sign-in attempt.
      'user-disabled' => ErrorCode.authAccountDisabled,

      // The refresh token is gone or stale. §10's behavioural distinction
      // applies: this means sign in again, not you may never do this.
      'user-token-expired' ||
      'requires-recent-login' => ErrorCode.authSessionExpired,

      // The address is taken. `account-exists-with-different-credential`
      // is the same collision reached through a federated provider.
      'email-already-in-use' ||
      'credential-already-in-use' ||
      'account-exists-with-different-credential' =>
        ErrorCode.authEmailAlreadyInUse,

      // Rejected before the request left the device, or by the provider's
      // own password policy (Volume 8 §8.5 §1 delegates that policy to
      // Firebase rather than reimplementing it).
      'weak-password' => ErrorCode.validationInvalidInput,

      // Volume 8 §8.5 §2 relies on Firebase's progressive delay as the first
      // line of defence against brute force. There is no auth-specific
      // rate-limit code in the taxonomy, so the network one is reused — see
      // the gap noted below.
      'too-many-requests' || 'quota-exceeded' => ErrorCode.networkRateLimited,

      'network-request-failed' => ErrorCode.networkUnavailable,

      // The provider is not enabled in the Firebase Console. A configuration
      // fault, not a user-facing failure — and the taxonomy has no
      // configuration code, so it degrades to unknown. See the gap below.
      'operation-not-allowed' => ErrorCode.unknown,

      _ => ErrorCode.unknown,
    };
  }
}
