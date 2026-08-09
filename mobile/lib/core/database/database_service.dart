import 'package:isar/isar.dart';

import 'package:mobile/core/database/database_config.dart';
import 'package:mobile/core/database/migrations/migration.dart';
import 'package:mobile/core/database/migrations/migration_runner.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';

/// Sole owner of the Isar instance.
///
/// Opens the database, closes it, hands out the single instance, and
/// guarantees it is opened exactly once. Per ADR-009 nothing outside
/// `core/database/` imports `isar` other than through this service.
///
/// ## Why single-open needs more than a null check
///
/// The realistic failure is two callers reaching [open] during startup before
/// either has finished. A guard on the *instance* does not prevent that —
/// both see null and both call `Isar.open`. So the service holds the in-flight
/// `Future` and hands the same one to every concurrent caller. The second
/// caller awaits the first open rather than starting its own.
///
/// ## Error boundary
///
/// No `IsarError` escapes. Failures surface as `StorageException` from the
/// Mission 0.10 taxonomy, matching the boundaries `DioClient` and
/// `SecureStorageService` maintain for their own packages.
class DatabaseService {
  DatabaseService({
    required this.config,
    required this.logger,
    this.migrations = const <Migration>[],
  });

  /// How the database is opened.
  final DatabaseConfig config;

  /// Destination for lifecycle and migration events.
  final AppLogger logger;

  /// Upgrade steps available to the migration runner.
  final List<Migration> migrations;

  Isar? _isar;
  Future<Isar>? _opening;

  /// Whether the database is open and usable.
  bool get isOpen => _isar?.isOpen ?? false;

  /// The open instance.
  ///
  /// Throws if the database has not been opened. Synchronous access is
  /// provided for code already past startup; anything that might run before
  /// the database is ready should await [open] instead.
  Isar get instance {
    final Isar? isar = _isar;
    if (isar == null || !isar.isOpen) {
      throw const StorageException(
        errorCode: ErrorCode.storageUnavailable,
        message:
            'The database has not been opened. Await open() before '
            'reading instance.',
      );
    }
    return isar;
  }

  /// Opens the database, or returns the instance already open.
  ///
  /// Safe to call repeatedly and safe to call concurrently. Runs pending
  /// migrations before returning, so a caller never receives an instance whose
  /// schema version is behind the build.
  Future<Isar> open() {
    final Isar? existing = _isar;
    if (existing != null && existing.isOpen) {
      return Future<Isar>.value(existing);
    }
    return _opening ??= _open();
  }

  /// Closes the database.
  ///
  /// Closing an already-closed database succeeds — the postcondition holds
  /// either way. Set [deleteFromDisk] to discard the file, which is intended
  /// for tests and for clearing local state on sign-out.
  Future<void> close({bool deleteFromDisk = false}) async {
    final Isar? isar = _isar;
    _isar = null;
    _opening = null;

    if (isar == null || !isar.isOpen) {
      return;
    }

    try {
      await isar.close(deleteFromDisk: deleteFromDisk);
      logger.info('Database closed${deleteFromDisk ? ' and deleted' : ''}.');
    } catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageUnavailable,
        message: 'Failed to close the database.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Isar> _open() async {
    final DateTime startedAt = DateTime.now();

    try {
      final Isar isar = await Isar.open(
        config.schemas,
        directory: config.directory,
        name: config.name,
        maxSizeMiB: config.maxSizeMiB,
        relaxedDurability: config.relaxedDurability,
        inspector: config.inspector,
      );

      await MigrationRunner(
        migrations: migrations,
        logger: logger,
      ).run(isar, targetVersion: config.schemaVersion);

      _isar = isar;

      logger.info(
        'Database "${config.name}" opened with '
        '${config.schemas.length} collection'
        '${config.schemas.length == 1 ? '' : 's'} '
        'in ${DateTime.now().difference(startedAt).inMilliseconds}ms.',
      );

      return isar;
    } on StorageException catch (error) {
      // Migration failures are already in the taxonomy. Clear the in-flight
      // future so a later attempt is not handed this failure forever.
      _opening = null;
      logger.error('Database open failed.', error: error);
      rethrow;
    } catch (error, stackTrace) {
      _opening = null;
      final StorageException exception = StorageException(
        errorCode: ErrorCode.storageUnavailable,
        message:
            'Could not open database "${config.name}" in '
            '${config.directory}.',
        cause: error,
        stackTrace: stackTrace,
      );
      logger.error('Database open failed.', error: exception);
      throw exception;
    }
  }
}
