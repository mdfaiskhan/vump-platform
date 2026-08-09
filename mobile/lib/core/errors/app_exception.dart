import 'package:mobile/core/errors/error_codes.dart';

/// The base type for every exception the application raises.
///
/// Exceptions are the *internal* representation of something going wrong. They
/// may carry diagnostic detail — the originating third-party error, a stack
/// trace — because they never cross into the application layer. Converting one
/// into a `Failure` is what strips that detail.
///
/// Infrastructure is responsible for the conversion inward: a Dio error, an
/// Isar exception, a platform channel failure and a Firebase error are each
/// caught at the boundary where they arise and rethrown as a subclass of this
/// type. No layer above infrastructure ever sees a third-party exception.
///
/// This class is abstract rather than sealed. Sealing would confine subclasses
/// to this one file, and the taxonomy is deliberately extended per
/// infrastructure concern across `errors/exceptions/`.
abstract class AppException implements Exception {
  const AppException({
    required this.errorCode,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  /// The condition this exception represents.
  final ErrorCode errorCode;

  /// Developer-facing description of what went wrong.
  ///
  /// Written for a reader of logs, not for a user. It may name internal
  /// details freely; it is discarded or replaced when a failure is built.
  final String message;

  /// The originating error, where one exists.
  ///
  /// Typically the third-party exception being wrapped. Held for diagnostics
  /// only — it must never be surfaced above infrastructure.
  final Object? cause;

  /// Stack trace captured at the origin, where one is available.
  ///
  /// Retained so the eventual logging infrastructure can record the true point
  /// of failure rather than the point of rethrow.
  final StackTrace? stackTrace;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('$runtimeType(')
      ..write(errorCode.code)
      ..write('): ')
      ..write(message);
    if (cause != null) {
      buffer.write(' | cause: $cause');
    }
    return buffer.toString();
  }
}
