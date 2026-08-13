import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Admin's settings and account tab.
///
/// Volume 2 Chapter 2.4 §3 names it Settings/Account.
///
/// ## Two different ways of not importing `features/auth/`
///
/// ADR-022 R3 forbids a cross-feature import in either direction, and both
/// entries below respect it by different means — which is worth seeing side by
/// side.
///
/// The invite-code entry is a *destination*, so a route string suffices: a
/// path is not a dependency. Signing out is an *action*, so there is nothing
/// to navigate to; it arrives as an opaque widget from `app/router.dart`,
/// which is the one file permitted to import any feature's `presentation/`
/// (ADR-022 §2.2). That is R3's fourth resolution — compose, do not import.
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
          // Navigated to by path, deliberately — see the class documentation.
          //
          // TEMPORARY entry point, retired with ADR-036 at Mission 6/7.
          ListTile(
            key: const Key('adminSettings.inviteCodes'),
            leading: const Icon(Icons.key_outlined),
            title: const Text('Invite codes'),
            subtitle: const Text('Generate a code for a new Collector'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/admin/invite-codes'),
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
