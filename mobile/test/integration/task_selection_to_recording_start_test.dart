import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/core/identity/providers/identity_ports.dart';
import 'package:mobile/core/identity/selected_task.dart';
import 'package:mobile/core/onboarding/providers/onboarding_ports.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/recording/application/checklist_notifier.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';

import '../core/onboarding/fakes/onboarding_seen_fakes.dart';
import '../features/projects_tasks/data/fakes/fake_project_task_repository.dart';
import '../features/projects_tasks/data/fakes/in_memory_project_task_store.dart';
import '../features/recording/fakes/checklist_fakes.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._restored);

  final Session _restored;
  late final StreamController<Session> _sessions = StreamController<Session>(
    onListen: () {
      _sessions.add(const Session.unknown());
      _sessions.add(_restored);
    },
  );

  @override
  Stream<Session> get sessionChanges => _sessions.stream;

  @override
  Future<Session> restoreSession() async => _restored;

  @override
  Future<void> signOut() async =>
      _sessions.add(const Session.unauthenticated());

  @override
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<User> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    String? inviteCode,
  }) => throw UnimplementedError();

  @override
  Future<User> signUpWithGoogle({String? inviteCode}) =>
      throw UnimplementedError();
}

/// **One Task, carried across three hops of the REAL router.**
///
/// Every screen in this chain is already tested, and every one of them is
/// tested against a stub of the next: `collector_task_detail_screen_test.dart`
/// declares its own `/checklist/:taskId`, and
/// `pre_recording_checklist_screen_test.dart` declares its own
/// `/checklist/:taskId` and `/recording/:sessionId`. Each proves a screen
/// navigates *somewhere named correctly*. None proves the id that arrives is
/// the id that was chosen.
///
/// This file uses `routerProvider` — the router the app actually runs — and
/// follows one Task from a list of three Projects to a started recording.
///
/// **Why it matters beyond navigation.** Tapping Start Recording does two
/// things at once: it writes `SelectedTask` into `core/identity/` and it
/// navigates. `PlatformTaskContext` reads that selection for a chunk's
/// `project_id` and `task_id`, so a wrong or missing write here becomes a
/// chunk attributed to the wrong Task — which uploads happily.
/// `chunk_to_upload_queue_test.dart` picks the story up from the selection;
/// this file is how the selection gets made.
void main() {
  const User collector = User(
    uid: 'firebase-uid-1',
    backendUserId: '11111111-1111-4111-8111-111111111111',
    email: 'collector@example.com',
    role: Role.collector,
    orgId: 'org-vump-demo',
    emailVerified: true,
  );

  // Straight from the shared seed, so the ids under test are the fixture's
  // rather than this file's invention.
  const String projectName = 'Riverside Corridor Survey';
  const String projectId = 'prj-riverside-survey';
  const String taskTitle = 'East embankment, north to south';
  const String taskId = 'tsk-riverside-embankment';

  Future<(ProviderContainer, GoRouter)> boot(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(const Session.authenticated(collector)),
        ),
        onboardingSeenStoreProvider.overrideWithValue(
          FakeOnboardingSeenStore(),
        ),
        projectTaskRepositoryProvider.overrideWithValue(
          FakeProjectTaskRepository(store: InMemoryProjectTaskStore()),
        ),
        // The checklist's five reads, all passing, plus the recording pipeline
        // behind the Start button. Extracted at Mission 8.1 from the screen's
        // own test rather than copied.
        cameraPermissionProbeProvider.overrideWithValue(
          const FakePermissionProbe(null),
        ),
        freeSpaceReaderProvider.overrideWithValue(const FakeFreeSpace()),
        recordingsDirectoryProvider.overrideWithValue('/files'),
        batteryReaderProvider.overrideWithValue(const FakeBattery()),
        networkReaderProvider.overrideWithValue(const FakeNetwork()),
        wideAngleEligibilityCacheProvider.overrideWithValue(const FakeCache()),
        cameraCapabilityProbeProvider.overrideWithValue(const FakeProbe()),
        recordingPipelineProvider.overrideWithValue(FakePipeline()),
        sessionIdGeneratorProvider.overrideWithValue(const FixedIds()),
        chunkIdGeneratorProvider.overrideWithValue(const FixedIds()),
        chunkFinalizerProvider.overrideWithValue(const FakeFinalizer()),
        chunkStoreProvider.overrideWithValue(const FakeStore()),
        // BR-06's boundary would otherwise be reported as a pending timer
        // after the tree is disposed. Mission 3.2 declared these seams for it.
        boundaryTimerFactoryProvider.overrideWithValue(
          (Duration duration, void Function() callback) => NoopTimer(),
        ),
        storageTimerFactoryProvider.overrideWithValue(
          (Duration interval, void Function(Timer) callback) => NoopTimer(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Resolved before the first frame, exactly as main.dart does it: the guard
    // must not run against AsyncLoading or it declines every route.
    await container.read(authNotifierProvider.future);
    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return (container, router);
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> walkToTaskDetail(WidgetTester tester, GoRouter router) async {
    router.go('/collector/projects');
    await tester.pumpAndSettle();

    await tester.tap(find.text(projectName));
    await tester.pumpAndSettle();

    await tester.tap(find.text(taskTitle));
    await tester.pumpAndSettle();
  }

  testWidgets('the Task chosen in the list is the Task the checklist opens', (
    WidgetTester tester,
  ) async {
    final (_, GoRouter router) = await boot(tester);

    await walkToTaskDetail(tester, router);
    expect(locationOf(router), contains(taskId));

    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    // The id in the URL is the one tapped two screens earlier, not a stub and
    // not a default.
    expect(locationOf(router), '/checklist/$taskId');
  });

  testWidgets('choosing the Task records BOTH ids, not just the one in the '
      'route', (WidgetTester tester) async {
    // `SelectedTask` carries `projectId` as well, and the route does not. The
    // screen takes it from the Task already on screen — the source comment
    // notes that deriving it later "would mean a network call to learn
    // something this widget holds". If it ever regressed to an empty string,
    // the route would still be right and every chunk would carry a blank
    // project.
    final (ProviderContainer container, GoRouter router) = await boot(tester);

    expect(container.read(selectedTaskProvider), isNull);

    await walkToTaskDetail(tester, router);
    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    final SelectedTask? selected = container.read(selectedTaskProvider);
    expect(selected, isNotNull);
    expect(selected!.taskId, taskId);
    expect(selected.projectId, projectId);
  });

  testWidgets('a passing checklist starts the recording and moves off the '
      'checklist route', (WidgetTester tester) async {
    final (_, GoRouter router) = await boot(tester);

    await walkToTaskDetail(tester, router);
    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    // The checklist runs five async reads in a post-frame callback; the button
    // is disabled until they land, so settling is the wait.
    await tester.tap(find.text('Start Recording').last);
    await tester.pumpAndSettle();

    expect(locationOf(router), startsWith('/recording/'));
    expect(locationOf(router), isNot('/checklist/$taskId'));
  });
}
