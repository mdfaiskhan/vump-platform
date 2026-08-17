import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';

import 'fakes/controllable_project_task_repository.dart';

/// `ProjectsNotifier` — FR-PT-03's state, driven through its port.
///
/// The notifier holds no filter and no sort of its own, so what is observable
/// here is the wiring: that it reads through the provider rather than
/// constructing anything, that it preserves the order it was given rather than
/// re-deriving one, and that a repository failure becomes an `AsyncError`
/// instead of escaping `application/` (error-handling.md §26).
void main() {
  final DateTime createdAt = DateTime.utc(2026, 8, 1);

  Project project(String id) => Project(
    id: id,
    orgId: 'org-1',
    name: 'Project $id',
    createdBy: 'usr-admin-1',
    createdAt: createdAt,
  );

  _Harness build({List<Project> projects = const <Project>[]}) {
    final ControllableProjectTaskRepository repo =
        ControllableProjectTaskRepository(projects: projects);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        projectTaskRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return _Harness(container, repo);
  }

  group('it reads through the port', () {
    test('build returns what the repository returned', () async {
      final _Harness harness = build(
        projects: <Project>[project('a'), project('b')],
      );

      final List<Project> projects = await harness.container.read(
        projectsProvider.future,
      );

      expect(projects.map((Project p) => p.id), <String>['a', 'b']);
    });

    test('it preserves the order given, imposing no sort', () async {
      // No chapter specifies an ordering for C-04, so a sort invented here
      // would be a product decision taken by a notifier.
      final _Harness harness = build(
        projects: <Project>[project('z'), project('a'), project('m')],
      );

      final List<Project> projects = await harness.container.read(
        projectsProvider.future,
      );

      expect(projects.map((Project p) => p.id), <String>['z', 'a', 'm']);
    });

    test('an empty result is data, not an error', () async {
      // "You have no assigned work" and "nothing was wired up" must never be
      // confused. The first is an empty success; the second is the throwing
      // provider, covered in project_task_providers_test.dart.
      final _Harness harness = build();

      expect(await harness.container.read(projectsProvider.future), isEmpty);
      expect(harness.container.read(projectsProvider).hasError, isFalse);
    });

    test('it reads the repository once for one build', () async {
      final _Harness harness = build(projects: <Project>[project('a')]);

      await harness.container.read(projectsProvider.future);
      harness.container.read(projectsProvider);

      expect(harness.repo.fetchProjectsCalls, 1);
    });
  });

  group('failure becomes AsyncError, never an escaped exception', () {
    test('a NetworkException at build surfaces as an error state', () async {
      final _Harness harness = build();
      harness.repo.failWith();

      await expectLater(
        harness.container.read(projectsProvider.future),
        throwsA(isA<NetworkException>()),
      );
      expect(harness.container.read(projectsProvider).hasError, isTrue);
    });

    test('refresh captures a throw rather than letting it escape', () async {
      // `AsyncValue.guard` is what makes this an assertion about §26 rather
      // than about Riverpod: `refresh` is an ordinary async method, so without
      // the guard the exception would leave `application/` uncaught.
      final _Harness harness = build(projects: <Project>[project('a')]);
      await harness.container.read(projectsProvider.future);

      harness.repo.failWith();
      await harness.container.read(projectsProvider.notifier).refresh();

      final AsyncValue<List<Project>> state = harness.container.read(
        projectsProvider,
      );
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkException>());
    });
  });

  group('refresh re-reads', () {
    test('it picks up data added since build', () async {
      // No cache exists yet (`local_task_cache` is deferred — open item 2), so
      // refresh is the only way a Collector gets newer data than build's.
      final _Harness harness = build(projects: <Project>[project('a')]);
      await harness.container.read(projectsProvider.future);

      harness.repo.projects = <Project>[project('a'), project('b')];
      await harness.container.read(projectsProvider.notifier).refresh();

      expect(
        harness.container
            .read(projectsProvider)
            .requireValue
            .map((Project p) => p.id),
        <String>['a', 'b'],
      );
    });

    test('it calls the repository again', () async {
      final _Harness harness = build(projects: <Project>[project('a')]);
      await harness.container.read(projectsProvider.future);

      await harness.container.read(projectsProvider.notifier).refresh();

      expect(harness.repo.fetchProjectsCalls, 2);
    });

    test('a recovered repository clears the error state', () async {
      final _Harness harness = build();
      harness.repo.failWith();
      await harness.container.read(projectsProvider.notifier).refresh();
      expect(harness.container.read(projectsProvider).hasError, isTrue);

      harness.repo.failure = null;
      harness.repo.projects = <Project>[project('a')];
      await harness.container.read(projectsProvider.notifier).refresh();

      final AsyncValue<List<Project>> state = harness.container.read(
        projectsProvider,
      );
      expect(state.hasError, isFalse);
      expect(state.requireValue, hasLength(1));
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
