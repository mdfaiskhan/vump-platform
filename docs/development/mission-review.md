# Mission Review — 0.19.1 to 0.19.11

An independent audit of the eleven missions that built this repository's standards corpus.

Governed by **ADR-032**. Where this document and the ADR disagree, the ADR governs.

**Every figure here was re-derived, not copied.** ADR-024 §30 requires counts to be re-verified when a document is edited; this review treats each prior mission's stated figures as claims to be re-tested rather than as established fact. Two were wrong, and one was wrong for a systematic reason that affected eight missions.

---

## 1. What was built

| Mission | Commit | Produced | Governed by |
|---|---|---|---|
| 0.19.1 | `8fa54a7` | `analysis_options.yaml` — 176 lint rules, 3 strictness flags, severity map | ADR-021 |
| 0.19.2 | `b765e54` | `folder-structure.md` | ADR-022 |
| 0.19.3 | `74159a0` | `naming-conventions.md` | ADR-023 |
| 0.19.4 | `88057fe` | `documentation-standards.md`; rewrote `mobile/README.md` | ADR-024 |
| 0.19.5 | `55942b9` | `error-handling.md` | ADR-025 |
| 0.19.6 | `b6812c1` | `architecture-guardrails.md` | ADR-026 |
| 0.19.7 | `d4c83fd` | `logging-standards.md` | ADR-027 |
| 0.19.8 | `9bffc53` | `review-checklist.md`; corrected three claims in `logging-standards.md` | ADR-028 |
| 0.19.9 | `87097e0` | `testing-standards.md` | ADR-029 |
| — | `6cd6a11` | Removed two scratch files committed in error by 0.19.9 | — |
| 0.19.10 | `c4a5422` | `dependency-management-standards.md` | ADR-030 |
| 0.19.11 | `0da6896` | `performance-standards.md` | ADR-031 |

**Eleven ADRs (021–031), ten reference documents, and amendments A-031 to A-050** — twenty new amendment entries against the Volumes.

**Exactly one mission changed code:** 0.19.1, which fixed 18 findings its new lint rules surfaced. Every mission after it was documentation-only, as each brief required.

---

## 2. Structural integrity

All verified by re-running each check against the working tree.

| Check | Result |
|---|---|
ADR files | **31**, numbered 001–031, **no gaps, no duplicates** |
ADR filenames matching `ADR-NNN-kebab-case.md` | 31 of 31 |
ADR `H1` matching its filename number | 31 of 31 |
ADRs with a valid `Status` line | 31 of 31 |
ADRs with an ISO 8601 `Date` | 31 of 31 |
ADRs with all four required sections | 31 of 31 |
ADRs with `Related Missions` | 31 of 31 |
ADRs with `Implementation Status` | **30 of 31** — ADR-002 is the exception |
ADRs containing a horizontal rule | **0 of 31** |
Amendment entries | **50**, A-001 to A-050, **no gaps, no duplicates, in order** |
Amendment entries with a `Status` row | 50 of 50 |
`A-nnn` cited anywhere but never defined | **0** |
`ADR-nnn` cited anywhere but never defined | **0** |
ADRs never cited outside their own file | **0** |
Broken internal links | **0** |
External links in the whole corpus | **1** — `conventionalcommits.org` |

**The reference-to-ADR pairing is complete.** Every one of the ten standards documents declares `Governed by **ADR-0NN**` and carries a precedence statement. Three older documents predate the pattern and have no governing ADR: `aws-sdk-integration.md`, `branching-strategy.md`, `commit-conventions.md` — the last two are governed by ADR-019 and ADR-020 respectively without saying so in the established form.

---

## 3. Markdown conformance (ADR-024)

| Check | Result |
|---|---|
Tracked markdown files | **54** |
Exactly one `H1` | 53 of 54 at the audited state — the exception is `.github/pull_request_template.md`, correctly |
Heading level skips | **0** |
Depth beyond `H3` | **0** |
Trailing whitespace | **0** |
Missing final newline | **1** — `CLAUDE.md` |
Unlabelled code fences | **49** of 108 |

