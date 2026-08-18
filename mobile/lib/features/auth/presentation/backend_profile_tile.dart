import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/auth/application/backend_profile_provider.dart';

/// Shows what the backend says about the signed-in account.
///
/// Reads `GET /v1/users/me` (Chapter 4.6 §2) through the API Gateway
/// authorizer — the row, not the token. Chapter 4.7 §2 makes the `users` table
/// *"the authoritative source if the claim and the table ever disagree"*, so a
/// screen that shows the organisation is showing this rather than the claim.
///
/// ## Composed in, like `SignOutTile`, and for the same reason
///
/// `features/settings/` may not import `features/auth/` — ADR-022 R3 forbids a
/// cross-feature import in either direction. `app/router.dart` builds this and
/// hands it to the Settings screens as an opaque `Widget`.
///
/// ## Failure is shown, not swallowed
///
/// A failed read renders its message. Chapter 2.9 §2 forbids a generic
/// *"Something went wrong"*, and the envelope carries a named code precisely so
/// a caller can say what happened — including the authorizer refusing, which is
/// the one failure this tile is most likely to surface.
class BackendProfileTile extends ConsumerWidget {
  /// Creates the tile.
  const BackendProfileTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<BackendProfile> profile = ref.watch(
      backendProfileProvider,
    );

    return ListTile(
      leading: const Icon(Icons.badge_outlined),
      title: const Text('Backend profile'),
      subtitle: profile.when(
        loading: () => const Text('Loading…'),
        error: (Object error, StackTrace _) =>
            Text('$error', style: TextStyle(color: theme.colorScheme.error)),
        data: (BackendProfile it) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Role: ${it.role}'),
              Text('Organisation: ${it.orgId}'),
              Text('User: ${it.userId}'),
            ],
          ),
        ),
      ),
      isThreeLine: profile.hasValue,
    );
  }
}
