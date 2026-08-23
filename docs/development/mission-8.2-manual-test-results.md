# Mission 8.2 — Manual Test Plan, Pass 1 — Results

Volume 9 Chapter 9.8's scenarios and Chapter 9.4's performance targets, executed on real hardware. Every result here was observed on a device; nothing is inferred from a simulator, and every "does it look right" judgement came from the project owner rather than from logs.

**Device:** CPH2707 (`f389ad31`), Android 15, dual SIM (JIO / airtel).
**Builds:** each scenario records the commit it ran against. A-205's double wipe — emptying both `apk/` and `flutter-apk/` — was performed before every build, with artefact mtimes checked against the wipe time.

---

## Chapter 9.8 — 5 of 5 closed

| # | Scenario | Status |
|---|---|---|
| 1 | Real wide-angle capture | **PASS** |
| 2 | Background upload survives app kill | **PASS** (build `e1b53d4`) |
| 3 | Sustained recording, thermal and battery | **PASS**, one human sub-check unassessed |
| 4 | Real offline field conditions | **PASS** |
| 5 | Accessibility pass | **PASS** |

### 1 — PASS

Tier `PRIMARY_SENSOR_ZOOM` (Tier 2), zoom **0.6**, **1920x1080 at 30 fps** — matching Chapter 5.1 and BR-02.

Judged from the recorded file rather than a live preview. The original approach assumed a viewfinder existed; it does not, which A-064 §5 records. The reviewed frame is genuinely wide, with no letterboxing, no severe fisheye, and straight lines staying straight.

### 2 — PASS, against build `e1b53d4`

**This supersedes an earlier FAIL without contradicting it.** The FAIL is accurate documentation of the pre-fix build and remains on record. This is a new result against fixed code.

Chunk `ae6e8d43-6922-4b59-b43b-7a1d04e320d0`, **275,896,765 bytes**, `am force-stop` issued **4.2 s** into a live multipart transfer — 3 PUTs issued, 0 completed, process gone, 0 service records.

On relaunch, with nothing else touching the device:

```
22:27:24.205  Vump Technologies starting
22:27:25.561  Network restored — claiming the queue.
22:27:25.714  Chunk ae6e8d43… was left uploading by a process that did
              not finish. Returned to the queue as attempt 1 of 6.
22:27:26.386  → POST /sessions        0.67 s after reconciliation
22:27:27.194  → PUT                   1.48 s after reconciliation
      … 17 multipart parts …
22:28:08.379  → POST /metadata → {status: complete, verified: true}
22:28:14.522  Chunk ae6e8d43… uploaded.
```

Relaunch to first PUT **2.99 s**; relaunch to complete **50.3 s**. **S3 21 to 22**, the object byte-exact against the file on disk. The project owner confirmed on screen: uploading automatically, bar and percentage advancing, upload completed. No Retry Chunk button — correct, since the chunk was never `failed`.

The defect this scenario originally exposed is open item 137, now closed; the fix is ADR-052.

### 3 — PASS on the machine half; heat-feel UNASSESSED

Session `86861bb9`, **25.2 minutes continuous**.

- **Two BR-06 boundary crossings**, registration interval **587 s** against the 600 s target — within **2.2 %**
- Three chunks uploaded and verified: 697 MB, 613 MB, 335 MB
- **Zero crashes, ANRs, engine restarts or process death** — pid stable throughout
- Battery **−6 %**, temperature **+4.3 °C to 42.2 °C** over 24 min 7 s
- Thermal level climbed 3 to 12 monotonically, **no throttle event, no shutdown**

**The battery figure is a partial-window measurement, not a clean result.** Recording began before the cable was out, the device charged through the first two minutes (level rose 49 to 52 %), and the start was already warm at 37.9 °C. True drain is higher than −6 % by whatever charging added.

**The human sub-check is UNASSESSED, not passed and not inconclusive.** Chapter 9.8 asks whether the phone *feels uncomfortably hot*. Too much time passed between the recording and the question, and the project owner correctly declined to report a recalled impression rather than a real one. Recorded as a gap. Cheap to close: ask immediately after stopping, next time a sustained recording runs.

### 4 — PASS

**A genuine low-signal area, not the airplane-mode substitute.** Chapter 9.8 asks for *"airplane mode in an actual low-signal area, not just a simulator toggle"*, and this was run in a location where mobile data rarely works.

