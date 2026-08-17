import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/onboarding_guard.dart';

/// `OnboardingGuard`'s rules, as a table.
///
/// The guard is a pure function of three primitives, so every rule is checked
/// without a widget tree, a provider or a route — the property ADR-037 asks
/// of a guard and the reason this one takes a `bool` rather than an
/// `AuthState`.
void main() {
  group('OnboardingGuard.redirect', () {
    test('sends an unprimed Collector to /onboarding', () {
      expect(
        OnboardingGuard.redirect(
          isCollector: true,
          hasSeenOnboarding: false,
          location: '/collector/dashboard',
        ),
        '/onboarding',
      );
    });

    test('declines once the carousel has been seen', () {
      expect(
        OnboardingGuard.redirect(
          isCollector: true,
          hasSeenOnboarding: true,
          location: '/collector/dashboard',
        ),
        isNull,
      );
    });

    test('declines for an Admin, primed or not', () {
      // FR-ONB-01's five permissions are all capture permissions, and Chapter
      // 2.4 §3 gives an Admin no path to a Recording Screen.
      for (final bool seen in <bool>[false, true]) {
        expect(
          OnboardingGuard.redirect(
            isCollector: false,
            hasSeenOnboarding: seen,
            location: '/admin/dashboard',
          ),
          isNull,
          reason: 'Admin with hasSeenOnboarding=$seen',
        );
      }
    });

    test('declines at /onboarding itself, so the redirect cannot loop', () {
      // Returning the route again from the route would be a redirect to the
      // current location, which GoRouter treats as a cycle rather than a
      // no-op.
      expect(
        OnboardingGuard.redirect(
          isCollector: true,
          hasSeenOnboarding: false,
          location: '/onboarding',
        ),
        isNull,
      );
    });

    test('intercepts every Collector location, including deep links', () {
      // The guard is not scoped to the tab roots: a restored route or a deep
      // link into a Project, a checklist or the chrome-free recording surface
      // is still a first launch, and Chapter 2.7 puts the carousel first.
      const List<String> locations = <String>[
        '/collector/dashboard',
        '/collector/projects/p1/tasks/t1',
        '/collector/sessions',
        '/checklist/t1',
        '/recording/s1',
        '/processing/s1',
      ];

      for (final String location in locations) {
        expect(
          OnboardingGuard.redirect(
            isCollector: true,
            hasSeenOnboarding: false,
            location: location,
          ),
          '/onboarding',
          reason: location,
        );
      }
    });
  });
}
