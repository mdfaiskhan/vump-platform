import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';

/// Raised when a request to a remote service fails.
///
/// The networking layer catches its client's native errors — connection
/// failures, timeouts, non-success status codes, decode failures — and
/// rethrows them as this type. Nothing above that layer imports the HTTP
/// client, so nothing above it can catch a client-specific error.
///
/// [statusCode] is carried because retry and refresh policies are written
/// against it, and reconstructing it from an [ErrorCode] would be lossy.
///
/// ## [backendCode] carries Chapter 4.6 §1's named refusal
///
/// The envelope requires that errors *"always carry a specific code, never a
/// bare HTTP status alone"*. Until Mission 7.4 the client kept that code in the
/// **message string** only: `ErrorInterceptor` classifies by status, and
/// `VumpApi` interpolated the backend's code into the prose. So a caller that
/// needed to tell `RESOURCE_NOT_FOUND` from `REQUEST_INVALID_CURSOR` — both
/// arriving as a bare 404 or 400 — had to match on English.
///
/// It is **optional and additive**: null for every transport failure, for every
/// response that carries no envelope, and for every existing caller that does
/// not ask. Nothing that worked before behaves differently.
///
/// It is a `String`, not an enum, deliberately. The backend's code set is
/// declared in `errors.ts` and grows there; mirroring it as a Dart enum would
/// make every new backend code a client release, and an unknown value would
/// have to become `unknown` — losing exactly the specificity this field exists
/// to preserve.
class NetworkException extends AppException {
  const NetworkException({
    required super.errorCode,
    required super.message,
    this.statusCode,
    this.backendCode,
    super.cause,
    super.stackTrace,
  });

  /// HTTP status code, where the failure reached the server and it answered.
  ///
  /// Null for transport-level failures — no connection, timeout, cancellation
  /// — where no response was ever received.
  final int? statusCode;

  /// The `error.code` from Volume 4 Chapter 4.6 §1's envelope, when there was
  /// one.
  ///
  /// Null whenever the failure never reached an envelope: no connection, a
  /// timeout, a cancellation, a body the client could not decode, or a
  /// non-Vump host such as S3.
  final String? backendCode;

  @override
  String toString() {
    final String base = super.toString();
    final String withStatus = statusCode == null
        ? base
        : '$base | status: $statusCode';
    return backendCode == null
        ? withStatus
        : '$withStatus | code: $backendCode';
  }
}
