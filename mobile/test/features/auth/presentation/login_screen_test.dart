import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/auth_guard.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';

/// Widget tests for SH-02 and the SH-03 Role Router branch it performs.
///
/// Only what needs a tree is tested here. The state transitions behind it are
/// covered without one in `auth_notifier_test.dart`, per Volume 9 §9.6 §1.
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

  /// Pumps the login screen inside a router that records where it lands.
  Future<GoRouter> pumpLogin(
    WidgetTester tester,
    _FakeAuthRepository repository,
  ) async {
    late final ProviderContainer container;
    final _Refresh refresh = _Refresh();

    final GoRouter router = GoRouter(
      initialLocation: '/login',
      // The Role Router is the guard now, not the screen (ADR-037). Wiring it
      // here is what keeps these assertions honest: they exercise the real
      // redirect rather than navigation the screen no longer performs.
      refreshListenable: refresh,
      redirect: (BuildContext context, GoRouterState state) =>
          AuthGuard.redirect(
            auth: container.read(authNotifierProvider).value,
            location: state.matchedLocation,
          ),
      routes: <RouteBase>[
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/collector/dashboard',
          builder: (_, _) => const Scaffold(body: Text('collector root')),
        ),
        GoRoute(
          path: '/admin/dashboard',
          builder: (_, _) => const Scaffold(body: Text('admin root')),
        ),
      ],
    );
    addTearDown(router.dispose);

    final Widget app = ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: Builder(
        builder: (BuildContext context) {
          container = ProviderScope.containerOf(context);
          container.listen(authNotifierProvider, (_, _) {
            refresh.bump();
          });
          return MaterialApp.router(routerConfig: router);
        },
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    return router;
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  Future<void> enterCredentials(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('login.email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('login.password')), 'pw');
  }

  group('what SH-02 shows', () {
    testWidgets('email, password and the SSO entry point', (
      WidgetTester tester,
    ) async {
      // Volume 2 Chapter 2.5 §1 fixes the contents: "Email/password fields,
      // SSO entry point, error states".
      await pumpLogin(tester, _FakeAuthRepository());

      expect(find.byKey(const Key('login.email')), findsOneWidget);
      expect(find.byKey(const Key('login.password')), findsOneWidget);
      expect(find.byKey(const Key('login.google')), findsOneWidget);
      expect(find.byKey(const Key('login.submit')), findsOneWidget);
    });

    testWidgets('no sign-up link, per Volume 10 Chapter 10.4 §4', (
      WidgetTester tester,
    ) async {
      // "there deliberately isn't one". A link appearing here would make
      // SignupScreen reachable and route into a throwing redemption step.
      await pumpLogin(tester, _FakeAuthRepository());

      expect(find.textContaining('Sign up'), findsNothing);
      expect(find.textContaining('Create an account'), findsNothing);
    });

    testWidgets('no error banner before an attempt', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester, _FakeAuthRepository());
      expect(find.byKey(const Key('login.error')), findsNothing);
    });
  });

  group('local validation', () {
    testWidgets('an empty form does not reach the repository', (
      WidgetTester tester,
    ) async {
      final _FakeAuthRepository repository = _FakeAuthRepository();
      await pumpLogin(tester, repository);

      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      expect(repository.emailSignInCalls, 0);
      expect(find.text('Enter your work email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('a malformed address is caught before a round trip', (
      WidgetTester tester,
    ) async {
      final _FakeAuthRepository repository = _FakeAuthRepository();
      await pumpLogin(tester, repository);

      await tester.enterText(find.byKey(const Key('login.email')), 'nope');
      await tester.enterText(find.byKey(const Key('login.password')), 'pw');
      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      expect(repository.emailSignInCalls, 0);
      expect(
        find.text('That does not look like an email address.'),
        findsOneWidget,
      );
    });

    testWidgets('Google sign-in ignores the empty form', (
      WidgetTester tester,
    ) async {
      // The account picker supplies the identity, so blank fields are not a
      // reason to block this path.
      final _FakeAuthRepository repository = _FakeAuthRepository(
        signInResult: collector,
      );
      await pumpLogin(tester, repository);

      await tester.tap(find.byKey(const Key('login.google')));
      await tester.pumpAndSettle();

      expect(repository.googleSignInCalls, 1);
    });
  });

  group('the Role Router — SH-03', () {
    testWidgets('a collector lands on the collector root', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpLogin(
        tester,
        _FakeAuthRepository(signInResult: collector),
      );

      await enterCredentials(tester);
      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      expect(location(router), '/collector/dashboard');
    });

    testWidgets('an admin lands on the admin root', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpLogin(
        tester,
        _FakeAuthRepository(signInResult: admin),
      );

      await enterCredentials(tester);
      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      expect(location(router), '/admin/dashboard');
    });

    testWidgets('routing is silent — no intermediate screen', (
      WidgetTester tester,
    ) async {
      // Chapter 2.4 §4: it "happens once, silently, and is not user-visible as
      // a separate step". SH-03 renders nothing of its own.
      final GoRouter router = await pumpLogin(
        tester,
        _FakeAuthRepository(signInResult: admin),
      );

      await enterCredentials(tester);
      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      expect(find.text('admin root'), findsOneWidget);
      expect(find.textContaining('Role Router'), findsNothing);
      expect(location(router), '/admin/dashboard');
    });
  });

  group('the fallback from a lapsed session', () {
    // Volume 6 Chapter 6.7 §3 ends silent re-authentication by "falling back
    // to the Login screen". Until Mission 2.5 made AuthState.expired
    // reachable, this branch could not be exercised at all.

    testWidgets('an expired session is explained, not silent', (
      WidgetTester tester,
    ) async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.authenticated(collector),
      );
      await pumpLogin(tester, repository);

      repository.emit(const Session.unauthenticated());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login.expired')), findsOneWidget);
      expect(
        find.text('Your session ended. Sign in again to continue.'),
        findsOneWidget,
      );
    });

    testWidgets('a first-run user sees no expiry notice', (
      WidgetTester tester,
    ) async {
      // Telling someone their session ended when they have never had one is
      // the same class of defect as a generic error message.
      await pumpLogin(tester, _FakeAuthRepository());

      expect(find.byKey(const Key('login.expired')), findsNothing);
    });

    testWidgets('the notice is not styled as an error', (
      WidgetTester tester,
    ) async {
      // An expiry is not a mistake the person made. Chapter 2.9 §5's rule that
      // queued must not look like failed is the same instinct.
      final _FakeAuthRepository repository = _FakeAuthRepository(
        restored: const Session.authenticated(collector),
      );
      await pumpLogin(tester, repository);

      repository.emit(const Session.unauthenticated());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login.error')), findsNothing);
    });
  });

  group('error states name a cause and a fix', () {
    testWidgets('a rejected credential shows the specific message', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpLogin(
        tester,
        _FakeAuthRepository(
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.authInvalidCredentials,
            message: 'internal wording that must not be shown',
          ),
        ),
      );

      await enterCredentials(tester);
      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login.error')), findsOneWidget);
      expect(
        find.text(
          'That email and password do not match an account. Check both and '
          'try again.',
        ),
        findsOneWidget,
      );
      expect(location(router), '/login', reason: 'a failure does not route');
    });

    testWidgets('the internal exception message is never rendered', (
      WidgetTester tester,
    ) async {
      // error-handling.md §21: an exception message is written for a reader of
      // logs. Failure carries it, and presentation resolves copy from the code
      // instead — this asserts the screen honours that.
      await pumpLogin(
        tester,
        _FakeAuthRepository(
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.authInvalidCredentials,
            message: 'internal wording that must not be shown',
          ),
        ),
      );

      await enterCredentials(tester);
      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('internal wording that must not be shown'),
        findsNothing,
      );
    });

    testWidgets('no generic "something went wrong" anywhere', (
      WidgetTester tester,
    ) async {
      // Chapter 2.9 §2 calls that string a defect, not a fallback. Asserted
      // against the code with no copy of its own, which is where a generic
      // message would otherwise creep in.
      await pumpLogin(
        tester,
        _FakeAuthRepository(
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.storageCorrupted,
            message: 'unmapped',
          ),
        ),
      );

      await enterCredentials(tester);
      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Something went wrong'), findsNothing);
      expect(find.byKey(const Key('login.error')), findsOneWidget);
    });

    testWidgets('a cancelled Google sign-in shows nothing at all', (
      WidgetTester tester,
    ) async {
      // Dismissing the account picker is a deliberate action, not a fault. A
      // red banner under it would report an error that did not occur.
      await pumpLogin(
        tester,
        _FakeAuthRepository(
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.authSignInCancelled,
            message: 'dismissed',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('login.google')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login.error')), findsNothing);
    });

    testWidgets('the form is usable again after a failure', (
      WidgetTester tester,
    ) async {
      // Chapter 2.9 §4.3: every error pairs a cause with a recovery action.
      // Here the action is "try again", so the controls must come back.
      await pumpLogin(
        tester,
        _FakeAuthRepository(
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.authInvalidCredentials,
            message: 'rejected',
          ),
        ),
      );

      await enterCredentials(tester);
      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('login.submit')),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}

/// A scripted `AuthRepository` that also reports the new session.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.signInResult,
    this.signInThrows,
    this.restored = const Session.unauthenticated(),
  });

  final User? signInResult;
  final AuthenticationException? signInThrows;
  final Session restored;

  int emailSignInCalls = 0;
  int googleSignInCalls = 0;

  final StreamController<Session> _sessions =
      StreamController<Session>.broadcast();

  @override
  Stream<Session> get sessionChanges => _sessions.stream;

  void emit(Session session) => _sessions.add(session);

  @override
  Future<Session> restoreSession() async => restored;

  @override
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    emailSignInCalls += 1;
    return _signIn();
  }

  @override
  Future<User> signInWithGoogle() async {
    googleSignInCalls += 1;
    return _signIn();
  }

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
  Future<void> signOut() async {}

  User _signIn() {
    final AuthenticationException? failure = signInThrows;
    if (failure != null) {
      throw failure;
    }
    final User user = signInResult!;
    // The real repository reports the new session on its stream, and the
    // notifier is what the Role Router reads. Emitting synchronously here
    // reproduces that ordering.
    _sessions.add(Session.authenticated(user));
    return user;
  }
}

/// A Listenable the test drives by hand, standing in for the router provider's
/// own refresh wiring.
class _Refresh extends ChangeNotifier {
  void bump() => notifyListeners();
}
