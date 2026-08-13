import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/config/app_environment.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart' as domain;

/// Claim reading, which is the authorization-relevant part of this class.
///
/// `_toUser` decides what role and organisation a signed-in account has, from
/// the custom claims Volume 4 Chapter 4.7 §2 puts in the signed token. Getting
/// it wrong grants an identity nobody provisioned, so its refusals matter more
/// than its successes and are tested first.
///
/// Reached through `restoreSession`, which is the shortest public path to it.
/// The Firebase types are faked with `implements` plus `noSuchMethod` — they
/// have private constructors so they cannot be extended, and `mocktail` is not
/// a dependency (A-028). testing-standards.md §8 asks for fakes anyway.
void main() {
  AuthRepositoryImpl repositoryFor(Map<String, dynamic>? claims) {
    return AuthRepositoryImpl(
      logger: AppLogger(environment: AppEnvironment.production),
      firebaseAuth: _FakeFirebaseAuth(_FakeUser(claims: claims)),
    );
  }

  group('a fully provisioned account', () {
    test('maps both claims onto the domain user', () async {
      final Session session = await repositoryFor(<String, dynamic>{
        'role': 'collector',
        'org_id': 'org-42',
      }).restoreSession();

      final SessionAuthenticated authenticated =
          session as SessionAuthenticated;
      expect(authenticated.user.role, Role.collector);
      expect(authenticated.user.orgId, 'org-42');
      expect(authenticated.user.uid, 'uid-1');
      expect(authenticated.user.email, 'someone@example.com');
    });

    test('admin is recognised as distinct from collector', () async {
      final Session session = await repositoryFor(<String, dynamic>{
        'role': 'admin',
        'org_id': 'org-42',
      }).restoreSession();

      expect((session as SessionAuthenticated).user.role, Role.admin);
    });
  });

  group('an account the claims do not provision', () {
    // Every one of these throws rather than defaulting. A default would hand
    // out an identity that provisioning never issued, which is the failure
    // this whole boundary exists to prevent — and it would be invisible,
    // because the person would simply be let in.

    test('no claims at all is refused', () async {
      await expectLater(
        repositoryFor(null).restoreSession(),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authUnauthenticated,
          ),
        ),
      );
    });

    test('a missing role is refused', () async {
      await expectLater(
        repositoryFor(<String, dynamic>{'org_id': 'org-42'}).restoreSession(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('an unrecognised role is refused, not defaulted', () async {
      // The case that would be most tempting to fall through on.
      await expectLater(
        repositoryFor(<String, dynamic>{
          'role': 'superuser',
          'org_id': 'org-42',
        }).restoreSession(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('a missing org_id is refused', () async {
      await expectLater(
        repositoryFor(<String, dynamic>{'role': 'collector'}).restoreSession(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('an empty org_id is refused', () async {
      // Present but useless. A blank organisation would scope every query to
      // nothing, or to everything, depending on who reads it.
      await expectLater(
        repositoryFor(<String, dynamic>{
          'role': 'collector',
          'org_id': '',
        }).restoreSession(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('a non-string org_id is refused', () async {
      // Claims arrive as dynamic across a platform channel.
      await expectLater(
        repositoryFor(<String, dynamic>{
          'role': 'collector',
          'org_id': 42,
        }).restoreSession(),
        throwsA(isA<AuthenticationException>()),
      );
    });
  });

  group('sign-in maps or converts, and never leaks', () {
    test('a successful sign-in returns the provisioned user', () async {
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        logger: AppLogger(environment: AppEnvironment.production),
        firebaseAuth: _FakeFirebaseAuth(
          _FakeUser(
            claims: <String, dynamic>{'role': 'admin', 'org_id': 'org-7'},
          ),
        ),
      );

      final domain.User user = await repository.signInWithEmailPassword(
        email: 'a@b.com',
        password: 'pw',
      );

      expect(user.role, Role.admin);
      expect(user.orgId, 'org-7');
    });

    test('a FirebaseAuthException is converted, not propagated', () async {
      // The guarantee ADR-034 states: no third-party auth error escapes this
      // class. The code comes from FirebaseAuthErrorMapper, tested separately;
      // what is asserted here is that _guard routes through it at all.
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        logger: AppLogger(environment: AppEnvironment.production),
        firebaseAuth: _FakeFirebaseAuth(
          null,
          signInThrows: fb.FirebaseAuthException(code: 'invalid-credential'),
        ),
      );

      await expectLater(
        repository.signInWithEmailPassword(email: 'a@b.com', password: 'no'),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authInvalidCredentials,
          ),
        ),
      );
    });

    test('a disabled account converts to AUTH_ACCOUNT_DISABLED', () async {
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        logger: AppLogger(environment: AppEnvironment.production),
        firebaseAuth: _FakeFirebaseAuth(
          null,
          signInThrows: fb.FirebaseAuthException(code: 'user-disabled'),
        ),
      );

      await expectLater(
        repository.signInWithEmailPassword(email: 'a@b.com', password: 'pw'),
        throwsA(
          isA<AuthenticationException>().having(
            (AuthenticationException e) => e.errorCode,
            'errorCode',
            ErrorCode.authAccountDisabled,
          ),
        ),
      );
    });

    test('an unexpected error still converts, via the catch-all', () async {
      // error-handling.md §7: the catch-all is required, so that a failure
      // nobody thought of still cannot escape untranslated.
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        logger: AppLogger(environment: AppEnvironment.production),
        firebaseAuth: _FakeFirebaseAuth(
          null,
          // Not a Firebase or Google error, so only the catch-all can take it.
          signInThrows: const FormatException('unexpected'),
        ),
      );

      await expectLater(
        repository.signInWithEmailPassword(email: 'a@b.com', password: 'pw'),
        throwsA(isA<AuthenticationException>()),
      );
    });
  });

  group('the session stream', () {
    test('originates unknown before Firebase reports anything', () {
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        logger: AppLogger(environment: AppEnvironment.production),
        firebaseAuth: _FakeFirebaseAuth(null),
      );

      // Session.unknown is originated, not mapped — Firebase has no such
      // event, and AsyncLoading depends on it arriving first.
      expect(
        repository.sessionChanges,
        emitsInOrder(<Matcher>[
          isA<SessionUnknown>(),
          isA<SessionUnauthenticated>(),
        ]),
      );
    });

    test('a signed-in user is mapped through the claims', () {
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        logger: AppLogger(environment: AppEnvironment.production),
        firebaseAuth: _FakeFirebaseAuth(
          null,
          stream: <fb.User?>[
            _FakeUser(
              claims: <String, dynamic>{'role': 'collector', 'org_id': 'org-9'},
            ),
          ],
        ),
      );

      expect(
        repository.sessionChanges,
        emitsInOrder(<Matcher>[
          isA<SessionUnknown>(),
          isA<SessionAuthenticated>(),
        ]),
      );
    });
  });

  group('no signed-in user', () {
    test(
      'restoreSession reports unauthenticated rather than throwing',
      () async {
        final AuthRepositoryImpl repository = AuthRepositoryImpl(
          logger: AppLogger(environment: AppEnvironment.production),
          firebaseAuth: _FakeFirebaseAuth(null),
        );

        expect(
          await repository.restoreSession(),
          isA<SessionUnauthenticated>(),
        );
      },
    );
  });
}

/// Enough of `FirebaseAuth` to answer `currentUser`.
class _FakeFirebaseAuth implements fb.FirebaseAuth {
  _FakeFirebaseAuth(this._user, {this.signInThrows, this.stream});

  final fb.User? _user;
  final Exception? signInThrows;
  final List<fb.User?>? stream;

  @override
  fb.User? get currentUser => _user;

  @override
  Stream<fb.User?> authStateChanges() =>
      Stream<fb.User?>.fromIterable(stream ?? <fb.User?>[null]);

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final Exception? failure = signInThrows;
    if (failure != null) {
      throw failure;
    }
    return _FakeCredential(_user);
  }

  // Everything else is unreached. `implements` plus `noSuchMethod` is what
  // makes a partial fake legal for a class with a private constructor.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements fb.User {
  _FakeUser({required this.claims});

  final Map<String, dynamic>? claims;

  @override
  String get uid => 'uid-1';

  @override
  String? get email => 'someone@example.com';

  @override
  bool get emailVerified => true;

  @override
  String? get displayName => null;

  @override
  Future<fb.IdTokenResult> getIdTokenResult([
    bool forceRefresh = false,
  ]) async => _FakeIdTokenResult(claims);

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

class _FakeIdTokenResult implements fb.IdTokenResult {
  _FakeIdTokenResult(this.claims);

  @override
  final Map<String, dynamic>? claims;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
