# ADR-024 — Documentation Standards

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Records the documentation practice established across ADR-001 to ADR-023 and fixes the gaps. See amendments A-032, A-033 and A-034.

## Context

This repository is documentation-first by constitution. Volume 0, Chapter 0.2 §1 states it twice over: *"Every decision is written down. A choice that is not recorded in these documents does not count as decided — it will be re-litigated the next time it comes up"*, and *"Documentation drives code, not the other way around."* Thirty-eight markdown files carry 23 architecture decisions, four reference standards, an amendment register, three runbooks and the templates.

None of it is governed. There is no standard for how any of those documents is written.

**The practice exists but is unrecorded, and it is unusually consistent.** An audit of all 38 files found: zero heading-level skips, zero broken internal links, zero non-enclosed table rows, zero trailing whitespace, a maximum heading depth of H3 everywhere, exactly one H1 per document, all 23 ADRs carrying the four required sections with a `Status` and an ISO date, and — a convention nobody wrote down — **zero horizontal rules in any ADR** against 3 to 11 in every prose document. That consistency is currently one author's habit across eleven missions. The next contributor breaks none of it, because none of it is a rule.

**Three specific gaps make this a decision rather than a tidy-up.**

**The Constitution's documentation rules do not fit a git repository, and nobody has said so.** Chapter 0.2 §5 requires documentation files to be named `Chapter_<volume>.<chapter>_<Title>.docx`; §8 requires every document to carry a version number and status in a Document Control block. Both are correct for the volumes — `.docx` deliverables outside version control, with no other way to identify their current state — and neither transfers to markdown in git. ADR-023 §1.4 already fixed documentation filenames as `kebab-case.md` **without recording that it diverges from the Constitution**, which is exactly the latent disagreement the amendment register exists to prevent.

**The Glossary is authoritative and unused.** Volume 0, Chapter 0.3 states: *"This glossary is the authoritative definition of every recurring term used across Volumes 0–12. If a later document uses one of these words differently, the later document is wrong."* No document in this repository references it. The repository is in fact compliant — `Collector` is capitalised 4 times out of 4, `Client` 3 times as the customer organisation against 47 lowercase uses meaning an HTTP client, `Project` 7 times as the Glossary entity against 59 meaning this software project — but the reason it works is unstated, so the first "the client owns the project" will mean neither.

**Fifty of seventy-nine code fences declare no language**, while ADR-021 makes `missing_code_block_language_in_doc_comment` an enforced lint on Dart doc comments. The same requirement, on the same kind of content, holds in one file type and not the other. There is no reason for the asymmetry; there was simply never a rule.

`backend/` is empty and `lib/features/` is empty. Every document either exists and is consistent, or does not exist yet.

## Decision

### One canonical standard, in `docs/development/`

`docs/development/documentation-standards.md` is the canonical documentation standard. Thirty numbered sections cover purpose, hierarchy, single-source-of-truth rules, what belongs in each of the seven document types, markdown mechanics, language, terminology, references, versioning, examples, RFC 2119 usage, diagrams, images, deprecation, the amendment process, a review checklist, the lifecycle, and maintenance rules with an audited deviation register.

It follows the ADR-plus-reference pattern established four times over — ADR-019/`branching-strategy.md`, ADR-020/`commit-conventions.md`, ADR-022/`folder-structure.md`, ADR-023/`naming-conventions.md`.

**Placement is in `docs/development/`, not `docs/architecture/`.** The document governs writing and its reader is a contributor, alongside `secrets-management.md`. `docs/architecture/` is for decisions and the architecture references; an architect looking for the binding decision finds this ADR. The standard states this reasoning in its own §20, because placement is the first thing it tells others to get right.

**The standard is derived, not invented.** Every rule was measured against the corpus by command. Where the corpus was unanimous, the existing practice became the rule and the count is recorded. Where it was not, the deviation is registered rather than resolved by rewriting 38 files.

### Nothing already governed is restated

The standard opens with a table of what is fixed by the Constitution, the Glossary, `CLAUDE.md`, `docs/architecture/README.md`, and ADRs 019 through 023 — and cites rather than duplicates each. Documentation filenames, heading case, the ADR template, the ADR lifecycle, the `docs` commit type and the volume change-management process are all referenced and none is repeated.

