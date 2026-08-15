# Architecture Guide

The official architecture guide for Vump Technologies.

This document governs how architectural decisions are recorded, changed and retired.

---

## Single Source of Truth

Architecture documentation is the single source of truth.

Where code and an accepted ADR disagree, the ADR is correct and the code is a defect.

An architectural decision that is not recorded here does not exist. Verbal agreement, chat history, a comment in a pull request and an implementation detail in the codebase are all insufficient. If a decision matters, it is an ADR.

No implementation may contradict an accepted ADR.

---

## Purpose of ADRs

An ADR — Architecture Decision Record — is a short document capturing one architectural decision, the context that forced it, and the consequences accepted alongside it.

ADRs exist to answer the question *"why is it built this way?"* long after everyone who made the decision has forgotten.

They record:

- **The decision** — what was chosen.
- **The context** — the constraints and forces that made the choice necessary.
- **The alternatives** — what was rejected, and why.
- **The consequences** — what this costs, including what becomes harder.

They are immutable in spirit: an ADR is a historical record of what was decided at a point in time. Decisions are reversed by writing a new ADR, never by rewriting the old one.

An ADR is not a design document, a specification, a tutorial or a task list.

---

## Folder Structure

```text
docs/
└── architecture/
    ├── README.md                  # This guide. Governs the process.
    ├── architecture-guardrails.md # Every invariant, its authority, its enforcement.
    ├── aws-sdk-integration.md     # Implementation spec: how the app reaches AWS.
    ├── error-handling.md          # The error model and its boundary contract.
    ├── folder-structure.md        # The repository's folder and import rules.
    ├── logging-standards.md       # Levels, sinks, redaction, what never gets logged.
    ├── naming-conventions.md      # The canonical naming standard.
    ├── volume-amendments.md       # Corrections to the source volumes.
    └── decisions/                 # One file per decision.
        ├── ADR-001-<title>.md
        ├── ADR-002-<title>.md
        └── ...
```

`README.md` describes the process. It never records a decision.

Each reference document below specifies what an ADR decides; where the two disagree, the ADR governs. **Listed in ADR order.**

`folder-structure.md` (**ADR-022**) — root directory ownership, `lib/` responsibilities, feature layers, the import matrix, and the procedure for adding a feature.

`naming-conventions.md` (**ADR-023**) — the closed suffix vocabulary, every naming category from folders to JSON fields, and an audited register of known deviations. Cites rather than restates the conventions already fixed by `CLAUDE.md`, ADR-021 and the domain ADRs.

`error-handling.md` (**ADR-025**) — the two error representations, the exception hierarchy, the `ErrorCode` taxonomy, redaction, propagation by layer, and an audited register of known gaps.

`architecture-guardrails.md` (**ADR-026**) — the invariant register: every architectural invariant in force, the ADR or Volume it derives from, whether CI, the analyzer or a reviewer enforces it, and the command that verifies it. It duplicates no rule.

`logging-standards.md` (**ADR-027**) — the five levels and the environment that selects them, the sinks that exist and those that do not, where redaction happens and why `AppLogger` cannot do it, and the boundary between diagnostic and audit logging.

`aws-sdk-integration.md` — an implementation specification rather than a reference standard, and the only document here with no governing ADR. It describes how the backend reaches AWS and why the mobile app never holds a credential. Where it and an accepted ADR disagree, the ADR governs.

`volume-amendments.md` records corrections to the Volume 1–12 PDFs. Those are distributed as PDFs and cannot be edited here, so an ADR that supersedes a volume section registers the correction there. Where a volume and an accepted ADR disagree, the ADR governs.

Six further standards live in [`../development/`](../development/) because their reader is a contributor rather than an architect (ADR-024 §20), also in ADR order:

