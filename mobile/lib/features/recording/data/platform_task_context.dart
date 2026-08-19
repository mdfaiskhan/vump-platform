import 'package:mobile/core/identity/interfaces/task_context.dart';
import 'package:mobile/core/identity/selected_task.dart';
import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';

/// Supplies Chapter 4.5 §2's `project_id` and `task_id` from the Collector's
/// selection — Mission 7.4, F38.
///
/// Replaces `UnsourcedTaskContext`, which returned the empty string for both
/// because `features/projects_tasks/` was unbuilt and there was no Task to
/// name. There is now.
///
/// ## The composition root resolves it, for ADR-022 R3's reason
///
/// The value originates in `features/projects_tasks/` and is consumed here, and
/// R3 forbids the import in either direction. `selectedTaskProvider` in `core/`
/// is the neutral ground; `main.dart` reads it and passes the result in. Same
/// arrangement as `collectorId` on `PlatformDeviceContext`, and for the same
/// rule.
///
/// ## An absent selection stays absent
///
/// `PlatformTaskContext.unsourced` is what a null selection produces, and it is
/// `MetadataIdentity.unsourced` for both fields — the same empty string
/// `UnsourcedTaskContext` returned, reaching A-068's Guard 1, which refuses the
/// chunk. Recording without having chosen a Task is therefore stopped at
/// upload rather than uploaded unattributed.
///
/// Substituting anything else — a placeholder Task, the last one selected —
/// would produce a chunk that is attributed and **wrong**, which is worse than
/// one that is refused. `MetadataCaptureConditions` makes the same argument
/// about `{0.0, 0.0}`: a plausible wrong value is harder to catch than an
/// obviously absent one.
class PlatformTaskContext implements TaskContext {
  /// Creates a context over the Collector's current selection.
  const PlatformTaskContext({required SelectedTask this._selection});

  /// A context for a session with no Task chosen.
  const PlatformTaskContext.unsourced() : _selection = null;

  final SelectedTask? _selection;

  @override
  String get projectId => _selection?.projectId ?? MetadataIdentity.unsourced;

  @override
  String get taskId => _selection?.taskId ?? MetadataIdentity.unsourced;
}
