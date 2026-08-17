import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/network/interfaces/auth_token_source.dart';
import 'package:mobile/features/auth/data/firebase_auth_error_mapper.dart';

/// Supplies Firebase ID tokens to `core/network/`'s `AuthInterceptor`.
///
/// The `features/auth/` half of the inversion ADR-035 describes:
/// `core/network/` declares [AuthTokenSource] and this satisfies it, so the
/// interceptor reaches a Firebase token without `core/` importing a feature.
///
/// Volume 4 Chapter 4.7 §1 is the flow this implements — the app receives a
/// signed ID token and *"attaches it as a Bearer token on every backend
/// request"*.
///
/// ## Why the SDK is resolved lazily
///
/// `FirebaseAuth.instance` calls `Firebase.app()`, which throws
/// `FirebaseException(plugin: 'core', code: 'no-app')` when the platform never
/// initialised — a state ADR-017 deliberately tolerates in development.
/// Resolving it in a constructor would throw there, outside any guard, and put
/// a raw `FirebaseException` in front of a caller. Every resolution here
/// happens inside [_guard] instead.
class FirebaseAuthTokenSource implements AuthTokenSource {
  /// Creates a source over [firebaseAuth], defaulting to the SDK singleton.
  ///
  /// The instance is stored rather than resolved, so construction cannot fail.
  FirebaseAuthTokenSource({fb.FirebaseAuth? firebaseAuth})
    : _injected = firebaseAuth;

  final fb.FirebaseAuth? _injected;

  /// Resolved on each use, never in the constructor. Only called from [_guard].
  fb.FirebaseAuth get _auth => _injected ?? fb.FirebaseAuth.instance;

  @override
  Future<String?> currentToken() {
    return _guard(
      description: 'read the current credential',
      action: () async {
        // Not a failure. Nobody is signed in, and the interceptor sends the
        // request unauthenticated rather than refusing it locally.
        final fb.User? user = _auth.currentUser;
        if (user == null) {
          return null;
        }
        // The SDK refreshes an ID token before its ~1-hour expiry on its own
        // (Volume 4 Ch. 4.7 §3) — a cache read on the common path.
        return user.getIdToken();
      },
    );
  }

  @override
  Future<String?> refreshToken() {
    return _guard(
      description: 'renew the credential',
      action: () async {
        final fb.User? user = _auth.currentUser;
        if (user == null) {
          return null;
        }
        // `true` forces a round trip rather than returning the cached token the
        // server has just rejected. Returns null when the refresh token itself
        // is revoked or expired, which is a session that cannot be renewed.
        return user.getIdToken(true);
      },
    );
  }

  /// Runs [action], converting any failure into an `AuthenticationException`.
  ///
  /// [description] never carries a token or an email. `AuthenticationException`
  /// holds no credential, and an exception message is a log line waiting to
  /// happen.
  Future<T> _guard<T>({
    required String description,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on fb.FirebaseAuthException catch (error, stackTrace) {
      throw FirebaseAuthErrorMapper.toAuthenticationException(
        error,
        stackTrace,
        description: description,
      );
    } on fb.FirebaseException catch (error, stackTrace) {
      // The platform, not the product. `core/no-app` and `core/not-initialized`
      // both land here, and both mean startup tolerated a Firebase failure
      // (ADR-017) and something now needs it. Named explicitly so the message
      // says Firebase rather than reporting an unclassified auth failure.
      throw AuthenticationException(
        errorCode: ErrorCode.unknown,
        message:
            'Firebase is not initialised, so the application could not '
            '$description (firebase code: ${error.code}).',
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw AuthenticationException(
        errorCode: ErrorCode.unknown,
        message: 'The application could not $description.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
