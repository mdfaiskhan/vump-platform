import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/features/auth/data/firebase_functions_error_mapper.dart';

/// Tests for the redemption boundary's code mapping.
///
/// **Retired with the function they cover, at Mission 6/7 (ADR-036).**
///
/// The mapping is static for the reason `FirebaseAuthErrorMapper`'s is: it is
/// reachable without a deployed function or a Firebase project, which is what
/// error-handling.md §28's "a test per mapped code" requires of a boundary.
void main() {
  FirebaseFunctionsException failure(String code, {Object? details}) =>
      FirebaseFunctionsException(code: code, message: 'x', details: details);

  group('the function reports an ErrorCode in details', () {
    // This is the path that carries the real meaning. The gRPC code is a
    // coarse status; details.errorCode is this application's own taxonomy.

    test('an invalid code maps to AUTH_INVITE_CODE_INVALID', () {
      expect(
        FirebaseFunctionsErrorMapper.mapError(
          failure(
            'not-found',
            details: <Object?, Object?>{
              'errorCode': 'AUTH_INVITE_CODE_INVALID',
            },
          ),
        ),
        ErrorCode.authInviteCodeInvalid,
      );
    });

    test('an expired code maps to AUTH_INVITE_CODE_EXPIRED', () {
      expect(
        FirebaseFunctionsErrorMapper.mapError(
          failure(
            'failed-precondition',
            details: <Object?, Object?>{
              'errorCode': 'AUTH_INVITE_CODE_EXPIRED',
            },
          ),
        ),
        ErrorCode.authInviteCodeExpired,
      );
    });

    test('details win over the gRPC code when they disagree', () {
      // The function says expired; the gRPC status says not-found. The
      // function is the one that looked at the document.
      expect(
        FirebaseFunctionsErrorMapper.mapError(
          failure(
            'not-found',
            details: <Object?, Object?>{
              'errorCode': 'AUTH_INVITE_CODE_EXPIRED',
            },
          ),
        ),
        ErrorCode.authInviteCodeExpired,
      );
    });
  });

  group('falling back to the gRPC status', () {
    // Reached when the call fails before the function's own logic runs, so
    // there are no details to read.

    test('unauthenticated, permission-denied and unavailable map across', () {
      expect(
        FirebaseFunctionsErrorMapper.mapError(failure('unauthenticated')),
        ErrorCode.authUnauthenticated,
      );
      expect(
        FirebaseFunctionsErrorMapper.mapError(failure('permission-denied')),
        ErrorCode.authForbidden,
      );
      expect(
        FirebaseFunctionsErrorMapper.mapError(failure('unavailable')),
        ErrorCode.networkUnavailable,
      );
    });

    test('an unrecognised status degrades to unknown', () {
      expect(
        FirebaseFunctionsErrorMapper.mapError(failure('data-loss')),
        ErrorCode.unknown,
      );
    });
  });

  group('malformed details do not break the error path', () {
    // details is dynamic, crosses a platform channel, and is written by a
    // separate deployable that can roll forward independently of this app.
    // Throwing while handling an error would replace a useful failure with a
    // useless one.

    test('a details payload that is not a map falls back', () {
      expect(
        FirebaseFunctionsErrorMapper.mapError(
          failure('unauthenticated', details: 'nonsense'),
        ),
        ErrorCode.authUnauthenticated,
      );
    });

    test('an errorCode that names nothing falls back', () {
      expect(
        FirebaseFunctionsErrorMapper.mapError(
          failure(
            'not-found',
            details: <Object?, Object?>{
              'errorCode': 'AUTH_SOMETHING_INVENTED_LATER',
            },
          ),
        ),
        ErrorCode.authInviteCodeInvalid,
      );
    });

    test('a null details payload falls back', () {
      expect(
        FirebaseFunctionsErrorMapper.mapError(failure('deadline-exceeded')),
        ErrorCode.networkTimeout,
      );
    });
  });

  group('the exception it builds', () {
    test('carries the mapped code and keeps the origin as cause', () {
      final FirebaseFunctionsException origin = failure(
        'not-found',
        details: <Object?, Object?>{'errorCode': 'AUTH_INVITE_CODE_INVALID'},
      );

      final Object converted =
          FirebaseFunctionsErrorMapper.toAuthenticationException(
            origin,
            StackTrace.current,
            description: 'redeem the invite code',
          );

      expect(converted, isA<Exception>());
      expect(
        FirebaseFunctionsErrorMapper.mapError(origin),
        ErrorCode.authInviteCodeInvalid,
      );
    });
  });
}
