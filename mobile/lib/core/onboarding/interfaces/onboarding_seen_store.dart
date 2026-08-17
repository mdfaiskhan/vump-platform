/// Whether this device has already been shown C-01's priming carousel.
///
/// Volume 2 Chapter 2.7 places C-01 as a *"full-screen modal, shown at first
/// launch"*, and FR-ONB-01 asks for the permission requests *"during first
/// launch"*. Both sentences need something that remembers a launch happened;
/// nothing in this project did, so `/onboarding` was declared as a route with
/// **no inbound navigation edge from anywhere in `lib/`** — an unreachable
/// screen, which is to say an unshipped one.
///
/// ## Why the read is synchronous and the write is not
///
/// [hasSeenOnboarding] is a getter, not a `Future`. `OnboardingGuard` is
/// consulted from GoRouter's `redirect`, which is synchronous and cannot await:
/// a redirect that returned a future would have to guess while it resolved,
/// and a guess here is a carousel shown twice or never. The implementation
/// therefore reads an already-resolved store rather than opening one, the same
/// arrangement `SharedPreferencesWideAngleEligibilityCache` uses and for the
/// same reason.
///
/// [markSeen] is asynchronous because persisting genuinely is. Its caller
/// awaits it before navigating, so the redirect that follows observes the new
/// value rather than racing it.
///
/// ## Why it lives in `core/` — and where that stretches ADR-040
///
/// ADR-022 R2 permits `lib/app/` to import a feature's `presentation/` and
/// **nothing else**: *"`router.dart` may name a screen; it may not import a
/// feature's `domain/`, `data/` or `application/`."* The guard needs a fact
/// owned by `features/onboarding/`, so declaring this contract inside that
/// feature would have forced the router across the line R2 draws.
///
/// `core/` is the neutral ground both sides may already import, which is
/// ADR-040's pattern — contract in `core/`, implementation in a feature,
/// the two introduced by the composition root.
///
/// **ADR-040 does not actually name this relationship.** Its stated shape is
/// *feature ↔ feature*: two modules that must not know about each other. Here
/// the consumer is `app/`, not a second feature. The pattern transfers
/// cleanly, but the citation does not — this is ADR-040 applied by analogy,
/// and whether `app/ ↔ feature` belongs inside ADR-040 or in a clarifying
/// record of its own is left open rather than settled by pointing at a
/// decision that did not consider it.
///
/// ## What is deliberately not here
///
/// No permission state. The carousel primes five permissions and requests
/// none of them — this project has no permission plugin, so Location,
/// Notifications and Files access cannot be read or requested at all
/// (`OnboardingCarouselScreen` states this in full). **This contract answers
/// "was the explanation shown", never "was anything granted."** Conflating the
/// two would let a device that dismissed the carousel look permitted.
abstract interface class OnboardingSeenStore {
  /// Whether the carousel has already run to completion on this device.
  ///
  /// False on a fresh install, and false for a device whose storage was
  /// cleared — both are first launches as far as Chapter 2.7 is concerned.
  bool get hasSeenOnboarding;

  /// Records that the carousel finished, so it does not run again.
  ///
  /// Called from the last card's "Get Started", which is the only completion
  /// Chapter 2.7 defines. Skipping is not a state this project has.
  Future<void> markSeen();
}