### Nine document types, each with one job

The hierarchy is made explicit: source volumes, the constitution, ADRs, the amendment register, the process guide, reference standards, implementation specifications, runbooks, and orientation READMEs. Each gets its location, its authority level, and — the part that matters — **when it is allowed to change.**

That last column is the useful one. An ADR never changes; a reference document is *expected* to change and is wrong the moment it stops matching practice; an amendment entry is append-only. Conflating "immutable historical record" with "living specification" is how an ADR ends up being edited to match the code.

### Every non-ADR document states its own precedence

One sentence, in the opening lines: *"Where this document and the ADR disagree, the ADR governs."* Ten of fourteen documents already carry it, including `aws-sdk-integration.md`, which is where the form originated. The four that do not are recorded.

This is the smallest possible mechanism for the biggest governance risk: a reader who finds a rule in a reference document and does not know whether it outranks the code, the volume, or nothing at all.

### RFC 2119: declarative prose by default, keywords only where strength is ambiguous

The repository uses **zero** RFC 2119 keywords across 38 files, and its rules are not weaker for it. *"Dependencies point inward"* is not less binding than *"dependencies MUST point inward"* — it is shorter and reads as prose.

Blanket adoption is rejected. It would mean either rewriting every existing document or maintaining two registers of normativity, and the benefit is nil where the declarative form is already unambiguous.

`MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT` and `MAY` are permitted, uppercase, with their RFC 2119 meanings, **only where the strength of a rule would otherwise be genuinely ambiguous** — chiefly beside a `SHOULD`, or where a reader might read a requirement as advice. `SHALL`, `REQUIRED`, `RECOMMENDED` and `OPTIONAL` are not used: they add synonyms without adding distinctions.

The accompanying interpretive rule is the load-bearing part: **a requirement expressed in declarative present tense is a requirement, and the absence of `MUST` makes nothing optional.** Without it, adopting the keywords at all would retroactively weaken every rule already written.

The most valuable keyword is `SHOULD`, because it is the only one that says *"this has exceptions and you must justify yours"* — which declarative prose cannot express in fewer than a paragraph.

### The Glossary is the terminology authority

Volume 0, Chapter 0.3 governs the meaning of every recurring domain term. A defined term carries its defined meaning, and the business-role terms are **capitalised when used in their defined sense** — because for `Client`, `Project`, `Collector` and `Session` the lowercase form already means something else in this repository, and the collision is live rather than theoretical.

`Vump Technologies` is the project name (ADR-011). "Human Archive" appears only when quoting a source being corrected — verified: all nine occurrences are in ADR-011 or the amendment register, and every one is a quotation.

### No images, ASCII diagrams only

The repository contains zero images, and this is the standard rather than an accident. An image cannot be diffed, so a change to it is invisible in review; cannot be searched; goes stale silently, so a screenshot of a changed UI is confidently wrong; and lives in git history at full size forever.

Diagrams are ASCII in a `text` fence, with **every arrow labelled** — an unlabelled arrow could mean depends-on, calls, contains or becomes. Mermaid is not adopted: it renders on GitHub and nowhere else in this toolchain, so a Mermaid diagram is invisible in a terminal, in a diff, and in a plain editor, which is where most of this documentation is read.

### Versioning is git, not a Document Control block

Markdown documents carry no version number and no revision history. `git log --follow` gives every change with its author, date, reason and diff, exactly and without maintenance.

ADRs carry `Status` and `Date` because `Proposed`/`Accepted`/`Deprecated`/`Superseded` is a **lifecycle state** that determines whether the document is binding — not a version. Dates are ISO 8601.

This diverges from Constitution §8 and the divergence is registered as **A-033** rather than left implicit.

### Deviations are recorded, not fixed

Six deviations were found and none is fixed here. Existing documents are not rewritten by this mission, and modifying accepted ADRs is forbidden by its terms. Each is recorded with its disposition — most notably the 50 unlabelled code fences, of which 13 files are accepted ADRs eligible for a formatting correction under `docs/architecture/README.md`, but only as a deliberate pass rather than as a side effect of unrelated work.

