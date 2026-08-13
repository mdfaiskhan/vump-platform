import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/auth_error_copy.dart';

/// The sign-up variant of SH-02 — routed at `/signup` and linked from Login.
///
/// ## Reachable, and now advertised
///
/// Mission 2.7 routed this screen without a link, because Volume 10 Chapter
/// 10.4 §4 frames the absent Sign Up option as something to explain to an App
/// Store reviewer, and an unadvertised route kept that framing literally true.
/// Amendment **A-056** reverses that on its own terms: a build shared as an
/// APK among known people is not submitted to App Review, so the reasoning
/// does not reach this distribution model. `LoginScreen` links here.
///
/// ## The invite code is optional
///
/// Without one the account joins the default organisation; with one it joins
/// that code's organisation and spends a use. **The role is Collector either
/// way** — no invite code grants admin, and admin remains a manual bootstrap
/// performed outside the application.
///
/// ## Where the navigation happens after this
///
/// Nowhere in this file. A successful sign-up leaves the account created with
/// its claims already set, so the session stream reports an authenticated user
/// and the route guard moves the person to their role's root. This screen
/// never calls `go`.
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
                        labelText: 'Invite code (optional)',
                        helperText: 'Leave empty unless an admin gave you one.',
                      ),
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
                    const SizedBox(height: AppSpacing.lg),
                    // The mirror of Login's 'Create an account' link, in the
                    // same position and with the same shape: a TextButton last
                    // in the column, disabled while an attempt is in flight,
                    // navigating by path so the router stays the only place
                    // that maps paths to screens (ADR-004).
                    TextButton(
                      key: const Key('signup.signIn'),
                      onPressed: _busy ? null : () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
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
            inviteCode: _codeOrNull(),
          ),
    );
  }

  Future<void> _submitGoogle() {
    return _run(
      () => ref
          .read(authNotifierProvider.notifier)
          .signUpWithGoogle(inviteCode: _codeOrNull()),
      // The picker supplies the identity, so the email and password fields
      // are not filled in on this path and must not block it.
      validateAll: false,
    );
  }

  /// The typed code, or null when the field was left empty.
  ///
  /// Null and empty mean the same thing to the function — the default
  /// organisation (A-056) — but sending null says so deliberately rather than
  /// by coincidence.
  String? _codeOrNull() {
    final String code = _inviteCode.text.trim();
    return code.isEmpty ? null : code;
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
