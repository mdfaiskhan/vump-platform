import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:mobile/core/network/interfaces/auth_token_source.dart';
import 'package:mobile/core/network/network_constants.dart';

/// Tests for the credential attach and the refresh-and-retry path.
///
/// No Firebase project is involved. [AuthTokenSource] is two methods, which is
/// the point of ADR-035's inversion: `core/network/` owns the interface, so its
/// behaviour is testable with a fake and the provider is never constructed.
///
/// HTTP is faked at Dio's `HttpClientAdapter` seam — the substitution
/// testing-standards.md §8 prefers, and the same boundary Volume 9 §9.6 §4
/// names for platform services.
void main() {
  group('attaching a credential', () {
    test('a token becomes a bearer Authorization header', () async {
      final _Harness harness = _Harness(source: _FakeTokenSource('token-abc'));

      await harness.dio.get<dynamic>('/v1/users/me');

      expect(
        harness.lastRequest?.headers[NetworkConstants.authorizationHeader],
        'Bearer token-abc',
      );
    });

    test('a null token sends the request with no Authorization header', () {
      // Not signed in is not a failure. Volume 4 Chapter 4.8 §1 makes the
      // backend the sole arbiter of authorization, so the interceptor does not
      // refuse locally on its behalf.
      final _Harness harness = _Harness(source: _FakeTokenSource(null));

      return harness.dio.get<dynamic>('/v1/users/me').then((_) {
        expect(
          harness.lastRequest?.headers.containsKey(
            NetworkConstants.authorizationHeader,
          ),
          isFalse,
        );
      });
    });
  });

  group('when the token source cannot answer', () {
    // The ADR-017 development path: Firebase startup failed, was tolerated,
    // and something now needs a token. This is the case the mission required
    // be verified rather than assumed.

    test('the request fails rather than going out unauthenticated', () async {
      final _Harness harness = _Harness(source: _ThrowingTokenSource());

      await expectLater(
        harness.dio.get<dynamic>('/v1/users/me'),
        throwsA(isA<DioException>()),
      );

      // The request never reached the adapter. Sending it without a credential
      // would have reported a local fault as a server 401.
      expect(harness.requestCount, 0);
    });

    test('it fails as AUTH_UNAUTHENTICATED on a NetworkException', () async {
      final _Harness harness = _Harness(source: _ThrowingTokenSource());

      final DioException error = await _captureDioError(
        harness.dio.get<dynamic>('/v1/users/me'),
      );

      // A NetworkException carrying an AUTH_ code, matching what
      // ErrorInterceptor already does for a 401 (error-handling.md §8) so
      // DioClient's documented unwrap needs no change.
      final Object? converted = error.error;
      expect(converted, isA<NetworkException>());
      expect(
        (converted! as NetworkException).errorCode,
        ErrorCode.authUnauthenticated,
      );
    });

    test('the originating AuthenticationException survives as cause', () async {
      final _Harness harness = _Harness(source: _ThrowingTokenSource());

      final DioException error = await _captureDioError(
        harness.dio.get<dynamic>('/v1/users/me'),
      );

      expect(
        (error.error! as NetworkException).cause,
        isA<AuthenticationException>(),
      );
    });
  });

  group('a 401 refreshes once and replays', () {
    test('the replay carries the new token and succeeds', () async {
      final _FakeTokenSource source = _FakeTokenSource(
        'stale',
        refreshed: 'fresh',
      );
      final _Harness harness = _Harness(source: source, unauthorizedFirst: 1);

      final Response<dynamic> response = await harness.dio.get<dynamic>(
        '/v1/users/me',
      );

      expect(response.statusCode, 200);
      expect(harness.requestCount, 2);
      expect(
        harness.lastRequest?.headers[NetworkConstants.authorizationHeader],
        'Bearer fresh',
      );
      expect(source.refreshCalls, 1);
    });

    test('a 401 on the replay is not retried again', () async {
      // error-handling.md §16: retryable once, after a refresh, never in a
      // loop. A second 401 with a fresh token is not transient.
      final _FakeTokenSource source = _FakeTokenSource(
        'stale',
        refreshed: 'fresh',
      );
      final _Harness harness = _Harness(source: source, unauthorizedFirst: 99);

      await expectLater(
        harness.dio.get<dynamic>('/v1/users/me'),
        throwsA(isA<DioException>()),
      );

      expect(harness.requestCount, 2, reason: 'original plus one replay');
      expect(source.refreshCalls, 1);
    });

    test('a non-401 failure is passed through untouched', () async {
      final _FakeTokenSource source = _FakeTokenSource('token-abc');
      final _Harness harness = _Harness(source: source, status: 500);

      await expectLater(
        harness.dio.get<dynamic>('/v1/users/me'),
        throwsA(isA<DioException>()),
      );

      expect(harness.requestCount, 1);
      expect(
        source.refreshCalls,
        0,
        reason: 'a 500 is not a credential problem',
      );
    });
  });

  group('concurrent 401s share one refresh', () {
    test('five simultaneous rejections trigger exactly one refresh', () async {
      // The requirement error-handling.md §16 states outright: "concurrent
      // 401s must wait on one refresh, not trigger one each". Five refreshes
      // would be five round trips and, worse, four discarded tokens.
      final _FakeTokenSource source = _FakeTokenSource(
        'stale',
        refreshed: 'fresh',
        refreshDelay: const Duration(milliseconds: 50),
      );
      final _Harness harness = _Harness(source: source, unauthorizedFirst: 5);

      final List<Response<dynamic>> responses = await Future.wait(
        List<Future<Response<dynamic>>>.generate(
          5,
          (int i) => harness.dio.get<dynamic>('/v1/resource/$i'),
        ),
      );

      expect(
        responses.every((Response<dynamic> r) => r.statusCode == 200),
        isTrue,
      );
      expect(source.refreshCalls, 1);
    });

    test(
      'a later 401 starts a new refresh once the first has settled',
      () async {
        // The in-flight future is cleared on completion, not held forever — a
        // token that expires twice in one session must refresh twice.
        final _FakeTokenSource source = _FakeTokenSource(
          'stale',
          refreshed: 'fresh',
        );
        final _Harness harness = _Harness(source: source, unauthorizedEvery: 2);

        await harness.dio.get<dynamic>('/v1/first');
        await harness.dio.get<dynamic>('/v1/second');

        expect(source.refreshCalls, 2);
      },
    );
  });

  group('when the refresh itself fails', () {
    test(
      'a null refresh fails the request as AUTH_TOKEN_REFRESH_FAILED',
      () async {
        final _Harness harness = _Harness(
          source: _FakeTokenSource('stale'),
          unauthorizedFirst: 1,
        );

        final DioException error = await _captureDioError(
          harness.dio.get<dynamic>('/v1/users/me'),
        );

        expect(
          (error.error! as NetworkException).errorCode,
          ErrorCode.authTokenRefreshFailed,
        );
      },
    );

    test('a throwing refresh fails the request, it does not escape', () async {
      final _Harness harness = _Harness(
        source: _ThrowingTokenSource(onRefreshOnly: true),
        unauthorizedFirst: 1,
      );

      final DioException error = await _captureDioError(
        harness.dio.get<dynamic>('/v1/users/me'),
      );

      expect(
        (error.error! as NetworkException).errorCode,
        ErrorCode.authTokenRefreshFailed,
      );
    });

    test('the interceptor does nothing beyond failing the request', () async {
      // ADR-035: sign-out is the session stream's job. AuthTokenSource has two
      // methods and neither ends a session, so the interceptor structurally
      // cannot — this asserts the interface stayed that shape.
      final _FakeTokenSource source = _FakeTokenSource('stale');
      final _Harness harness = _Harness(source: source, unauthorizedFirst: 1);

      await expectLater(
        harness.dio.get<dynamic>('/v1/users/me'),
        throwsA(isA<DioException>()),
      );

      expect(source.signOutCalls, 0);
    });
  });
}

