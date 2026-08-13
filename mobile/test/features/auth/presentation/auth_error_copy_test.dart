import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/auth/presentation/auth_error_copy.dart';

/// The Chapter 2.9 copy table, asserted per arm.
///
/// `auth_error_copy.dart` read 100% line coverage before this file existed and
/// still had untested branches: several arms are grouped with `||`, and a
/// grouped arm counts as one line however many codes reach it. Line coverage
/// cannot see the difference, which is why §28's rule is "a test per mapped
/// code" and not "a covered line".
///
/// Volume 2 Chapter 2.9 §2 makes a generic message a defect rather than a
/// fallback, so the property worth pinning across every code is that the copy
/// is specific — and that the one code which must stay silent, does.
void main() {
  String copyFor(ErrorCode code) =>
      AuthErrorCopy.forFailure(Failure(code: code));

  group('every ErrorCode resolves to usable copy', () {
    test('no code produces an empty message except the silent one', () {
      // Exhaustive over the enum, so a code added later cannot quietly arrive
      // with no copy and fall through to the catch-all unnoticed.
      for (final ErrorCode code in ErrorCode.values) {
        if (code == ErrorCode.authSignInCancelled) {
          continue;
        }
        expect(
          copyFor(code),
          isNotEmpty,
          reason: '${code.code} has no message',
        );
      }
    });

    test('no code produces a generic "something went wrong"', () {
      // §2 calls that string a defect, not an acceptable fallback — including
      // for the fallback arm itself.
      for (final ErrorCode code in ErrorCode.values) {
        expect(
          copyFor(code).toLowerCase(),
          isNot(contains('something went wrong')),
          reason: code.code,
        );
      }
    });

    test('every message names an action, not just a cause', () {
      // §4.3: "every error state pairs a plain-language cause with a single,
      // specific recovery action — never an error with no action attached."
      // Checked by looking for an imperative the copy is built around.
      const List<String> actions = <String>[
        'try again',
        'check',
        'ask your organisation admin',
        'sign in',
        'wait',
      ];

      for (final ErrorCode code in ErrorCode.values) {
        if (code == ErrorCode.authSignInCancelled) {
          continue;
        }
        final String message = copyFor(code).toLowerCase();
        expect(
          actions.any(message.contains),
          isTrue,
          reason: '${code.code} states a cause with no action: "$message"',
        );
      }
    });
  });

  group('the arms grouped behind ||', () {
    // These are the ones line coverage reported as covered while only one code
    // in each group had ever been passed through.

    test('both session codes share the sign-in-again message', () {
      expect(
        copyFor(ErrorCode.authSessionExpired),
        copyFor(ErrorCode.authTokenRefreshFailed),
      );
      expect(copyFor(ErrorCode.authSessionExpired), contains('Sign in again'));
    });

    test('all three validation codes resolve, not just the first', () {
      // The gap Mission 2.8's audit found: VALIDATION_REQUIRED_FIELD and
      // VALIDATION_INVALID_FORMAT sit in a grouped arm and had never been
      // passed through it.
      expect(copyFor(ErrorCode.validationInvalidInput), isNotEmpty);
      expect(copyFor(ErrorCode.validationRequiredField), isNotEmpty);
      expect(copyFor(ErrorCode.validationInvalidFormat), isNotEmpty);
      expect(
        copyFor(ErrorCode.validationRequiredField),
        copyFor(ErrorCode.validationInvalidFormat),
      );
    });
  });

  group('codes whose copy carries a decision', () {
    test('invalid credentials does not reveal whether the account exists', () {
      // Firebase collapses wrong-password and user-not-found so a caller
      // cannot enumerate accounts (ADR-034). Copy that distinguished them
      // would undo that at the last step.
      final String message = copyFor(ErrorCode.authInvalidCredentials);

      expect(message, contains('do not match'));
      expect(message.toLowerCase(), isNot(contains('no account')));
      expect(message.toLowerCase(), isNot(contains('not registered')));
    });

    test('a rejected invite code reveals nothing about the address', () {
      // The sign-up half of the enumeration property, after Mission 2.10's
      // fix to F1. The server reports a registered address as an invalid
      // code, so this one string is what a caller sees either way — it must
      // not hint at an account.
      final String message = copyFor(
        ErrorCode.authInviteCodeInvalid,
      ).toLowerCase();

      expect(message, contains('invite code'));
      expect(message, isNot(contains('account')));
      expect(message, isNot(contains('already')));
      expect(message, isNot(contains('registered')));
      expect(message, isNot(contains('exists')));
    });

    test('a cancelled sign-in is silent, and reported as such', () {
      // Not a failure: the person dismissed the sheet deliberately. Both the
      // empty message and the isSilent flag say so, and the screen reads the
      // flag rather than testing for emptiness.
      expect(copyFor(ErrorCode.authSignInCancelled), isEmpty);
      expect(
        AuthErrorCopy.isSilent(
          const Failure(code: ErrorCode.authSignInCancelled),
        ),
        isTrue,
      );
    });

    test('no other code is silent', () {
      for (final ErrorCode code in ErrorCode.values) {
        if (code == ErrorCode.authSignInCancelled) {
          continue;
        }
        expect(
          AuthErrorCopy.isSilent(Failure(code: code)),
          isFalse,
          reason: '${code.code} would be swallowed',
        );
      }
    });

    test('the unmapped fallback blames this side, not the person', () {
      // Reached by an unmapped code and by the configuration gap ADR-034
      // records. Neither is the user's doing.
      final String message = copyFor(ErrorCode.storageCorrupted).toLowerCase();

      expect(message, contains('not working'));
      expect(message, isNot(contains('your password')));
    });
  });
}
