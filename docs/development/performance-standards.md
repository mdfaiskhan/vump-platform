# Performance Standards

The canonical performance standard for the Vump Technologies repository.

Governed by **ADR-031**. Where this document and the ADR disagree, the ADR governs.

**The targets are not this document's.** Volume 1 fixes the requirements, Volume 9 Chapter 9.4 makes six of them measurable, Volume 5 fixes the capture and retry parameters, and Volume 4 accepts the backend's cold-start cost. This document consolidates them into one table, records **which are measured by what**, and records that **almost no instrumentation exists.**

**Nothing already governed is restated.** Cited, not duplicated:

| Already fixed by | What it fixes |
|---|---|
| Volume 1 §NFRs | `NFR-PERF-01/02`, `NFR-REL-01/02/04`, `NFR-AVL-01/02`, `NFR-SCL-01/02` |
| Volume 9 Ch. 9.4 | Six measurable targets and the method for each |
| Volume 9 Ch. 9.8, 9.9 | Manual and device testing — where four of the six are measured |
| Volume 5 Ch. 5.2 | Capture parameters and the device-tier degradation rule |
| Volume 5 Ch. 5.4 | Hardware encoder only; streamed checksumming |
| Volume 5 Ch. 5.13 | The retry backoff schedule, attempt cap and jitter |
| Volume 4 Ch. 4.1 | Lambda cold-start latency as an accepted trade-off |
| Volume 0 Ch. 0.2 §3 | Offline-first; never lose a take; recording decoupled from upload |
| ADR-029 · `testing-standards.md` §13 | Why there is no automated performance test |
| ADR-025 · `error-handling.md` §15–16 | Timeouts and the retryable/terminal classification |
| ADR-027 · `logging-standards.md` §11 | Why suppressed log levels still cost evaluation |

---

## 1. Why performance is a product requirement here

Volume 9 §9.4 §2 states it more plainly than a standard could: the Recording Screen *"runs continuously for up to 10 minutes per chunk, often back-to-back across a full field shift — a janky preview or excessive battery drain isn't a minor annoyance here, it's a direct threat to the product's core promise of reliable, unattended field capture."*

The Constitution §3 adds the constraints that shape every decision below: **offline-first**, **never lose a take**, and **recording and uploading are decoupled** — *"a collector must always be able to start a new recording while a previous session is still uploading."*

Volume 1 turns the last one into a rule with no exception: **"Recording throughput must never be gated on upload speed or network quality."**

---

## 2. The binding targets

Every numeric target in force, with its source and the method assigned to it.

| # | Target | Source | Measured by |
|---|---|---|---|
| **P1** | Recording preview starts **< 1.5 s** on a mid-range device | `NFR-PERF-01` | **Nothing — no method assigned (A-049)** |
| **P2** | Local chunking begins **< 2 s** after Stop | `NFR-PERF-02` | **Nothing — no method assigned (A-049)** |
| **P3** | Metadata generation **< 500 ms** per chunk | `NFR-META-01`, V9.4 §1 | In-app instrumented timestamp diff around Volume 5 §5.7's generation step |
| **P4** | Upload resumes **< 30 s** after connectivity returns | `NFR-AVL-02`, V9.4 §1 | In-app, from Chapter 9.3's recovery-time metric source |
| **P5** | Cold start to Login **< 2.5 s** on a mid-range device | V9.4 §1 | Manual stopwatch, Chapter 9.9 — *"no automated instrumentation needed for a one-time-per-launch metric"* |
| **P6** | Recording Screen **sustained 60 fps**, zero dropped-frame jank across a full chunk | V9.4 §1 | Flutter DevTools performance overlay, Chapter 9.8 manual device testing |
| **P7** | Battery drain **< 15 %** per 10-minute chunk on a reference mid-range device | V9.4 §1 | Manual measurement, Chapter 9.9 |
| **P8** | **No OOM kill** across a full multi-chunk session on the reference low-end device | V9.4 §1 | Android Studio / Xcode Instruments profiling, device testing |
| **P9** | Queue depth of **50+ pending chunks** without degrading device performance | `NFR-SCL-01` | **Nothing — no method assigned (A-049)** |
| **P10** | Backend scales to a growing fleet of concurrent Collectors | `NFR-SCL-02` | *"Verified under load during Volume 9 — Testing"*; no load test exists |

