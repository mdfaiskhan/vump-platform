import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/features/auth/data/firebase_auth_error_mapper.dart';

/// Tests for the `firebase_auth` conversion boundary's code mapping.
///
/// error-handling.md §28 requires "a test per mapped code" of every boundary,
/// and `mapCode` is static precisely so that is possible without a live
/// Firebase project — the same reason `ErrorInterceptor.mapToNetworkException`
/// is (§8).
///
/// **Several of these assert a relationship rather than a value.** The mapping
/// table is not the interesting part; the reasoning behind it is, and a test
/// that restates the table breaks whenever the table is legitimately edited
/// while catching nothing. Where a group of codes share an `ErrorCode` *for a
/// reason* — Firebase deprecating two spellings into one, an emulator
/// reporting the same condition differently — the test asserts they agree with
/// each other, so it survives a change to which `ErrorCode` they agree on and
/// still fails if they stop agreeing.
void main() {
  // The complete switch in `mapCode`, as data. Iterated rather than written
  // out as one test per code: 19 near-identical test bodies would obscure the
  // four that carry actual reasoning below.
  const Map<String, ErrorCode> documentedCodes = <String, ErrorCode>{
    'invalid-credential': ErrorCode.authInvalidCredentials,
    'INVALID_LOGIN_CREDENTIALS': ErrorCode.authInvalidCredentials,
    'wrong-password': ErrorCode.authInvalidCredentials,
    'user-not-found': ErrorCode.authInvalidCredentials,
    'invalid-password': ErrorCode.authInvalidCredentials,
    'invalid-email': ErrorCode.authInvalidCredentials,
    'custom-token-mismatch': ErrorCode.authInvalidCredentials,
    'invalid-custom-token': ErrorCode.authInvalidCredentials,
    'user-disabled': ErrorCode.authAccountDisabled,
    'user-token-expired': ErrorCode.authSessionExpired,
    'requires-recent-login': ErrorCode.authSessionExpired,
    'email-already-in-use': ErrorCode.authEmailAlreadyInUse,
    'credential-already-in-use': ErrorCode.authEmailAlreadyInUse,
    'account-exists-with-different-credential': ErrorCode.authEmailAlreadyInUse,
    'weak-password': ErrorCode.validationInvalidInput,
    'too-many-requests': ErrorCode.networkRateLimited,
    'quota-exceeded': ErrorCode.networkRateLimited,
    'network-request-failed': ErrorCode.networkUnavailable,
    'operation-not-allowed': ErrorCode.unknown,
  };

  group('the documented mapping', () {
    test('every code in the switch reaches the ErrorCode its arm names', () {
      for (final MapEntry<String, ErrorCode> entry in documentedCodes.entries) {
        expect(
          FirebaseAuthErrorMapper.mapCode(entry.key),
          entry.value,
          reason: '${entry.key} must map to ${entry.value.code}',
        );
      }
    });

    test('the table above still covers all 19 arms of the switch', () {
      // A tripwire, not a proof. Nothing can enumerate a switch's arms from
      // outside it, so this catches the table being shrunk without the count
      // being reconsidered — the one failure mode a table-driven test has
      // that a test-per-code does not.
      expect(documentedCodes, hasLength(19));
    });
  });

  group('codes Firebase deprecated', () {
    // The mapper's doc comment records that reading the package changed the
    // mapping: `wrong-password` and `user-not-found` are no longer returned by
    // a project created since September 2023. Firebase enables email
    // enumeration protection by default and collapses both into
    // `invalid-credential`, so that a caller cannot learn whether an account
    // exists. These assert that collapse, which is the security property —
    // not the particular ErrorCode all three land on.

    test('wrong-password is indistinguishable from invalid-credential', () {
      expect(
        FirebaseAuthErrorMapper.mapCode('wrong-password'),
        FirebaseAuthErrorMapper.mapCode('invalid-credential'),
      );
    });

    test('user-not-found is indistinguishable from invalid-credential', () {
      expect(
        FirebaseAuthErrorMapper.mapCode('user-not-found'),
        FirebaseAuthErrorMapper.mapCode('invalid-credential'),
      );
    });

    test(
      'a wrong password and an absent account are told apart by nothing',
      () {
        // Stated as one assertion because it is one guarantee. If these three
        // ever diverge, the application can distinguish "no such account" from
        // "wrong password", which is exactly what email enumeration protection
        // exists to prevent — and it would be a security regression reachable
        // without touching any code that looks security-related.
        expect(
          FirebaseAuthErrorMapper.mapCode('user-not-found'),
          FirebaseAuthErrorMapper.mapCode('wrong-password'),
        );
      },
    );
  });

  group('the Firebase emulator spelling', () {
    test('INVALID_LOGIN_CREDENTIALS agrees with invalid-credential', () {
      // The emulator reports the same condition in a different shape. Mapping
      // them together is what stops behaviour differing between the emulator
      // and a real project — a difference that would surface as a test passing
      // locally and the app misbehaving in production.
      expect(
        FirebaseAuthErrorMapper.mapCode('INVALID_LOGIN_CREDENTIALS'),
        FirebaseAuthErrorMapper.mapCode('invalid-credential'),
      );
    });

    test('it is an explicit arm, not case-insensitive matching', () {
      // If the switch were ever "fixed" to compare case-insensitively, the
      // assertion above would still pass while every other code silently
      // gained a second spelling. Matching is exact.
      expect(
        FirebaseAuthErrorMapper.mapCode('Invalid-Credential'),
        ErrorCode.unknown,
      );
      expect(
        FirebaseAuthErrorMapper.mapCode('USER-DISABLED'),
        ErrorCode.unknown,
      );
    });
  });

  group('an unrecognised code', () {
    test('falls back to unknown rather than throwing', () {
      // Totality is the guarantee: a Firebase SDK upgrade that introduces a
      // code must degrade to an unclassified failure, never to an
      // untranslated one escaping the boundary.
      expect(
        FirebaseAuthErrorMapper.mapCode('a-code-firebase-has-not-invented'),
        ErrorCode.unknown,
      );
    });

    test('the empty string is a code like any other', () {
      expect(FirebaseAuthErrorMapper.mapCode(''), ErrorCode.unknown);
    });
  });

  group('mappings that collide with the fallback', () {
    test('operation-not-allowed lands on unknown, and that is a gap', () {
      // This is a real mapping, not a fallthrough — the provider is not
      // enabled in the Firebase Console, which is a deployment fault.
      // ErrorCode has no configuration case (error-handling.md §13 describes
      // the category; the enum omits it), so the two are indistinguishable by
      // return value and this test cannot tell them apart either.
      //
      // Recorded here rather than glossed: when a configuration ErrorCode is
      // added, this assertion is the one that must change.
      expect(
        FirebaseAuthErrorMapper.mapCode('operation-not-allowed'),
        ErrorCode.unknown,
      );
      expect(
        FirebaseAuthErrorMapper.mapCode('operation-not-allowed'),
        FirebaseAuthErrorMapper.mapCode('an-unrecognised-code'),
      );
    });
  });

  group('codes that deliberately leave the AUTH_ group', () {
    // Two arms reach outside the authentication codes, and both were
    // judgement calls the mapper documents. Asserted so the reasoning is
    // visible at the point it would be undone.

    test('too-many-requests is a rate limit, not an auth failure', () {
      // Volume 8 §8.5 §2 makes Firebase's progressive delay the first line of
      // brute-force defence. The taxonomy has no auth-specific rate-limit
      // code, so the network one is reused.
      expect(
        FirebaseAuthErrorMapper.mapCode('too-many-requests'),
        ErrorCode.networkRateLimited,
      );
    });

    test('weak-password is a validation failure, not a credential one', () {
      // The password was rejected by the provider's own policy (Volume 8
      // §8.5 §1) before any identity was in question. Mapping it to
      // authInvalidCredentials would tell a user signing up that their
      // credentials were wrong, when they have none yet.
      expect(
        FirebaseAuthErrorMapper.mapCode('weak-password'),
        ErrorCode.validationInvalidInput,
      );
      expect(
        FirebaseAuthErrorMapper.mapCode('weak-password'),
        isNot(ErrorCode.authInvalidCredentials),
      );
    });
  });
}
