# ADR-028 — Review Checklist

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Implements the checklist Volume 3 Chapter 3.7 §9 fixes and ADR-019 already makes binding. Registers A-044.

## Context

**The review checklist already exists and is already binding. It has never been usable.**

Volume 3, Chapter 3.7 §9 is titled *"Code Review Checklist"* and states: *"Every pull request is checked against this list before merge."* Volume 7 §7.6 points at it by name. Volume 9 §9.1 §3 defines a rule and says *"enforced at code review (Volume 3, Chapter 3.7's checklist already lists this)"*. ADR-019 makes it a merge condition: a pull request must *"satisfy the review checklist in Volume 3, Chapter 3.7 §9"*.

Four documents therefore require compliance with a six-item checklist that exists only inside a PDF, is not reproduced anywhere in the repository, and whose items reference chapters (3.4, 3.5) that four amendments have since corrected.

**What exists in the repository instead is partial and mis-aimed.** `.github/pull_request_template.md`, written in Mission 0.16, has 17 checkboxes. Seven select the change type. Of the remaining ten, **five duplicate a CI job** — `flutter analyze`, `flutter test`, `dart format`, the four package confinements, and the secret check. The template also predates ADR-021 through ADR-027 and mentions only ADR-007 and ADR-009: **no error-handling, logging, naming or documentation criterion appears in it at all.**

So the repository asks a human to re-verify five things that cannot reach review, and asks nothing about the seven standards written since.

**Two facts make the human half weaker than it looks, and both are already recorded.** ADR-019 sets required approvals to **zero** while the team is one person, and states the consequence: *"Zero required approvals today is a real gap, not a solved problem. CI catches what CI can check; nothing catches a bad decision that compiles."* ADR-026's register then shows that **14 of 38 architectural invariants are enforced by review only** — and that every layer and feature invariant is in that group.

The scarcest resource in this process is reviewer attention, and it is currently pointed at the wrong things.

**Reading Volume 9 for this mission surfaced a chapter Mission 0.19.7 missed.** Volume 9 Chapter 9.2 is titled *"Logging — What Gets Logged, at What Level, and for How Long"* and declares itself an extension of Volume 3 §3.7 §6. It was not consulted when ADR-027 and `logging-standards.md` were written, and it contradicts them in three places. Recorded as **A-044**, and the reference document is corrected.

## Decision

### The checklist is partitioned by mechanism, not by topic

`docs/development/review-checklist.md` is the canonical review checklist. Its organising principle is that **every criterion is checked by exactly one of four mechanisms** — the analyzer, CI, the author before pushing, or a reviewer — and that a criterion checked by a machine **must not appear on a human checklist**.

ADR-020 already states the principle for formatting: *"format is exactly what a machine checks better than a human, and a reviewer's attention is better spent on the change."* This ADR generalises it and applies it to the whole checklist.

§2 therefore lists what is already gated — nine CI jobs and the analyzer rules that subsume them — and instructs reviewers not to check any of it. §4 contains only what no machine can check.

### Volume 3 §3.7 §9's six items are reproduced with their mechanisms

Each of the six is mapped to the mechanism that checks it and the document that carries the detail. Two need correction rather than transcription:

- **Item 2** allows a cross-module dependency that is *"justified and documented"*. ADR-022 R3 forbids cross-feature imports outright, and Volume 3 §3.5 §4's own closing rule agrees (A-039). A reviewer does not weigh a justification — they reject the import.
- **Item 4** has two halves, and only one is automated. CI proves analysis is clean; it does not prove cleanliness was not bought with an `// ignore`. The reviewer checks the justification, not the presence, because `document_ignores` already makes an undocumented suppression a diagnostic.

### The author/reviewer distinction is made explicit

Today, with zero required approvals, **the author performs the reviewer checklist on their own change.** The standard says so rather than implying a second person exists, and §6's sequence shows the author running the four CI-gated commands *before* pushing — so a failure is local rather than public.

This is weaker than review by a second person. `branching-strategy.md` already sets the trigger to change it: raise approvals to 1 before the second engineer's first pull request.

