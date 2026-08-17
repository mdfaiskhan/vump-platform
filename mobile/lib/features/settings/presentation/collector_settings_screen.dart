import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_spacing.dart';

/// The Collector's settings tab.
///
/// Volume 2 Chapter 2.3 §2 gives it account and logout, upload mode
/// (automatic or manual), and — in Phase 2 — support contact and
/// notifications. Only the first exists so far.
///
/// ## Why the account actions arrive as opaque widgets
///
/// Signing out belongs to `features/auth/`, and this feature may not import
/// it: ADR-022 R3 forbids a cross-feature import in either direction, and
/// A-039 records that the rule overrides Volume 3 Chapter 3.5's module graph
/// where they disagree. R3's fourth resolution is to compose instead, so
/// `app/router.dart` — the one file permitted to import any feature's
/// `presentation/` — builds the controls and passes them in.
///
/// This screen therefore renders something it cannot name, which is the
/// point: it hosts the section without depending on what fills it.
class CollectorSettingsScreen extends StatelessWidget {
  const CollectorSettingsScreen({
    super.key,
    this.accountActions = const <Widget>[],
  });

  /// Controls for the account section, supplied by the composition point.
  final List<Widget> accountActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          if (accountActions.isNotEmpty) ...<Widget>[
            const _SectionHeader('Account'),
            ...accountActions,
          ],
        ],
      ),
    );
  }
}

/// A section label, kept private until a second screen needs one.
///
/// R2 admits nothing to `shared/` without a second consumer, so this stays
/// here rather than being promoted on the strength of one use.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
