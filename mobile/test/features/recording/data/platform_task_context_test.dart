import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/identity/selected_task.dart';
import 'package:mobile/features/recording/data/platform_task_context.dart';
import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';

/// The Task half of Chapter 4.5 §2's identity group — F38.
void main() {
  test('a selection supplies both ids', () {
    const PlatformTaskContext context = PlatformTaskContext(
      selection: SelectedTask(projectId: 'prj-1', taskId: 'tsk-1'),
    );

    expect(context.projectId, 'prj-1');
    expect(context.taskId, 'tsk-1');
  });

  test('no selection is unsourced, not a substitute', () {
    // A recording started without choosing a Task must be REFUSED at upload by
    // A-068's Guard 1, not attributed to a guess. A plausible wrong Task is
    // worse than an obviously absent one: the chunk uploads, and it uploads
    // against somebody else's work.
    const PlatformTaskContext context = PlatformTaskContext.unsourced();

    expect(context.projectId, MetadataIdentity.unsourced);
    expect(context.taskId, MetadataIdentity.unsourced);
  });
}
