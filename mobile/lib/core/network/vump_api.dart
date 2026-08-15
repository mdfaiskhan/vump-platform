import 'package:dio/dio.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/network/dio_client.dart';

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
    final Response<Map<String, dynamic>> response = await _http
        .post<Map<String, dynamic>>('$versionPrefix$path', data: body);
    return _unwrap(response, what);
  }

  /// `PATCH $versionPrefix$path`, returning the envelope's `data`.
  Future<Map<String, Object?>> patch(
    String path, {
    required String what,
    Object? body,
  }) async {
    final Response<Map<String, dynamic>> response = await _http
        .patch<Map<String, dynamic>>('$versionPrefix$path', data: body);
    return _unwrap(response, what);
  }

  /// `GET $versionPrefix$path`, returning the envelope's `data`.
  Future<Map<String, Object?>> get(
    String path, {
    required String what,
    Map<String, dynamic>? queryParameters,
  }) async {
    final Response<Map<String, dynamic>> response = await _http
        .get<Map<String, dynamic>>(
          '$versionPrefix$path',
          queryParameters: queryParameters,
        );
    return _unwrap(response, what);
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

    final Object? error = body['error'];
    if (error is Map) {
      throw NetworkException(
        errorCode: ErrorCode.networkBadRequest,
        message:
            'The backend refused $what: '
            '${error['code'] ?? 'no code'} — '
            '${error['message'] ?? 'no message'}.',
        statusCode: response.statusCode,
      );
    }

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
}
