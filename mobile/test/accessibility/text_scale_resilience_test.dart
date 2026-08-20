import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';
import 'package:mobile/core/queue/providers/queue_ports.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_carousel_screen.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_create_project_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_create_task_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_dashboard_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_project_detail_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_projects_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_dashboard_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_project_detail_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_projects_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_task_detail_screen.dart';

import '../core/time/fakes/fake_clock.dart';
import '../features/projects_tasks/data/fakes/fake_project_task_admin_repository.dart';
import '../features/projects_tasks/data/fakes/fake_project_task_repository.dart';
import '../features/projects_tasks/data/fakes/in_memory_project_task_store.dart';

/// Chapter 2.10 §6 at 150% and 200%, across every screen Mission 5 built.
///
/// > *"Layouts … reflow vertically rather than truncating or overlapping when
/// > text is scaled up to at least 200%, per WCAG 1.4.4."*
///
/// ## WHAT THIS CATCHES, AND THE HALF IT CANNOT SEE
///
/// A genuine overflow — a `Column` taller than its box, a `Row` wider than its
/// constraints — raises `A RenderFlex overflowed by N pixels` through
/// `FlutterError`, which a widget test records as an exception. **That class is
/// what this file covers**, on ten screens at two scales.
///
/// **It does NOT catch silent clipping**, and that limit was measured rather
/// than assumed. A `NavigationBar` pinned to a fixed height clips a two-line
/// label at 200% and throws nothing; a fixed-height `FilledButton` does the
/// same. `tester.takeException()` returns null in both cases.
///
/// **This is a correction to A-134, not a footnote to it.** A-134 proposed
/// exactly this sweep as the test that "would have caught 107 without a
/// device". It would not have. 107 is held instead by
/// `test/app/navigation/tab_shell_test.dart`, which asserts the bar's height
/// against the text scale directly, and the two files are complementary rather
/// than redundant.
///
/// So: passing here means *no widget reported an overflow*. It does not mean
/// every screen is legible at 200%, and only the device pass can say that.
void main() {
  final DateTime now = DateTime.utc(2026, 9, 1, 10);

  Widget host(Widget screen, double scale) {
    final InMemoryProjectTaskStore store = InMemoryProjectTaskStore();
    return ProviderScope(
      overrides: <Override>[
        projectTaskRepositoryProvider.overrideWithValue(
          FakeProjectTaskRepository(store: store),
        ),
        projectTaskAdminRepositoryProvider.overrideWithValue(
          FakeProjectTaskAdminRepository(
            store: store,
            clock: FakeClock(start: now),
          ),
        ),
        chunkQueueSourceProvider.overrideWithValue(const _EmptyQueue()),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
  }

  final Map<String, Widget> screens = <String, Widget>{
    'C-01 Onboarding': OnboardingCarouselScreen(onComplete: () {}),
    'C-03 Collector Dashboard': const CollectorDashboardScreen(),
    'C-04 Collector Projects': const CollectorProjectsScreen(),
    'C-05 Collector Project Detail': const CollectorProjectDetailScreen(
      projectId: 'prj-riverside-survey',
    ),
    'C-06 Collector Task Detail': const CollectorTaskDetailScreen(
      projectId: 'prj-riverside-survey',
      taskId: 'tsk-riverside-embankment',
    ),
    'A-01 Admin Dashboard': const AdminDashboardScreen(),
    'A-02 Admin Projects': const AdminProjectsScreen(),
    'A-03 Admin Project Detail': const AdminProjectDetailScreen(
      projectId: 'prj-riverside-survey',
    ),
    'A-04 Create Project': const AdminCreateProjectScreen(),
    'A-05 Create Task': const AdminCreateTaskScreen(
      projectId: 'prj-riverside-survey',
    ),
  };

  for (final double scale in <double>[1.5, 2.0]) {
    group('no overflow at ${(scale * 100).round()}%', () {
      for (final MapEntry<String, Widget> entry in screens.entries) {
        testWidgets(entry.key, (WidgetTester tester) async {
          await tester.pumpWidget(host(entry.value, scale));
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} overflowed at ${scale}x',
          );
        });
      }
    });
  }
}

/// A queue with nothing in it — see the sweep test's copy for why.
class _EmptyQueue implements ChunkQueueSource {
  const _EmptyQueue();

  @override
  Stream<List<QueuedChunk>> watchQueue() =>
      Stream<List<QueuedChunk>>.value(const <QueuedChunk>[]);

  @override
  Future<List<QueuedChunk>> currentQueue() async => const <QueuedChunk>[];

  @override
  Future<void> requeue(String chunkId) async {}
}
