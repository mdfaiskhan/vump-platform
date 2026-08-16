/// The seam where Chapter 5.9's queue rows are introduced to their readers.
///
/// Unimplemented rather than defaulted, for the reason every other port in
/// this project follows: a default would have to name a concrete class living
/// in a feature's `data/`, which `core/` may not import at all (invariant
/// I41). Failing loudly at the override point beats a silent default that
/// would present an unwired queue as an empty one.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/queue/interfaces/chunk_queue_source.dart';

/// Where Chapter 5.9's queue rows come from.
///
/// Overridden in `main.dart` to the single `IsarChunkStore`, which also backs
/// `chunkStoreProvider`, `chunkUploadSourceProvider` and
/// `chunkMetadataSourceProvider` — one instance behind four contracts, so
/// every reader sees the same rows.
///
/// ## Why this lives in `core/queue/` and not in a feature
///
/// It was declared in `features/upload/application/` at Mission 4.1, when
/// `features/upload/` was the only reader and the placement was invisible.
/// **It stopped being invisible when a second feature needed the queue.**
///
/// Chapter 2.7's C-03 Home Dashboard belongs to `features/projects_tasks/`
/// and FR-PT-02 requires it to show pending, uploading and completed chunk
/// counts — the same rows C-11 renders. Reading them through a provider
/// declared in `features/upload/` would be the cross-feature import ADR-022 R3
/// forbids *"at any layer, in either direction"*, so the provider moved to the
/// neutral ground its contract already occupied.
///
/// This is what `core/upload/providers/upload_ports.dart` and
/// `core/connectivity/providers/connectivity_ports.dart` already do for their
/// own contracts. `core/queue/` was the one ADR-040 contract module whose
/// provider still lived inside a consumer, and nothing had forced the
/// question until now.
///
/// **A second provider was not declared alongside the first.** Two providers
/// over one contract means two override sites and, the first time one is
/// missed, two different answers to "what is in the queue" — the
/// two-sources-of-truth failure ADR-018 exists to prevent. There is one
/// provider and it moved.
final Provider<ChunkQueueSource> chunkQueueSourceProvider =
    Provider<ChunkQueueSource>(
      (Ref ref) => throw UnimplementedError(
        'chunkQueueSourceProvider must be overridden with a ChunkQueueSource. '
        'features/recording/data/ provides IsarChunkStore, which implements '
        'it. See ADR-040.',
      ),
    );
