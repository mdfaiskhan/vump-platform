# Feature Tracker

Volume 11 Chapter 11.6's tracker: every FR group from Volume 1 Chapter 1.3, mapped to actual build status.

**Precedence.** Where this file and an accepted ADR disagree, the ADR governs. Chapter 11.6 §1 makes this the single home for build status — it is not re-derived elsewhere, and Chapter 11.3's sprint backlog updates it rather than the reverse.

---

## Status legend

Chapter 11.6 §2, unchanged: **Not Started** · **In Progress** · **Built (unverified)** · **Verified** (Volume 9 tests passing) · **Shipped** (in a released version, Chapter 11.5).

### Two rules from §4, applied literally

> *"A row moves to 'Verified' only once its Volume 9 test coverage (Chapters 9.6/9.7) actually passes in CI — **not on the developer's local machine**."*

**This rule was unsatisfiable until Mission 4.3, and it is satisfiable now.** The previous revision of this file recorded that *"nothing in this repository has ever run in CI"* and that no row could therefore read Verified however well tested. That is no longer true. The pipeline first executed on 2026-08-16 at Mission 4.3.7 (run #1, 7 of 9 jobs green) and has been green on every job since run #11. **Run #13 — the current HEAD, `67cd79b` — reports 10 of 10.** The suite it runs is 789 tests.

**So rows move to Verified for the first time in this project's history.** Four do. The bar is Chapter 11.6 §4's, read exactly: the Volume 9 suite covering that group passes in CI. It is *not* a claim that every Chapter 9.5 §2 coverage target is met — one is not (below), and no row's Verified status rests on the layer that misses it.

> *"A row moves to 'Shipped' only once Chapter 11.5 has a dated changelog entry for it."*

`docs/CHANGELOG.md` is current as of Mission 4.8 — every commit touching auth, storage or data handling across Missions 4.1–4.7 now carries a Security entry — but every entry still sits under `[Unreleased]`, and Chapter 11.5 §4 makes the first dated section v1.0.0 at Milestone M13. **No row can be Shipped yet, by construction.**

### One caveat that qualifies every Verified row below

Chapter 9.5 §2's data-layer target is **80%+**. Measured this session: **68.34%** (505/739). The entire miss is one file — `isar_chunk_store.dart` at **1.89%** (4/212); excluding it the layer reads **95.07%**. That file cannot be unit-tested without downloading a native Isar binary at test time, which Mission 4.7 considered and declined (A-096, open item 58), so **device verification is its declared standard**.

Every row below that depends on local storage therefore rests partly on device passes rather than on CI. That is stated here rather than buried, because it is the one place a Verified row means something narrower than it appears.

---

## Tracker

| FR Group (V1 Ch. 1.3) | Status | Notes |
|---|---|---|
| **FR-AUTH** — Authentication & Session | **Verified** | Mission 2. Firebase email/password + Google SSO, silent refresh, role routing, route guards. `auth/data` measures 99.42%. Self-signup diverges from the volumes by the owner's decision (A-051, A-056); role is hard-locked to Collector at a single site. |
| **FR-ONB** — Onboarding & Permissions | **In Progress** | **C-01's priming carousel is built (Mission 5.1.2) and requests nothing, so FR-ONB-01 is NOT satisfied.** The requirement is that the system *"shall **request** Camera, Microphone, Location (When In Use), Notifications, and Files access during first launch"* — five cards now explain all five permissions and ask for none. This project has no permission plugin: the only permission machinery is `CameraPermissionProbeImpl`, which infers camera and microphone grants by opening a camera and disposing it, and **nothing can read or request Location, Notifications or Files**. The carousel also has no first-launch trigger — `/onboarding` is reachable by route and fires automatically for nobody, because deciding *"has this Collector seen onboarding"* needs persisted state that does not exist. **FR-ONB-02 (C-02, the blocking explainer and settings deep link) is not built at all** and needs the same plugin, so both wait on one ADR-030 decision — open item 78. FR-ONB-03's camera/microphone gate *is* met (Mission 3.8), by the camera open. Three separate obligations; one met, one half-built, one absent. |
| **FR-ADM** — Admin Project & Task Mgmt | **Not Started** | Unchanged by Mission 5.1.1, which built the Collector's **read** path only. `ProjectTaskAdminRepository` — FR-ADM-01–04's writes — is a decided split (A-099) with no file, no implementation and no surface; it is owed to Mission 5.2. Keeping the writes off a separate interface is what makes FR-ADM-07 and BR-18 a compile-time guarantee rather than a per-notifier role check. The temporary invite-code Admin surface (ADR-036) is auth, not FR-ADM. |
| **FR-PT** — Collector Dashboard / Projects / Tasks | **In Progress** | **Mission 5.1.3 added C-04, C-05 and C-06. FR-PT-03, FR-PT-04 and FR-PT-07 are satisfied; FR-PT-05 is satisfied only in part.** C-04 lists every assigned Project with archived ones marked by the word *"Archived"* (A-109); C-05 lists a Project's Tasks and tells empty, not-found and failed apart; C-06 is the entry point to the Checklist, and Start Recording routes to `/checklist/:taskId` per Ch. 2.3 §5. FR-PT-07's more-than-one-Project case has a surface for the first time. **FR-PT-05 asks for *"instructions, reference examples, and requirements"* and C-06 renders two of the three:** there is no `requirements` section, because Ch. 4.4 §3's table has no such column and open item 69 is a product question — and reference examples are text that **opens nothing**, which is FR-PT-05 met in letter and missed in substance (open item 80). Neither shortfall is hidden on screen or in the register (A-110). **No repository method was added for any of the three screens.** FR-PT-06's offline cache is still unbuilt (open item 2). **Mission 5.1.2 added C-03, and it renders four of FR-PT-01's aggregates as three.** FR-PT-02 is satisfied in full — pending, uploading and completed chunk counts come from `core/queue/`, the same rows C-11 reads. **FR-PT-01 is satisfied in part**: active projects and sync status are shown; *"in-progress sessions"* (open item 75) and *"total recorded time"* (open item 76) render **no tile at all**, because neither has a source and a `0` would be a false claim about the Collector's work. Item 76 is the harder one — a queue-sum would *decrease* as recording continues, since cleanup soft-deletes completed rows. **FR-PT-03/04/05 still have no screen**: C-04, C-05 and C-06 remain Mission 1.3 placeholders, though C-06 now reads the `projectId` its route always carried, closing the narrow half of open item 70. FR-PT-06's offline cache is unbuilt (`local_task_cache`, ADR-039 §3, open item 2) and FR-PT-07 has no surface. Visual output is unreconciled against Chapter 2.8, which is not in this repository — open item 74. **Moved from Not Started by Mission 5.1.1, on the domain/data/application layers only.** `Project` and `Task` are traced from V4 Ch. 4.4's Data Dictionary (A-097); `ProjectTaskRepository` serves FR-PT-03/04/05 against a fake, with 51 tests. **No screen consumes any of it** — the seven Mission 1.3 placeholders are untouched, so FR-PT-01, FR-PT-02 and FR-PT-07 have no surface and FR-PT-06's offline cache is deliberately unbuilt (`local_task_cache`, ADR-039 §3, open item 2). Not Built (unverified), because the module is a layer rather than a feature until 5.1.2 renders it. **Nothing this row blocks has been unblocked**: A-062's `project_id`/`task_id` still have no runtime source, `TaskContext` is still bound to `UnsourcedTaskContext`, the debug button still has no Task picker to replace it, and open items 1, 2, 3, 5, 11, 36 and 37 are **all still open** — see A-100 for why 36 gained a second blocker rather than losing one. |
| **FR-CHK** — Pre-Recording Checklist | **Verified** | Mission 3.8. Five rows — permissions, storage, battery, network, wide-angle (A-057's sixth item). Confirmed on a CPH2707: all five pass, `allPassed=true`. FR-CHK-05's remedy copy is total over every check and every `ErrorCode`. |
| **FR-REC** — Recording | **Verified**, one gap | **Mission 5.1.3 removed the temporary debug button** from the Record tab. It navigated to `/checklist/debug-test-task` with a hardcoded fake id and had sat uncommitted in the working tree since Mission 3.12; its stated removal condition — a real Task picker existing — is met by C-04/C-05/C-06. In its place the tab implements Ch. 2.4 §2's *second* half, *"prompts Task selection if none is obviously in progress"*; the first half needs `LocalSession.status`, which no `core/` contract exposes (open item 75), so the prompt always shows (A-111). The tab also had to gain content rather than merely lose a button, because `RecordingGuard.fallbackRoute` points at it. **This changed nothing about attribution:** the checklist ignores its `taskId`, `TaskContext` is still `UnsourcedTaskContext`, and a recording started through the real picker is attributed to nothing — open items 1 and 79. Missions 3.1–3.3, 3.8, 3.12-PRE. Rear camera (BR-01), wide-angle 0.6x measured on device (BR-02), 1080p30 at ~8.17 Mbps against an 8.128 Mbps target, REC indicator and elapsed timer (FR-REC-04), chrome-free surface. **FR-REC-03's full-screen live preview is NOT rendered** — A-064 §5, open item 8. |
| **FR-CHNK** — Chunking & Local Processing | **Verified** | Missions 3.4, 3.4.5, 3.5. Ten-minute boundary confirmed on device at 601 s; capture restarts while the previous chunk still hashes (A-061). Deterministic `{sequence_index:04d}.mp4` naming (FR-CHNK-05). Storage rests on the 1.89% file — see the caveat above. |
| **FR-META** — Metadata Generation & Integrity | **In Progress** | Missions 3.6, 3.7. SHA-256 per chunk (FR-META-10) independently re-verified on device; FR-META-09's atomic chunk+metadata write confirmed by read-back. **Nine of twenty-one fields have no source** (A-062): GPS, battery and network are schema-only, and five identity fields carry the empty-string sentinel (A-064 §3). |
| **FR-UPL** — Upload | **Built (unverified)** | **Moved from Not Started by Mission 4.** Chapters 5.9–5.15 are built end to end: queue, pipeline, Android foreground service, offline gating, six-attempt backoff, storage cleanup, and C-11's status UI. 789 tests pass in CI. **It has never uploaded a byte to a real endpoint** — `SessionRegistrar` has no implementation (open item 36) and A-068's Guard 1 refuses 100% of chunks a device has actually recorded (open item 37). Not Verified, because what CI proves is that the code is correct against fakes. |
| **FR-SES** — Session Lifecycle & Status | **In Progress** | **FR-SES-03's Collector half was already satisfied by Mission 4.6's C-11 and was improved rather than rebuilt by Mission 5.1.4**: session headings now name a time instead of a raw UUID (Ch. 2.7 asks for a *"session name"* and no session has one — A-112), and each session carries a per-status summary. The Admin half of FR-SES-03 (*"Project-wide status to the Admin"*, A-07) is a placeholder and belongs to 5.2. **FR-SES-04 is half-satisfied**: C-10's Done button returns to the Dashboard, which is the requirement's own *"or Dashboard"*; the Task List half needs a `projectId` the recording path never carries and stays blocked on open item 79 (A-114). FR-SES-02's `complete` transition confirmed on device (`SESSION-COMPLETE status=complete`); BR-12's *"Complete only when every chunk is confirmed uploaded"* needs a backend and is not met. **FR-SES-01 is NOT met and the reason is structural, not cosmetic**: it asks the system to *"track the state of every session … end to end"*, and C-11 forgets a session entirely once its chunks are uploaded and swept — open item 81, and the third symptom of the soft-delete blind spot the register now carries as a standing recommendation. **C-12 Session Complete is unbuilt, correctly** — BR-12 reserves *"confirmed uploaded"* for backend verification (open item 36), so building it today would be the false confirmation FR-SES-02 guards against. |
| **FR-SEC** — Secondary Features | **Not Started** | Phase 2 by design (V1 Ch. 1.10/1.11). `collector_authored` exists in the schema, empty at generation as Ch. 5.7 §2 requires. |

---

## What moved this mission

| Group | Before Mission 4 | After |
|---|---|---|
| FR-AUTH | Built (unverified) | **Verified** |
| FR-CHK | Built (unverified) | **Verified** |
| FR-REC | Built (unverified), FR-REC-03 gap | **Verified**, FR-REC-03 gap |
| FR-CHNK | Built (unverified) | **Verified** |
| FR-UPL | Not Started | **Built (unverified)** |

FR-ONB, FR-ADM, FR-PT, FR-META, FR-SES and FR-SEC are unchanged.

**Four of those five moves are the CI rule being satisfiable at last, not new code.** Missions 4.1–4.8 wrote no recording, checklist or auth code; what changed is that Chapter 11.6 §4's condition — passing in CI rather than locally — became meetable. FR-UPL is the only row that moved because something was built.

---

## Last updated

**2026-08-16**, Mission 4.9, at commit `67cd79b`, against CI run #13 (10/10 green). Every status above was checked against the repository in the session that wrote it, and every number in it was measured in that session — 789 tests, 68.34% data-layer coverage, 1.89% on `isar_chunk_store.dart` — not carried forward from a sub-mission report.
