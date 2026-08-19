import 'package:dio/dio.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/network/dio_client.dart';

/// One page of a list endpoint — the rows, and where the next page starts.
///
/// ## Why this type exists at all
///
/// Chapter 4.6 §1 puts pagination in `meta.nextCursor`, and [VumpApi] returned
/// the envelope's `data` and nothing else. A-184 recorded the consequence: an
/// org with 51 Projects rendered 50, *"with no error, no empty state and
/// nothing on either side reporting a truncation"*. `data` alone cannot express
/// a page, so a list read needs a return type that can.
///
/// It carries the raw rows rather than a decoded entity. `core/network/` knows
/// about envelopes and knows nothing about Projects — decoding belongs to the
/// feature's `data/` layer, which is where every other DTO mapping in this
/// project already lives.
class ApiPage {
  /// Creates a page.
  const ApiPage({required this.rows, required this.nextCursor});

  /// The envelope's `data` array, one map per row.
  final List<Map<String, Object?>> rows;

  /// The cursor for the next page, or null on the last one.
  ///
  /// Null and absent are the same answer. Chapter 4.6 §1 makes `meta` absent
  /// entirely on non-list endpoints and `nextCursor` null on the last page, and
  /// both mean *"there is nothing after this"*.
  final String? nextCursor;

  /// Whether a further page exists.
  bool get hasMore => nextCursor != null;
}

/// The Vump backend, spoken to in Volume 4 Chapter 4.6 §1's conventions.
///
/// Returns the envelope's `data` object and nothing else. **No Dio type
/// crosses this boundary** — not `Response`, not `Options`, not
/// `DioException`.
///
/// ## Why this exists, and what it fixes
///
/// `DioClient`'s verb methods return `Future<Response<T>>`. `Response` is a
/// Dio type, so *any* caller of them must import `package:dio` — which the
/// `Architecture boundaries` CI job confines to `core/network/`. The rule was
/// green only because nothing outside `core/network/` had ever called
/// `DioClient`: `features/auth/data/` talks to Firebase, and Missions 3.x made
/// no network calls at all. Mission 4.2 is the first feature consumer, and it
/// surfaced the gap immediately.
///
/// Two ways out. Widening the confinement to admit `features/upload/data/` was
/// rejected — it is the first crack in a rule that has held for thirteen
/// packages, and S1's whole lesson (A-067) is that confinement gaps go unseen
/// for missions at a time. So `core/network/` publishes a type instead, which
/// is the same move `TransferHandle` and `TransferProgress` make for
/// cancellation and progress, and the same inversion ADR-035 and ADR-040
/// established. ADR-041 records all three together.
///
/// `DioClient` is unchanged. It stays the general-purpose client with its
/// interceptor chain and its no-`DioException`-escapes guarantee; this sits on
/// top and adds the one thing every Vump endpoint has in common.
///
/// ## The envelope is the contract, not the status code
///
/// Chapter 4.6 §1: *"`{ "data": …, "error": null }` on success, `{ "data":
/// null, "error": { "code", "message" } }` on failure — errors always carry a
/// specific code, never a bare HTTP status alone, mirroring Chapter 2.9's
/// named-cause-and-fix rule at the API layer."*
///
/// So a 2xx carrying a populated `error` is a failure here. Reading the status
/// alone would let a named backend refusal pass as success, which is exactly
/// the *"generic 'Something went wrong'"* failure mode Chapter 2.9 §2 treats
/// as a defect.
class VumpApi {
  /// Creates an API over [client].
  VumpApi({required DioClient client}) : _http = client;

  final DioClient _http;

  /// Volume 4 Chapter 4.6 §1: *"Base path: `/v1/…`"*.
  ///
  /// *"a breaking change bumps to `/v2` rather than mutating existing
  /// contracts"*, so this is a constant rather than a value a caller supplies.
  static const String versionPrefix = '/v1';

  /// `POST $versionPrefix$path`, returning the envelope's `data`.
  ///
  /// [what] names the operation for error messages — Chapter 2.9 §2 forbids a
  /// failure that does not say what failed.
  Future<Map<String, Object?>> post(
    String path, {
    required String what,
    Object? body,
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _http
          .post<Map<String, dynamic>>('$versionPrefix$path', data: body);
      return _unwrap(response, what);
    } on NetworkException catch (error) {
      throw _named(error, what);
    }
  }

