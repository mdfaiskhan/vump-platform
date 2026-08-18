import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/core/onboarding/providers/onboarding_ports.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_carousel_screen.dart';

import '../core/onboarding/fakes/onboarding_seen_fakes.dart';

/// C-01's first-launch trigger, through the real route table.
///
/// `onboarding_guard_test.dart` covers the rules. This covers the wiring the
/// pure function cannot prove: that the redirect actually fires, that the
/// carousel's "Get Started" persists the flag *before* navigating, and that
/// the Collector does not bounce straight back into the screen they just
/// finished.
///
/// **The route this exercises had no inbound edge at all before Mission 5.4**,
/// so there was nothing here to test — the screen existed and no path reached
/// it.
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

  Future<(GoRouter, FakeOnboardingSeenStore)> pumpApp(
    WidgetTester tester, {
    required User user,
    required bool seen,
  }) async {
    final FakeOnboardingSeenStore store = FakeOnboardingSeenStore(seen: seen);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(
          _SignedInRepository(Session.authenticated(user)),
        ),
        onboardingSeenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    // Resolved before the first frame, as main.dart does it: the guard must
    // not run against AsyncLoading or it declines everything.
    await container.read(authNotifierProvider.future);

    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return (router, store);
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('an unprimed Collector lands on the carousel', (
    WidgetTester tester,
  ) async {
    final (GoRouter router, _) = await pumpApp(
      tester,
      user: collector,
      seen: false,
    );

    expect(locationOf(router), '/onboarding');
    expect(find.byType(OnboardingCarouselScreen), findsOneWidget);
  });

  testWidgets('a primed Collector goes to the dashboard untouched', (
    WidgetTester tester,
  ) async {
    final (GoRouter router, FakeOnboardingSeenStore store) = await pumpApp(
      tester,
      user: collector,
      seen: true,
    );

    expect(locationOf(router), '/collector/dashboard');
    // Nothing wrote the flag: it was already true. Asserting the call count
    // rather than the value is what separates "already seen" from "seen
    // because this test set it".
    expect(store.markSeenCalls, 0);
  });

  testWidgets('an unprimed Admin is not primed', (WidgetTester tester) async {
    final (GoRouter router, FakeOnboardingSeenStore store) = await pumpApp(
      tester,
      user: admin,
      seen: false,
    );

    expect(locationOf(router), '/admin/dashboard');
    expect(store.markSeenCalls, 0);
  });

  testWidgets('completing the carousel persists the flag and leaves', (
    WidgetTester tester,
  ) async {
    final (GoRouter router, FakeOnboardingSeenStore store) = await pumpApp(
      tester,
      user: collector,
      seen: false,
    );

    // Five cards, per FR-ONB-01's five permissions. The last button completes.
    for (int i = 0; i < 5; i++) {
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    expect(store.markSeenCalls, 1);
    expect(locationOf(router), '/collector/dashboard');
  });

  testWidgets('a completed carousel does not reappear on renavigation', (
    WidgetTester tester,
  ) async {
    // The regression this guards is the one the ordering in `onComplete`
    // exists to prevent: if `go` ran before `markSeen` resolved, the redirect
    // would read a stale `false` and send the Collector straight back.
    final (GoRouter router, _) = await pumpApp(
      tester,
      user: collector,
      seen: false,
    );

    for (int i = 0; i < 5; i++) {
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    router.go('/collector/projects');
    await tester.pumpAndSettle();

    expect(locationOf(router), '/collector/projects');
    expect(find.byType(OnboardingCarouselScreen), findsNothing);
  });
}

/// An [AuthRepository] that restores one already-signed-in session.
class _SignedInRepository implements AuthRepository {
  _SignedInRepository(this._restored);

  final Session _restored;

  /// Seeded on subscription, mirroring the real repository.
  ///
  /// A-177: `AuthNotifier.build` resolves the first session from this stream
  /// and no longer calls `restoreSession`, so a silent stream leaves `build`
  /// awaiting forever and every test here times out rather than fails.
  late final StreamController<Session> _sessions = StreamController<Session>(
    onListen: () {
      _sessions.add(const Session.unknown());
      _sessions.add(_restored);
    },
  );

  @override
  Stream<Session> get sessionChanges => _sessions.stream;

  @override
  Future<Session> restoreSession() async => _restored;

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

  @override
  Future<void> signOut() async =>
      _sessions.add(const Session.unauthenticated());
}
