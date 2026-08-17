/// The seams where Chapter 5.10's pipeline is introduced to its collaborators.
///
/// All three throw until overridden, for the reason `authTokenSourceProvider`
/// and `databaseDirectoryProvider` already established: failing loudly at the
/// override point is easier to diagnose than any default. A silent default
/// here would be worse than a misplaced file — it would present as a backend
/// fault rather than as unwired configuration.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/upload/interfaces/chunk_metadata_source.dart';
import 'package:mobile/core/upload/interfaces/chunk_upload_source.dart';
import 'package:mobile/core/upload/interfaces/session_registrar.dart';

/// Where claimed chunks and their status transitions come from.
///
/// Overridden in `main.dart` to the single `IsarChunkStore`, which also backs
/// `chunkStoreProvider` and `chunkQueueSourceProvider` — one instance behind
/// four contracts, so the pipeline moves exactly the rows the finalizer wrote
/// and C-11 renders.
final Provider<ChunkUploadSource> chunkUploadSourceProvider =
    Provider<ChunkUploadSource>(
      (Ref ref) => throw UnimplementedError(
        'chunkUploadSourceProvider must be overridden before the upload '
        'pipeline runs. features/recording/data/IsarChunkStore implements it; '
        'see ADR-040.',
      ),
    );

/// Where Chapter 5.10 §1 step 4's metadata document comes from.
final Provider<ChunkMetadataSource> chunkMetadataSourceProvider =
    Provider<ChunkMetadataSource>(
      (Ref ref) => throw UnimplementedError(
        'chunkMetadataSourceProvider must be overridden before the upload '
        'pipeline runs. features/recording/data/IsarChunkStore implements it; '
        'see ADR-040.',
      ),
    );

/// Where the backend session id in Chapter 5.10 §1 step 1's URL comes from.
///
/// **Unlike the other two, nothing in `lib/` overrides this yet.** No
/// implementation exists, because it needs a Task and
/// `features/projects_tasks/` is unbuilt — `SessionRegistrar`'s doc has the
/// full argument. A fake satisfies it in the test suite; binding one in a
/// build would be the defect Volume 11's M12 gate names.
///
/// So the pipeline throws here today rather than uploading anything. That is
/// the honest state of the feature, and it is visible at the seam rather than
/// buried in a runtime failure downstream.
final Provider<SessionRegistrar> sessionRegistrarProvider =
    Provider<SessionRegistrar>(
      (Ref ref) => throw UnimplementedError(
        'sessionRegistrarProvider has no implementation yet. It needs a '
        'task_id, which features/projects_tasks/ owns and which is unbuilt. '
        'See SessionRegistrar and open item 1.',
      ),
    );
