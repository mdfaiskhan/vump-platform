import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/projects_tasks/application/admin_project_task_notifier.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_create_project_screen.dart';

/// A-05 — Create Task. **The create half only.**
///
/// Chapter 2.5 names the screen *"Create / Edit Task"* and describes it as
/// *"Instructions, reference examples, requirements — mirrors what the
/// Collector will see."*
///
/// ## The edit half is held back, and not because it is hard
///
/// `ProjectTaskAdminRepository.updateTask` exists and works. **Chapter 2.9
/// contradicts itself about what editing a Task must do**, and shipping either
/// reading would encode an answer nobody has given:
///
/// - **§2 principle 4:** *"editing Task instructions after Collectors are
///   already assigned, **always confirms** the action and states its effect in
///   plain language before it takes effect."*
/// - **§4.4:** *"Reversible actions (reassigning a Collector, **editing Task
///   instructions**) **do not require a confirmation dialog** — they save
///   immediately."*
///
/// Same action, named explicitly in both, opposite rules. Open item 90, and it
/// is a product decision rather than something derivable — unlike G3, where
/// the sources disagreed in *emphasis* and one of them specified a mechanism.
/// Here both sentences specify behaviour and they conflict outright.
///
/// ## It renders two of the three things Chapter 2.5 names
///
/// **`requirements` is absent**, for the reason C-06 omits it on the read side
/// (A-110, open item 69): Chapter 4.4 §3's `tasks` table has no such column,
/// and whether it is prose inside `instructions` or a missing column is an
/// unanswered product question. `createTask` takes no such parameter either
/// (5.2.1), so this is the write side of the same gap.
///
/// **Reference examples are absent too, and for a different reason.** They are
/// a real column, and `createTask` accepts them — but entering a list of media
/// URLs needs a repeating field the Design System would specify, and Chapter
/// 2.8 is not in this repository (open item 74). C-06 renders them as
/// unopenable text for the same missing-component reason (open item 80). A
/// Task created here has none; adding them is owed to whichever mission has a
/// component to add them with.
class AdminCreateTaskScreen extends ConsumerStatefulWidget {
  /// Creates the form for a Task inside [projectId].
  const AdminCreateTaskScreen({required this.projectId, super.key});

  /// The owning Project, from the route path.
  final String projectId;

  @override
  ConsumerState<AdminCreateTaskScreen> createState() =>
      _AdminCreateTaskScreenState();
}

class _AdminCreateTaskScreenState extends ConsumerState<AdminCreateTaskScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _instructions = TextEditingController();
  bool _saving = false;
  Failure? _failure;

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
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
        .createTask(
          projectId: widget.projectId,
          title: _title.text.trim(),
          instructions: _instructions.text.trim(),
        );

    if (!mounted) {
      return;
    }
    if (failure == null) {
      context.go('/admin/projects/${widget.projectId}');
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
      title: 'New Task',
      form: _form,
      saving: _saving,
      failure: _failure,
      submitLabel: 'Create Task',
      onSubmit: _submit,
      fields: <Widget>[
        TextFormField(
          controller: _title,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Task title',
            helperText: 'Required.',
          ),
          validator: (String? value) => (value ?? '').trim().isEmpty
              ? 'Enter a title for this Task.'
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _instructions,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Instructions',
            // Chapter 4.4 §3 marks this NOT NULL and C-06 renders it as the
            // Collector's only statement of what to record, so "required" here
            // is a product fact rather than a schema one.
            helperText: 'Required. This is what the Collector will follow.',
          ),
          validator: (String? value) => (value ?? '').trim().isEmpty
              ? 'Enter the instructions the Collector should follow.'
              : null,
        ),
      ],
    );
  }
}
