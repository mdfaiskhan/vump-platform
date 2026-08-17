# ADR-039 — Feature-Owned Isar Collections

- **Status:** Accepted
- **Date:** 2026-08-15
- **Supersedes:** ADR-009 — Local Database Architecture, on two points only. Every other decision in ADR-009 is carried forward unchanged.

## Context

ADR-009 §"Isar does not escape the layer" states:

> No file outside `core/database/` imports `isar`, exactly as no file outside `core/network/` imports `dio` and no file outside `core/storage/` imports `flutter_secure_storage`. Access is through the service, behind an interface.

`.github/workflows/ci.yml`'s `Architecture boundaries` job enforces it: `check isar lib/core/database/`.

Mission 3.7 implements Volume 5 Chapter 5.8's three local tables. An Isar collection is a class annotated `@collection` whose file must import `package:isar/isar.dart` and carry a generated `part`. **There is no way to declare one without importing the package.** So the tables can live in `core/database/` and satisfy the rule, or in `features/recording/data/` and break it. There is no third arrangement.

### The rule is right, and its stated scope is too narrow

The confinement rule exists to keep a layer replaceable, and given ADR-009's own recorded version risk — `isar 3.1.0+1`, unmaintained since 2023, Isar 4 permanently pre-release, the open Android 16 KB page-size question — replaceability here is not hypothetical.

But that argument is about the **engine**, and a collection is not the engine. ADR-009 already draws this distinction itself, describing its metadata collection as *"a metadata collection owned by `core/database/` — **infrastructure, not a feature model**"*. The clause presumes feature models exist and are somebody else's; it just never says where they go, because when ADR-009 was written `lib/features/` was empty and no feature model existed to place.

The same distinction is already settled elsewhere in this codebase, in the same CI job, in a comment:

> The last two are owned by a feature rather than by `core/`. ADR-010 keeps the Firebase **platform** in `core/firebase/`; a Firebase **product** belongs to the module that consumes it, which is what makes `features/auth/` the replaceable unit rather than `core/`.

Platform in `core/`, product in the feature. Engine in `core/`, collections in the feature. It is one rule applied twice.

### What the alternative actually costs

Putting `LocalSession`, `LocalChunk` and `LocalChunkMetadata` in `core/database/collections/` would satisfy ADR-009 verbatim and require no ADR at all. It is rejected because:

- It puts the recording feature's data model inside the engine's module, contradicting `DatabaseMetadata`'s own *"infrastructure, not a feature model"* line.
- It makes `core/` the unit that changes when a feature's schema changes, which is the coupling ADR-009's own §"Collections are registered, not hardcoded" exists to prevent — that section removed the coupling from `DatabaseService` and this would reintroduce it one directory over.
- It fails again for every future feature. Upload, projects/tasks and settings will each need collections.

## Decision

### 1. `isar` is confined to `core/database/` **and** to any feature's `data/collections/`

The engine, its lifecycle, its configuration, its migrations and its own infrastructure collections stay in `core/database/`, exclusively. Nothing about `DatabaseService` changes.

A feature may import `isar` in exactly two places:

1. `lib/features/<feature>/data/collections/` — where collections are declared.
2. `lib/features/<feature>/data/<package>_*.dart` — the engine-named implementation at the feature's `data/` root.

Nowhere else. Not elsewhere in `data/`, not in `domain/`, not in `application/` or `presentation/`.

**The second permission was missed in this ADR's first draft, and CI caught it.** The draft said collections and *"only there, not elsewhere in `data/`"*, which is wrong for a reason that should have been obvious: a collection is a declaration, and something has to actually open a transaction over it. `IsarChunkStore` holds the `Isar` instance and calls `writeTxn`; it cannot do that without the import, and it is not a collection, so it belongs at the `data/` root rather than inside `collections/`. Moving it into `collections/` to satisfy the narrower rule would also have subjected it to ADR-038's two directory-scoped analysis relaxations, which exist for generated output and have no business covering hand-written code.

**The naming prefix is the rule, not an accident.** ADR-023's conventions already produce it and this feature already follows it twice — `shared_preferences_wide_angle_eligibility_cache.dart` and `camera_recording_pipeline.dart`. An implementation that binds to a package is named for that package, so the file that may import `isar` announces it in its own filename. That makes the permission greppable and self-declaring instead of a directory anyone can drop a file into.

CI's confinement check becomes:

```
check isar  'lib/core/database/|lib/features/[^/]+/data/collections/|lib/features/[^/]+/data/isar_[^/]*\.dart'
```

The `check` helper's owner argument changes from a literal prefix to an extended regex to allow it. Every other package keeps a single-prefix owner, and those prefixes are valid regexes unchanged. `firebase_core` and `firebase_auth` will want the same shape eventually.

**The engine stays replaceable, which is the property the original rule protected.** Replacing Isar would mean rewriting these three collection files and their mappers. It would not mean touching any `domain/`, `application/` or `presentation/` file, because none of them can see an Isar type: `ChunkStore` is a domain port, `IsarChunkStore` implements it, and `ChunkRecordMapper` is the single conversion boundary ADR-030 requires. That is the same guarantee ADR-009 wanted, delivered by inversion rather than by directory.

### 2. Collections are contributed at the composition root, never by editing `core/`

ADR-009's §"Collections are registered, not hardcoded" already decided this and is carried forward unchanged. This ADR only states where a feature's contribution lives: a `RecordingSchemas.all`-style constant beside the collections, passed to `DatabaseConfig.schemas` alongside `coreSchemas` at composition time.

