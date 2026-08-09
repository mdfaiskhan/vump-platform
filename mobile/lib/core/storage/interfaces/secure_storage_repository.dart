import 'package:mobile/core/storage/storage_keys.dart';

/// Contract for reading and writing secrets.
///
/// The only type any feature may depend on for secret storage. Per ADR-008 no
/// code outside `core/storage/` imports `flutter_secure_storage`; it imports
/// this interface instead. Replacing the storage backend — a different
/// package, a hardware-backed key, a platform channel — then means writing one
/// new implementation, with no call site changing.
///
/// Pure Dart by design. ADR-001 requires that `domain` depend on nothing
/// outside itself, and a repository interface declared in `domain` may be
/// satisfied by an implementation of this contract.
///
/// Every operation is asynchronous, because both platform credential stores
/// are. ADR-008 records the consequence: a session cannot be resolved
/// synchronously before `runApp`.
///
/// Implementations must never allow a platform exception to escape. Failures
/// surface as `StorageException` from the Mission 0.10 taxonomy.
abstract interface class SecureStorageRepository {
  /// Returns the value stored under [key], or null if nothing is stored.
  ///
  /// A missing key is not an error — it is the normal state before a user
  /// signs in. Only a failure of the store itself throws.
  Future<String?> read(StorageKey key);

  /// Stores [value] under [key], replacing anything already there.
  ///
  /// Passing null deletes the entry, matching the underlying platform
  /// behaviour rather than writing the string `"null"`.
  Future<void> write(StorageKey key, String? value);

  /// Removes the entry stored under [key].
  ///
  /// Deleting an absent key succeeds. The postcondition is that nothing is
  /// stored under [key], which already holds.
  Future<void> delete(StorageKey key);

  /// Removes every entry this application has stored.
  ///
  /// Intended for sign-out, and for clearing credentials left behind by a
  /// previous installation — ADR-008 records that iOS Keychain entries survive
  /// app uninstall.
  Future<void> deleteAll();

  /// Whether anything is stored under [key].
  ///
  /// Prefer [read] when the value is wanted: this performs the same platform
  /// round trip and then discards the result.
  Future<bool> containsKey(StorageKey key);
}
