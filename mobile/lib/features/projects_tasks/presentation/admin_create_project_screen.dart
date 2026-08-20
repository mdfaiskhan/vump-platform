import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/projects_tasks/application/admin_project_task_notifier.dart';
import 'package:mobile/features/projects_tasks/application/write_failure.dart';

/// A-04 — Create Project. **The create half only.**
///
/// Chapter 2.5 names the screen *"Create / Edit Project"* and describes it as
/// *"Name, description, and Project-level settings."* Two of those three are
/// built and the third does not exist.
///
/// ## There is no edit affordance, and that is deliberate
///
/// Editing a Project has **no route and no requirement**: Chapter 4.6 §3 has
/// no `PATCH /v1/projects/{id}`, and Chapter 1.3's FR-ADM-01 is *"create a new
/// Project"* with no edit counterpart anywhere in FR-ADM (open item 87). Only
/// MVP §2.2 and this screen's own name assume one.
///
/// A greyed-out Edit button would imply a capability that is temporarily off.
/// Nothing is off — nothing exists. **This follows Mission 5.1.5's C-12
/// decision**: a half-thing that looks finished is worse than an honest
/// absence, and the register carries the gap instead.
///
/// ## "Project-level settings" is not rendered, because it is not anything
///
/// The phrase appears **exactly once in all of Volume 2** — in Chapter 2.5's
/// A-04 row. Nothing defines it, `projects` has no such column (Chapter 4.4
/// §2), and `POST /v1/projects` carries no such field. So there is no settings
/// section and no empty placeholder implying one is coming — the same
/// treatment C-06 gave FR-PT-05's `requirements` (A-110). Open item 91.
///
/// ## Validation is inline, per-field and announced
///
/// Chapter 2.9 §2 principle 1: *"name the specific cause and the specific fix.
/// A generic 'Something went wrong' is treated as a defect."* Chapter 2.10 §4:
/// every error state is *"**announced when it appears** — not just shown
/// visually."* `TextFormField`'s `errorText` satisfies both — Flutter's
/// semantics attach it to the field, so a screen reader reads the label and
/// the error together rather than either alone.
///
/// The check runs **before** the repository call, so a blank name never
/// reaches it. `FakeProjectTaskAdminRepository`'s own rejection stays as the
/// backstop it is.
class AdminCreateProjectScreen extends ConsumerStatefulWidget {
  /// Creates the form.
  const AdminCreateProjectScreen({super.key});

  @override
  ConsumerState<AdminCreateProjectScreen> createState() =>
      _AdminCreateProjectScreenState();
}

class _AdminCreateProjectScreenState
    extends ConsumerState<AdminCreateProjectScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  bool _saving = false;
  Failure? _failure;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });

    final Failure? failure = await ref
        .read(adminProjectTaskProvider.notifier)
        .createProject(
          name: _name.text.trim(),
          // An empty description is *no description*, not a blank one.
          // Chapter 4.4 §2 makes the column nullable precisely so the two are
          // distinguishable, and a stored "" would render as an empty line on
          // C-04 rather than as absence.
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        );

    if (!mounted) {
      return;
    }
    if (failure == null) {
      // Return to the list that launched this. Chapter 2.9 §2 principle 2
      // wants an unambiguous confirmation the action registered, and seeing
      // the new Project in the list is a stronger one than a toast — the
      // shared store makes it visible immediately (A-117).
      context.go('/admin/projects');
      return;
    }
    setState(() {
      _saving = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminCreateScaffold(
      title: 'New Project',
      form: _form,
      saving: _saving,
      failure: _failure,
      submitLabel: 'Create Project',
      onSubmit: _submit,
      fields: <Widget>[
        TextFormField(
          controller: _name,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Project name',
            // Chapter 4.4 §2 marks the column NOT NULL. Saying so up front
            // beats saying it after a failed submit.
            helperText: 'Required.',
          ),
          validator: (String? value) => (value ?? '').trim().isEmpty
              ? 'Enter a name for this Project.'
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description',
            helperText: 'Optional.',
          ),
        ),
      ],
    );
  }
}

/// The shape A-04 and A-05 share.
///
/// Chapter 2.7 §5 calls both *"standard forms using the field component
/// (Design System §7), including its built-in error state"*, and Chapter 2.4
/// §3 presents both as modals. They differ only in their fields, their title
/// and which repository method they call — so the chrome lives in one place
/// rather than being copied and drifting.
///
/// It is **local to this feature**, not promoted: ADR-022 R5 admits nothing to
/// `shared/` without a second consumer outside the feature, and both consumers
/// are here (A-106 took the same decision for C-01's dot row).
class AdminCreateScaffold extends StatelessWidget {
  /// Creates the shared form chrome.
  const AdminCreateScaffold({
    required this.title,
    required this.form,
    required this.saving,
    required this.failure,
    required this.submitLabel,
    required this.onSubmit,
    required this.fields,
    super.key,
  });

  /// Shown in the app bar.
  final String title;

  /// The form being validated.
  final GlobalKey<FormState> form;

  /// Whether a write is in flight.
  final bool saving;

  /// The last write failure, or null.
  final Failure? failure;

  /// The primary button's label.
  final String submitLabel;

  /// Runs the write.
  final Future<void> Function() onSubmit;

  /// The form's fields, in order.
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final Failure? failure = this.failure;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // A modal must be dismissible without completing (Chapter 2.4 §3), and
        // the close affordance is explicit rather than relying on a back
        // gesture that a modal route may not offer.
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: saving ? null : () => context.pop(),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              ...fields,
              if (failure != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _WriteFailure(failure: failure),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: AppSizes.buttonHeightLg,
                child: FilledButton(
                  onPressed: saving ? null : onSubmit,
                  child: Text(saving ? 'Saving…' : submitLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A write that failed after validation passed.
///
/// Distinct from a field error: the fields are fine and the save did not
/// happen. Chapter 2.9 §4.3 requires *"a plain-language cause with a single,
/// specific recovery action — never an error with no action attached"*.
///
/// **The cause comes from the code, never from the message** — see
/// `ProjectTaskWriteFailure`. This rendered `failure.message` until Mission
/// 7.8, which put a backend diagnostic on screen for anything the envelope
/// named, including *"AUTH_FORBIDDEN — Not permitted: this endpoint requires
/// the admin role."*
///
/// The two cases need different recovery actions, which is the whole reason
/// for distinguishing them: one can be retried and the other cannot.
class _WriteFailure extends StatelessWidget {
  const _WriteFailure({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              switch (classifyWriteFailure(failure)) {
                ProjectTaskWriteFailure.notPermitted =>
                  "You don't have permission to do this.",
                ProjectTaskWriteFailure.unavailable =>
                  "This couldn't be saved.",
              },
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              switch (classifyWriteFailure(failure)) {
                // No "try again": retrying is precisely what will not work, and
                // Chapter 2.9 §4.3 asks for the recovery action that exists
                // rather than the one that reads well.
                ProjectTaskWriteFailure.notPermitted =>
                  'Ask your organisation admin to check your role, then sign '
                      'in again.',
                ProjectTaskWriteFailure.unavailable =>
                  'Check your connection and try again.',
              },
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
