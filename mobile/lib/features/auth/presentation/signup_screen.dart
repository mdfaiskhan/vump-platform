import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';

/// The sign-up variant of SH-02 — **built, and deliberately unreachable.**
///
/// ## Why it is not registered
///
/// This screen has no route in `app/router.dart`, no link from
/// `LoginScreen`, and no other entry point. That is not an
/// oversight and not a temporary state to be tidied up: reaching it would be a
/// defect, because the flow behind it cannot work and, as specified, should
/// not exist.
///
/// Volume 10 Chapter 10.4 §4 records that accounts are *"provisioned by the
/// client organization, not public self-signup"* and that the login screen
/// deliberately has no Sign Up option. Amendment **A-051** registers
/// self-service registration as a product change the project owner asked for,
/// and it is still blocked on three unspecified things: a redemption endpoint
/// (Volume 4 Chapter 4.6 defines none, and `backend/` is empty), an Admin
/// surface that issues codes, and how role and `org_id` are set for an account
/// nobody provisioned.
///
/// Beneath all of that, `AuthRepositoryImpl._redeemInviteCode` throws an
/// `UnimplementedError`. **A reachable sign-up button would crash the app**,
/// which is exactly what that throw is for — it is loud on purpose rather than
/// a stub that quietly admits anyone who can type a string.
///
/// ## Why it exists at all
///
/// The mission asked for the surface so the shape of the flow is settled — the
/// three inputs Mission 2.1's `signUpWithEmailPassword` requires, and the
/// Google variant beside them. It is a form with no submit path, so nothing
/// here can be called by accident.
///
/// ## What Mission 2.6 has to do
///
/// Register a route, add the entry point, and replace the blocked notice
/// with a
/// real submit that calls `signUpWithEmailPassword`. Until then it is
/// the honest description of the screen's state, and it is rendered rather
/// than commented out so that anyone who does reach it is told why nothing
/// happens instead of tapping a dead button.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _inviteCode = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _blockedNotice(context),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('signup.inviteCode'),
                      controller: _inviteCode,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Organisation invite code',
                        helperText: 'From the admin who invited you.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('signup.email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Work email',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('signup.password'),
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Choose a password',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Disabled, not merely unwired. `onPressed: null` is what
                    // makes it unpressable; there is no handler to call even
                    // if it were enabled, so no code path reaches the throwing
                    // redemption step.
                    const FilledButton(
                      key: Key('signup.submit'),
                      onPressed: null,
                      child: Text('Create account'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      key: const Key('signup.google'),
                      onPressed: null,
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Text('Continue with Google'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// States plainly that the flow is not built, per Chapter 2.9 §2.
  ///
  /// *"Never fail silently"* applies to a screen that cannot do its job as
  /// much as to a failed operation. A form that looks ready and does nothing
  /// is the silent failure that principle forbids.
  Widget _blockedNotice(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const Key('signup.blocked'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: AppSizes.iconSm),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Creating your own account is not available yet. Your '
              'organisation admin sets up your account and sends you the '
              'sign-in details.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
