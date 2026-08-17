import 'package:flutter/services.dart' show appFlavor;
import 'package:mobile/app/config/app_environment.dart';

export 'package:mobile/app/config/app_constants.dart';
export 'package:mobile/app/config/app_environment.dart';
export 'package:mobile/app/config/app_feature_flags.dart';
export 'package:mobile/app/config/app_info.dart';

/// The build flavor, which is the environment selector — ADR-047.
///
/// `appFlavor` is Flutter's own constant, populated from `FLUTTER_APP_FLAVOR`,
/// which the Flutter tool defines from `--flavor`. It is `null` when no
/// flavor was given, which is the case for `flutter test` and for any plain
/// `flutter run`.
///
/// **This is the single selector.** The same `--flavor dev` that makes Gradle
/// read `src/dev/google-services.json` and install
/// `com.vump.humanarchive.dev` also produces the value read here. Nothing
/// passes `--dart-define=APP_ENV` beside it, so there is no second input that
/// can disagree with the first.
const String? _flavor = appFlavor;

/// The `APP_ENV` value this build resolved to.
///
/// Derived from the flavor, falling back to an explicit `--dart-define` only
/// when no flavor was supplied. Both are `String.fromEnvironment` underneath:
/// compile-time constants baked into the binary, so a production build cannot
/// be made to behave like a development one by anything on the device.
///
/// The fallback exists for the flavourless builds that legitimately occur —
/// `flutter test` is the main one — and not as a second way to select an
/// environment for a real build. A flavour always wins when present.
///
/// The literals below are [AppEnvironment.slug] values, and that is not a
/// coincidence to be tidied away: the Gradle flavors are *named* after the
/// slugs precisely so the two cannot drift. A `switch` or a lookup would read
/// better and would not be const-evaluable, which is what would forfeit the
/// compile-time guarantee above.
const String _rawAppEnv = _flavor == 'prod'
    ? 'production'
    : _flavor == 'staging'
    ? 'staging'
    : _flavor == 'dev'
    ? 'development'
    : String.fromEnvironment('APP_ENV', defaultValue: 'development');

/// The single entry point for application configuration.
///
/// Importing this file brings `AppInfo`, `AppConstants`, `AppEnvironment` and
/// `AppFeatureFlags` into scope, so no consumer needs to know how
/// configuration is split across files.
abstract final class AppConfig {
  /// The environment this build targets.
  ///
  /// Selected by the build flavor per ADR-047, which supersedes ADR-007's
  /// `--dart-define=APP_ENV` as the mechanism while leaving its three-
  /// environment model untouched:
  ///
  /// ```shell
  /// flutter run   --flavor dev
  /// flutter build appbundle --flavor prod
  /// ```
  ///
  /// One flag. It picks the Firebase project, the application ID and this
  /// value together, so they cannot be selected inconsistently.
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

  /// Whether this build named an environment that exists.
  ///
  /// False when the selector was set to something unrecognised — `--flavor
  /// prd`, or an `APP_ENV` of `PRODUCTION`. True when it was set correctly,
  /// and true when it was absent entirely, since absence is the documented
  /// default rather than a mistake.
  ///
  /// **The flavor is checked directly, not through [rawEnvironmentValue], and
  /// that is the point.** An unrecognised flavor resolves to
  /// `development` by the fallback above, so testing the resolved value would
  /// report a misspelled `--flavor` as recognised — the fallback would hide
  /// exactly the mistake this flag exists to surface. A typo in the selector
  /// has to be visible at the selector.
  ///
  /// ADR-007 requires the fallback to be logged. Configuration cannot log —
  /// it is `const` and resolved before any logger exists — so it reports the
  /// fact and the composition root announces it.
  static const bool environmentWasRecognised = _flavor != null
      ? _flavor == 'dev' || _flavor == 'staging' || _flavor == 'prod'
      : _rawAppEnv == 'production' ||
            _rawAppEnv == 'staging' ||
            _rawAppEnv == 'development';

  /// The resolved environment key, for diagnostics.
  ///
  /// Exposed so a fallback warning can name what was actually supplied.
  /// Nothing should branch on this — branch on [environment].
  static const String rawEnvironmentValue = _rawAppEnv;

  /// The build flavor this binary was compiled with, or null if none.
  ///
  /// Diagnostics only, and the value a fallback warning should name: when
  /// [environmentWasRecognised] is false because of a misspelled `--flavor`,
  /// [rawEnvironmentValue] holds the fallback rather than the mistake, so it
  /// cannot report what actually went wrong.
  static const String? flavor = _flavor;
}
