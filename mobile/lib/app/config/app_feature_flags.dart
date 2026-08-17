import 'package:mobile/app/config/app_environment.dart';

/// Behaviour that differs between environments.
///
/// A flag belongs here only if it is **not derivable from something that
/// already exists**. Logging verbosity, for instance, is absent: `AppLogger`
/// already derives it from the environment, and restating it here would give
/// one behaviour two sources of truth that could disagree.
///
/// The bar for adding a flag is deliberately high. Each one multiplies the
/// number of distinct behaviours the application can exhibit, and a flag whose
/// combinations are never exercised is a configuration nobody has tested.
class AppFeatureFlags {
  const AppFeatureFlags({
    required this.databaseInspectorEnabled,
    required this.firebaseFailureIsFatal,
  });

  /// Resolves the flag set for [environment].
  ///
  /// Exhaustive over the enum: adding an environment is a compile error here
  /// rather than a silent inheritance of development's behaviour.
  factory AppFeatureFlags.forEnvironment(AppEnvironment environment) {
    return switch (environment) {
      AppEnvironment.development => const AppFeatureFlags(
        databaseInspectorEnabled: true,
        firebaseFailureIsFatal: false,
      ),
      AppEnvironment.staging => const AppFeatureFlags(
        databaseInspectorEnabled: false,
        firebaseFailureIsFatal: true,
      ),
      AppEnvironment.production => const AppFeatureFlags(
        databaseInspectorEnabled: false,
        firebaseFailureIsFatal: true,
      ),
    };
  }

  /// Whether the Isar Inspector is exposed (ADR-009).
  ///
  /// Development only. The inspector opens a debugging channel into the local
  /// database, which is useful on a developer's machine and is an unnecessary
  /// surface anywhere a real recording could exist.
  final bool databaseInspectorEnabled;

  /// Whether a Firebase initialisation failure aborts startup (ADR-017).
  ///
  /// False in development, so an unconfigured or offline machine can still run
  /// the app while no feature depends on Firebase. True in staging and
  /// production, where starting without the platform is silent breakage rather
  /// than degraded operation.
  ///
  /// ADR-010 recorded the original tolerance as provisional and required it to
  /// become either fatal or an explicit degraded mode in an ADR. This is that
  /// decision, made environment-aware.
  final bool firebaseFailureIsFatal;
}
