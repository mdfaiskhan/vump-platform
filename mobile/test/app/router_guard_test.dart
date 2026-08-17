import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/onboarding/providers/onboarding_ports.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

import '../core/onboarding/fakes/onboarding_seen_fakes.dart';

/// The real `routerProvider`, driven by real auth state.
///
/// `auth_guard_test.dart` covers the rules; this covers the wiring that makes
/// them fire — that `refreshListenable` re-runs the redirect when a session
/// starts or ends, which is the part a pure function cannot prove.
///
/// The whole app router is built here, so this also replaces the coverage of
/// the `HomeScreen` widget test retired by this mission: it pumps
/// `MaterialApp.router` against the actual route table.
void main() {
  const User collector = User(
    uid: 'u1',
    email: 'c@example.com',
    role: Role.collector,
    orgId: 'org1',
    emailVerified: true,
  );
  const User admin = User(
    uid: 'u2',
    email: 'a@example.com',
    role: Role.admin,
    orgId: 'org1',
    emailVerified: true,
  );

  Future<(GoRouter, _FakeAuthRepository)> pumpApp(
    WidgetTester tester, {
    Session restored = const Session.unauthenticated(),
    User? signInResult,
  }) async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      restored: restored,
      signInResult: signInResult,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        // The redirect consults this on every navigation and the provider
        // throws until overridden. Seen-by-default, so C-01 does not
        // intercept tests about auth; onboarding_route_test.dart owns it.
        onboardingSeenStoreProvider.overrideWithValue(
          FakeOnboardingSeenStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Resolved before the first frame, exactly as main.dart does it — the
    // guard must not run against AsyncLoading or it declines everything.
    await container.read(authNotifierProvider.future);

    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return (router, repository);
  }

  String where(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  group('cold start', () {
    testWidgets('signed out lands on /login, not the retired placeholder', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpApp(tester);

      expect(where(router), '/login');
      // Mission 0.6's HomeScreen is gone. Asserted by its absence rather than
      // trusted, because a stale route would still build it.
      expect(find.textContaining('Mission'), findsNothing);
    });

    testWidgets('a restored Collector session lands on the collector root', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpApp(
        tester,
        restored: const Session.authenticated(collector),
      );

      expect(where(router), '/collector/dashboard');
    });

    testWidgets('a restored Admin session lands on the admin root', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpApp(
        tester,
        restored: const Session.authenticated(admin),
      );

      expect(where(router), '/admin/dashboard');
    });
  });

  group('protected routes', () {
    testWidgets('a signed-out user cannot reach a protected route', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpApp(tester);

      router.go('/collector/dashboard');
      await tester.pumpAndSettle();

      expect(where(router), '/login');
    });

    testWidgets('a signed-out user cannot reach the admin invite screen', (
      WidgetTester tester,
    ) async {
      // The screen whose Firestore writes are gated by rules — the guard is
      // the second line, not the first, but it should still hold.
      final (GoRouter router, _) = await pumpApp(tester);

      router.go('/admin/invite-codes');
      await tester.pumpAndSettle();

      expect(where(router), '/login');
    });

    testWidgets('a signed-out user may reach /signup', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpApp(tester);

      router.go('/signup');
      await tester.pumpAndSettle();

      expect(where(router), '/signup');
      expect(find.byKey(const Key('signup.inviteCode')), findsOneWidget);
    });
  });

  group('the role guard', () {
    testWidgets('a Collector reaching into /admin is sent home', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpApp(
        tester,
        restored: const Session.authenticated(collector),
      );

      router.go('/admin/dashboard');
      await tester.pumpAndSettle();

      expect(where(router), '/collector/dashboard');
    });

    testWidgets('an Admin reaching into /collector is sent home', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpApp(
        tester,
        restored: const Session.authenticated(admin),
      );

      router.go('/collector/projects');
      await tester.pumpAndSettle();

      expect(where(router), '/admin/dashboard');
    });
  });

  group('a session that starts or ends moves the user', () {
    // This is what refreshListenable buys. Without it the redirect only runs
    // on navigation, so a sign-in would leave the person on /login.

    testWidgets('signing in moves them off /login without navigating', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _FakeAuthRepository repository) = await pumpApp(
        tester,
      );
      expect(where(router), '/login');

      repository.emit(const Session.authenticated(collector));
      await tester.pumpAndSettle();

      expect(where(router), '/collector/dashboard');
    });

    testWidgets('an Admin signing in lands on the admin root', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _FakeAuthRepository repository) = await pumpApp(
        tester,
      );

      repository.emit(const Session.authenticated(admin));
      await tester.pumpAndSettle();

      expect(where(router), '/admin/dashboard');
    });

    testWidgets('a session ending returns them to /login', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _FakeAuthRepository repository) = await pumpApp(
        tester,
        restored: const Session.authenticated(collector),
      );
      expect(where(router), '/collector/dashboard');

      repository.emit(const Session.unauthenticated());
      await tester.pumpAndSettle();

      expect(where(router), '/login');
    });
  });

  group('sign-up lands at the collector root', () {
    // The end-to-end path Mission 2.6 built and this mission made reachable.
    // The Cloud Function is faked at the repository boundary, per the pattern
    // Missions 2.3 to 2.5 established — a live call would need a real invite
    // code, and the deployed function is verified separately in ADR-036.

    testWidgets('a redeemed code signs the person in and routes them', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _FakeAuthRepository repository) = await pumpApp(
        tester,
        signInResult: collector,
      );

      router.go('/signup');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('signup.inviteCode')),
        'ABCDEFGHJK',
      );
      await tester.enterText(
        find.byKey(const Key('signup.email')),
        'new@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('signup.password')),
        'pw1234',
      );
      await tester.tap(find.byKey(const Key('signup.submit')));
      await tester.pumpAndSettle();

      expect(repository.signUpCalls, 1);
      expect(where(router), '/collector/dashboard');
    });

    testWidgets('a rejected code keeps them on /signup with the reason', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpApp(tester);

      router.go('/signup');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('signup.inviteCode')),
        'BADCODE123',
      );
      await tester.enterText(
        find.byKey(const Key('signup.email')),
        'new@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('signup.password')),
        'pw1234',
      );
      await tester.tap(find.byKey(const Key('signup.submit')));
      await tester.pumpAndSettle();

      expect(where(router), '/signup');
      expect(find.byKey(const Key('signup.error')), findsOneWidget);
      expect(
        find.text(
          'That invite code is not valid. Check it with your organisation '
          'admin.',
        ),
        findsOneWidget,
      );
    });
  });
}

