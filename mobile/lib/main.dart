import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/errors/app_exception.dart';
import 'core/firebase/providers/firebase_provider.dart';
import 'core/logging/providers/logger_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The container is built before runApp so that asynchronous startup work can
  // be awaited here rather than inside a widget. ADR-010 requires Firebase to
  // be initialised exactly once, off the widget tree; this is the only place
  // that satisfies both.
  final ProviderContainer container = ProviderContainer();

  await _initializeFirebase(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VumpApp(),
    ),
  );
}

/// Brings up the Firebase platform before the first frame.
///
/// Awaiting the provider here means every Firebase product is usable from the
/// first frame, and no widget ever triggers initialisation.
///
/// ## Why a failure is currently survivable
///
/// No feature depends on Firebase yet. Nothing in the application reads a
/// Firebase product, so a build that starts without the platform is degraded
/// in theory and identical in practice.
///
/// iOS is also not fully configured — `GoogleService-Info.plist` is absent —
/// so aborting on failure would make the application unrunnable on that
/// platform while nothing yet depends on it.
///
/// **This tolerance is provisional.** The moment a feature depends on
/// Firebase — authentication, Crashlytics, Messaging — starting without it is
/// no longer degraded operation but silent breakage. At that point this must
/// either become fatal or become an explicit degraded mode recorded in an ADR.
///
/// The failure is logged as an error rather than swallowed, so an unconfigured
/// build is loud in the console rather than mysterious later.
Future<void> _initializeFirebase(ProviderContainer container) async {
  try {
    await container.read(firebaseAppProvider.future);
  } on AppException catch (error) {
    container.read(loggerProvider).error(
          'Starting without Firebase. Products that depend on it will fail.',
          error: error,
        );
  }
}
