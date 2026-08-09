import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/app.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/environment/environment_profile.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firebase/providers/firebase_provider.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/logging/providers/logger_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The container is built before runApp so that asynchronous startup work can
  // be awaited here rather than inside a widget. ADR-010 requires Firebase to
  // be initialised exactly once, off the widget tree; this is the only place
  // that satisfies both.
  final ProviderContainer container = ProviderContainer();
  final AppLogger logger = container.read(loggerProvider);

  _announceEnvironment(logger);
  await _initializeFirebase(container, logger);

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