| Document | Fixes |
|---|---|
| [`documentation-standards.md`](../development/documentation-standards.md) (**ADR-024**) | How every document here is written — hierarchy, markdown conventions, terminology, RFC 2119 usage. Read before adding one |
| [`review-checklist.md`](../development/review-checklist.md) (**ADR-028**) | How any change is reviewed — which criteria CI gates, which the analyzer gates, which remain for a human. Implements Volume 3 Chapter 3.7 §9, which ADR-019 makes a merge condition |
| [`testing-standards.md`](../development/testing-standards.md) (**ADR-029**) | The pyramid, substitution with fakes, determinism, error-path coverage, and what Volume 9 requires that the repository does not have |
| [`dependency-management-standards.md`](../development/dependency-management-standards.md) (**ADR-030**) | Pinning tiers, the admission checklist, review cadence, and the toolchain constraint one unmaintained generator imposes |
| [`performance-standards.md`](../development/performance-standards.md) (**ADR-031**) | The ten numeric targets from Volumes 1, 4, 5 and 9, what measures each, and why the capture and UI frame rates are deliberately different |
| [`mission-review.md`](../development/mission-review.md) (**ADR-032**) | The audit of missions 0.19.1–0.19.11: structural integrity, inconsistencies found, missing governance, and next actions |

`decisions/` holds the decisions themselves. It is a flat directory — no subfolders, no grouping by domain. Ordering is chronological by number, not thematic.

### Logs

A log records state rather than fixing a rule, so it is not in the standards table above and has no governing ADR:

[`deferred-items.md`](../development/deferred-items.md) — known-incomplete implementation, each item with the mission that owns closing it. It decides nothing; every entry restates a fact already recorded in an ADR or a source comment. Not Volume 11's Risk Register (Ch. 11.4), Feature Tracker (Ch. 11.6) or Bug Tracker (Ch. 11.7) — the document itself records why it is none of the three.

---

## Naming Convention

```
ADR-NNN-kebab-case-title.md
```

- `ADR-` — a literal prefix on every file.
- `NNN` — a three-digit sequential number, zero-padded, starting at `001`.
- Numbers are never reused, never renumbered, and never skipped.
- The title is lowercase kebab-case, describing the decision, not the problem.
- The file extension is always `.md`.

Good:

```
ADR-003-state-management-riverpod.md
ADR-006-app-configuration.md
ADR-007-network-configuration.md
```

Bad:

```
ADR-8-storage.md               # not zero-padded, title too vague
ADR-009_local_database.md      # snake_case, describes a topic not a decision
ADR-010-how-should-we-do-auth.md  # a question, not a decision
```

Once a file is committed, its number and filename are permanent. A superseded ADR keeps its original name.

---

## ADR Lifecycle

```
Proposed ──► Accepted ──┬──► Deprecated
                        └──► Superseded by ADR-NNN
```

1. **Draft.** A new ADR is written with status `Proposed`. It is assigned the next free number at the moment it is written.
2. **Review.** The decision is discussed. A `Proposed` ADR may be edited freely — it is not yet binding.
3. **Accept or reject.** On approval the status becomes `Accepted` and the ADR is binding from that moment. A rejected proposal is either deleted before commit or retained with status `Deprecated` and a note explaining the rejection.
4. **Retire.** An accepted ADR is never edited to change its decision. It is retired by moving to `Deprecated` or `Superseded`.

An ADR is binding only while `Accepted`. Implementation must comply with every accepted ADR and no others.

---

## Status Meanings

### Proposed

The decision is drafted but not yet approved.

Not binding. Must not be implemented against. A `Proposed` ADR may be edited, renumbered before commit, or abandoned entirely.

### Accepted

The decision is approved and in force.

Binding on all implementation. The content must not be edited to change the decision — corrections limited to typos, formatting and broken links are permitted. Anything that alters meaning requires a superseding ADR.

### Deprecated

The decision no longer applies, and nothing replaced it.

Used when a decision has simply been retired — the feature was removed, the constraint disappeared, the problem no longer exists. Not binding. The file remains in place as a historical record.

### Superseded

The decision has been replaced by a newer ADR.

The status line must name the replacement: `Superseded by ADR-007`. The replacing ADR must reference the one it supersedes. Not binding. The file remains in place — the trail from old decision to new is the point.

---

