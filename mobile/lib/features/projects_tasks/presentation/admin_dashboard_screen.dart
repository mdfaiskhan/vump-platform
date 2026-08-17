import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';

/// A-01 — Admin Dashboard.
///
/// ## What this screen is, and the framing matters
///
/// **This is a placeholder being given its specified job**, not a dashboard
/// shipped with two tiles missing. The distinction decides why it was built
/// when A-06 was not (A-122).
///
/// Volume 2 Chapter 2.2's Admin flow, step 2, gives the Admin Dashboard one
/// concrete responsibility: *"Selects '**New Project**' or an existing
/// Project"*, with the branch *"No Projects yet → empty state prompting
/// Project creation."* That is a **navigation duty**, and it is fully
/// satisfiable today. Until now this tab rendered its own name — a Mission 1.3
/// placeholder sitting in the Admin shell's first slot, which is where the
/// Role Router lands every Admin on login (Chapter 2.2 step 1).
///
/// So the screen exists to do the job Chapter 2.2 assigns it, and it carries
/// the one tile that has an honest source. It is not an attempt at the
/// three-tile dashboard Chapter 1.1 §7.3 sketches.
///
/// ## One of three tiles has a source, and the other two are omitted silently
///
/// Chapter 1.1 §7.3: *"Admin view: all managed Projects, Collector activity
/// summary, and outstanding Task counts."* Chapter 2.5's A-01 row transcribes
/// it. **No functional requirement governs this screen at all** — FR-ADM-01
/// through 08 cover create, edit, assign, view-status and view-metadata, and
/// none is a dashboard; FR-PT-01 is the Collector's and has no Admin
/// counterpart (open item 93).
///
/// | Tile | Source |
/// |---|---|
/// | Managed Projects | `fetchProjects()` — Ch. 4.6 §3's Admin scope (A-119) |
/// | Collector activity | **None.** Items 92, 89 and 36, by reading |
/// | Outstanding Tasks | **None.** `tasks` has no status (item 94) |
///
/// The two absent tiles render **nothing at all** — no zero, no placeholder,
/// no "unavailable" label. C-03 set that precedent for its own two unsourced
/// aggregates, and Chapter 2.9 supplies no vocabulary for *"this data has no
/// source"* (A-122), so labelling them would need copy the chapter does not
/// support and would say something false.
///
/// ## Why C-03's implementation could not be reused, and it is not an item
///
/// C-03 counts chunks through `core/queue/`, which is *"a live view over
/// `local_chunks.status`"* — **this device's** chunks. A Collector's dashboard
/// works because it summarises the work sitting on the phone in their hand.
///
/// **An Admin's device holds no Collector chunks.** *"Collector activity
/// across them"* is about other people's devices, and nothing local can see
/// it. That is structural rather than a gap: no open item blocks it, because
/// no fix on this side would help.
///
/// **Consequence worth carrying to A-07's trace:** open item 81 — C-11
/// forgetting swept sessions in the local queue — **does not apply to any
/// Admin screen**, because no Admin screen can read the local queue in the
/// first place.
class AdminDashboardScreen extends ConsumerWidget {
  /// Creates the Admin dashboard.
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: switch (projects) {
        AsyncData<List<Project>>(:final List<Project> value)
            when value.isEmpty =>
          const _AdminDashboardEmpty(),
        AsyncData<List<Project>>(:final List<Project> value) =>
          _AdminDashboardBody(projectCount: value.length),
        AsyncError<List<Project>>() => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text(
              "Your Projects couldn't be loaded. Check your connection and "
              'try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Chapter 2.2 step 2's two destinations, over the one sourced tile.
class _AdminDashboardBody extends StatelessWidget {
  const _AdminDashboardBody({required this.projectCount});

  final int projectCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    // "All managed Projects", not "active" -- unlike C-03 this
                    // needs no archivedAt reading (A-104), because Chapter 1.1
                    // §7.3 asks for the managed set rather than the live one.
                    projectCount == 1
                        ? 'You manage 1 Project'
                        : 'You manage $projectCount Projects',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Chapter 2.2 step 2: "Selects 'New Project' or an existing Project."
        // Both destinations, in the order that sentence names them.
        SizedBox(
          height: AppSizes.buttonHeightLg,
          child: FilledButton.icon(
            onPressed: () => context.go('/admin/projects/new'),
            icon: const Icon(Icons.add),
            label: const Text('New Project'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: AppSizes.buttonHeightLg,
          child: OutlinedButton(
            onPressed: () => context.go('/admin/projects'),
            child: const Text('View all Projects'),
          ),
        ),
      ],
    );
  }
}

/// Chapter 2.2 step 2's branch: *"No Projects yet → empty state prompting
/// Project creation."*
///
/// The same shape A-02's empty state takes under Chapter 2.9 §4.2 (A-120) —
/// an Admin with nothing yet has one obvious next step, so the state leads
/// into it rather than explaining an absence.
class _AdminDashboardEmpty extends StatelessWidget {
  const _AdminDashboardEmpty();

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
