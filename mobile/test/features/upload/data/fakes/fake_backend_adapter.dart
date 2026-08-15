import 'dart:convert';

import 'package:dio/dio.dart';

/// One request the scripted backend saw.
class RecordedRequest {
  /// Records a request.
  RecordedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  /// `GET`, `POST`, `PATCH`, `PUT`.
  final String method;

  /// The full URI, query string included.
  final Uri uri;

  /// Every header the client actually sent.
  ///
  /// **This is what the `Authorization` assertion reads.** Recording the whole
  /// map rather than a boolean is what lets a test prove the header is absent
  /// from the S3 `PUT` and present on the Vump calls, from the same evidence.
  final Map<String, List<String>> headers;

  /// The decoded JSON body, or null for a binary or empty one.
  final Map<String, Object?>? body;

  /// Whether an `Authorization` header was sent, case-insensitively.
  ///
  /// HTTP header names are case-insensitive and Dio lower-cases them, but a
  /// test asserting on the wrong casing would pass while the header was
  /// present — the exact false negative this whole fake exists to prevent.
  bool get hasAuthorization =>
      headers.keys.any((String k) => k.toLowerCase() == 'authorization');
}

/// A scripted Vump backend and S3, installed under a real Dio client.
///
/// Volume 9 Chapter 9.7 §1 specifies *"a fake backend (a local mock server
/// returning scripted responses) rather than the real staging environment —
/// fast, deterministic, and runnable in CI"*. `integration_test` is not
/// installed (open item 20), so this is that idea at the tier available now:
/// an `HttpClientAdapter` swapped in beneath the **real** `DioClient`,
/// `VumpApi`, `S3TransferClient` and `ChunkUploadApiImpl`.
///
/// That placement is the point. Faking the repository would test the pipeline
/// and leave the code that builds Chapter 4.6 §5's request body and parses its
/// envelope completely unexercised — which is where a contract mismatch would
/// actually live. Here every layer below the pipeline is real, and only the
/// socket is not.
///
/// Nothing in `lib/` binds this. Volume 11's M12 gate makes a fake repository
/// wired into a release build a defect in its own right, and Volume 11 step 9
/// treats fakes as *"the fakes used in Volume 9, Chapter 9.6/9.7's tests"*.
class FakeBackendAdapter implements HttpClientAdapter {
  /// Creates an adapter with the happy path scripted.
  FakeBackendAdapter({
    this.remoteSessionId = 'srv_sess_1',
    this.s3ObjectKey = 'org_9f2/proj_4a1/task_7c3/sess_e810/0003_chk_5b2a.mp4',
    this.partCount = 1,
  });

  /// The session id `POST /v1/tasks/{id}/sessions` returns.
  final String remoteSessionId;

  /// The key `POST /v1/sessions/{id}/chunks` returns.
  final String s3ObjectKey;

  /// How many presigned URLs registration hands back.
  ///
  /// The backend chooses this, so a test can set it to 3 and watch the client
  /// split one file into three ranged `PUT`s.
  final int partCount;

  /// Every request, in order.
  final List<RecordedRequest> requests = <RecordedRequest>[];

  /// Status codes to answer with, keyed by `'<METHOD> <path-substring>'`.
  ///
  /// Set `'POST /chunks'` to 500 and the registration call fails transiently;
  /// set `'PUT s3'` to 403 and the part upload is refused. Chapter 5.13 §1's
  /// three classes are reachable without touching the client.
  final Map<String, int> statusOverrides = <String, int>{};

  /// Envelope errors to answer with, keyed the same way.
  ///
  /// Chapter 4.6 §1 requires errors carry *"a specific code, never a bare HTTP
  /// status alone"*, so a refusal can be scripted with a real code even on a
  /// 200.
  final Map<String, Map<String, Object?>> errorOverrides =
      <String, Map<String, Object?>>{};

  /// Presigned URLs handed out, so a test can assert the client used them.
  List<String> get issuedUploadUrls => <String>[
    for (int i = 1; i <= partCount; i++) _presignedUrl(i),
  ];

  /// One presigned URL, shaped as AWS actually shapes them.
  ///
  /// The `X-Amz-Signature` and `X-Amz-Credential` query parameters are the
  /// reason `S3TransferClient.redactUrl` exists: they are a bearer credential
  /// for writing to the bucket, and `LoggingInterceptor` would have written
  /// them to a log in full.
  String _presignedUrl(int partNumber) =>
      'https://human-archive-dev.s3.amazonaws.com/$s3ObjectKey'
      '?partNumber=$partNumber&uploadId=up_1'
      '&X-Amz-Credential=AKIAEXAMPLE%2F20260815%2Fus-east-1%2Fs3'
      '&X-Amz-Signature=deadbeefcafe$partNumber';

