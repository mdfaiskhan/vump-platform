import 'dart:io';

// One alphabetically sorted `package:` block rather than this file's previous
// third-party-then-first-party grouping: `directives_ordering` (ADR-021) sorts
// the whole section, and `path_provider` sorts after `mobile`, so the grouping
// and the lint can no longer both hold.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/database/providers/database_provider.dart';
import 'package:mobile/core/environment/environment_profile.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firebase/providers/firebase_provider.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/logging/providers/logger_provider.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved before the container so the database directory override can be
  // supplied at construction. ADR-009 Caveat 2 makes this the composition
  // root's job: `databaseDirectoryProvider` throws until overridden, because a
  // guessed path is wrong on at least one platform and failing at the override
  // point is easier to diagnose than a database opened somewhere unexpected.
  final Directory documents = await getApplicationDocumentsDirectory();

  // The container is built before runApp so that asynchronous startup work can
  // be awaited here rather than inside a widget. ADR-010 requires Firebase to
  // be initialised exactly once, off the widget tree; this is the only place
  // that satisfies both.
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      databaseDirectoryProvider.overrideWithValue(documents.path),
      // The composition root is the only place that may name a concrete
      // implementation: `application/` declares `authRepositoryProvider` and
      // may not import `data/` (ADR-022), so the two are introduced here.
      //
      // Constructing it is safe with Firebase down — ADR-035 made the SDK
      // resolution lazy precisely so this line cannot throw during startup
      // that ADR-017 has already decided to tolerate.
      authRepositoryProvider.overrideWithValue(AuthRepositoryImpl()),
    ],
  );
  final AppLogger logger = container.read(loggerProvider);

  _announceEnvironment(logger);
  await _initializeFirebase(container, logger);
  await _openDatabase(container, logger);
  await _restoreSession(container, logger);

  runApp(
    UncontrolledProviderScope(container: container, child: const VumpApp()),
  );
}

/// Records which environment this build resolved to, and warns if it fell back.
///
/// ADR-007 requires an unrecognised `APP_ENV` to be logged rather than
/// silently defaulting. A silent fallback hides a typo in a release pipeline —
/// the build succeeds, ships, and points at the wrong infrastructure.
///
/// This runs before anything else so the first line in any diagnostic report
/// says which environment produced everything after it.
void _announceEnvironment(AppLogger logger) {
  if (!AppConfig.environmentWasRecognised) {
    logger.warning(
      'APP_ENV was set to "${AppConfig.rawEnvironmentValue}", which is not a '
      'recognised environment. Falling back to '
      '${AppEnvironment.defaultEnvironment.label}. Expected one of: '
      '${AppEnvironment.values.map((AppEnvironment e) => e.key).join(', ')}.',
    );
  }

  logger.info(
    '${AppInfo.appName} ${AppInfo.fullVersion} starting — '
    '${EnvironmentProfile.current.describe()}',
  );
}

