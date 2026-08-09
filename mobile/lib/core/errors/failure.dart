import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';

/// A failure as exposed to the application and presentation layers.
///
/// This is the only error type that crosses out of infrastructure. It carries
/// what a caller legitimately needs in order to decide what to do — a code to
/// branch on and a message to render — and nothing else.
///
/// What it deliberately omits is as much the point as what it holds. There is
/// no `cause`, no `stackTrace` and no reference to the exception it came from.
/// Those exist on `AppException` and stop at the boundary. A failure therefore
/// cannot leak a Dio error, an Isar handle or a file path into a widget, and
/// cannot tempt application code into branching on an implementation detail.
///
/// The class is `final`: there is exactly one failure type, distinguished by
/// its [code]. A hierarchy of failure subclasses would push infrastructure
/// concerns back into the shape of the type.
///
/// Pure Dart by necessity — ADR-001 requires that `domain` depend on nothing
/// outside itself, and `domain` consumes this type.
final class Failure {
  const Failure({required this.code, this.message});

  /// Builds a failure from an exception, discarding its diagnostic detail.
  ///
  /// This is the single sanctioned conversion point. Routing every exception
  /// through it is what guarantees that [AppException.cause] and stack traces
  /// cannot reach the application layer by accident.
  ///
  /// Pass [message] to substitute a description intended for display; omit it
  /// to carry the exception's own message across. Presentation is expected to
  /// resolve display text from [code] regardless, so the message is a
  /// diagnostic aid rather than the primary channel.
  factory Failure.fromException(AppException exception, {String? message}) {
    return Failure(
      code: exception.errorCode,
      message: message ?? exception.message,
    );
  }

  /// The condition that occurred. The value application code branches on.
  final ErrorCode code;

  /// Optional description of the failure.
  ///
  /// Absent for failures whose code is self-describing. Presentation should
  /// prefer text resolved from [code], since only that is localisable.
  final String? message;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Failure && other.code == code && other.message == message;
  }

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() =>
      'Failure(${code.code})${message == null ? '' : ': $message'}';
}
