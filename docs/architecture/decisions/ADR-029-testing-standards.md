# ADR-029 — Testing Standards

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Implements Volume 9's testing chapters against the current repository. Registers A-045 and A-046.

## Context

**Volume 9 is the most complete specification in the volume set, and the repository implements almost none of it.**

Chapter 9.5 fixes a four-layer pyramid with proportions and tooling. 9.6 fixes what gets a unit test. 9.7 fixes five end-to-end flows and golden testing as a hard CI gate. 9.4 fixes six measurable performance targets. 9.1 §3 defines the one rule the chapter says it *defines* rather than references: *"No untested error path ships."*

Against that: **4 test files, 28 tests, and three of the four named test tools absent.**

**The measured gap is worse than the coverage number suggests, and that is the finding that forced this ADR.** CI reports 65% line coverage. Computed from the committed `coverage/lcov.info`, that figure is **146 of 224 lines across 16 files** — while `lib/` contains **55 hand-written source files**. `lcov.info` lists only files loaded during the run, so a file no test imports does not appear as 0%; it does not appear at all. **39 of 55 files have no test contact**, including all of `core/database`, `core/errors`, `core/network` and `core/storage` — every module that converts a third-party error into the taxonomy ADR-025 governs.

So the repository reports a passing-looking coverage figure computed over 29% of its files, and the four modules whose correctness ADR-025 depends on are untested.

**Two Volume defects surfaced while reading.** Volume 9 §9.6 §2 requires an injectable clock and claims *"this pattern is itself a Chapter 3.7 coding-standard requirement, not just a testing convenience."* Volume 3 §3.7 has nine sections — Static Analysis, Naming, Traceability Comments, Documentation Comments, Logging, Immutability & Null Safety, Widget & State Conventions, Code Review Checklist — and **none mentions a clock, `DateTime.now()` or time injection.** The requirement is sound and is recorded nowhere binding.

And Volume 9 §9.5 §2's per-layer targets — domain 90%, data 80% — **cannot be computed from what CI measures**, which is a single repository-wide percentage with no layer breakdown.

**Nothing in the repository records any of this.** There is no testing ADR, no testing standard, and no document that states which of Volume 9's requirements are met, deferred, or unmeasurable.

## Decision

### Volume 9 is implemented as far as the repository allows, and the rest is cited

`docs/development/testing-standards.md` is the canonical testing standard: 18 sections covering the pyramid, structure, naming, unit, widget, integration and golden testing, substitution, determinism, async, error paths, logging verification, platform and performance measurement, fixtures, coverage, CI, gaps and maintenance.

**Volume 9 is the authority and is cited, not restated.** Where a rule is Volume 9's, the standard quotes the clause and points at it. What the standard adds is what Volume 9 cannot know: which rules the current repository meets, which are unmeasurable, and which are absent.

Placed in `docs/development/` beside `documentation-standards.md` and `review-checklist.md` — it is a practice standard whose reader is a contributor writing a test, and ADR-024 §20's audience test puts it there rather than in `docs/architecture/`.

### Fakes are the default substitution mechanism; mocks are for interaction guarantees

The repository has no mocking framework and one hand-written fake. This ADR makes that the rule rather than an accident:

**Prefer a fake.** Volume 6 §6.4 §4 already specifies the mechanism — `recordingRepositoryProvider.overrideWithValue(FakeRecordingRepository())` — and the reason: *"every repository provider is designed to be overridden this way, so Volume 9's test suite never needs a real Drift database, a real camera, or a real network call."* ADR-001's `abstract interface class` declarations exist to be substituted, and a fake implementing one is compiler-checked.

**Use a mock only where the interaction is the guarantee** — that a retry happened exactly N times, that a credential was never requested. Asserting that a method was called couples the test to how the code is written rather than to what it promises, so it is the exception, not the default. `mocktail` stays uninstalled until it has such a consumer (A-028).

### The requirement-ID prefix is the test's traceability mechanism

Volume 9 §9.6 §2's worked example is `test('BR-06: chunk boundary fires at exactly 10 minutes', …)`. That composes with ADR-023 §8 — an identifier followed by a lowercase sentence — and it is how Volume 3 §3.7 §4's traceability requirement is satisfied for a test.

**Used only where a numbered requirement drives the test.** Inventing an ID to satisfy a convention would be worse than omitting one, and no test in the suite carries a prefix today because no Volume 1 requirement is implemented.

### Coverage is reported, not gated, and the reason is now precise

The gate stays off. CI's stated reason — *"`lib/features/` is empty, so `domain/` and `data/` do not exist and any gate would be vacuous"* — is sound **for the layer targets** and does not extend to the six `core/` modules that exist and ship untested.

