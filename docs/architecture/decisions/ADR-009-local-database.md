# ADR-009 — Local Database Architecture

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none

## Context

The platform needs structured local persistence: recordings and their metadata, cached remote data, and queued work that must survive an app restart. Secure Storage (ADR-008) is the wrong tool for this — it is a key-value credential store, not a queryable database, and platform credential stores are slow and size-limited by design.

`CLAUDE.md` names Isar in the technology stack, so the engine is settled by the project constitution. What is not settled, and what this record decides, is the shape of the layer around it: who owns the database lifecycle, how features add collections without editing shared code, how schema change is handled over time, and how the engine is kept from leaking into the rest of the application.

The lifecycle question is the pressing one. Isar is opened once per process and returns the same instance thereafter; opening it twice concurrently during startup is a race that surfaces as an intermittent failure rather than a clean error. Without a single owner, the first two features to need the database will each open it.

## Decision

### Isar is the only local database

Structured local persistence goes through Isar and nothing else. No second embedded database is introduced. `SharedPreferences` remains acceptable for non-secret scalar preferences, and Secure Storage remains the only home for secrets per ADR-008.

**No secret is stored in the database.** If the database is ever encrypted, its encryption key lives in Secure Storage under `StorageKey.databaseEncryptionKey`, which ADR-008 already reserves. The inverse arrangement — secrets in an encrypted database whose key sits elsewhere in the database — is forbidden.

### The layer lives in `core/database/`

Per ADR-002, `core/` holds cross-cutting infrastructure. The module is organised as:

```
core/database/
├── database_service.dart        # Lifecycle owner
├── database_config.dart         # Name, directory, versioning, options
├── database_schema_registry.dart# Collection registration
├── interfaces/                  # Contract consumed by outer layers
└── providers/                   # Riverpod exposure
```

Configuration is a separate file from the service, so that what the database *is* can be changed — name, location, inspector setting — without touching the code that opens it.

### `DatabaseService` owns the lifecycle exclusively

It is responsible for opening Isar, closing it, exposing the instance, and guaranteeing a single open.

**Multiple openings are prevented by construction, not by convention.** A concurrent second call to open must await the first rather than start its own — the service holds the in-flight `Future`, not merely a completed instance, because two callers racing during startup is the realistic failure and a null-check on the instance does not prevent it. Opening an already-open database returns the existing instance.

### Isar does not escape the layer

No file outside `core/database/` imports `isar`, exactly as no file outside `core/network/` imports `dio` and no file outside `core/storage/` imports `flutter_secure_storage`. Access is through the service, behind an interface.

This is the rule that makes the engine replaceable. Given the version risk recorded below, that is not a hypothetical benefit.

### Failures convert to `StorageException`

Every Isar error is caught at this boundary and rethrown as `StorageException` from the Mission 0.10 taxonomy, using the storage error codes: `storageUnavailable` when the database cannot be opened, `storageCorrupted` when data cannot be read in the shape it was written, `storageReadFailed` and `storageWriteFailed` for operation failures. No `IsarError` reaches a caller.

### Lifecycle events are logged

The service logs open, close and failure through `AppLogger` (Mission 0.11.2). Database open is on the startup path, so its duration is worth recording. Log the operation and the outcome, never the contents of a record.

### Collections are registered, not hardcoded

Isar requires the full set of schemas at open time. A literal list inside `DatabaseService` would mean every new feature edits the shared service — the coupling this decision exists to prevent.

Instead a **schema registry** owned by `core/database/` collects `CollectionSchema` entries, and the service opens with whatever is registered. A feature contributes its schema at composition time. Adding a collection does not modify `DatabaseService`, `DatabaseConfig`, or any other feature.

### Schema versioning is explicit

Isar migrates additive changes silently — a new collection or a new property appears, absent for existing records. It does **not** handle renames, type changes, or any change requiring data to be rewritten, and it offers no migration hook.

The strategy is therefore explicit and owned by this layer:

1. `DatabaseConfig` declares a `schemaVersion` integer, incremented whenever a change requires data transformation.
2. A metadata collection owned by `core/database/` — infrastructure, not a feature model — records the version last written to disk.
3. On open, the service compares the stored version with the configured one and runs the ordered migration steps between them inside a single write transaction, then records the new version.
4. A stored version *newer* than the configured one means a downgraded application. This fails with `storageCorrupted` rather than attempting to interpret unknown data.

Migration steps are declared as an ordered, append-only list. A shipped step is never edited, for the same reason an accepted ADR is never rewritten: it describes what already ran on real devices.

## Alternatives Considered

