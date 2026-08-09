import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/core/storage/interfaces/secure_storage_repository.dart';
import 'package:mobile/core/storage/storage_keys.dart';

/// Platform-backed implementation of [SecureStorageRepository].
///
/// **The only file in the application that imports `flutter_secure_storage`.**
/// ADR-008 makes that a rule rather than an accident: an import of the package
/// anywhere under `lib/features/`, `lib/app/` or `lib/shared/` is a defect.
///
/// Secrets are delegated to the operating system's credential store — the
/// Keychain on iOS and macOS, `EncryptedSharedPreferences` backed by the
/// Keystore on Android — so key material is protected by the platform rather
/// than by application code.
///
/// ## Error boundary
///
/// No `PlatformException` escapes this class. Every operation converts
/// platform failures into `StorageException` from the Mission 0.10 taxonomy,
/// mirroring the guarantee `DioClient` makes for `DioException`. A caller
/// catches one exception type and never learns which package is underneath.
///
/// ## What this class does not do
///
/// It does not cache. ADR-008 notes that a Keychain round trip costs
/// milliseconds and that hot values should be held in memory, but a cache
/// needs an invalidation rule, and inventing one here would guess at how
/// authentication will behave.
///
/// It does not clear storage on first run after install. ADR-008 records that
/// iOS Keychain entries survive uninstall and that the fix is a non-secret
/// flag in ordinary preferences — which requires a preferences dependency the
/// project does not yet have. [deleteAll] is the mechanism; the trigger is not
/// wired.
class SecureStorageService implements SecureStorageRepository {
  /// Creates a service over [storage], defaulting to platform-backed storage
  /// configured with [defaultAndroidOptions] and [defaultIosOptions].
  ///
  /// The parameter exists so tests can substitute a fake without reaching the
  /// platform channels, which are unavailable under `flutter test`.
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: defaultAndroidOptions,
            iOptions: defaultIosOptions,
          );

  final FlutterSecureStorage _storage;

  /// Routes Android storage through `EncryptedSharedPreferences`.
  ///
  /// Off by default in the package, which would fall back to a weaker scheme.
  /// ADR-008 records the constraint this imposes: **minSdk 23**.
  static const AndroidOptions defaultAndroidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  /// Restricts Keychain items to this device, readable after first unlock.
  ///
  /// `first_unlock_this_device` rather than `unlocked`, so a token remains
  /// readable during background work while the screen is locked.
  /// `_this_device` prevents the item migrating to a new device through an
  /// iCloud Keychain backup.
  static const IOSOptions defaultIosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  @override
  Future<String?> read(StorageKey key) {
    return _guard(
      errorCode: ErrorCode.storageReadFailed,
      description: 'read ${key.value}',
      action: () => _storage.read(key: key.value),
    );
  }

  @override
  Future<void> write(StorageKey key, String? value) {
    return _guard(
      errorCode: ErrorCode.storageWriteFailed,
      description: 'write ${key.value}',
      action: () => _storage.write(key: key.value, value: value),
    );
  }

  @override
  Future<void> delete(StorageKey key) {
    return _guard(
      errorCode: ErrorCode.storageDeleteFailed,
      description: 'delete ${key.value}',
      action: () => _storage.delete(key: key.value),
    );
  }

  @override
  Future<void> deleteAll() {
    return _guard(
      errorCode: ErrorCode.storageDeleteFailed,
      description: 'delete all entries',
      action: () => _storage.deleteAll(),
    );
  }

  @override
  Future<bool> containsKey(StorageKey key) {
    return _guard(
      errorCode: ErrorCode.storageReadFailed,
      description: 'check for ${key.value}',
      action: () => _storage.containsKey(key: key.value),
    );
  }

  /// Runs [action], converting any failure into a `StorageException`.
  ///
  /// [description] names the attempted operation for the log, and is safe to
  /// record: it contains the storage *key*, never the value stored under it.
  /// ADR-007 and ADR-008 both forbid a secret reaching a log, and an exception
  /// message is a log line waiting to happen.
  Future<T> _guard<T>({
    required ErrorCode errorCode,
    required String description,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on MissingPluginException catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageUnavailable,
        message:
            'Secure storage is unavailable on this platform; '
            'could not $description.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on PlatformException catch (error, stackTrace) {
      throw StorageException(
        errorCode: errorCode,
        message:
            'Secure storage failed to $description '
            '(platform code: ${error.code}).',
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: errorCode,
        message: 'Secure storage failed to $description.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
