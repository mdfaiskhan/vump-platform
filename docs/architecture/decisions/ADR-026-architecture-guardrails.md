# ADR-026 — Architecture Guardrails

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Records the enforcement status of the invariants established by ADR-001 to ADR-025, and registers four previously unrecorded divergences from Volume 3 — amendments A-038 to A-041.

## Context

Twenty-five accepted ADRs establish this repository's architecture. Nine CI jobs and 176 lint rules enforce part of it. **No document says which part.**

That is the gap this ADR closes, and it is not a cosmetic one. The repository already has two recorded cases of a rule that was binding in writing and unenforced in fact:

- **ADR-020** records its own convention as *"binding in writing and unenforced in fact until the workflow lands"*.
- **Mission 0.18.1** found four empty layer directories sitting at the root of `features/` — the layer-first structure ADR-001 explicitly rejects — described in ADR-001 itself as compliance, for eleven missions.

Both were caught by audit rather than by a check. A rule whose enforcement status is unknown is a rule that decays quietly, and the current position is that every architectural invariant in the repository has an unknown enforcement status.

**The audit for this mission found the ratio is worse than it looks.** Fifteen invariants are enforced by CI and nine by the analyzer — but every one of those concerns **packages, secrets, environments or formatting**. Every invariant about **layers and features** is enforced by review alone. That is not an accident: `lib/features/` is empty, so most layer rules cannot be tested yet. But six of them concern code that already exists and are checkable today, and nothing checks them.

**Reading Volume 3 Chapters 3.4, 3.5 and 3.6 in full surfaced four divergences that no ADR and no amendment records.** Two are substantive:

- **Volume 3 §3.4 §2–3 specifies five layers with the dependency arrow running `Domain → Data/Repositories → Platform Services`** — downward and uninverted. ADR-001 specifies four layers with the arrow inverted: `data/` implements the interfaces `domain/` declares. These are opposite claims about the most important arrow in the architecture, and ADR-001 cites no Volume.
- **Volume 3 §3.5 §4 contradicts itself.** Its bullets list `recording → projects_tasks`, `upload → recording`, `onboarding`/`settings` → `auth` and `admin_shared → projects_tasks`; its closing sentence forbids *"two feature modules depend[ing] on each other directly without going through core"*. ADR-022 R3 forbids cross-feature imports absolutely, aligning with the closing sentence and conflicting with the bullets — and ADR-022 was written without knowing either existed.

`lib/features/` is empty. Every layer and feature invariant is still theoretical, which makes this the cheapest moment to record what is checked and what is merely written down.

## Decision

### The invariant register is the deliverable

`docs/architecture/architecture-guardrails.md` records every architectural invariant in force — **38 of them** — each with three things: its **authority** (the ADR, Volume, Constitution or Vision clause it derives from), its **enforcement mechanism** (`CI`, `Analyzer`, or `Review`), and where applicable the **command that verifies it**.

**The enforcement column is the contribution.** ADR-022 already fixes the import rules; ADR-025 the error boundary; ADR-021 static analysis; ADR-023 naming. None of them says whether a machine checks the rule. The guardrails document adds that column and nothing else, so it duplicates no rule — every invariant is a one-line statement plus a citation, never a restatement.

The register is split three ways, and the split is the finding:

| Enforcement | Count | What they cover |
|---|---|---|
| CI | 15 | Package confinement, AWS credential isolation, secrets, environment consistency, codegen drift, format, analyze, tests, commit convention |
| Analyzer | 9 | Import form, `print`, dynamic calls, error-path rules, dead code, file naming |
| **Review only** | **14** | **Every layer and feature rule** — cross-feature imports, cycles, the `data/` prohibitions, `domain/` purity, `app/` feature-blindness, the suffix vocabulary |

### Nothing is invented, and the derivation is stated per invariant

Every guardrail traces to existing implementation, an accepted ADR, an approved Volume, the Constitution or the Vision. The authority column is not decoration — it is what makes a guardrail removable only by superseding the decision behind it, rather than by disagreeing with this document.

### Module-level dependency direction is recorded, since no ADR carries it

ADR-022 §5.1 fixes the **layer** import matrix. The **module** graph — nine modules, all depending on `core` and none on each other — comes from Volume 3 §3.5 §4 and appears in no ADR. It is recorded in the guardrails document with A-039's correction applied.

**Volume 3 §3.5's nine modules are the authoritative inventory:** `core`, `auth`, `onboarding`, `settings`, `projects_tasks`, `recording`, `upload`, `metadata`, `admin_shared`. ADR-022 §6.2 named five, which were illustrative of the procedure rather than a complete list. Where they differ, Volume 3 §3.5 is the inventory and ADR-022 §6 is the procedure.