**One precondition nearly invalidated the run and was caught before it started.** The device was routing data over IWLAN — Wi-Fi calling — with `mIsIwlanPreferred=true`. Had Wi-Fi stayed enabled, walking into a cellular dead zone would have changed nothing, the app would never have seen connectivity degrade, and the scenario would have recorded a pass for a test that never happened. Wi-Fi was disabled and the active transport confirmed as `CELLULAR` on `rmnet_data3` before recording began.

Recording started on normal signal, continued into the low-signal area, and was stopped there — so the chunk finalized and entered the queue **while signal was bad**, which is the actual field scenario rather than a single toggle.

```
22:42:54.467  [282 CELLULAR] CONNECTED → DISCONNECTED     genuine outage
22:42:55.7–56.0  resolv: Validation failed ×6             DNS dead
22:42:56.656  App: "Network restored — claiming the queue."
22:43:22.930  [283 CELLULAR] validation passed            internet usable
22:43:23.333  App: → POST /sessions                       0.4 s later
22:43:27.605  App: → PUT  (chunk 91be5549, 201,385,519 B)
      … 9m 51s, one part, ~35 kB/s, no error, no timeout …
22:53:18.945  [284 WIFI] becomes default, validation passed
      … 42.6 s more — the in-flight part still does not finish …
22:54:01.587  App relaunched (swipe-away and reopen)
22:54:21.712  Reconciliation: "Chunk 91be5549 was left uploading…"
22:54:24.542  → PUT  … 13 parts at ~2.5 s each
22:55:08.742  Chunk 91be5549 uploaded.        S3 22 → 23
```

**What passed.** The outage was real and the app handled it correctly: connectivity loss detected, work held, **no error, no crash, no Failed state, no data loss**, and an autonomous resume **0.4 seconds** after the link became genuinely usable — with nothing touched, no force-stop, no manual retry. The upload then progressed steadily on a **−103 to −105 dBm** link.

**Independently corroborated.** The project owner observed that ordinary web browsing was also slow on the same connection. That rules out the alternative reading — that the app was stalled and merely appeared slow — and establishes the constraint as the network rather than the upload path.

**A third, unprompted confirmation of ADR-052.** The swipe-away was not part of the plan. It killed the process mid-transfer and left the row at `uploading` — precisely open item 137's old trap. Reconciliation caught it 20 seconds after relaunch and drove the chunk to completion. Because this happened by accident rather than by script, it is stronger evidence than the designed run in scenario 2.

**One behaviour recorded but not counted against the scenario:** the in-flight transfer did not benefit from Wi-Fi becoming available. That is open item 142, filed as tracked behaviour rather than a defect, with its own honest statement of what the 42.6-second observation window does and does not prove.

### 5 — PASS

**Automated semantics tree: PASS.** All five tabs are real touch targets at **62x69 dp**, clearing the 48x48 minimum. Every element is labelled, tabs announce their position, and session cards carry composed labels. The three small nodes are labels rather than clickable targets, so the 48 dp rule does not apply — checked rather than assumed.

**TalkBack sweep, all five tabs: PASS.** Driven by the project owner on the device, not inferred from the tree. The Dashboard reads its composed status labels correctly (*"waiting to upload 0, uploading 0, uploaded…"*), and every tab announces its position — *"Projects tab 2 of 5, button"* and so on. Drilling Projects to a Project to a Task read the task name, the instructions, and — worth noting — **the empty state aloud**: *"this task has no reference examples"*, spoken rather than silently skipped. **No blank elements, no raw ids, nothing visible that TalkBack skipped.**

**Contrast in direct sunlight: PASS.** Checked outdoors in bright light. Nothing washed out, and **the status colours and the checklist's pass/fail icons stayed distinguishable** — the specific risk, since a hue that separates cleanly indoors can collapse in sunlight and Collectors work outdoors.

**Touch-target feel: PASS.** Normal use across tabs, cards and the re-run buttons. No missed taps and nothing fiddly, including the elements the automated sweep could not judge because they sit inside cards and rows.

**This scenario found the mission's most severe defect.** The TalkBack sweep is what surfaced open item 144 — the Pre-Recording Checklist had no way out at all. It was never an accessibility defect; every user was equally stuck, and a screen reader is simply what made it visible. Fixed and device-verified within this mission.

---

## Chapter 9.4 — 4 of 6 closed or scoped

| # | Target | Status |
|---|---|---|
| 2 | Upload resume < 30 s | **PASS** — 4.7 s, see the ruling below |
| 3 | Cold start < 2.5 s | **PASS** — median ~2119 ms, steady state |
| 5 | Battery < 15 % per 10-minute chunk | **PASS, with caveats** — ~2.5 % observed |
| 6 | No OOM across a multi-chunk session | **PASS, single-device scoped** |
| 1 | Metadata generation < 500 ms | **DEFERRED** — not instrumented |
| 4 | 60 fps sustained, zero jank | **DEFERRED to 8.3** — needs a profile build |

