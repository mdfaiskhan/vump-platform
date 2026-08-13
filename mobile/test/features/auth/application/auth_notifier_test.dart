import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// State-transition tests for `AuthNotifier`.
///
/// Driven through `ProviderContainer` overrides rather than a widget pump, per
/// Volume 9 §9.6 §1 and testing-standards.md §4: a notifier is plain Dart
/// reading from an interface, and rendering it adds a tree, an async settle
/// and a source of flakiness for no extra assurance.
///
/// Substitution is a fake, not a mock (testing-standards.md §8).
void main() {
  const User collector = User(
    uid: 'u1',
    email: 'collector@example.com',
    role: Role.collector,
    orgId: 'org1',
    emailVerified: true,
  );
  const User admin = User(
    uid: 'u2',
    email: 'admin@example.com',
    role: Role.admin,
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

  group('the state the Role Router reads', () {
    test(
      'a restored session resolves to authenticated with the role',
      () async {
        final _FakeAuthRepository repository = _FakeAuthRepository(
          restored: const Session.authenticated(admin),
        );
        final ProviderContainer container = containerWith(repository);

        final AuthState state = await container.read(
          authNotifierProvider.future,
        );

        expect(state, isA<AuthStateAuthenticated>());
        expect(state.user?.role, Role.admin);
      },
    );

    test('no session resolves to unauthenticated', () async {
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(restored: const Session.unauthenticated()),
      );

      expect(
        await container.read(authNotifierProvider.future),
        isA<AuthStateUnauthenticated>(),
      );
    });

    test('a failed restore is unauthenticated, not an error state', () async {
      // Nobody is signed in as far as this launch is concerned. Surfacing it
      // as AsyncError would put an error banner in front of a first-run user
      // who has simply never signed in.
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(restoreThrows: true),
      );

      expect(
        await container.read(authNotifierProvider.future),
        isA<AuthStateUnauthenticated>(),
      );
    });
  });

  group('Session maps onto AuthState', () {
    test('unknown has no AuthState, because AsyncLoading is that state', () {
      // The mapping returns null rather than inventing a fourth case; the
      // notifier turns that into AsyncLoading. Two spellings of "not yet
      // known" would mean AsyncValue.when could not cover it.
      expect(AuthState.fromSession(const Session.unknown()), isNull);
    });

    test('unauthenticated and authenticated map across', () {
      expect(
        AuthState.fromSession(const Session.unauthenticated()),
        isA<AuthStateUnauthenticated>(),
      );
      expect(
        AuthState.fromSession(const Session.authenticated(collector))?.user,
        collector,
      );
    });

    test('user is null in every state but authenticated', () {
      expect(const AuthState.unauthenticated().user, isNull);
      expect(const AuthState.expired().user, isNull);
      expect(const AuthState.authenticated(collector).user, collector);
    });
  });

  group('the session stream drives state', () {
    test('signing in elsewhere updates state without a sign-in call', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.unauthenticated(),
      );
      final ProviderContainer container = containerWith(repository);
      await container.read(authNotifierProvider.future);

      repository.emit(const Session.authenticated(collector));
      await pumpEventQueue();

      expect(
        container.read(authNotifierProvider).value,
        isA<AuthStateAuthenticated>(),
      );
    });

    test('an unknown emission returns the notifier to loading', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.authenticated(collector),
      );
      final ProviderContainer container = containerWith(repository);
      await container.read(authNotifierProvider.future);

      repository.emit(const Session.unknown());
      await pumpEventQueue();

      expect(container.read(authNotifierProvider).isLoading, isTrue);
    });

    test('a stream error becomes AsyncError', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.unauthenticated(),
      );
      final ProviderContainer container = containerWith(repository);
      await container.read(authNotifierProvider.future);

      repository.emitError(
        const AuthenticationException(
          errorCode: ErrorCode.unknown,
          message: 'Firebase is not initialised',
        ),
      );
      await pumpEventQueue();

      expect(container.read(authNotifierProvider).hasError, isTrue);
    });
  });

  group('a sign-in attempt returns its own outcome', () {
    // The decision this group exists to pin: a rejected password is an outcome
    // of one attempt, not a session state. If these ever start writing to
    // `state`, the app can no longer tell "not signed in" from "someone just
    // mistyped a password".

    test('success returns null', () async {
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(
          restored: const Session.unauthenticated(),
          signInResult: collector,
        ),
      );
      await container.read(authNotifierProvider.future);

      final Failure? failure = await container
          .read(authNotifierProvider.notifier)
          .signInWithEmailPassword(email: 'a@b.com', password: 'pw');

      expect(failure, isNull);
    });

    test('a rejected credential returns a Failure carrying its code', () async {
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(
          restored: const Session.unauthenticated(),
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.authInvalidCredentials,
            message: 'rejected',
          ),
        ),
      );
      await container.read(authNotifierProvider.future);

      final Failure? failure = await container
          .read(authNotifierProvider.notifier)
          .signInWithEmailPassword(email: 'a@b.com', password: 'wrong');

      expect(failure?.code, ErrorCode.authInvalidCredentials);
    });

    test('a failed attempt leaves session state untouched', () async {
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(
          restored: const Session.unauthenticated(),
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.authInvalidCredentials,
            message: 'rejected',
          ),
        ),
      );
      await container.read(authNotifierProvider.future);

      await container
          .read(authNotifierProvider.notifier)
          .signInWithEmailPassword(email: 'a@b.com', password: 'wrong');

      final AsyncValue<AuthState> after = container.read(authNotifierProvider);
      expect(after.hasError, isFalse, reason: 'the session is not broken');
      expect(after.value, isA<AuthStateUnauthenticated>());
    });

    test('a cancelled Google sign-in returns its own code', () async {
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(
          restored: const Session.unauthenticated(),
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.authSignInCancelled,
            message: 'dismissed',
          ),
        ),
      );
      await container.read(authNotifierProvider.future);

      final Failure? failure = await container
          .read(authNotifierProvider.notifier)
          .signInWithGoogle();

      expect(failure?.code, ErrorCode.authSignInCancelled);
    });

    test('no AppException escapes to the caller', () async {
      // error-handling.md §26: application/ is the last layer that may catch
      // an AppException, and presentation/ must never receive one.
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(
          restored: const Session.unauthenticated(),
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.unknown,
            message: 'boom',
          ),
        ),
      );
      await container.read(authNotifierProvider.future);

      await expectLater(
        container.read(authNotifierProvider.notifier).signOut(),
        completion(isA<Failure>()),
      );
    });
  });
}

/// A scripted `AuthRepository`. No Firebase, no platform channels.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.restored = const Session.unknown(),
    this.restoreThrows = false,
    this.signInResult,
    this.signInThrows,
  });

  final Session restored;
  final bool restoreThrows;
  final User? signInResult;
  final AuthenticationException? signInThrows;

  final StreamController<Session> _sessions =
      StreamController<Session>.broadcast();

  void emit(Session session) => _sessions.add(session);
  void emitError(Object error) => _sessions.addError(error);

  @override
  Stream<Session> get sessionChanges => _sessions.stream;

  @override
  Future<Session> restoreSession() async {
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
  }) async => _signIn();

  @override
  Future<User> signInWithGoogle() async => _signIn();

  @override
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    required String inviteCode,
  }) async => _signIn();

  @override
  Future<User> signUpWithGoogle({required String inviteCode}) async =>
      _signIn();

  @override
  Future<void> signOut() async {
    final AuthenticationException? failure = signInThrows;
    if (failure != null) {
      throw failure;
    }
  }

  User _signIn() {
    final AuthenticationException? failure = signInThrows;
    if (failure != null) {
      throw failure;
    }
    return signInResult!;
  }
}