## When to Create a New ADR

Create a new ADR when a decision:

- Introduces, replaces or removes a core technology or package.
- Defines or changes a layer boundary, module boundary or dependency direction.
- Establishes a cross-cutting pattern — error handling, logging, navigation, state management, persistence, serialization.
- Determines how data is stored, cached, encrypted or transmitted.
- Sets an authentication, authorization or security posture.
- Is costly to reverse later.
- Would otherwise be discovered only by reading the implementation.

Create a new ADR to **reverse** an existing decision. The new ADR takes the next number, states the new decision, and marks the previous one `Superseded`.

Do not create an ADR for: naming and formatting conventions, choosing a widget, a bug fix, a refactor that preserves structure, or anything already fixed by an accepted ADR.

When in doubt, write one. An unnecessary ADR costs a page. An unrecorded decision costs an archaeology expedition.

---

## When to Update an Existing ADR

An **accepted** ADR may be updated only for changes that do not alter its meaning:

- Fixing a typo or grammatical error.
- Correcting formatting or a broken link.
- Adding a cross-reference to a related ADR.
- Changing its status as part of the lifecycle above.

An accepted ADR must **never** be updated to:

- Change the decision.
- Add, remove or reinterpret a constraint.
- Retrofit a justification for something already built.
- Reflect what the code actually does.

That last point is the one that matters most. When code and an accepted ADR disagree, the ADR is not updated to match the code. Either the code is fixed, or a new ADR is proposed and accepted to change the decision — and only then is the code correct.

A **proposed** ADR may be edited freely until it is accepted.

---

## ADR Template

```markdown
# ADR-NNN — <Decision Title>

- **Status:** Proposed | Accepted | Deprecated | Superseded by ADR-NNN
- **Date:** YYYY-MM-DD
- **Supersedes:** ADR-NNN (omit if none)

## Context

The forces at play. Constraints, requirements and the problem being solved.
Written so a reader who was not present can understand why a decision was needed.

## Decision

What was chosen. Stated plainly, in the active voice.

## Alternatives Considered

What else was evaluated, and the specific reason each was rejected.

## Consequences

What follows from this decision — including what it makes harder, what it
forecloses, and what must now be maintained.
```

---

## Current State

`decisions/` holds ADR-001 through ADR-039.

All are Accepted and therefore binding, except ADR-021 (**Superseded** by ADR-038) and ADR-009 (**Superseded** by ADR-039).

| ADR | Decision |
|---|---|
| ADR-001 | Clean Architecture — four layers per feature |
| ADR-002 | Top-level project structure |
| ADR-003 | Riverpod for state management |
| ADR-004 | GoRouter for navigation |
| ADR-005 | Token-based Material 3 theme system |
| ADR-006 | Centralised application configuration |
| ADR-007 | Network configuration and environment selection |
| ADR-008 | Secure storage for secrets |
| ADR-009 | Local database architecture (**superseded by ADR-039**) |
| ADR-010 | Firebase platform integration |
| ADR-011 | S3 storage architecture |
| ADR-012 | S3 lifecycle and retention |
| ADR-013 | Legal hold enforcement |
| ADR-014 | Environment strategy |
| ADR-015 | Backend runtime |
| ADR-016 | Secrets management |
| ADR-017 | Environment-driven startup failure |
| ADR-018 | Environment profile as the single read surface |
| ADR-019 | Branching strategy |
| ADR-020 | Commit convention |
| ADR-021 | Static analysis configuration (**superseded by ADR-038**) |
| ADR-022 | Folder architecture and import rules |
| ADR-023 | Naming conventions |
| ADR-024 | Documentation standards |
| ADR-025 | Error handling model |
| ADR-026 | Architecture guardrails |
| ADR-027 | Logging architecture |
| ADR-028 | Review checklist |
| ADR-029 | Testing standards |
| ADR-030 | Dependency management |
| ADR-031 | Performance standards |
| ADR-032 | Mission review and documentation maintenance rules |
| ADR-033 | Database startup failure policy |
| ADR-034 | Firebase Authentication integration |
| ADR-035 | Authenticated requests and token refresh |
| ADR-036 | Invite-code redemption runtime (**temporary**) |
| ADR-037 | Route guards |
| ADR-038 | Static analysis for generated collections |
| ADR-039 | Feature-owned Isar collections |

