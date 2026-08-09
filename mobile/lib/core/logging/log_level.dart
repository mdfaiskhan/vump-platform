import 'package:logger/logger.dart';

/// Severity levels the application logs at.
///
/// This enum is the application's own vocabulary. It exists so that no code
/// outside `core/logging` refers to the `logger` package's `Level` type —
/// replacing the underlying package should not require editing call sites.
///
/// Five levels, deliberately: `logger` also offers `trace`, `all` and `off`,
/// which are either redundant with [debug] or a filter setting rather than a
/// severity.
enum LogLevel {
  /// Diagnostic detail useful while developing. Suppressed outside development.
  debug(Level.debug, 'DEBUG'),

  /// A normal, expected event worth recording.
  info(Level.info, 'INFO'),

  /// Something unexpected that the application recovered from.
  warning(Level.warning, 'WARNING'),

  /// An operation failed. The application continues.
  error(Level.error, 'ERROR'),

  /// An unrecoverable failure. The application cannot continue meaningfully.
  fatal(Level.fatal, 'FATAL');

  const LogLevel(this.level, this.label);

  /// The equivalent level in the underlying `logger` package.
  ///
  /// Internal to `core/logging`. No caller should need this.
  final Level level;

  /// Fixed identifier written to log output.
  final String label;

  /// Whether this level is at least as severe as [other].
  bool isAtLeast(LogLevel other) => level.value >= other.level.value;

  /// Maps a `logger` level back to the application's vocabulary.
  ///
  /// Used by the formatter, which receives events typed by the package rather
  /// than by this enum. Levels with no direct equivalent collapse to the
  /// nearest sensible match.
  static LogLevel fromLevel(Level level) {
    return switch (level) {
      Level.trace || Level.debug || Level.all => LogLevel.debug,
      Level.info => LogLevel.info,
      Level.warning => LogLevel.warning,
      Level.error => LogLevel.error,
      Level.fatal || Level.off => LogLevel.fatal,
      _ => LogLevel.info,
    };
  }
}
