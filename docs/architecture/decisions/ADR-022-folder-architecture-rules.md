# ADR-022 — Folder Architecture and Import Rules

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Refines ADR-002 in one respect — see *The router exception* below. ADR-002 remains Accepted and binding in every other respect.

## Context

Two accepted ADRs already decide most of how this repository is organised. **ADR-001** divides every feature into four layers with dependencies pointing inward. **ADR-002** divides `mobile/lib/` into `app/`, `core/`, `features/` and `shared/`.

Neither decides four things that the first feature will immediately need.

**The repository root has never been a decision.** `mobile/`, `backend/`, `docs/`, `infrastructure/` and `.github/` exist and are described in `README.md`, but a README is editable without governance and records no reasoning. Nothing states what earns a place at the root, which is why the question "where does a shell script go?" has no answer today and will be answered by whoever needs one first.

**The rules that keep features separate are unwritten.** No cross-feature imports, no circular dependencies, no feature code in `core/`, nothing in `shared/` without a second consumer — these are the rules that make ADR-001's layering worth having, and not one of them is recorded. ADR-001 makes a violation of the *inward* rule a defect. It says nothing about a *sideways* import between features, which is the more common failure and the one that quietly turns two modules into one.

**The import matrix is incomplete in the one place that matters.** ADR-001 establishes that `presentation` and `data` may depend on `domain`. It does not state that `presentation` may not depend on `data` — the prohibition that stops a widget bypassing every use case by constructing a repository directly.

**ADR-002 and ADR-004 are in tension, and the first feature triggers it.** ADR-002: *"Nothing in `app/` may depend on a specific feature."* ADR-004: *"Routes are declared in one place: `lib/app/router.dart`."* A route table must name its screens. Today there is no conflict because the only screen is `app/home_screen.dart`; the moment a feature has a screen, one of the two sentences must give. Discovering that at implementation time means it is resolved by whoever is mid-feature, silently, in whichever direction is convenient.

`lib/features/` is empty. This is the last moment at which these rules cost nothing to state and can be stated without reference to code already written against a different assumption.

## Decision

### The rules are recorded in one reference document

`docs/architecture/folder-structure.md` is the canonical folder architecture reference: the purpose and ownership of every root directory, the responsibilities of each `lib/` directory and each feature layer, eight numbered folder rules with their justifications, the complete import matrix, and the procedure for adding a feature.

It is a reference document, not an ADR, following the pattern this repository already uses — ADR-019 with `docs/git/branching-strategy.md`, ADR-020 with `docs/git/commit-conventions.md`. The ADR records the decision and why; the reference states the rule a developer needs at the moment they add a file. `docs/architecture/README.md` is explicit that an ADR "is not a design document, a specification, a tutorial or a task list", and a folder specification is all four.

**ADR-001 and ADR-002 are not restated.** The reference cites them and adds only what they leave open.

### The root is a boundary, not a grouping

A top-level directory is a **deployment or governance boundary**. The test: does it ship, or govern, independently of everything else at the root? `mobile/` ships to app stores; `backend/` ships to Lambda; `infrastructure/` is applied to AWS; `docs/` governs; `.github/` is executed by GitHub. A directory that fails the test belongs inside one of these.

The distinction most easily lost is `backend/` against `infrastructure/`: **`backend/` is code that runs, `infrastructure/` is state that exists.** A Lambda handler is `backend/`; the IAM policy that lets it read a bucket is `infrastructure/`.

### `scripts/` and `assets/` are reserved, not created

Both have a defined purpose and a defined trigger, and neither is created before it has contents. An empty directory in a git repository is not a structure — git does not track it, so a clone does not receive it.

`assets/` carries a technical constraint that is recorded because the natural instinct produces a broken build: **Flutter resolves `pubspec.yaml` asset paths relative to the package root and refuses paths outside it, so a repository-root `assets/` can never be declared in `pubspec.yaml`.** Runtime assets — fonts, icons, images — must live at `mobile/assets/`. A root `assets/` is only ever for material the app does not ship: design exports, logo masters, store screenshots.

### The four sideways rules

The layer rules ADR-001 gives are about direction *within* a feature. These are about separation *between* units, and they are what the folder tree cannot enforce on its own:

- **No cross-feature imports.** `features/a/` never imports `features/b/`, at any layer, in either direction.
- **No circular dependencies** — between features, between layers, or between `core/` modules.
- **No feature code in `core/`.** `core/` is defined by having every feature as a potential consumer, not by being low-level.
- **Nothing enters `shared/` without a second consumer.** Components are written inside the feature that needs them and *promoted* when a second feature needs them.

Cross-feature imports get the fullest treatment because they are the failure this structure exists to prevent, and the only one that is invisible in the folder tree — the structure still looks modular after it has stopped being so. The reference gives four ordered resolutions and forbids the fifth, which is reaching for the import because the code is already there.

### `presentation/` and `application/` may not import `data/`