**The measurement itself is recorded as defective for its stated purpose.** A single repository-wide percentage cannot express Volume 9 §9.5 §2's per-layer targets, and computing it from `lcov.info` alone makes it blind to files no test imports. Registered as **A-046**. Any future gate needs per-layer computation and a denominator that includes unimported files, or it will pass vacuously — which is precisely the failure mode a 65%-over-29%-of-files figure already demonstrates.

### Absences are recorded as absences

Applied in six places, and one of them corrects a draft of this ADR.

No integration test, no golden test, no fixtures, no `dart_test.yaml`, no clock abstraction, no manual test plan and no device matrix. Each is recorded with the Volume 9 chapter that specifies it and whether the absence is *correct* — most depend on features that do not exist — or a real gap.

**The automated performance test is the case worth naming.** A draft of the standard recorded its absence as *"no Volume requires one"*. That was wrong: **Volume 9 Chapter 9.4 fixes six measurable performance targets.** Reading it changed the finding rather than confirming it — §9.4 assigns four targets to manual measurement (DevTools overlay, stopwatch, profiler, all during Chapters 9.8 and 9.9) and two to in-app instrumentation. **No Volume asks for an automated performance test**, so its absence is correct by design; what is absent is the instrumentation and the manual procedures.

### The clock requirement is recorded where it is enforceable

Volume 9 §9.6 §2's injectable clock is a real requirement mis-attributed to Volume 3 §3.7 (**A-045**). The standard records it under determinism, with the audit finding that `DateTime.now()` is called directly in three `core/` files — none of them a use case, so none in violation, and all three producing a duration for a log line rather than a decision.

The consequence is stated rather than dramatised: **those durations cannot be asserted**, which is part of why `LogFormatter` and the interceptors have no tests, and it stops being cosmetic the moment Volume 9 §9.4's metadata-generation target depends on one.

## Alternatives Considered

- **Write no testing standard; Volume 9 is already complete.** Rejected. Volume 9 specifies the target state and cannot know the current one. Nothing in the repository recorded that 39 of 55 files are untested, that three of four tools are absent, or that the coverage figure is computed over a third of the codebase — and Volume 9 is a PDF that cannot be annotated with any of it.

- **Enable a coverage gate now, at the measured 65%.** Rejected, and it is the most tempting wrong move. The figure is computed over 16 instrumented files, so a gate on it would pass while `core/database`, `core/errors`, `core/network` and `core/storage` stay untested — and would *tighten* as fewer files were imported. A gate on a metric blind to unimported files rewards not writing tests.

- **Install `mocktail`, `integration_test` and a golden tool now, to match Volume 3 §3.1.** Rejected, consistent with A-028's reasoning: *"an installed-but-unused test dependency is weight in the lockfile and an invitation to use the wrong tool for the current problem."* All five of Volume 9 §9.7's flows depend on features that do not exist, and the golden tool cannot be chosen because `golden_toolkit` is discontinued (A-027) and there is no component to capture.

- **Adopt mocks as the default and specify `mocktail` usage.** Rejected. Volume 6 §6.4 §4 specifies fakes behind provider overrides, ADR-001's interfaces are built for substitution, and interaction assertions couple a test to the implementation. Mocks are kept for the narrow case where the interaction is the guarantee.

- **Write the missing `core/` tests as part of this mission.** Rejected as out of scope — this is a documentation and governance mission and changes no code — but the standard names them as the highest-value missing tests, and ADR-025 §28 and ADR-027 §13 already specify exactly what each needs.

- **Record the coverage figure without recomputing it.** Rejected, and the recomputation is what produced the finding. Taking CI's 65% at face value would have described a repository two-thirds tested. Deriving it from `lcov.info` showed the denominator excludes 39 files.

- **Fold testing rules into `review-checklist.md`**, since §4.5 already lists the reviewer's test items. Rejected. The checklist answers *"what do I check in this change"*; the standard answers *"how is a test written and what must exist"*. The checklist cites the standard, which is the direction that avoids duplication.

- **Treat Volume 9 §9.6 §2's mis-citation as a transcription slip and ignore it.** Rejected. The claim is load-bearing — it asserts the clock rule is a *coding standard*, which would make it binding on all code rather than advice to test authors. It is not in Volume 3, so nothing binding requires it, and recording that gap is how it eventually becomes a real rule.

## Consequences

- **The tested surface is now a number rather than an impression:** 16 of 55 files, with the six untested `core/` modules named. That is a backlog, and the four error-converting modules are its top.

