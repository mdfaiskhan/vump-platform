# Review Checklist

How every change in the Vump Technologies repository is reviewed.

Governed by **ADR-028**. Where this document and the ADR disagree, the ADR governs.

**The authoritative checklist is Volume 3, Chapter 3.7 §9**, which ADR-019 already makes binding: a pull request must *"satisfy the review checklist in Volume 3, Chapter 3.7 §9"*. This document implements those six items, adds what the ADRs written since have made checkable, and — the part that matters most — **says which mechanism checks what**, so a human never spends attention on something a machine already rejected.

**Nothing already governed is restated.** Cited, not duplicated:

| Already fixed by | What it fixes |
|---|---|
| Volume 3 Ch. 3.7 §9 | The six-item code review checklist. **The authority for this document** |
| Volume 9 Ch. 9.1 §3 | *"No untested error path ships"* — a new failure mode adds its test in the same PR |
| Volume 9 Ch. 9.5 §2 | Coverage targets: `domain` 90%+, `data` 80%+, golden tests for Design System components |
| Volume 7 Ch. 7.6 | Every change reaches a protected branch by pull request |
| ADR-019 · `branching-strategy.md` | Protection rules, required checks, required approvals as the team grows |
| ADR-020 · `commit-conventions.md` | The PR title format, validated by CI |
| ADR-021 | The 176 analyzer rules and the severity map |
| ADR-022 · `folder-structure.md` | Folder placement and the import matrix |
| ADR-023 · `naming-conventions.md` | The closed suffix vocabulary and every naming rule |
| ADR-024 §28 | **The documentation review checklist.** Referenced, not repeated |
| ADR-025 · `error-handling.md` | The error boundary and its conventions |
| ADR-026 · `architecture-guardrails.md` | All 38 invariants with their enforcement mechanism |
| ADR-027 · `logging-standards.md` | Levels, sinks, redaction |
| `.github/pull_request_template.md` | The in-PR form a contributor fills in |

---

## 1. The four mechanisms

A review criterion is checked by exactly one of these. Knowing which is the point of this document.

