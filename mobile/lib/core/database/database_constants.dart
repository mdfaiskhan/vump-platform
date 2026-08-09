/// Fixed values for the local database.
///
/// Literals only. What varies per build belongs in `DatabaseConfig`; what is
/// true of the database in every build belongs here.
abstract final class DatabaseConstants {
  /// Name of the Isar instance, and of the file on disk.
  ///
  /// Changing this orphans the existing database: the old file is neither
  /// migrated nor deleted, and the application opens an empty one. Treat it as
  /// permanent.
  static const String databaseName = 'vump';

  /// Current schema version.
  ///
  /// Increment **only** when a change requires existing data to be
  /// transformed. Adding a collection or a nullable property does not qualify
  /// — Isar handles those implicitly.
  ///
  /// Every increment must be accompanied by a `Migration` covering the step,
  /// or opening an existing database will fail.
  static const int schemaVersion = 1;

  /// Upper bound on the database file, in mebibytes.
  ///
  /// Isar reserves virtual address space up to this size at open; it is a
  /// ceiling, not an allocation. Raising it later is safe, lowering it below
  /// the current file size is not.
  static const int maxSizeMiB = 512;

  /// Whether writes may be acknowledged before reaching disk.
  ///
  /// True trades durability under abrupt power loss for throughput. Acceptable
  /// because this database holds cached and reconstructible data — never a
  /// secret, per ADR-008, and never the sole record of a user's work.
  static const bool relaxedDurability = true;

  /// Identifier of the single metadata record.
  ///
  /// The metadata collection holds exactly one row, so its id is fixed rather
  /// than auto-incremented.
  static const int metadataId = 0;
}
