import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
    backendUserId: 'backend-u1',
    email: 'c@example.com',
    role: Role.collector,
    orgId: 'org1',
    emailVerified: true,
  );
  const User admin = User(
    uid: 'u2',
    backendUserId: 'backend-u2',
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
          path: '/signup',
          builder: (_, _) => const Scaffold(body: Text('signup screen')),
        ),
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

    testWidgets('the password field is obscured', (WidgetTester tester) async {
      // Mutating `obscureText: true` to false at Mission 8.1 changed nothing
      // any test could see: the field's presence was asserted, its behaviour
      // was not. A regression here shows the password in plain text on a
      // device someone else can see, and every test would stay green.
      await pumpLogin(tester, _FakeAuthRepository());

      final TextField password = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('login.password')),
          matching: find.byType(TextField),
        ),
      );

      expect(password.obscureText, isTrue);
    });

    testWidgets('a Create an account link, per A-056', (
      WidgetTester tester,
    ) async {
      // Mission 2.7 deliberately had no link here, honouring Volume 10 Ch.
      // 10.4 §4's App Store reviewer framing. A-056 reverses it for this
      // distribution model — the assertion is inverted on purpose, and this
      // is the test that would catch it being reverted by accident.
      await pumpLogin(tester, _FakeAuthRepository());

      expect(find.byKey(const Key('login.createAccount')), findsOneWidget);
    });

    testWidgets('the link navigates to /signup', (WidgetTester tester) async {
      final GoRouter router = await pumpLogin(tester, _FakeAuthRepository());

      await tester.tap(find.byKey(const Key('login.createAccount')));
      await tester.pumpAndSettle();

      expect(location(router), '/signup');
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

    testWidgets('the error is announced, not just shown — Ch. 2.10 §4', (
      WidgetTester tester,
    ) async {
      // §4: "every error state (field.error) is announced when it appears —
      // not just shown visually — so a Collector using VoiceOver/TalkBack
      // hears ... rather than silence."
      //
      // Silence was the behaviour until Mission 5.5: the banner rendered and
      // nothing reached the semantics layer, on the screen §8 lists FIRST for
      // its TalkBack pass.
      //
      // What this asserts is the `liveRegion` flag, which is what Flutter
      // translates into the platform announcement. That TalkBack actually
      // speaks it is a device observation and stays in the device pass — no
      // widget test can see it.
      final SemanticsHandle handle = tester.ensureSemantics();
      final GoRouter router = await pumpLogin(
        tester,
        _FakeAuthRepository(
          signInThrows: const AuthenticationException(
            errorCode: ErrorCode.authInvalidCredentials,
            message: 'internal wording that must not be shown',
          ),
        ),
      );

      // The quiet baseline first. A live region already present at first paint
      // announces nothing when the error arrives, so proving the banner is
      // ABSENT before is what makes the assertion after it meaningful.
      expect(find.byKey(const Key('login.error')), findsNothing);

      await enterCredentials(tester);
      await tester.tap(find.byKey(const Key('login.submit')));
      await tester.pumpAndSettle();

      final SemanticsNode banner = tester.getSemantics(
        find.byKey(const Key('login.error')),
      );
      expect(banner.flagsCollection.isLiveRegion, isTrue);
      // The announcement must carry the copy, not merely fire. A live region
      // with an empty label announces nothing.
      expect(banner.label, contains('do not match an account'));
      expect(location(router), '/login');
      handle.dispose();
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

  /// Seeded on subscription, mirroring the real repository.
  ///
  /// A-177: `AuthNotifier.build` resolves the first session from this stream
  /// and no longer calls `restoreSession`, so a silent stream leaves `build`
  /// awaiting forever — the tests time out rather than fail.
  late final StreamController<Session> _sessions = StreamController<Session>(
    onListen: () {
      _sessions.add(const Session.unknown());
      _sessions.add(restored);
    },
  );

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
    String? inviteCode,
  }) async => _signIn();

  @override
  Future<User> signUpWithGoogle({String? inviteCode}) async => _signIn();

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
