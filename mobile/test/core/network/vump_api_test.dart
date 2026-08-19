import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/network/interfaces/auth_token_source.dart';
import 'package:mobile/core/network/network_config.dart';
import 'package:mobile/core/network/vump_api.dart';

/// Volume 4 Chapter 4.6 §1's envelope, on the way in and on the way out.
///
/// The rule that matters here is the one a plain HTTP client loses: errors
/// *"always carry a specific code, never a bare HTTP status alone"*. Chapter
/// 2.9 §2 calls a generic failure message a defect rather than a fallback, so
/// a test that only checked the happy path would have let it ship — and did,
/// until a Mission 4.2 test scripted a real refusal and got back a bare 400.
void main() {
  late _ScriptedAdapter adapter;
  late VumpApi api;

  setUp(() {
    adapter = _ScriptedAdapter();
    api = VumpApi(
      client: DioClient(
        config: NetworkConfig.forEnvironment(AppEnvironment.production),
        logger: AppLogger(environment: AppEnvironment.production),
        tokenSource: _NoToken(),
      )..dio.httpClientAdapter = adapter,
    );
  });

  group('the version prefix', () {
    test('every verb goes to /v1', () async {
      adapter.body = <String, Object?>{
        'data': <String, Object?>{},
        'error': null,
      };

      await api.post('/thing', what: 'a thing');
      await api.patch('/thing', what: 'a thing');
      await api.get('/thing', what: 'a thing');

      expect(adapter.paths, <String>['/v1/thing', '/v1/thing', '/v1/thing']);
      expect(VumpApi.versionPrefix, '/v1');
    });

    test('query parameters reach the request', () async {
      adapter.body = <String, Object?>{
        'data': <String, Object?>{},
        'error': null,
      };

      await api.get(
        '/projects',
        what: 'the projects',
        queryParameters: <String, dynamic>{'cursor': 'abc', 'limit': 20},
      );

      expect(adapter.lastQuery, <String, String>{
        'cursor': 'abc',
        'limit': '20',
      });
    });
  });

  group('success', () {
    test('the data object is returned, unwrapped', () async {
      adapter.body = <String, Object?>{
        'data': <String, Object?>{'session_id': 'srv_1'},
        'error': null,
      };

      expect(await api.post('/x', what: 'x'), <String, Object?>{
        'session_id': 'srv_1',
      });
    });

    test('a null data object is an empty map, not a failure', () async {
      // A PATCH that succeeds has nothing to say; requiring a payload would
      // make every no-content endpoint look malformed.
      adapter.body = <String, Object?>{'data': null, 'error': null};

      expect(await api.patch('/x', what: 'x'), isEmpty);
    });

    test('an undecodable body on a 2xx is a no-content success', () async {
      adapter.raw = '';
      adapter.status = 204;
      adapter.contentType = 'text/plain';

      expect(await api.patch('/x', what: 'x'), isEmpty);
    });
  });

  group('failure', () {
    test('a 2xx carrying an error is still a failure', () async {
      // The envelope is the contract, not the status code.
      adapter.body = <String, Object?>{
        'data': null,
        'error': <String, Object?>{
          'code': 'CHUNK_ALREADY_REGISTERED',
          'message': 'This chunk is registered.',
        },
      };

      await expectLater(
        api.post('/x', what: 'chunk registration'),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.message,
            'message',
            allOf(
              contains('CHUNK_ALREADY_REGISTERED'),
              contains('chunk registration'),
            ),
          ),
        ),
      );
    });

    test(
      'a 4xx carrying an error keeps the backend code, not a bare status',
      () async {
        // The regression this class exists to prevent. ErrorInterceptor
        // converts the 400 first; _named recovers the envelope from the cause.
        adapter.status = 400;
        adapter.body = <String, Object?>{
          'data': null,
          'error': <String, Object?>{
            'code': 'TASK_NOT_ASSIGNED',
            'message': 'You are not assigned to this Task.',
          },
        };

        await expectLater(
          api.post('/x', what: 'chunk registration'),
          throwsA(
            isA<NetworkException>()
                .having(
                  (NetworkException e) => e.message,
                  'message',
                  contains('TASK_NOT_ASSIGNED'),
                )
                .having(
                  (NetworkException e) => e.statusCode,
                  'statusCode',
                  400,
                ),
          ),
        );
      },
    );

    test('the same recovery applies to PATCH and GET', () async {
      adapter.status = 403;
      adapter.body = <String, Object?>{
        'data': null,
        'error': <String, Object?>{'code': 'FORBIDDEN', 'message': 'no'},
      };

      for (final Future<Map<String, Object?>> call
          in <Future<Map<String, Object?>>>[
            api.patch('/x', what: 'a patch'),
            api.get('/x', what: 'a get'),
          ]) {
        await expectLater(
          call,
          throwsA(
            isA<NetworkException>().having(
              (NetworkException e) => e.message,
              'message',
              contains('FORBIDDEN'),
            ),
          ),
        );
      }
    });

    test('a 5xx with no envelope keeps its transport classification', () async {
      // _named must not invent a code where the backend gave none — a genuine
      // transport failure has to stay classifiable as transient (Ch. 5.13 §1).
      // A gateway 503 answers in text/plain, not in Chapter 4.6 §1's envelope.
      adapter.status = 503;
      adapter.raw = 'gateway down';
      adapter.contentType = 'text/plain';

      await expectLater(
        api.post('/x', what: 'x'),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });

    test('a data field that is not an object is malformed', () async {
      adapter.body = <String, Object?>{'data': 'a string', 'error': null};

      await expectLater(
        api.post('/x', what: 'x'),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.errorCode,
            'errorCode',
            ErrorCode.networkSerialization,
          ),
        ),
      );
    });

    test('an error object with no code still names what failed', () async {
      adapter.body = <String, Object?>{
        'data': null,
        'error': <String, Object?>{},
      };

      await expectLater(
        api.post('/x', what: 'the widget fetch'),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.message,
            'message',
            allOf(contains('the widget fetch'), contains('no code')),
          ),
        ),
      );
    });
  });

  group('getList — Chapter 4.6 §1 pagination, F24', () {
    test('reads the data array and meta.nextCursor', () async {
      adapter.body = <String, Object?>{
        'data': <Object?>[
          <String, Object?>{'id': 'a'},
          <String, Object?>{'id': 'b'},
        ],
        'error': null,
        'meta': <String, Object?>{'nextCursor': 'eyJhIjoxfQ'},
      };

      final ApiPage page = await api.getList('/projects', what: 'projects');

      expect(page.rows, hasLength(2));
      expect(page.rows.first['id'], 'a');
      expect(page.nextCursor, 'eyJhIjoxfQ');
      expect(page.hasMore, isTrue);
    });

    test('a null nextCursor is the last page', () async {
      adapter.body = <String, Object?>{
        'data': <Object?>[
          <String, Object?>{'id': 'a'},
        ],
        'error': null,
        'meta': <String, Object?>{'nextCursor': null},
      };

      final ApiPage page = await api.getList('/projects', what: 'projects');

      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
    });

    test('an absent meta is the last page too', () async {
      // Chapter 4.6 §1 makes `meta` absent entirely on non-list endpoints, and
      // absent and null carry the same fact.
      adapter.body = <String, Object?>{'data': <Object?>[], 'error': null};

      final ApiPage page = await api.getList('/projects', what: 'projects');

      expect(page.rows, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('cursor and limit reach the query string', () async {
      adapter.body = <String, Object?>{'data': <Object?>[], 'error': null};

      await api.getList(
        '/projects',
        what: 'projects',
        cursor: 'abc',
        limit: 200,
      );

      expect(adapter.lastQuery, <String, String>{
        'cursor': 'abc',
        'limit': '200',
      });
    });

    test('a first page sends neither', () async {
      // Null-aware elements: an absent cursor or limit drops out entirely
      // rather than going out empty, so the backend applies DEFAULT_LIMIT.
      adapter.body = <String, Object?>{'data': <Object?>[], 'error': null};

      await api.getList('/projects', what: 'projects');

      expect(adapter.lastQuery, isEmpty);
    });

    test('an empty data array is an empty page, not a failure', () async {
      // "No assigned work" is a real answer and a different one from "the read
      // failed". Raising here would erase a distinction C-04 renders.
      adapter.body = <String, Object?>{'data': <Object?>[], 'error': null};

      expect((await api.getList('/p', what: 'projects')).rows, isEmpty);
    });

    test('a data OBJECT is malformed — that is what get is for', () async {
      adapter.body = <String, Object?>{
        'data': <String, Object?>{'id': 'a'},
        'error': null,
      };

      await expectLater(
        api.getList('/p', what: 'projects'),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.errorCode,
            'errorCode',
            ErrorCode.networkSerialization,
          ),
        ),
      );
    });

    test('an envelope error is raised even on a 200', () async {
      adapter.body = <String, Object?>{
        'data': null,
        'error': <String, Object?>{
          'code': 'REQUEST_INVALID_CURSOR',
          'message': 'This cursor was not issued by this API.',
        },
      };

      await expectLater(
        api.getList('/p', what: 'projects'),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.backendCode,
            'backendCode',
            'REQUEST_INVALID_CURSOR',
          ),
        ),
      );
    });
  });

  group('delete', () {
    test('goes to /v1 and reads a 204 as an empty success', () async {
      adapter.status = 204;
      adapter.body = <String, Object?>{'data': null, 'error': null};

      final Map<String, Object?> data = await api.delete(
        '/tasks/t1/assignments/u1',
        what: 'the unassignment',
      );

      expect(data, isEmpty);
      expect(adapter.paths.single, '/v1/tasks/t1/assignments/u1');
    });
  });

  group('backendCode — F29', () {
    test('a non-2xx envelope code arrives structurally, not only in prose', () {
      adapter.status = 404;
      adapter.body = <String, Object?>{
        'data': null,
        'error': <String, Object?>{
          'code': 'RESOURCE_NOT_FOUND',
          'message': 'That project was not found.',
        },
      };

      return expectLater(
        api.getList('/projects/x/tasks', what: 'tasks'),
        throwsA(
          isA<NetworkException>()
              .having(
                (NetworkException e) => e.backendCode,
                'backendCode',
                'RESOURCE_NOT_FOUND',
              )
              // The status-derived classification is unchanged: F29 is
              // additive, and nothing that branched on errorCode before
              // behaves differently now.
              .having(
                (NetworkException e) => e.errorCode,
                'errorCode',
                ErrorCode.networkNotFound,
              ),
        ),
      );
    });

    test('a transport failure carries no backendCode', () async {
      // No envelope was ever received, so there is no code to carry and
      // inventing one would be worse than null.
      adapter.status = 500;
      adapter.raw = 'not json at all';
      adapter.contentType = Headers.textPlainContentType;

      await expectLater(
        api.get('/thing', what: 'a thing'),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.backendCode,
            'backendCode',
            isNull,
          ),
        ),
      );
    });
  });
}

/// Returns one scripted response to everything.
class _ScriptedAdapter implements HttpClientAdapter {
  int status = 200;
  Map<String, Object?>? body;
  String? raw;
  String contentType = Headers.jsonContentType;

  final List<String> paths = <String>[];
  Map<String, String> lastQuery = <String, String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    lastQuery = options.uri.queryParameters;

    return ResponseBody.fromString(
      raw ?? jsonEncode(body ?? <String, Object?>{}),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Nobody is signed in — the request goes out unauthenticated.
class _NoToken implements AuthTokenSource {
  @override
  Future<String?> currentToken() async => null;

  @override
  Future<String?> refreshToken() async => null;
}
