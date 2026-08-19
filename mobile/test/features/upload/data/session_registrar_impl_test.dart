import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/errors/exceptions/validation_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/network/interfaces/auth_token_source.dart';
import 'package:mobile/core/network/network_config.dart';
import 'package:mobile/core/network/vump_api.dart';
import 'package:mobile/features/upload/data/session_registrar_impl.dart';

/// Chapter 4.6 §4's session registration — the seam that has thrown since
/// Mission 4.2.
///
/// Driven through a real `VumpApi` over a scripted adapter, so the envelope,
/// the `/v1` prefix and the error mapping are all on the path being exercised.
void main() {
  late _ScriptedAdapter adapter;
  late SessionRegistrarImpl registrar;

  final DateTime startedAt = DateTime.utc(2026, 8, 19, 10, 30);

  setUp(() {
    adapter = _ScriptedAdapter();
    registrar = SessionRegistrarImpl(
      backend: VumpApi(
        client: DioClient(
          config: NetworkConfig.forEnvironment(AppEnvironment.production),
          logger: AppLogger(environment: AppEnvironment.production),
          tokenSource: _NoToken(),
        )..dio.httpClientAdapter = adapter,
      ),
    );
  });

  group('a session with a Task', () {
    test('posts under the Task and returns the backend id', () async {
      // The `{id}` in Chapter 5.10 §1 step 1's URL is THIS one, never the
      // local session UUID — which is the whole reason this port exists.
      adapter.status = 201;
      adapter.body = <String, Object?>{
        'data': <String, Object?>{
          'id': 'srv-session-1',
          'task_id': 'tsk-1',
          'client_session_id': 'local-sess-1',
        },
        'error': null,
      };

      final String id = await registrar.remoteSessionId(
        localSessionId: 'local-sess-1',
        taskId: 'tsk-1',
        startedAt: startedAt,
      );

      expect(id, 'srv-session-1');
      expect(adapter.paths.single, '/v1/tasks/tsk-1/sessions');
    });

    test('sends the local id as client_session_id — F5', () async {
      // The idempotency key. Without it the backend has nothing to converge
      // on, and a pipeline that registers once per chunk would fragment one
      // recording across 38 backend sessions.
      adapter.status = 201;
      adapter.body = _created();

      await registrar.remoteSessionId(
        localSessionId: 'local-sess-1',
        taskId: 'tsk-1',
        startedAt: startedAt,
      );

      expect(adapter.lastBody?['client_session_id'], 'local-sess-1');
    });

    test('sends started_at as UTC ISO-8601 — F15', () async {
      // A deferred upload registers hours after capture. Omitting this lets
      // the column default to now(), stamping the session with the upload
      // time rather than when recording began.
      adapter.status = 201;
      adapter.body = _created();

      await registrar.remoteSessionId(
        localSessionId: 'local-sess-1',
        taskId: 'tsk-1',
        startedAt: DateTime.utc(2026, 8, 19, 10, 30),
      );

      expect(adapter.lastBody?['started_at'], '2026-08-19T10:30:00.000Z');
    });

    test('a local time is converted, not sent as-is', () async {
      // The backend rejects a future instant, and a positive-offset device
      // sending local time as though it were UTC would present one.
      adapter.status = 201;
      adapter.body = _created();

      final DateTime local = DateTime.utc(2026, 8, 19, 10, 30).toLocal();
      await registrar.remoteSessionId(
        localSessionId: 'local-sess-1',
        taskId: 'tsk-1',
        startedAt: local,
      );

      expect(adapter.lastBody?['started_at'], '2026-08-19T10:30:00.000Z');
    });

    test('a repeat answers 200 and is not an error — F34', () async {
      // `ON CONFLICT DO NOTHING` plus a re-read. This is what makes calling
      // once per chunk safe, and why nothing is cached.
      adapter.status = 200;
      adapter.body = _created();

      expect(
        await registrar.remoteSessionId(
          localSessionId: 'local-sess-1',
          taskId: 'tsk-1',
          startedAt: startedAt,
        ),
        'srv-session-1',
      );
    });
  });

  group('a session with no Task', () {
    test('refuses before any request — terminal, device-side', () async {
      // Chapter 5.13 §1's device-side class. Retrying cannot help: nothing
      // about the stored session row will change. Substituting a Task id
      // would upload real footage against somebody else's work.
      await expectLater(
        registrar.remoteSessionId(
          localSessionId: 'local-sess-1',
          taskId: null,
          startedAt: startedAt,
        ),
        throwsA(
          isA<ValidationException>()
              .having(
                (ValidationException e) => e.errorCode,
                'errorCode',
                ErrorCode.validationRequiredField,
              )
              .having((ValidationException e) => e.field, 'field', 'task_id'),
        ),
      );

      expect(adapter.paths, isEmpty, reason: 'nothing was sent');
    });

    test('an empty Task id is refused the same way', () async {
      await expectLater(
        registrar.remoteSessionId(
          localSessionId: 'local-sess-1',
          taskId: '',
          startedAt: startedAt,
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(adapter.paths, isEmpty);
    });
  });

  group('refusals from the backend', () {
    test('SESSION_ALREADY_REGISTERED reaches the caller by name', () async {
      // Fires only when the same client_session_id is re-presented under a
      // DIFFERENT Task. Neither honouring it nor returning the original is a
      // thing to do quietly.
      adapter.status = 409;
      adapter.body = <String, Object?>{
        'data': null,
        'error': <String, Object?>{
          'code': 'SESSION_ALREADY_REGISTERED',
          'message': 'That session belongs to another Task.',
        },
      };

      await expectLater(
        registrar.remoteSessionId(
          localSessionId: 'local-sess-1',
          taskId: 'tsk-2',
          startedAt: startedAt,
        ),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.backendCode,
            'backendCode',
            'SESSION_ALREADY_REGISTERED',
          ),
        ),
      );
    });

    test('a response with no id is malformed, not an empty id', () async {
      // Continuing would put an empty session id into the next request's URL.
      adapter.status = 201;
      adapter.body = <String, Object?>{
        'data': <String, Object?>{'task_id': 'tsk-1'},
        'error': null,
      };

      await expectLater(
        registrar.remoteSessionId(
          localSessionId: 'local-sess-1',
          taskId: 'tsk-1',
          startedAt: startedAt,
        ),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.errorCode,
            'errorCode',
            ErrorCode.networkSerialization,
          ),
        ),
      );
    });
  });
}

Map<String, Object?> _created() => <String, Object?>{
  'data': <String, Object?>{
    'id': 'srv-session-1',
    'task_id': 'tsk-1',
    'client_session_id': 'local-sess-1',
  },
  'error': null,
};

/// Returns one scripted response, and records what was sent.
class _ScriptedAdapter implements HttpClientAdapter {
  int status = 200;
  Map<String, Object?>? body;

  final List<String> paths = <String>[];
  Map<String, Object?>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    final Object? sent = options.data;
    lastBody = sent is Map<String, Object?> ? sent : null;

    return ResponseBody.fromString(
      jsonEncode(body ?? <String, Object?>{}),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
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
