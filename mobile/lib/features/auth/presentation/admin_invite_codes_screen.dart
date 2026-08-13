import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/invite_code_notifier.dart';
import 'package:mobile/features/auth/domain/entities/org_invite_code.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/presentation/auth_error_copy.dart';

/// The Admin's invite-code generation surface.
///
/// **TEMPORARY — retired with the rest of ADR-036 at Mission 6/7.**
///
/// ## Why it lives in `features/auth/` and not `features/settings/`
///
/// Settings is where an Admin would look for it, and Volume 3 Chapter 3.5
/// gives `settings` the Admin account surface. Putting the screen there would
/// mean `features/settings/` importing this feature's invite-code repository,
/// which is the cross-feature import ADR-022 R3 forbids outright — the failure
/// that "quietly turns two modules into one".
///
/// Discoverability is solved without the import: `AdminSettingsScreen`
/// navigates here by *path*, and a route string is not a dependency.
///
/// ## The Firestore rules are the gate, not this screen
///
/// Reaching this screen grants nothing. Every write is checked against
/// `firestore.rules`, which requires the `admin` claim and an `org_id`
/// matching the code's organisation, so an Admin cannot mint a code for
/// another org and a non-admin cannot write at all. The screen reads the
/// org from the signed-in user's own claim rather than offering a field,
/// because a field would imply a choice the rules would then refuse.
class AdminInviteCodesScreen extends ConsumerStatefulWidget {
  const AdminInviteCodesScreen({super.key});

  @override
  ConsumerState<AdminInviteCodesScreen> createState() =>
      _AdminInviteCodesScreenState();
}

class _AdminInviteCodesScreenState
    extends ConsumerState<AdminInviteCodesScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _uses = TextEditingController(text: '1');

  /// Default expiry. Long enough to send and be read, short enough that a
  /// forgotten code stops working on its own.
  Duration _validFor = const Duration(days: 7);

  bool _busy = false;
  OrgInviteCode? _issued;
  String? _error;

  @override
  void dispose() {
    _uses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? admin = ref.watch(authNotifierProvider).value?.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Invite codes')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: admin == null
                ? const _Notice(
                    key: Key('invite.signedOut'),
                    message: 'Sign in as an admin to issue invite codes.',
                  )
                : _form(context, admin),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, User admin) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Notice(
            key: const Key('invite.org'),
            message:
                'Codes are issued for your organisation (${admin.orgId}). '
                'Anyone who redeems one joins it as a Collector.',
          ),
          const SizedBox(height: AppSpacing.lg),

          DropdownButtonFormField<Duration>(
            key: const Key('invite.expiry'),
            initialValue: _validFor,
            decoration: const InputDecoration(labelText: 'Valid for'),
            items: const <DropdownMenuItem<Duration>>[
              DropdownMenuItem<Duration>(
                value: Duration(days: 1),
                child: Text('1 day'),
              ),
              DropdownMenuItem<Duration>(
                value: Duration(days: 7),
                child: Text('7 days'),
              ),
              DropdownMenuItem<Duration>(
                value: Duration(days: 30),
                child: Text('30 days'),
              ),
            ],
            onChanged: _busy
                ? null
                : (Duration? value) =>
                      setState(() => _validFor = value ?? _validFor),
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            key: const Key('invite.uses'),
            controller: _uses,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Number of uses',
              helperText: 'Leave empty for unlimited.',
            ),
            validator: _validateUses,
          ),

          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Notice(
              key: const Key('invite.error'),
              message: _error!,
              isError: true,
            ),
          ],
          if (_issued != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _IssuedCode(code: _issued!),
          ],

          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('invite.submit'),
            onPressed: _busy ? null : () => _issue(admin.orgId),
            child: _busy
                ? const SizedBox(
                    height: AppSizes.iconSm,
                    width: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate code'),
          ),
        ],
      ),
    );
  }

  /// Empty means unlimited; anything present must be a positive whole number.
  String? _validateUses(String? value) {
    final String raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(raw);
    if (parsed == null || parsed < 1) {
      return 'Enter a number of 1 or more, or leave it empty for unlimited.';
    }
    return null;
  }

  Future<void> _issue(String orgId) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _issued = null;
    });

    final String raw = _uses.text.trim();
    final ({OrgInviteCode? code, Failure? failure}) result = await ref
        .read(inviteCodeIssuerProvider)
        .issue(
          orgId: orgId,
          // Computed from the device clock, which is fine: this value is a
          // deadline the admin is choosing, and the server compares against
          // its own clock at redemption. A skewed device makes a code expire
          // sooner or later than intended, never a code that outlives its
          // check.
          expiresAt: DateTime.now().toUtc().add(_validFor),
          remainingUses: raw.isEmpty ? null : int.parse(raw),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _issued = result.code;
      _error = result.failure == null
          ? null
          : AuthErrorCopy.forFailure(result.failure!);
    });
  }
}

/// The generated code, shown once and copyable.
///
/// Shown once because nothing can retrieve it later: the Firestore rules deny
/// every client read, so there is no list to come back to. The screen says so
/// rather than letting an admin discover it by looking.
class _IssuedCode extends StatelessWidget {
  const _IssuedCode({required this.code});

  final OrgInviteCode code;

  /// Uses and expiry, in one line.
  String _summary(OrgInviteCode code) {
    final String uses = code.remainingUses == null
        ? 'Unlimited uses'
        : '${code.remainingUses} use(s)';
    final String expiry = code.expiresAt.toLocal().toString().split('.').first;
    return 'Copy this now — it cannot be shown again. $uses, expires $expiry.';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const Key('invite.issued'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            code.code,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _summary(code),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('invite.copy'),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: code.code)),
              icon: const Icon(Icons.copy, size: AppSizes.iconSm),
              label: const Text('Copy'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain message block, error-coloured when [isError].
class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.isError = false, super.key});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final Color foreground = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: AppSizes.iconSm,
            color: foreground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