  /// `PATCH $versionPrefix$path`, returning the envelope's `data`.
  Future<Map<String, Object?>> patch(
    String path, {
    required String what,
    Object? body,
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _http
          .patch<Map<String, dynamic>>('$versionPrefix$path', data: body);
      return _unwrap(response, what);
    } on NetworkException catch (error) {
      throw _named(error, what);
    }
  }

  /// `GET $versionPrefix$path`, returning the envelope's `data`.
  Future<Map<String, Object?>> get(
    String path, {
    required String what,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _http
          .get<Map<String, dynamic>>(
            '$versionPrefix$path',
            queryParameters: queryParameters,
          );
      return _unwrap(response, what);
    } on NetworkException catch (error) {
      throw _named(error, what);
    }
  }

  /// `GET $versionPrefix$path`, returning one page of a list endpoint.
  ///
  /// **Separate from [get] rather than a widening of it.** Two reasons, and
  /// neither is style:
  ///
  ///  * A list route's `data` is a JSON **array**, and [get]'s contract is that
  ///    it returns the `data` **object**. `_unwrap` throws
  ///    `NETWORK_SERIALIZATION` on an array, which is correct for what [get]
  ///    promises — so a list read was not merely unsupported, it was refused.
  ///  * [get], [post] and [patch] have three verified callers between them
  ///    (auth verification and two chunk-upload steps). Changing their return
  ///    type to carry a `meta` none of them has would edit a request path that
  ///    has been exercised against the real backend, to no purpose.
  ///
  /// [cursor] and [limit] are Chapter 4.6 §1's `?cursor=&limit=`. Both are
  /// omitted from the query string when null, so a first page sends neither and
  /// the backend applies its own `DEFAULT_LIMIT`.
  Future<ApiPage> getList(
    String path, {
    required String what,
    String? cursor,
    int? limit,
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _http
          .get<Map<String, dynamic>>(
            '$versionPrefix$path',
            // Null-aware elements: an absent cursor or limit drops out of the
            // query string entirely rather than being sent empty, so a first
            // page asks for neither and the backend applies DEFAULT_LIMIT.
            queryParameters: <String, dynamic>{
              'cursor': ?cursor,
              'limit': ?limit,
            },
          );
      return _unwrapPage(response, what);
    } on NetworkException catch (error) {
      throw _named(error, what);
    }
  }

  /// `DELETE $versionPrefix$path`, returning the envelope's `data`.
  ///
  /// Added for `DELETE /v1/tasks/{id}/assignments/{userId}`, which answers 204
  /// with a null `data` — [_unwrap] reads that as an empty map, the same way it
  /// already reads a `PATCH` with nothing to say.
  Future<Map<String, Object?>> delete(
    String path, {
    required String what,
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _http
          .delete<Map<String, dynamic>>('$versionPrefix$path');
      return _unwrap(response, what);
    } on NetworkException catch (error) {
      throw _named(error, what);
    }
  }

  /// Recovers the backend's named error from a non-2xx response.
  ///
  /// **This is the half of Chapter 4.6 §1 that a plain client loses.**
  /// `ErrorInterceptor` converts a 400 into `NETWORK_BAD_REQUEST: Server
  /// returned 400 for POST …` before anything reads the body — correct for a
  /// general-purpose client, which knows nothing about envelopes, and wrong
  /// here. The chapter requires that errors *"always carry a specific code,
  /// never a bare HTTP status alone, mirroring Chapter 2.9's
  /// named-cause-and-fix rule at the API layer"*, and Chapter 2.9 §2 calls a
  /// generic failure message a defect rather than a fallback.
  ///
  /// Found by a test in Mission 4.2 that scripted a `CHUNK_ALREADY_REGISTERED`
  /// refusal and got back a bare 400. `ErrorInterceptor` is deliberately not
  /// changed — it sits in the verified request path and its behaviour is right
  /// for what it knows. The envelope knowledge belongs here, which is the
  /// class that has it.
  ///
  /// Returns [error] unchanged when the body carries no envelope error, so a
  /// genuine transport failure keeps its own classification.
  NetworkException _named(NetworkException error, String what) {
    final Object? cause = error.cause;
    if (cause is! DioException) {
      return error;
    }
    final Object? body = cause.response?.data;
    if (body is! Map) {
      return error;
    }
    final Object? envelope = body['error'];
    if (envelope is! Map) {
      return error;
    }

    final Object? code = envelope['code'];
    return NetworkException(
      errorCode: error.errorCode,
      message:
          'The backend refused $what: '
          '${code ?? 'no code'} — '
          '${envelope['message'] ?? 'no message'}.',
      statusCode: error.statusCode,
      // Structural since Mission 7.4, F29. The message keeps the code too, for
      // a log; a caller that needs to branch reads this instead of the prose.
      backendCode: code is String ? code : null,
      cause: cause,
      stackTrace: error.stackTrace,
    );
  }

