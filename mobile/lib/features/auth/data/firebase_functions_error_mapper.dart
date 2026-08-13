import 'package:cloud_functions/cloud_functions.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';

/// Converts `cloud_functions` failures into the application error taxonomy.
///
/// **TEMPORARY — retired with the function it maps, at Mission 6/7 (ADR-036).**
/// When redemption becomes a `/v1/...` route, its failures arrive as
/// `DioException` and `ErrorInterceptor` already maps those; this file is
/// deleted rather than ported.
///
/// ## Why this is a sibling of `FirebaseAuthErrorMapper` and not part of it
///
/// The two exceptions look alike — both extend `FirebaseException`, both carry
/// a `String code` — and mapping them together would be the obvious move. It
/// would also be wrong, because the two `code` fields are different kinds of
/// thing.
///
/// `FirebaseAuthException.code` is a large domain vocabulary
/// (`invalid-credential`, `user-disabled`) where the code *is* the meaning.
/// `FirebaseFunctionsException.code` is the fixed gRPC status set
/// (`not-found`, `failed-precondition`, `internal`) — deliberately generic,
/// and shared by every callable in existence. Feeding it to
/// `FirebaseAuthErrorMapper.mapCode` would silently return
/// [ErrorCode.unknown] for every failure, because none of those strings
/// appears in its switch.
///
/// The meaning lives in `details.errorCode` instead, which is where the
/// function puts an `ErrorCode` name from this application's own taxonomy.
abstract final class FirebaseFunctionsErrorMapper {
  /// Wraps [error] as an [AuthenticationException] in the taxonomy.
  static AuthenticationException toAuthenticationException(
    FirebaseFunctionsException error,
    StackTrace stackTrace, {
    required String description,
  }) {
    return AuthenticationException(
      errorCode: mapError(error),
      message:
          'The invite-code service could not $description '
          '(function code: ${error.code}).',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Reads the application [ErrorCode] the function reported.
  ///
  /// Prefers `details.errorCode`, which the function sets from this
  /// application's own taxonomy, and falls back to the gRPC status when the
  /// details are absent or malformed — which happens for failures the function
  /// never saw, such as the platform refusing the call before dispatch.
  static ErrorCode mapError(FirebaseFunctionsException error) {
    final ErrorCode? reported = _fromDetails(error.details);
    if (reported != null) {
      return reported;
    }

    return switch (error.code) {
      // The transport-level shapes a callable can fail with before the
      // function's own logic runs.
      'unauthenticated' => ErrorCode.authUnauthenticated,
      'permission-denied' => ErrorCode.authForbidden,
      'not-found' => ErrorCode.authInviteCodeInvalid,
      'failed-precondition' => ErrorCode.authInviteCodeInvalid,
      'invalid-argument' => ErrorCode.validationInvalidInput,
      'resource-exhausted' => ErrorCode.networkRateLimited,
      'deadline-exceeded' => ErrorCode.networkTimeout,
      'unavailable' => ErrorCode.networkUnavailable,
      _ => ErrorCode.unknown,
    };
  }

  /// Pulls an `ErrorCode` out of the function's `details` payload.
  ///
  /// Defensive about the shape on purpose: `details` is `dynamic`, crosses a
  /// platform channel, and is written by a separate deployable that can be
  /// rolled forward independently of this app. A malformed payload falls back
  /// rather than throwing inside an error path.
  static ErrorCode? _fromDetails(Object? details) {
    if (details is! Map<Object?, Object?>) {
      return null;
    }
    final Object? name = details['errorCode'];
    if (name is! String) {
      return null;
    }
    for (final ErrorCode code in ErrorCode.values) {
      if (code.code == name) {
        return code;
      }
    }
    return null;
  }
}
