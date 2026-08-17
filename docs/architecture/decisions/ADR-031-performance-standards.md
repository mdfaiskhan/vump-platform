# ADR-031 — Performance Standards

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Consolidates the performance targets fixed across Volumes 1, 4, 5 and 9. Registers A-049 and A-050.

## Context

**Ten numeric performance targets are in force and they are spread across four volumes.** Volume 1 fixes `NFR-PERF-01/02`, `NFR-AVL-02`, `NFR-SCL-01/02` and `NFR-META-01`. Volume 9 Chapter 9.4 makes six targets measurable and assigns a method to each. Volume 5 Chapter 5.2 fixes the capture parameters and Chapter 5.13 the retry backoff. Volume 4 Chapter 4.1 accepts Lambda cold-start latency as a trade-off.

**No document in the repository lists them, and no ADR records any of it.** A developer asking "what is the frame-rate target" has to know that the answer is in Volume 9 while the *capture* rate is in Volume 5, and that the two numbers are deliberately different.

**Three targets have no measurement method anywhere.** Volume 9 Chapter 9.4 is subtitled *"Measurable Targets, Not Just Volume 1's Prose"*, and Volume 1's own `NFR-PERF` family is not in it. Verified: **Volume 9 contains zero occurrences of `PERF` and zero of `SCL`.** So `NFR-PERF-01` (preview starts < 1.5 s), `NFR-PERF-02` (chunking begins < 2 s) and `NFR-SCL-01` (50+ queued chunks without degrading the device) are requirements with concrete numbers and no assigned method.

**Two decisions with real performance consequences exist in code with no ADR behind them.** `DatabaseConstants.relaxedDurability = true` trades durability under abrupt power loss for throughput, justified because the database *"never [holds] the sole record of a user's work"* — a clause the upload queue will directly test, since Volume 5 §5.6 §3 puts the queue in that database and `NFR-REL-04` requires it to survive a force-close. And `SecureStorageService` deliberately does not cache, because *"a cache needs an invalidation rule, and inventing one here would guess at how authentication will behave."* Both reasons are good; both live only in a doc comment.

**And almost nothing is instrumented.** Verified: no `Timeline`, no `dart:developer`, no `SchedulerBinding.addTimingsCallback`, no `FrameTiming`, no benchmark, no profile-mode build. What exists is three duration log lines built from `DateTime.now()` differences — the right shape for two of Volume 9's targets, and not assertable because the clock is not injected (A-045).

## Decision

### The targets are consolidated into one table, with their measurement method

`docs/development/performance-standards.md` is the canonical performance standard: fifteen sections covering why performance is a product requirement here, the ten binding targets, the two frame rates, capture parameters and degradation, memory, storage, network, startup, background work, caching, instrumentation, CI, platform differences, bottlenecks and maintenance.

**The targets are not this document's and it says so.** Volume 1, Volume 5 and Volume 9 remain authoritative; §2's table is a consolidated view that names the source and the method for each of the ten, and marks the four that have no method.

Placed in `docs/development/` beside the other practice standards, per ADR-024 §20.

### The two frame rates are recorded as deliberately different

**Capture is 30 fps (Volume 5 §5.2 §1). The UI target is sustained 60 fps (Volume 9 §9.4 §1).** They measure different subsystems and neither may be changed to match the other.

This is recorded because it is the most plausible wrong "fix" available: raising capture to 60 fps doubles chunk size against Volume 5 §5.2's explicit file-size rationale, and lowering the UI target to 30 fps accepts visible jank on a screen a Collector watches for ten minutes at a stretch. Two numbers that look like a contradiction and are not.

### Degradation steps down bitrate only

Volume 5 §5.2 §2's rule is adopted verbatim as a performance rule: on a device whose encoder cannot sustain the target bitrate, the pipeline steps down **bitrate, never resolution or frame rate**.

**The reason is dataset consistency, not device sympathy** — Volume 5 states it as *"keeping the field of view and smoothness consistent across the Collector fleet, which matters more for usable training data than a slightly larger file."* A well-meaning performance fix that lowered resolution on a slow device would silently produce footage that cannot be compared with the rest of the dataset, which is a product failure rather than a performance one.

**The hardware encoder is mandatory** (Volume 5 §5.4 §1): a software-encoder fallback is a performance-correctness failure, not a graceful degradation.

### A cache is decided by its invalidation rule

`SecureStorageService`'s reasoning is promoted from a doc comment to a rule: **the invalidation rule is the decision; the cache is the consequence.** A cache added without one is a correctness bug wearing a performance costume.

