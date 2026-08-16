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
| **FR-ONB** — Onboarding & Permissions | **In Progress** | C-01's priming carousel is **not built**. FR-CHK-01's camera/microphone verification *is* (Mission 3.8), via a camera open rather than a permission plugin. The two are separate obligations and only one is met. |
| **FR-ADM** — Admin Project & Task Mgmt | **Not Started** | `features/projects_tasks/` is `.gitkeep` beyond Mission 1.3's placeholder screens. The temporary invite-code Admin surface (ADR-036) is auth, not FR-ADM. |
| **FR-PT** — Collector Dashboard / Projects / Tasks | **Not Started** | Placeholder screens only. Blocks A-062's `project_id`/`task_id`, A-063 §2's `local_task_cache`, the Task picker that would retire the debug button — and, through open item 36, the entire upload path. |
| **FR-CHK** — Pre-Recording Checklist | **Verified** | Mission 3.8. Five rows — permissions, storage, battery, network, wide-angle (A-057's sixth item). Confirmed on a CPH2707: all five pass, `allPassed=true`. FR-CHK-05's remedy copy is total over every check and every `ErrorCode`. |
| **FR-REC** — Recording | **Verified**, one gap | Missions 3.1–3.3, 3.8, 3.12-PRE. Rear camera (BR-01), wide-angle 0.6x measured on device (BR-02), 1080p30 at ~8.17 Mbps against an 8.128 Mbps target, REC indicator and elapsed timer (FR-REC-04), chrome-free surface. **FR-REC-03's full-screen live preview is NOT rendered** — A-064 §5, open item 8. |
| **FR-CHNK** — Chunking & Local Processing | **Verified** | Missions 3.4, 3.4.5, 3.5. Ten-minute boundary confirmed on device at 601 s; capture restarts while the previous chunk still hashes (A-061). Deterministic `{sequence_index:04d}.mp4` naming (FR-CHNK-05). Storage rests on the 1.89% file — see the caveat above. |
| **FR-META** — Metadata Generation & Integrity | **In Progress** | Missions 3.6, 3.7. SHA-256 per chunk (FR-META-10) independently re-verified on device; FR-META-09's atomic chunk+metadata write confirmed by read-back. **Nine of twenty-one fields have no source** (A-062): GPS, battery and network are schema-only, and five identity fields carry the empty-string sentinel (A-064 §3). |
| **FR-UPL** — Upload | **Built (unverified)** | **Moved from Not Started by Mission 4.** Chapters 5.9–5.15 are built end to end: queue, pipeline, Android foreground service, offline gating, six-attempt backoff, storage cleanup, and C-11's status UI. 789 tests pass in CI. **It has never uploaded a byte to a real endpoint** — `SessionRegistrar` has no implementation (open item 36) and A-068's Guard 1 refuses 100% of chunks a device has actually recorded (open item 37). Not Verified, because what CI proves is that the code is correct against fakes. |
| **FR-SES** — Session Lifecycle & Status | **In Progress** | FR-SES-02's `complete` transition confirmed on device (`SESSION-COMPLETE status=complete`). BR-12's "Complete only when every chunk is confirmed uploaded" needs a backend and is not met. |
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
