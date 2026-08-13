import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/auth_error_copy.dart';

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

  bool _busy = false;
  String? _error;

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
                    TextFormField(
                      key: const Key('signup.inviteCode'),
                      controller: _inviteCode,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Organisation invite code',
                        helperText: 'From the admin who invited you.',
                      ),
                      validator: _required('Enter your invite code.'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('signup.email'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Work email',
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('signup.password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Choose a password',
                      ),
                      validator: _required('Choose a password.'),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _ErrorBanner(
                        key: const Key('signup.error'),
                        message: _error!,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      key: const Key('signup.submit'),
                      onPressed: _busy ? null : _submitEmailPassword,
                      child: _busy
                          ? const SizedBox(
                              height: AppSizes.iconSm,
                              width: AppSizes.iconSm,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      key: const Key('signup.google'),
                      onPressed: _busy ? null : _submitGoogle,
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

  /// Rejects an empty field before a round trip.
  String? Function(String?) _required(String message) {
    return (String? value) => (value?.trim().isEmpty ?? true) ? message : null;
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Enter your work email.';
    }
    if (!email.contains('@') || email.startsWith('@') || email.endsWith('@')) {
      return 'That does not look like an email address.';
    }
    return null;
  }

  Future<void> _submitEmailPassword() {
    return _run(
      () => ref
          .read(authNotifierProvider.notifier)
          .signUpWithEmailPassword(
            email: _email.text.trim(),
            password: _password.text,
            inviteCode: _inviteCode.text.trim(),
          ),
    );
  }

  Future<void> _submitGoogle() {
    return _run(
      () => ref
          .read(authNotifierProvider.notifier)
          .signUpWithGoogle(inviteCode: _inviteCode.text.trim()),
      // The picker supplies the identity, so the email and password fields
      // are not filled in on this path and must not block it.
      validateAll: false,
    );
  }

  /// Runs an attempt and shows the failure, if any.
  ///
  /// There is no success branch, deliberately. A created account changes the
  /// session, and the route guard acts on that; navigating here as well would
  /// put two things in charge of where a signed-in person belongs, which is
  /// the duplication Mission 2.4's Role Router comment warned about.
  Future<void> _run(
    Future<Failure?> Function() attempt, {
    bool validateAll = true,
  }) async {
    if (validateAll) {
      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }
    } else if (_inviteCode.text.trim().isEmpty) {
      setState(() => _error = 'Enter your invite code.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final Failure? failure = await attempt();

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _error = failure == null || AuthErrorCopy.isSilent(failure)
          ? null
          : AuthErrorCopy.forFailure(failure);
    });
  }
}

/// The named, actionable error state Chapter 2.9 §2 requires.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: AppSizes.iconSm,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