- **The coverage figure is now known to be misleading for its purpose**, which matters most at the moment someone proposes gating on it. A-046 records what a usable gate would need.

- **Fakes-by-default is binding**, so the first feature will not introduce a mocking framework by reflex. The cost is that a genuine interaction guarantee now requires an explicit decision to install `mocktail`, which is the friction intended.

- **The requirement-ID prefix is specified before its first use**, so traceability arrives with the first feature test rather than being retrofitted across a suite.

- **A-045 leaves a real requirement unenforced.** Volume 9 §9.6 §2's injectable clock is correct and is cited to a chapter that does not contain it, so no accepted ADR and no Volume section binds it. Until that is fixed, the rule rests on this standard's §9 alone.

- **`DateTime.now()` stays in three `core/` files.** Not a violation, and not free: the durations they produce are unassertable, and one of them — operation timing — is the same shape Volume 9 §9.4 will need instrumented and measured.

- **Volume 9 §9.4's performance targets are recorded as manual by design**, which prevents a future mission from building an automated performance suite no Volume asked for. Four stopwatch-and-profiler procedures and two instrumentation points are what is actually owed.

- **The standard will need revising as tools arrive.** §1's *Installed* column, §6, §7 and §17 all describe an absence that is expected to end, and §18 makes updating them an obligation of the mission that installs each tool.

- **Nothing in the repository changed.** No test was written, no dependency added, no gate enabled.

## Related Missions

- Mission 0.6.2 — Application Bootstrap, which produced the widget test that sets the pump-the-real-composition convention.
- Mission 0.18.6 — which declined to install `mocktail`, `integration_test` and `golden_toolkit`, recorded as A-028.
- Mission 0.18.4 — CI, which added `flutter test --coverage` and the coverage report line A-046 now finds insufficient.
- Mission 0.19.5 — Error handling (ADR-025), whose §28 specifies what every untested conversion boundary needs.
- Mission 0.19.9 — Testing Standards, which produced this ADR, the standard, and amendments A-045 and A-046.

## Implementation Status

**Documented. Volume 9's unit layer is partially met; every other layer is absent.**

`docs/development/testing-standards.md` carries the standard. Verified by audit and by recomputing every figure from the repository:

| Audited | Result |
|---|---|
| Test files | **4** |
| Tests | **28** — 27 `test()`, 1 `testWidgets()`, in 7 groups |
| Test tree mirrors `lib/` | Yes, for all 4 |
| Hand-written source files in `lib/` | **55** |
| Files instrumented by the suite | **16** |
| **Files never loaded by any test** | **39** |
| Coverage as CI reports it | **146 / 224 lines = 65%**, over the 16 instrumented files |
| Modules with zero test contact | `app/theme` 8 · `core/database` 7 · `core/errors` 6 · `core/network` 6 · `app/config` 4 · `core/storage` 4 · `core/firebase` 2 · `core/logging` 1 · `main.dart` |
| Mocking framework | **None** — no `mocktail`, no `Mock` subclass, no generated mock |
| Hand-written fakes | **1** — `_SilentOutput extends LogOutput` |
| `integration_test` directory | **Absent** |
| Golden tests or golden files | **Absent** |
| `dart_test.yaml`, fixtures, shared helpers | **Absent** |
| Clock abstraction | **Absent**; `DateTime.now()` called directly in 3 `core/` files |
| Automated performance test | **Absent, and correct** — Volume 9 §9.4 assigns 4 of 6 targets to manual measurement |
| Requirement-ID prefixes in test names | **0** — no Volume 1 requirement is implemented |
| `flutter test` | **28 passed** |
| `flutter analyze` | No issues |

No code was changed. Volume 3 §§3.1, 3.6, 3.7 and Volume 9 §§9.1, 9.4, 9.5, 9.6, 9.7 were read from the source PDFs and quoted from the extracted text.

**Two errors in this mission's own draft were caught by verification and corrected.**

1. **The untested-file count was computed wrongly on the first pass.** A path-matching bug in the coverage script compared `lib/core/...` against `core/...` and reported all 55 files as never loaded. Re-running with the prefix stripped gave 39, which is the figure recorded. A number this central to the audit had to be produced twice before it was trusted.

2. **The performance-testing finding was wrong, and reading the Volume reversed it.** The draft recorded *"no performance test of any kind — no Volume requires one for the mobile app."* Volume 9 **Chapter 9.4 is titled "Performance Requirements"** and fixes six measurable targets. The corrected finding is more useful than the original claim: no Volume asks for an automated performance *test*, because §9.4 assigns four targets to manual measurement and two to in-app instrumentation — so the absence of a performance suite is correct, and what is actually owed is instrumentation and procedures.