### Target 2 — the measurement depends on what "network restoration" means

Two defensible readings, landing on opposite sides of the threshold:

| Measured from | To first PUT | |
|---|---|---|
| The OS signal the app acted on — **22:42:56.656** | **30.9 s** | marginally over |
| Internet genuinely validated — **22:43:22.930** | **4.7 s** | comfortably under |

The 26-second gap between them is a period in which **the radio had reattached but the link could not resolve DNS** — six `resolv: Validation failed` entries sit inside it. The OS was reporting a network that did not yet work.

**Ruled: measure from validation. Result PASS at 4.7 s.** The target's intent is real usability, not a possibly-premature OS signal — the same principle that caught the IWLAN confound before this scenario started. Both timestamps are recorded here rather than only the passing one, so a later reader can apply the other definition if they disagree.

The app's own responsiveness is not in question under either reading: its first API call came **0.4 seconds** after validation passed.

**Measurement conditions.** The chunk was `queued` and freshly finalized, attempt count **1**, so no backoff deadline was involved and `clearBackoff` played no part. The Wi-Fi restoration later in the same run is **not** a second valid measurement: at that moment the chunk was `uploading`, not queued, so there was no queued work awaiting resume.

### Target 6 — what "single-device scoped" means

Chapter 9.4 asks for no OOM kill across a full multi-chunk session. Scenario 3's run was exactly that — 25 minutes, three chunks, roughly 1.6 GB — with no OOM, no process death and a stable pid throughout. That satisfies the condition **on this device**. Chapter 9.4 specifies *the reference low-end device*, and a CPH2707 is not it; that is Chapter 9.9's device-matrix question and belongs to Mission 8.3.

**Every target here is a single-device baseline.** Chapter 9.9's cross-device matrix remains outstanding.

---

## Open items raised or closed by this mission

| Item | State |
|---|---|
| 137 — an interrupted upload strands its chunk at `uploading` | **CLOSED** — fixed by ADR-052, hardware-verified |
| 138 — the Dart engine restarts mid-upload | Open; mechanism UNDETERMINED, size correlation refuted |
| 139 — no usable credential reads Aurora or Secrets Manager | Open; never blocked 137, corrected |
| 140 — a session directory outlives a recording with no chunk | Open; accumulation not proven |
| 141 — port fakes model the contract but not the concurrency | Open; recommends an audit |
| 142 — an in-flight transfer does not migrate to a better network | Open; tracked behaviour, not a defect |
| 143 — a closing sweep narrower than the one CI enforces | Open as a habit; this instance fixed |
| 144 — the Pre-Recording Checklist has no way back | **CLOSED** — fixed and device-verified |
| 145 — the Admin creation routes may share 144's shape | Open; **a suspicion, not a finding** — untraced |

Items 135 and 136 were raised at Mission 8.1 and remain open; neither was touched here.

**Two fixes shipped.** **ADR-052** — startup reconciliation for chunks stranded at `uploading` — was written, accepted, **shipped broken**, corrected, and verified inside this mission; its `Correction, 2026-08-23` section records the defect its own first build carried. **Item 144's fix** gave the checklist a way out, by pushing rather than going *and* adding an explicit close, because the device proved neither alone was sufficient.

---

## What remains

Nothing in Chapter 9.8 or Chapter 9.4 is outstanding within this mission's scope. What carries forward:

- **Chapter 9.4 targets 1 and 4.** Target 1 needs a `Stopwatch` around metadata generation, which is a production change. Target 4 needs a profile build, which `flutter build apk --profile` has never produced here (ADR-031 names that gap). Both are Mission 8.3's.
- **Chapter 9.9's cross-device matrix.** **Every result in this document is a single-device baseline** on one CPH2707. Nothing here establishes behaviour on the reference low-end device, which is why target 6 is recorded as scoped rather than claimed.
- **Item 145** — whether the Admin creation routes repeat item 144's shape. Read from the route table, never opened on a device.
- **Item 130 / A-218's F4** — whether the foreground service survives a genuine, timestamped screen-off window. **Untouched by this mission**, and explicitly not evidenced by scenario 2: the screen was on and the app foregrounded throughout, so none of that work says anything about it.
- **Items 135, 136, 138, 140, 141, 142, 143** — carried, each with its own next step recorded in the register.