### An automated item is deleted from the human checklist, not kept "for safety"

§8 makes this a maintenance rule: **when a criterion becomes automated, it moves to §2 and is removed from §4.** A checklist that only grows stops being read, and every item automated is attention returned.

This is what makes ADR-026 §10's six checkable-but-unchecked guardrails worth closing: each one moved is one fewer thing a human must remember.

### Absences are recorded, not filled

Two findings are recorded as absences rather than turned into rules:

**No Volume 1 requirement ID appears anywhere in `lib/` or `test/`**, though Volume 3 §3.7 §9 item 3 requires business rules to cite one. This is **correct today, not a violation**: `lib/features/` is empty, so no Volume 1 business rule has been implemented. What exists instead is 54 ADR citations across 10 distinct ADRs in `lib/` doc comments — the same discipline applied to the decisions that have been implemented.

**No review item is machine-verified as having been performed.** Ticking a box asserts a check happened; it is not evidence. This is inherent to human review and is stated so the boxes are not mistaken for gates.

### Documentation review is referenced, not restated

ADR-024 §28 is already a 16-item documentation review checklist. §4.8 cites it and adds only the two items specific to reviewing a *change* rather than a document: an edit that alters what is permitted is an ADR amendment, and a Volume deviation is registered rather than silently taken.

## Alternatives Considered

- **Rewrite `.github/pull_request_template.md` instead of writing a document.** Rejected for this mission, and it is the closest call. The template is where a contributor actually is, and it should carry §4's groups — but it cannot carry the reasoning, the citations or the mechanism partition without becoming unusable at the point of filling in a form. The document is the reference; extending the template is the follow-up it now specifies. Recorded as the first gap in §7.

- **Reproduce Volume 3 §3.7 §9 verbatim and stop.** Rejected. Two of its six items need correcting against amendments taken since (A-039), one references a lint that is not enabled (A-025, A-034), and it says nothing about error handling, logging or documentation, because ADR-025, ADR-027 and ADR-024 did not exist when it was written. A verbatim copy would be binding and wrong in two places.

- **Organise the checklist by topic — code, architecture, docs — without the mechanism partition.** Rejected. That is the shape the PR template already has, and it is how five boxes ended up duplicating CI. Topic tells a reviewer where to look; mechanism tells them whether to look at all, which is the more valuable of the two.

- **Keep the CI-duplicating items on the human checklist as a safety net.** Rejected. They cannot reach review — a change failing them cannot merge — so the "safety" is imaginary while the attention cost is real. They are retained in §6 as *author* self-checks before pushing, which is the only place they do work.

- **Require one approval now to close the review gap.** Rejected, and not this ADR's decision to make: ADR-019 already settled it, on the ground that GitHub forbids self-approval so the rule would be bypassed on day one, and *"a bypassed rule is worse than an absent one."*

- **Implement the six checkable guardrails as CI checks in this mission.** Rejected as out of scope — documentation only — but §8 makes moving them the standing mechanism for shrinking the human checklist.

- **Add a review criterion for requirement-ID traceability enforced by grep.** Rejected as inventing enforcement. Volume 3 §3.7 §9 item 3 asks whether *non-obvious business rules* cite an ID — a judgement about which rules are non-obvious, which no grep makes. Recorded as a reviewer item, with the audit finding that no such rule exists yet.

- **Fold the review checklist into ADR-026's guardrail register.** Rejected. The register answers *"what is invariant and what enforces it"*; the checklist answers *"what do I do when reviewing this change"*. They share the enforcement column and differ in audience and shape — the register is a reference table, the checklist is a procedure.

## Consequences

- **Reviewer attention is now pointed at the 14 review-only invariants and the error, logging, naming and documentation standards** — none of which the PR template asked about.

- **The checklist will shrink as automation grows**, which is the opposite of how checklists usually behave, and it is enforced by §8's maintenance rule rather than by good intentions.

- **The PR template is now known to be out of date**, with the specific gap named: five CI-duplicating boxes and nothing from seven ADRs. Extending it is a small, specified change.