The last three are all previously recorded deviations, unchanged. The 49 unlabelled fences span 26 files including 13 accepted ADRs, which is why no mission has fixed them — ADR-024's own terms forbid bundling that diff into unrelated work.

---

## 4. Inconsistencies found

### I1 — The stated markdown-file count was wrong, for a systematic reason

`documentation-standards.md` stated **52** markdown files. The actual figure is **54**.

**The number was not carelessly copied — it was measured with a flawed method.** Every mission computed the count with `git ls-files '*.md'` *before committing*, and `git ls-files` lists only **tracked** files. The two documents each mission had just created were still untracked, so every count was **exactly two short**, in every mission from 0.19.4 onward.

That the error was constant is what hid it: each mission's number was internally consistent with the one before, so no re-verification caught it. ADR-024 §30 requires counts to be re-verified and says nothing about *when* — the gap was in the method, not the diligence.

**Corrected to 54, and ADR-032 fixes the method.**

### I2 — The precedence claim in §3 was stale, and §30's list had drifted

`documentation-standards.md` §3 stated *"Ten of fourteen documents already carry it."* There are now **22** non-ADR documents excluding `CLAUDE.md`, of which **18 carry a precedence statement and 4 do not** — so the ratio is 18 of 22, not 10 of 14.

§30's count of **four** documents without one is still correct, but **its membership changed and the list was not updated.** The four are now:

| Document | Note |
|---|---|
| `.github/pull_request_template.md` | **Should be exempt** — it is a form whose content becomes a pull request body, where a precedence statement would be meaningless. ADR-032 exempts templates |
| `docs/development/secrets-management.md` | Genuine gap |
| `docs/operations/disaster-recovery.md` | Genuine gap |
| `infrastructure/aws/cloudfront/README.md` | Genuine gap |

`mobile/README.md` was on §30's list and was fixed by Mission 0.19.4 in the same commit that wrote the list. **The list was stale the moment it was written.**

### I3 — Two documents are absent from the architecture README's file tree

The tree under *Folder Structure* lists `README.md`, `architecture-guardrails.md`, `error-handling.md`, `folder-structure.md`, `logging-standards.md`, `naming-conventions.md` and `decisions/`. It omits:

- **`aws-sdk-integration.md`** — cited by five documents, and named by `documentation-standards.md` §2 and §7 as *the* example of an implementation specification.
- **`volume-amendments.md`** — described in prose immediately below the tree, but not in it.

`aws-sdk-integration.md` is also **absent from the root README's documentation table**, making it the only document in `docs/architecture/` registered nowhere.

### I4 — Both registration surfaces have accreted rather than been ordered

Each mission appended its row to the top of the root README table and its paragraph to the middle of the architecture README's prose. The result is neither chronological nor thematic:

- Root README rows run ADR-031, 030, 029, 028, 027, 026, **022**, 025, 023 — with ADR-024's row appearing after the `docs/git/` directory row.
- Architecture README prose runs 022, then 024, 028, 029, 030, 031, then back to 023, 026, 027, 025.

No rule was broken — ADR-024 §11 does not fix an order for these — but a reader scanning for a standard cannot predict where it sits. **Both are reordered by this mission.**

### I5 — A naive terminology check produces four false positives on this corpus

Searching for the forbidden spellings ADR-024 §15 names returns hits in four places, and **all four are legitimate**:

| Hit | Why it is correct |
|---|---|
`Github`, `pre-signed` in `documentation-standards.md` and ADR-024 | Inside backticks, naming the forbidden form: *"`GitHub` (never `Github`)"* |
`Human Archive` in ADR-011, `volume-amendments.md` | Quoting the source being corrected — verified in Mission 0.19.4 |
`behavior` in `dependency-management-standards.md` | Inside a **quotation** from Volume 3 §3.8 §3. A quotation preserves its source's spelling |

