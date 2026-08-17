import 'package:mobile/core/onboarding/interfaces/onboarding_seen_store.dart';

/// An in-memory [OnboardingSeenStore] for tests that build the router.
///
/// `onboardingSeenStoreProvider` throws until overridden, so every test that
/// reads the real route table needs one of these — the redirect consults it on
/// each navigation. Defaults to `seen` `true`, because most such tests are
/// about something else entirely (auth redirects, sign-out, signup) and would
/// otherwise be dragged onto `/onboarding` before reaching their subject.
///
/// A test *about* onboarding constructs it with `seen: false` and says so.
class FakeOnboardingSeenStore implements OnboardingSeenStore {
  /// Creates a store already marked seen unless [seen] says otherwise.
  FakeOnboardingSeenStore({this.seen = true});

  /// Whether the carousel has already run. Mutated by [markSeen].
  bool seen;

  /// How many times [markSeen] was called.
  ///
  /// Distinguishes "the flag ended up true" from "the screen set it", which a
  /// store constructed with `seen: true` would otherwise conflate.
  int markSeenCalls = 0;

  @override
  bool get hasSeenOnboarding => seen;

  @override
  Future<void> markSeen() async {
    markSeenCalls++;
    seen = true;
  }
}
