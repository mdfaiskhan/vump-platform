import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/features/auth/data/firebase_auth_token_source.dart';

/// `FirebaseAuthTokenSource` with a signed-in user.
///
/// Its sibling file covers the uninitialised-Firebase path, which needs no
/// fake because a test host has no Firebase. These are the paths that do: the
/// ones `AuthInterceptor` actually calls on every request (ADR-035).
///
/// The contract being pinned is the one the interceptor is written against —
/// **null means signed out, a throw means the token could not be determined**
/// — because the interceptor sends the request unauthenticated for the first
/// and fails it for the second.
void main() {
  FirebaseAuthTokenSource sourceFor(fb.User? user) =>
      FirebaseAuthTokenSource(firebaseAuth: _FakeAuth(user));

  group('signed in', () {
    test('currentToken returns the cached token', () async {
      // The common path: the SDK refreshes before expiry on its own (Volume 4
      // Ch. 4.7 §3), so this is a read rather than a round trip.
      final _FakeUser user = _FakeUser();

      expect(await sourceFor(user).currentToken(), 'token');
      expect(user.forcedRefreshes, 0, reason: 'no refresh was asked for');
    });

    test('refreshToken forces a round trip', () async {
      // `true` matters: without it the SDK returns the cached token the server
      // has just rejected, and the retry fails identically.
      final _FakeUser user = _FakeUser();

      expect(await sourceFor(user).refreshToken(), 'token');
      expect(user.forcedRefreshes, 1);
    });
  });

  group('signed out', () {
    test('currentToken is null, not an error', () async {
      // Nobody signed in is not a failure. The interceptor sends the request
      // without a credential and lets the backend decide.
      expect(await sourceFor(null).currentToken(), isNull);
    });

    test(
      'refreshToken is null, meaning the session cannot be renewed',
      () async {
        expect(await sourceFor(null).refreshToken(), isNull);
      },
    );
  });

  group('the SDK fails', () {
    test('a FirebaseAuthException is converted and mapped', () async {
      await expectLater(
        sourceFor(
          _FakeUser(throws: fb.FirebaseAuthException(code: 'user-disabled')),
        ).currentToken(),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authAccountDisabled,
          ),
        ),
      );
    });

    test('a revoked token maps to AUTH_SESSION_EXPIRED', () async {
      await expectLater(
        sourceFor(
          _FakeUser(
            throws: fb.FirebaseAuthException(code: 'user-token-expired'),
          ),
        ).refreshToken(),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authSessionExpired,
          ),
        ),
      );
    });

    test('an unexpected error still converts, via the catch-all', () async {
      // error-handling.md §7: the catch-all exists so a failure nobody
      // anticipated cannot escape untranslated into core/network.
      await expectLater(
        sourceFor(
          _FakeUser(throws: const FormatException('nonsense')),
        ).currentToken(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('no raw platform exception reaches the interceptor', () async {
      await expectLater(
        sourceFor(
          _FakeUser(throws: const FormatException('nonsense')),
        ).currentToken(),
        throwsA(isNot(isA<FormatException>())),
      );
    });
  });
}

class _FakeAuth implements fb.FirebaseAuth {
  _FakeAuth(this._user);

  final fb.User? _user;

  @override
  fb.User? get currentUser => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements fb.User {
  _FakeUser({this.throws});

  final Exception? throws;
  int forcedRefreshes = 0;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    final Exception? failure = throws;
    if (failure != null) {
      throw failure;
    }
    if (forceRefresh) {
      forcedRefreshes += 1;
    }
    return 'token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
