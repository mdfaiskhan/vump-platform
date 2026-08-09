import 'package:logger/logger.dart';

import 'log_level.dart';

/// Renders a log event as plain, readable lines.
///
/// Output is one line per event, with the error and stack trace indented
/// beneath it when present:
///
/// ```
/// 2026-08-09T14:32:07.118Z [ERROR  ] Token refresh failed
///   error: NetworkException(NETWORK_TIMEOUT): request timed out
///   stack:
///     #0  TokenRefresher.refresh (package:mobile/...)
/// ```
///
/// Deliberately not `PrettyPrinter`. Its boxes and colour codes are pleasant
/// in a terminal and unreadable in a log aggregator, where these lines will
/// eventually be shipped. Timestamps are ISO-8601 for the same reason: they
/// sort lexicographically and parse without a format string.
///
/// The formatter renders what it is given. It performs **no redaction** — see
/// the sensitive-data contract on `AppLogger`. A secret passed to a log call
/// will be written verbatim.
class LogFormatter extends LogPrinter {
  LogFormatter({this.stackTraceLineLimit = 15});

  /// Maximum stack trace lines rendered before truncation.
  ///
  /// Deep traces bury the event that caused them. The frames nearest the
  /// failure are the ones that matter, and they come first.
  final int stackTraceLineLimit;

  /// Width the level label is padded to, so messages align down the page.
  static const int _labelWidth = 7;

  @override
  List<String> log(LogEvent event) {
    final String label = LogLevel.fromLevel(
      event.level,
    ).label.padRight(_labelWidth);
    final String timestamp = event.time.toIso8601String();

    final List<String> lines = <String>['$timestamp [$label] ${event.message}'];

    if (event.error != null) {
      lines.add('  error: ${event.error}');
    }

    if (event.stackTrace != null) {
      lines
        ..add('  stack:')
        ..addAll(_formatStackTrace(event.stackTrace!));
    }

    return lines;
  }

  List<String> _formatStackTrace(StackTrace stackTrace) {
    final List<String> frames = stackTrace
        .toString()
        .split('\n')
        .where((String line) => line.trim().isNotEmpty)
        .toList();

    final List<String> rendered = frames
        .take(stackTraceLineLimit)
        .map((String frame) => '    ${frame.trim()}')
        .toList();

    final int omitted = frames.length - rendered.length;
    if (omitted > 0) {
      rendered.add('    ... $omitted more frame${omitted == 1 ? '' : 's'}');
    }

    return rendered;
  }
}
