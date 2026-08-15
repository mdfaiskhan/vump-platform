import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';
import 'package:mobile/features/recording/domain/repositories/task_context.dart';

/// Supplies [MetadataIdentity.unsourced] for both Task fields, and says so.
///
/// **This is a stand-in, and it is named to be impossible to mistake for an
/// implementation.** `project_id` and `task_id` belong to
/// `features/projects_tasks/`, whose `domain/`, `data/` and `application/` are
/// still `.gitkeep`. Amendment A-062 records the gap; A-064 records this.
///
/// ## Why a stand-in exists at all
///
/// The alternative considered and rejected was throwing. It is more honest
/// about the gap and it loses footage: metadata assembly sits in front of
/// `ChunkStore.saveChunk`, so a throw here means no chunk is ever persisted,
/// and the Constitution's *"never lose a take"* outranks the tidiness of
/// refusing to guess. Recording a real walkthrough with two empty identity
/// fields is recoverable — the fields are back-fillable and the footage is
/// not.
///
/// ## Nothing plausible is invented
///
/// The value is the empty string, for the reason
/// `MetadataCaptureConditions` gives about `{0.0, 0.0}`: a wrong value that
/// looks real is harder to catch than an obviously absent one.
/// `ChunkMetadata.isIdentityComplete` reports the consequence, and upload
/// (Chapter 5.10) is the consumer that must check it before composing an S3
/// key from these fields.
class UnsourcedTaskContext implements TaskContext {
  /// Creates the stand-in.
  const UnsourcedTaskContext();

  @override
  String get projectId => MetadataIdentity.unsourced;

  @override
  String get taskId => MetadataIdentity.unsourced;
}