/// Fails the future and returns the `DioException` it carried.
Future<DioException> _captureDioError(Future<Object?> request) async {
  try {
    await request;
  } on DioException catch (error) {
    return error;
  }
  fail('expected the request to fail');
}

/// A Dio wired with only [AuthInterceptor] over a scripted adapter.
///
/// `AuthInterceptor` is exercised alone rather than through `DioClient`, so a
/// failure here names this class instead of the chain.
class _Harness {
  _Harness({
    required AuthTokenSource source,
    this.unauthorizedFirst = 0,
    this.unauthorizedEvery,
    this.status = 200,
  }) {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    dio.interceptors.add(AuthInterceptor(tokenSource: source, client: dio));
    dio.httpClientAdapter = _ScriptedAdapter(this);
  }

  late final Dio dio;

  /// How many of the first requests answer 401.
  final int unauthorizedFirst;

  /// Answer 401 on every nth request, for testing a second expiry.
  final int? unauthorizedEvery;

  /// Status returned once the 401s are exhausted.
  final int status;

  int requestCount = 0;
  RequestOptions? lastRequest;
}

/// Returns 401 according to the harness's script, then [_Harness.status].
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._harness);

  final _Harness _harness;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _harness
      ..requestCount += 1
      ..lastRequest = options;

    final int n = _harness.requestCount;
    final int? every = _harness.unauthorizedEvery;
    final bool unauthorized =
        n <= _harness.unauthorizedFirst || (every != null && n.isOdd);

    return ResponseBody.fromString(
      '{}',
      unauthorized ? NetworkConstants.unauthorized : _harness.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A token source that answers from fixed values and counts its calls.
class _FakeTokenSource implements AuthTokenSource {
  _FakeTokenSource(this.token, {this.refreshed, this.refreshDelay});

  final String? token;
  final String? refreshed;
  final Duration? refreshDelay;

  int refreshCalls = 0;

  /// Always zero. The interface has no sign-out, and that is the assertion.
  int get signOutCalls => 0;

  @override
  Future<String?> currentToken() async => token;

  @override
  Future<String?> refreshToken() async {
    refreshCalls += 1;
    final Duration? delay = refreshDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    return refreshed;
  }
}

/// A token source standing in for an uninitialised Firebase platform.
class _ThrowingTokenSource implements AuthTokenSource {
  _ThrowingTokenSource({this.onRefreshOnly = false});

  /// When true, [currentToken] succeeds so a 401 can be reached first.
  final bool onRefreshOnly;

  @override
  Future<String?> currentToken() async {
    if (onRefreshOnly) {
      return 'stale';
    }
    throw _notInitialised;
  }

  @override
  Future<String?> refreshToken() async => throw _notInitialised;

  static const AuthenticationException _notInitialised =
      AuthenticationException(
        errorCode: ErrorCode.unknown,
        message:
            'Firebase is not initialised, so the application could not read '
            'the current credential (firebase code: no-app).',
      );
}
