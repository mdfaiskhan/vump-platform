/// Static identity of the application.
///
/// Answers "what is this build?" — name, owner and version. Values here are
/// compile-time placeholders; a later mission may source [version] and [build]
/// from the platform bundle so they cannot drift from `pubspec.yaml`.
abstract final class AppInfo {
  /// The application name as shown to users.
  static const String appName = 'Vump Technologies';

  /// The organization that owns the application.
  static const String organizationName = 'Vump Technologies';

  /// Semantic version. Mirrors the version segment of `pubspec.yaml`.
  ///
  /// Placeholder — must be kept in step with `version:` until it is read from
  /// the platform bundle at runtime.
  static const String version = '1.0.0';

  /// Build number. Mirrors the build segment of `pubspec.yaml`.
  ///
  /// Placeholder — see [version].
  static const String build = '1';

  /// Convenience form used in diagnostics and about screens, e.g. `1.0.0+1`.
  static const String fullVersion = '$version+$build';
}
