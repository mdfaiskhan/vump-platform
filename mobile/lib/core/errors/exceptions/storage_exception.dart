import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';

/// Raised when a local persistence operation fails.
///
/// Covers every on-device store — the local database, secure storage and the
/// file system alike. One type rather than three, because the caller's
/// response is the same in each case: the data is not available, and the
/// [ErrorCode] says why.
///
/// The backend that failed is not identified in the type. Which store a
/// repository uses is an implementation detail, and encoding it in the
/// exception would leak that detail upward through the `catch` clause.
class StorageException extends AppException {
  const StorageException({
    required super.errorCode,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}
