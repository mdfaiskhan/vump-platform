import 'package:mobile/core/errors/app_exception.dart';

/// Raised when a value fails validation.
///
/// Unlike the other exception types, this one does not originate from a
/// third-party boundary — it is raised by the application's own rules when
/// input is rejected, whether that input came from a user, a stored record or
/// a remote response.
///
/// [field] names the offending input where one can be named, so a form can
/// attach the message to the correct control rather than to the form as a
/// whole. It is null for validations that span several values.
class ValidationException extends AppException {
  const ValidationException({
    required super.errorCode,
    required super.message,
    this.field,
    super.cause,
    super.stackTrace,
  });

  /// Identifier of the value that failed validation.
  ///
  /// Null when the rule applies across several values rather than to one.
  final String? field;

  @override
  String toString() {
    final String base = super.toString();
    return field == null ? base : '$base | field: $field';
  }
}
