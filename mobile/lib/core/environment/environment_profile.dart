import '../../app/config/app_config.dart';
import '../firebase/firebase_options.dart';
import '../logging/app_logger.dart';
import '../logging/log_level.dart';
import '../network/network_config.dart';

/// Everything that varies by environment, in one place to read.
///
/// ## This class defines nothing
///
/// Every member below **delegates** to the module that owns the value. That is
/// the entire design, and it is what separates a single source of truth from a
/// second one.
///
/// A profile holding its own copy of the base URL would be a duplicate that
/// compiles, passes tests, and silently disagrees with `NetworkConfig` the
/// first time someone edits one of the two. Delegation makes disagreement
/// impossible: there is one definition, and this is a view onto it.
///
/// **Adding a value here must never mean typing a literal.** If a value has no
/// owner yet, give it one and delegate — do not define it here.
///
/// ## Where each value is actually defined
///
/// | Exposed | Owner | Authority |
/// |---|---|---|
/// | [apiBaseUrl] | `NetworkConfig.baseUrlFor` | ADR-007 |
/// | [chunkBucket] | `NetworkConfig.chunkBucketFor` | ADR-011 |
/// | [cloudFrontDomain] | not provisioned | ADR-011 |
/// | [firebaseProjectId] | `DefaultFirebaseOptions` | ADR-010 |
/// | [logLevel] | `AppLogger.minimumLevelFor` | ADR-016 |
/// | [featureFlags] | `AppFeatureFlags.forEnvironment` | ADR-017 |
///
/// The ownership split is ADR-007's: `app/config/` owns what the application
/// *is*, `core/` owns what it *talks to*. This class lives in `core/` because
/// it reads from `core/network/`, and ADR-007 forbids `app/config/` from doing
/// so.
class EnvironmentProfile {
  const EnvironmentProfile(this.environment);

  /// The profile for the environment this build was compiled against.
  ///
  /// The ordinary way to reach configuration. Prefer this to calling the
  /// individual owners with `AppConfig.environment` at each call site.
  static const EnvironmentProfile current = EnvironmentProfile(
    AppConfig.environment,
  );

  /// The environment this profile describes.
  final AppEnvironment environment;

  /// Root of every backend API call.
  String get apiBaseUrl => NetworkConfig.baseUrlFor(environment);

  /// Bucket holding raw video chunks.
  ///
  /// Informational, per Volume 7 Chapter 7.10 §2. The application never
  /// addresses S3 by bucket — it uploads to presigned URLs the backend
  /// returns.
  String get chunkBucket => NetworkConfig.chunkBucketFor(environment);

  /// CloudFront distribution domain, once media delivery exists.
  ///
  /// Null in every environment today. ADR-011 provisions the distributions
  /// disabled and gates enabling them behind a key group, access logging and a
  /// real consumer — none of which exist. Exposed now so that the shape of
  /// configuration does not change when they do.
  String? get cloudFrontDomain => null;

  /// Firebase project backing this environment.
  ///
  /// **Currently identical in all three environments.** One project,
  /// `vump-platform-f86af`, serves development, staging and production,
  /// because only one was created. Volume 7 Chapter 7.10 §2 expects one per
  /// environment.
  ///
  /// This is a real gap, not a design choice: production analytics, crash
  /// reports and auth users are presently indistinguishable from development
  /// ones. Closing it means running `flutterfire configure` against two
  /// further projects; it is deliberately not faked here.
  ///
  /// Platform-dependent, so it is a getter rather than a constant — reading it
  /// requires a platform the Firebase options were generated for.
  String get firebaseProjectId => DefaultFirebaseOptions.currentPlatform.projectId;

  /// Least severe level this environment emits.
  LogLevel get logLevel => AppLogger.minimumLevelFor(environment);

  /// Behaviour that differs between environments.
  AppFeatureFlags get featureFlags =>
      AppFeatureFlags.forEnvironment(environment);

  /// One-line summary for startup logs and support reports.
  ///
  /// Deliberately excludes [firebaseProjectId], which touches platform
  /// channels and would make this unusable before Firebase initialises.
  String describe() =>
      '${environment.label}: api=$apiBaseUrl bucket=$chunkBucket '
      'log=${logLevel.label} cdn=${cloudFrontDomain ?? 'none'}';
}
