/// The environment a build targets.
///
/// Carries the identity of the environment only. It holds no endpoints, keys
/// or credentials — what differs per environment is decided by the code that
/// reads this value, not by the enum itself.
///
/// Two names per case, because two systems name environments differently and
/// neither is wrong:
///
/// - [key] is the `APP_ENV` token supplied at build time.
/// - [slug] is the suffix AWS resources use, fixed by ADR-011.
///
/// Holding both here is what lets a resource name be *derived* rather than
/// duplicated. `vump-platform-${slug}` has one definition; a second list of
/// bucket names would have two, and two lists disagree eventually.
enum AppEnvironment {
  /// Local development. The default for any build that does not declare one.
  development('Development', 'development', 'dev'),

  /// Pre-production verification.
  staging('Staging', 'staging', 'staging'),

  /// Live, user-facing builds.
  production('Production', 'production', 'prod');

  const AppEnvironment(this.label, this.key, this.slug);

  /// Human-readable name, for diagnostics and debug surfaces.
  final String label;

  /// The `APP_ENV` value that selects this environment at build time.
  final String key;

  /// The suffix used by AWS resources for this environment, per ADR-011.
  ///
  /// Deliberately not equal to [key]: the buckets are `vump-platform-dev`,
  /// not `vump-platform-development`. They were created that way and S3
  /// bucket names are immutable.
  final String slug;

  /// Applied when a build does not declare an environment, or declares one
  /// that is not recognised.
  ///
  /// Development is the safe default: an undeclared build is a developer's
  /// machine, and defaulting to production would point an unverified build at
  /// live infrastructure. ADR-007 records this reasoning.
  static const AppEnvironment defaultEnvironment = development;
}
