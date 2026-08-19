import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/projects_tasks/application/dashboard_summary.dart';

/// C-03 — Home Dashboard. FR-PT-01 in part, FR-PT-02 in full.
///
/// ## This screen has no Chapter 2.7 component table
///
/// Chapter 2.7 §1 specifies in full only the screens *"with distinct
/// interaction logic"* and §5 cross-references the rest. C-03 is in §5:
/// *"standard card-list and label/value layouts using only components already
/// defined in Chapter 2.8."*
///
/// **Chapter 2.8 is not in this repository** — Volume 2's front matter says it
/// and Chapter 2.6 are *"delivered separately"* as interactive HTML, and
/// neither file is here. So the components this screen was told to use cannot
/// be read. It is built from the tokens Missions 0.7 and 4.6 already
/// transcribed into `lib/app/theme/` and from `Theme.of(context)`, which is
/// what ADR-005 requires of a widget in any case.
///
/// **The visual result is therefore unreconciled against Chapter 2.8's real
/// definitions**, and that is recorded rather than assumed away — Mission 5.3's
/// Design System audit inherits it as open item 74.
///
/// ## Two of FR-PT-01's four aggregates are not shown at all
///
/// *"In-progress sessions"* and *"total recorded time"* have no source this
/// feature can reach; `DashboardSummary` carries the full argument and the two
/// open items. **No tile is rendered for either.** A tile reading `0` or
/// `0h 0m` would be a claim about the Collector's work, and a false one — an
/// absent tile is an absence, which is the honest state.
class CollectorDashboardScreen extends ConsumerWidget {
  /// Creates the dashboard.
  const CollectorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardSummary> summary = ref.watch(
      dashboardSummaryProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: switch (summary) {
        AsyncData<DashboardSummary>(:final DashboardSummary value) =>
          _DashboardBody(summary: value),
        AsyncError<DashboardSummary>() => const _DashboardMessage(
          // Chapter 2.9 §2's named-cause rule. This is the one failure this
          // screen can actually have -- the queue is local, so it is a storage
          // fault rather than a network one, and saying "check your
          // connection" would send the Collector to fix the wrong thing.
          message: "Your recording data couldn't be read from this device.",
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        // "Active projects" was the first tile until Mission 7.4 step 4. F20
        // paginated `projectsProvider`, so the count it was reading became
        // "projects on the pages loaded so far" — and this screen's existing
        // rule for an aggregate it cannot answer is to omit the tile, not to
        // approximate it. Two of FR-PT-01's four were already absent on those
        // terms; this is the third. A-200.
        _StatCard(label: 'Waiting to upload', value: '${summary.queuedChunks}'),
        const SizedBox(height: AppSpacing.md),
        _StatCard(label: 'Uploading', value: '${summary.uploadingChunks}'),
        const SizedBox(height: AppSpacing.md),
        _StatCard(
          label: 'Uploaded',
          value: '${summary.completeChunks}',
          // Open item 61: cleanup soft-deletes completed chunks and the queue
          // excludes them, so this number falls as housekeeping runs. Said on
          // screen because a count that resets itself reads as data loss.
          note: 'Counts recordings still stored on this device.',
        ),
        if (summary.failedChunks > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _StatCard(
            label: 'Needs attention',
            value: '${summary.failedChunks}',
            note: 'Open Sessions to retry.',
            emphasised: true,
          ),
        ],
      ],
    );
  }
}

/// One label/value row in a card — Chapter 2.7 §5's *"label/value layout"*.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.note,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final String? note;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? note = this.note;

    return Card(
      // Chapter 2.10 §2.1's colour-is-never-the-only-signal rule, applied
      // beyond status pills: the attention card is distinguished by its own
      // label text and note, and the container colour only reinforces them.
      color: emphasised ? theme.colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: theme.textTheme.titleMedium),
                  if (note != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(note, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Chapter 2.10 §6: the value reflows with the label rather than
            // truncating, because a truncated count is worse than no count.
            Text(value, style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({required this.message});

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