`core/database/` therefore has **no import of, and no knowledge of, any feature collection**. The dependency runs one way only, which is what keeps the engine module free of feature models.

### 3. `local_task_cache` belongs to `features/projects_tasks/`

Volume 5 Chapter 5.8 §1 lists four local tables. This mission implements three. The fourth mirrors `tasks` and `task_assignments` and exists so C-03–C-06 render offline — screens owned by `features/projects_tasks/`, which is unbuilt.

Assigning it here, in advance, prevents the obvious wrong answer later: adding it to `features/recording/` because that is where the other three already are. One feature's read cache inside another feature's data layer is the cross-feature coupling ADR-022 R3 forbids *"at any layer, in either direction"*.

**It is assigned, not implemented.** When `features/projects_tasks/data/collections/` exists, the table goes there and contributes its schema the same way.

### 4. Nothing else in ADR-009 changes

Isar as the only local database; no secret in the database; `core/database/`'s structure; `DatabaseService`'s exclusive lifecycle ownership and single-open guarantee; conversion of every Isar error to `StorageException`; lifecycle logging; explicit schema versioning with an append-only migration list; both recorded caveats and the unresolved 16 KB page-size risk — all carried forward, all binding.

## Alternatives Considered

- **Put the collections in `core/database/collections/`.** Rejected, for the three reasons under Context. It is the cheapest option today and the most expensive one by the third feature.

- **Leave ADR-009 unamended and grant an exception in CI.** Rejected. A confinement rule with an undocumented exception is worse than either a rule or no rule: the next reader cannot tell whether the exception is a decision or a lapse. Where code and an accepted ADR disagree, `CLAUDE.md` says the ADR is right and the code is a defect — so the code is a defect until this is approved, which is why it is stated plainly above.

- **Edit ADR-009 in place to widen the clause.** Forbidden by governance, and the same instrument ADR-038 used for ADR-021 applies here: an Accepted ADR is corrected by a superseding decision, not by rewriting. The original scope and the reason it changed both stay legible.

- **Permit `isar` anywhere under `lib/features/*/data/`.** Rejected as too wide. Collections and the store that opens transactions over them need the import; a mapper does not — `ChunkRecordMapper` imports the collection types and never `isar` itself. Permitting the whole directory would let Isar types spread until replacing the engine means rewriting all of it. The two-place rule above is the smallest permission that lets the code compile.

- **Move `IsarChunkStore` into `data/collections/` so one directory suffices.** Rejected, and it was the first draft's implicit position. It is not a collection, and that directory carries ADR-038's two analysis relaxations — `public_member_api_docs` off, `experimental_member_use` ignored — which exist for generated output. Hand-written code silently inheriting them is exactly the drift ADR-038 scoped them narrowly to avoid.

- **Define collections in `core/` but generate them per feature.** Rejected. It is the first alternative with extra machinery, and the ownership problem is unchanged.

## Consequences

- **A feature owns its own schema**, so a schema change touches one feature and nothing shared.
- **`isar` is permitted in two further, narrowly-scoped locations**, and the CI check now takes a regex owner rather than a literal prefix to express it.
- **A file's name is now load-bearing.** `data/isar_*.dart` is a permission, so renaming the store removes its right to import the package and the confinement job fails. That is the intent — the permission should be visible in the file listing — but it is a coupling worth knowing about before renaming.
- **Replacing Isar now means editing files in more than one module.** Bounded and countable: three collections, eight embedded types, one mapper and one store, all under `features/recording/data/`. No layer above `data/` can name an Isar type.
- **Every feature that adds collections must also add its schema list to the composition root.** A collection that is declared but never registered fails at open time with a schema error, not silently.
- **`local_task_cache` has an owner before it has an implementation**, which is the point of recording it.
- **ADR-009's version risk is unchanged and still open.** ADR-038 sharpened it: the project now depends on an `@experimental` API from an unmaintained package for a real uniqueness guarantee. Revisiting the engine under this ADR's §1 is the decision that would close both.

## Related Missions

- Mission 0.14 — Isar Local Database Foundation, which produced ADR-009 and the confinement rule.
- Mission 3.7 — Local Storage & File Naming, which placed the first feature-owned collections and surfaced the conflict.
- ADR-038 — the parallel correction to ADR-021, caused by the same placement.

## Implementation Status

| Item | State |
|---|---|
| ADR-009 | **Superseded** by this record. Header marked; body untouched, including the clause this widens. |
| `.github/workflows/ci.yml` | Updated — `check` takes a regex owner; `isar` owns `core/database/`, `features/*/data/collections/` and `features/*/data/isar_*.dart`. |
| The `Architecture boundaries` job | **Passes.** Verified locally against the same file set: eleven packages, zero violations. |
| `lib/features/recording/data/collections/` | Three collections, eight embedded types, `RecordingSchemas.all`. |
| `lib/features/recording/data/isar_chunk_store.dart` | The one engine-named implementation permitted at the `data/` root. |
| Any Isar type above `data/` | **None.** `ChunkStore` is a domain port; `ChunkRecordMapper` imports collection types, never `isar`. |
| `local_task_cache` | Not implemented, assigned to `features/projects_tasks/`. |

**One correction was made between drafting and acceptance**, recorded because the near-miss is the useful part: §1 originally permitted `data/collections/` alone, which the confinement check immediately failed on `isar_chunk_store.dart`. The draft had reasoned about where collections are *declared* and forgotten that something must *open a transaction* over them. The check found it in one run — which is the argument for widening the rule in CI rather than granting an undocumented exception.
