import 'package:isar/isar.dart';

import 'package:mobile/core/database/database_constants.dart';

part 'database_metadata.g.dart';

/// Bookkeeping the database keeps about itself.
///
/// Infrastructure, not a feature model. It exists so the schema version last
/// written to disk can be compared against the version this build expects, per
/// ADR-009. Nothing outside `core/database/` reads or writes it.
///
/// Exactly one row, at [DatabaseConstants.metadataId].
@collection
class DatabaseMetadata {
  DatabaseMetadata({
    required this.updatedAt,
    this.id = DatabaseConstants.metadataId,
    this.schemaVersion = DatabaseConstants.schemaVersion,
  });

  /// Fixed identifier. There is only ever one metadata record.
  Id id;

  /// Schema version of the data currently on disk.
  ///
  /// Compared against [DatabaseConstants.schemaVersion] at open. Lower means
  /// migrations are pending; higher means the application was downgraded and
  /// cannot safely interpret what it finds.
  int schemaVersion;

  /// When this record was last written.
  ///
  /// Diagnostic only — it makes a migration visible in a support log.
  DateTime updatedAt;
}
