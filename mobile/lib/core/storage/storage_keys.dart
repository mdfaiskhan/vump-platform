/// Every key under which a secret may be stored.
///
/// The complete registry, per ADR-008. A secret has no home until its key is
/// declared here, and the storage API accepts nothing else — [StorageKey] is
/// the parameter type on every operation, so a call site cannot pass a string
/// literal even by accident. That is what makes the "no hardcoded secret names
/// outside this file" rule enforced by the compiler rather than by review.
///
/// [value] is the identifier written to the platform credential store. Once a
/// build has shipped, changing one orphans whatever was stored under the old
/// name: the entry is not migrated, not deleted, and no longer readable.
/// Treat these strings as permanent.
enum StorageKey {
  /// Short-lived JWT presented on API requests.
  accessToken('access_token'),

  /// Long-lived credential exchanged for a new [accessToken].
  ///
  /// The most sensitive value the application holds. Possession of it is
  /// equivalent to being signed in.
  refreshToken('refresh_token'),

  /// Push notification token issued to this device installation.
  deviceToken('device_token'),

  /// Identifier of the active session, where the backend issues one.
  sessionId('session_id'),

  /// Encryption key for the local database.
  ///
  /// ADR-008 permits an encrypted local store provided its key lives here.
  /// The inverse — a secret in an encrypted database — is forbidden, because
  /// it moves the problem rather than solving it.
  databaseEncryptionKey('database_encryption_key');

  const StorageKey(this.value);

  /// The identifier used in the platform credential store.
  final String value;
}
