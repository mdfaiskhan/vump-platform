/// Sends a Collector who has never seen C-01 to C-01, once.
///
/// Volume 2 Chapter 2.7 places the carousel as a *"full-screen modal, shown at
/// first launch"*. Until Mission 5.4 nothing showed it: `/onboarding` was a
/// declared route with **no inbound navigation edge anywhere in `lib/`**, so
/// no Collector could reach it by any path — not a tab, not a button, not a
/// redirect. Mission 5.1.2 recorded this as a missing first-launch trigger;
/// stated as a navigation fact it is sharper, because an unreachable route is
/// an unshipped screen.
///
/// ## A pure function, like the two guards beside it
///
/// No `BuildContext`, no provider, no `GoRouter`, and — deliberately — **no
/// imports at all**. ADR-037's testability argument is the first reason: every
/// rule below is a table test with no widget tree.
///
/// The second reason is ADR-022 R2, which permits `lib/app/` to import a
/// feature's `presentation/` and nothing else. A guard taking `AuthState` or
/// `Role` would have to import `features/auth/`'s `application/` and
/// `domain/`, so this takes `isCollector` as a plain `bool` instead. The
/// router derives it through `AuthGuard.isCollector`, which already owns those
/// types. **Passing a primitive is what keeps this file on the correct side of
/// R2** — and R2 is already breached seven times elsewhere in `lib/app/`, so
/// not adding an eighth was a live concern rather than a hypothetical one.
///
/// ## Admins are excluded, and that is a reading of FR-ONB-01 worth stating
///
/// FR-ONB-01 primes Camera, Microphone, Location, Notifications and Files
/// access. **Every one is a capture permission**, and Chapter 2.4 §3's Admin
/// navigation model contains no path to a Recording Screen — an Admin never
/// records. Priming an Admin for permissions their role cannot exercise would
/// be asking for access to justify nothing.
///
/// The specification does not say "Collectors only" in those words. It places
/// C-01 in Chapter 2.4 §2, which is the *Collector* navigation model, and
/// names no Admin equivalent — so this follows where the screen is placed
/// rather than inventing a rule about who it is for.
///
/// ## What "seen" means here, and what it does not
///
/// `hasSeenOnboarding` records that the explanation was shown. **It records
/// nothing about permissions being granted**, because this project cannot
/// request four of the five and cannot read three of them at all. A Collector
/// who completes the carousel has been informed and nothing more, which is
/// exactly what the carousel does. FR-ONB-01 remains unsatisfied for that
/// reason, and this guard does not make it look otherwise.
abstract final class OnboardingGuard {
  /// C-01's route.
  static const String route = '/onboarding';

  /// Null to allow [location], or the route to send this person to instead.
  ///
  /// [isCollector] is false for an Admin and for anyone not signed in.
  /// [hasSeenOnboarding] comes from `OnboardingSeenStore`.
  static String? redirect({
    required bool isCollector,
    required bool hasSeenOnboarding,
    required String location,
  }) {
    if (!isCollector || hasSeenOnboarding) {
      return null;
    }

    // Already there. Returning the route again would be a redirect to the
    // current location, which GoRouter treats as a loop.
    if (location == route) {
      return null;
    }

    return route;
  }
}
