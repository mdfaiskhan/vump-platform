import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/data/shared_preferences_onboarding_seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C-01's first-launch flag, and the two properties that make it a trigger.
///
/// A flag that does not default to false shows the carousel to nobody; a flag
/// that does not survive a restart shows it on every launch. Both failures
/// look like a product decision rather than a bug, so both are asserted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferencesOnboardingSeenStore> build([
    Map<String, Object> initial = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferencesOnboardingSeenStore(
      await SharedPreferences.getInstance(),
    );
  }

  test('a fresh install has not seen onboarding', () async {
    final SharedPreferencesOnboardingSeenStore store = await build();

    // The default matters more than it looks: `getBool` returns null for an
    // absent key, and a null coalesced the other way would skip C-01 for
    // every user who has never run it — which is everyone, once.
    expect(store.hasSeenOnboarding, isFalse);
  });

  test('markSeen is visible immediately, without awaiting a reload', () async {
    final SharedPreferencesOnboardingSeenStore store = await build();

    await store.markSeen();

    // The router's redirect reads this synchronously right after the write
    // completes. If the value were only visible after re-resolving the
    // instance, completing the carousel would navigate back into it.
    expect(store.hasSeenOnboarding, isTrue);
  });

  test('the flag survives a restart', () async {
    final SharedPreferencesOnboardingSeenStore first = await build();
    await first.markSeen();

    // A second instance over the same backing store is what the next cold
    // start sees.
    final SharedPreferencesOnboardingSeenStore second =
        SharedPreferencesOnboardingSeenStore(
          await SharedPreferences.getInstance(),
        );

    expect(second.hasSeenOnboarding, isTrue);
  });

  test('an unrelated stored value does not read as seen', () async {
    // Guards the key rather than the behaviour: the store must answer for
    // `onboarding_seen_v1` and nothing else, so a neighbouring preference --
    // the wide-angle cache shares this instance -- cannot flip it.
    final SharedPreferencesOnboardingSeenStore store = await build(
      <String, Object>{'wide_angle_tier': 'ultraWide'},
    );

    expect(store.hasSeenOnboarding, isFalse);
  });
}
