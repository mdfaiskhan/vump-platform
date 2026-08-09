import 'app_environment.dart';

export 'app_constants.dart';
export 'app_environment.dart';
export 'app_feature_flags.dart';
export 'app_info.dart';

/// The `APP_ENV` value this build was compiled with.
///
/// `String.fromEnvironment` is a compile-time constant: the value is baked in
/// by `--dart-define`, not read at runtime. A production binary therefore
/// cannot be made to behave like a development one by anything on the device.
const String _rawAppEnv = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'development',
);

/// The single entry point for application configuration.
///
/// Importing this file brings `AppInfo`, `AppConstants`, `AppEnvironment` and
/// `AppFeatureFlags` into scope, so no consumer needs to know how
/// configuration is split across files.
abstract final class AppConfig {
  /// The environment this build targets.
  ///
  /// Resolved from `--dart-define=APP_ENV` per ADR-007:
  ///
  /// ```
  /// flutter run --dart-define-from-file=.env.dev
  /// flutter build appbundle --dart-define-from-file=.env.prod
  /// ```
  ///
  /// The chain below is a nest of conditionals rather than a `switch` or a
  /// parse function because it must be **const-evaluable**. A function call
  /// would defer resolution to runtime and forfeit the compile-time guarantee
  /// that makes this safe.
  ///
  /// An unrecognised value falls back to development rather than failing the
  /// build. ADR-007 chose that deliberately: a hard failure breaks builds over
  /// a typo in a value that has a safe default, while a *silent* fallback
  /// hides that typo in a release pipeline. The fallback is therefore visible
  /// — see [environmentWasRecognised].
  static const AppEnvironment environment = _rawAppEnv == 'production'
      ? AppEnvironment.production
      : _rawAppEnv == 'staging'
      ? AppEnvironment.staging
      : AppEnvironment.development;

  /// Whether `APP_ENV` named an environment that exists.
  ///
  /// False when `APP_ENV` was set to something unrecognised — a typo such as
  /// `prod` or `PRODUCTION`. True when it was set correctly, and true when it
  /// was absent entirely, since absence is the documented default rather than
  /// a mistake.
  ///
  /// ADR-007 requires the fallback to be logged. Configuration cannot log —
  /// it is `const` and resolved before any logger exists — so it reports the
  /// fact and the composition root announces it.
  static const bool environmentWasRecognised =
      _rawAppEnv == 'production' ||
      _rawAppEnv == 'staging' ||
      _rawAppEnv == 'development';

  /// The raw `APP_ENV` value, for diagnostics.
  ///
  /// Exposed so a fallback warning can name what was actually supplied.
  /// Nothing should branch on this — branch on [environment].
  static const String rawEnvironmentValue = _rawAppEnv;
}
