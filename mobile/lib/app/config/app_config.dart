import 'app_environment.dart';

export 'app_constants.dart';
export 'app_environment.dart';
export 'app_info.dart';

/// The single entry point for application configuration.
///
/// Importing this file brings `AppInfo`, `AppConstants` and `AppEnvironment`
/// into scope, so no consumer needs to know how configuration is split across
/// files. It also declares the one piece of configuration that is a choice
/// rather than a constant: which environment this build targets.
abstract final class AppConfig {
  /// The environment this build targets.
  ///
  /// Defaults to [AppEnvironment.development]. Selecting an environment at
  /// build time is deliberately not implemented yet — it requires a decision
  /// on how the value is supplied, which is an architectural change and so
  /// belongs in an ADR rather than in this mission.
  static const AppEnvironment environment = AppEnvironment.defaultEnvironment;
}