**The check ADR-024 §30 recommends would fail on all four.** Any implementation must exclude backticked spans and quoted text, or it will report a corpus that is in fact clean. Recorded so the job is written correctly rather than discovered to be noisy and disabled.

### I6 — One mission committed scratch files

Mission 0.19.9 swept `docs/volumes/v3.tmp.txt` and `v9.tmp.txt` into its commit via `git add -A`. Caught in the same session and removed in `6cd6a11`. **No scratch file is tracked today** — verified.

---

## 5. Duplication

ADR-024 §3's rule is that a rule lives in exactly one document and every other mention is a link. Probed against six rules that span several documents:

| Rule | Owner | Appears in | Verdict |
|---|---|---|---|
`always_use_package_imports` | ADR-021 | ADR-021, `folder-structure.md`, `naming-conventions.md` | **Citation, not duplication** — both cite it as enforced elsewhere |
No cross-feature import | ADR-022 R3 | `architecture-guardrails.md` only | Correct — the guardrail register cites R3 by number |
`Failure.fromException` | ADR-025 | ADR-025, `error-handling.md`, `naming-conventions.md` | **Citation** — naming-conventions names it as the example of a factory |
`redactedHeaders` | ADR-027 | `logging-standards.md`, `naming-conventions.md`, `review-checklist.md` | **Citation** — the checklist points at the single list |
`90%+` coverage | Volume 9 §9.5 §2 | 6 documents | **Borderline.** The number itself is restated in `review-checklist.md`, `testing-standards.md`, `architecture-guardrails.md`, `error-handling.md`, `folder-structure.md` and the amendment register |
Bitrate-only degradation | ADR-031 | ADR-031, `performance-standards.md`, amendment register | Correct |

**The coverage target is the one real case.** Volume 9's 90%/80% figures appear in six documents. Each occurrence cites Volume 9 §9.5 §2, so no document claims ownership — but six copies of a number is six places to update if it changes. **Recorded rather than consolidated:** each occurrence serves a different reader, and ADR-024 §3's remedy (link, do not repeat) would make five of them less useful. It is the closest the corpus comes to violating its own rule.

---

## 6. Missing governance

Recorded as absences, per each mission's brief.

### Domains with no standard document

| Domain | Evidence | Note |
|---|---|---|
| **Security** | Volume 8 is cited **43 times** across the corpus and eight amendments; `secrets-management.md` covers secrets only | **The largest gap in the standards corpus.** No document governs authentication posture, data classification, personal-data handling or the audit trail |
| Analytics | Volume 9 Chapter 9.3 exists and is cited twice, never read | Deliberately separate from logging (Volume 9 §9.2 §3) |
| Deployment / release | Volume 10 cited 15 times, no standard | Volume 10 Chapter 10.7 owns versioning and changelog |
| Project management | Volume 11 cited 5 times | Volume 11 §11.5's changelog is referenced by ADR-020 |
| **AI-assisted development** | **Volume 12 has zero citations in the entire repository** | Never consulted, despite `CLAUDE.md` governing exactly this and Volume 0 §7 fixing AI collaboration rules |

### Decisions the architecture README still lists as unrecorded

- **The HTTP client boundary** — ADR-007 fixes its configuration and `error-handling.md` §8 its error conversion; the interceptor chain and `DioClient`'s contract have no record.
- **Runtime provisioning of build-time secrets.**

### Decisions deferred to a future ADR by an existing one

| Deferred | By | Blocking |
|---|---|---|
| Retry mechanism | ADR-025 §16, `AuthInterceptor` | A-050, upload |
| Global error handlers + reporting service | A-036 | Field diagnosis |
| Crash reporter | A-037 | A-036, A-044 |
| Isar engine | A-029, A-048 | The codegen toolchain |
| Golden test tool | A-027 | Presentation coverage |
| Typed failure payloads | A-035 | Localisable error copy |
| Coverage measurement per layer | A-046 | Any meaningful gate |

