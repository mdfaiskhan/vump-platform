import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:mobile/app/config/app_environment.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/user.dart' as domain;

import 'fakes/fake_vump_api.dart';

import 'fakes/google_sign_in_fakes.dart';

/// The Google sign-in and sign-up paths of `AuthRepositoryImpl`.
///
/// These were the whole of the `features/auth/data` coverage shortfall after
/// Mission 2.8's audit: 47.5% of `auth_repository_impl.dart`, entirely in the
/// two flows that need a Google account and a Cloud Function.
///
/// The fakes are in `fakes/google_sign_in_fakes.dart` and model behaviour
/// rather than returning canned values — a cancellation raises the same
/// `GoogleSignInException` the SDK raises, which is the only way to prove the
/// mapping that separates it from a real failure.
void main() {
  const Map<String, dynamic> goodClaims = <String, dynamic>{
    'role': 'collector',
    // Retained so the claim shape stays realistic. It is no longer read:
    // A-177 removed the fallback and the backend is authoritative (ADR-048).
    'org_id': 'org-1',
  };

  late _CapturedLog log;

  setUp(() => log = _CapturedLog());

  AuthRepositoryImpl build({
    GoogleOutcome outcome = GoogleOutcome.succeeds,
    Map<String, dynamic>? claims = goodClaims,
    Exception? redemptionThrows,
    FakeGoogleSignIn? google,
    FakeFirebaseFunctions? functions,
    _FakeAuth? auth,
  }) {
    return AuthRepositoryImpl(
      backend: FakeVumpApi(orgId: 'org-1'),
      logger: AppLogger(environment: AppEnvironment.development, output: log),
      firebaseAuth: auth ?? _FakeAuth(_FakeUser(claims: claims)),
      googleSignIn: google ?? FakeGoogleSignIn(outcome: outcome),
      functions:
          functions ?? FakeFirebaseFunctions(throwsOnCall: redemptionThrows),
    );
  }

  group('signInWithGoogle succeeds', () {
    test('returns the provisioned user', () async {
      final domain.User user = await build().signInWithGoogle();

      expect(user.role, Role.collector);
      expect(user.orgId, 'org-1');
    });

    test('initialises the SDK before showing the picker', () async {
      // google_sign_in 7.x documents initialize as required first, and calling
      // it twice as undefined. The fake enforces the ordering rather than
      // tolerating it, so this would fail loudly if the await were dropped.
      final FakeGoogleSignIn google = FakeGoogleSignIn();

      await build(google: google).signInWithGoogle();

      expect(google.initializeCalls, 1);
      expect(google.authenticateCalls, 1);
    });

    test('two sign-ins share one initialisation', () async {
      // The in-flight future ADR-034 records. Two taps in quick succession
      // must not initialise twice.
      final FakeGoogleSignIn google = FakeGoogleSignIn();
      final AuthRepositoryImpl repository = build(google: google);

      await Future.wait<domain.User>(<Future<domain.User>>[
        repository.signInWithGoogle(),
        repository.signInWithGoogle(),
      ]);

      expect(google.initializeCalls, 1);
      expect(google.authenticateCalls, 2);
    });
  });

  group('signInWithGoogle is cancelled', () {
    test('maps to AUTH_SIGN_IN_CANCELLED, not a generic failure', () async {
      // The distinction Mission 2.2 built the mapper for: dismissing the
      // sheet is a deliberate act, and the UI stays silent for this code.
      await expectLater(
        build(outcome: GoogleOutcome.cancelled).signInWithGoogle(),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authSignInCancelled,
          ),
        ),
      );
    });

    test('no GoogleSignInException escapes the boundary', () async {
      await expectLater(
        build(outcome: GoogleOutcome.cancelled).signInWithGoogle(),
        throwsA(isNot(isA<GoogleSignInException>())),
      );
    });
  });

  group('signInWithGoogle fails in the SDK', () {
    test(
      'a provider configuration error does not read as a cancellation',
      () async {
        // The assertion that makes the fake worth having: same exception type,
        // different code, and the two must not collapse into one outcome.
        await expectLater(
          build(outcome: GoogleOutcome.errors).signInWithGoogle(),
          throwsA(
            isA<AuthenticationException>().having(
              (AuthenticationException e) => e.errorCode,
              'errorCode',
              isNot(ErrorCode.authSignInCancelled),
            ),
          ),
        );
      },
    );
  });

  group('signOut', () {
    test('signs out of Firebase and of Google', () async {
      // Firebase alone would leave the account selected, so the next sign-in
      // silently reuses it instead of showing the picker.
      final FakeGoogleSignIn google = FakeGoogleSignIn();
      final _FakeAuth auth = _FakeAuth(_FakeUser(claims: goodClaims));

      await build(google: google, auth: auth).signOut();

      expect(auth.signOutCalls, 1);
      expect(google.signOutCalls, 1);
    });
  });

  group('signUpWithGoogle', () {
    test('redeems the code, then returns the provisioned user', () async {
      final FakeFirebaseFunctions functions = FakeFirebaseFunctions();

      final domain.User user = await build(
        functions: functions,
      ).signUpWithGoogle(inviteCode: 'ABCDEFGHJK');

      expect(functions.calledNames, <String>['redeemInviteCode']);
      expect(functions.calledWith.single, <String, Object?>{
        'code': 'ABCDEFGHJK',
        'email': 'someone@example.com',
      });
      expect(user.orgId, 'org-1');
    });

    test('the token is refreshed so the new claims are readable', () async {
      // setCustomUserClaims writes on the server; the held token predates it.
      // Without the forced refresh, _toUser would reject the account it just
      // provisioned.
      final _FakeUser user = _FakeUser(claims: goodClaims);

      await build(auth: _FakeAuth(user)).signUpWithGoogle(inviteCode: 'CODE');

      expect(user.forcedRefreshes, 1);
    });

    test('a cancelled picker never reaches redemption', () async {
      // Ordering matters: a use must not be consumed for someone who backed
      // out before an account existed.
      final FakeFirebaseFunctions functions = FakeFirebaseFunctions();

      await expectLater(
        build(
          outcome: GoogleOutcome.cancelled,
          functions: functions,
        ).signUpWithGoogle(inviteCode: 'CODE'),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authSignInCancelled,
          ),
        ),
      );
      expect(functions.calledNames, isEmpty);
    });

    test('a rejected code maps through the functions mapper', () async {
      await expectLater(
        build(
          redemptionThrows: FirebaseFunctionsException(
            code: 'not-found',
            message: 'no such code',
            details: const <Object?, Object?>{
              'errorCode': 'AUTH_INVITE_CODE_INVALID',
            },
          ),
        ).signUpWithGoogle(inviteCode: 'BADCODE'),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authInviteCodeInvalid,
          ),
        ),
      );
    });

    test('a rejected code deletes the account it just created', () async {
      // The compensation ADR-036 records. Without it the address is held by
      // an account with no organisation that the person cannot use or reuse.
      final _FakeUser user = _FakeUser(claims: goodClaims);

      await expectLater(
        build(
          auth: _FakeAuth(user),
          redemptionThrows: FirebaseFunctionsException(
            code: 'not-found',
            message: 'no such code',
            details: const <Object?, Object?>{
              'errorCode': 'AUTH_INVITE_CODE_INVALID',
            },
          ),
        ).signUpWithGoogle(inviteCode: 'BADCODE'),
        throwsA(isA<AuthenticationException>()),
      );

      expect(user.deleteCalls, 1);
    });

    test('a failed cleanup still reports the redemption failure', () async {
      // The caller needs the reason they can act on, not the tidy-up problem.
      final _FakeUser user = _FakeUser(claims: goodClaims, deleteFails: true);

      await expectLater(
        build(
          auth: _FakeAuth(user),
          redemptionThrows: FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'expired',
            details: const <Object?, Object?>{
              'errorCode': 'AUTH_INVITE_CODE_EXPIRED',
            },
          ),
        ).signUpWithGoogle(inviteCode: 'OLDCODE'),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authInviteCodeExpired,
          ),
        ),
      );

      expect(user.deleteCalls, 1);
      // Not swallowed. error-handling.md §26 forbids silent absorption, and
      // an orphaned account is precisely what support needs told about.
      expect(log.lines, contains(contains('Could not remove the account')));
    });
  });

  group('signUpWithEmailPassword no longer creates before validating', () {
    // The F1 regression group. Mission 2.9 found that creating the account
    // first let an unauthenticated caller enumerate registered addresses: a
    // taken one failed differently from a free one. Validation is server-side
    // and first now, so the client attempts no local creation at all.

    test('redemption happens server-side, then the caller signs in', () async {
      final FakeFirebaseFunctions functions = FakeFirebaseFunctions();
      final _FakeAuth auth = _FakeAuth(_FakeUser(claims: goodClaims));

      final domain.User user = await build(functions: functions, auth: auth)
          .signUpWithEmailPassword(
            email: 'new@example.com',
            password: 'pw1234',
            inviteCode: 'ABCDEFGHJK',
          );

      expect(functions.calledWith.single, <String, Object?>{
        'code': 'ABCDEFGHJK',
        'email': 'new@example.com',
        'password': 'pw1234',
      });
      expect(
        auth.createUserCalls,
        0,
        reason: 'the function creates the account, not the client',
      );
      expect(auth.emailSignInCalls, 1, reason: 'sign in after provisioning');
      expect(user.orgId, 'org-1');
    });

    test('a rejected code creates nothing and deletes nothing', () async {
      // The fix stated as a property. Previously this path created an account,
      // failed redemption, then deleted it — and the create attempt was the
      // observable that leaked whether the address was already registered.
      final _FakeUser user = _FakeUser(claims: goodClaims);
      final _FakeAuth auth = _FakeAuth(user);

      await expectLater(
        build(
          auth: auth,
          redemptionThrows: FirebaseFunctionsException(
            code: 'not-found',
            message: 'no',
            details: const <Object?, Object?>{
              'errorCode': 'AUTH_INVITE_CODE_INVALID',
            },
          ),
        ).signUpWithEmailPassword(
          email: 'target@example.com',
          password: 'pw1234',
          inviteCode: 'BADCODE',
        ),
        throwsA(isA<AuthenticationException>()),
      );

      expect(auth.createUserCalls, 0, reason: 'nothing was created');
      expect(user.deleteCalls, 0, reason: 'so nothing had to be deleted');
      expect(auth.emailSignInCalls, 0, reason: 'and no session was opened');
    });

    test('no invite code omits the field entirely', () async {
      // A-056: an absent code means the default organisation. The field is
      // omitted rather than sent empty, so the function reads the intent
      // rather than inferring it from a blank string.
      final FakeFirebaseFunctions functions = FakeFirebaseFunctions();
      final _FakeAuth auth = _FakeAuth(_FakeUser(claims: goodClaims));

      await build(
        functions: functions,
        auth: auth,
      ).signUpWithEmailPassword(email: 'new@example.com', password: 'pw1234');

      expect(functions.calledWith.single, <String, Object?>{
        'email': 'new@example.com',
        'password': 'pw1234',
      });
      expect(auth.createUserCalls, 0, reason: 'still server-side');
    });

    test('a supplied code is still sent, unchanged by A-056', () async {
      final FakeFirebaseFunctions functions = FakeFirebaseFunctions();

      await build(functions: functions).signUpWithEmailPassword(
        email: 'new@example.com',
        password: 'pw1234',
        inviteCode: 'ABCDEFGHJK',
      );

      expect(
        (functions.calledWith.single! as Map<String, Object?>)['code'],
        'ABCDEFGHJK',
      );
    });

    test('signing up never yields an admin, code or no code', () async {
      // The property A-056 must not relax. The role comes from the claims the
      // function set; the client cannot ask for one. Asserted on both paths.
      for (final String? code in <String?>[null, 'ABCDEFGHJK']) {
        final domain.User user = await build().signUpWithEmailPassword(
          email: 'new@example.com',
          password: 'pw1234',
          inviteCode: code,
        );
        expect(user.role, Role.collector, reason: 'code=$code');
      }
    });

    test('a registered address is indistinguishable from a bad code', () async {
      // The oracle F1 described, asserted closed at this boundary. The server
      // reports AUTH_INVITE_CODE_INVALID for both, and the client does nothing
      // locally that could tell them apart.
      final _FakeAuth auth = _FakeAuth(_FakeUser(claims: goodClaims));

      await expectLater(
        build(
          auth: auth,
          redemptionThrows: FirebaseFunctionsException(
            code: 'not-found',
            message: 'address already registered',
            details: const <Object?, Object?>{
              'errorCode': 'AUTH_INVITE_CODE_INVALID',
            },
          ),
        ).signUpWithEmailPassword(
          email: 'registered@example.com',
          password: 'pw1234',
          inviteCode: 'GOODCODE12',
        ),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authInviteCodeInvalid,
          ),
        ),
      );

      expect(auth.createUserCalls, 0);
    });
  });
}

