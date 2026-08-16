/// The seam where C-01's first-launch flag is introduced to its readers.
///
/// Unimplemented rather than defaulted, for the reason every other port in
/// this project follows: a default would have to name a concrete class living
/// in a feature's `data/`, which `core/` may not import at all. A default of
/// `false` would be worse than a throw — it reads as "never seen", so a
/// misconfigured build would show the carousel on every single launch and look
/// like a product decision rather than a missing override.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/onboarding/interfaces/onboarding_seen_store.dart';

/// Where the "has this device seen onboarding" answer comes from.
///
/// Overridden in `main.dart` to `SharedPreferencesOnboardingSeenStore`, over
/// the same resolved `SharedPreferences` instance that backs
/// `wideAngleEligibilityCacheProvider` — one instance, two ports, which is the
/// arrangement A-067 established for this plugin at the composition root.
///
/// Read by `router.dart` with `ref.read`, never `watch`: it is consulted
/// inside GoRouter's `redirect`, and watching there would rebuild the provider
/// that owns the router.
final Provider<OnboardingSeenStore> onboardingSeenStoreProvider =
    Provider<OnboardingSeenStore>(
      (Ref ref) => throw UnimplementedError(
        'onboardingSeenStoreProvider must be overridden with an '
        'OnboardingSeenStore. features/onboarding/data/ provides '
        'SharedPreferencesOnboardingSeenStore, which implements it.',
      ),
    );