**Four of the ten have no measurement method at all.** P1, P2 and P9 are Volume 1 requirements with concrete numbers that Volume 9 Chapter 9.4 — the chapter subtitled *"Measurable Targets, Not Just Volume 1's Prose"* — does not carry. Verified: Volume 9 contains **zero occurrences of `PERF` or `SCL`**. Registered as **A-049**.

**None of the ten is measured today**, because all ten depend on recording, upload or a Login screen, and none exists.

---

## 3. The two frame rates are different numbers, deliberately

**This is the most likely thing for someone to "fix" wrongly.**

| | Value | Source | What it is |
|---|---|---|---|
| **Capture** frame rate | **30 fps** | Volume 5 §5.2 §1 | The rate frames are encoded into the chunk file |
| **UI** frame rate | **60 fps** sustained | Volume 9 §9.4 §1 (P6) | The rate Flutter renders the Recording Screen |

They are unrelated measurements of different subsystems. Volume 5 §5.2 §1 gives 30 fps as *"standard for smooth egocentric walkthrough footage without inflating file size"*; Volume 9 §9.4 asks the preview not to jank while that encode runs.

**Neither number may be changed to match the other.** Raising capture to 60 fps doubles chunk size against Volume 5 §5.2's file-size rationale; lowering the UI target to 30 fps accepts visible jank on a screen a Collector watches for ten minutes at a time.

---

## 4. Capture parameters are fixed, and degrade in one direction only

Volume 5 §5.2 §1 is the authoritative source for every value:

| Parameter | Value | Volume 5's rationale |
|---|---|---|
| Resolution | 1920×1080 | *"Balances footage usability against chunk file size / upload time on constrained field connectivity"* |
| Frame rate | 30 fps | Smooth egocentric footage without inflating file size |
| Codec | H.264 (AVC) | *"Universal hardware-encoder support… keeping battery/thermal impact low during a 10-minute continuous encode"* |
| Target bitrate | ~8,000 kbps | *"Keeping a 10-minute chunk in the low hundreds of MB, not gigabytes"* |
| Audio | AAC, mono, 128 kbps | *"Mono keeps size down since stereo separation isn't meaningful for a body-worn/handheld capture"* |
| Zoom | 0.5× or 0.6×, device-dependent | Fixed for the whole session, never changed mid-recording |

**The degradation rule, from Volume 5 §5.2 §2:** on lower-end devices where the target bitrate exceeds the encoder's stable hardware capability, the pipeline *"steps down bitrate (never resolution or frame rate) in fixed increments"*.

**The reason is dataset consistency, not device sympathy** — *"keeping the field of view and smoothness consistent across the Collector fleet, which matters more for usable training data than a slightly larger file."* A performance fix that lowered resolution on a slow device would silently produce footage that cannot be compared with the rest of the dataset.

**Hardware encoder only.** Volume 5 §5.4 §1: frames stream to *"the device's hardware video encoder — never a software encoder, to keep battery/"* thermal cost down. A software encoder is a correctness-of-performance failure, not a fallback.

**Zoom selection is cached per device model**, decided once at first launch and *"not re-negotiated every session, so footage from the same device is always comparable to itself over time."* That is the one cache Volume 5 specifies.

---

## 5. Memory

**Streamed, never whole-file.** Volume 5 §5.4 computes the chunk checksum *"streamed in fixed-size blocks rather than loading the whole file into memory"* — `FR-META-10`. A 10-minute chunk is in the low hundreds of MB, so a whole-file read is an OOM on the reference low-end device, which is P8's target.

**The upload queue is not in memory.** Volume 5 §5.6 §3: *"The queue is not an in-memory list — it is a live view (Riverpod `StreamNotifier`) over `local_chunks.status`"* in the local database. That is what satisfies `NFR-REL-04` — full queue state restored after a force-close — and it is also why P9's 50+ queued chunks do not scale with memory.

