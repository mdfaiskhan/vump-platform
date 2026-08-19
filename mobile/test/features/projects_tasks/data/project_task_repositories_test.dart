import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/network/interfaces/auth_token_source.dart';
import 'package:mobile/core/network/network_config.dart';
import 'package:mobile/core/network/vump_api.dart';
import 'package:mobile/features/projects_tasks/data/project_task_admin_repository_impl.dart';
import 'package:mobile/features/projects_tasks/data/project_task_repository_impl.dart';
import 'package:mobile/features/projects_tasks/domain/entities/paged_result.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// The two real repositories, against Chapter 4.6 §3's seven routes.
///
/// Driven through a real `VumpApi` over a scripted HTTP adapter rather than
/// through a hand-rolled `VumpApi` double, and that is the point: the envelope
/// handling, the `/v1` prefix, the query string and the error mapping are all
/// on the path being exercised. A fake API would prove the mapping and assume
/// everything the client had to get right to reach it.
///
/// **What it does not prove** is that the deployed backend answers these
/// shapes. Every body below is transcribed from `functions/*/src/index.ts`, and
/// a transcription is a claim about a file, not about a running Lambda.
void main() {
  late _ScriptedAdapter adapter;
  late ProjectTaskRepositoryImpl reads;
  late ProjectTaskAdminRepositoryImpl writes;

  setUp(() {
    adapter = _ScriptedAdapter();
    final VumpApi api = VumpApi(
      client: DioClient(
        config: NetworkConfig.forEnvironment(AppEnvironment.production),
        logger: AppLogger(environment: AppEnvironment.production),
        tokenSource: _NoToken(),
      )..dio.httpClientAdapter = adapter,
    );
    reads = ProjectTaskRepositoryImpl(backend: api);
    writes = ProjectTaskAdminRepositoryImpl(backend: api);
  });

  Map<String, Object?> projectRow(String id, {String name = 'Riverside'}) {
    return <String, Object?>{
      'id': id,
      'org_id': 'org-1',
      'name': name,
      'description': null,
      'created_by': 'user-1',
      'created_at': '2026-08-19 10:00:00+00',
      'archived_at': null,
    };
  }

  Map<String, Object?> taskRow(String id, {String title = 'North face'}) {
    return <String, Object?>{
      'id': id,
      'project_id': 'prj-1',
      'title': title,
      'instructions': 'Walk the length at a steady pace.',
      'reference_examples': <Object?>[],
      'created_at': '2026-08-19 10:00:00+00',
    };
  }

  group('fetchProjects — GET /v1/projects', () {
    test('sends no scope of any kind — BR-19 is server-side', () async {
      // Chapter 4.8: "every endpoint re-derives role and scope from the
      // verified token context". A collector id in the query would be a
      // client-supplied scope on a server-enforced rule, and the backend picks
      // its branch from the role the authorizer read out of `users`.
      adapter.body = <String, Object?>{'data': <Object?>[], 'error': null};

      await reads.fetchProjects();

      expect(adapter.paths.single, '/v1/projects');
      expect(adapter.lastQuery, isEmpty);
    });

    test('decodes the rows and carries nextCursor through', () async {
      adapter.body = <String, Object?>{
        'data': <Object?>[projectRow('p1'), projectRow('p2', name: 'Depot')],
        'error': null,
        'meta': <String, Object?>{'nextCursor': 'CURSOR_A'},
      };

      final PagedResult<Project> page = await reads.fetchProjects();

      expect(page.items.map((Project p) => p.id), <String>['p1', 'p2']);
      expect(page.items.last.name, 'Depot');
      expect(page.nextCursor, 'CURSOR_A');
      expect(page.hasMore, isTrue);
    });

    test('the cursor it was given is the cursor it sends back', () async {
      // A-184's fix, in the shape a half-done fix would fail: sending nothing
      // here re-reads page one forever and the list never advances.
      adapter.body = <String, Object?>{'data': <Object?>[], 'error': null};

      await reads.fetchProjects(cursor: 'CURSOR_A', limit: 200);

      expect(adapter.lastQuery['cursor'], 'CURSOR_A');
      expect(adapter.lastQuery['limit'], '200');
    });

    test('an empty page is empty, not a failure', () async {
      adapter.body = <String, Object?>{'data': <Object?>[], 'error': null};

      final PagedResult<Project> page = await reads.fetchProjects();

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  group('fetchTasks — GET /v1/projects/{id}/tasks', () {
    test('the project id is in the path', () async {
      adapter.body = <String, Object?>{'data': <Object?>[], 'error': null};

      await reads.fetchTasks('prj-1');

      expect(adapter.paths.single, '/v1/projects/prj-1/tasks');
    });

    test('decodes the rows', () async {
      adapter.body = <String, Object?>{
        'data': <Object?>[taskRow('t1'), taskRow('t2', title: 'South face')],
        'error': null,
      };

      final PagedResult<Task> page = await reads.fetchTasks('prj-1');

      expect(page.items.map((Task t) => t.title), <String>[
        'North face',
        'South face',
      ]);
      expect(page.hasMore, isFalse);
    });

    test('an invisible Project RAISES 404, it does not answer empty', () async {
      // The divergence from FakeProjectTaskRepository, which answers empty.
      // A-186 makes a Project outside the caller's reach absent rather than
      // forbidden, and merging that with "this Project has no Tasks" would
      // erase a distinction C-05 renders on purpose.
      adapter.status = 404;
      adapter.body = <String, Object?>{
        'data': null,
        'error': <String, Object?>{
          'code': 'RESOURCE_NOT_FOUND',
          'message': 'That project was not found.',
        },
      };

      await expectLater(
        reads.fetchTasks('prj-nope'),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.backendCode,
            'backendCode',
            'RESOURCE_NOT_FOUND',
          ),
        ),
      );
    });
  });

  group('createProject — POST /v1/projects', () {
    test(
      'sends only name and description, and returns the server row',
      () async {
        // Chapter 4.8 §1: "No authorization decision is ever trusted from the
        // mobile client." org_id and created_by are the authorizer's, and
        // a body
        // carrying either would be proposing its own tenant.
        adapter.status = 201;
        adapter.body = <String, Object?>{
          'data': projectRow('p-new', name: 'New Project'),
          'error': null,
        };

        final Project created = await writes.createProject(
          name: 'New Project',
          description: 'why',
        );

        expect(adapter.paths.single, '/v1/projects');
        expect(adapter.lastBody, <String, Object?>{
          'name': 'New Project',
          'description': 'why',
        });
        expect(created.id, 'p-new');
      },
    );

    test(
      'a null description is absent from the body, not sent as null',
      () async {
        adapter.status = 201;
        adapter.body = <String, Object?>{
          'data': projectRow('p-new'),
          'error': null,
        };

        await writes.createProject(name: 'New Project');

        expect(adapter.lastBody, <String, Object?>{'name': 'New Project'});
      },
    );
  });

  group('createTask — POST /v1/projects/{id}/tasks', () {
    test('sends the three fields the backend reads', () async {
      adapter.status = 201;
      adapter.body = <String, Object?>{'data': taskRow('t-new'), 'error': null};

      await writes.createTask(
        projectId: 'prj-1',
        title: 'North face',
        instructions: 'Walk it.',
        referenceExamples: <String>['https://example.test/a.mp4'],
      );

      expect(adapter.paths.single, '/v1/projects/prj-1/tasks');
      expect(adapter.lastBody, <String, Object?>{
        'title': 'North face',
        'instructions': 'Walk it.',
        'reference_examples': <String>['https://example.test/a.mp4'],
      });
    });

    test('no requirements field is sent — open item 69', () async {
      // FR-PT-05 names it, Chapter 4.4 §3's six columns do not include it, and
      // the backend would reject it. The absence is the recorded reading.
      adapter.status = 201;
      adapter.body = <String, Object?>{'data': taskRow('t-new'), 'error': null};

      await writes.createTask(
        projectId: 'prj-1',
        title: 'x',
        instructions: 'y',
      );

      expect(adapter.lastBody?.containsKey('requirements'), isFalse);
    });
  });

  group('updateTask — PATCH /v1/tasks/{id}', () {
    test('only the supplied fields are sent — null means unchanged', () async {
      adapter.body = <String, Object?>{'data': taskRow('t1'), 'error': null};

      await writes.updateTask(taskId: 't1', instructions: 'Walk it slower.');

      expect(adapter.paths.single, '/v1/tasks/t1');
      expect(adapter.lastBody, <String, Object?>{
        'instructions': 'Walk it slower.',
      });
    });

    test('all three are sent when all three are given', () async {
      adapter.body = <String, Object?>{'data': taskRow('t1'), 'error': null};

      await writes.updateTask(
        taskId: 't1',
        title: 'a',
        instructions: 'b',
        referenceExamples: <String>['c'],
      );

      expect(adapter.lastBody, <String, Object?>{
        'title': 'a',
        'instructions': 'b',
        'reference_examples': <String>['c'],
      });
    });
  });

  group('assignments — FR-ADM-03 and FR-ADM-04', () {
    test('assign posts collector_id and tolerates a 204', () async {
      adapter.status = 204;
      adapter.body = <String, Object?>{'data': null, 'error': null};

      await writes.assignCollector(taskId: 't1', collectorId: 'u1');

      expect(adapter.paths.single, '/v1/tasks/t1/assignments');
      expect(adapter.lastBody, <String, Object?>{'collector_id': 'u1'});
    });

    test('unassign is a DELETE with both ids in the path', () async {
      adapter.status = 204;
      adapter.body = <String, Object?>{'data': null, 'error': null};

      await writes.unassignCollector(taskId: 't1', collectorId: 'u1');

      expect(adapter.paths.single, '/v1/tasks/t1/assignments/u1');
      expect(adapter.methods.single, 'DELETE');
    });
  });
}

/// Returns one scripted response to everything, and records what was sent.
class _ScriptedAdapter implements HttpClientAdapter {
  int status = 200;
  Map<String, Object?>? body;

  final List<String> paths = <String>[];
  final List<String> methods = <String>[];
  Map<String, String> lastQuery = <String, String>{};
  Map<String, Object?>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    methods.add(options.method);
    lastQuery = options.uri.queryParameters;

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
