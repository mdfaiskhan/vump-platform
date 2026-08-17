import 'dart:async';

import 'package:dio/dio.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/network/interfaces/auth_token_source.dart';
import 'package:mobile/core/network/network_constants.dart';

/// Attaches the current credential, and renews it once when the server
/// rejects it.
///
/// Runs first in `DioClient`'s chain, ahead of `LoggingInterceptor`, so the
/// `Authorization` header it adds is subject to that interceptor's redaction.
/// An interceptor added after logging would write its credential to the log.
///
/// The token arrives through [AuthTokenSource], an interface `core/network/`
/// owns and `features/auth/` implements — see ADR-035 for why the dependency
/// is inverted rather than imported.
///
/// ## Refresh and retry
///
/// Volume 4 Chapter 4.7 §3 specifies this behaviour for this component: when a
/// token expires mid-request the interceptor *"requests a fresh token and
/// retries the request rather than failing the chunk outright"*.
///
/// error-handling.md §16 bounds it. A 401 is retryable **once, after a
/// refresh, never in a loop**, and concurrent 401s must *"wait on one refresh,
/// not trigger one each"*.
///
/// ## What it deliberately cannot do
///
/// **It cannot end a session.** A failed refresh fails the request and nothing
/// else. Firebase signs the user out when a refresh token is revoked, so
/// `AuthRepository.sessionChanges` emits and the route guard redirects — the
/// sign-out is already happening, driven by the same event. Giving this class
/// a way to trigger one would mean a bug in retry logic signs people out.
class AuthInterceptor extends Interceptor {
  /// Creates an interceptor over [tokenSource], retrying through [client].
  ///
  /// [client] is the same `Dio` this interceptor is installed on. Retrying
  /// through it rather than through a bare client means the replayed request
  /// traverses the full chain, so it is logged and its errors are converted
  /// like any other. [retriedFlag] guards the recursion that would otherwise
  /// invite.
  AuthInterceptor({required this.tokenSource, required this.client});

  /// Where the credential comes from.
  final AuthTokenSource tokenSource;

  /// The client a refreshed request is replayed through.
  final Dio client;

  /// Marks a request already replayed once, in `RequestOptions.extra`.
  static const String retriedFlag = 'authInterceptor.retried';

  /// The refresh currently in flight, or null when none is.
  ///
  /// Holding the `Future` rather than a boolean is what makes five concurrent
  /// 401s produce one refresh: the second through fifth callers await this
  /// rather than starting their own. The same pattern `FirebaseInitializer`
  /// and `DatabaseService.open` use for the same reason.
  Future<String?>? _refreshInFlight;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // `avoid_void_async` (ADR-021) forbids marking this override `async`, and
    // Dio fixes the signature as returning void. `unawaited` is the sanctioned
    // form for both that rule and `unawaited_futures`: the handler, not the
    // return value, is what resumes the chain.
    unawaited(_attach(options, handler));
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    unawaited(_recover(err, handler));
  }

  /// Reads a token and puts it on the request.
  Future<void> _attach(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[retriedFlag] == true) {
      // A replay. `_recover` has already put the freshly refreshed credential
      // on this request, and reading the source again would overwrite it with
      // whatever is cached — which, on a source that caches, is the very token
      // the server just rejected.
      handler.next(options);
      return;
    }

    final String? token;
    try {
      token = await tokenSource.currentToken();
    } on AppException catch (error, stackTrace) {
      // The source could not answer — the platform is down, not the user
      // signed out. Failing here is deliberate: sending the request without a
      // credential would surface a local fault as a server 401.
      handler.reject(
        _rejection(
          options,
          errorCode: ErrorCode.authUnauthenticated,
          message:
              'No credential could be obtained for '
              '${options.method} ${options.uri}.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }

    if (token != null) {
      options.headers[NetworkConstants.authorizationHeader] =
          '${NetworkConstants.bearerPrefix}$token';
    }

    // A null token is not a failure. Nobody is signed in, the request goes out
    // unauthenticated, and the backend decides — it is the sole arbiter of
    // authorization per Volume 4 Chapter 4.8 §1.
    handler.next(options);
  }

  /// Renews the credential once and replays the request, on a 401 only.
  Future<void> _recover(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;

    final bool isUnauthorized =
        err.response?.statusCode == NetworkConstants.unauthorized;
    final bool alreadyRetried = options.extra[retriedFlag] == true;

    if (!isUnauthorized || alreadyRetried) {
      // Not ours, or ours and already tried once. A second 401 after a fresh
      // token is not transient, and retrying again is the loop §16 forbids.
      handler.next(err);
      return;
    }

    final String? token;
    try {
      token = await _refreshOnce();
    } on AppException catch (error, stackTrace) {
      handler.reject(
        _rejection(
          options,
          errorCode: ErrorCode.authTokenRefreshFailed,
          message: 'Renewing the credential for ${options.uri} failed.',
          cause: error,
          stackTrace: stackTrace,
          response: err.response,
        ),
      );
      return;
    }

    if (token == null) {
      // The session cannot be renewed. Fail the request and stop. Sign-out is
      // the session stream's job, not this class's — see the class comment.
      handler.reject(
        _rejection(
          options,
          errorCode: ErrorCode.authTokenRefreshFailed,
          message:
              'The session could not be renewed after '
              '${options.uri} was rejected.',
          cause: err,
          response: err.response,
        ),
      );
      return;
    }

    options
      ..headers[NetworkConstants.authorizationHeader] =
          '${NetworkConstants.bearerPrefix}$token'
      ..extra[retriedFlag] = true;

    try {
      handler.resolve(await client.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      // The replay failed on its own terms. Pass the second failure along
      // rather than the first: it is the more recent truth, and it has already
      // travelled the chain.
      handler.next(retryError);
    }
  }

  /// Runs at most one refresh at a time, shared by every waiting caller.
  Future<String?> _refreshOnce() async {
    final Future<String?>? inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final Future<String?> started = tokenSource.refreshToken();
    _refreshInFlight = started;
    try {
      return await started;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Builds the envelope Dio requires around a [NetworkException].
  ///
  /// A `NetworkException` carrying an `AUTH_*` code, not an
  /// `AuthenticationException` — the shape `ErrorInterceptor` already uses
  /// when it maps a 401, and the reason `DioClient`'s unwrap needs no change.
  /// error-handling.md §8: the transport succeeded, the request was refused
  /// for an identity reason, and the `ErrorCode` is what says so.
  DioException _rejection(
    RequestOptions options, {
    required ErrorCode errorCode,
    required String message,
    Object? cause,
    StackTrace? stackTrace,
    Response<dynamic>? response,
  }) {
    return DioException(
      requestOptions: options,
      response: response,
      error: NetworkException(
        errorCode: errorCode,
        message: message,
        statusCode: response?.statusCode,
        cause: cause,
        stackTrace: stackTrace,
      ),
      stackTrace: stackTrace,
    );
  }
}
