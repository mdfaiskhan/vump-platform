import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/network/interceptors/error_interceptor.dart';

/// The 13 mappings error-handling.md §8 documents.
///
/// §30 recorded this file's absence as *"the highest-value missing test in the
/// repository"* and named this exact path. `mapToNetworkException` is a static
/// specifically so it is reachable without a live client, and §28's "a test
/// per mapped code" rule is what this closes.
///
/// Added by Mission 2.8, whose audit found it: it is outside `features/auth/`,
/// but two of the mappings below produce `AUTH_*` codes, and it is the one
/// file the standard itself names as violating the rule being audited.
void main() {
  final RequestOptions options = RequestOptions(path: '/v1/projects');

  DioException dioError(DioExceptionType type, {int? status, Object? error}) {
    return DioException(
      requestOptions: options,
      type: type,
      error: error,
      response: status == null
          ? null
          : Response<dynamic>(requestOptions: options, statusCode: status),
    );
  }

  ErrorCode codeFor(DioException error) =>
      ErrorInterceptor.mapToNetworkException(error).errorCode;

  group('transport failures', () {
    test('all four timeout types map to NETWORK_TIMEOUT', () {
      // Grouped in one arm in the source; asserted individually here, because
      // a regression would most likely drop one from the group.
      for (final DioExceptionType type in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(
          codeFor(dioError(type)),
          ErrorCode.networkTimeout,
          reason: '$type',
        );
      }
    });

    test('cancel maps to NETWORK_CANCELLED', () {
      expect(
        codeFor(dioError(DioExceptionType.cancel)),
        ErrorCode.networkCancelled,
      );
    });

    test('connectionError maps to NETWORK_UNAVAILABLE', () {
      expect(
        codeFor(dioError(DioExceptionType.connectionError)),
        ErrorCode.networkUnavailable,
      );
    });

    test('badCertificate is UNAVAILABLE, not a code of its own', () {
      // §8: "a hard failure with no client-side remedy, and giving it a code
      // would invite a retry".
      expect(
        codeFor(dioError(DioExceptionType.badCertificate)),
        ErrorCode.networkUnavailable,
      );
    });
  });

  group('failures Dio could not classify', () {
    test('a wrapped SocketException is NETWORK_UNAVAILABLE', () {
      expect(
        codeFor(
          dioError(
            DioExceptionType.unknown,
            error: const SocketException('no route'),
          ),
        ),
        ErrorCode.networkUnavailable,
      );
    });

    test('a wrapped FormatException is NETWORK_SERIALIZATION', () {
      expect(
        codeFor(
          dioError(
            DioExceptionType.unknown,
            error: const FormatException('bad json'),
          ),
        ),
        ErrorCode.networkSerialization,
      );
    });

    test('anything else unknown degrades to UNKNOWN', () {
      expect(
        codeFor(dioError(DioExceptionType.unknown, error: StateError('x'))),
        ErrorCode.unknown,
      );
    });
  });

  group('responses that arrived with a failing status', () {
    test('401 and 403 map to AUTH_ codes, not NETWORK_', () {
      // §8 states the reasoning: "the transport succeeded; the request was
      // refused for an identity reason". This is the property AuthInterceptor
      // relies on (ADR-035).
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 401)),
        ErrorCode.authUnauthenticated,
      );
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 403)),
        ErrorCode.authForbidden,
      );
    });

    test('404, 409 and 429 map to their specific codes', () {
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 404)),
        ErrorCode.networkNotFound,
      );
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 409)),
        ErrorCode.networkConflict,
      );
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 429)),
        ErrorCode.networkRateLimited,
      );
    });

    test('5xx maps to NETWORK_SERVER_ERROR', () {
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 500)),
        ErrorCode.networkServerError,
      );
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 503)),
        ErrorCode.networkServerError,
      );
    });

    test('an unlisted 4xx falls through to NETWORK_BAD_REQUEST', () {
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 400)),
        ErrorCode.networkBadRequest,
      );
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 418)),
        ErrorCode.networkBadRequest,
      );
    });

    test('the specific codes are checked before the ranges', () {
      // 429 is a 4xx and 500 is >= 400; if the guard clauses were reordered,
      // both would collapse into NETWORK_BAD_REQUEST. Asserted because
      // ordering is the failure mode a switch on ranges invites.
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 429)),
        isNot(ErrorCode.networkBadRequest),
      );
      expect(
        codeFor(dioError(DioExceptionType.badResponse, status: 500)),
        isNot(ErrorCode.networkBadRequest),
      );
    });

    test('a badResponse with no status degrades to UNKNOWN', () {
      expect(
        codeFor(dioError(DioExceptionType.badResponse)),
        ErrorCode.unknown,
      );
    });
  });

  group('what the exception carries', () {
    test('statusCode survives, because retry policy is written against it', () {
      final NetworkException converted = ErrorInterceptor.mapToNetworkException(
        dioError(DioExceptionType.badResponse, status: 503),
      );

      expect(converted.statusCode, 503);
    });

    test('statusCode is null for a transport failure', () {
      // §8: "null for transport failures, where no response was ever
      // received" — a caller must be able to tell those apart.
      expect(
        ErrorInterceptor.mapToNetworkException(
          dioError(DioExceptionType.connectionError),
        ).statusCode,
        isNull,
      );
    });

    test('the originating DioException is kept as cause', () {
      final DioException origin = dioError(DioExceptionType.cancel);

      expect(
        ErrorInterceptor.mapToNetworkException(origin).cause,
        same(origin),
      );
    });

    test('the message names the request, not just the failure', () {
      expect(
        ErrorInterceptor.mapToNetworkException(
          dioError(DioExceptionType.badResponse, status: 500),
        ).message,
        contains('/v1/projects'),
      );
    });
  });
}