**Seven open decisions, each recorded with what it blocks.** None is a documentation gap — each is a decision deliberately not taken by a mission that lacked the authority or the code to take it.

---

## 7. Consistency of the standards themselves

Checked for contradictions between the eleven documents, not merely within them.

| Pair | Potential conflict | Verdict |
|---|---|---|
ADR-023 §4.2 vs Volume 3 | `Controller` against `Notifier` | **Registered as A-041**, with the caveat that ADR-023's stated reason does not hold |
ADR-025 §16 vs Volume 5 §5.13 | 429 retryable against 4xx terminal | **Registered as A-050** |
ADR-027 §5 vs Volume 9 §9.2 | Production suppresses `info` | **Registered as A-044** |
ADR-022 R3 vs Volume 3 §3.5 §4 | Cross-feature dependency | **Registered as A-039** |
ADR-001 vs Volume 3 §3.4 §3 | Dependency direction inverted | **Registered as A-038** |
`performance-standards.md` §3 | 30 fps capture vs 60 fps UI | **Not a conflict** — different subsystems, recorded explicitly to prevent a wrong "fix" |
ADR-021 vs ADR-023 | `always_specify_types` vs the excluded rules | Consistent — ADR-023 §11 lists the mutually exclusive set |
ADR-029 §8 vs Volume 9 §9.5 | Fakes-by-default vs `mocktail` in the pyramid | Consistent — ADR-029 keeps mocks for interaction guarantees |

**No unregistered contradiction was found between any two accepted ADRs.** Every conflict this review could identify is already in the amendment register, and each is a conflict with a *Volume*, not between two ADRs.

---

## 8. Self-correction record

Each mission recorded the errors verification caught in its own draft, in its ADR's `Implementation Status`. **Counted by reading each ADR, not from memory** — see the correction below.

| Mission | ADR | Errors recorded |
|---|---|---|
0.19.1 | ADR-021 | **0** — none stated |
0.19.2 | ADR-022 | 1 |
0.19.3 | ADR-023 | 1 |
0.19.4 | ADR-024 | 3 |
0.19.5 | ADR-025 | 4 |
0.19.6 | ADR-026 | 2 |
0.19.7 | ADR-027 | 2 |
0.19.8 | ADR-028 | 2 |
0.19.9 | ADR-029 | 2 |
0.19.10 | ADR-030 | 2 |
0.19.11 | ADR-031 | 2 |
**Total** | | **21** |

> **This table was wrong in its first draft, and the error is the review's own.** It stated 2 for missions 0.19.1, 0.19.2 and 0.19.3 and a total of 25 — figures asserted from recollection rather than read from the ADRs. Grepping each `Implementation Status` gave 0, 1 and 1, and a total of **21**. A review whose central discipline is *"verify every count instead of copying previous values"* produced a fabricated statistics table on its first pass, and it was caught by the same method it prescribes.

**Four categories of error recur across the twelve missions.** Each produced a claim a reader would have believed:

- **A failed regex read as a finding.** Twice — the fence-unaware heading scanner in 0.19.4, and the NFR pattern in 0.19.11 that returned nothing from Volume 9 and would have supported a false claim. Both were caught only because a second, differently-shaped check disagreed.
- **A citation inferred rather than read.** Twice — Mission 0.15 mis-cited as 0.12 in 0.19.5, and Mission 0.18.7 invented in 0.19.10. Both were mission numbers guessed from a sequence.
- **A count measured with a method wrong in a constant direction.** Once, spanning eight missions — I1. Reproducible wrongness is invisible to re-verification, because each measurement agrees with the last.
- **A figure asserted from recollection.** Once — §8's own table, above.

**The common thread is that none of the four was caught by re-running the same check.** Each needed a *differently shaped* check: a fence-aware scanner, a source document, a staging step, a grep over the ADRs. That is the practical lesson of this review, and it is what ADR-032's verification rule encodes.

---

## 9. Verification commands

Reproducible. Run from the repository root.

