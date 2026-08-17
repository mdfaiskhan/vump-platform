import 'package:mobile/core/onboarding/interfaces/onboarding_seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores C-01's first-launch flag in `shared_preferences`.
///
/// ## Why this store and not `flutter_secure_storage`
///
/// The same test ADR-008 applies to every other value in this project: **it
/// holds no secret, no credential and no identifier of any person or
/// account.** One boolean about a device. Writing non-secrets into secure
/// storage would blur the rule that makes ADR-008 checkable, which is the
/// argument `SharedPreferencesWideAngleEligibilityCache`'s doc already makes
/// for the wide-angle verdict.
///
/// ## The flag is per-device, matching what the specification asks
///
/// Chapter 2.7 says *"shown at first launch"* and FR-ONB-01 says *"during
/// first launch"*. Neither says "per account", and `shared_preferences` is
/// device-scoped, so a device shared by two Collectors primes once. **That is
/// the specification's granularity, not a simplification of it** — the
/// permissions being primed are the device's, and the OS grants them to the
/// install rather than to whoever is signed in.
///
/// ## The key is versioned
///
/// `onboarding_seen_v1`. If the carousel's content ever changes enough that
/// existing users should see it again, a `_v2` key reprimes everyone without a
/// migration and without reading a stale value under the old name. The version
/// is in the key rather than in a stored payload because there is no payload —
/// the presence of `true` is the whole record.
///
/// ## Why this file is named for the package it imports
///
/// `shared_preferences` is confined by CI to a closed list, and this file is
/// on it **by name, not by directory** — the same permission shape
/// `main.dart` and `main_cleanup_probe.dart` hold. ADR-039 states the
/// convention: *"the file that may import [the package] announces it in its
/// own filename … greppable and self-declaring instead of a directory anyone
/// can drop a file into."* Nothing else under `features/onboarding/data/` may
/// import the plugin, and adding a file nearby does not acquire the right.
class SharedPreferencesOnboardingSeenStore implements OnboardingSeenStore {
  /// Creates a store over an already-resolved `SharedPreferences` instance.
  ///
  /// Taken rather than resolved here because resolving is asynchronous and
  /// [hasSeenOnboarding] is not: the router's redirect cannot await. The
  /// composition root resolves one instance before `runApp` and hands it to
  /// both this and the wide-angle cache.
  ///
  /// It also keeps the class substitutable in tests, which need only
  /// `SharedPreferences.setMockInitialValues` and no plugin.
  const SharedPreferencesOnboardingSeenStore(this._preferences);

  final SharedPreferences _preferences;

  static const String _key = 'onboarding_seen_v1';

  @override
  bool get hasSeenOnboarding => _preferences.getBool(_key) ?? false;

  @override
  Future<void> markSeen() async {
    await _preferences.setBool(_key, true);
  }
}