- **The zero-approval gap is stated in the document a reviewer reads**, not only in ADR-019. Anyone using this checklist knows they are reviewing their own change and what that costs.

- **A-044 corrects three claims in ADR-027's reference document.** `logging-standards.md` said no Volume required contextual log fields — Volume 9 §9.2 §2 requires `chunk_id`/`session_id` by name. It framed the missing remote sink as the gap — V9.2 §3 forbids off-device transmission and specifies a ring buffer plus Crashlytics attachment instead. And the production level policy suppresses `info`, which V9.2 §1 wants visible in production. The reference is corrected; ADR-027 stands, with A-044 recording where its Volume basis was incomplete.

- **Volume 9 Chapter 9.2 was missed once, which is evidence the reading list is not self-verifying.** Mission 0.19.7's brief named Volumes 3, 4 and 6; the logging chapter is in Volume 9. A mission that reads only the volumes it is told to read can miss the chapter that governs its subject.

- **Ticking a box remains an assertion, not evidence.** No mechanism verifies a human check occurred, and §7 says so, so the checklist is not mistaken for a gate.

- **Nothing in the repository changed.** No code, no CI job, no template — the checklist is a document, and the gaps it names are the work it specifies.

## Related Missions

- Mission 0.16 — Git & GitHub Foundation, which produced the pull request template this ADR finds out of date.
- Mission 0.18.2 — Branch Strategy (ADR-019), which made Volume 3 §3.7 §9 a merge condition and set approvals to zero.
- Mission 0.19.6 — Architecture guardrails (ADR-026), whose enforcement column this checklist consumes.
- Mission 0.19.7 — Logging standards (ADR-027), whose Volume basis A-044 completes.
- Mission 0.19.8 — Review Checklist, which produced this ADR, the checklist, and amendment A-044.

## Implementation Status

**Documented. Enforced by CI for 15 criteria, by the analyzer for 9, and by the author for the rest — with zero required approvals.**

`docs/development/review-checklist.md` carries the checklist. Verified by audit:

| Audited | Result |
|---|---|
| CI jobs, all required by ADR-019's protection rules | **9** |
| Criteria gated by CI or the analyzer | 24 (ADR-026 I1–I24) |
| Invariants enforced by review only | **14** (ADR-026 I25–I38) |
| Required approvals today | **0** — ADR-019, team of one |
| `pull_request_template.md` checkboxes | **17** — 7 select the type; 5 of the remaining 10 duplicate a CI job |
| ADRs referenced by the template | **2** — ADR-007, ADR-009. None of ADR-021 to ADR-027 |
| Error-handling, logging, naming or documentation criteria in the template | **0** |
| Volume 1 requirement IDs in `lib/` or `test/` | **0** — correct; no Volume 1 business rule is implemented |
| ADR citations in `lib/` doc comments | **54**, across 10 distinct ADRs |
| `ignore` comments in hand-written Dart | **0**. One `ignore_for_file` exists, in flutterfire-generated `firebase_options.dart` |
| `CODEOWNERS` | Absent; required at 5+ engineers |
| `flutter analyze` | No issues |

No code was changed. Volume 3 §3.7 §9, Volume 7 §7.6, Volume 9 §9.1, §9.2 and §9.5 were read from the source PDFs and quoted from the extracted text.

**Two errors in this mission's own draft were caught by verification and corrected.**

1. **The pull request template's checkbox count was wrong.** The draft said ten boxes, five duplicating CI. There are **17**: seven select the change type, leaving ten criteria, five of which duplicate CI. The ratio that matters was right; the number was not, and it is the kind of figure a reader would check.

2. **`logging-standards.md` §7 asserted that no Volume requires contextual log fields.** Volume 9 §9.2 §2 requires `chunk_id`/`session_id` on every log line touching a chunk or session. The claim was false, it was load-bearing — it justified recording the absence as neutral rather than as a deviation — and it existed because Volume 9 was outside Mission 0.19.7's reading list. Corrected in place, with the correction marked, and registered as A-044.
