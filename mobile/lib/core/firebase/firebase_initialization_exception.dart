import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';

/// Raised when the Firebase platform cannot be initialised.
///
/// Extends `AppException`, so the Mission 0.10 contract holds: a caller
/// catches the application's own type and never a `FirebaseException` from the
/// SDK. `AppException` was deliberately left abstract rather than sealed so
/// infrastructure could extend it this way.
///
/// ## Two deviations from Mission 0.10, both forced by scope
///
/// **Placement.** The other subclasses live in `core/errors/exceptions/`. That
/// path was outside this mission's allowed paths, so this one sits beside the
/// layer that raises it. It should be moved for consistency when
/// `core/errors/` is next in scope.
///
/// **Error code.** `ErrorCode` has no case for a platform service failing to
/// start, and the enum could not be extended from here. [ErrorCode.unknown] is
/// therefore used, which is weaker than it should be — a
/// `firebaseInitializationFailed` case belongs in the taxonomy.
class FirebaseInitializationException extends AppException {
  const FirebaseInitializationException({
    required super.message,
    super.errorCode = ErrorCode.unknown,
    super.cause,
    super.stackTrace,
  });
}
