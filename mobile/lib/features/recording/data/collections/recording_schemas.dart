import 'package:isar/isar.dart';

import 'package:mobile/features/recording/data/collections/local_chunk.dart';
import 'package:mobile/features/recording/data/collections/local_chunk_metadata.dart';
import 'package:mobile/features/recording/data/collections/local_session.dart';

/// The Isar collections this feature owns.
///
/// `DatabaseConfig.schemas` already accepts a list and defaults to
/// `coreSchemas`, whose own documentation calls those *"Schemas owned by
/// `core/database/` itself"*. So a feature contributes its collections at the
/// composition root rather than by editing `core/database/` — which is what
/// keeps the engine's module free of feature models.
///
/// Volume 5 Chapter 5.8 §1 lists a fourth table, `local_task_cache`, which is
/// deliberately absent: it mirrors `tasks` and `task_assignments`, so it
/// belongs to `features/projects_tasks/`. Assigned there by ADR-039, which is
/// Proposed rather than approved.
abstract final class RecordingSchemas {
  /// Passed to `DatabaseConfig` with `coreSchemas` at the composition root.
  static const List<CollectionSchema<dynamic>> all =
      <CollectionSchema<dynamic>>[
        LocalSessionSchema,
        LocalChunkSchema,
        LocalChunkMetadataSchema,
      ];
}