**Database address space is reserved, not allocated.** `DatabaseConstants.maxSizeMiB = 512`, documented in place: *"Isar reserves virtual address space up to this size at open; it is a ceiling, not an allocation. Raising it later is safe, lowering it below the current file size is not."*

**No memory instrumentation exists.** P8 is measured by a profiler during device testing (V9.4 §1), and nothing in the app reports its own footprint.

---

## 6. Storage and database performance

**`relaxedDurability = true`**, and the trade is recorded at the constant: *"True trades durability under abrupt power loss for throughput. Acceptable because this database holds cached and reconstructible data — never a secret, per ADR-008, and never the sole record of a user's work."*

**That last clause is load-bearing and will be tested by the upload queue.** `NFR-REL-04` requires queue state to survive a force-close, and Volume 5 §5.6 §3 puts the queue in this database. A force-close is not abrupt power loss, so the two are compatible today — but the moment the database becomes the sole record of which chunks are pending, `relaxedDurability` deserves re-examination against `NFR-REL-01`'s zero-data-loss requirement. Recorded here rather than assumed safe.

**Isar is a synchronous, single-file store with no query cache of its own configured.** No index is declared beyond `DatabaseMetadata`'s primary key, and the metadata collection holds exactly one row with a fixed id, so no query performance question exists yet.

---

## 7. Network efficiency

**Timeouts** are fixed by ADR-007 and specified in `error-handling.md` §15: 15 s connect, 30 s receive, 30 s send.

**`sendTimeout` is the one that will not survive contact with upload.** `NetworkConstants` already records it: *"Uploads that need longer must raise it per request."* A 10-minute chunk at a few hundred MB will not transmit in 30 seconds on a field connection, so the upload path sets a per-request `Options` rather than raising the global default — raising the global would make every ordinary request wait minutes before failing.

**Retry backoff is fully specified by Volume 5 §5.13 §2 and is a performance decision as much as an error one:**

| | |
|---|---|
| Schedule | Exponential — **5 s, 10 s, 20 s, 40 s**, capped at **5 minutes** between attempts |
| Attempt cap | **6 automatic attempts** per chunk, then `Failed` |
| Jitter | **±20 %** on each delay |

**The jitter has a stated purpose and it is the thundering-herd case:** *"so that many chunks failing at once (e.g. a whole batch losing connectivity together) don't all retry in the same instant and thundering-herd the backend the moment connectivity returns."*

**Manual retry resets the attempt counter** and fires immediately — *"a deliberate Collector override of the automatic backoff schedule, not a bypass of Section 1's terminal-failure classification."*

**Retry is safe by construction, not by discipline.** Volume 5 §5.13 §4: every retry reuses the same `chunk_id`, the same deterministic S3 key and where possible the same multipart upload ID, so *"there is structurally no code path that generates a new key for the same chunk."*

**One divergence from `error-handling.md` §16.** Volume 5 §5.13 §1 classifies a server-side 4xx as terminal and not retried. `error-handling.md` §16 lists `NETWORK_RATE_LIMITED` (HTTP 429, a 4xx) as **retryable**, honouring `Retry-After`. Registered as **A-050** — the Volume's examples are auth and permission errors, so 429 is likely outside what it meant, but the blanket wording covers it.

**Log volume is a network-adjacent cost.** Production emits `warning` and above (ADR-027 §11), so request and response logging is off outside development — a `debug` line per request during a field shift would be pure overhead.

---

## 8. Startup

**P5 — cold start to Login < 2.5 s.** Measured by a manual stopwatch during device testing, and V9.4 §1 justifies not instrumenting it: *"no automated instrumentation needed for a one-time-per-launch metric."*

**What startup does today**, from `main.dart`, in order: `WidgetsFlutterBinding.ensureInitialized()`, build the `ProviderContainer`, read the logger, log the resolved environment, `await` Firebase initialisation, then `runApp`.