```bash
# ADR and amendment numbering, sequential with no gaps or duplicates
ls docs/architecture/decisions/ADR-*.md | wc -l
grep -cE '^### A-0[0-9]{2}' docs/architecture/volume-amendments.md
grep -oE '^### A-0[0-9]{2}' docs/architecture/volume-amendments.md | sort | uniq -d

# Every ADR carries the required sections
for f in docs/architecture/decisions/*.md; do
  for s in Context Decision "Alternatives Considered" Consequences "Related Missions"; do
    grep -q "^## $s" "$f" || echo "$f missing $s"
  done
done

# No ADR contains a horizontal rule
grep -l '^---$' docs/architecture/decisions/*.md || echo "ok"

# Counts — run AFTER staging, or new files are invisible to git ls-files
git add -A && git ls-files '*.md' | grep -v mobile/ios | wc -l

# Broken internal links
git ls-files '*.md' | while read f; do d=$(dirname "$f")
  grep -oE '\]\([^)#][^)]*\)' "$f" | sed -E 's/^.\(//; s/.$//' | while read t; do
    case "$t" in http*) continue;; esac
    [ -e "$d/${t%%#*}" ] || [ -e "${t%%#*}" ] || echo "BROKEN $f -> $t"
  done
done
```

---

## 10. Risks

| Risk | Evidence |
|---|---|
**Nothing enforces any of it mechanically** | 14 of ADR-026's 38 invariants are review-only; the markdown-lint job ADR-024 §30 specifies does not exist; six checkable guardrails are unchecked |
**Zero required approvals** | ADR-019: *"CI catches what CI can check; nothing catches a bad decision that compiles"* — and every human review item in the corpus is performed by the author on their own change |
**The corpus documents an empty application** | `lib/features/` and `lib/shared/` are empty; 39 of 55 source files have no test contact. Most rules are binding and unexercised |
**Standards can rot silently** | I1, I2 and I3 all appeared within eleven missions. Every one was a documentation-maintenance failure, not a design failure |
**No security standard** | Volume 8 cited 43 times, governed by no document |
**Seven open decisions block each other** | A-036 depends on A-037; A-048 depends on A-029; A-046 blocks any coverage gate |
**Volume 12 never read** | It governs AI-assisted development, which is how this entire corpus was produced |

---

## 11. Recommended next actions

In dependency order, derived from what the audit found blocking what.

1. **Write the markdown-lint CI job** ADR-024 §30 specifies — six checks, one script. It would have caught I1's method error if it computed counts itself, and it closes the drift that produced I1–I3. Exclude backticked and quoted spans per I5.
2. **Extend the `Architecture boundaries` job** with the six checkable guardrails plus `logger` confinement — seven greps, and each one moves an item off the human checklist.
3. **Resolve A-029** — the Isar engine decision. It blocks A-048 and the whole codegen toolchain, and it is the oldest unresolved architecture decision in the register.
4. **Resolve A-037, then A-036** — crash reporter, then global handlers. Field failures are currently invisible.
5. **Write the security standard.** Volume 8 has 43 citations and no owner.
6. **Test the four error-converting `core/` modules.** ADR-025 §28 and ADR-027 §13 already specify exactly what each needs.
7. **Upgrade `go_router` and `flutter_secure_storage`** — both resolvable today (A-047).
8. **Read Volume 12** before the next AI-assisted mission.

---

## 12. Verdict

**The corpus is structurally sound.** Thirty-one ADRs with no numbering gaps, fifty amendments with none, zero broken links, zero dangling references, zero unregistered contradictions between accepted ADRs, and every reference document paired with its governing ADR.

**Its weakness is not its content but its enforcement.** Almost every rule in eleven documents is checked by a human who is also the author, and three documentation-consistency failures accumulated in eleven missions — which is the same failure mode, at a smaller scale, that the corpus exists to prevent in the code.

**The one thing this review changes about how the standards are maintained** is the count methodology in I1: a figure derived from `git ls-files` before staging is wrong in a constant direction, and constant wrongness is invisible to re-verification.
