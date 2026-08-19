import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';

/// Where a navigation request should actually go, given the session.
///
/// The Role Router of Volume 2 Ch. 2.4 §4, and the Login fallback of Volume 6
/// Ch. 6.7 §3, expressed as one function. ADR-004 named route-level
/// redirects as the home for both and left the guard undecided; ADR-037
/// decides it.
///
/// **A pure function of state and location, deliberately.** It touches no
/// `BuildContext`, no provider and no `GoRouter`, so every rule below is
/// testable as a table with no widget tree and no navigation. The router
/// supplies the two arguments and does as it is told.
///
/// Returns null to mean *stay where you are* — GoRouter's contract for a
/// redirect that declines.
abstract final class AuthGuard {
  /// Routes reachable without a session.
  ///
  /// `/signup` is here because someone creating an account necessarily has no
  /// session yet. It is the only unauthenticated write path in the
  /// application, which is why the invite code — not this list — is what
  /// actually protects it (ADR-036).
  static const Set<String> publicRoutes = <String>{'/login', '/signup'};

  /// The entry point, which renders nothing and always redirects.
  static const String entryRoute = '/';

  static const String collectorRoot = '/collector/dashboard';
  static const String adminRoot = '/admin/dashboard';

  /// Resolves a redirect, or null to allow [location].
  ///
  /// [auth] is null while the session is still resolving — `AsyncLoading`,
  /// which at cold start is the window before the first session emission
  /// answers.
  static String? redirect({
    required AuthState? auth,
    required String location,
  }) {
    if (auth == null) {
      // Not yet known. Redirecting now would send a signed-in user to /login
      // for the moment it takes to find out, which is the flash Mission 2.2
      // originated Session.unknown to prevent. main.dart resolves the session
      // before the first frame, so this is a guard against a rebuild rather
      // than a state a user normally sees.
      return null;
    }

    return switch (auth) {
      AuthStateAuthenticated(:final User user) => _forSignedIn(user, location),
      // Expired and unauthenticated route identically. The difference between
      // them is what Login *says* (Mission 2.5), not where the person goes.
      AuthStateExpired() ||
      AuthStateUnauthenticated() => _forSignedOut(location),
    };
  }

  /// Keeps a signed-in user inside their own role's root.
  static String? _forSignedIn(User user, String location) {
    final String home = user.role == Role.admin ? adminRoot : collectorRoot;

    // Nothing to do on an auth screen but leave it, and `/` renders nothing.
    if (location == entryRoute || publicRoutes.contains(location)) {
      return home;
    }

    // The role guard. A Collector reaching into /admin is sent home rather
    // than shown an error: Chapter 2.4 §4 makes role routing silent, and the
    // backend refuses the data regardless (Volume 4 Chapter 4.8 §1), so this
    // is a navigation correction and not a security boundary.
    final bool trespassing = switch (user.role) {
      Role.collector => location.startsWith('/admin'),
      Role.admin => location.startsWith('/collector'),
    };

    return trespassing ? home : null;
  }

  /// Whether [auth] is a signed-in Collector.
  ///
  /// Exists so `OnboardingGuard` can be told *which role* without importing
  /// one. ADR-022 R2 permits `lib/app/` to import a feature's `presentation/`
  /// and nothing else; this file already imports `AuthState`, `User` and
  /// `Role`, so answering the question here costs nothing, while asking it in
  /// the new guard would have added three fresh breaches of R2.
  ///
  /// False while [auth] is null — the session is still resolving, and
  /// redirecting on a role nobody has established yet is how the flash
  /// Mission 2.2 removed would come back.
  static bool isCollector(AuthState? auth) => switch (auth) {
    AuthStateAuthenticated(:final User user) => user.role == Role.collector,
    _ => false,
  };

  /// Sends anyone without a session to Login, except where they may already be.
  static String? _forSignedOut(String location) {
    if (publicRoutes.contains(location)) {
      return null;
    }
    return '/login';
  }
}