**One `await` sits between the process starting and the first frame.** Firebase initialisation is on the critical path by design — ADR-010 requires it exactly once, off the widget tree, and ADR-017 makes its failure fatal in staging and production. Its duration is already logged, which is the instrumentation P5 would otherwise need.

**Database open is not on the startup path today.** `databaseProvider` is a `FutureProvider`, and Riverpod providers are lazy, so nothing opens the database until something reads it. Volume 6 §6.1 §2's bootstrap sequence puts opening the local database *before* `runApp` — *"before any provider reads it"* — which the current `main.dart` does not do. That is a divergence with a performance consequence in both directions: today startup is faster and the first database read pays the cost; under Volume 6 §6.1 §2 startup is slower and predictable.

**No provider is `autoDispose`.** Verified: no `autoDispose` or `keepAlive` anywhere. Every provider is created on first read and lives for the process, which is the correct default for infrastructure and worth revisiting for per-screen state.

---

## 9. Background work and concurrency

**Nothing runs in the background today.** Verified: no `Isolate`, no `compute()`, no `WorkManager`, no foreground-service code anywhere in `lib/`.

The Constitution §3 requires recording and uploading to be decoupled, and Volume 1 requires *"recording throughput must never be gated on upload speed or network quality"* — so background upload is a requirement, not an optimisation. Volume 3 §3.4 confines it to the Platform Services layer, and Volume 9 §9.6 §4 and §9.7 §3 both state that real background upload across an app kill cannot be faked and belongs to manual and device testing.

**Chunking is CPU work that must not block the UI.** Volume 5 §5.3 places it after Stop, never during active recording, and `NFR-PERF-02` requires it to *begin* within 2 s. Nothing implements it, so whether it runs in an isolate is undecided.

---

## 10. Caching

**There is no cache in the repository, and one absence is a recorded decision.**

`SecureStorageService` deliberately does not cache, and says why: *"ADR-008 notes that a Keychain round trip costs milliseconds and that hot values should be held in memory, but a cache needs an invalidation rule, and inventing one here would guess at how authentication will behave."*

**That is the pattern for every future cache: the invalidation rule is the decision, not the cache.** A cache added without one is a correctness bug wearing a performance costume.

**Two caches are specified elsewhere and unimplemented:** the per-device zoom-factor selection cached at first launch (Volume 5 §5.2 §2), and the offline read cache for Projects and Tasks that Volume 3 §3.9 §3 requires so *"the Collector/Admin dashboards work offline against the last-synced data."*

---

## 11. Instrumentation, benchmarking and profiling

**No profiling API is used anywhere.** Verified: no `Timeline`, no `dart:developer`, no `SchedulerBinding.addTimingsCallback`, no `FrameTiming`, no `PerformanceOverlay`.

**No benchmark exists**, and none is required — `testing-standards.md` §13 records why: Volume 9 §9.4 assigns four of its six targets to manual measurement and two to in-app instrumentation, so an automated performance suite is not something any Volume asks for.

**What instrumentation does exist is duration logging**, in three places, all as `DateTime.now()` differences written to a log line:

| Site | Measures |
|---|---|
| `DatabaseService` | Database open duration, with collection count |
| `FirebaseInitializer` | Platform initialisation duration |
| `LoggingInterceptor` | Per-request elapsed time, via a start stamp in `RequestOptions.extra` |

**That is the same shape P3 and P4 need**, and it is the precedent to follow — an instrumented timestamp diff, per V9.4 §1.

**It is also not yet assertable.** `testing-standards.md` §9 and **A-045** record the constraint: `DateTime.now()` is called directly rather than through an injected clock, so none of these durations can be tested. That is tolerable for a log line and not for a target — the moment P3's 500 ms becomes a pass/fail number, the clock has to be injectable.

**Profiling is a build-mode question.** Flutter's profile mode is the only valid mode for measuring frame time and CPU; debug-mode numbers are meaningless and release mode has no observatory. Nothing in the repository configures or documents a profile build, and `flutter build apk --profile` has never been run here.

---

## 12. CI verification

**No CI job measures anything about performance**, and none should be added without a target it can check. The nine jobs are correctness gates.

