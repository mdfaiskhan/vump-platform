import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/exceptions/validation_exception.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

import '../../../core/time/fakes/fake_clock.dart';
import 'fakes/fake_project_task_admin_repository.dart';
import 'fakes/fake_project_task_repository.dart';
import 'fakes/in_memory_project_task_store.dart';

/// The Admin write path, and the shared store that makes it visible.
///
/// The assertions worth having are the cross-fake ones: a write through the
/// Admin repository must be readable through the Collector's. That is the
/// whole reason the store exists, and two independent fakes would pass every
/// single-sided test in this file while failing the product.
void main() {
  late InMemoryProjectTaskStore store;
  late FakeProjectTaskAdminRepository admin;
  late FakeProjectTaskRepository read;
  late FakeClock clock;

  setUp(() {
    store = InMemoryProjectTaskStore();
    clock = FakeClock(start: DateTime.utc(2026, 9, 1, 10));
    admin = FakeProjectTaskAdminRepository(store: store, clock: clock);
    read = FakeProjectTaskRepository(store: store);
  });

  group('createProject — FR-ADM-01', () {
    test(
      'the created Project is readable through the read repository',
      () async {
        // The cross-fake assertion. Two independent fakes would let this
        // succeed on one side and show nothing on the other, which is what
        // InMemoryProjectTaskStore exists to prevent.
        final Project created = await admin.createProject(
          name: 'Harbour Survey',
        );

        final List<Project> visible = (await read.fetchProjects()).items;
        expect(visible.map((Project p) => p.id), contains(created.id));
        expect(visible.last.name, 'Harbour Survey');
      },
    );

    test('server-assigned fields are filled, not left to the caller', () async {
      // Chapter 4.8 derives org and actor from the verified token, so the
      // client sends neither and the fake stands in for the backend.
      final Project created = await admin.createProject(name: 'Harbour');

      expect(created.orgId, InMemoryProjectTaskStore.seedOrgId);
      expect(created.createdBy, InMemoryProjectTaskStore.seedCreatedBy);
      expect(created.id, isNotEmpty);
    });

    test(
      'createdAt comes from the injected clock, not the wall clock',
      () async {
        final Project created = await admin.createProject(name: 'Harbour');

        expect(created.createdAt, DateTime.utc(2026, 9, 1, 10));
      },
    );

    test('a new Project is live, not archived', () async {
      // A-104: active means archivedAt == null. Nothing in Volume 1 or 2
      // specifies who archives a Project or when (open item 88), so a created
      // one is simply not archived.
      final Project created = await admin.createProject(name: 'Harbour');

      expect(created.archivedAt, isNull);
    });

    test('it lists as a Project with no Tasks, not as an absent one', () async {
      // C-05 renders those as two different messages, so the store must be
      // able to tell them apart the moment a Project is created.
      final Project created = await admin.createProject(name: 'Harbour');

      expect((await read.fetchTasks(created.id)).items, isEmpty);
      expect(store.tasks.containsKey(created.id), isTrue);
    });

    test('a blank name is refused', () async {
      // Chapter 4.4 §2 marks `name` NOT NULL, and a blank string is the
      // looks-real-and-is-not problem MetadataIdentity already has.
      await expectLater(
        admin.createProject(name: '   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'ids are deterministic, so a golden cannot vary between runs',
      () async {
        final Project first = await admin.createProject(name: 'One');
        final Project second = await admin.createProject(name: 'Two');

        expect(first.id, 'prj-1');
        expect(second.id, 'prj-2');
      },
    );
  });

  group('createTask — FR-ADM-02', () {
    test('the created Task is readable through the read repository', () async {
      final Task created = await admin.createTask(
        projectId: 'prj-riverside-survey',
        title: 'South bank',
        instructions: 'Walk south to north.',
      );

      final List<Task> visible = (await read.fetchTasks(
        'prj-riverside-survey',
      )).items;
      expect(visible.map((Task t) => t.id), contains(created.id));
    });

    test('it appends rather than replacing the seeded Tasks', () async {
      await admin.createTask(
        projectId: 'prj-riverside-survey',
        title: 'South bank',
        instructions: 'Walk south to north.',
      );

      expect(
        (await read.fetchTasks('prj-riverside-survey')).items,
        hasLength(3),
      );
    });

    test('referenceExamples defaults to empty, never null', () async {
      final Task created = await admin.createTask(
        projectId: 'prj-depot-inventory',
        title: 'Bay B',
        instructions: 'Pan each unit.',
      );

      expect(created.referenceExamples, isEmpty);
    });

    test('an unknown Project is refused', () async {
      await expectLater(
        admin.createTask(projectId: 'prj-nope', title: 'T', instructions: 'I'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('blank title and blank instructions are each refused', () async {
      await expectLater(
        admin.createTask(
          projectId: 'prj-depot-inventory',
          title: '  ',
          instructions: 'Pan each unit.',
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        admin.createTask(
          projectId: 'prj-depot-inventory',
          title: 'Bay B',
          instructions: '',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('no requirements parameter exists — open item 69', () async {
      // FR-ADM-02 names "instructions, reference examples, and requirements",
      // and Chapter 4.4 §3 has no such column. C-06 omits it on the read side
      // (A-110); this is the write side of the same gap. A later mission that
      // adds the parameter without settling item 69 breaks this test.
      final Task created = await admin.createTask(
        projectId: 'prj-depot-inventory',
        title: 'Bay B',
        instructions: 'Pan each unit.',
      );

      expect(created.toString(), isNot(contains('requirement')));
    });
  });

  group('updateTask — FR-ADM-02s edit half', () {
    test('null means leave unchanged, which is what PATCH means', () async {
      final Task updated = await admin.updateTask(
        taskId: 'tsk-riverside-embankment',
        title: 'Renamed',
      );

      expect(updated.title, 'Renamed');
      expect(updated.instructions, startsWith('Walk the embankment path'));
      expect(updated.referenceExamples, hasLength(3));
    });

    test('the update is visible through the read repository', () async {
      await admin.updateTask(
        taskId: 'tsk-riverside-bridge',
        instructions: 'Two passes per span.',
      );

      final List<Task> tasks = (await read.fetchTasks(
        'prj-riverside-survey',
      )).items;
      final Task bridge = tasks.firstWhere(
        (Task t) => t.id == 'tsk-riverside-bridge',
      );
      expect(bridge.instructions, 'Two passes per span.');
    });

    test('reference examples can be replaced wholesale', () async {
      final Task updated = await admin.updateTask(
        taskId: 'tsk-riverside-embankment',
        referenceExamples: const <String>['https://example.invalid/new.mp4'],
      );

      expect(updated.referenceExamples, hasLength(1));
    });

    test('an unknown Task is refused', () async {
      await expectLater(
        admin.updateTask(taskId: 'tsk-nope', title: 'X'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a blank replacement for a NOT NULL column is refused', () async {
      await expectLater(
        admin.updateTask(taskId: 'tsk-riverside-bridge', title: '   '),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('assignment — FR-ADM-03 and FR-ADM-04, Task-scoped only', () {
    test('assigning records the Collector against the Task', () async {
      await admin.assignCollector(
        taskId: 'tsk-depot-bay-a',
        collectorId: 'usr-collector-1',
      );

      expect(store.assignments['tsk-depot-bay-a'], contains('usr-collector-1'));
    });

    test('assigning twice is a no-op, not an error', () async {
      // A-06 saves a whole checkbox set at once and cannot know which boxes
      // changed, because no read endpoint for assignments exists (item 89).
      await admin.assignCollector(
        taskId: 'tsk-depot-bay-a',
        collectorId: 'usr-collector-1',
      );
      await admin.assignCollector(
        taskId: 'tsk-depot-bay-a',
        collectorId: 'usr-collector-1',
      );

      expect(store.assignments['tsk-depot-bay-a'], hasLength(1));
    });

    test('unassigning removes only that Collector', () async {
      await admin.assignCollector(
        taskId: 'tsk-depot-bay-a',
        collectorId: 'usr-a',
      );
      await admin.assignCollector(
        taskId: 'tsk-depot-bay-a',
        collectorId: 'usr-b',
      );

      await admin.unassignCollector(
        taskId: 'tsk-depot-bay-a',
        collectorId: 'usr-a',
      );

      expect(store.assignments['tsk-depot-bay-a'], <String>{'usr-b'});
    });

    test('unassigning someone never assigned is a no-op', () async {
      await admin.unassignCollector(
        taskId: 'tsk-depot-bay-a',
        collectorId: 'usr-never',
      );

      expect(store.assignments['tsk-depot-bay-a'] ?? <String>{}, isEmpty);
    });

    test('reassignment is unassign then assign, not a third method', () async {
      // UC-07's alternate flow. Chapter 4.6 §3 labels the DELETE row
      // "remove/reassign"; a `reassign` method would be two requests wearing
      // one name, and a partial failure would leave the caller unable to tell
      // which half landed.
      await admin.assignCollector(
        taskId: 'tsk-depot-loading',
        collectorId: 'usr-a',
      );

      await admin.unassignCollector(
        taskId: 'tsk-depot-loading',
        collectorId: 'usr-a',
      );
      await admin.assignCollector(
        taskId: 'tsk-depot-loading',
        collectorId: 'usr-b',
      );

      expect(store.assignments['tsk-depot-loading'], <String>{'usr-b'});
    });

    test('an unknown Task is refused on both calls', () async {
      await expectLater(
        admin.assignCollector(taskId: 'tsk-nope', collectorId: 'usr-a'),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        admin.unassignCollector(taskId: 'tsk-nope', collectorId: 'usr-a'),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'it does not validate that the Collector exists — UC-07 is the backend s',
      () async {
        // UC-07's exception flow blocks assigning a deactivated or non-existent
        // Collector. That is Chapter 4.8's judgement and this client holds no
        // user directory; a fake that invented the rule would model a guarantee
        // the real repository does not make here.
        await admin.assignCollector(
          taskId: 'tsk-depot-bay-a',
          collectorId: 'usr-does-not-exist',
        );

        expect(
          store.assignments['tsk-depot-bay-a'],
          contains('usr-does-not-exist'),
        );
      },
    );
  });

  // NOT TESTED, and worth saying why rather than writing a test that looks
  // like a guard and is not: the ABSENCE of removeTask, editProject and
  // archiveProject (open items 86, 87, 88) is a compile-time fact about the
  // interface, and Dart offers no runtime assertion over a class's method set.
  // If a later mission adds one, nothing here breaks.
  //
  // C-06's missing `requirements` section IS guarded by a test, because that
  // absence shows up in rendered output. This one does not. The distinction is
  // real and the register carries the items instead.
}