## Alternatives Considered

- **Write no standard; the practice is already consistent.** Rejected, and this was the closest call — the audit found a remarkably clean corpus. But that consistency has one author and no rule behind it. The first contributor to add an H4, an unlabelled fence, a duplicated rule or an image breaks nothing written down. Consistency that survives only while one person maintains it is not a standard.

- **Adopt an external style guide** — the Google, Microsoft or Divio documentation frameworks. Rejected as a poor fit rather than as wrong. Each assumes a rendered documentation site with a build step, an audience of external users, and a product-manual structure. This repository has none of those: its documentation is read in a terminal, in a diff, and in an editor, by people changing the system. Divio's four-quadrant model in particular assumes tutorials and how-to guides, which this repository deliberately does not have.

- **Adopt RFC 2119 wholesale and rewrite existing documents in `MUST`/`SHOULD` form.** Rejected. It would touch all 38 files, including 23 accepted ADRs this mission is forbidden to modify, and would make every existing rule ambiguous in the interim — a rule not yet converted would read as weaker than one that had been. The narrow adoption plus the interpretive rule gets the distinction where it is needed at no cost.

- **Reject RFC 2119 entirely.** Rejected as insufficient. `SHOULD` expresses something declarative prose genuinely cannot: a rule with legitimate exceptions that must be justified. Forbidding the keyword would mean spending a paragraph each time that arises.

- **Place the standard in `docs/architecture/`** beside `folder-structure.md` and `naming-conventions.md`. Rejected. Those two specify the architecture; this one specifies how to write, and its reader is anyone opening a markdown file. `docs/development/` already holds exactly this kind of practice document.

- **Fix the 50 unlabelled code fences as part of this mission.** Rejected. Thirteen of the affected files are accepted ADRs. `docs/architecture/README.md` does permit formatting corrections to an accepted ADR, so this is not forbidden in principle — but a 26-file diff bundled into the commit that establishes the standard would make both unreviewable, and the mission's terms are explicit about not modifying accepted ADRs.

- **Rename or delete `docs/Teams_work.txt`.** Rejected, and recommended instead. Its contents were reviewed for this mission: a table allocating AI tools to workstreams — a personal working note rather than repository documentation. Relocating or deleting someone's working note is a decision about their material, not a naming fix.

- **Require a version number and changelog block in every document**, complying literally with Constitution §8. Rejected. It is a second source of truth that goes stale the first time someone edits without bumping it, in a repository where git already holds the authoritative history. Registered as an amendment rather than silently ignored.

- **Adopt Mermaid for diagrams.** Rejected. It renders on GitHub and nowhere else here, so it is invisible in the terminal, the diff and the editor. Worth revisiting only if the documentation gains a rendered site.

## Consequences

- **The documentation conventions are now checkable at review**, and six of them are mechanically checkable: one H1, no skipped levels, no unlabelled fence, no broken internal link, no trailing whitespace, trailing newline. A script over `git ls-files '*.md'` covers all six.

- **None of it is checked today.** This is a convention enforced by reviewers, and it will drift without them — the same position ADR-020 and ADR-023 are in, and this repository already knows what that costs. The CI job is named in the standard's §30 as the intended mechanism and is not implemented.

- **Three latent conflicts with the Project Constitution are now explicit** (A-032, A-033, A-034) instead of being differences nobody had noticed. **A-034 is the consequential one:** Constitution §4 requires a documentation comment on *every* public class, method and non-trivial function, and the Constitution overrides later volumes — so it outranks Volume 3 §3.7 §2's narrowing of `public_member_api_docs` to `domain/` and `data/`. Amendment A-025 was written on the assumption that Volume 3's scoping was the binding requirement. It is not. Re-measuring for A-034 also surfaced an obstacle A-025 did not record: of the 167 findings the rule produces, **45 are in generated code** that `isar_generator` does not cover in its `ignore_for_file` header and that nobody may edit — so enabling the rule collides with ADR-021's decision to analyse generated output.

- **The Glossary becomes load-bearing.** Any document using `Session`, `Chunk`, `Collector`, `Client`, `Project` or `Task` loosely is now a defect rather than a stylistic preference. This is a real constraint on future writing and the correct one — those six words are the ones most likely to be used carelessly.

