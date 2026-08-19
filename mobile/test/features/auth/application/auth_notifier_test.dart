import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
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
    backendUserId: 'backend-u1',
    email: 'collector@example.com',
    role: Role.collector,
    orgId: 'org1',
    emailVerified: true,
  );
  const User admin = User(
    uid: 'u2',
    backendUserId: 'backend-u2',
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

    test('a session that cannot be read at startup is unauthenticated, '
        'not an error state', () async {
      // Nobody is signed in as far as this launch is concerned. Surfacing it
      // as AsyncError would put an error banner in front of a first-run user
      // who has simply never signed in.
      //
      // This used to be expressed as `restoreThrows`, when `build` called
      // `restoreSession`. Since A-177 it does not, so the same condition
      // arrives as an error on the session stream — the shape the real
      // repository produces when Firebase failed to initialise (ADR-017).
      final ProviderContainer container = containerWith(
        _FakeAuthRepository(
          startupError: const AuthenticationException(
            errorCode: ErrorCode.unknown,
            message: 'Firebase is not initialised',
          ),
        ),
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
  group('a transient backend failure does not destroy the session', () {
    // F5, A-178. Reproduced on CPH2707: two 502s from POST /v1/auth/verify
    // (gap 9 — Aurora resuming from MinCapacity 0 outran the Lambda's 15s
    // timeout) signed the Collector out completely. The session was fine; the
    // backend was briefly not.

    test('a 502 during startup does not sign the user out', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        startupError: const NetworkException(
          errorCode: ErrorCode.networkServerError,
          message: 'Server returned 502 for POST /v1/auth/verify',
        ),
      );
      final ProviderContainer container = containerWith(repository);

      expect(
        await container.read(authNotifierProvider.future),
        isA<AuthStateUnauthenticated>(),
      );
      await pumpEventQueue();

      // The whole of F5. Signing out here destroys a working credential and
      // makes recovery need the person's password rather than a working
      // backend.
      expect(repository.signOutCalls, 0);
    });

    test('an unprovisioned account IS still signed out', () async {
      // The case the discard was written for, and the proof that F5's fix is
      // a distinction rather than a blanket refusal to sign anybody out. This
      // account authenticates and carries no usable role, so it returns on
      // every cold start and the person could never reach Login without it.
      final _FakeAuthRepository repository = _FakeAuthRepository(
        startupError: const AuthenticationException(
          errorCode: ErrorCode.authUnauthenticated,
          message: 'no usable role claim',
        ),
      );
      final ProviderContainer container = containerWith(repository);

      await container.read(authNotifierProvider.future);
      await pumpEventQueue();

      expect(repository.signOutCalls, 1);
    });
  });
}

/// A scripted `AuthRepository`. No Firebase, no platform channels.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.restored = const Session.unknown(),
    this.startupError,
    this.signInResult,
    this.signInThrows,
  });

  final Session restored;

  /// An error the stream raises before any session resolves.
  ///
  /// Replaces `restoreThrows` for the startup case: since A-177 `build` never
  /// calls `restoreSession`, so a repository that cannot answer expresses that
  /// by erroring the stream, which is what the real one does.
  final Object? startupError;
  final User? signInResult;
  final AuthenticationException? signInThrows;

  late final StreamController<Session> _sessions = StreamController<Session>(
    onListen: _seed,
  );

  /// Emitted on subscription, in the order the real repository emits them.
  void _seed() {
    _sessions.add(const Session.unknown());
    final Object? failure = startupError;
    if (failure != null) {
      _sessions.addError(failure);
      return;
    }
    if (restored is! SessionUnknown) {
      _sessions.add(restored);
    }
  }

  void emit(Session session) => _sessions.add(session);
  void emitError(Object error) => _sessions.addError(error);

  /// Mirrors the real repository: `Session.unknown()` first, then whatever the
  /// platform reports, then any later emissions a test pushes with [emit].
  ///
  /// Seeded through `onListen` on a SINGLE-subscription controller rather than
  /// delegated with `yield*`. Both look equivalent and are not: an `async*`
  /// getter builds a new stream per access and forwards a broadcast
  /// controller's events only while it sits in the delegation, so emissions a
  /// test pushed after `build` resolved were silently dropped. One controller,
  /// one listener, every event delivered.
  ///
  /// Seeding at all is what keeps this fake faithful after A-177:
  /// `AuthNotifier.build` resolves the first session from THIS stream now — it
  /// no longer calls `restoreSession` — so a stream that stayed silent until a
  /// test pushed to it would leave `build` awaiting forever, modelling a
  /// repository that does not exist.
  @override
  Stream<Session> get sessionChanges => _sessions.stream;

  @override
  Future<Session> restoreSession() async => restored;

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
    String? inviteCode,
  }) async => _signIn();

  @override
  Future<User> signUpWithGoogle({String? inviteCode}) async => _signIn();

  /// How many times the notifier discarded the session — F5's evidence.
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
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
