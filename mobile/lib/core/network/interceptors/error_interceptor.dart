import 'dart:io';

import 'package:dio/dio.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/network/network_constants.dart';

/// Translates every `DioException` into a [NetworkException].
///
/// This is the boundary Mission 0.10 defined: infrastructure catches its
/// client's native errors and converts them into the application's taxonomy,
/// so that no layer above imports Dio in order to handle a failure.
///
/// Dio can only propagate a `DioException`, so the converted exception is
/// carried in that envelope's `error` field. `DioClient` unwraps it, which is
/// what makes the guarantee hold end to end: a caller of `DioClient` sees a
/// [NetworkException] and never a `DioException`.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final NetworkException exception = mapToNetworkException(err);

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
        stackTrace: err.stackTrace,
      ),
    );
  }

  /// Maps a Dio failure onto the application's error vocabulary.
  ///
  /// Exposed as a static so the mapping is testable without a live client and
  /// reusable by any future adapter that produces a `DioException`.
  static NetworkException mapToNetworkException(DioException err) {
    final int? status = err.response?.statusCode;

    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => NetworkException(
        errorCode: ErrorCode.networkTimeout,
        message:
            'Request to ${err.requestOptions.uri} timed out '
            '(${err.type.name}).',
        cause: err,
        stackTrace: err.stackTrace,
      ),
      DioExceptionType.cancel => NetworkException(
        errorCode: ErrorCode.networkCancelled,
        message: 'Request to ${err.requestOptions.uri} was cancelled.',
        cause: err,
        stackTrace: err.stackTrace,
      ),
      DioExceptionType.connectionError => NetworkException(
        errorCode: ErrorCode.networkUnavailable,
        message: 'Could not reach ${err.requestOptions.uri}.',
        cause: err,
        stackTrace: err.stackTrace,
      ),
      DioExceptionType.badCertificate => NetworkException(
        errorCode: ErrorCode.networkUnavailable,
        message:
            'Rejected the TLS certificate presented by '
            '${err.requestOptions.uri}.',
        cause: err,
        stackTrace: err.stackTrace,
      ),
      DioExceptionType.badResponse => _mapStatus(err, status),
      DioExceptionType.unknown => _mapUnknown(err),
    };
  }

  /// Maps a response that arrived but carried a failing status code.
  static NetworkException _mapStatus(DioException err, int? status) {
    final ErrorCode code = switch (status) {
      NetworkConstants.unauthorized => ErrorCode.authUnauthenticated,
      NetworkConstants.forbidden => ErrorCode.authForbidden,
      NetworkConstants.notFound => ErrorCode.networkNotFound,
      NetworkConstants.conflict => ErrorCode.networkConflict,
      NetworkConstants.tooManyRequests => ErrorCode.networkRateLimited,
      final int s when s >= NetworkConstants.internalServerError =>
        ErrorCode.networkServerError,
      final int s when s >= NetworkConstants.clientErrorFloor =>
        ErrorCode.networkBadRequest,
      _ => ErrorCode.unknown,
    };

    return NetworkException(
      errorCode: code,
      message:
          'Server returned ${status ?? 'no status'} for '
          '${err.requestOptions.method} ${err.requestOptions.uri}.',
      statusCode: status,
      cause: err,
      stackTrace: err.stackTrace,
    );
  }

  /// Maps a failure Dio could not classify.
  ///
  /// Two cases are worth separating from the rest: a socket failure, which is
  /// a connectivity problem Dio did not label, and a decode failure, which
  /// means the response arrived but did not match its declared type.
  static NetworkException _mapUnknown(DioException err) {
    final Object? cause = err.error;

    if (cause is SocketException) {
      return NetworkException(
        errorCode: ErrorCode.networkUnavailable,
        message: 'No network route to ${err.requestOptions.uri}.',
        cause: err,
        stackTrace: err.stackTrace,
      );
    }

    if (cause is FormatException) {
      return NetworkException(
        errorCode: ErrorCode.networkSerialization,
        message:
            'Could not decode the response from '
            '${err.requestOptions.uri}.',
        cause: err,
        stackTrace: err.stackTrace,
      );
    }

    return NetworkException(
      errorCode: ErrorCode.unknown,
      message:
          'Unclassified network failure for '
          '${err.requestOptions.method} ${err.requestOptions.uri}.',
      cause: err,
      stackTrace: err.stackTrace,
    );
  }
}
