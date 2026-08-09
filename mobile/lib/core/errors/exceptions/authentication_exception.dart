import 'package:mobile/core/errors/app_exception.dart';

/// Raised when authentication or authorisation fails.
///
/// Covers both halves of the concern: proving who the caller is, and
/// determining what they may do. They share a type because they share a
/// consumer — the layer that decides whether to prompt for sign-in, refresh a
/// session, or refuse an action.
///
/// Whichever identity provider is eventually adopted, its native errors are
/// mapped to this type at the boundary. No layer above sees a provider-specific
/// error class.
///
/// Carries no credential, token or identifier. An exception is logged, and a
/// secret in a log is a secret disclosed.
class AuthenticationException extends AppException {
  const AuthenticationException({
    required super.errorCode,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}
