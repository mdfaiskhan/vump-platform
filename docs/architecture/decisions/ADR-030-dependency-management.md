# ADR-030 — Dependency Management

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Implements Volume 3 Chapter 3.8 against the current dependency tree. Registers A-047 and A-048.

## Context

Volume 3 Chapter 3.8 is titled *"Dependency Management: How Packages Enter the Project, and How They're Kept Under Control"*. It fixes the monorepo question, a four-tier version-pinning policy, a six-item admission checklist, a review cadence and a minimal-surface principle. **No ADR records any of it, and no document in the repository applies it to the packages that exist.**

That matters more here than it would elsewhere, because the audit found the tree is aging in a way nothing is watching.

**Seven direct dependencies are constrained below a resolvable version.** `go_router` is three major versions behind, `flutter_secure_storage` two — and **both are upgradable today**. `flutter_riverpod`, `freezed`, `freezed_annotation`, `build_runner` and `json_serializable` are behind and blocked. Four packages in the tree are discontinued. Twenty-six packages have newer versions the current constraints forbid.

**Volume 3 §3.8 §5 has a cadence rule and nothing implements it:** *"`flutter pub outdated` is run and reviewed at the start of each development phase boundary… Any dependency with a published security advisory is patched immediately."* Verified: no CI step, no Dependabot, no Renovate, no advisory scanning, and `dart pub audit` does not exist as a subcommand in this SDK. §3.8 §7 defers the CI step to Volume 7, which does not specify it either. So the tree ages until someone happens to look — which is exactly the *"silently aging for a year or more"* outcome §3.8 §5 was written to prevent.

**And one dev dependency is holding the toolchain back by nine major versions.** `isar_generator 3.1.0+1`, published in 2023, declares `environment: sdk: ">=2.17.0 <3.0.0"` — no Dart 3 support at all, resolving only because pub relaxes the upper bound of pre-Dart-3 packages. It caps `analyzer` below 6.0.0 against a current 14.1.0, and `source_gen` at 1.x against 4.2.4. The resolver states the consequence directly: *"because mobile depends on both `freezed ^2.5.2` and `isar_generator ^3.1.0+1`, version solving failed."*

That is a concrete, previously unrecorded consequence of the engine problem A-029 describes for `isar_flutter_libs` — a different package, a different mechanism, and one A-029 does not mention.

## Decision

### Volume 3 §3.8 is implemented, and the tiers are assigned to actual packages

`docs/development/dependency-management-standards.md` is the canonical dependency standard: eleven sections covering shape, the dependency inventory with tier and owner, pinning, the admission process, review cadence and measured staleness, transitive dependencies, the codegen toolchain constraint, security, CI verification, gaps and maintenance.

**Volume 3 §3.8 is the authority and is cited, not restated.** What the standard adds is the application: which of the 18 dependencies sits in which of §3.8 §3's four tiers, which module owns it, and which ADR justifies it. §3.8 names `riverpod`, `drift`, `dio` and `go_router` as the core tier; the repository has Isar rather than Drift (ADR-009) and three packages §3.8 does not mention — `flutter_secure_storage`, `firebase_core`, `logger` — all of which are load-bearing and are assigned to the core tier here.

Placed in `docs/development/` beside the other practice standards, per ADR-024 §20's audience test: the reader is a contributor about to add a package.

### Automated dependency-update PRs are declined

Dependabot and Renovate are **not adopted**, and this is a decision rather than an omission.

Volume 3 §3.8 §5 requires review *"at the start of each development phase boundary… **not continuously** — batching upgrades avoids constant churn"*, and §3.8 §3 requires core architectural packages to be *"reviewed and bumped deliberately, **never on an automated schedule alone**"*. A bot that opens a pull request per package per release is continuous by construction and would contradict both.

**What is needed instead is a trigger, not automation:** `flutter pub outdated` reviewed at a phase boundary, with the output recorded. That has no mechanism today, which is the substance of A-047 — the gap is the missing trigger, not the missing bot.

### `pubspec.lock` is committed

Correct for an application: it makes a build reproducible from a clone, and it is what allowed this mission's transitive audit to run without resolving. A library would not commit it. Volume 3 §3.8 does not address it, so it is decided here.

### Transitive dependencies are resolved and audited, never constrained

No `dependency_overrides` entry exists and none is added by default. An override silences the resolver rather than satisfying it, and it pins a package this project does not own.

**Where an override becomes unavoidable**, it carries a comment naming the upstream issue and the condition for its removal. Stated ahead of its first use, because an undocumented override is indistinguishable from a permanent fork.