Two caches are specified elsewhere and unimplemented — the per-device zoom-factor selection (Volume 5 §5.2 §2) and the offline Projects/Tasks read cache (Volume 3 §3.9 §3).

### Instrumentation follows the pattern that exists, with an injected clock

Volume 9 §9.4 §1 assigns two targets to an *"instrumented timestamp diff"*, which is exactly the shape of the three duration log lines already in `core/`. Those are the precedent.

**With one change: a duration that is a target must be measured through an injected clock, not `DateTime.now()`.** A log line can afford to be unassertable; a pass/fail number cannot. A-045 records the underlying rule and where it is unrecorded in the Volumes.

**Never measure in debug mode.** Profile mode is the only valid mode for frame time or CPU. Nothing in the repository configures a profile build, which is a gap that opens when device testing starts rather than now.

### No automated performance test, and no CI performance gate

Restated by reference rather than re-decided: ADR-029 already records that Volume 9 §9.4 assigns four of six targets to manual measurement and two to in-app instrumentation, so **no Volume asks for an automated performance test.** No CI job measures performance, and none should be added without a target it can actually check — CI runs `ubuntu-latest` and cannot measure a device metric.

### Two divergences are registered

- **A-049** — Volume 9 §9.4 omits `NFR-PERF-01`, `NFR-PERF-02` and `NFR-SCL-01`, so three of Volume 1's numeric requirements have no measurement method.
- **A-050** — Volume 5 §5.13 §1 classifies a server-side 4xx as terminal and not retried; `error-handling.md` §16 lists HTTP 429 as retryable, honouring `Retry-After`.

## Alternatives Considered

- **Write no performance standard; the targets are already in the Volumes.** Rejected. Ten targets across four volumes with four unmeasured and two frame rates that look contradictory is precisely the situation a consolidated reference exists for. Nothing in the repository previously said what the targets were.

- **Build performance instrumentation now.** Rejected. All ten targets depend on recording, upload or a Login screen, and none exists — so instrumentation would measure nothing and would be written against an unknown call site. The two in-app targets get their instrumentation in the mission that builds the step they measure.

- **Add a CI performance gate — a frame-budget or startup-time check.** Rejected. CI runs on `ubuntu-latest`, where a device metric is meaningless, and Volume 9 §9.4 assigns every device-measured target to a physical device (Chapters 9.8, 9.9). A CI number would be precise and irrelevant.

- **Adopt an automated benchmark suite.** Rejected, consistent with ADR-029: no Volume asks for one, and Volume 9 §9.4's methods are a stopwatch, a DevTools overlay, a profiler and two instrumented diffs. A benchmark suite would be inventing a testing layer the specification does not have.

- **Reconcile the two frame rates to one number.** Rejected in both directions, with the cost of each recorded. They are different subsystems.

- **Change `relaxedDurability` to `false` pre-emptively**, ahead of the upload queue. Rejected as premature. The constant's justification is sound *today* — the database holds cached, reconstructible data — and the standard records the precise condition under which it stops being sound, which is more useful than flipping a flag before the queue exists.

- **Register the `main.dart` versus Volume 6 §6.1 §2 bootstrap difference as an amendment.** Rejected for now, and this is a deliberate restraint. Volume 6 §6.1 §2 puts opening the local database before `runApp`; `main.dart` awaits only Firebase, and `databaseProvider` is a lazy `FutureProvider`. The divergence has a real performance consequence in both directions — faster startup and a deferred cost, versus slower and predictable. But §6.1 §2 also names Drift and `HumanArchiveApp`, both already amended (ADR-009, A-002), so the sequence needs reading against the Isar decision before it can be recorded accurately. Registering it now would mean amending a clause whose other halves are already superseded, and I would be guessing which part still binds.

- **Fold performance into `testing-standards.md`**, since ADR-029 §13 already covers performance measurement. Rejected. That section answers "is there a performance test" — this standard answers "what are the targets, where do they come from, and what measures each." The former cites the latter, which is the direction that avoids duplication.

## Consequences

- **The ten targets are in one table with their sources**, so the answer to "what is the target" no longer requires knowing which volume to open.

- **Four targets are now visibly unmeasured**, three of them because Volume 9 omitted Volume 1's `NFR-PERF` family. That is a specific, closable documentation gap rather than a vague sense that performance is untracked.

- **The frame-rate distinction is protected.** The most likely wrong fix now has a written reason against it, in the document someone would read before making it.

- **The degradation direction is fixed**, so a future device-tier optimisation cannot quietly trade dataset comparability for smoothness.

