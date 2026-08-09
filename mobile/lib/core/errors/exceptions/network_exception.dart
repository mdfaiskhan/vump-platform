import '../app_exception.dart';
import '../error_codes.dart';

/// Raised when a request to a remote service fails.
///
/// The networking layer catches its client's native errors — connection
/// failures, timeouts, non-success status codes, decode failures — and
/// rethrows them as this type. Nothing above that layer imports the HTTP
/// client, so nothing above it can catch a client-specific error.
///
/// [statusCode] is carried because retry and refresh policies are written
/// against it, and reconstructing it from an [ErrorCode] would be lossy.
class NetworkException extends AppException {
  const NetworkException({
    required super.errorCode,
    required super.message,
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  /// HTTP status code, where the failure reached the server and it answered.
  ///
  /// Null for transport-level failures — no connection, timeout, cancellation
  /// — where no response was ever received.
  final int? statusCode;

  @override
  String toString() {
    final String base = super.toString();
    return statusCode == null ? base : '$base | status: $statusCode';
  }
}
