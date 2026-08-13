import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Admin's settings and account tab.
///
/// Volume 2 Chapter 2.4 §3 names it Settings/Account. Still largely a
/// placeholder from Mission 1.3's navigation skeleton; the invite-code entry
/// point below is the first real thing on it.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          // Navigated to by path, deliberately. The screen lives in
          // features/auth/, and importing it here would be the cross-feature
          // import ADR-022 R3 forbids — a route string is not a dependency.
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
        ],
      ),
    );
  }
}
