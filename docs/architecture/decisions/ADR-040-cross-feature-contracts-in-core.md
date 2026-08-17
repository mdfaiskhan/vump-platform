# ADR-040 — Cross-Feature Contracts in `core/`

- **Status:** Accepted
- **Date:** 2026-08-15
- **Supersedes:** none. Extends ADR-022 R3's resolution set and reuses ADR-035's inversion at a wider scope.

## Context

Volume 5 Chapter 5.9's Upload Queue is *"a live view … over `local_chunks.status`"*. Those rows are written by `features/recording/` at chunk finalization and read by `features/upload/`, which owns Chapter 2.7's C-11 screen.

ADR-022 R3 forbids exactly that: no cross-feature imports, *"at any layer, in either direction"*. So the queue could not simply import the recording feature's store, and the recording feature could not import an interface owned by upload either — the prohibition is symmetric.

`shared/` does not exist, and ADR-022 R5 admits nothing to it without a second consumer.

### Why ADR-035 is the right shape but not the right instance

ADR-035 solved a similar problem: `AuthInterceptor` in `core/network/` needed a token owned by `features/auth/`. Its resolution was to have `core/network/` declare `AuthTokenSource` and let the feature implement it — ADR-001's dependency inversion applied sideways, with the composition root introducing the two.

**That precedent is `core/` ↔ one feature.** One party already lived in `core/`, so `core/` declaring the contract was natural: it was stating its own requirement.

**This case is feature ↔ feature.** Neither party is `core/`. Nothing in `core/` wants these rows; `core/` is being asked to hold a contract between two modules that must not know about each other. That is a different shape, and it needs its own record — someone hitting this fork will search for "how do two features share data", and ADR-035's title is about authenticated requests.

### Why this is not a cross-reference on ADR-039

ADR-039 settled where Isar *collections* live: the engine in `core/database/`, the collections in the feature that owns them. This decision is about a *contract* between features and happens to involve those collections only incidentally — the same problem would arise for any two features sharing any data.

ADR-039's Related Missions section is a pointer list. Burying a reusable pattern there means the next person facing this fork finds it only if they already know to look under an ADR about Isar collections, which is precisely the discovery path that fails. A pattern needs a home, not a footnote.

## Decision

### A contract shared by two features lives in `core/`, and names neither of them

`core/queue/` holds:

- `chunk_upload_status.dart` — `ChunkUploadStatus`, Chapter 5.9 §1's four states
- `queued_chunk.dart` — `QueuedChunk`, the read model
- `interfaces/chunk_queue_source.dart` — `ChunkQueueSource`, the contract

`features/recording/data/`'s `IsarChunkStore` implements `ChunkQueueSource` alongside its existing `ChunkStore`. `features/upload/` depends only on the `core/` contract. The composition root binds one instance behind both.

Neither feature imports the other. Both import `core/`, which ADR-022 already permits.

### The contract carries a projection, not either feature's model

`QueuedChunk` is deliberately not `LocalChunk`. It carries what Chapter 5.9 §2's ordering and C-11's rendering need — chunk id, session id, sequence index, session start time, status, byte count — and nothing else. No file path, no checksum, no database type.

**This is the part that makes the decoupling real rather than nominal.** A contract that passed the storage type through would relocate the coupling into `core/` instead of removing it: `features/upload/` would still be reading the recording feature's schema, just via a longer path. Each side can now change its storage or its presentation without the other noticing.

### A new `core/` module, not `core/database/`

The contract could have gone in `core/database/interfaces/`. It did not, because ADR-039 decided three commits earlier that feature models do not belong in the engine's module, and putting chunk-shaped types there would undercut that immediately.

`core/queue/` says what it is: a published contract, not the database growing opinions about chunks. Its shape follows `core/errors/` — value types at the module root, a subfolder for the interface family.

### Enforced in CI, not only written down

`.github/workflows/ci.yml`'s `Architecture boundaries` job now checks:

1. **Every ordered pair of features** — `features/<a>/` must not import `features/<b>/`, for all a ≠ b. ADR-022 itself records R3 as *"binding in writing and unenforced in fact"* because with zero features the check was vacuous. It is not vacuous now.
2. **`core/queue/` names no feature.** I41 already forbids `core/` importing `features/` generally; this is the narrower, louder check for the one module whose entire purpose is to sit between two features. A contract that imported either side would stop being neutral ground and become a third party both features are coupled through — worse than the import it replaced.

Both were **verified by deliberately breaking them**: an injected import in `features/upload/` and another in `core/queue/` each produced a failing check, and removing them restored a pass. A rule stated only in a document is what let S1 sit undetected for two missions (A-067).

## Alternatives Considered

- **Put the queue in `features/recording/`.** No new contract, no new module, R3 satisfied trivially. Rejected: Volume 3 Chapter 3.5 §2 assigns the sessions root to `upload`, which already owns C-11's screens. The queue would then live in one feature while the only screen rendering it lived in another — the same coupling, moved and made less visible.

- **Move the collections to `core/database/` or `shared/`.** Rejected. It reopens ADR-039 immediately after it was decided, and it makes `core/` the owner of a feature's schema, which is the thing ADR-039 argued against at length.

- **Declare the port in `features/upload/domain/` and have `IsarChunkStore` implement it.** This is the reflex, and it does not work: `features/recording/data/` would then import `features/upload/domain/`. R3 is symmetric, so inverting the direction does not escape it.

- **A cross-reference note on ADR-039 instead of this ADR.** Rejected for the discovery reason under Context. Also a category error: ADR-039 is about collection ownership, this is about inter-feature contracts.

- **Pass `LocalChunk` through the contract.** Rejected. It would satisfy the import checker while leaving `features/upload/` coupled to the recording feature's schema — compliance without the property the rule exists to protect.

## Consequences

- **Two features share data with no import between them**, and CI proves it for every pair rather than for the one pair this mission created.
- **A third module now participates in the relationship.** `core/queue/` must stay free of feature types or it becomes the coupling it was built to remove. That is why it has its own check rather than relying on I41.
- **The projection must be maintained.** A field C-11 later needs — a failure cause, an attempt count — has to be added to `QueuedChunk` deliberately, not picked up for free by widening a passthrough. That friction is the point.
- **`ChunkUploadStatus.queued` and `ChunkRecordMapper.statusQueued` are two constants holding one string.** Mission 3's constant was left untouched because it sits in the verified capture path; a test pins the two equal so a rename in either fails the build rather than orphaning stored rows.
- **This pattern will recur.** Upload↔metadata, projects_tasks↔recording. The shape is now established: contract in `core/`, projection not model, CI check per pair.
- **ADR-022 R3 is enforced for the first time.** Previously binding in writing only.

## Related Missions

- Mission 4.1 — Upload Queue, which produced this decision.
- ADR-035 — the `core/` ↔ one-feature inversion this widens.
- ADR-039 — collection ownership, and the reason this did not go in `core/database/`.
- A-067 — the confinement gap that argued for enforcing rules in CI rather than in prose.

## Implementation Status

| Item | State |
|---|---|
| `core/queue/` — status, projection, contract | Written |
| `IsarChunkStore implements ChunkStore, ChunkQueueSource` | Additive; capture path untouched |
| `features/upload/application/upload_queue_notifier.dart` | Written — `StreamNotifier` per Chapter 3.9 |
| Composition root binds one instance behind both | `main.dart` |
| CI: every feature pair | Verified against a deliberately broken import |
| CI: `core/queue/` names no feature | Verified against a deliberately broken import |
| Tests | 29 covering ordering, retry position, all four states, grouping |
