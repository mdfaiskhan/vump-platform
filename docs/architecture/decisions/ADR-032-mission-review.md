# ADR-032 — Mission Review and Documentation Maintenance Rules

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Refines ADR-024 in three respects — see *What this changes about ADR-024*. ADR-024 remains Accepted and binding in every other respect.

## Context

Missions 0.19.1 to 0.19.11 produced eleven ADRs, ten reference documents and twenty amendment entries. Mission 0.19.12 audited all of it independently, re-deriving every figure rather than accepting any prior mission's.

**The corpus is structurally sound.** Thirty-one ADRs numbered without a gap or a duplicate, fifty amendments likewise, zero broken internal links, zero dangling `ADR-nnn` or `A-nnn` references, every reference document paired with its governing ADR, and no unregistered contradiction between any two accepted ADRs.

**But three documentation-consistency failures accumulated in eleven missions**, and their pattern is what forces this ADR rather than a review document alone.

**The first is a method error, not a diligence error.** `documentation-standards.md` stated 52 tracked markdown files; the actual figure is 54. Every mission computed that number with `git ls-files '*.md'` **before committing** — and `git ls-files` lists only tracked files, so the two documents each mission had just written were invisible to its own count. **Every count from Mission 0.19.4 onward was exactly two short.** ADR-024 §30 requires counts to be re-verified and says nothing about *when*; because the error was constant, each mission's figure agreed with the last, and re-verification could never catch it.

**The second is a list that was stale the moment it was written.** ADR-024 §30 records four documents lacking a precedence statement and names `mobile/README.md` among them — in the same commit that rewrote `mobile/README.md` with a precedence statement. The count of four remains correct today by coincidence: `mobile/README.md` left the list and `infrastructure/aws/cloudfront/README.md` was already on it.

**The third is a registration gap.** `aws-sdk-integration.md` — cited by five documents and named by ADR-024 §2 and §7 as *the* example of an implementation specification — appears in neither README, and `volume-amendments.md` is missing from the architecture README's file tree while being described in the prose directly beneath it.

**And the review's own first draft fabricated a statistics table**, asserting per-mission error counts from recollection. Reading the ADRs gave 21 where the draft said 25, with three of eleven rows wrong. A review whose stated discipline is *"verify every count instead of copying previous values"* failed at exactly that, and caught it only by applying its own rule.

Across twelve missions, twenty-two errors of this kind were caught in draft. **None was caught by re-running the same check.** Each needed a differently shaped one.

## Decision

### The review is recorded as a document

`docs/development/mission-review.md` is the canonical review of missions 0.19.1 to 0.19.11: what was built, structural integrity, markdown conformance, six numbered inconsistencies, duplication analysis, missing governance, cross-standard consistency, the self-correction record, reproducible verification commands, risks, and recommended next actions in dependency order.

It is a **reference document, not a register** — it describes a point in time and is superseded by the next review rather than appended to.

### What this changes about ADR-024

Three refinements. ADR-024 is not edited; this ADR narrows and extends it, and `documentation-standards.md` is updated to match.

**A count is verified after staging, never before.** `git ls-files` is blind to untracked files, so a count taken before `git add` omits exactly the documents the mission just wrote. Any figure derived from the tracked file set is computed after staging, or by a method that does not depend on tracking at all.

**Templates are exempt from the precedence rule.** ADR-024 §3 requires every non-ADR document to state its own precedence. `.github/pull_request_template.md` is a form whose content becomes the body of a pull request, where a precedence sentence would be neither read nor meaningful. The rule applies to documents, not to templates.

**A terminology check must exclude backticked and quoted spans.** ADR-024 §30 recommends a markdown-lint job, and §15 fixes forbidden spellings. A naive search for them returns four hits in this corpus and **all four are legitimate**: `Github` and `pre-signed` appear inside backticks in the very sentences forbidding them, `Human Archive` appears where a source is being quoted for correction, and `behavior` appears inside a verbatim quotation from Volume 3 §3.8 §3. A check that flags these would be disabled as noisy within a week.

### Registration completeness is a verifiable property

