import 'package:dio/dio.dart';

import '../../logging/app_logger.dart';
import '../network_constants.dart';

/// Records every request, response and failure through [AppLogger].
///
/// Logs the method, URL, headers, body, status and elapsed time of each call.
///
/// ## Redaction
///
/// `AppLogger` documents that credentials must never be logged but cannot
/// enforce it — by the time a value reaches a log call it is an opaque string.
/// This interceptor is where the obligation is discharged, because here the
/// sensitive values are still identifiable as headers.
///
/// Every header named in [NetworkConstants.redactedHeaders] has its value
/// replaced before the map is handed to the logger. The header's *presence* is
/// still recorded, since knowing whether a request carried authorization is
/// exactly what makes a 401 diagnosable.
///
/// Bodies are **not** redacted. A body is unstructured at this layer and could
/// contain a password or token under any key. It is truncated, not sanitised.
/// Callers posting credentials must not rely on this interceptor to hide them.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({required this.logger});

  /// Destination for every line this interceptor writes.
  final AppLogger logger;

  /// Key under which the request start time is stashed on `RequestOptions`.
  ///
  /// `extra` is the sanctioned per-request scratch space and is not
  /// transmitted, so the timing does not leak into the request itself.
  static const String _startTimeKey = 'vump.request.start';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startTimeKey] = DateTime.now();

    logger.debug(
      '→ ${options.method} ${options.uri}\n'
      '  headers: ${_redactHeaders(options.headers)}'
      '${_formatBody('body', options.data)}',
    );

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final RequestOptions options = response.requestOptions;

    logger.debug(
      '← ${response.statusCode} ${options.method} ${options.uri} '
      '(${_elapsedFor(options)})'
      '${_formatBody('body', response.data)}',
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final RequestOptions options = err.requestOptions;
    final int? status = err.response?.statusCode;

    logger.warning(
      '✗ ${status ?? err.type.name} ${options.method} ${options.uri} '
      '(${_elapsedFor(options)})'
      '${_formatBody('body', err.response?.data)}',
      error: err.error ?? err,
    );

    handler.next(err);
  }

  /// Copies [headers], replacing the value of every sensitive entry.
  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    return headers.map((String name, dynamic value) {
      final bool isSensitive = NetworkConstants.redactedHeaders.contains(
        name.toLowerCase(),
      );
      return MapEntry<String, dynamic>(
        name,
        isSensitive ? NetworkConstants.redactedPlaceholder : value,
      );
    });
  }

  /// Renders [body] as an indented line, or nothing when there is no body.
  String _formatBody(String label, Object? body) {
    if (body == null) {
      return '';
    }

    final String rendered = body.toString();
    if (rendered.isEmpty) {
      return '';
    }

    final bool isTruncated = rendered.length > NetworkConstants.maxLoggedBodyLength;
    final String shown = isTruncated
        ? '${rendered.substring(0, NetworkConstants.maxLoggedBodyLength)}'
            '… (${rendered.length} chars)'
        : rendered;

    return '\n  $label: $shown';
  }

  /// Time since the request left [onRequest], as a readable string.
  String _elapsedFor(RequestOptions options) {
    final Object? start = options.extra[_startTimeKey];
    if (start is! DateTime) {
      return 'unknown';
    }
    return '${DateTime.now().difference(start).inMilliseconds}ms';
  }
}