  /// Reads Chapter 4.6 §1's envelope, or throws.
  ///
  /// An empty `data` object is returned as an empty map rather than raised: a
  /// `PATCH` that succeeds has nothing to say, and requiring a payload from it
  /// would make every no-content endpoint look malformed.
  Map<String, Object?> _unwrap(
    Response<Map<String, dynamic>> response,
    String what,
  ) {
    final Map<String, dynamic>? body = response.data;
    if (body == null) {
      // A 204, or a body the client could not decode. Both mean "no envelope",
      // and for a successful status that is a no-content success.
      return const <String, Object?>{};
    }

    _throwIfEnvelopeError(body, what, response.statusCode);

    final Object? data = body['data'];
    if (data == null) {
      return const <String, Object?>{};
    }
    if (data is! Map<String, dynamic>) {
      throw NetworkException(
        errorCode: ErrorCode.networkSerialization,
        message: 'The response to $what carried no data object.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  /// Reads a list endpoint's envelope: a `data` array plus `meta.nextCursor`.
  ///
  /// A missing or null `data` is an **empty page**, not a malformed response. A
  /// list route with nothing to return is an ordinary answer — no assigned
  /// work, a Project with no Tasks — and the screens above this draw a real
  /// distinction between "empty" and "failed" that a throw here would erase.
  ///
  /// A `data` that is present and is **not** an array is malformed, and is
  /// raised: that is the shape a non-list endpoint returns, which means the
  /// caller used the wrong method.
  ApiPage _unwrapPage(Response<Map<String, dynamic>> response, String what) {
    final Map<String, dynamic>? body = response.data;
    if (body == null) {
      return const ApiPage(rows: <Map<String, Object?>>[], nextCursor: null);
    }

    _throwIfEnvelopeError(body, what, response.statusCode);

    final Object? data = body['data'];
    if (data == null) {
      return const ApiPage(rows: <Map<String, Object?>>[], nextCursor: null);
    }
    if (data is! List) {
      throw NetworkException(
        errorCode: ErrorCode.networkSerialization,
        message: 'The response to $what carried no data array.',
        statusCode: response.statusCode,
      );
    }

    // A non-map element is dropped rather than raised, for the same reason the
    // empty page is not raised: one unreadable row must not lose the page.
    final List<Map<String, Object?>> rows = <Map<String, Object?>>[
      for (final Object? row in data)
        if (row is Map<String, Object?>) row,
    ];

    final Object? meta = body['meta'];
    final Object? cursor = meta is Map ? meta['nextCursor'] : null;

    return ApiPage(
      rows: rows,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }

  /// Raises Chapter 4.6 §1's named refusal when the envelope carries one.
  ///
  /// Shared by [_unwrap] and [_unwrapPage] because the rule is the envelope's,
  /// not either method's: *"a 2xx carrying a populated `error` is a failure
  /// here"*, whatever shape `data` would have had.
  void _throwIfEnvelopeError(
    Map<String, dynamic> body,
    String what,
    int? statusCode,
  ) {
    final Object? error = body['error'];
    if (error is! Map) {
      return;
    }
    final Object? code = error['code'];
    throw NetworkException(
      errorCode: ErrorCode.networkBadRequest,
      message:
          'The backend refused $what: '
          '${code ?? 'no code'} — '
          '${error['message'] ?? 'no message'}.',
      statusCode: statusCode,
      backendCode: code is String ? code : null,
    );
  }
}