### Adding a package incurs three obligations beyond §3.8 §4's checklist

A new package is not only admitted; it is placed. From decisions already taken:

- **A confinement entry** in the `Architecture boundaries` CI job (ADR-022 §2.3), or the confinement is documentation only — already true of `logger`.
- **A conversion boundary** at the owning module (ADR-025 §7), so nothing above sees a third-party error type.
- **A record against a Volume chapter** before it is added (Volume 0 §2).

### Absences are recorded as absences

No licence verification, no advisory scanning, no staleness check, no Windows-buildability check in CI, and no backend dependency tree. Each is recorded with the Volume clause it fails to satisfy and whether the absence is correct.

**One is correct and worth naming:** the backend has no dependency tree because `backend/` is empty (ADR-015). When it exists it is a **separate tree with separate rules** — npm, its own lockfile, its own audit — and this standard governs `mobile/`.

## Alternatives Considered

- **Adopt Dependabot or Renovate to close the staleness gap.** Rejected on the Volume's own terms: §3.8 §5 requires batched, phase-boundary review *"not continuously"*, and §3.8 §3 forbids bumping core packages *"on an automated schedule alone"*. A bot would produce exactly the churn both clauses reject. The gap is a missing trigger, and A-047 records it as such.

- **Upgrade `go_router` and `flutter_secure_storage` as part of this mission.** Rejected — this is a documentation and governance mission and changes no code — but they are named as the cheapest available improvement, because both are resolvable today with no blocker. Three major versions of a router and two of a secure-storage plugin are behaviour changes that deserve their own commit and their own testing, which is precisely §3.8 §3's *"reviewed and bumped deliberately"*.

- **Add `dependency_overrides` to force `analyzer 6+` and unblock the codegen chain.** Rejected, and it is the tempting wrong answer. `isar_generator` declares `analyzer <6.0.0` because it was built against 5.x; overriding it would run a 2023 generator against an analyzer nine majors newer than it has ever seen, and the failure would appear as malformed generated code rather than as a resolution error. The `Generated code drift` job would catch a difference, not a subtle wrongness. The real fix is A-029's engine decision.

- **Record the toolchain constraint as part of A-029 rather than a new amendment.** Rejected. A-029 is about `isar_flutter_libs` and the Android Gradle Plugin — a runtime package and a native build. This is `isar_generator`, a dev dependency, capping `analyzer` and `source_gen` for the whole codegen chain. Same root cause, different package, different mechanism, different consequence; folding them would hide the second behind the first, and A-029's status is already *"partially resolved"* for a fix that does nothing for this.

- **Adopt a Melos monorepo to make module boundaries compile-time.** Rejected — Volume 3 §3.8 §2 already decided it, and its reasoning holds: *"for a single app with one team, that trade isn't worth it yet."* The trigger it names is a genuinely separate Admin web app.

- **Alphabetise `pubspec.yaml`.** Rejected, consistent with ADR-023 §11: the purpose grouping with explanatory comments is the more useful organisation of a dozen entries, which is why `sort_pub_dependencies` is excluded from the lint set.

- **Pin exact versions instead of caret constraints.** Rejected. §3.8 §3 fixes caret constraints for all four tiers; exact pins would make every transitive security patch a manual edit, and `pubspec.lock` already provides build reproducibility, which is what an exact pin is usually reached for.

- **Add a licence-checking CI job now.** Rejected as out of scope, and recorded. All 16 pub packages were verified compliant by hand for this document — MIT, BSD-3-Clause or Apache-2.0 — so the risk today is a future transitive arrival, not a present violation.

## Consequences

- **The dependency tree's condition is now a number rather than an impression:** 7 direct dependencies behind, 4 discontinued packages, 26 blocked upgrades. That is a backlog, and two items on it are unblocked.

- **A-048 makes the cost of A-029 concrete.** The engine decision was previously a build-blocker plus an unmaintained-package risk. It is now also the reason `freezed` cannot pass 2.5.7 and `flutter_riverpod` cannot reach 3.x — so the decision has a price that grows with every release of the packages it blocks.

- **Declining Dependabot means staleness stays a human responsibility**, and today no human is prompted. A-047 records that the missing piece is a phase-boundary trigger; until one exists, this decision leaves the tree aging by design rather than by accident, which is worse in effect and better in that it is now written down.

