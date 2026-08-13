import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/auth_guard.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';

/// Every rule the route guard enforces, as a table.
///
/// `AuthGuard.redirect` is a pure function of state and location (ADR-037), so
/// none of this needs a widget tree, a router or a navigation. The wiring that
/// connects it to GoRouter is exercised separately in `router_guard_test.dart`
/// — these are the rules, that is the plumbing.
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

  String? at(String location, {AuthState? auth}) =>
      AuthGuard.redirect(auth: auth, location: location);

  group('while the session is still resolving', () {
    // main.dart resolves the session before the first frame, so a user does
    // not normally see this. It is reachable on a rebuild, and redirecting
    // here would flash /login at someone who is signed in — the flash
    // Session.unknown was originated to prevent.

    test('nothing is redirected', () {
      expect(at('/collector/dashboard'), isNull);
      expect(at('/admin/dashboard'), isNull);
      expect(at('/login'), isNull);
      expect(at('/'), isNull);
    });
  });

  group('signed out', () {
    const AuthState out = AuthState.unauthenticated();

    test('a protected route redirects to /login', () {
      expect(at('/collector/dashboard', auth: out), '/login');
      expect(at('/admin/dashboard', auth: out), '/login');
      expect(at('/collector/projects/p1/tasks/t1', auth: out), '/login');
      expect(at('/recording/s1', auth: out), '/login');
      expect(at('/admin/invite-codes', auth: out), '/login');
    });

    test('/ redirects to /login', () {
      expect(at('/', auth: out), '/login');
    });

    test('/login and /signup are left alone', () {
      // Redirecting /login to /login is an infinite loop, and /signup must be
      // reachable by someone who by definition has no session yet.
      expect(at('/login', auth: out), isNull);
      expect(at('/signup', auth: out), isNull);
    });
  });

  group('expired', () {
    const AuthState expired = AuthState.expired();

    test('routes exactly like signed out', () {
      // The difference between expired and unauthenticated is what Login says
      // (Mission 2.5), not where the person is sent.
      expect(at('/collector/dashboard', auth: expired), '/login');
      expect(at('/', auth: expired), '/login');
      expect(at('/login', auth: expired), isNull);
      expect(at('/signup', auth: expired), isNull);
    });
  });

  group('signed in as a Collector', () {
    const AuthState auth = AuthState.authenticated(collector);

    test('their own routes are allowed', () {
      expect(at('/collector/dashboard', auth: auth), isNull);
      expect(at('/collector/projects/p1', auth: auth), isNull);
      expect(at('/collector/settings', auth: auth), isNull);
    });

    test('/admin is redirected home, silently', () {
      expect(at('/admin/dashboard', auth: auth), AuthGuard.collectorRoot);
      expect(at('/admin/projects', auth: auth), AuthGuard.collectorRoot);
      expect(at('/admin/invite-codes', auth: auth), AuthGuard.collectorRoot);
    });

    test('/login and /signup send them home', () {
      // Chapter 2.4 §4's Role Router: the moment a session exists, the auth
      // screens are somewhere to leave rather than somewhere to be.
      expect(at('/login', auth: auth), AuthGuard.collectorRoot);
      expect(at('/signup', auth: auth), AuthGuard.collectorRoot);
    });

    test('/ sends them home', () {
      expect(at('/', auth: auth), AuthGuard.collectorRoot);
    });

    test('shared routes outside either root are allowed', () {
      // The checklist, recording and processing routes belong to a Collector's
      // flow but sit outside /collector, so a prefix rule must not catch them.
      expect(at('/checklist/t1', auth: auth), isNull);
      expect(at('/recording/s1', auth: auth), isNull);
      expect(at('/processing/s1', auth: auth), isNull);
    });
  });

  group('signed in as an Admin', () {
    const AuthState auth = AuthState.authenticated(admin);

    test('their own routes are allowed', () {
      expect(at('/admin/dashboard', auth: auth), isNull);
      expect(at('/admin/invite-codes', auth: auth), isNull);
    });

    test('/collector is redirected home', () {
      expect(at('/collector/dashboard', auth: auth), AuthGuard.adminRoot);
      expect(at('/collector/projects/p1', auth: auth), AuthGuard.adminRoot);
    });

    test('/, /login and /signup send them home', () {
      expect(at('/', auth: auth), AuthGuard.adminRoot);
      expect(at('/login', auth: auth), AuthGuard.adminRoot);
      expect(at('/signup', auth: auth), AuthGuard.adminRoot);
    });
  });

  group('the guard cannot send anyone in a circle', () {
    // A redirect whose destination also redirects is an infinite loop, and
    // GoRouter throws on one rather than hanging. Every destination the guard
    // can return must be a fixed point for the state that produced it.

    test('every destination is stable for the state that produced it', () {
      const List<AuthState> states = <AuthState>[
        AuthState.unauthenticated(),
        AuthState.expired(),
        AuthState.authenticated(collector),
        AuthState.authenticated(admin),
      ];
      const List<String> locations = <String>[
        '/',
        '/login',
        '/signup',
        '/collector/dashboard',
        '/admin/dashboard',
        '/admin/invite-codes',
        '/recording/s1',
      ];

      for (final AuthState state in states) {
        for (final String location in locations) {
          final String? first = AuthGuard.redirect(
            auth: state,
            location: location,
          );
          if (first == null) {
            continue;
          }
          expect(
            AuthGuard.redirect(auth: state, location: first),
            isNull,
            reason: '$state sent $location to $first, which redirects again',
          );
        }
      }
    });
  });
}
