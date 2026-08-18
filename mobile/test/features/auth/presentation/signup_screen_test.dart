import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/core/onboarding/providers/onboarding_ports.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

import '../../../core/onboarding/fakes/onboarding_seen_fakes.dart';

/// SH-02's sign-up variant, and the link back to Login.
///
/// Driven through the real `routerProvider` rather than a hand-built one:
/// `/signup` is only reachable because `AuthGuard` treats it as public, and a
/// test router of its own would prove the link works while proving nothing
/// about whether anyone can get there.
void main() {
  Future<GoRouter> pumpSignup(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
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

    router.go('/signup');
    await tester.pumpAndSettle();
    return router;
  }

  String where(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('the sign-in link is present', (WidgetTester tester) async {
    final GoRouter router = await pumpSignup(tester);

    expect(where(router), '/signup');
    expect(find.byKey(const Key('signup.signIn')), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
  });

  testWidgets('tapping it navigates to /login', (WidgetTester tester) async {
    final GoRouter router = await pumpSignup(tester);

    await tester.tap(find.byKey(const Key('signup.signIn')));
    await tester.pumpAndSettle();

    expect(where(router), '/login');
    expect(find.byKey(const Key('login.email')), findsOneWidget);
  });

  testWidgets('the two links form a round trip', (WidgetTester tester) async {
    // Login's 'Create an account' and this one are each other's inverse, so
    // the pair is worth asserting together: a mismatch in either path would
    // strand someone on a screen with no way back.
    final GoRouter router = await pumpSignup(tester);

    await tester.tap(find.byKey(const Key('signup.signIn')));
    await tester.pumpAndSettle();
    expect(where(router), '/login');

    await tester.tap(find.byKey(const Key('login.createAccount')));
    await tester.pumpAndSettle();
    expect(where(router), '/signup');
  });
}

/// Nobody signed in, so the guard permits `/signup` and `/login`.
class _SignedOutRepository implements AuthRepository {
  // A-177: the guard sees "signed out" from this STREAM now — `build` no
  // longer calls `restoreSession`, so an empty stream would leave it awaiting
  // forever and every test here would time out rather than fail.
  @override
  Stream<Session> get sessionChanges => Stream<Session>.fromIterable(
    const <Session>[Session.unknown(), Session.unauthenticated()],
  );

  @override
  Future<Session> restoreSession() async => const Session.unauthenticated();

  @override
  Future<void> signOut() async {}

  @override
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<User> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    String? inviteCode,
  }) => throw UnimplementedError();

  @override
  Future<User> signUpWithGoogle({String? inviteCode}) =>
      throw UnimplementedError();
}
