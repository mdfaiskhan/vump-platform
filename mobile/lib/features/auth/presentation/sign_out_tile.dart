import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/auth/application/auth_notifier.dart';

/// The Sign out control, owned by `auth` and placed by whoever hosts it.
///
/// ## Why this is a widget rather than a button on the Settings screens
///
/// Volume 2 Chapter 2.3 §2 puts "account and logout" on Settings, so that is
/// where it belongs on screen. But `features/settings/` may not import
/// `features/auth/` — ADR-022 R3 forbids a cross-feature import *"at any
/// layer, in either direction"*, and A-039 records that this rule overrides
/// Volume 3 Chapter 3.5's module graph where the two disagree.
///
/// R3's fourth resolution is to compose rather than import. `app/router.dart`
/// is the one file permitted to import from any feature's `presentation/`
/// (ADR-022 §2.2), so it builds this tile and hands it to the Settings screens
/// as an opaque `Widget`. Settings renders something it cannot name; `auth`
/// owns what it does. Neither feature imports the other.
///
/// `AdminSettingsScreen` already solves the same problem the other way, for a
/// case where navigation was enough: it reaches the invite-code screen by
/// path, because a route string is not a dependency. That does not work here —
/// signing out is an action, not a destination.
///
/// ## It does not navigate
///
/// Signing out changes the session; the route guard reacts to that and moves
/// the person to Login (ADR-037). Calling `go` here as well would put two
/// things in charge of where a signed-out user belongs, which is the
/// duplication Mission 2.7 removed from `LoginScreen`.
class SignOutTile extends ConsumerStatefulWidget {
  const SignOutTile({super.key});

  @override
  ConsumerState<SignOutTile> createState() => _SignOutTileState();
}

class _SignOutTileState extends ConsumerState<SignOutTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      key: const Key('settings.signOut'),
      leading: Icon(Icons.logout, color: theme.colorScheme.error),
      title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
      enabled: !_busy,
      onTap: _busy ? null : _confirmThenSignOut,
    );
  }

  Future<void> _confirmThenSignOut() async {
    // A plain confirmation, not Chapter 2.9 §4.4's named-consequence dialog:
    // signing out is reversible by signing back in, and §4.4 reserves that
    // treatment for irreversible actions.
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            key: const Key('settings.signOut.dialog'),
            title: const Text('Sign out?'),
            content: const Text(
              'You will need to sign in again to use the app.',
            ),
            actions: <Widget>[
              TextButton(
                key: const Key('settings.signOut.cancel'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('settings.signOut.confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _busy = true);
    await ref.read(authNotifierProvider.notifier).signOut();

    // No navigation, and no success branch. The guard owns where the person
    // goes next; if this widget is still mounted when that happens, it is
    // about to be disposed with the screen behind it.
    if (mounted) {
      setState(() => _busy = false);
    }
  }
}
