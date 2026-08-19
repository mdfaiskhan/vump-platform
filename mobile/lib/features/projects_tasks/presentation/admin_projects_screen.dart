import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/presentation/load_more_tile.dart';

/// A-02 — Projects List (Admin). *"Every Project this Admin manages."*
///
/// ## It uses the Collector's read methods, unchanged
///
/// Chapter 4.6 §3's `GET /v1/projects` row serves both roles from one route:
/// *"Admin: all Projects in their org. Collector: only Projects with an
/// assigned Task (BR-19)."* **The scope difference is server-side**, derived
/// from the token exactly as BR-19 is (Chapter 4.8), so there is no
/// Admin-specific method, no `fetchAllProjects`, and no role parameter — the
/// same argument A-099 made for `fetchProjects` taking no `collectorId`.
///
/// **Consequence worth knowing:** `FakeProjectTaskRepository` models no
/// scoping at all, deliberately (5.1.1), so against the fake **this screen and
/// C-04 render identically**. The difference is real and untestable until
/// Mission 7 — recorded as A-119 rather than left to look like a bug.
///
/// ## Its empty state is NOT C-04's, and Chapter 2.9 says so
///
/// §4.2 specifies them separately:
///
/// > *"A Collector with no assigned Projects sees a plain-language explanation
/// > … An Admin's Projects List before their first Project is created **leads
/// > directly into the "+ New Project" action**, since that empty state has an
/// > obvious, single next step."*
///
/// So C-04 says *nothing here, wait*; this says *nothing here, do this*. That
/// divergence is easy to lose under Chapter 2.7 §5's *"same pattern as their
/// Collector counterparts"*, which is why it is called out here.
class AdminProjectsScreen extends ConsumerWidget {
  /// Creates the Admin Projects list.
  const AdminProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: switch (projects) {
        AsyncData<List<Project>>(:final List<Project> value)
            when value.isEmpty =>
          const _AdminProjectsEmpty(),
        AsyncData<List<Project>>(:final List<Project> value) =>
          RefreshIndicator(
            onRefresh: () => ref.read(projectsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              // One extra row when the backend said there is another page.
              // `hasMore` is the notifier's narrow getter — F25 keeps the
              // cursor off the state, so the list itself is still List<Project>
              // and this widget is the only thing that had to learn about it.
              itemCount:
                  value.length +
                  (ref.read(projectsProvider.notifier).hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) =>
                  index >= value.length
                  ? LoadMoreTile(
                      label: 'Projects',
                      onLoad: () =>
                          ref.read(projectsProvider.notifier).loadMore(),
                    )
                  : _AdminProjectCard(project: value[index]),
            ),
          ),
        AsyncError<List<Project>>() => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text(
              "Your Projects couldn't be loaded. Check your connection and "
              'pull down to try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      // Chapter 2.7 §5: the Collector's pattern "with Admin-only action
      // buttons ('+ New Project', '+ New Task') added per FR-ADM-01/02".
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/projects/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }
}

/// Chapter 2.9 §4.2's Admin empty state — a next step, not an explanation.
class _AdminProjectsEmpty extends StatelessWidget {
  const _AdminProjectsEmpty();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'No Projects yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create a Project, then add the Tasks your Collectors will '
              'record.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            // The action itself, not just a pointer at the button behind it.
            // §4.2's "leads directly into" is what makes this different from
            // C-04's copy, which has no action to offer.
            FilledButton.icon(
              onPressed: () => context.go('/admin/projects/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminProjectCard extends StatelessWidget {
  const _AdminProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? description = project.description;
    final bool archived = project.archivedAt != null;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        title: Text(project.name, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (description != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            if (archived) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              // A word, not a colour — Chapter 2.10 §2.1, the same marker
              // C-04 uses (A-109). Nothing in this app sets `archived_at`;
              // open item 88 records that it is read in three places and
              // written in none.
              Text(
                'Archived',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/admin/projects/${project.id}'),
      ),
    );
  }
}