### Four divergences from Volume 3 are registered, not silently taken

- **A-038** — Volume 3 §3.4's five layers and its uninverted `Domain → Data` arrow, against ADR-001's four layers with dependency inversion. ADR-001 governs; the divergence had never been written down.
- **A-039** — Volume 3 §3.5 §4's self-contradiction on cross-feature dependency. ADR-022 R3 resolves it in favour of the chapter's own closing rule, and the listed dependencies are recorded as conceptual rather than as permitted imports.
- **A-040** — Volume 3 §3.5 §2 gives the `core` module the `ProviderScope` setup and `go_router` configuration; ADR-002 places composition in `main.dart` and routing in `app/router.dart`.
- **A-041** — Volume 3 §3.4 §2 and §3.6 §5 name the State layer's classes `Notifier` and its files `_notifier.dart`; ADR-023 §4.2 requires `Controller`.

**A-041 is registered with a caveat against my own prior work.** ADR-023 §4.2 rejected `Notifier` on the grounds that it *"borrow[s] another framework's vocabulary"* — but `Notifier`, `AsyncNotifier` and `StreamNotifier` are Riverpod's own class names, so under ADR-003 that vocabulary is native rather than foreign. The stated reason does not hold for this term, even though it holds for `ViewModel` and `Bloc`. ADR-023 remains binding until superseded; the amendment records that the Volume's term may be the better one and flags the last cheap moment to change course.

### Volume clauses confirmed correct are recorded too

Seven are listed so they are not re-litigated — including **Volume 3 §3.4 §1**, whose *"never sideways across features without going through a shared layer"* is exactly ADR-022 R3. Recording this matters: it establishes that Volume 3 §3.5 §4's bullet list is the outlier within Volume 3 itself, not that ADR-022 diverges from Volume 3 as a whole.

### The verification commands are executable, and their exit codes are stated

The guardrails document carries a runnable script for the six invariants checkable against today's code, matching the capture-and-test pattern the CI workflow uses.

**The exit-code behaviour is documented explicitly** because it is inverted from the obvious reading: these checks pass when `grep` finds nothing, and `grep` exits `1` on no match — so a bare `grep` in a CI job reports failure exactly when the invariant holds. Stating this is the difference between a document someone can build a job from and one that produces a permanently red pipeline.

## Alternatives Considered

- **Write no guardrails document; the rules are already in ADR-022, ADR-025 and ADR-021.** Rejected. Those documents state the rules and are silent on enforcement, which is the question a reviewer actually has. It also leaves the fact that *every* layer and feature rule is unenforced spread across three documents' footnotes instead of visible as a single list of fourteen.

- **Implement the six checkable guardrails as a CI job in this mission.** Rejected, and it is the closest call. The mission's deliverables are two documents and its requirements are documentation-only. Writing the job would also be the wrong order: the register is what says which checks are worth writing, and it did not exist until now. Recorded as the highest-value follow-up.

- **Adopt `custom_lint` or an import-graph tool to close the unenforced set.** Rejected, consistent with A-026. The `Architecture boundaries` job already enforces the package rules with no dependencies, and extending it costs nothing. `custom_lint` would add seven dependencies and a second mechanism for one outcome — and most of the unenforced rules cannot be tested until `features/` has contents, so the tooling would arrive ahead of anything to check.

- **Resolve A-038 by adopting Volume 3 §3.4's five layers.** Rejected. ADR-001 is accepted and binding, the dependency inversion is the property that makes `domain/` testable without a widget tree — which Volume 3 §3.4 §5 itself claims as a benefit — and `core/errors/failure.dart` is already pure Dart *by necessity* for exactly that reason. The Volume's own stated goal is better served by ADR-001's arrow than by its own.

- **Resolve A-039 by permitting the cross-feature dependencies Volume 3 §3.5 §4 lists.** Rejected. The chapter's closing sentence forbids them and Volume 3 §3.4 §1 forbids them, so two of the three statements in Volume 3 agree with ADR-022 R3. Adopting the bullet list would make `upload` and `recording` one deployable unit while the folder tree still showed two.

- **Silently apply ADR-022 R3 and not register A-039.** Rejected. Volume 3 §3.5 §4's bullets are specific and plausible, and the next reader to reach for `upload → recording` will find the Volume authorising it. The register exists to make that disagreement explicit rather than latent.

- **Record only the unenforced invariants, since the enforced ones already work.** Rejected. The register's value is the comparison: seeing fifteen CI-enforced invariants about packages and secrets beside fourteen review-only invariants about layers is what makes the imbalance legible. A list of gaps alone reads as a backlog rather than as a shape.