ADR-038 supersedes ADR-021 solely to correct one section. ADR-021 claimed `isar_generator` emits its own `ignore_for_file` header; it emits none, and the claim was verified only in a directory where the rule it would have tripped is not enabled. ADR-021 is marked Superseded and left otherwise untouched, incorrect paragraph included, so the error stays legible. Everything else it decided is carried forward unchanged.

ADR-039 supersedes ADR-009 on two points: the `isar` confinement now covers `core/database/` plus a feature's `data/collections/` and its `data/isar_*.dart`, and `local_task_cache` is assigned to `features/projects_tasks/`. It follows the line ADR-034 drew for Firebase — the engine belongs to `core/`, the collections belong to the feature that consumes them, which is what keeps the feature the replaceable unit. Everything else ADR-009 decided is carried forward and still binding; it is marked Superseded and left otherwise untouched.

ADR-007 supersedes the networking assumptions of ADR-006 in part. ADR-006 remains Accepted and binding in every other respect.

ADR-032 refines ADR-024 in three respects — counts are measured after staging, templates are exempt from the precedence rule, and a terminology check must exclude backticked and quoted spans. ADR-024 remains Accepted and binding in every other respect.

ADR-033 departs from ADR-017's Consequences in one respect. ADR-017 recommends that any future startup prerequisite — naming the database and secure storage — use its environment-driven shape. ADR-033 declines that for the database and makes an open failure fatal in every environment, because ADR-017's development tolerance exists to absorb a missing network and a missing configuration, and a local database needs neither. ADR-017 remains Accepted and binding for Firebase and in every other respect; secure storage is still undecided.

ADR-022 refines ADR-002 in one respect: `app/router.dart` is the single file in `app/` permitted to import from `features/`, because ADR-004 requires one route table and a route table must name its screens. ADR-002 remains Accepted and binding in every other respect.

ADR-037 discharges the guard ADR-004 deferred, and is recorded there as a dated correction rather than by editing ADR-004's decision. ADR-004 remains Accepted and binding: its route table is still declared in one place, and only its statement that no redirects exist has been overtaken.

ADR-036 is the only accepted ADR that contradicts another on purpose. ADR-015 fixes the backend runtime as AWS Lambda; ADR-036 adds a Firebase Cloud Function beside it, because writing a Firebase custom claim from Lambda would require a long-lived service-account key that can grant `admin` on any organisation. It is explicitly temporary and is retired at Mission 6/7, at which point it is superseded rather than amended. ADR-015 is unchanged and still governs every other endpoint.

ADR-035 resolves the one case ADR-022's `core/` ↛ `features/` rule had no answer for. `AuthInterceptor` lives in `core/network/` and needs a token `features/auth/` owns; rather than relax the rule, `core/network/` declares the `AuthTokenSource` interface and the composition root supplies the implementation — ADR-001's dependency inversion applied between a `core/` module and a feature. ADR-022 is unchanged and its rule now has a machine-checked invariant, I41.

ADR-034 extends ADR-010 to the first Firebase product. ADR-010 confines the Firebase *platform* to `core/firebase/` and declines to decide anything about products until one has a consumer; ADR-034 confines `firebase_auth` and `google_sign_in` to `features/auth/data/` instead, because a product has one consumer and putting it in `core/` would place feature code there. ADR-010 remains Accepted and binding in every respect, including for `firebase_core`.

Decisions still to be recorded: the HTTP client boundary, and runtime provisioning of build-time secrets. The networking layer is implemented but its client boundary is undocumented — ADR-007 fixes its configuration, and `error-handling.md` §8 fixes its error conversion, but the interceptor chain and `DioClient`'s contract have no record of their own.

Logging was on this list until Mission 0.19.7 and is now recorded by **ADR-027**.
