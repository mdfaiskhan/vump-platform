/// The environment a build targets.
///
/// Carries the identity of the environment only. It holds no endpoints, keys
/// or credentials — what differs per environment is decided by the code that
/// reads this value, not by the enum itself.
enum AppEnvironment {
  /// Local development. The default for any build that does not declare one.
  development('Development'),

  /// Pre-production verification.
  staging('Staging'),

  /// Live, user-facing builds.
  production('Production');

  const AppEnvironment(this.label);

  /// Human-readable name, for diagnostics and debug surfaces.
  final String label;

  /// Applied when a build does not declare an environment.
  ///
  /// Development is the safe default: an undeclared build is a developer's
  /// machine, and defaulting to production would point an unverified build at
  /// live infrastructure.
  static const AppEnvironment defaultEnvironment = development;
}
