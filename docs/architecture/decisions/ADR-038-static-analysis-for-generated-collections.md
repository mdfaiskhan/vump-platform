# ADR-038 — Static Analysis Configuration for Generated Collections

- **Status:** Accepted
- **Date:** 2026-08-15
- **Supersedes:** ADR-021 — Static Analysis Configuration. Every decision in ADR-021 is carried forward unchanged except the one section named below.

## Context

ADR-021 §"Generated code is analysed, not excluded" rests on a claim of fact:

> This is workable because `isar_generator` emits its own `ignore_for_file` header covering the rules its output trips. Verified: the committed generated files produce zero issues under this configuration.

**The claim is false.** `isar_generator` emits no suppression header of any kind. The complete preamble of the only Isar-generated file that existed when ADR-021 was written:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_metadata.dart';
```

Contrast `freezed`, which does what ADR-021 attributes to Isar:

```dart
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, ...
```

`type=lint` suppresses every lint in the file. Isar suppresses nothing.

**Why the error went unnoticed.** ADR-021's verification was real but narrower than its wording. The sole Isar collection, `DatabaseMetadata`, lives in `lib/core/database/collections/`, and `core/database/` has **no nested `analysis_options.yaml`**. Amendment A-025 requires that file only for each feature's `domain/` and `data/`, where it enables `public_member_api_docs`. So the one Isar collection in existence was analysed under the root configuration alone, which does not enable that rule. "Zero issues" was a true observation about one file in one directory, generalised into a false statement about a generator.

The ADR contains its own contrary evidence, unrecognised at the time: it records dropping `cascade_invocations` because *"the generator does not suppress"* it — the same generator, observed suppressing nothing, one paragraph after being credited with suppressing what it trips.

**What exposed it.** Mission 3.7 places Volume 5 Chapter 5.8's three collections in `features/recording/data/`, following the precedent the `Architecture boundaries` CI job states for Firebase — *"a Firebase **product** belongs to the module that consumes it, which is what makes `features/auth/` the replaceable unit rather than `core/`"* — and matching `DatabaseMetadata`'s own description of itself as *"Infrastructure, not a feature model."* Engine in `core/`, collections in the feature.

That placement puts Isar output under A-025's nested configuration for the first time. Measured:

| Location | `public_member_api_docs` violations in Isar output |
|---|---|
| `lib/core/database/` (no nested config) | **0** |
| `lib/features/recording/data/collections/` | **689** |

Three accepted decisions are jointly unsatisfiable: ADR-021 forbids excluding generated code, A-025 requires `public_member_api_docs` in every feature's `data/`, and `isar_generator` emits no suppression. Any Isar collection owned by a feature fails analysis.

## Decision

### ADR-021 is carried forward entire, except one paragraph

The rule set, the reason-per-rule requirement, the tightened type system, severity-by-consequence, explicit type annotation, constrained suppression, the stated formatter width, and the single-file scope are all unchanged and remain binding. This ADR replaces ADR-021 solely to correct §"Generated code is analysed, not excluded" and to add the resolutions below.

### Generated code is still analysed, and still not excluded

The policy survives, because it was never the part that was wrong. Generated files are committed (Volume 6 §6.2, Volume 3 §3.6 §5), they ship, and code that ships is analysed. **`analyzer.exclude` remains empty.**

Excluding `*.g.dart` was rejected by ADR-021 on the grounds that it *"hides genuine generator-output errors"*, and that reasoning is now demonstrated rather than hypothetical: Mission 3.7's collections produced three genuine errors — an undefined `EmbeddedGpsFixSchema`, and two consequent const-map failures — caused by a real defect in how the embedded types were declared. They were fixed by adding a `part` directive to each embedded file and a direct import to the collection. **An exclusion would have hidden all three and the collections would have been committed broken.**

### `public_member_api_docs` is not applied in directories holding generated collections

A `data/collections/analysis_options.yaml` includes the root configuration and does **not** add `public_member_api_docs`. Every other rule, and the whole tightened type system, still applies to those files.

**Nothing is excluded from analysis.** One documentation lint is not applied in one directory, which is a strictly smaller change than removing files from the analyser's view.

**Why directory scope rather than file glob.** `analysis_options.yaml` offers exactly two mechanisms: `analyzer.exclude:`, which takes globs and removes files from analysis entirely, and nested configuration files, which scope by directory. There is no way to disable a rule for `*.g.dart` alone. Directory scoping is therefore the narrowest expressible form of the intent, and the directory holds only the collections and the output generated from them.

The hand-written declarations there are documented member by member regardless — **verified, not assumed.** The first draft of this ADR asserted it before it was true: the embedded types had 25 undocumented public fields. All are now documented, and a check confirms zero hand-written violations in that directory.

### `experimental_member_use` is not applied there either — the same cause, a second time

`isar_generator` emits calls to Isar APIs marked `@experimental` — `getByIndex`, `getByIndexSync` and their siblings — whenever a collection declares `@Index`. It suppresses those exactly as it suppresses everything else: not at all. 36 warnings, all in the new generated files.

This did not appear before for a mechanical reason: `DatabaseMetadata` declares **zero** `@Index` annotations, so no such extensions are generated for it. Confirmed — 0 occurrences in its output, 2 in `local_chunk.g.dart`.

The nested configuration therefore also carries `analyzer: errors: experimental_member_use: ignore`, scoped to the same directory.

**This argument is weaker than the documentation one, and that is worth stating rather than glossing.** Undocumented generated members are noise: nobody wrote them and nobody reads them. An experimental-API warning is a *real risk signal* about a real dependency, and silencing it removes information rather than clutter.

**It is silenced because the alternative is worse.** The warnings originate from `@Index(unique: true)` on `LocalChunk.chunkId`. That index exists because Chapter 5.13 §4 requires every retry to reuse *"the exact same `chunk_id`"*, so a second row for one chunk would break BR-11's duplicate-prevention guarantee. Removing the index to quiet a linter would move a correctness guarantee out of the database engine and into hand-written repository code that nothing enforces. **A uniqueness constraint the engine guarantees is worth more than a clean warning count.**

### The compounding risk this creates, named and not resolved

This project now depends on an `@experimental` API, from a package that is **unmaintained**, for a **real correctness guarantee**.

Isar 3's maintenance status is already recorded in A-029, which keeps the engine question open. `getByIndex` being experimental in an abandoned package means it will not stabilise, and if it changes or is withdrawn upstream there is no upstream to fix it — `LocalChunk`'s unique indexing breaks, and with it BR-11's duplicate prevention at the storage layer.

Three things compound here and each is individually tolerable: an experimental API, an unmaintained package, and a correctness guarantee resting on both. Silencing the warning removes the last routine reminder that they overlap, which is why the overlap is written down here instead.

**Named, not resolved**, and flagged for the same kind of future attention as A-058's software-encoder fallback and unmeasurable flush interval: risks that are real, currently unactionable, and must not become invisible merely because nothing in the build reports them any more. Revisiting the engine choice under A-029 is the decision that would close it.

## Alternatives Considered

- **Move the collections to `core/database/`.** Rejected. No lint conflict and no ADR touched, but it puts a feature's data model inside the engine's module, contradicting `DatabaseMetadata`'s own documentation and the ownership precedent the CI job states for Firebase products. It also fails the next time any feature needs a collection.

- **Exclude `**/*.g.dart` in the nested configuration.** Rejected on ADR-021's original grounds, now with evidence: Mission 3.7's three real generator errors would have been hidden.

- **Drop the unique indexes and enforce uniqueness in the repository.** Rejected. It would silence `experimental_member_use` with no suppression at all, which is genuinely attractive — but it trades a guarantee the database enforces for one that hand-written code must remember to. BR-11's duplicate prevention is exactly the kind of rule that should not depend on discipline.

- **Leave ADR-021 unamended and suppress inline.** Not possible. A suppression comment must live in the file, and the file is regenerated on every build.

- **Drop `public_member_api_docs` from feature layers entirely.** Rejected. It is A-025's substance and it works. Removing a functioning rule to accommodate one generator is disproportionate.

- **Edit ADR-021 in place.** Forbidden by governance: an Accepted ADR is corrected by a superseding decision, not by rewriting. Same relationship A-057 established for Draft-status Volume chapters and `bc81a07` for a shipped defect.

## Consequences

- **ADR-021 is marked Superseded and left otherwise untouched**, including its incorrect paragraph. The error stays legible, so a reader who meets the claim elsewhere can trace why it is no longer operative.
- **Isar collections may live in the feature that owns them**, which is what makes a feature the replaceable unit.
- **One directory carries two relaxations**, stated in its own configuration file with its reasons, rather than centrally.
- **This will recur for any generator that suppresses nothing.** The pattern is established: a directory-scoped configuration file, not a fresh argument.
- **A real risk is now quieter.** The experimental-API dependency is no longer reported by the build, so this ADR and A-029 are the only places it is visible.
- **ADR-021's verification method is the lesson, not just its conclusion.** *"Verified: zero issues"* was true and insufficient, because the configuration it ran against was not the configuration the codebase would eventually have. A verification is only as general as the arrangement it ran against — and this ADR's own first draft repeated the mistake in miniature, asserting the hand-written files were documented before anyone had counted.

## Related Missions

- Mission 0.18.4 — ADR-021's original configuration.
- Mission 3.7 — Volume 5 Chapter 5.8's local storage; placed the first feature-owned Isar collections and surfaced both instances.

## Implementation Status

| Item | State |
|---|---|
| `lib/features/recording/data/collections/analysis_options.yaml` | Written — includes root, omits `public_member_api_docs`, sets `experimental_member_use: ignore` |
| `analyzer.exclude` | Still empty, repository-wide |
| Hand-written members in that directory documented | Verified — 0 violations |
| The three generator errors | Fixed, not suppressed |
| `flutter analyze` | **No issues found** |
| ADR-021 | Marked Superseded; body untouched |