  /// The requests that went to S3 rather than to the Vump backend.
  Iterable<RecordedRequest> get s3Requests =>
      requests.where((RecordedRequest r) => r.uri.host.contains('s3'));

  /// The requests that went to the Vump backend.
  Iterable<RecordedRequest> get backendRequests =>
      requests.where((RecordedRequest r) => !r.uri.host.contains('s3'));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final List<int> raw = requestStream == null
        ? const <int>[]
        : await requestStream.expand<int>((List<int> c) => c).toList();

    requests.add(
      RecordedRequest(
        method: options.method,
        uri: options.uri,
        headers: options.headers.map(
          (String k, dynamic v) =>
              MapEntry<String, List<String>>(k, <String>['$v']),
        ),
        body: _decodeBody(options.data, raw),
      ),
    );

    return _respond(options);
  }

  Map<String, Object?>? _decodeBody(Object? data, List<int> raw) {
    if (data is Map) {
      return data.map(
        (Object? k, Object? v) => MapEntry<String, Object?>('$k', v),
      );
    }
    if (raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(utf8.decode(raw));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      // A part's bytes. Not JSON, and not meant to be.
      return null;
    }
  }

  ResponseBody _respond(RequestOptions options) {
    final String path = options.uri.path;
    final String method = options.method.toUpperCase();
    final bool isS3 = options.uri.host.contains('s3');

    final String? key = _matchKey(method, isS3 ? 's3' : path);
    final int status = key == null ? 200 : statusOverrides[key]!;

    if (isS3) {
      return ResponseBody.fromString(
        '',
        status,
        headers: <String, List<String>>{
          'etag': <String>[
            '"etag-${options.uri.queryParameters['partNumber']}"',
          ],
        },
      );
    }

    final String? errorKey = _matchErrorKey(method, path);
    if (errorKey != null) {
      return _json(<String, Object?>{
        'data': null,
        'error': errorOverrides[errorKey],
      }, status == 200 ? 400 : status);
    }

    if (status >= 400) {
      return _json(<String, Object?>{
        'data': null,
        'error': <String, Object?>{
          'code': 'SCRIPTED_$status',
          'message': 'Scripted failure.',
        },
      }, status);
    }

    // Chapter 4.6 §4's endpoints.
    if (method == 'POST' &&
        path.contains('/sessions') &&
        !path.endsWith('/chunks')) {
      return _json(<String, Object?>{
        'data': <String, Object?>{'session_id': remoteSessionId},
        'error': null,
      }, 201);
    }
    if (method == 'POST' && path.endsWith('/chunks')) {
      // Chapter 4.6 §5's response, verbatim in shape.
      return _json(<String, Object?>{
        'data': <String, Object?>{
          'chunk_id': _chunkIdOf(path) ?? 'chk_1',
          's3_object_key': s3ObjectKey,
          'upload_urls': issuedUploadUrls,
        },
        'error': null,
      }, 201);
    }
    if (method == 'PATCH' && path.endsWith('/status')) {
      // Chapter 5.10 §3 — idempotent, so a repeat is a plain success.
      return _json(<String, Object?>{'data': null, 'error': null}, 200);
    }
    if (method == 'POST' && path.endsWith('/metadata')) {
      return _json(<String, Object?>{'data': null, 'error': null}, 201);
    }

    return _json(<String, Object?>{
      'data': null,
      'error': <String, Object?>{
        'code': 'NOT_SCRIPTED',
        'message': 'No script for $method $path.',
      },
    }, 404);
  }

  /// The chunk id registration should echo, read back from the request path.
  String? _chunkIdOf(String path) => registeredChunkId;

  /// Overrides the `chunk_id` registration echoes.
  ///
  /// Left null for the happy path, where the adapter echoes whatever the test
  /// set. Setting it to a different value is how the mismatch guard is tested.
  String? registeredChunkId;

  String? _matchKey(String method, String pathOrS3) {
    for (final String key in statusOverrides.keys) {
      final List<String> parts = key.split(' ');
      if (parts.first == method && pathOrS3.contains(parts.last)) {
        return key;
      }
    }
    return null;
  }

  String? _matchErrorKey(String method, String path) {
    for (final String key in errorOverrides.keys) {
      final List<String> parts = key.split(' ');
      if (parts.first == method && path.contains(parts.last)) {
        return key;
      }
    }
    return null;
  }

  ResponseBody _json(Map<String, Object?> body, int status) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