**Two jobs bound performance-relevant risk indirectly:** `Analyze` enforces the `prefer_const_*` family and `avoid_unnecessary_containers`, `use_colored_box` and `use_decorated_box` (ADR-021), which change how much work a frame does rather than merely how code reads. And `AWS credential isolation` keeps the app off any AWS SDK, so uploads go through presigned URLs rather than a client library with its own retry and buffering behaviour.

**CI runs `ubuntu-latest`** and cannot measure a device metric. Every target in §2 that is measured at all is measured on a physical device (Volume 9 §9.8, §9.9).

---

## 13. Platform differences

**Android is the primary target.** The Constitution §2 fixes it: *"90–100% of development… to happen on Windows using Android as the primary test target"*, with iOS *"secondary to Android during the MVP phase"* and built via a cloud Mac or CI service.

**The performance consequence:** every target in §2 is measured on Android first, and the reference devices Volume 9 §9.4 names — *"a reference mid-range device"*, *"the reference low-end device"* — are Android. iOS numbers are unmeasured, and Volume 9 Chapter 9.9's device matrix, which would name the devices, does not exist in the repository.

**Two Android-specific risks are already recorded**, both from A-029: the Gradle shim forces `compileSdk 36` on `isar_flutter_libs`, code written for API 30 — *"it compiles, but that combination was never tested by the package author"* — and **16 KB page size support for those prebuilt native libraries is unverified**, which A-029 calls the next likely release blocker. Page size affects memory behaviour directly, so it belongs on this list as well as that one.

---

## 14. Known bottlenecks and gaps

Recorded rather than fixed — this is a documentation and governance mission.

| Item | Evidence | Disposition |
|---|---|---|
| **4 of 10 targets have no measurement method** | P1, P2, P9, P10. Volume 9 contains zero occurrences of `PERF` or `SCL` | **A-049.** V9.4 is subtitled *"Measurable Targets"* and omits three of Volume 1's numeric ones |
| **No target is measured today** | All ten depend on recording, upload or a Login screen | Correct — none of those exists |
| **No profiling API, no benchmark, no profile-mode build** | §11 | Correct by design for the suite (ADR-029); the profile build is a gap when device testing starts |
| **Duration instrumentation is not assertable** | `DateTime.now()` direct, no injected clock | **A-045.** Blocks P3 and P4 from becoming pass/fail |
| **`relaxedDurability` versus the upload queue** | The constant's own justification depends on the database *"never [being] the sole record of a user's work"* | §6. Re-examine when the queue lands, against `NFR-REL-01` |
| **Volume 6 §6.1 §2 puts database open before `runApp`; `main.dart` does not** | §8 | A divergence with a performance consequence either way. Not registered — Volume 6 §6.1 §2 also names Drift and `HumanArchiveApp`, both already amended (A-002), so the sequence needs reading against ADR-009 first |
| **429 classified terminal by V5.13, retryable by ADR-025** | §7 | **A-050** |
| **16 KB page size unverified** | A-029 | Memory behaviour on modern Android; the next likely release blocker |
| **iOS performance entirely unmeasured** | §13 | Accepted for MVP by Constitution §2 |
| **No device matrix** | Volume 9 Ch. 9.9 gates every release and does not exist here | Blocks P5–P8, which are all device-measured |

---

## 15. Maintenance

- **A new numeric target needs a measurement method named at the same time**, or it joins the four in §2 that cannot be checked.
- **A performance change to capture parameters is a Volume 5 §5.2 change**, not a local tuning decision — and degradation steps down bitrate only (§4).
- **A new cache needs its invalidation rule decided first** (§10).
- **A new `await` before `runApp` costs cold-start time against P5.** Adding one is a decision.
- **Never measure in debug mode.** Profile mode is the only valid mode for frame time or CPU (§11).
- **Instrument with an injected clock, not `DateTime.now()`**, once a duration is a target rather than a log line.
- **Every figure here is re-derived from the Volumes and the code**, not copied forward. §2's table is the consolidated view; the Volumes remain authoritative.
