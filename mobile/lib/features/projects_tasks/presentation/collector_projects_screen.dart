import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';

/// C-04 — Projects List. FR-PT-03, and FR-PT-07's more-than-one case.
///
/// Volume 2 Chapter 2.5: *"Every Project assigned to this Collector."*
/// Chapter 2.7 §5 covers it by cross-reference as a *"standard card-list"*
/// using Chapter 2.8 components — which are not in this repository, so this is
/// built from `lib/app/theme/`'s tokens and `Theme.of(context)` (open item 74).
///
/// ## It applies no assignment filter, and that is correct
///
/// BR-19 — *"a Collector shall never have visibility into a Project or Task
/// they are not assigned to"* — is enforced **server-side**. Volume 4 Chapter
/// 4.8 re-derives scope from the verified token and Chapter 4.2 §3 injects
/// `WHERE task_assignments.user_id = :current_user`, *"never left optional"*.
/// Filtering again here would be a client-side guess at a server-side rule.
///
/// ## Archived Projects are SHOWN, and labelled
///
/// Nothing decides this: FR-PT-03, BR-19, Chapter 2.5 and Chapter 4.6 §3 are
/// all silent on archival, and Chapter 4.2 §1 only establishes that an
/// archived Project's data stays queryable. So it was a genuine choice.
///
/// Hiding them would drop a Project a Collector may have recorded against out
/// of their list with no explanation. Showing them undifferentiated would let
/// someone start work against a closed Project. **Showing them with a text
/// label** is the option that loses nothing and hides nothing.
///
/// The marker is a **word, not a tint** — Chapter 2.10 §2.1's colour-is-never-
/// the-only-signal rule, which is written about status pills and applies
/// exactly as well here.
///
/// C-03 counts only *active* Projects (`archivedAt == null`, A-104), so its
/// number and this list's length can differ. The two labels — "Active
/// projects" there, "Projects" here — are what make that legible.
class CollectorProjectsScreen extends ConsumerWidget {
  /// Creates the Projects list.
  const CollectorProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: switch (projects) {
        AsyncData<List<Project>>(:final List<Project> value)
            when value.isEmpty =>
          const _ProjectsMessage(
            // A real answer, and a different one from "nothing was wired up"
            // — which is what `projectTaskRepositoryProvider` throws for.
            message: 'No Projects are assigned to you yet.',
          ),
        AsyncData<List<Project>>(:final List<Project> value) =>
          RefreshIndicator(
            onRefresh: () => ref.read(projectsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: value.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) =>
                  _ProjectCard(project: value[index]),
            ),
          ),
        AsyncError<List<Project>>() => const _ProjectsMessage(
          // Ch. 2.9 §2's named-cause rule. This list is the one surface that
          // genuinely depends on the network, so naming the connection is
          // accurate here in a way it would not be on C-03.
          message:
              "Your Projects couldn't be loaded. Check your connection "
              'and pull down to try again.',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

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
              // A word, not a colour. Ch. 2.10 §2.1.
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
        // Archived Projects stay openable. Chapter 4.2 §1 keeps their data
        // queryable deliberately, and a Collector who recorded against one
        // still needs to reach its Tasks.
        onTap: () => context.go('/collector/projects/${project.id}'),
      ),
    );
  }
}

class _ProjectsMessage extends StatelessWidget {
  const _ProjectsMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
