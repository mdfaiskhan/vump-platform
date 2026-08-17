import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';

/// Raised when device hardware cannot do what a feature requires.
///
/// The fourth sibling of [AppException], alongside authentication, network and
/// storage. It exists because a missing capability is none of those three: the
/// request was well-formed, the user is who they say they are, nothing failed
/// in transit, and no data was lost. The device simply cannot.
///
/// **The distinguishing property is that no retry helps.** A network failure
/// may succeed on the next attempt and a storage failure may clear when space
/// is freed; a phone without an ultra-wide lens will not grow one. Callers
/// that see this type should stop rather than back off, which is why it is a
/// type and not an [ErrorCode] inside `StorageException`.
///
/// Which piece of hardware failed is carried by the [ErrorCode], not the type
/// — the same reasoning `StorageException` gives for not naming its backend.
class DeviceException extends AppException {
  /// Creates a device capability failure.
  const DeviceException({
    required super.errorCode,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}