/// A scripted `AuthRepository`. `signInResult` null means every attempt is
/// rejected as an invalid invite code.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.restored, this.signInResult});

  final Session restored;
  final User? signInResult;

  int signUpCalls = 0;

  final StreamController<Session> _sessions =
      StreamController<Session>.broadcast();

  void emit(Session session) => _sessions.add(session);

  @override
  Stream<Session> get sessionChanges => _sessions.stream;

  @override
  Future<Session> restoreSession() async => restored;

  @override
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async => _succeed();

  @override
  Future<User> signInWithGoogle() async => _succeed();

  @override
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    String? inviteCode,
  }) async {
    signUpCalls += 1;
    return _succeed();
  }

  @override
  Future<User> signUpWithGoogle({String? inviteCode}) async {
    signUpCalls += 1;
    return _succeed();
  }

  @override
  Future<void> signOut() async =>
      _sessions.add(const Session.unauthenticated());

  User _succeed() {
    final User? user = signInResult;
    if (user == null) {
      throw const AuthenticationException(
        errorCode: ErrorCode.authInviteCodeInvalid,
        message: 'rejected by the function',
      );
    }
    // The real repository reports the new session on its stream; the guard
    // reads the notifier, so the ordering matters and is reproduced here.
    _sessions.add(Session.authenticated(user));
    return user;
  }
}
