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

import 'fakes/fake_vump_api.dart';

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
  AuthRepositoryImpl repositoryFor(
    Map<String, dynamic>? claims, {
    FakeVumpApi? backend,
  }) {
    return AuthRepositoryImpl(
      backend: backend ?? FakeVumpApi(),
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

    test(
      'backendUserId is the response userId, NOT the Firebase uid',
      () async {
        // A-206. Step 3 wired `identity.collector_id` to `uid`; the metadata
        // route joins `sessions.collector_id`, which is `users.id`, and refuses
        // a document that disagrees. Every metadata POST would have been
        // refused, for every chunk, forever.
        //
        // Asserted as a PAIR rather than as one field, because the defect was
        // not a missing value — it was the wrong one of two present values.
        final Session session = await repositoryFor(<String, dynamic>{
          'role': 'collector',
          'org_id': 'org-42',
        }, backend: FakeVumpApi(userId: 'users-row-99')).restoreSession();

        final SessionAuthenticated authenticated =
            session as SessionAuthenticated;
        expect(authenticated.user.backendUserId, 'users-row-99');
        expect(authenticated.user.uid, 'uid-1');
        expect(
          authenticated.user.backendUserId,
          isNot(authenticated.user.uid),
          reason: 'the two identifiers must not be interchangeable',
        );
      },
    );

    test('a backend that returns no userId is refused', () async {
      // Both or neither: a blank here would put an empty collector_id on every
      // chunk the session records, which is the substitution A-068's Guard 1
      // exists to refuse, arriving from the other end.
      await expectLater(
        repositoryFor(<String, dynamic>{
          'role': 'collector',
          'org_id': 'org-42',
        }, backend: FakeVumpApi(userId: '')).restoreSession(),
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

    // ADR-048 moved org_id from the claim to `POST /v1/auth/verify`, and
    // Mission 7.2 removed the claim fallback that survived alongside it. So
    // "no organisation" is now something the BACKEND says, not something the
    // token omits — these two assert the same refusal at its new source.
    test('an org the backend does not return is refused', () async {
      await expectLater(
        repositoryFor(<String, dynamic>{
          'role': 'collector',
        }, backend: FakeVumpApi(orgId: '')).restoreSession(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('an empty org from the backend is refused', () async {
      // Present but useless. A blank organisation would scope every query to
      // nothing, or to everything, depending on who reads it.
      await expectLater(
        repositoryFor(<String, dynamic>{
          'role': 'collector',
          'org_id': 'ignored',
        }, backend: FakeVumpApi(orgId: '')).restoreSession(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('the org_id claim is ignored even when present and valid', () async {
      // The regression this replaces a fallback with. A stale claim must not
      // win over the table — Chapter 4.7 §2 names the table authoritative
      // "if the claim and the table ever disagree", and A-177 removed the
      // path where the claim could still be read.
      final Session session = await repositoryFor(<String, dynamic>{
        'role': 'collector',
        'org_id': 'stale-org',
      }, backend: FakeVumpApi(orgId: 'org-from-table')).restoreSession();

      expect((session as SessionAuthenticated).user.orgId, 'org-from-table');
    });
  });

  group('sign-in maps or converts, and never leaks', () {
    test('a successful sign-in returns the provisioned user', () async {
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        backend: FakeVumpApi(),
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
      expect(user.orgId, 'org-42');
    });

    test('a FirebaseAuthException is converted, not propagated', () async {
      // The guarantee ADR-034 states: no third-party auth error escapes this
      // class. The code comes from FirebaseAuthErrorMapper, tested separately;
      // what is asserted here is that _guard routes through it at all.
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        backend: FakeVumpApi(),
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
        backend: FakeVumpApi(),
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
        backend: FakeVumpApi(),
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
        backend: FakeVumpApi(),
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
        backend: FakeVumpApi(),
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
          backend: FakeVumpApi(),
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
  group('one sign-in performs one token exchange', () {
    // F6, A-180. Measured on CPH2707: a sign-in produced two POSTs 4ms apart,
    // because `signInWithEmailPassword` resolves a User and Firebase then
    // emits that same user on the stream, which resolves it again.
    //
    // Counts, not values — the same reason gap 11's guard counts (A-177).

    test('sign-in and the stream emission share one exchange', () async {
      final FakeVumpApi backend = FakeVumpApi();
      final AuthRepositoryImpl repository = repositoryFor(<String, dynamic>{
        'role': 'collector',
      }, backend: backend);

      // The two overlapping resolutions the device saw: the sign-in path and
      // the stream reacting to it, in flight at the same moment.
      await Future.wait<Object?>(<Future<Object?>>[
        repository.restoreSession(),
        repository.restoreSession(),
      ]);

      expect(backend.verifyCallCount, 1);
    });

    test('a later resolution is a fresh call, not a cached one', () async {
      // The single-flight shares an in-flight future and never a completed
      // result. If it cached, an org change would never be seen again.
      final FakeVumpApi backend = FakeVumpApi();
      final AuthRepositoryImpl repository = repositoryFor(<String, dynamic>{
        'role': 'collector',
      }, backend: backend);

      await repository.restoreSession();
      await repository.restoreSession();

      expect(backend.verifyCallCount, 2);
    });
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