- **`relaxedDurability`'s expiry condition is recorded.** The flag is correct now and the standard names exactly what changes when the upload queue lands — which is better than either leaving it undocumented or flipping it early.

- **A-045 is now blocking two targets rather than being a testing nicety.** P3's 500 ms and P4's 30 s cannot become pass/fail numbers while the clock is called directly.

- **No instrumentation is added, so nothing is measured.** That is correct while the measured subsystems do not exist, and it means every target in §2 is aspirational today. The standard says so in the table rather than in a footnote.

- **The profile-mode gap is named.** `flutter build apk --profile` has never been run here, and it is the only valid mode for the frame-time and CPU measurements Volume 9 §9.8 assigns to DevTools.

- **iOS performance stays unmeasured**, accepted by Constitution §2's Android-first position. Every reference device Volume 9 §9.4 names is Android, and the device matrix that would name them does not exist.

- **Nothing in the repository changed.** No instrumentation, no CI job, no capture parameter.

## Related Missions

- Mission 0.19.5 — Error handling (ADR-025), whose §15–16 fix timeouts and the retryable classification A-050 now qualifies.
- Mission 0.19.7 — Logging (ADR-027), whose duration log lines are the instrumentation precedent.
- Mission 0.19.9 — Testing (ADR-029), which recorded why there is no automated performance test and registered A-045's clock finding.
- Mission 0.18.8A — the Gradle shim (A-029), whose unverified 16 KB page-size support is a memory risk this standard records.
- Mission 0.19.11 — Performance Standards, which produced this ADR, the standard, and amendments A-049 and A-050.

## Implementation Status

**Documented. Nothing is instrumented, and nothing is measured.**

`docs/development/performance-standards.md` carries the standard. Verified by audit:

| Audited | Result |
|---|---|
| Numeric targets in force | **10**, across Volumes 1, 4, 5 and 9 |
| Targets with a measurement method assigned | **6** — all in Volume 9 §9.4 |
| Targets with **no** method | **4** — `NFR-PERF-01`, `NFR-PERF-02`, `NFR-SCL-01`, `NFR-SCL-02` |
| Occurrences of `PERF` in Volume 9 | **0** |
| Occurrences of `SCL` in Volume 9 | **0** |
| NFRs Volume 9 does cite | `NFR-META-01`, `NFR-AVL-02` |
| Targets measured today | **0** — all depend on subsystems that do not exist |
| Profiling APIs used (`Timeline`, `dart:developer`, `FrameTiming`, `SchedulerBinding` timings) | **0** |
| Benchmarks | **0** |
| Profile-mode build ever run here | **No** |
| Duration instrumentation sites | **3** — `DatabaseService`, `FirebaseInitializer`, `LoggingInterceptor`, all `DateTime.now()` diffs |
| Injected clock | **None** (A-045) |
| Isolates, `compute()`, background workers | **0** |
| Caches implemented | **0**; one absence is a recorded decision (`SecureStorageService`) |
| `autoDispose` / `keepAlive` providers | **0** — every provider is lazy and process-lived |
| Isar indexes declared | **0** beyond `DatabaseMetadata`'s `Id id` |
| `await` calls before `runApp` | **1** — Firebase initialisation |
| Database opened before `runApp` | **No** — `databaseProvider` is a lazy `FutureProvider` |
| CI jobs measuring performance | **0** |
| `flutter analyze` | No issues |

No code was changed. Volume 1's NFR table and Volume 5 §§5.2, 5.4, 5.6, 5.13 were read from the source PDFs for the first time in this mission; Volume 9 §9.4 was read in Mission 0.19.9.

**Two verification steps changed what this ADR says.**

**A failed grep was nearly recorded as a finding.** Searching Volume 9 for `NFR - [A-Z]+ - ?[0-9]+` returned nothing, which would have supported the claim that Volume 9 cites no NFRs at all — but the same pattern also returned nothing for `NFR-META-01`, which Volume 9 demonstrably contains. The pattern was wrong, not the volume. Re-checking with a plain substring search gave the accurate result: `META` appears twice, `AVL` three times, `PERF` and `SCL` zero times. **A-049 rests on that second measurement, not the first.**

**The startup claims were checked against `main.dart` rather than inferred.** The draft assumed the database was opened during startup because Volume 6 §6.1 §2 requires it. It is not: `main.dart` awaits only Firebase, and `databaseProvider` is a lazy `FutureProvider<Isar>`, so nothing opens the database until something reads it. That is a divergence from Volume 6 §6.1 §2 with a genuine performance consequence, and it is recorded as a gap rather than an amendment for the reason given in Alternatives.