Every document under `docs/` appears in at least one registration surface — the architecture README's file tree and prose for `docs/architecture/`, the root README's documentation table for everything else. A document registered nowhere is unfindable except by someone who already knows it exists, which is the condition `aws-sdk-integration.md` was in.

**Registration surfaces are ordered, not accreted.** Both READMEs had grown by prepending each mission's row, leaving the root table running ADR-031, 030, 029, 028, 027, 026, **022**, 025, 023 with ADR-024's row after a directory row. No rule was broken — ADR-024 §11 fixes no order for these — but a reader cannot predict where a standard sits. Both are reordered by this mission and are maintained in order thereafter.

### Verification requires a differently shaped check

**Re-running the same check does not verify a claim; it reproduces it.** All four recurring error categories were invisible to repetition:

| Error | Invisible to | Caught by |
|---|---|---|
Fence-unaware heading scan | Re-running the scan | A fence-aware scanner |
Inferred mission number | Re-reading the draft | The cited ADR's own `Related Missions` |
Pre-staging count | Re-counting the same way | Counting after `git add` |
Table from recollection | Re-reading the table | A grep over the ADRs |

So a figure or citation is confirmed by a **second method or a primary source**, not by a second look. This is what the review's §9 commands are for, and it is the rule that would have prevented all four.

### The largest governance gap is named

**No document governs security.** Volume 8 is cited 43 times across the corpus and by eight amendments; `secrets-management.md` covers secrets alone. Authentication posture, data classification, personal-data handling and the audit trail have no owner.

**Volume 12 has zero citations anywhere in the repository** — it governs AI-assisted development, which is how this entire corpus was produced, and no mission has read it.

Neither is closed here. Both are recorded with the evidence, per the standing rule that an absence is recorded rather than filled by invention.

## Alternatives Considered

- **Write the review document and no ADR.** Rejected, and this was the closest call — a review is a report, not a decision, and `docs/architecture/README.md` warns that an ADR is not a status document. But the audit produced four genuine binding decisions: the count-after-staging rule, the template exemption, the terminology-check exclusion, and the registration-completeness property. Each refines ADR-024, and ADR-024 cannot be edited to carry them. Without this ADR the corrections to `documentation-standards.md` would have no authority behind them.

- **Amend ADR-024 directly with the three refinements.** Rejected, and not permitted. `docs/architecture/README.md` forbids updating an accepted ADR to *"add, remove or reinterpret a constraint"*. All three do exactly that.

- **Treat the count error as a transcription slip and just fix the number.** Rejected. Fixing 52 to 54 without recording the method would leave the next mission computing 56 when the answer is 58. The number was a symptom; the pre-staging measurement was the defect.

- **Require every document, templates included, to state precedence.** Rejected. It would put a governance sentence into the body of every pull request, which is worse than the inconsistency it resolves.

- **Fix the 50 unlabelled code fences in this mission.** Rejected, consistent with ADR-024's own terms: 13 of the 26 affected files are accepted ADRs, and bundling a 26-file formatting diff into a review commit would make both unreviewable. It remains a recorded deviation with a stated route.

- **Fix ADR-002's missing `Implementation Status`.** Rejected — adding a section to an accepted ADR is a content change, not a formatting correction. It stays the documented exception.

- **Consolidate the six copies of Volume 9's 90%/80% coverage figures into one document and link to it.** Rejected, and recorded as the corpus's closest brush with its own no-duplication rule. Each of the six occurrences serves a different reader — a reviewer, a test author, a guardrail register, an amendment — and every one cites Volume 9 §9.5 §2 as the owner rather than claiming ownership. Replacing five with links would make five documents less useful to save one edit if the number ever changes.

- **Open the security standard in this mission.** Rejected as out of scope: the mission's deliverables are the review and this ADR, and a security standard needs Volume 8 read in full, which is a mission of its own. Recorded as the largest gap instead.

## Consequences

- **The count methodology is fixed**, so the figure stops drifting. It also means any mission that reports a corpus count must stage first — a small procedural obligation with a real failure behind it.

