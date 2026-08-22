import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/features/recording/data/shared_preferences_wide_angle_eligibility_cache.dart';
import 'package:mobile/features/recording/domain/entities/device_fingerprint.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_tier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A `SharedPreferences` whose writes fail.
///
/// `SharedPreferences.setMockInitialValues` gives a real instance backed by an
/// in-memory map, which is what every other test here wants and is exactly why
/// the error paths were unreachable: that instance does not fail. Mission 8.1
/// installed `mocktail` for this — Volume 3 §3.1 named it and the project had
/// been hand-rolling doubles instead.
class _FailingPreferences extends Mock implements SharedPreferences {}

/// The cache Volume 5.2 §2 requires, and its invalidation rule.
///
/// The assertions worth having are the invalidation ones: a cache that never
/// goes stale is a cache that pins a wrong verdict to a device forever, and a
/// cache that always goes stale re-opens the camera every launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const DeviceFingerprint v1 = DeviceFingerprint(
    appVersion: '1.0.0+1',
    osVersion: 'Android 14',
  );

  Future<SharedPreferencesWideAngleEligibilityCache> build([
    Map<String, Object> initial = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferencesWideAngleEligibilityCache(
      await SharedPreferences.getInstance(),
    );
  }

  group('a verdict survives a restart', () {
    test('what was written is what is read back', () async {
      final SharedPreferencesWideAngleEligibilityCache cache = await build();

      await cache.write(tier: WideAngleTier.primarySensorZoom, fingerprint: v1);

      expect(await cache.read(v1), WideAngleTier.primarySensorZoom);
    });

    test('each tier round-trips', () async {
      for (final WideAngleTier tier in WideAngleTier.values) {
        final SharedPreferencesWideAngleEligibilityCache cache = await build();
        await cache.write(tier: tier, fingerprint: v1);

        expect(await cache.read(v1), tier, reason: tier.name);
      }
    });

    test('a blocked verdict is cached too, not only an eligible one', () async {
      // Tier 3 must not re-probe every launch. Opening the camera repeatedly
      // on a device already known to be ineligible is the cost §2 avoids.
      final SharedPreferencesWideAngleEligibilityCache cache = await build();
      await cache.write(tier: WideAngleTier.unsupported, fingerprint: v1);

      expect(await cache.read(v1), WideAngleTier.unsupported);
    });
  });

  group('nothing cached yet', () {
    test('an empty store reads null', () async {
      final SharedPreferencesWideAngleEligibilityCache cache = await build();

      expect(await cache.read(v1), isNull);
    });
  });

  group('invalidation is by fingerprint, not by time', () {
    test('a new app version invalidates', () async {
      final SharedPreferencesWideAngleEligibilityCache cache = await build();
      await cache.write(tier: WideAngleTier.opticalDedicated, fingerprint: v1);

      const DeviceFingerprint upgraded = DeviceFingerprint(
        appVersion: '1.1.0+7',
        osVersion: 'Android 14',
      );

      expect(
        await cache.read(upgraded),
        isNull,
        reason: 'a new build may carry a new ladder, so the verdict re-runs',
      );
    });

    test('a new OS version invalidates', () async {
      final SharedPreferencesWideAngleEligibilityCache cache = await build();
      await cache.write(tier: WideAngleTier.unsupported, fingerprint: v1);

      const DeviceFingerprint upgraded = DeviceFingerprint(
        appVersion: '1.0.0+1',
        osVersion: 'Android 15',
      );

      expect(
        await cache.read(upgraded),
        isNull,
        reason:
            'CameraX gains and loses capabilities across releases, so a '
            'device that could not zoom out before may now',
      );
    });

    test('an unchanged fingerprint does NOT invalidate', () async {
      // The mutation this catches: an invalidation rule that always fires
      // would pass every test above except this one, and would re-open the
      // camera on every single launch.
      final SharedPreferencesWideAngleEligibilityCache cache = await build();
      await cache.write(tier: WideAngleTier.primarySensorZoom, fingerprint: v1);

      expect(await cache.read(v1), isNotNull);
      expect(await cache.read(v1), isNotNull);
      expect(await cache.read(v1), WideAngleTier.primarySensorZoom);
    });

    test('a re-probe overwrites rather than accumulating', () async {
      final SharedPreferencesWideAngleEligibilityCache cache = await build();
      await cache.write(tier: WideAngleTier.unsupported, fingerprint: v1);

      const DeviceFingerprint v2 = DeviceFingerprint(
        appVersion: '2.0.0+1',
        osVersion: 'Android 14',
      );
      await cache.write(tier: WideAngleTier.opticalDedicated, fingerprint: v2);

      expect(await cache.read(v2), WideAngleTier.opticalDedicated);
      expect(await cache.read(v1), isNull, reason: 'the old verdict is gone');
    });
  });

  group('a store written by a different version of the code', () {
    test('an unrecognised tier key re-probes rather than guessing', () async {
      final SharedPreferencesWideAngleEligibilityCache cache =
          await build(<String, Object>{
            'flutter.recording.wideAngle.tier': 'SOME_RETIRED_TIER',
            'flutter.recording.wideAngle.appVersion': '1.0.0+1',
            'flutter.recording.wideAngle.osVersion': 'Android 14',
          });

      expect(await cache.read(v1), isNull);
    });

    test('a fingerprint with no tier reads as absent', () async {
      // The half-written state `write` is ordered to produce if it is
      // interrupted: versions stored, tier not yet.
      final SharedPreferencesWideAngleEligibilityCache cache =
          await build(<String, Object>{
            'flutter.recording.wideAngle.appVersion': '1.0.0+1',
            'flutter.recording.wideAngle.osVersion': 'Android 14',
          });

      expect(await cache.read(v1), isNull);
    });
  });

  group('clearing', () {
    test('clear forgets the verdict', () async {
      final SharedPreferencesWideAngleEligibilityCache cache = await build();
      await cache.write(tier: WideAngleTier.opticalDedicated, fingerprint: v1);

      await cache.clear();

      expect(await cache.read(v1), isNull);
    });

    test('clearing an empty store is not an error', () async {
      final SharedPreferencesWideAngleEligibilityCache cache = await build();

      await expectLater(cache.clear(), completes);
    });
  });

  group('what is stored', () {
    test('exactly three keys, all non-sensitive', () async {
      // Volume 8 forbids secrets in unencrypted storage. This asserts the
      // shape of what lands there, so a later field cannot be added without
      // this test noticing.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final SharedPreferencesWideAngleEligibilityCache cache =
          SharedPreferencesWideAngleEligibilityCache(preferences);

      await cache.write(tier: WideAngleTier.primarySensorZoom, fingerprint: v1);

      expect(preferences.getKeys(), <String>{
        'recording.wideAngle.tier',
        'recording.wideAngle.appVersion',
        'recording.wideAngle.osVersion',
      });
      expect(
        preferences.getString('recording.wideAngle.tier'),
        'PRIMARY_SENSOR_ZOOM',
        reason: 'the stored key is stable across enum renames',
      );
    });

    test('the storage key survives an enum rename', () {
      // WideAngleTier.storageKey exists so that renaming a constant is a
      // refactor rather than a field-wide cache invalidation.
      expect(
        WideAngleTier.fromStorageKey('OPTICAL_DEDICATED'),
        WideAngleTier.opticalDedicated,
      );
      expect(WideAngleTier.fromStorageKey('nonsense'), isNull);
      expect(WideAngleTier.fromStorageKey(null), isNull);
    });
  });

  group('the error taxonomy', () {
    test('StorageException codes are the write/delete ones', () {
      // Asserted as a pair so the two paths cannot silently share one code.
      expect(ErrorCode.storageWriteFailed.code, 'STORAGE_WRITE_FAILED');
      expect(ErrorCode.storageDeleteFailed.code, 'STORAGE_DELETE_FAILED');
    });
  });

  /// The paths that run when the platform refuses.
  ///
  /// testing-standards.md:239 records that Chapter 9.5 §2's data-layer target
  /// is *"focused on error-path coverage … not just the happy path"*, so a
  /// repository at 80% covering only success does not meet it. These four
  /// lines were the whole of this file's shortfall and all four are failures.
  group('when the platform refuses', () {
    late _FailingPreferences preferences;
    late SharedPreferencesWideAngleEligibilityCache cache;

    setUp(() {
      preferences = _FailingPreferences();
      cache = SharedPreferencesWideAngleEligibilityCache(preferences);
    });

    test(
      'a failed write raises storageWriteFailed, not the platform error',
      () async {
        final Exception cause = Exception('the platform store is unavailable');
        when(() => preferences.setString(any(), any())).thenThrow(cause);

        await expectLater(
          () => cache.write(
            tier: WideAngleTier.primarySensorZoom,
            fingerprint: v1,
          ),
          throwsA(
            isA<StorageException>()
                .having(
                  (StorageException e) => e.errorCode,
                  'errorCode',
                  ErrorCode.storageWriteFailed,
                )
                // The cause is kept, not discarded: ADR-025 §7 converts
                // a third-party failure at the module that owns it, and a
                // conversion dropping the original leaves nothing to
                // diagnose.
                .having((StorageException e) => e.cause, 'cause', cause),
          ),
        );
      },
    );

    test(
      'a failed clear raises storageDeleteFailed, a distinct code',
      () async {
        when(() => preferences.remove(any())).thenThrow(Exception('locked'));

        await expectLater(
          cache.clear,
          throwsA(
            isA<StorageException>().having(
              (StorageException e) => e.errorCode,
              'errorCode',
              ErrorCode.storageDeleteFailed,
            ),
          ),
        );
      },
    );

    test(
      'the failure message names the verdict, not the storage key',
      () async {
        // The message reaches a person. A key name would tell them nothing.
        when(
          () => preferences.setString(any(), any()),
        ).thenThrow(Exception('x'));

        try {
          await cache.write(
            tier: WideAngleTier.primarySensorZoom,
            fingerprint: v1,
          );
          fail('write should have thrown');
        } on StorageException catch (error) {
          expect(error.message, contains('wide-angle eligibility verdict'));
          expect(error.message, isNot(contains('_tier')));
        }
      },
    );
  });

  test('currentOsVersion reads the platform rather than a stored value', () {
    // Volume 3 §3.8's minimal-surface principle is why this is `dart:io` and
    // not `device_info_plus`; the assertion is only that it is sourced at all,
    // because the value itself is whatever host the suite runs on.
    expect(
      SharedPreferencesWideAngleEligibilityCache.currentOsVersion,
      isNotEmpty,
    );
  });
}
