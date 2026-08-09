import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/logging/log_level.dart';
import 'package:mobile/core/network/network_config.dart';

/// `AppConfig.environment` is a compile-time constant, so a test process can
/// only ever observe the value it was compiled with — `development`, since
/// `flutter test` passes no `--dart-define`.
///
/// These tests therefore verify the two things that *are* testable and that
/// actually matter: that the default is the safe one, and that every value
/// the application derives from an environment is derived correctly for
/// **all three** environments, not just the one the test process happens to
/// be running as.
void main() {
  group('APP_ENV resolution', () {
    test('an undeclared APP_ENV resolves to development', () {
      // ADR-007: an undeclared build is a developer's machine. Defaulting to
      // production would point an unverified build at live infrastructure.
      expect(AppConfig.environment, AppEnvironment.development);
      expect(AppConfig.rawEnvironmentValue, 'development');
    });

    test('an absent APP_ENV is not treated as a mistake', () {
      // Absence is the documented default; only a *wrong* value is a typo
      // worth warning about.
      expect(AppConfig.environmentWasRecognised, isTrue);
    });

    test('every environment key round-trips to its own case', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        final Iterable<AppEnvironment> matches = AppEnvironment.values.where(
          (AppEnvironment e) => e.key == environment.key,
        );
        expect(matches, hasLength(1), reason: 'keys must be unique');
      }
    });

    test('keys are exactly the three documented tokens', () {
      expect(AppEnvironment.values.map((AppEnvironment e) => e.key), <String>[
        'development',
        'staging',
        'production',
      ]);
    });
  });

  group('values derived from the environment', () {
    test('every environment has a distinct API base URL', () {
      final Set<String> urls = AppEnvironment.values
          .map(NetworkConfig.baseUrlFor)
          .toSet();
      expect(
        urls,
        hasLength(AppEnvironment.values.length),
        reason: 'two environments sharing a base URL would let one write to '
            'the other',
      );
    });

    test('no base URL is a placeholder in disguise', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        final String url = NetworkConfig.baseUrlFor(environment);
        expect(url, startsWith('https://'), reason: 'plaintext is forbidden');
        expect(url, isNot(endsWith('/')), reason: 'no trailing slash');
      }
    });

    test('bucket names follow the ADR-011 rule for every environment', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        expect(
          NetworkConfig.chunkBucketFor(environment),
          'vump-platform-${environment.slug}',
        );
      }
    });

    test('bucket slugs match the buckets that actually exist', () {
      // S3 bucket names are immutable. If these drift from AWS, uploads break
      // in a way that is invisible until runtime.
      expect(
        AppEnvironment.values.map(NetworkConfig.chunkBucketFor),
        <String>[
          'vump-platform-dev',
          'vump-platform-staging',
          'vump-platform-prod',
        ],
      );
    });

    test('logging verbosity narrows as the environment gets more real', () {
      expect(
        AppLogger.minimumLevelFor(AppEnvironment.development),
        LogLevel.debug,
      );
      expect(AppLogger.minimumLevelFor(AppEnvironment.staging), LogLevel.info);
      expect(
        AppLogger.minimumLevelFor(AppEnvironment.production),
        LogLevel.warning,
      );
    });
  });

  group('feature flags', () {
    test('the database inspector is exposed only in development', () {
      expect(
        AppFeatureFlags.forEnvironment(
          AppEnvironment.development,
        ).databaseInspectorEnabled,
        isTrue,
      );
      for (final AppEnvironment environment in <AppEnvironment>[
        AppEnvironment.staging,
        AppEnvironment.production,
      ]) {
        expect(
          AppFeatureFlags.forEnvironment(environment).databaseInspectorEnabled,
          isFalse,
          reason: 'the inspector is a debugging channel into stored data',
        );
      }
    });

    test('Firebase failure is fatal everywhere except development', () {
      expect(
        AppFeatureFlags.forEnvironment(
          AppEnvironment.development,
        ).firebaseFailureIsFatal,
        isFalse,
      );
      expect(
        AppFeatureFlags.forEnvironment(
          AppEnvironment.staging,
        ).firebaseFailureIsFatal,
        isTrue,
      );
      expect(
        AppFeatureFlags.forEnvironment(
          AppEnvironment.production,
        ).firebaseFailureIsFatal,
        isTrue,
      );
    });

    test('flags resolve for every environment without throwing', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        expect(() => AppFeatureFlags.forEnvironment(environment), returnsNormally);
      }
    });
  });
}