- **Three of ADR-024's rules now have a documented exception or refinement**, and a reader of ADR-024 alone will not see them. This is the unavoidable cost of the no-editing rule, mitigated by `documentation-standards.md` carrying the refinements inline and by the cross-reference in `docs/architecture/README.md`.

- **`aws-sdk-integration.md` is findable.** It had been cited by five documents and registered by none since before this series began.

- **Both registration surfaces are ordered**, and staying ordered is now an obligation rather than a courtesy. The next mission that appends a row out of order recreates the drift.

- **Twenty-one draft errors across eleven missions are on record with their categories.** That is a high number and it is the honest one — every mission verified its own claims and published what it found wrong. The rate is evidence the verification worked, not that the work was careless; the errors that matter are the ones nobody looked for.

- **The security gap is named and unfilled.** Anyone auditing governance coverage will find it immediately, which is the point of recording it rather than quietly leaving it.

- **Seven open decisions are documented with what each blocks** — retry, global handlers, crash reporter, the Isar engine, golden tooling, typed failure payloads, per-layer coverage. None is a documentation gap; each is a decision a mission lacked the authority or the code to take.

- **This review is a snapshot and will go stale.** It describes the corpus at commit `0da6896` plus this mission's changes. A later review supersedes it rather than amending it, and nothing prevents it from being read as current after it is not.

## Related Missions

- Missions 0.19.1 to 0.19.11 — the eleven missions audited, producing ADR-021 to ADR-031 and amendments A-031 to A-050.
- Mission 0.19.4 — Documentation standards (ADR-024), whose §3, §15 and §30 this ADR refines.
- Mission 0.19.12 — Mission Review, which produced this ADR and `mission-review.md`.

## Implementation Status

**Implemented.** The review is written, the three inconsistencies are corrected, and the refinements are recorded in `documentation-standards.md`.

Verified by re-running every check against the working tree rather than accepting any prior figure:

| Audited | Result |
|---|---|
| ADR files | **31**, 001–031, no gaps, no duplicates |
| ADRs with valid filename, `H1`, `Status`, ISO `Date` | 31 of 31 |
| ADRs with all four required sections | 31 of 31 |
| ADRs with `Related Missions` | 31 of 31 |
| ADRs with `Implementation Status` | **30 of 31** — ADR-002 excepted |
| ADRs containing a horizontal rule | **0 of 31** |
| Amendment entries | **50**, A-001–A-050, sequential, no duplicates, in order |
| Amendment entries with a `Status` row | 50 of 50 |
| `A-nnn` or `ADR-nnn` cited but undefined | **0** |
| ADRs never cited outside their own file | **0** |
| Broken internal links | **0** |
| External links in the corpus | **1** |
| Tracked markdown files | **54** — corrected from a stated 52 |
| Documents with exactly one `H1` | 53 of 54; the PR template correctly has none |
| Heading level skips · depth beyond `H3` · trailing whitespace | **0 · 0 · 0** |
| Unlabelled code fences | **50**, unchanged, recorded |
| Files missing a final newline | **1** — `CLAUDE.md` |
| Non-ADR documents lacking a precedence statement | **4**, of which one is a template now exempt |
| Documents in `docs/` registered nowhere | **1 before this mission**, `aws-sdk-integration.md`; **0 after** |
| Unregistered contradictions between accepted ADRs | **0** |
| Terminology-check hits | **4, all false positives** — backticked or quoted |
| Draft errors recorded across the eleven missions | **21** |
| Scratch files tracked | **0** |
| `flutter analyze` | No issues |

No code was changed. No accepted ADR was modified.

**One error in this ADR's own supporting document was caught by verification.** `mission-review.md` §8's per-mission error table was asserted from recollection: it stated 2 for missions 0.19.1, 0.19.2 and 0.19.3 and a total of 25. Grepping each ADR's `Implementation Status` gave 0, 1 and 1, and a total of **21** — three of eleven rows wrong. The failure is worth recording plainly: a review whose central rule is *"verify every count instead of copying previous values"* fabricated a statistics table on its first pass. It was caught by applying that rule, which is the only reason this ADR can state the figure with confidence.
