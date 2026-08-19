import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/features/projects_tasks/application/page_size.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/application/tasks_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/paged_result.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

import 'fakes/controllable_project_task_repository.dart';

/// `TasksNotifier` — FR-PT-04's state, keyed by `project_id`.
///
/// The family argument is the whole reason this notifier differs from
/// `ProjectsNotifier`, so most of what is asserted here is that the argument
/// actually reaches the port and that two Projects do not share one instance.
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 1);

  Task task(String id, String projectId) => Task(
    id: id,
    projectId: projectId,
    title: 'Task $id',
    instructions: 'Do the thing.',
    createdAt: createdAt,
  );

  _Harness build({
    Map<String, List<Task>> tasks = const <String, List<Task>>{},
  }) {
    final ControllableProjectTaskRepository repo =
        ControllableProjectTaskRepository(tasks: tasks);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        projectTaskRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return _Harness(container, repo);
  }

  group('the family argument reaches the port', () {
    test('build asks for the Project it was keyed with', () async {
      final _Harness harness = build(
        tasks: <String, List<Task>>{
          'prj-1': <Task>[task('t1', 'prj-1')],
        },
      );

      await harness.container.read(tasksProvider('prj-1').future);

      expect(harness.repo.fetchTasksCalls, <String>['prj-1']);
    });

    test('two Projects are independent instances, not one shared', () async {
      final _Harness harness = build(
        tasks: <String, List<Task>>{
          'prj-1': <Task>[task('t1', 'prj-1')],
          'prj-2': <Task>[task('t2', 'prj-2'), task('t3', 'prj-2')],
        },
      );

      final List<Task> first = await harness.container.read(
        tasksProvider('prj-1').future,
      );
      final List<Task> second = await harness.container.read(
        tasksProvider('prj-2').future,
      );

      expect(first.map((Task t) => t.id), <String>['t1']);
      expect(second.map((Task t) => t.id), <String>['t2', 't3']);
      expect(harness.repo.fetchTasksCalls, <String>['prj-1', 'prj-2']);
    });

    test('revisiting a Project does not refetch it', () async {
      // Riverpod keeps one instance per family key, which is what makes
      // navigating back to a Project already visited free.
      final _Harness harness = build(
        tasks: <String, List<Task>>{
          'prj-1': <Task>[task('t1', 'prj-1')],
        },
      );

      await harness.container.read(tasksProvider('prj-1').future);
      await harness.container.read(tasksProvider('prj-1').future);

      expect(harness.repo.fetchTasksCalls, <String>['prj-1']);
    });

    test(
      'a Project with no Tasks yields an empty list, not an error',
      () async {
        final _Harness harness = build();

        expect(
          await harness.container.read(tasksProvider('prj-empty').future),
          isEmpty,
        );
        expect(
          harness.container.read(tasksProvider('prj-empty')).hasError,
          isFalse,
        );
      },
    );
  });

  group('failure becomes AsyncError', () {
    test('a NetworkException at build surfaces as an error state', () async {
      final _Harness harness = build();
      harness.repo.failWith();

      await expectLater(
        harness.container.read(tasksProvider('prj-1').future),
        throwsA(isA<NetworkException>()),
      );
      expect(harness.container.read(tasksProvider('prj-1')).hasError, isTrue);
    });

    test('refresh captures a throw rather than letting it escape', () async {
      final _Harness harness = build(
        tasks: <String, List<Task>>{
          'prj-1': <Task>[task('t1', 'prj-1')],
        },
      );
      await harness.container.read(tasksProvider('prj-1').future);

      harness.repo.failWith();
      await harness.container.read(tasksProvider('prj-1').notifier).refresh();

      final AsyncValue<List<Task>> state = harness.container.read(
        tasksProvider('prj-1'),
      );
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkException>());
    });
  });

  group('refresh re-reads under the same key', () {
    test('it asks for the Project it was keyed with, again', () async {
      final _Harness harness = build(
        tasks: <String, List<Task>>{
          'prj-1': <Task>[task('t1', 'prj-1')],
        },
      );
      await harness.container.read(tasksProvider('prj-1').future);

      await harness.container.read(tasksProvider('prj-1').notifier).refresh();

      expect(harness.repo.fetchTasksCalls, <String>['prj-1', 'prj-1']);
    });

    test('it picks up Tasks added since build', () async {
      final _Harness harness = build(
        tasks: <String, List<Task>>{
          'prj-1': <Task>[task('t1', 'prj-1')],
        },
      );
      await harness.container.read(tasksProvider('prj-1').future);

      harness.repo.tasks = <String, List<Task>>{
        'prj-1': <Task>[task('t1', 'prj-1'), task('t2', 'prj-1')],
      };
      await harness.container.read(tasksProvider('prj-1').notifier).refresh();

      expect(
        harness.container
            .read(tasksProvider('prj-1'))
            .requireValue
            .map((Task t) => t.id),
        <String>['t1', 't2'],
      );
    });

    test('refreshing one Project leaves another untouched', () async {
      final _Harness harness = build(
        tasks: <String, List<Task>>{
          'prj-1': <Task>[task('t1', 'prj-1')],
          'prj-2': <Task>[task('t2', 'prj-2')],
        },
      );
      await harness.container.read(tasksProvider('prj-1').future);
      await harness.container.read(tasksProvider('prj-2').future);

      await harness.container.read(tasksProvider('prj-1').notifier).refresh();

      expect(harness.repo.fetchTasksCalls, <String>['prj-1', 'prj-2', 'prj-1']);
      expect(
        harness.container
            .read(tasksProvider('prj-2'))
            .requireValue
            .map((Task t) => t.id),
        <String>['t2'],
      );
    });
  });

  group('pagination — F20, and why the page size matters here most', () {
    test('the first read asks for MAX_LIMIT and no cursor', () async {
      // C-06 selects its Task out of THIS list, because Chapter 4.6 §3 has no
      // GET /v1/tasks/{id}. At the backend's default of 50 the 51st Task in a
      // Project would render "This Task isn't available to you" — a false
      // claim about authorization. F26.
      final _Harness harness = build(
        tasks: <String, List<Task>>{
          'prj-1': <Task>[task('t1', 'prj-1')],
        },
      );

      await harness.container.read(tasksProvider('prj-1').future);

      expect(harness.repo.cursors, <String?>[null]);
      expect(harness.repo.limits, <int?>[projectTaskPageSize]);
    });

    test('loadMore sends the cursor back and appends', () async {
      final _Harness harness = build();
      harness.repo.taskPages = <String, List<PagedResult<Task>>>{
        'prj-1': <PagedResult<Task>>[
          PagedResult<Task>(
            items: <Task>[task('t1', 'prj-1')],
            nextCursor: 'C1',
          ),
          PagedResult<Task>.last(<Task>[task('t2', 'prj-1')]),
        ],
      };

      await harness.container.read(tasksProvider('prj-1').future);
      final bool loaded = await harness.container
          .read(tasksProvider('prj-1').notifier)
          .loadMore();

      expect(loaded, isTrue);
      expect(harness.repo.cursors, <String?>[null, 'C1']);
      expect(
        harness.container
            .read(tasksProvider('prj-1'))
            .requireValue
            .map((Task t) => t.id),
        <String>['t1', 't2'],
      );
    });

    test('a failed loadMore keeps the Tasks already on screen', () async {
      final _Harness harness = build();
      harness.repo.taskPages = <String, List<PagedResult<Task>>>{
        'prj-1': <PagedResult<Task>>[
          PagedResult<Task>(
            items: <Task>[task('t1', 'prj-1')],
            nextCursor: 'C1',
          ),
        ],
      };

      await harness.container.read(tasksProvider('prj-1').future);
      harness.repo.failWith();
      final bool loaded = await harness.container
          .read(tasksProvider('prj-1').notifier)
          .loadMore();

      expect(loaded, isFalse);
      final AsyncValue<List<Task>> state = harness.container.read(
        tasksProvider('prj-1'),
      );
      expect(state.hasError, isFalse);
      expect(state.requireValue.single.id, 't1');
    });

    test('each family member paginates on its own cursor', () async {
      // Two Projects, two cursors. One shared field would make loading page
      // two of one Project fetch page two of the other.
      final _Harness harness = build();
      harness.repo.taskPages = <String, List<PagedResult<Task>>>{
        'prj-1': <PagedResult<Task>>[
          PagedResult<Task>(
            items: <Task>[task('t1', 'prj-1')],
            nextCursor: 'C-ONE',
          ),
        ],
        'prj-2': <PagedResult<Task>>[
          PagedResult<Task>.last(<Task>[task('t2', 'prj-2')]),
        ],
      };

      await harness.container.read(tasksProvider('prj-1').future);
      await harness.container.read(tasksProvider('prj-2').future);

      expect(
        harness.container.read(tasksProvider('prj-1').notifier).hasMore,
        isTrue,
      );
      expect(
        harness.container.read(tasksProvider('prj-2').notifier).hasMore,
        isFalse,
      );
    });
  });
}

/// One container and the instrument bound into it.
///
/// A named record type for this pair reads past the 80-column limit at every
/// use site, so the pair gets a name instead.
class _Harness {
  _Harness(this.container, this.repo);

  final ProviderContainer container;
  final ControllableProjectTaskRepository repo;
}
