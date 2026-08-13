import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/features/auth/data/firebase_auth_token_source.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';

/// Covers the ADR-017 development path: Firebase startup failed, the failure
/// was tolerated, and something now needs a token.
///
/// **These run with no Firebase project and no `Firebase.initializeApp`,
/// which is exactly the state under test.** `FirebaseAuth.instance` calls
/// `Firebase.app()`, which throws `FirebaseException(core/no-app)` — so the
/// test host reproduces the development failure for free, without a fake.
///
/// The mission required this path be verified rather than assumed. Tracing it
/// is what found the defect the first two tests now pin.
void main() {
  group('constructing with Firebase uninitialised', () {
    // The Mission 2.2 defect. Both classes resolved FirebaseAuth.instance in
    // their constructor initializer list, outside any guard, so merely
    // constructing them threw a raw FirebaseException — the precise leak
    // ADR-034 claims cannot happen. Resolution is lazy now.

    test('FirebaseAuthTokenSource can be constructed', () {
      expect(FirebaseAuthTokenSource.new, returnsNormally);
    });

    test('AuthRepositoryImpl can be constructed', () {
      expect(AuthRepositoryImpl.new, returnsNormally);
    });
  });

  group('reading a token with Firebase uninitialised', () {
    test(
      'currentToken throws AuthenticationException, not FirebaseException',
      () async {
        // The guarantee: no third-party error escapes features/auth/data/.
        // A raw FirebaseException here would be the boundary failing.
        await expectLater(
          FirebaseAuthTokenSource().currentToken(),
          throwsA(isA<AuthenticationException>()),
        );
      },
    );

    test('refreshToken throws AuthenticationException too', () async {
      await expectLater(
        FirebaseAuthTokenSource().refreshToken(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('no FirebaseException reaches the caller', () async {
      await expectLater(
        FirebaseAuthTokenSource().currentToken(),
        throwsA(isNot(isA<FirebaseException>())),
      );
    });

    test('the message names Firebase, not the credential', () async {
      // The one place a message is asserted rather than a code, and
      // deliberately: legibility of this failure is the requirement. A
      // developer whose machine has no Firebase must be told that, not shown
      // an unclassified auth error. Asserted loosely — a substring, not the
      // whole sentence — so a reword does not break it.
      try {
        await FirebaseAuthTokenSource().currentToken();
        fail('expected the call to throw');
      } on AuthenticationException catch (error) {
        expect(error.message, contains('Firebase is not initialised'));
        expect(error.message, contains('no-app'));
      }
    });
  });

  group('the repository fails the same way', () {
    test('restoreSession throws AuthenticationException', () async {
      await expectLater(
        AuthRepositoryImpl().restoreSession(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test(
      'sessionChanges yields unknown, then errors in the taxonomy',
      () async {
        // Session.unknown() is originated before Firebase is touched, so a
        // subscriber still sees it. The failure arrives as a stream error — and
        // a stream error crosses the boundary just as a thrown one does, which
        // is why subscribing is guarded.
        await expectLater(
          AuthRepositoryImpl().sessionChanges,
          emitsInOrder(<Matcher>[
            isA<Object>(),
            emitsError(isA<AuthenticationException>()),
          ]),
        );
      },
    );
  });
}