- **Windows buildability — the constraint §3.8 §1 says this project cares about most — is verified only on a developer's machine.** CI runs `ubuntu-latest`. A native plugin that breaks the Windows build passes CI.

- **The confinement obligation is now explicit at the moment a package is added**, which is when it is cheap. `logger` shows the alternative: a documented owner and no check, which nothing prevents from being violated.

- **The standard's numbers go stale by design.** §5's staleness table is true on 2026-08-11 and will be wrong after the next release of anything. §11 makes re-deriving them an obligation rather than treating the table as a record.

- **Nothing in the repository changed.** No dependency added, removed or upgraded; no CI job added.

## Related Missions

- The foundation commit `b0493b5`, which established `pubspec.yaml` and its constraints. No numbered mission is recorded as its author — the pre-0.16 history is squashed into two commits, so the dependency set predates mission-level attribution.
- Mission 0.18.8A — the Gradle shim that keeps Isar building, recorded as A-029, whose engine decision A-048 now bears on.
- Mission 0.18.6 — which declined to install `mocktail`, `integration_test` and `golden_toolkit` (A-028), on the same minimal-surface reasoning §3.8 §6 states.
- Mission 0.19.1 — Static analysis (ADR-021), which enables `secure_pubspec_urls`.
- Mission 0.19.10 — Dependency Management Standards, which produced this ADR, the standard, and amendments A-047 and A-048.

## Implementation Status

**Documented. Volume 3 §3.8's structural rules are met; its cadence and verification rules have no mechanism.**

`docs/development/dependency-management-standards.md` carries the standard. Verified by running every audit command against the repository:

| Audited | Result |
|---|---|
| Melos workspace | **Absent** — single package, per §3.8 §2 |
| Direct dependencies | **12** |
| Dev dependencies | **6** |
| Transitive | **97** — 115 packages resolved |
| Bare, unconstrained dependencies | **0** — every non-SDK entry is caret-constrained |
| Dart SDK constraint | `^3.12.2`, resolving `>=3.12.2 <4.0.0`, `flutter >=3.38.4` |
| `pubspec.lock` committed | **Yes** |
| `dependency_overrides` | **None** |
| Licences of the 16 pub packages | **All pre-approved** — 8 MIT, 5 BSD-3-Clause, 3 Apache-2.0 |
| Direct dependencies below a resolvable version | **7** |
| Discontinued packages in the tree | **4** — all transitive |
| Packages with newer versions blocked by constraints | **26** |
| `isar_generator` declared SDK support | `">=2.17.0 <3.0.0"` — **excludes Dart 3**; resolves only via pub's pre-Dart-3 relaxation |
| `isar_generator` caps | `analyzer >=4.6.0 <6.0.0` (current 14.1.0), `source_gen ^1.2.2` (current 4.2.4) |
| Resolved analyzer in the codegen chain | **5.13.0** |
| CI jobs verifying dependencies as such | **0** |
| Dependabot / Renovate configuration | **Absent** |
| `dart pub audit` | **Does not exist** as a subcommand in this SDK |
| Windows buildability checked in CI | **No** — CI runs `ubuntu-latest` |
| `flutter analyze` | No issues |

No code was changed. Volume 3 §§3.1 and 3.8 were read from the source PDF and quoted from the extracted text.

**Two claims in this mission's draft were corrected by verification, and one was confirmed rather than assumed.**

**A cited mission number had no evidence behind it.** The draft's Related Missions attributed `pubspec.yaml` to "Mission 0.18.7". Grepping showed that string appeared nowhere in the repository except in the draft itself — the number was inferred from the sequence, not read from a record. The dependency set in fact predates mission-level attribution: it arrives in the squashed foundation commit `b0493b5`, and `git log -- mobile/pubspec.yaml` returns that single commit.

**The toolchain constraint was a hypothesis before it was a finding.** The draft asserted that `isar_generator` blocks the toolchain. That was a hypothesis from the version numbers; reading the package's published `pubspec.yaml` from the pub cache and then reading the resolver's own explanation turned it into a quotable fact — *"because mobile depends on both `freezed ^2.5.2` and `isar_generator ^3.1.0+1`, version solving failed"* — and revealed the stronger finding underneath it, that the package declares no Dart 3 support at all.

The claim that `analyzer` is unpinned by this project and independent of ADR-021's lint set was checked rather than reasoned: `analyzer` is not a direct dependency, and `flutter analyze` uses the SDK's own analyzer, so the resolved 5.13.0 constrains code generation and not the 176 lint rules. A reader would reasonably have assumed the two were connected.
