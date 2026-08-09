import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/environment/environment_profile.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/network/network_config.dart';

/// `firebaseProjectId` is deliberately untested here: it reads
/// `DefaultFirebaseOptions.currentPlatform`, which depends on a platform the
/// test host does not provide. Everything else is pure.
void main() {
  group('EnvironmentProfile exposes every required value', () {
    test('for all three environments, nothing is missing or empty', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        final EnvironmentProfile profile = EnvironmentProfile(environment);

        expect(profile.apiBaseUrl, isNotEmpty);
        expect(profile.chunkBucket, isNotEmpty);
        expect(profile.logLevel, isNotNull);
        expect(profile.featureFlags, isNotNull);
        // CloudFront is not provisioned; null is the correct answer, not a gap.
        expect(profile.cloudFrontDomain, isNull);
      }
    });

    test('current resolves to the compiled environment', () {
      expect(EnvironmentProfile.current.environment, AppConfig.environment);
    });
  });

  group('the profile delegates and never defines', () {
    // These are the tests that matter. If someone gives the profile its own
    // copy of a value, it will drift from the owner and these will catch it.

    test('apiBaseUrl equals the owner NetworkConfig', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        expect(
          EnvironmentProfile(environment).apiBaseUrl,
          NetworkConfig.baseUrlFor(environment),
        );
      }
    });

    test('chunkBucket equals the owner NetworkConfig', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        expect(
          EnvironmentProfile(environment).chunkBucket,
          NetworkConfig.chunkBucketFor(environment),
        );
      }
    });

    test('logLevel equals the owner AppLogger', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        expect(
          EnvironmentProfile(environment).logLevel,
          AppLogger.minimumLevelFor(environment),
        );
      }
    });

    test('featureFlags equal the owner AppFeatureFlags', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        final AppFeatureFlags viaProfile = EnvironmentProfile(
          environment,
        ).featureFlags;
        final AppFeatureFlags viaOwner = AppFeatureFlags.forEnvironment(
          environment,
        );
        expect(
          viaProfile.databaseInspectorEnabled,
          viaOwner.databaseInspectorEnabled,
        );
        expect(
          viaProfile.firebaseFailureIsFatal,
          viaOwner.firebaseFailureIsFatal,
        );
      }
    });
  });

  group('environments cannot collide', () {
    test('no two environments share an API endpoint', () {
      final Set<String> urls = AppEnvironment.values
          .map((AppEnvironment e) => EnvironmentProfile(e).apiBaseUrl)
          .toSet();
      expect(
        urls,
        hasLength(AppEnvironment.values.length),
        reason: 'a shared endpoint lets one environment write to another',
      );
    });

    test('no two environments share a bucket', () {
      final Set<String> buckets = AppEnvironment.values
          .map((AppEnvironment e) => EnvironmentProfile(e).chunkBucket)
          .toSet();
      expect(
        buckets,
        hasLength(AppEnvironment.values.length),
        reason: 'a shared bucket puts test data among real recordings',
      );
    });

    test('describe() names the environment and never leaks a credential', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        final String described = EnvironmentProfile(environment).describe();
        expect(described, contains(environment.label));
        expect(described, contains(NetworkConfig.chunkBucketFor(environment)));
        expect(described, isNot(matches(RegExp(r'(AKIA|ASIA)[0-9A-Z]{16}'))));
      }
    });
  });
}
