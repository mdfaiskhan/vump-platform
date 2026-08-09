import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/database/database_config.dart';
import 'package:mobile/core/database/database_service.dart';
import 'package:mobile/core/database/migrations/migration.dart';
import 'package:mobile/core/logging/providers/logger_provider.dart';

/// Writable directory the database file lives in.
///
/// **Must be overridden before the database is opened.** Resolving an
/// application directory requires a platform plugin the project does not
/// depend on, so the path is supplied by the composition root:
///
/// ```dart
/// final Directory dir = await getApplicationDocumentsDirectory();
/// runApp(
///   ProviderScope(
///     overrides: <Override>[
///       databaseDirectoryProvider.overrideWithValue(dir.path),
///     ],
///     child: const VumpApp(),
///   ),
/// );
/// ```
///
/// Unimplemented rather than defaulted: a guessed path is wrong on at least
/// one platform, and failing at the override point is far easier to diagnose
/// than a database silently opened somewhere unexpected.
final Provider<String> databaseDirectoryProvider = Provider<String>(
  (Ref ref) => throw UnimplementedError(
    'databaseDirectoryProvider must be overridden with a writable directory '
    'before the database is opened.',
  ),
);

/// Migration steps available to the runner.
///
/// Empty at schema version 1 — there is nothing to upgrade from. Override to
/// register steps as the schema evolves.
final Provider<List<Migration>> databaseMigrationsProvider =
    Provider<List<Migration>>((Ref ref) => const <Migration>[]);

/// How the database is opened.
///
/// The registration point for feature collections. A composition root adds
/// schemas without editing any existing file:
///
/// ```dart
/// databaseConfigProvider.overrideWith(
///   (ref) => DatabaseConfig(
///     directory: ref.watch(databaseDirectoryProvider),
///   ).withSchemas(<CollectionSchema<dynamic>>[RecordingSchema]),
/// )
/// ```
final Provider<DatabaseConfig> databaseConfigProvider =
    Provider<DatabaseConfig>(
      (Ref ref) => DatabaseConfig(
        directory: ref.watch(databaseDirectoryProvider),
        inspector: AppFeatureFlags.forEnvironment(
          AppConfig.environment,
        ).databaseInspectorEnabled,
      ),
    );

/// Owner of the database lifecycle.
///
/// Constructing the service does not open the database. Closing it when the
/// provider is disposed keeps the instance from outliving the container that
/// created it, which otherwise leaves a second open attempt fighting the
/// first in tests.
final Provider<DatabaseService> databaseServiceProvider =
    Provider<DatabaseService>((Ref ref) {
      final DatabaseService service = DatabaseService(
        config: ref.watch(databaseConfigProvider),
        logger: ref.watch(loggerProvider),
        migrations: ref.watch(databaseMigrationsProvider),
      );

      ref.onDispose(() => unawaited(service.close()));

      return service;
    });

/// The open Isar instance.
///
/// Asynchronous because opening is. ADR-009 records the consequence: together
/// with secure storage, the application has two async prerequisites before a
/// session can be resolved, so the router needs a loading state.
///
/// Prefer [databaseServiceProvider] for lifecycle control; read this when the
/// instance itself is wanted.
final FutureProvider<Isar> databaseProvider = FutureProvider<Isar>(
  (Ref ref) => ref.watch(databaseServiceProvider).open(),
);
