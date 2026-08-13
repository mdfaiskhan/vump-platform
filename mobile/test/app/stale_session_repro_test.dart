import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// Regression tests for the cold-start crash on a stale, role-less session.
///
/// ## What went wrong
///
/// Firebase persists its own credential, so a device that once signed in as an
/// account with no `role` claim replays that session on every launch.
/// `_toUser` refuses it, correctly — and the refusal became an **uncaught**
/// exception before any screen was drawn.
///
/// The cause was not the refusal but how it was read. `AsyncValue.value`
/// *rethrows* on an `AsyncError` rather than returning null, and the router's
/// redirect read `.value` during `MaterialApp.router`'s build. Two screens read
/// it the same way. All three now use `valueOrNull`.
///
/// ## Why the timing matters, and why these tests set a delay
///
/// The refusal only reaches the widget tree as an `AsyncError` when the session
/// stream errors *after* `build()` has resolved. On a device `restoreSession`
/// does platform-channel work while `authStateChanges` replays its persisted
/// user almost at once, so that ordering is the normal one. With both
/// resolving in the same microtask the notifier settles on `AsyncData` and the
/// bug hides — which is exactly why the first attempt at reproducing this
/// passed.
void main() {
  Future<(GoRouter, _StaleSessionRepository)> boot(WidgetTester tester) async {
    final _StaleSessionRepository repository = _StaleSessionRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    // Exactly what main.dart does before runApp, including swallowing.
    try {
      await container.read(authNotifierProvider.future);
    } on Object {
      // main.dart logs and continues.
    }
    // No pump before pumpWidget: main.dart goes straight to runApp. Draining
    // the event queue here would settle the notifier into AsyncData before the
    // tree exists and hide the very state under test — which is how the first
    // attempt at this test passed against the broken code.

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

  testWidgets('a refused session does not reach the framework uncaught', (
    WidgetTester tester,
  ) async {
    await boot(tester);

    // The assertion the crash report reduces to. Before the fix this was an
    // AuthenticationException thrown while building the router's descendants.
    expect(tester.takeException(), isNull);
  });

  testWidgets('it falls back to Login rather than an error screen', (
    WidgetTester tester,
  ) async {
    final (GoRouter router, _) = await boot(tester);

    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    expect(find.byKey(const Key('login.email')), findsOneWidget);
  });

  testWidgets('the unusable session is signed out, so it cannot loop', (
    WidgetTester tester,
  ) async {
    // Without this the device is stuck: Firebase replays the same credential
    // every launch, the app refuses it every launch, and the only escape is
    // clearing app storage by hand.
    final (_, _StaleSessionRepository repository) = await boot(tester);

    expect(repository.signOutCalls, greaterThan(0));
  });
}

/// Firebase holding a persisted session whose account has no `role` claim.
///
/// `restoreSession` resolves slowly, as a real platform-channel call does,
/// while the session stream reports its persisted user at once — the ordering
/// that produced the crash.
class _StaleSessionRepository implements AuthRepository {
  static const AuthenticationException _noRole = AuthenticationException(
    errorCode: ErrorCode.authUnauthenticated,
    message:
        'The signed-in account carries no usable "role" claim, so it has not '
        'been provisioned for this application.',
  );

  int signOutCalls = 0;

  @override
  Stream<Session> get sessionChanges async* {
    yield const Session.unknown();
    // Mapping the persisted user throws inside the generator, which the
    // subscriber sees as a stream error.
    throw _noRole;
  }

  @override
  Future<Session> restoreSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw _noRole;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async => throw _noRole;

  @override
  Future<User> signInWithGoogle() async => throw _noRole;

  @override
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    String? inviteCode,
  }) async => throw _noRole;

  @override
  Future<User> signUpWithGoogle({String? inviteCode}) async => throw _noRole;
}
