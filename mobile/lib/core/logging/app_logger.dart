import 'package:logger/logger.dart';

import '../../app/config/app_environment.dart';
import 'log_formatter.dart';
import 'log_level.dart';

/// The application's only logging mechanism.
///
/// Every log statement in the codebase goes through an instance of this class,
/// obtained from `loggerProvider`. No code outside `core/logging` constructs a
/// `Logger` directly — that is what makes the underlying package replaceable
/// and the redaction contract below enforceable in one place.
///
/// ## Sensitive data must never be logged
///
/// Logs are written to the console, persisted by the platform, and will
/// eventually be shipped to an aggregator. Treat every log line as permanently
/// disclosed to anyone with access to any of those.
///
/// The following must **never** appear in a log message, an error object, or
/// any value interpolated into either:
///
/// - `Authorization` headers, in any form
/// - Access tokens
/// - Refresh tokens
/// - Passwords, PINs and passphrases
/// - API keys and secrets of any kind
/// - Session cookies and identifiers that grant access
///
/// Per ADR-007 these values are forbidden in source code; logging one puts it
/// back in plain text and defeats that decision.
///
/// This class does **not** redact. It cannot: by the time a value reaches a
/// log call it is an opaque string, and a redactor that guesses would either
/// miss secrets or mangle legitimate content. Redaction is the caller's
/// obligation, discharged at the boundary where the sensitive value is known —
/// a networking interceptor strips headers before logging a request; it does
/// not hand them over and hope.
///
/// Log the shape of a thing, not the thing: `'Authorization header present'`,
/// not the header. `'refresh failed for user ${user.id}'`, not the token.
///
/// ## Environment awareness
///
/// The minimum level is derived from the [AppEnvironment] supplied at
/// construction, per [minimumLevelFor]. There is no `kDebugMode` check
/// anywhere in this layer — build mode and environment are different
/// questions, and a staging build is a release build.
class AppLogger {
  /// Creates a logger whose verbosity is determined by [environment].
  ///
  /// [output] is an injection point for tests and for future log destinations.
  /// When null, the underlying package writes to the console.
  AppLogger({required AppEnvironment environment, LogOutput? output})
    : this._(minimumLevelFor(environment), output);

  AppLogger._(LogLevel minimum, LogOutput? output)
    : minimumLevel = minimum,
      _logger = Logger(
        filter: _ThresholdFilter(minimum),
        printer: LogFormatter(),
        output: output,
      );

  final Logger _logger;

  /// The least severe level this logger will emit.
  ///
  /// Exposed so callers can skip building an expensive message that would be
  /// discarded, and so the configured verbosity is assertable in tests.
  final LogLevel minimumLevel;

  /// The verbosity policy, as a pure function of environment.
  ///
  /// - [AppEnvironment.development] — verbose. Everything, including [debug].
  /// - [AppEnvironment.staging] — [info] and above. Enough to trace a session
  ///   without the volume of development logging.
  /// - [AppEnvironment.production] — minimal. [warning] and above only, so
  ///   logs record what went wrong rather than what happened.
  ///
  /// Exhaustive over the enum: adding an environment is a compile error here
  /// rather than a silent default.
  static LogLevel minimumLevelFor(AppEnvironment environment) {
    return switch (environment) {
      AppEnvironment.development => LogLevel.debug,
      AppEnvironment.staging => LogLevel.info,
      AppEnvironment.production => LogLevel.warning,
    };
  }

  /// Whether a message at [level] would be emitted.
  bool isEnabled(LogLevel level) => level.isAtLeast(minimumLevel);

  /// Diagnostic detail useful while developing.
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// A normal, expected event worth recording.
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Something unexpected that the application recovered from.
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// An operation failed. The application continues.
  ///
  /// Pass the originating exception as [error]. An `AppException` renders its
  /// error code and message, which is what makes a log line searchable.
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// An unrecoverable failure. The application cannot continue meaningfully.
  void fatal(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

/// Emits events at or above a fixed level.
///
/// Replaces the package's `DevelopmentFilter`, which suppresses everything
/// outside debug builds and would therefore silence production logging
/// entirely.
class _ThresholdFilter extends LogFilter {
  _ThresholdFilter(this._minimum);

  final LogLevel _minimum;

  @override
  bool shouldLog(LogEvent event) => event.level.value >= _minimum.level.value;
}
