import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_spacing.dart';

/// The Admin's settings and account tab.
///
/// Volume 2 Chapter 2.4 §3 names it Settings/Account.
///
/// ## How this screen avoids importing `features/auth/`
///
/// ADR-022 R3 forbids a cross-feature import in either direction. Signing out
/// is an *action*, so there is nothing to navigate to; it arrives as an opaque
/// widget from `app/router.dart`, which is the one file permitted to import
/// any feature's `presentation/` (ADR-022 §2.2). That is R3's fourth
/// resolution — compose, do not import.
///
/// This section once contrasted that with a second entry, the invite-code
/// *destination*, which needed only a route string because a path is not a
/// dependency. That entry was removed with invite-code issuing in Mission 7.6
/// Phase 6 (A-227), so only one of the two techniques is still demonstrated
/// here.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({
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

/// A section label, private for the reason its Collector twin is.
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