class _FakeAuth implements fb.FirebaseAuth {
  _FakeAuth(this._user);

  final fb.User? _user;
  int signOutCalls = 0;
  int createUserCalls = 0;
  int emailSignInCalls = 0;

  @override
  fb.User? get currentUser => _user;

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    emailSignInCalls += 1;
    return _FakeCredential(_user);
  }

  @override
  Future<fb.UserCredential> signInWithCredential(
    fb.AuthCredential credential,
  ) async => _FakeCredential(_user);

  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Still implemented so a regression that reintroduces client-side
    // creation is caught by the counter rather than by a crash.
    createUserCalls += 1;
    return _FakeCredential(_user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCredential implements fb.UserCredential {
  _FakeCredential(this._user);

  final fb.User? _user;

  @override
  fb.User? get user => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements fb.User {
  _FakeUser({required this.claims, this.deleteFails = false});

  final Map<String, dynamic>? claims;
  final bool deleteFails;

  int deleteCalls = 0;
  int forcedRefreshes = 0;

  @override
  String get uid => 'uid-1';

  @override
  String? get email => 'someone@example.com';

  @override
  bool get emailVerified => true;

  @override
  String? get displayName => null;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) {
      forcedRefreshes += 1;
    }
    return 'token';
  }

  @override
  Future<fb.IdTokenResult> getIdTokenResult([
    bool forceRefresh = false,
  ]) async => _FakeIdTokenResult(claims);

  @override
  Future<void> delete() async {
    deleteCalls += 1;
    if (deleteFails) {
      // Modelled because the repository logs rather than rethrows here, and
      // that behaviour is worth exercising.
      throw fb.FirebaseAuthException(code: 'requires-recent-login');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIdTokenResult implements fb.IdTokenResult {
  _FakeIdTokenResult(this.claims);

  @override
  final Map<String, dynamic>? claims;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Captures log output instead of printing it.
///
/// Two jobs: a test that exercises a logged failure should not print a stack
/// trace into a passing run, and the one assertion that the failure *was*
/// logged needs somewhere to read it from.
class _CapturedLog extends LogOutput {
  final List<String> lines = <String>[];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}