/// Brings up the Firebase platform before the first frame.
///
/// Awaiting the provider here means every Firebase product is usable from the
/// first frame, and no widget ever triggers initialisation.
///
/// Whether a failure is fatal is environment-driven, per ADR-017. In
/// development it is survivable, so an unconfigured or offline machine can
/// still run the app while no feature depends on Firebase. In staging and
/// production it aborts startup, because a build that silently runs without
/// the platform it was built against is worse than one that fails loudly.
Future<void> _initializeFirebase(
  ProviderContainer container,
  AppLogger logger,
) async {
  final bool isFatal = AppFeatureFlags.forEnvironment(
    AppConfig.environment,
  ).firebaseFailureIsFatal;

  try {
    await container.read(firebaseAppProvider.future);
  } on AppException catch (error, stackTrace) {
    if (isFatal) {
      logger.fatal(
        'Firebase initialisation failed in ${AppConfig.environment.label}. '
        'Aborting startup rather than running against an uninitialised '
        'platform.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    logger.error(
      'Starting without Firebase. Products that depend on it will fail.',
      error: error,
    );
  }
}

/// Resolves who is signed in before the first frame.
///
/// Volume 6 Chapter 6.7 §3 requires the session to be resolved *"only at app
/// cold-start, to attempt silent re-authentication before falling back to the
/// Login screen"*. Awaiting `authNotifierProvider` here is what puts that on
/// the startup path: `AuthNotifier.build` calls `restoreSession`, and until
/// this line existed nothing read the provider, so the restore never ran until
/// something happened to watch it.
///
/// ADR-008 predicted the shape of this: *"the session cannot be known
/// synchronously before `runApp`, so the router needs a loading state while
/// the token is read"*. Awaiting it here satisfies the constraint without a
/// loading state in the router, because the OS-native splash already covers
/// the window — the first Flutter frame is drawn after the answer is known.
///
/// ## There is no token to read, and that is not an omission
///
/// Volume 6 Chapter 6.7 §2 expects the Firebase refresh token to live in
/// `flutter_secure_storage`. It cannot: `firebase_auth` documents
/// `User.refreshToken` as *"an empty string for native platforms (android, iOS
/// & macOS)"*, so the value this application would store is not obtainable
/// through the API. The native SDK persists its own credential in the
/// platform's keystore instead, which is the same protection by a different
/// owner. Registered as amendment A-055.
///
/// ## Failure is never fatal
///
/// Unlike the database, an unresolvable session is a normal outcome — nobody
/// has signed in yet on a fresh install. `AuthNotifier` already converts a
/// failed restore into `unauthenticated` rather than an error, so this await
/// resolves either way; the guard here is for a defect in that conversion, not
/// for the expected path.
Future<void> _restoreSession(
  ProviderContainer container,
  AppLogger logger,
) async {
  try {
    await container.read(authNotifierProvider.future);
  } on Object catch (error, stackTrace) {
    logger.error(
      'The session could not be resolved at startup. Continuing signed out.',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Opens the local database before the first frame.
///
/// Awaiting `databaseProvider` here is what puts the open on the startup path,
/// which Volume 6 Chapter 6.1 §2's bootstrap sequence requires and ADR-009
/// assumes when it records that "database open is on the startup path, so its
/// duration is worth recording".
///
/// ## Opening exactly once
///
/// Two mechanisms combine, and neither is sufficient alone. Riverpod caches the
/// `FutureProvider`, so a later `ref.watch(databaseProvider)` from a widget
/// receives this same future rather than starting a second open. Beneath it,
/// `DatabaseService.open` holds the in-flight `Future` rather than the
/// instance, so even direct concurrent callers await the first open — the
/// guarantee ADR-009 requires by construction rather than by convention.
///
/// ## Failure aborts startup
///
/// **ADR-009 does not specify a failure policy for startup**, and this is the
/// choice made here: a database that cannot open is fatal in every
/// environment, unlike Firebase, whose policy ADR-017 makes environment-driven
/// via `AppFeatureFlags.firebaseFailureIsFatal`.
///
/// The reasoning is that the two are not comparable. Firebase is survivable in
/// development because no feature depends on it yet. The database is the
/// offline-first foundation the Constitution §3 requires — every core workflow
/// must work with no network, and `NFR-REL-04` requires the upload queue to
/// survive a force-close. An application running without local persistence
/// cannot honour "never lose a take"; it is broken rather than degraded, and
/// continuing would hide that.
///
/// This is the second `fatal` call site in the codebase. `logging-standards.md`
/// §5 records that adding one is a decision rather than a detail, which is why
/// the reasoning is here and not left implicit.
Future<void> _openDatabase(
  ProviderContainer container,
  AppLogger logger,
) async {
  try {
    await container.read(databaseProvider.future);
  } on AppException catch (error, stackTrace) {
    logger.fatal(
      'The local database could not be opened. Aborting startup rather than '
      'running without local persistence.',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