Stated explicitly as the two most consequential prohibitions in the matrix. The repository interface is in `domain/`; the implementation is in `data/`. A layer that imports `data/` has bound itself to one implementation, which breaks test substitution, and — for `presentation/` — lets a widget skip whatever rule the use case applied.

The failure mode is what makes this worth an ADR: everything compiles, the feature works when demonstrated, and the defect appears months later as an inconsistency between two screens.

### `domain/` purity, with two named exceptions

`domain/` imports nothing outside itself — no Flutter, no Dio, no Isar, no Riverpod, no `core/` — except **`core/errors/failure.dart` and `core/errors/error_codes.dart`**, and pure-Dart annotation packages (`freezed_annotation`, `json_annotation`).

The exception is not a concession. `core/errors/failure.dart` already documents itself as "pure Dart by necessity — ADR-001 requires that `domain` depend on nothing outside itself, and `domain` consumes this type." Those two files are the error vocabulary that has to cross every layer; they carry no I/O and no third-party dependency. Naming the exception precisely is what stops it widening to "`domain/` may import `core/`".

### `core/` reads `app/config/`, one-way, and nothing else from `app/`

The obvious rule — "`core/` may not import `app/`" — is wrong, and writing it down would have made eight files defects that the accepted ADRs require.

`core/` **may** import `app/config/`. ADR-007 has `NetworkConfig` derive base URLs and timeouts from `AppEnvironment`; ADR-018 has `EnvironmentProfile` delegate to `AppConfig` rather than hold its own copy of a value, because a copy is a second source of truth that silently disagrees with the first. The dependency is safe because `app/config/` is const-evaluable configuration with no behaviour and no I/O (ADR-006): it couples `core/` to a compile-time value, not to the application's identity.

`core/` **may not** import `app/theme/`, `app/app.dart` or `app/router.dart`. A database service that imports a colour token has a presentation dependency in its I/O path.

**The direction is strictly one-way: `app/config/` must never import `core/`.** This rule already exists in the codebase — `core/network/network_config.dart` states it in its own doc comment — and this ADR promotes it from a comment in one file to a rule of the architecture. Reversing it creates the cycle R4 forbids and puts a base URL in two places, which is the failure ADR-018 exists to prevent.

The same precision applies to `shared/`: it may read `app/config/` and must reach design tokens through `Theme.of(context)` and the `AppSemanticColors` theme extension, per ADR-005, rather than importing `app/theme/`.

### The router exception — this refines ADR-002

**`app/router.dart` is the only file in `app/` permitted to import from `features/`, and only from `features/<name>/presentation/`.** Every other file in `app/` names no feature. `router.dart` may name a screen; it may not import a feature's `domain/`, `data/` or `application/`.

This narrows ADR-002's sentence *"Nothing in `app/` may depend on a specific feature"* from a blanket prohibition to a precise one. ADR-002's **purpose is preserved in full**: `app/` still contains no feature logic, and every file in it except one still names no feature.

The alternative was considered and rejected below. This is the one place where this ADR changes the reading of an accepted decision rather than extending it, and it is called out here rather than buried in the reference so that a reviewer who disagrees can reject it on its own terms.

### Adding a feature changes one new directory and one existing line

The reference documents the procedure: create `features/<name>/` with the four layers, write `domain/` first, then `data/`, `application/`, `presentation/`, register routes in `app/router.dart`, add the nested `analysis_options.yaml` that amendment A-025 requires for `domain/` and `data/`, mirror the structure in `test/`.

All five planned features — `authentication`, `recording`, `upload`, `tasks`, `settings` — fit without architectural change. Two are named as the tests of these rules: **`recording` and `upload`** will make a cross-feature import look locally sensible, since one produces chunks and the other consumes them; **`settings`** will look like `core/` because every feature observes it, and is not.

## Alternatives Considered

- **Put everything in the ADR and write no reference document.** Rejected. `docs/architecture/README.md` states that an ADR is not a specification or a tutorial, and a folder specification is both. An ADR that a developer must reread to remember whether `presentation/` may import `data/` is being used as documentation, and the repository already separates the two — ADR-019/ADR-020 each have a reference document beside them.

- **Extend ADR-001 and ADR-002 instead of writing a new ADR.** Rejected, and not permitted. `docs/architecture/README.md` states that an accepted ADR must never be updated to "add, remove or reinterpret a constraint" — that requires a new record. Both remain Accepted and binding; this ADR cites them and does not restate them.

- **Document the rules only in `CLAUDE.md`.** Rejected. `CLAUDE.md` is the engineering constitution and states standards, not their justification. A rule whose reason is not recorded is deleted the first time it is inconvenient, and the folder rules are inconvenient at exactly the moment they matter — when the code you want is in another feature.

- **Create `scripts/` and `assets/` now, with `.gitkeep` files.** Rejected. Both would be structure without contents, and one of them would be wrong: a root `assets/` cannot serve Flutter runtime assets at all. Naming the trigger for creation is more useful than an empty directory that invites the wrong contents.

