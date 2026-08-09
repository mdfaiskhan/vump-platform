import 'package:isar/isar.dart';

import '../../errors/error_codes.dart';
import '../../errors/exceptions/storage_exception.dart';
import '../../logging/app_logger.dart';
import '../collections/database_metadata.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Brings an opened database up to the schema version the build expects.
///
/// Implements the strategy in ADR-009. Runs once, immediately after open,
/// before any caller is handed the instance.
class MigrationRunner {
  const MigrationRunner({
    required this.migrations,
    required this.logger,
  });

  /// Available upgrade steps, in any order — the runner selects and sequences
  /// the ones it needs.
  final List<Migration> migrations;

  final AppLogger logger;

  /// Reconciles the version on disk with [targetVersion].
  ///
  /// Four cases, in the order they are checked:
  ///
  /// 1. **No metadata** — a database that has never been opened. Records
  ///    [targetVersion] and runs nothing; there is no data to transform.
  /// 2. **Stored equals target** — the ordinary case. Does nothing.
  /// 3. **Stored above target** — the application was downgraded. Fails with
  ///    `storageCorrupted` rather than guessing at data written by a newer
  ///    build; interpreting an unknown schema is how data is destroyed.
  /// 4. **Stored below target** — applies each step in sequence inside a
  ///    single write transaction, then records the new version.
  Future<void> run(Isar isar, {required int targetVersion}) async {
    final DatabaseMetadata? metadata =
        await isar.databaseMetadatas.get(DatabaseConstants.metadataId);

    if (metadata == null) {
      logger.info(
        'Database initialised at schema version $targetVersion.',
      );
      await _writeVersion(isar, targetVersion);
      return;
    }

    final int current = metadata.schemaVersion;

    if (current == targetVersion) {
      return;
    }

    if (current > targetVersion) {
      throw StorageException(
        errorCode: ErrorCode.storageCorrupted,
        message: 'Database is at schema version $current but this build '
            'expects $targetVersion. The application appears to have been '
            'downgraded; refusing to interpret newer data.',
      );
    }

    await _upgrade(isar, from: current, to: targetVersion);
  }

  Future<void> _upgrade(
    Isar isar, {
    required int from,
    required int to,
  }) async {
    final List<Migration> path = _pathBetween(from: from, to: to);

    logger.info(
      'Migrating database from schema version $from to $to '
      '(${path.length} step${path.length == 1 ? '' : 's'}).',
    );

    try {
      await isar.writeTxn(() async {
        for (final Migration migration in path) {
          await migration.apply(isar);
          logger.debug(
            'Applied migration ${migration.from} → ${migration.to}.',
          );
        }
        await isar.databaseMetadatas.put(
          DatabaseMetadata(updatedAt: DateTime.now(), schemaVersion: to),
        );
      });
    } on StorageException {
      rethrow;
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageCorrupted,
        message: 'Migration from schema version $from to $to failed. '
            'The database remains at version $from.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Selects the ordered chain of steps covering [from] to [to].
  ///
  /// A missing step is a programming error caught here rather than a silent
  /// skip: an absent step means data would be left in a shape no version
  /// describes.
  List<Migration> _pathBetween({required int from, required int to}) {
    final List<Migration> path = <Migration>[];

    for (int version = from; version < to; version++) {
      final Migration? step = migrations
          .where((Migration migration) => migration.from == version)
          .firstOrNull;

      if (step == null) {
        throw StorageException(
          errorCode: ErrorCode.storageCorrupted,
          message: 'No migration is registered from schema version $version. '
              'Upgrading from $from to $to is not possible.',
        );
      }

      path.add(step);
    }

    return path;
  }

  Future<void> _writeVersion(Isar isar, int version) async {
    await isar.writeTxn(() async {
      await isar.databaseMetadatas.put(
        DatabaseMetadata(updatedAt: DateTime.now(), schemaVersion: version),
      );
    });
  }
}
