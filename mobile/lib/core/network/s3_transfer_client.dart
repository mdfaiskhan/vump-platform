import 'package:dio/dio.dart';

import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/network/interceptors/error_interceptor.dart';
import 'package:mobile/core/network/network_constants.dart';
import 'package:mobile/core/network/transfer_handle.dart';
import 'package:mobile/core/network/transfer_progress.dart';

/// Uploads bytes to a presigned S3 URL — and to nothing else.
///
/// Volume 5 Chapter 5.10 §1 step 2: *"Dio streams the local chunk file in
/// parts directly to S3 using those URLs — **the app never touches an AWS
/// credential**."* Volume 4 Chapter 4.10 §2 says the same from the other side.
///
/// ## Why this is a second client and not a flag on `DioClient`
///
/// **`AuthInterceptor` is unconditional.** It runs first in `DioClient`'s
/// chain and attaches `Authorization: Bearer <Firebase ID token>` to every
/// request that has a token. A presigned S3 request carries its own SigV4
/// authorisation in the query string, and S3 rejects a request that also
/// presents a conflicting `Authorization` header. So step 2 does not merely
/// *prefer* to skip the interceptor — it does not work with it attached.
///
/// Three ways to get there, and this is the third:
///
/// 1. **A bypass flag on `AuthInterceptor`.** Rejected. That class sits in the
///    verified request path, its refresh-once/shared-future logic is
///    load-bearing (error-handling.md §16), and giving it a branch for a
///    caller it should not know about is how that logic acquires a bug.
/// 2. **Strip the header per request.** Rejected. It relies on every future
///    caller remembering; the failure mode is a leaked credential.
/// 3. **A client that structurally cannot attach one.** This. There is no
///    `AuthTokenSource` in scope here, so no code path exists that could send
///    a Vump credential to Amazon.
///
/// ## No `baseUrl`
///
/// Presigned URLs are absolute and point at an AWS host, not at
/// `NetworkConfig.baseUrl`. Setting one would be inert at best and would
/// silently prefix a relative path at worst.
///
/// ## No send timeout — and why that is the documented choice, not an omission
///
/// See [NetworkConstants.uploadSendTimeout].
///
/// ## A presigned URL is a credential, so it is never logged
///
/// `LoggingInterceptor` writes `options.uri` **in full** — query string
/// included — on request, response and error. A presigned S3 URL carries
/// `X-Amz-Signature` and `X-Amz-Credential` as query parameters: anyone
/// holding that URL can write to the bucket until it expires.
/// `NetworkConstants.redactedHeaders` redacts *headers*; nothing in this
/// project redacts a query string.
///
/// So this client installs **no interceptors at all** and logs through
/// [AppLogger] directly, with every URL reduced by [redactUrl] to scheme, host
/// and path.
///
/// `ErrorInterceptor` is absent for the same reason rather than a different
/// one: `ErrorInterceptor.mapToNetworkException` builds its message from
/// `err.requestOptions.uri`, and `AppException.toString()` writes its `cause`
/// — which for a `DioException` prints the request URI again. Either path puts
/// the signature into a log line or an error surface. [_convert] therefore
/// reuses that method for its **classification only**, then rebuilds the
/// exception with a redacted message and **no cause**.
///
/// Dropping `cause` is a real diagnostic loss and is deliberate: the status
/// code, the Dio failure type and the redacted URL are kept, which is what a
/// failed upload is actually diagnosed from. Recorded as amendment A-074 and
/// re-verified in Mission 4.8's security review rather than taken on trust
/// from the mission that wrote it.
class S3TransferClient {
  /// Creates a client over a bare `Dio` with no interceptors.
  ///
  /// [dio] is injectable so a test can install a scripted `HttpClientAdapter`
  /// against the real client rather than replace the client with a fake.
  S3TransferClient({required AppLogger logger, Dio? dio})
    : _log = logger,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              // No baseUrl, no default Content-Type, no interceptors. See the
              // class comment for each.
              connectTimeout: NetworkConstants.connectTimeout,
              receiveTimeout: NetworkConstants.receiveTimeout,
              sendTimeout: NetworkConstants.uploadSendTimeout,
              responseType: ResponseType.plain,
            ),
          );

  final Dio _dio;
  final AppLogger _log;

  /// The header S3 returns for an accepted part, needed to complete a
  /// multipart upload.
  static const String etagHeader = 'etag';

  /// Uploads [bytes] to [presignedUrl] with `PUT`, returning its `ETag`.
  ///
  /// Chapter 5.10 §3: re-`PUT`ting a part with the same part number
  /// *"overwrites that part rather than duplicating it"*, so a retry of this
  /// call is safe by S3's own semantics and needs no guard here.
  ///
  /// [onProgress] is Chapter 5.10 §2's callback, reaching C-11 unchanged.
  /// [handle] is §4's cancellation.
  ///
  /// Throws a [NetworkException] — never a `DioException`, and never one whose
  /// message or cause names the signed URL.
  Future<String?> uploadPart({
    required Uri presignedUrl,
    required List<int> bytes,
    TransferProgress? onProgress,
    TransferHandle? handle,
  }) async {
    final String safeUrl = redactUrl(presignedUrl);
    _log.debug('→ PUT $safeUrl (${bytes.length} bytes)');

    try {
      final Response<String> response = await _dio.putUri<String>(
        presignedUrl,
        data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        options: Options(
          headers: <String, Object>{
            Headers.contentLengthHeader: bytes.length,
            // Deliberately no Authorization header, and no way to add one:
            // this client holds no token source.
            NetworkConstants.contentTypeHeader: binaryContentType,
          },
          responseType: ResponseType.plain,
        ),
        onSendProgress: onProgress,
        cancelToken: handle?.token,
      );

      _log.debug('← ${response.statusCode} PUT $safeUrl');
      return _etagOf(response);
    } on DioException catch (error, stackTrace) {
      _log.warning(
        '✗ ${error.response?.statusCode ?? error.type.name} PUT $safeUrl',
      );
      throw _convert(error, safeUrl, stackTrace);
    }
  }

  /// Media type for an opaque byte range.
  ///
  /// A part is a slice of an `.mp4`, not a whole one, so `video/mp4` would
  /// describe it wrongly for every part but the first.
  static const String binaryContentType = 'application/octet-stream';

  /// [url] reduced to scheme, host and path — no query, no fragment.
  ///
  /// **This is the function that keeps a presigned URL out of the logs.** The
  /// signature, the credential scope and the expiry all live in the query
  /// string; the host and path are what a reader needs to tell one bucket or
  /// object from another.
  ///
  /// Exposed as a static so it is directly testable and so any future caller
  /// handling a presigned URL has one obvious thing to use.
  static String redactUrl(Uri url) {
    return Uri(
      scheme: url.scheme,
      host: url.host,
      port: url.hasPort ? url.port : null,
      path: url.path,
    ).toString();
  }

  /// Reads the `ETag` S3 returns for an accepted part.
  ///
  /// Null rather than throwing when absent: the part landed — the status said
  /// so — and completing the multipart upload without an ETag is the caller's
  /// problem to classify, not a transport failure to raise here.
  String? _etagOf(Response<String> response) {
    final String? raw = response.headers.value(etagHeader);
    // S3 quotes the value. Callers compare it against what they later send
    // back, so the quoting is stripped once, here, rather than at each use.
    return raw?.replaceAll('"', '');
  }

  /// Rebuilds a Dio failure as a [NetworkException] that names no signature.
  ///
  /// Classification is delegated to [ErrorInterceptor.mapToNetworkException]
  /// so this client and `DioClient` cannot drift about what a timeout or a
  /// 5xx means. Only the message and the cause are replaced.
  NetworkException _convert(
    DioException error,
    String safeUrl,
    StackTrace stackTrace,
  ) {
    final NetworkException classified = ErrorInterceptor.mapToNetworkException(
      error,
    );

    return NetworkException(
      errorCode: classified.errorCode,
      message:
          'Uploading a chunk part to $safeUrl failed '
          '(${error.type.name}).',
      statusCode: error.response?.statusCode,
      // No `cause`. A DioException prints its request URI, and
      // AppException.toString() prints its cause — see the class comment.
      stackTrace: stackTrace,
    );
  }

  /// Releases the underlying client.
  ///
  /// [force] closes sockets mid-transfer. The composition root owns one
  /// instance for the process lifetime, so this exists for tests and for a
  /// future shutdown path rather than for routine use.
  void close({bool force = false}) => _dio.close(force: force);
}
