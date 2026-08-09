import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../app_logger.dart';

/// The application's logger.
///
/// The single sanctioned way to obtain an [AppLogger]. Per ADR-003, Riverpod
/// is the dependency injection mechanism; there is deliberately no singleton,
/// no static instance and no service locator. A global would be reachable from
/// anywhere, unoverridable in tests, and constructed before configuration was
/// known.
///
/// Read it as you would any provider:
///
/// ```dart
/// final AppLogger logger = ref.read(loggerProvider);
/// logger.info('Session restored');
/// ```
///
/// Verbosity comes from `AppConfig.environment`, so this provider is the seam
/// where configuration meets logging. Overriding it in a `ProviderScope`
/// substitutes a logger for tests, or one built for a different environment,
/// without any call site changing.
final Provider<AppLogger> loggerProvider = Provider<AppLogger>(
  (Ref ref) => AppLogger(environment: AppConfig.environment),
);
