import 'package:isar/isar.dart';

import 'package:mobile/core/database/collections/database_metadata.dart';
import 'package:mobile/core/database/database_constants.dart';

/// How the database is opened.
///
/// Separated from `DatabaseService` so that *what the database is* can change
/// without touching the code that opens it.
///
/// [directory] has no default. Resolving a writable application directory
/// needs a platform plugin the project does not depend on, so the path is
/// supplied from outside — see `databaseDirectoryProvider`. Guessing a path
/// here would be wrong on at least one platform.
class DatabaseConfig {
  const DatabaseConfig({
    required this.directory,
    this.schemas = coreSchemas,
    this.name = DatabaseConstants.databaseName,
    this.schemaVersion = DatabaseConstants.schemaVersion,
    this.maxSizeMiB = DatabaseConstants.maxSizeMiB,
    this.relaxedDurability = DatabaseConstants.relaxedDurability,
    this.inspector = false,
  });

  /// Writable directory the database file lives in.
  final String directory;

  /// Every collection schema the instance is opened with.
  ///
  /// Isar requires the complete set at open time. Rather than a literal list
  /// inside the service — which would make every new feature edit shared code
  /// — the set is configuration, and a feature contributes its schema by
  /// overriding the provider that supplies this object.
  ///
  /// Adding a collection therefore changes no existing file.
  final List<CollectionSchema<dynamic>> schemas;

  /// Instance name, and the filename on disk.
  final String name;

  /// Schema version this build expects on disk.
  final int schemaVersion;

  /// Ceiling on the database file size, in mebibytes.
  final int maxSizeMiB;

  /// Whether writes may be acknowledged before reaching disk.
  final bool relaxedDurability;

  /// Whether to expose the Isar Inspector.
  ///
  /// Off by default. The inspector opens a debugging channel into the
  /// database, which should be an explicit choice rather than something a
  /// build inherits.
  final bool inspector;

  /// Schemas owned by `core/database/` itself.
  ///
  /// Present in every configuration. [DatabaseMetadataSchema] backs the
  /// version tracking in ADR-009 and is infrastructure, not a feature model.
  static const List<CollectionSchema<dynamic>> coreSchemas =
      <CollectionSchema<dynamic>>[DatabaseMetadataSchema];

  /// Returns a copy with [schemas] appended to [coreSchemas].
  ///
  /// The intended way for a composition root to register feature collections:
  ///
  /// ```dart
  /// databaseConfigProvider.overrideWith(
  ///   (Ref<DatabaseConfig> ref) => DatabaseConfig(
  ///     directory: path,
  ///   ).withSchemas(<CollectionSchema<dynamic>>[RecordingSchema]),
  /// )
  /// ```
  DatabaseConfig withSchemas(List<CollectionSchema<dynamic>> schemas) {
    return DatabaseConfig(
      directory: directory,
      schemas: <CollectionSchema<dynamic>>[...this.schemas, ...schemas],
      name: name,
      schemaVersion: schemaVersion,
      maxSizeMiB: maxSizeMiB,
      relaxedDurability: relaxedDurability,
      inspector: inspector,
    );
  }
}