- **Drift (SQLite)** — the strongest alternative. Mature, actively maintained, real SQL with real migration tooling, and SQLite is available on every platform. Rejected because `CLAUDE.md` specifies Isar. Worth revisiting if the version risk below materialises; the abstraction in this decision is what would make that affordable.
- **Hive** — rejected. Key-value rather than queryable, weak at relations, and from the same author as Isar, which Isar effectively supersedes.
- **ObjectBox** — rejected. Comparable capability, but a more restrictive licence and no advantage over Isar to justify departing from the stack.
- **`sqflite` directly** — rejected. Hand-written SQL and manual mapping for every entity; Drift is the better form of this choice.
- **`SharedPreferences` for everything** — rejected. Not queryable, not transactional, and unsuited to collections of records.
- **A literal schema list in `DatabaseService`** — rejected. Couples every future feature to a shared file.
- **Relying on Isar's implicit migration alone** — rejected. It silently covers only additive change, so the first rename would corrupt or drop data with no error.

## Consequences

- The database has exactly one owner, and concurrent startup opens cannot race.
- Features add collections without touching shared code.
- Isar is replaceable at the cost of one implementation, because nothing outside the layer imports it.
- **Opening Isar is asynchronous and on the startup path.** Combined with ADR-008's asynchronous secure storage, the application now has two async prerequisites before a session can be resolved. The router needs a loading state; this compounds a constraint ADR-008 already recorded.
- Collections require code generation via `isar_generator` and `build_runner`. A schema change is not complete until generation is rerun, and generated files must be committed or generated in CI.
- Isar's native libraries must be present. Tests touching a real database need `Isar.initializeIsarCore`, and the interface must be substitutable by a fake for tests that do not.
- **Version risk, and it is material.** The resolvable version is `isar 3.1.0+1`, published in 2023 and not meaningfully maintained since; Isar 4 has remained pre-release. Two specific concerns must be verified before this decision is implemented:
  - **Android 16 KB page size support.** Google Play requires it for applications targeting recent Android versions. Isar 3.1.0's prebuilt native libraries predate that requirement, and failure here blocks release rather than degrading gracefully.
  - **Compatibility with Flutter 3.44 and Dart 3.12**, including the Android Gradle and NDK toolchain, given the gap between the package's release and the current SDK.

  If either fails, the engine choice must be revisited — which contradicts `CLAUDE.md` and would require both a new ADR and an amendment to the constitution. The abstraction decided above is what keeps that cost bounded.
- Web support is limited compared to the mobile targets and must not be assumed.

## Related Missions

- Mission 0.6.1 — Dependency Management, which did **not** add Isar despite `CLAUDE.md` naming it.
- Mission 0.10 — Error Architecture, which defined the `StorageException` and storage codes this layer maps onto.
- Mission 0.11.2 — Core Logging Infrastructure, which supplies the logger.
- Mission 0.13 — Secure Storage, which owns secrets and reserves the database encryption key.
- Mission 0.14 — Isar Local Database Foundation, which produced this ADR.

## Implementation Status

**Implemented** as of Mission 0.14 (continuation), with two caveats recorded below.

`isar 3.1.0+1`, `isar_flutter_libs 3.1.0+1` and `isar_generator 3.1.0+1` are declared and resolved. `mobile/lib/core/database/` contains the configuration, constants, lifecycle service, migration runner and interface, the core metadata collection, and the Riverpod providers. Code generation runs successfully. No file outside the layer imports `isar`.

### Caveat 1 — the toolchain is pinned by `isar_generator`

`isar_generator 3.1.0+1` requires `analyzer >=4.6.0 <6.0.0` and `dart_style ^2.2.3`. `freezed ^2.5.7` requires `analyzer ^6.5.0`. The two cannot coexist, so **`freezed` was downgraded to `^2.5.2`** to resolve.

The whole code-generation toolchain is therefore held at a 2023-era `analyzer`. Generation was verified to run correctly against the current Dart 3.12 sources, so this is not a present defect — but every future codegen dependency must fit inside the same constraint, and it will get harder. `flutter analyze` is unaffected: it uses the SDK's own analysis server, not the `analyzer` package.

### Caveat 2 — the directory is not yet supplied

`databaseDirectoryProvider` throws `UnimplementedError` until overridden. Resolving a writable application directory needs a platform plugin (`path_provider`) that was outside the mission's dependency scope, so the path is supplied by the composition root. **The database cannot open until that override is wired**, which requires editing `main.dart`.

### Still unverified

The **Android 16 KB page size** question recorded under Consequences remains open. Nothing in this implementation addresses it, and it is a release-blocking risk rather than a development one.
