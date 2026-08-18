import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// Cold-start restore and the expiry transition.
///
/// No Firebase project: the repository is a fake behind a `ProviderContainer`
/// override, the pattern Missions 2.3 and 2.4 established.
void main() {
  const User collector = User(
    uid: 'u1',
    email: 'c@example.com',
    role: Role.collector,
    orgId: 'org1',
    emailVerified: true,
  );

  ProviderContainer containerWith(AuthRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('cold start restores a persisted session', () {
    test('a persisted session resolves without a sign-in call', () async {
      // The behaviour FR-AUTH-03 asks for: a returning user is not sent to
      // Login. Firebase's SDK persists the credential natively, so restore is
      // a read of what the platform already holds.
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.authenticated(collector),
      );
      final ProviderContainer container = containerWith(repository);

      final AuthState state = await container.read(authNotifierProvider.future);

      expect(state, isA<AuthStateAuthenticated>());
      expect(repository.signInCalls, 0, reason: 'restore is not a sign-in');
    });

    test('awaiting the provider is what resolves the session', () async {
      // Before Mission 2.5, session resolution was wired into build() but
      // nothing read the provider at startup, so it never ran on a cold start.
      // This asserts the read is what triggers it — the original point, which
      // A-177 did not change.
      //
      // What A-177 changed is the mechanism: resolution is the
      // `sessionChanges` subscription now, not a `restoreSession` call, so the
      // counter that stands in for "the startup path ran" moved with it. The
      // second assertion is the gap-11 guarantee restated where this test can
      // see it: resolving must not also call `restoreSession`.
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.authenticated(collector),
      );
      final ProviderContainer container = containerWith(repository);

      expect(repository.subscribeCalls, 0, reason: 'nothing has read it yet');
      await container.read(authNotifierProvider.future);

      expect(repository.subscribeCalls, 1);
      expect(
        repository.restoreCalls,
        0,
        reason: 'gap 11 — the startup path must resolve the session once',
      );
    });

    test('no persisted session resolves to unauthenticated', () async {
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(restored: const Session.unauthenticated()),
      );

      expect(
        await container.read(authNotifierProvider.future),
        isA<AuthStateUnauthenticated>(),
      );
    });

    test('a restore that throws still resolves, signed out', () async {
      // Startup must not hang or crash on a device with no Firebase. main.dart
      // awaits this future, so a rejection here would abort launch.
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(restoreThrows: true),
      );

      await expectLater(
        container.read(authNotifierProvider.future),
        completion(isA<AuthStateUnauthenticated>()),
      );
    });
  });

  group('a lapsed session is told apart from a signed-out one', () {
    // Firebase emits the same null user for both, so the transition is the
    // only thing that distinguishes them. These are the tests that make
    // AuthState.expired reachable at all — it was structurally unreachable
    // before this mission.

    test('losing an authenticated session yields expired', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.authenticated(collector),
      );
      final ProviderContainer container = containerWith(repository);
      await container.read(authNotifierProvider.future);

      repository.emit(const Session.unauthenticated());
      await pumpEventQueue();

      expect(
        container.read(authNotifierProvider).value,
        isA<AuthStateExpired>(),
      );
    });

    test(
      'never having signed in yields unauthenticated, not expired',
      () async {
        final _FakeAuthRepository repository = _FakeAuthRepository(
          restored: const Session.unauthenticated(),
        );
        final ProviderContainer container = containerWith(repository);
        await container.read(authNotifierProvider.future);

        repository.emit(const Session.unauthenticated());
        await pumpEventQueue();

        expect(
          container.read(authNotifierProvider).value,
          isA<AuthStateUnauthenticated>(),
        );
      },
    );

    test('an explicit sign-out is not an expiry', () async {
      // The user asked for this one. Reporting it as an expiry would tell them
      // their session ended unexpectedly immediately after they ended it.
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.authenticated(collector),
        emitOnSignOut: true,
      );
      final ProviderContainer container = containerWith(repository);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).signOut();
      await pumpEventQueue();

      expect(
        container.read(authNotifierProvider).value,
        isA<AuthStateUnauthenticated>(),
      );
    });

    test('signing in after an expiry clears it', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.authenticated(collector),
      );
      final ProviderContainer container = containerWith(repository);
      await container.read(authNotifierProvider.future);

      repository.emit(const Session.unauthenticated());
      await pumpEventQueue();
      repository.emit(const Session.authenticated(collector));
      await pumpEventQueue();

      expect(
        container.read(authNotifierProvider).value,
        isA<AuthStateAuthenticated>(),
      );
    });

    test('a second loss after signing back in is an expiry again', () async {
      // The flag is re-armed by the new session rather than latched once.
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.unauthenticated(),
      );
      final ProviderContainer container = containerWith(repository);
      await container.read(authNotifierProvider.future);

      repository.emit(const Session.authenticated(collector));
      await pumpEventQueue();
      repository.emit(const Session.unauthenticated());
      await pumpEventQueue();

      expect(
        container.read(authNotifierProvider).value,
        isA<AuthStateExpired>(),
      );
    });
  });
}

/// A scripted `AuthRepository` that counts what startup actually called.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.restored = const Session.unauthenticated(),
    this.restoreThrows = false,
    this.emitOnSignOut = false,
  });

  final Session restored;
  final bool restoreThrows;

  /// Reproduces Firebase emitting a null user in response to `signOut`.
  final bool emitOnSignOut;

  int restoreCalls = 0;

  /// How many times `sessionChanges` was subscribed — the startup path's
  /// trigger since A-177, where `restoreCalls` used to be.
  int subscribeCalls = 0;
  int signInCalls = 0;

  /// Seeded on subscription, in the order the real repository emits.
  ///
  /// A-177: `AuthNotifier.build` resolves the first session from this stream
  /// and no longer calls `restoreSession`, so a fake whose stream stayed silent
  /// left `build` awaiting forever. Single-subscription rather than broadcast
  /// because there is one listener and `onListen` is what seeds it.
  late final StreamController<Session> _sessions = StreamController<Session>(
    onListen: () {
      subscribeCalls += 1;
      _sessions.add(const Session.unknown());
      if (restoreThrows) {
        _sessions.addError(
          const AuthenticationException(
            errorCode: ErrorCode.unknown,
            message: 'Firebase is not initialised',
          ),
        );
        return;
      }
      if (restored is! SessionUnknown) {
        _sessions.add(restored);
      }
    },
  );

  void emit(Session session) => _sessions.add(session);

  @override
  Stream<Session> get sessionChanges => _sessions.stream;

  @override
  Future<Session> restoreSession() async {
    restoreCalls += 1;
    if (restoreThrows) {
      throw const AuthenticationException(
        errorCode: ErrorCode.unknown,
        message: 'Firebase is not initialised',
      );
    }
    return restored;
  }

  @override
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    signInCalls += 1;
    return const User(
      uid: 'u1',
      email: 'c@example.com',
      role: Role.collector,
      orgId: 'org1',
      emailVerified: true,
    );
  }

  @override
  Future<User> signInWithGoogle() =>
      signInWithEmailPassword(email: '', password: '');

  @override
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    String? inviteCode,
  }) => signInWithEmailPassword(email: email, password: password);

  @override
  Future<User> signUpWithGoogle({String? inviteCode}) =>
      signInWithEmailPassword(email: '', password: '');

  @override
  Future<void> signOut() async {
    if (emitOnSignOut) {
      _sessions.add(const Session.unauthenticated());
    }
  }
}