- **`docs/development/` gains a second document and becomes the home for practice standards.** Anyone looking for a standard now has two plausible directories, `architecture/` and `development/`, which is one more than ideal. The standard's §20 states the split by audience so the question has an answer.

- **The no-images rule will eventually be inconvenient.** A design decision about a UI is genuinely easier to justify with a screenshot. The rule permits one, in `assets/`, with alt text and a prose description — and requires the document to survive without it.

- **50 unlabelled code fences remain**, across 26 files including 13 accepted ADRs. Anyone auditing markdown will find them; the register shows they were counted rather than missed.

- **`mobile/README.md` is corrected by this mission** — it was the unmodified Flutter template ("A new Flutter project"), and it is the worked example of §4's README rules. It was the only substantive documentation defect the audit found, as opposed to a convention gap.

## Related Missions

- Mission 0.19.1 — Static analysis configuration (ADR-021), which enforces the doc-comment fence rule this standard mirrors for markdown.
- Mission 0.19.2 — Folder architecture (ADR-022), which fixes document placement.
- Mission 0.19.3 — Naming conventions (ADR-023), which fixes documentation filenames and heading case, and which A-032 now reconciles with Constitution §5.
- Mission 0.19.4 — Documentation Standards, which produced this ADR, the standard, and amendments A-032 to A-034.

## Implementation Status

**Documented. Enforced by review; six rules are mechanically checkable and unchecked.**

`docs/development/documentation-standards.md` carries the standard. Every claim in both documents was produced by a command against the repository rather than asserted:

| Audited | Result |
|---|---|
| Tracked markdown files | 38 (excluding one 4-line Flutter platform template) |
| Documents with exactly one H1 | 37 of 38 — the exception is the PR template, correctly |
| Heading level skips | **0** |
| Maximum heading depth | H3, in every file |
| Broken internal links | **0** |
| Non-HTTPS external links | **0** |
| Non-enclosed table rows | **0** |
| Lines with trailing whitespace | **0** |
| Files not ending in a newline | 1 (`CLAUDE.md`) |
| ADRs with all four required sections, `Status`, ISO `Date` | 24 of 24 |
| ADRs containing a horizontal rule | **0 of 24** |
| ADR filenames matching the convention | 24 of 24 |
| Code fences declaring no language | 50 of 79, across 26 files |
| RFC 2119 keywords in use before this mission | **0** |
| Stale "Human Archive" references | **0** — all 9 are quotations of a source being corrected |
| Terminology variants (`Github`, `pre-signed`) | **0** |

`flutter analyze` reports no issues; no code was changed.

The new and changed documents were checked against the standard they define: one H1 each, maximum depth H3, zero skipped levels, zero unlabelled fences, zero trailing whitespace, trailing newline present, every internal link resolving.

**Three errors in this mission's own drafts were caught by verification and corrected before completion.**

1. **The first heading audit was wrong.** It reported five documents with multiple H1s and one with none. Every hit was a `#` shell comment *inside* a fenced code block, because the scanner was not fence-aware. Rewritten to track fence state, the real answer is exactly one H1 per document — which is what made the "one H1" rule recordable as existing practice rather than as an aspiration.

2. **A-034's issue count needed a breakdown.** The draft carried A-025's figure of 122. Re-measuring produced 167, which looked like a contradiction until it was split: 122 hand-written plus 45 in generated code. A-025's number was correct for hand-written code but did not say so, and the 45 generated findings are the obstacle nobody had recorded.

3. **The rewritten `mobile/README.md` had a wrong command.** It instructed `cp ../.env.example .env.dev`. Three `.env.example` files exist — the root one configures the `infrastructure/` scripts with `AWS_PROFILE` and `AWS_REGION`, and `mobile/.env.example` is the one holding `APP_ENV`. The command would have copied AWS tooling configuration into a Flutter build file. Corrected to `cp .env.example .env.dev`.

The Project Constitution and Glossary were also initially recorded as unreadable, because the Read tool cannot render PDFs in this environment. Extracting text directly from the PDF content streams made both readable, and that is what surfaced A-032, A-033 and A-034 — the three most consequential findings in this mission.
