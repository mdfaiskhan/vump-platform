import 'dart:io' show Platform;

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/features/recording/domain/entities/device_fingerprint.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_tier.dart';
import 'package:mobile/features/recording/domain/repositories/wide_angle_eligibility_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the wide-angle verdict in `shared_preferences`.
///
/// Volume 5.2 §2 asks for the zoom-factor decision to be made *"once at first
/// launch and cached"*; this is that cache.
///
/// ## Why not secure storage, and why not Isar
///
/// **Not `flutter_secure_storage`** because nothing here is a secret. ADR-008
/// governs secrets specifically, and the rule stays checkable only if
/// non-secrets stay out — three plain strings in the keystore would make
/// "what is in secure storage" stop meaning "what must be protected".
///
/// **Not Isar** because this is a single scalar triple with no relations, no
/// queries and no migrations. ADR-009 chose Isar for the structured domain
/// data of Projects, Tasks, Sessions and Chunks; a collection whose schema is
/// one row would carry a migration obligation forever for no benefit.
///
/// ## What is written
///
/// Three keys — a tier name, an app version and an OS version. **No secret,
/// no credential, no identifier of any person, account or device.** The two
/// version strings are already readable by every app on the device.
class SharedPreferencesWideAngleEligibilityCache
    implements WideAngleEligibilityCache {
  /// Creates a cache over a resolved `SharedPreferences` instance.
  ///
  /// Injected rather than resolved internally so tests can supply
  /// `SharedPreferences.setMockInitialValues`'s instance without a plugin.
  const SharedPreferencesWideAngleEligibilityCache(this._preferences);

  final SharedPreferences _preferences;

  /// Namespaced so a later feature's key cannot collide with these.
  static const String _tierKey = 'recording.wideAngle.tier';

  /// The app version the stored tier was decided under.
  static const String _appVersionKey = 'recording.wideAngle.appVersion';

  /// The OS version the stored tier was decided under.
  static const String _osVersionKey = 'recording.wideAngle.osVersion';

  /// The platform's version string, for building a [DeviceFingerprint].
  ///
  /// `dart:io` rather than a plugin: `device_info_plus` would add a
  /// dependency, an ADR-030 admission and a confinement entry to obtain a
  /// string the SDK already has. Volume 3 §3.8's minimal-surface principle
  /// is the reason to prefer the one that costs nothing.
  static String get currentOsVersion => Platform.operatingSystemVersion;

  @override
  Future<WideAngleTier?> read(DeviceFingerprint fingerprint) async {
    final String? storedApp = _preferences.getString(_appVersionKey);
    final String? storedOs = _preferences.getString(_osVersionKey);

    // Stale, or never written. Either way the caller re-probes, so the two
    // are not distinguished — see the port's documentation.
    if (storedApp != fingerprint.appVersion ||
        storedOs != fingerprint.osVersion) {
      return null;
    }

    // An unrecognised key returns null too: it means the tier vocabulary
    // changed under a stored value, and re-probing is safer than guessing.
    return WideAngleTier.fromStorageKey(_preferences.getString(_tierKey));
  }

  @override
  Future<void> write({
    required WideAngleTier tier,
    required DeviceFingerprint fingerprint,
  }) async {
    try {
      // Versions first, tier last. A crash between writes then leaves a
      // fingerprint with no tier, which `read` reports as absent — whereas
      // the reverse order could leave a new tier stamped with an old
      // fingerprint and be read back as valid.
      await _preferences.setString(_appVersionKey, fingerprint.appVersion);
      await _preferences.setString(_osVersionKey, fingerprint.osVersion);
      await _preferences.setString(_tierKey, tier.storageKey);
    } on Exception catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageWriteFailed,
        message: 'The wide-angle eligibility verdict could not be saved.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _preferences.remove(_tierKey);
      await _preferences.remove(_appVersionKey);
      await _preferences.remove(_osVersionKey);
    } on Exception catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageDeleteFailed,
        message: 'The wide-angle eligibility verdict could not be cleared.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
