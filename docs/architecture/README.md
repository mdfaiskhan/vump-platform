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

```
docs/
└── architecture/
    ├── README.md                 # This guide. Governs the process.
    └── decisions/                # One file per decision.
        ├── ADR-001-<title>.md
        ├── ADR-002-<title>.md
        └── ...
```

`README.md` describes the process. It never records a decision.

`volume-amendments.md` records corrections to the Volume 1–12 PDFs. Those are distributed as PDFs and cannot be edited here, so an ADR that supersedes a volume section registers the correction there. Where a volume and an accepted ADR disagree, the ADR governs.

`decisions/` holds the decisions themselves. It is a flat directory — no subfolders, no grouping by domain. Ordering is chronological by number, not thematic.

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

`decisions/` holds ADR-001 through ADR-020.

All are Accepted and therefore binding.

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
| ADR-009 | Local database architecture |
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

ADR-007 supersedes the networking assumptions of ADR-006 in part. ADR-006 remains Accepted and binding in every other respect.

Decisions still to be recorded: logging infrastructure, the HTTP client boundary, and runtime provisioning of build-time secrets. The logging and networking layers are implemented but undocumented.
