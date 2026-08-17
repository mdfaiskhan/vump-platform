import 'package:dio/dio.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:mobile/core/network/interceptors/error_interceptor.dart';
import 'package:mobile/core/network/interceptors/logging_interceptor.dart';
import 'package:mobile/core/network/interfaces/auth_token_source.dart';
import 'package:mobile/core/network/network_config.dart';

/// The application's HTTP client.
///
/// Wraps a configured `Dio` instance and guarantees the contract Mission 0.10
/// established: **no `DioException` escapes this class.** Every method throws
/// a [NetworkException] instead.
///
/// No URL is hardcoded here. The base URL, timeouts and default headers all
/// arrive via [NetworkConfig], which resolves them from the environment per
/// ADR-007.
///
/// ## Interceptor order
///
/// The chain is fixed and the order is load-bearing:
///
/// 1. `AuthInterceptor` — attaches credentials. First, so anything it adds is
///    visible to the redaction in step 2.
/// 2. `LoggingInterceptor` — records the call with sensitive headers redacted.
/// 3. `ErrorInterceptor` — converts failures into the error taxonomy.
///
/// Requests traverse the list in order and errors traverse it in the same
/// order, so logging observes the raw failure and conversion happens last.
/// Placing the error interceptor first would mean logging a wrapped exception
/// and losing Dio's own classification.
class DioClient {
  DioClient({
    required NetworkConfig config,
    required AppLogger logger,
    required AuthTokenSource tokenSource,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: config.baseUrl,
           connectTimeout: config.connectTimeout,
           receiveTimeout: config.receiveTimeout,
           sendTimeout: config.sendTimeout,
           headers: config.defaultHeaders,
           contentType: config.defaultHeaders['Content-Type'],
           responseType: ResponseType.json,
         ),
       ) {
    dio.interceptors.addAll(<Interceptor>[
      // `dio` is passed to the interceptor so a refreshed request replays
      // through this same chain — logged and converted like any other call.
      // It is available here because the field is assigned in the initializer
      // list, before this body runs.
      AuthInterceptor(tokenSource: tokenSource, client: dio),
      LoggingInterceptor(logger: logger),
      ErrorInterceptor(),
    ]);
  }

  /// The configured client.
  ///
  /// Exposed for the cases the verb methods below do not cover — multipart
  /// uploads, downloads, streamed responses. Callers using it directly take on
  /// the unwrapping that [_guard] performs, and must catch `DioException`
  /// themselves.
  final Dio dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Runs [send], converting any `DioException` that surfaces.
  ///
  /// `ErrorInterceptor` has already built the [NetworkException] and carried
  /// it in the envelope's `error` field; this unwraps it. The fallback covers
  /// a `DioException` raised outside the interceptor chain — a malformed
  /// request rejected before dispatch, for instance — so the guarantee holds
  /// even for failures the chain never saw.
  Future<Response<T>> _guard<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error, stackTrace) {
      final Object? converted = error.error;
      if (converted is NetworkException) {
        throw converted;
      }
      throw NetworkException(
        errorCode: ErrorCode.unknown,
        message:
            'Request to ${error.requestOptions.uri} failed before the '
            'interceptor chain could classify it.',
        statusCode: error.response?.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
