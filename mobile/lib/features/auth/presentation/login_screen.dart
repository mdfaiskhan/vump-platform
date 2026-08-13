import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/presentation/auth_error_copy.dart';

/// SH-02 — the single shared sign-in surface for both roles.
///
/// Volume 2 Chapter 2.5 §1 specifies its contents: *"Email/password fields,
/// SSO entry point, error states"*. Chapter 2.4 §4 makes it role-agnostic —
/// *"there is no separate 'Admin login' surface"*.
///
/// ## This screen does not navigate
///
/// It did until Mission 2.7. Chapter 2.4 §4's Role Router now lives in the
/// route guard (`AuthGuard`, ADR-037): a successful sign-in changes the
/// session, the router's `refreshListenable` fires, and the redirect sends the
/// person to their role's root.
///
/// Navigating from here as well would put two things in charge of where a
/// signed-in user belongs — the duplication the previous version of this
/// comment warned about, resolved in the direction it predicted.
///
/// ## Sign-up is not linked from here
///
/// Volume 10 Chapter 10.4 §4 records that the login screen has no Sign Up
/// option *"since there deliberately isn't one"*, and amendment A-051 keeps
/// self-service registration blocked until a redemption endpoint exists.
/// `SignupScreen` is built but registered nowhere — see its documentation.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  /// True while an attempt is in flight, so the buttons cannot be tapped twice.
  bool _busy = false;

  /// The failure to show, or null. Held here rather than in the notifier —
  /// a rejected password is an outcome of this attempt, not a session state.
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Whether the session lapsed rather than never having existed.
  ///
  /// Read from the notifier rather than passed as a route argument, so it
  /// stays true wherever the user reaches this screen from — Mission 2.7's
  /// guard will redirect here without going through a caller that could carry
  /// a flag.
  bool get _sessionExpired =>
      ref.watch(authNotifierProvider).valueOrNull is AuthStateExpired;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
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
                    // Volume 6 Chapter 6.7 §3 ends silent re-authentication by
                    // "falling back to the Login screen". Arriving here with no
                    // explanation, having been signed in a moment ago, is the
                    // silent failure Chapter 2.9 §2 forbids — so the fallback
                    // says why.
                    if (_sessionExpired) ...<Widget>[
                      const _Notice(
                        key: Key('login.expired'),
                        message:
                            'Your session ended. Sign in again to continue.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      key: const Key('login.email'),
                      controller: _email,
                      enabled: !_busy,
                      autofillHints: const <String>[AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Work email',
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('login.password'),
                      controller: _password,
                      enabled: !_busy,
                      autofillHints: const <String>[AutofillHints.password],
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: _validatePassword,
                      onFieldSubmitted: (_) => _submitEmailPassword(),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      key: const Key('login.submit'),
                      onPressed: _busy ? null : _submitEmailPassword,
                      child: _busy
                          ? const SizedBox(
                              height: AppSizes.iconSm,
                              width: AppSizes.iconSm,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // The "SSO entry point" of Chapter 2.5 §1. Amendment A-053
                    // records that this reads FR-AUTH-02's enterprise SSO more
                    // narrowly than written.
                    OutlinedButton.icon(
                      key: const Key('login.google'),
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

  /// Rejects an empty or obviously malformed address before a round trip.
  ///
  /// Deliberately shallow. A stricter pattern rejects addresses that are
  /// genuinely valid, and the server is the authority on whether an account
  /// exists — this only catches the typo that would waste a request.
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password.';
    }
    return null;
  }

  Future<void> _submitEmailPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _run(
      () => ref
          .read(authNotifierProvider.notifier)
          .signInWithEmailPassword(
            email: _email.text.trim(),
            password: _password.text,
          ),
    );
  }

  Future<void> _submitGoogle() async {
    // No form validation: the account picker supplies the identity, so the
    // empty email field is not a reason to block this path.
    await _run(ref.read(authNotifierProvider.notifier).signInWithGoogle);
  }

  /// Runs an attempt, then either routes by role or shows the failure.
  Future<void> _run(Future<Failure?> Function() attempt) async {
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

/// An informational message, distinct from a failure.
///
/// A lapsed session is not an error the person made, so it does not get the
/// error colouring — Chapter 2.9 §5's rule that a queued chunk must look
/// different from a failed one is the same instinct: two different situations
/// should not share one appearance.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
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
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// The named, actionable error state Chapter 2.9 §2 requires.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const Key('login.error'),
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