- **Move `infrastructure/aws/env.sh` and `apply-cloudfront.sh` into a new `scripts/`.** Rejected, and the mission forbade moving files regardless. They apply that directory's AWS state and are documented in `infrastructure/aws/README.md`; separating them from the JSON they apply means the reader of a lifecycle policy no longer finds the command that installs it.

- **Resolve the ADR-002/ADR-004 tension the other way** — keep `app/` absolutely feature-blind by having `app/router.dart` accept a `List<RouteBase>` that `main.dart` assembles from each feature. Rejected. It makes ADR-004's "routes are declared in one place" false: the route table would be distributed across N features, and no single file would show every route in the application. That is the property ADR-004 exists to protect, and it is worth more than the absolute form of ADR-002's sentence. The chosen exception is narrow, greppable, and leaves `app/` unable to reach any feature's logic.

- **Adopt `custom_lint` to enforce the new rules.** Rejected, consistent with amendment A-026. The `Architecture boundaries` CI job already enforces the package-confinement rules with no dependencies, and extending it is the intended mechanism. Adding a second enforcement tool for rules that cannot yet be tested — `features/` is empty — would be tooling ahead of need.

- **Defer all of this to the first feature mission.** Rejected. That is the mission least able to make the decision well: it would be resolving the ADR-002/ADR-004 tension while mid-feature, and writing the cross-feature import rule after the first cross-feature import already looked reasonable.

## Consequences

- **The first feature has an unambiguous procedure**, including the route registration and the nested analysis configuration A-025 requires — two steps that are easy to miss and produce a rule silently unenforced when missed.

- **The ADR-002/ADR-004 tension is settled before it is hit**, in writing, rather than by whoever encounters it first.

- **ADR-002's blanket sentence is no longer literally true.** Anyone reading ADR-002 alone will believe `app/` names no feature. The refinement is recorded here and in the reference, but the reader of ADR-002 has to follow the cross-reference to find it — an unavoidable cost of the rule that accepted ADRs are not edited.

- **Four of the new rules are not machine-checked.** R3 (cross-feature), R4 (cycles), the `data/` prohibitions and the `app/`↛`features/` rule are binding in writing and unenforced in fact. None can be tested with zero features. Each is a grep, and extending the `Architecture boundaries` job belongs to the mission that creates the first feature — recorded plainly in the reference rather than glossed, because this repository already has one convention in that state (ADR-020) and knows what it costs.

- **`shared/` will stay empty longer than it otherwise would.** Promotion-only means the first reusable-looking widget is written inside a feature and moved later, which is one extra step at the moment someone believes they are being helpful.

- **The `recording`/`upload` chunk concept now needs a decision when the second of the two is built.** This ADR forbids the import and names the resolutions; it does not choose one, because the right choice depends on what the chunk turns out to be.

- **A discrepancy is now on record rather than latent:** `lib/features/` and `lib/shared/` are untracked empty directories, so a fresh clone has neither, despite ADR-002 declaring both. The fix is a `.gitkeep` in each — deliberately not done here, since Mission 0.19.2 was constrained against creating placeholder folders.

- **The root gains a stated admission test**, so the next candidate for a root directory is argued rather than added.

## Related Missions

- Mission 0.6.2 — Application Bootstrap, which created the `lib/` tree ADR-002 records.
- Mission 0.18.1 — which removed the four layer directories wrongly scaffolded at the root of `features/`, the defect rule R8 now names.
- Mission 0.19.1 — Static analysis configuration (ADR-021), which enforces the package-import and file-naming rules this document relies on.
- Mission 0.19.2 — Folder Architecture Rules, which produced this ADR and the reference document.

## Implementation Status

**Documented. Partially enforced.**

`docs/architecture/folder-structure.md` carries the rules. Verified against the repository as it stands:

- The five root directories, `mobile/lib/`'s four-way split, and the seven `core/` modules described in the reference match the tree exactly.
- **Every import rule was checked against `lib/` by grep, not asserted.** No violation exists: no file imports `features/`, no `core/` or `shared/` file imports `app/theme/`, `app/config/` imports nothing from `core/`, there is no `Color` literal outside `app/theme/`, and there is no relative import anywhere in `lib/`.
- **One documented rule was wrong on the first pass and was corrected by that check.** The draft forbade `core/` from importing `app/` at all, which would have made eight files defects — including `NetworkConfig` and `EnvironmentProfile`, whose dependency on `AppEnvironment` is required by ADR-007 and ADR-018. The rule as recorded permits `app/config/` and forbids `app/theme/`, which is the prohibition the blanket version was reaching for.
- `flutter analyze` reports no issues, and the `Architecture boundaries` job's four package-confinement checks pass.
- No file was moved, renamed, or created outside `docs/`. No placeholder feature directory was created.
- `features/` and `shared/` remain empty, so the feature-level rules are binding but unexercised — the same position ADR-001 has been in since it was accepted.

Enforcement status is itemised in the reference, §5.5: two rules are checked by CI and `flutter analyze` today; four become checkable when `features/` has contents.