- **Include a maturity target or a score.** Rejected. It would be a number with no authority behind it, and this document carries no preferences — only invariants with a stated derivation.

## Consequences

- **The unenforced set is now a visible list of fourteen**, six of which are checkable today with commands the document provides. That is a concrete backlog rather than a diffuse worry.

- **A guardrail can no longer be added without an authority and an enforcement column.** That friction is deliberate: an invariant with `Review` in the enforcement column is honest, and one with a blank column is how the register would stop being trustworthy.

- **A-038 leaves two readable descriptions of the layer architecture in circulation.** Volume 3 §3.4's five layers and ADR-001's four describe the same system with different names and one inverted arrow. Anyone reading Volume 3 alone will build the wrong dependency direction. The amendment records it; the Volume cannot be edited here.

- **A-039 hands the `recording`/`upload` question a documented answer before it is asked.** ADR-022 §6.2 already predicted the temptation; it now has the Volume citation on both sides and the resolution.

- **A-041 records a flaw in ADR-023, which this ADR cannot fix.** ADR-023 §4.2's reason for rejecting `Notifier` does not survive contact with the fact that `Notifier` is Riverpod's own type. The rule stands until superseded, so the repository will use `Controller` while Volume 3 says `Notifier` — a divergence with a weak justification, now on record rather than hidden.

- **The register will go stale unless missions update it.** Every future ADR that adds an invariant must add a row. This is the same maintenance obligation ADR-024 §30 places on counts, and it fails the same way — silently.

- **Nothing in the repository changed.** The guardrails hold today, verified by running each check, and recording them changes no behaviour. The value is entirely in what the next contributor can see.

## Related Missions

- Mission 0.18.1 — which removed the layer directories wrongly scaffolded at the root of `features/`, the defect that motivates the enforcement column.
- Mission 0.18.4 — CI, which built the nine jobs that constitute the enforced half of the register.
- Mission 0.19.2 — Folder architecture (ADR-022), whose import rules A-039 now reconciles with Volume 3 §3.5.
- Mission 0.19.3 — Naming conventions (ADR-023), whose §4.2 A-041 records as weakly justified.
- Mission 0.19.6 — Architecture Guardrails, which produced this ADR, the register, and amendments A-038 to A-041.

## Implementation Status

**Documented. The enforced half is enforced; the review-only half is not.**

`docs/architecture/architecture-guardrails.md` carries the register. Every invariant claimed to hold was verified by running its check against the working tree, not asserted:

| Verified | Result |
|---|---|
| Package confinement (I1–I4) | 4 of 4 pass |
| AWS SDK dependency, credential references, hardcoded endpoints (I5–I6) | none present |
| Credential-bearing files, AWS keys, private keys, service-account keys (I7) | none tracked |
| Environment sets across Dart / JSON / shell (I8) | agree — `development`, `staging`, `production` |
| Bucket names from the ADR-011 slug rule (I9) | `vump-platform-dev` / `-staging` / `-prod` |
| Region (I10) | `ap-south-1` in `environments.json` and `env.sh` |
| Generated code drift (I11) | none |
| `dart format`, 59 hand-written files (I12) | 0 changed |
| `flutter analyze` (I13) | no issues |
| `app/` importing `features/` (I30) | none |
| `core/` importing `app/theme/` (I31) | none |
| `app/config/` importing `core/` (I32) | none |
| Layer directories at the root of `features/` (I33) | none |
| Forbidden type suffixes (I35) | none across 48 declared types |
| `Failure` subclasses (I37) | none |

The §9 script was executed as written and exits `0`.

No code was changed. All four Volume citations were read from the source PDFs and quoted from the text extracted from them.

**Two errors in this mission's own draft were caught by verification and corrected.**

1. **The reading of Volume 3 §3.5 was incomplete and would have produced a wrong amendment.** The first draft, based on §3.5 §2's dependency table alone, was going to record that Volume 3 *permits* cross-feature dependencies and that ADR-022 R3 overrides it. Reading §3.5 §4 to the end changed the finding materially: the chapter's closing sentence forbids direct feature-to-feature dependency, so the chapter contradicts *itself* and ADR-022 R3 agrees with two of its three statements. The amendment as registered says something quite different — and more accurate — than the one nearly written.

2. **The §9 exit-code claim was wrong and would have broken any job built from it.** The draft stated that each command *"prints nothing and exits zero when the invariant holds"*. `grep` exits `1` on no match, so every check exited `1` in exactly the success case. Running the commands rather than reasoning about them caught it; §9 now uses the capture-and-test pattern and documents the inversion explicitly.