| Mechanism | What it is | When it runs | If it fails |
|---|---|---|---|
| **Analyzer** | 176 lint rules and three type-strictness flags (ADR-021) | On save, in the IDE, and in CI `Analyze` | The diagnostic appears before the code is committed |
| **CI** | Nine jobs (ADR-019's protection rules require all nine) | On every push and pull request | The merge is blocked |
| **Author** | Self-review before pushing | Before opening the pull request | Nothing — it is discipline, and CI catches a subset |
| **Reviewer** | A second person reading the change | At review | Nothing today — **zero approvals are required** |

**Two honest facts about the last row.** ADR-019 sets required approvals to **0** while the team is one person, because *"GitHub forbids a pull request author from approving their own, so requiring one today would block every merge and be routinely bypassed."* ADR-019 also states the consequence plainly: *"Zero required approvals today is a real gap, not a solved problem. CI catches what CI can check; nothing catches a bad decision that compiles."*

So today, **§4's human items are performed by the author on their own change.** That is weaker than review by a second person and it is what exists. `branching-strategy.md` sets the trigger to change it: raise approvals to 1 before the second engineer's first pull request.

---

## 2. Do not review what a machine already rejected

**A reviewer who checks formatting, import style or analyzer cleanliness is spending the scarcest resource in the process on the one thing that cannot reach review.** ADR-020 states the principle for formatting — *"format is exactly what a machine checks better than a human, and a reviewer's attention is better spent on the change"* — and it generalises.

The following are **already gated**. A change that violates one cannot merge, so none of them belongs on a human checklist:

| Gated by | Criteria |
|---|---|
| CI `Format` | `dart format` clean across hand-written Dart |
| CI `Analyze` | Zero analyzer diagnostics — which subsumes every ADR-021 rule below |
| CI `Test` | Every test passes; coverage measured |
| CI `Generated code drift` | Committed `*.g.dart` matches what the generator produces |
| CI `Architecture boundaries` | `dio`, `isar`, `flutter_secure_storage`, `firebase_core` each confined to their owning module |
| CI `Commit convention` | The PR title matches ADR-020 |
| CI `Environment consistency` | Three environments agree across Dart, JSON and shell; bucket names derive from the ADR-011 slug rule; region is `ap-south-1` |
| CI `Secret scan` | No credential-bearing file, AWS key, private key or service-account key is tracked |
| CI `AWS credential isolation` | No AWS SDK dependency, credential reference or hardcoded AWS endpoint in `mobile/` |
| Analyzer | Package imports only · no `print` · no dynamic calls or implicit downcasts · no empty `catch` · only `Error`/`Exception` thrown · `rethrow` preserves the trace · no unawaited or discarded future · no `BuildContext` across an `await` · no dead code · `snake_case` filenames · no `Color` literal outside `app/theme/` · every `ignore` documented |

**The `pull_request_template.md` asks the author to tick five of these.** It has 17 checkboxes: 7 select the change type, leaving 10 criteria — and 5 of those 10 duplicate a CI job (`flutter analyze`, `flutter test`, `dart format`, the four package confinements, and the secret check).

That is defensible as an **author self-check before pushing** — fail locally rather than publicly — and it is not a reviewer task. The template does not currently draw that line, and it mentions only ADR-007 and ADR-009, so nothing from ADR-021 through ADR-027 appears in it: no error-handling, logging, naming or documentation criterion at all. Recorded as a gap in §7.

---

## 3. Volume 3 §3.7 §9 — the binding six

The authoritative checklist, verbatim in substance, with the mechanism that checks each and where the detail lives.

| # | Volume 3 §3.7 §9 asks | Mechanism | Detail in |
|---|---|---|---|
| **V1** | *"Does this change respect the layer dependency direction (no upward or sideways imports)?"* | **Reviewer** | ADR-022 §5.1's import matrix; guardrails I25, I27–I29 |
| **V2** | *"Does this change stay inside its module's boundary, or does a new cross-module dependency need to be justified and documented?"* | **Reviewer** | ADR-022 R3; guardrails I25. **No cross-feature import is permitted at all** — see below |
| **V3** | *"Is every non-obvious business rule traceable to a Volume 1 requirement ID in a comment?"* | **Reviewer** | §4.2 |
| **V4** | *"Does static analysis run clean, with zero suppressed lint warnings introduced by this change?"* | **CI `Analyze`** + **Reviewer** for the suppression half | ADR-021 |
| **V5** | *"Are new or changed public APIs in `domain/` or `data/` documented?"* | **Reviewer** | A-025, A-034 — the lint that would check this is not enabled |
| **V6** | *"Are tests added or updated per Volume 9's strategy for the layer being touched?"* | **Reviewer** | §4.5 |

**V2 is stricter here than the Volume's wording suggests.** §3.7 §9 allows a cross-module dependency that is *"justified and documented"*. ADR-022 R3 forbids cross-feature imports outright, and Volume 3 §3.5 §4's own closing rule agrees. A reviewer therefore does not weigh a justification — they reject the import and ask which of R3's four resolutions applies. Registered as **A-039**.

**V4 has two halves and only one is automated.** CI proves analysis is clean. It does not prove that cleanliness was not bought with an `// ignore`. That is a reviewer check — though `document_ignores` and `unnecessary_ignore` (ADR-021) make an undocumented or stale suppression a diagnostic, so the reviewer is checking the *justification*, not the presence.

---

## 4. Reviewer checklist

Every item here is one a machine cannot check. Grouped by what the change touches — skip the groups that do not apply.

### 4.1 Always

- [ ] **The change does what the PR says**, and the PR says why. ADR-020: the diff shows what; the message explains the constraint that forced it.
- [ ] **It contradicts no accepted ADR.** Where it changes an architectural decision, a new ADR is in the same pull request — `CLAUDE.md`: *"an architectural decision that is not recorded does not exist."*
- [ ] **Scope is one change.** ADR-020: *"a change that fits two types is two commits."*
- [ ] **No suppression was added to buy a clean build** (V4). An `// ignore` is documented and necessary, or it is removed.
- [ ] **Nothing is left dead or half-finished.** `CLAUDE.md`: *"do not leave dead code."* The analyzer catches unreachable code; it does not catch a feature wired to nothing.

### 4.2 Business rules and traceability

- [ ] **Every non-obvious business rule cites its Volume 1 requirement ID in a comment** (V3) — `FR-CHK-05`, `BR-22`, `NFR-REL-04`.
- [ ] **The rule lives in `domain/`**, not in a widget or a repository (ADR-022 R1).

**Audit finding, recorded rather than glossed:** **no Volume 1 requirement ID appears anywhere in `lib/` or `test/` today.** That is correct rather than a violation — `lib/features/` is empty, so no Volume 1 business rule has been implemented. What exists instead is **54 ADR citations across 10 distinct ADRs** in `lib/` doc comments, which is the same discipline applied to the decisions that *have* been implemented. V3 becomes live with the first feature.

### 4.3 Architecture

- [ ] **Layer direction holds** (V1) — ADR-022 §5.1. The two easiest to miss: `presentation/` must not import its own `data/`, and `application/` must not either.
- [ ] **No cross-feature import** (V2) — at any layer, in either direction.
- [ ] **`domain/` imports nothing outward** but `failure.dart` and `error_codes.dart`.
- [ ] **`app/` names no feature**, except `app/router.dart` importing a feature's `presentation/`.
- [ ] **`core/` does not import `app/theme/`**; `app/config/` does not import `core/`.
- [ ] **A new module in `core/` has more than one feature as a consumer** (ADR-022 R2). Name the second, or it belongs to the feature.
- [ ] **Nothing enters `shared/` without a second consumer** (ADR-022 R5).
- [ ] **A new third-party package brings a conversion boundary and a confinement entry** in the CI job (ADR-025 §7, ADR-022 §2.3).
- [ ] **Type suffixes come from the closed vocabulary** (ADR-023 §3). `Manager`, `Helper`, `Model`, `Impl`, `Page` are forbidden.

Guardrails I25–I37 are the same list with authorities; six are checkable by script today and unchecked (ADR-026 §10).

### 4.4 Errors

- [ ] **A new failure mode adds its test in the same pull request.** Volume 9 §9.1 §3: *"No untested error path ships."* This is the one rule Volume 9 defines rather than references.
- [ ] **A third-party error is converted at the module that owns the package** (ADR-025 §7), and the boundary ends in a catch-all so nothing escapes untranslated.
- [ ] **`cause` and `stackTrace` are captured** when constructing an `AppException`, and the trace is taken at the origin.
- [ ] **A new `ErrorCode` is added rather than reusing `unknown`.** A rising `UNKNOWN` count means the taxonomy has a gap (ADR-025 §19).
- [ ] **An existing `ErrorCode` string was not changed.** It is a protocol change — every log query and dashboard references it.
- [ ] **No new exception subclass without a field or a distinct consumer** (ADR-025 §17).
- [ ] **No `Failure` subclass** (ADR-025 §2).
- [ ] **Nothing above `application/` catches an `AppException`**; `presentation/` receives a `Failure`.
- [ ] **User-facing text resolves from the `ErrorCode`**, never from a message string, and is specific — *"Something went wrong"* is forbidden (Volume 3 §3.9 §5).

### 4.5 Tests

- [ ] **Tests exist for the behaviour changed** (V6), at the layer touched.
- [ ] **The failure path is tested, not only the happy path.** Volume 9 §9.5 §2 makes `data`'s 80% target *"focused on error-path coverage… not just the happy path."*
- [ ] **Coverage targets are met for the layer** — `domain` 90%+, `data` 80%+ (Volume 9 §9.5 §2). Measured by CI, **not gated** while `features/` is empty.
- [ ] **A new Design System component has a golden test** in both themes (Volume 9 §9.7 §2). The tool is unchosen — `golden_toolkit` is discontinued (**A-027**).
- [ ] **Test files mirror `lib/` exactly** (Volume 3 §3.6 §4).
- [ ] **Test names state the guarantee** as a lowercase sentence, no "should" (ADR-023 §8).
- [ ] **Assertions are on the `ErrorCode`, not on a message string** (ADR-025 §28).
- [ ] **Log output is silenced**, not tolerated — inject a `LogOutput` (ADR-027 §13).

### 4.6 Logging

- [ ] **No secret in a log message, an error, or any interpolated value** (ADR-027 §8). Log the shape, not the thing.
- [ ] **No personal data at `info` or `debug`** — GPS coordinates, device identifiers, or any field Volume 8 §8.6 classifies as personal data. Volume 9 §9.2 §4 requires the substitute to be an identifier: log the `chunk_id` and join against the metadata store. **V9.2 §4 names review as its enforcement mechanism** — there is no analyzer or CI check.
- [ ] **A log line touching a chunk or session carries its `chunk_id`/`session_id`** (Volume 9 §9.2 §2). Not yet implementable — **A-044**.
- [ ] **The level matches the event** (ADR-027 §5). `warning` recovered, `error` failed, `fatal` about to stop.
- [ ] **A second `fatal` call site is a decision.** There is one, and it aborts startup.
- [ ] **The exception is passed, not re-described**, and logged once, at the layer that decides (ADR-027 §9).
- [ ] **A new sensitive header is added to `NetworkConstants.redactedHeaders`** — the single list.
- [ ] **A request body carrying a credential is not logged.** The interceptor truncates bodies; it does not sanitise them, and will not.

### 4.7 Security

Beyond CI's `Secret scan` and `AWS credential isolation`, which gate the mechanical cases:

- [ ] **No credential reaches the mobile app in any form** — Volume 4 §4.10 §2. Uploads use backend-issued presigned URLs, which are a capability, not an identity.
- [ ] **A new secret is provisioned per ADR-016**, never committed, and never logged.
- [ ] **A new outbound host is deliberate.** ADR-007 permits non-secret base URLs in source; a new one is a decision.
- [ ] **A test fixture carries no real credential.** CI's patterns are deliberately narrow, so a fixture-shaped secret can pass.
- [ ] **Personal data handling matches Volume 8 §8.6** where the change touches metadata, GPS or device fields.

### 4.8 Documentation

**ADR-024 §28 is the documentation review checklist and is not repeated here.** Sixteen items covering placement, precedence, duplication, heading depth, fence languages, table form, links, Glossary terms, honesty about status, and examples.

Two additions specific to reviewing a *change*:

- [ ] **A rule changed in a reference document is checked against the ADR that governs it.** If the edit changes what is *permitted*, it is an amendment to the ADR, not a documentation edit (ADR-024 §27).
- [ ] **A deviation from an approved Volume is registered in `volume-amendments.md`**, not silently taken.

### 4.9 Dependencies

- [ ] **A new package is justified.** Volume 0 §2: *"Any new third-party package or service must be recorded against the relevant Volume 3/4/6 chapter before being added."*
- [ ] **It is confined to one module**, with a CI confinement entry (ADR-022 §2.3).
- [ ] **`pubspec.yaml`'s purpose grouping is preserved** (ADR-023 §11 records why it is not alphabetised).
- [ ] **No `git:` or `http:` dependency source** — the analyzer's `secure_pubspec_urls` catches this.

---

## 5. Architecture review

A change that alters a decision is not a code review. It is an architecture review, and it happens **before** the code.

- [ ] **The decision has an ADR**, `Proposed` first, following the template in `docs/architecture/README.md`.
- [ ] **The `Alternatives Considered` section names each rejected option with its specific reason.** ADR-024 §5: *"'Rejected — not suitable' records nothing."*
- [ ] **It contradicts no accepted ADR.** If it must, it supersedes it — an accepted ADR is never edited to change its meaning.
- [ ] **A Volume disagreement is registered as an amendment** with its authority and class.
- [ ] **`Consequences` states what becomes harder**, not only what improves.
- [ ] **New invariants are added to the guardrail register** with their enforcement column filled in, including `Review` (ADR-026 §8).
- [ ] **The reference document is updated in the same commit**, not a follow-up (ADR-024 §30).

---

## 6. Sequence

```text
Author, before pushing
  ├── flutter analyze            ─┐
  ├── flutter test --coverage     │ CI will gate these; run them first
  ├── dart format                 │ so the failure is local, not public
  └── build_runner, if generated  ─┘
        │
        ├── self-review against §4
        └── PR title per ADR-020, template filled in
                │
CI  (nine jobs, all required by ADR-019)
                │  merge blocked on any failure
                ▼
Reviewer  (§4 — zero required approvals today; the author performs it)
                │
                ▼
Squash-merge to develop  (ADR-019; PR title becomes the commit)
```

---

## 7. Gaps

Recorded rather than fixed — this is a documentation and governance mission.

| Gap | Evidence | Disposition |
|---|---|---|
| **Zero required approvals** | ADR-019: *"CI catches what CI can check; nothing catches a bad decision that compiles"* | Raise to 1 before the second engineer's first PR. Named in `branching-strategy.md` |
| **The PR template predates ADR-021 to ADR-027** | Written in Mission 0.16; mentions none of them. No error-handling, logging, naming or documentation item appears | Extend it with §4's groups, and mark the CI-duplicating boxes as author self-checks |
| **The template does not distinguish author from reviewer** | 17 checkboxes: 7 select the type, and 5 of the remaining 10 duplicate a CI job (§2) | Same fix as above |
| **No `CODEOWNERS`** | Absent. `branching-strategy.md` requires one at 5+ engineers for `infrastructure/` and `docs/architecture/` | Add at that threshold |
| **Six guardrails are checkable and unchecked** | ADR-026 §10 — I30, I31, I32, I33, I35, I37 | Extend the `Architecture boundaries` job. Every item moved from §4 to §2 is attention returned to the reviewer |
| **Coverage is measured, not gated** | CI `Test` prints the number | Deliberate while `features/` is empty |
| **No requirement ID appears in code** | 0 across `lib/` and `test/` | Correct today — no Volume 1 rule is implemented (§4.2) |
| **V5's lint is not enabled** | `public_member_api_docs` scoped-out (A-025); Constitution §4 is broader (A-034) | Reviewer-checked until resolved |
| **Golden testing has no tool** | `golden_toolkit` discontinued (A-027) | Decided by the mission that builds the first component |
| **No review item is machine-verified as *performed*** | Ticking a box in a template is an assertion, not evidence | Inherent to human review; noted so the boxes are not mistaken for gates |

---

## 8. Maintenance

- **A new ADR that adds a checkable rule adds a §4 item**, or states that the analyzer or CI covers it.
- **When a §4 item becomes automated, move it to §2 and delete it from §4.** A checklist that grows monotonically stops being read, and every automated item is attention given back.
- **The four mechanisms in §1 are the only ones.** A criterion with no mechanism is not a review item.
- **This document does not restate a rule.** One line, one citation — the detail lives in the ADR or reference that owns it.
- **A Volume review requirement is derived, never invented.** Volume 3 §3.7 §9 is the authority, extended by Volume 9 §9.1 and §9.5.
