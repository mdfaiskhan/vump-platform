import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/core/onboarding/providers/onboarding_ports.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

import '../../../core/onboarding/fakes/onboarding_seen_fakes.dart';

/// The Sign out control, and what happens after it.
///
/// The assertion worth having is the last group's: signing out lands the
/// person on `/login` **without this widget navigating**. `SignOutTile` calls
/// `go` nowhere — the route guard reacts to the session ending (ADR-037) — so
/// a test that drives the real router is the only thing that proves the two
/// halves meet.
void main() {
  Future<(GoRouter, _FakeAuthRepository)> pumpSignedIn(
    WidgetTester tester, {
    Role role = Role.collector,
  }) async {
    // The role matters: the guard sends a Collector out of /admin, so an
    // Admin-settings test signed in as a Collector never reaches the screen
    // it means to assert on.
    final _FakeAuthRepository repository = _FakeAuthRepository(role: role);
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

  group('the control appears on both Settings screens', () {
    testWidgets('the Collector settings tab has it', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpSignedIn(tester);

      router.go('/collector/settings');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings.signOut')), findsOneWidget);
    });

    testWidgets('the Admin settings tab has it too', (
      WidgetTester tester,
    ) async {
      // Composed by the router rather than imported by either feature, so
      // this also checks the composition actually reached both routes.
      final (GoRouter router, _) = await pumpSignedIn(tester, role: Role.admin);

      router.go('/admin/settings');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings.signOut')), findsOneWidget);
    });
  });

  group('the confirmation is asked before anything happens', () {
    testWidgets('tapping opens a dialog and signs nobody out yet', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _FakeAuthRepository repository) =
          await pumpSignedIn(tester);
      router.go('/collector/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings.signOut')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings.signOut.dialog')), findsOneWidget);
      expect(repository.signOutCalls, 0);
    });

    testWidgets('cancelling signs nobody out and stays put', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _FakeAuthRepository repository) =
          await pumpSignedIn(tester);
      router.go('/collector/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings.signOut')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings.signOut.cancel')));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 0);
      expect(where(router), '/collector/settings');
    });
  });

  group('confirming signs out and the guard does the routing', () {
    testWidgets('the repository is asked to sign out exactly once', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _FakeAuthRepository repository) =
          await pumpSignedIn(tester);
      router.go('/collector/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings.signOut')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings.signOut.confirm')));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
    });

    testWidgets('the app lands on /login, and not because the tile said so', (
      WidgetTester tester,
    ) async {
      // SignOutTile contains no `go`. The only thing that can move the person
      // is the guard reacting to the session ending — so if this passes, the
      // two halves are connected.
      final (GoRouter router, _) = await pumpSignedIn(tester);
      router.go('/collector/settings');
      await tester.pumpAndSettle();
      expect(where(router), '/collector/settings');

      await tester.tap(find.byKey(const Key('settings.signOut')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings.signOut.confirm')));
      await tester.pumpAndSettle();

      expect(where(router), '/login');
      expect(find.byKey(const Key('login.email')), findsOneWidget);
    });

    testWidgets('an Admin is returned to Login the same way', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _) = await pumpSignedIn(tester, role: Role.admin);
      router.go('/admin/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings.signOut')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings.signOut.confirm')));
      await tester.pumpAndSettle();

      expect(where(router), '/login');
    });
  });

  group('the state the notifier is left in', () {
    // A plain test, not a widget test: this asserts a state transition and
    // needs no tree. Driving it through `testWidgets` made `pumpEventQueue`
    // wait on an event queue nothing was pumping, which hung for ten minutes.
    test('signing out leaves unauthenticated, not expired', () async {
      // Mission 2.5 distinguishes a session that lapsed from one the person
      // ended. A deliberate sign-out reported as an expiry would tell them
      // their session ended unexpectedly right after they ended it.
      final _FakeAuthRepository repository = _FakeAuthRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
          // The redirect consults this on every navigation and the provider
          // throws until overridden. Seen-by-default, so C-01 does not
          // intercept tests about auth; onboarding_route_test.dart owns it.
          onboardingSeenStoreProvider.overrideWithValue(
            FakeOnboardingSeenStore(),
          ),
          // The redirect consults this on every navigation and the provider
          // throws until overridden. Seen-by-default, so C-01 does not
          // intercept tests about auth; onboarding_route_test.dart owns it.
          onboardingSeenStoreProvider.overrideWithValue(
            FakeOnboardingSeenStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).signOut();
      await pumpEventQueue();

      expect(repository.signOutCalls, 1);
      expect(
        container.read(authNotifierProvider).valueOrNull,
        isA<AuthStateUnauthenticated>(),
      );
    });
  });
}

/// Signed in as a Collector, and reports the sign-out on its stream the way
/// Firebase does.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.role = Role.collector});

  final Role role;

  User get _user => User(
    uid: 'u1',
    email: 'c@example.com',
    role: role,
    orgId: 'org-1',
    emailVerified: true,
  );

  int signOutCalls = 0;

  /// Seeded on subscription, mirroring the real repository.
  ///
  /// A-177: `AuthNotifier.build` resolves the first session from this stream
  /// and no longer calls `restoreSession`, so a silent stream leaves `build`
  /// awaiting forever — the tests time out rather than fail.
  late final StreamController<Session> _sessions = StreamController<Session>(
    onListen: () {
      _sessions.add(const Session.unknown());
      _sessions.add(Session.authenticated(_user));
    },
  );

  @override
  Stream<Session> get sessionChanges => _sessions.stream;

  @override
  Future<Session> restoreSession() async => Session.authenticated(_user);

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    _sessions.add(const Session.unauthenticated());
  }

  @override
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async => _user;

  @override
  Future<User> signInWithGoogle() async => _user;

  @override
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    String? inviteCode,
  }) async => _user;

  @override
  Future<User> signUpWithGoogle({String? inviteCode}) async => _user;
}
