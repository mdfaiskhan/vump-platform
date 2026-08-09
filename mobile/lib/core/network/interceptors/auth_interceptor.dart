import 'package:dio/dio.dart';

/// Extension point for attaching credentials to outgoing requests.
///
/// **A placeholder. It performs no authentication.** Every request passes
/// through unchanged, exactly as if the interceptor were absent.
///
/// It is installed now rather than later so that the position in the chain is
/// fixed: it runs first, before logging, so that any header it adds is subject
/// to the redaction the logging interceptor applies. An interceptor added
/// after logging would write its credential to the log.
///
/// ## What implementing this will involve
///
/// Attaching a bearer token is one line in [onRequest]:
///
/// ```dart
/// options.headers[NetworkConstants.authorizationHeader] =
///     '${NetworkConstants.bearerPrefix}$token';
/// ```
///
/// The decisions around it are the substance, and none is taken yet:
///
/// - Where the token is read from. ADR-007 forbids credentials in source, so
///   it comes from secure storage or a token exchange at runtime.
/// - Whether a 401 triggers a refresh-and-retry, and how concurrent requests
///   are held while a single refresh is in flight.
/// - What happens when refresh fails — sign-out is a navigation concern, and
///   an interceptor must not reach into routing.
///
/// Those require their own ADR. Until it is taken, this class stays inert.
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // No credential is attached yet. See the class documentation.
    handler.next(options);
  }
}
