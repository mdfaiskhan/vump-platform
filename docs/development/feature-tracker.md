# Feature Tracker

Volume 11 Chapter 11.6's tracker: every FR group from Volume 1 Chapter 1.3, mapped to actual build status.

**Precedence.** Where this file and an accepted ADR disagree, the ADR governs. Chapter 11.6 §1 makes this the single home for build status — it is not re-derived elsewhere, and Chapter 11.3's sprint backlog updates it rather than the reverse.

---

## Status legend

Chapter 11.6 §2, unchanged: **Not Started** · **In Progress** · **Built (unverified)** · **Verified** (Volume 9 tests passing) · **Shipped** (in a released version, Chapter 11.5).

### Two rules from §4, applied literally

> *"A row moves to 'Verified' only once its Volume 9 test coverage (Chapters 9.6/9.7) actually passes in CI — **not on the developer's local machine**."*

**Nothing in this repository has ever run in CI.** Every commit sits on `mission-0.18.4-ci`, which has never been pushed, so no workflow has executed against any of it. The suite passes locally — 519 tests, measured 2026-08-15 — and that is explicitly not what §4 accepts.

**So no row reads Verified, however well-tested.** The recording rows are marked *Built (unverified)* with their real evidence stated in the notes. Softening the rule to reflect local runs would make this tracker say something the chapter does not permit.

> *"A row moves to 'Shipped' only once Chapter 11.5 has a dated changelog entry for it."*

`docs/CHANGELOG.md` exists but every entry sits under `[Unreleased]`; the first dated section is v1.0.0 at Milestone M13. **No row can be Shipped yet**, by construction.

---

## Tracker

| FR Group (V1 Ch. 1.3) | Status | Notes |
|---|---|---|
| **FR-AUTH** — Authentication & Session | **Built (unverified)** | Mission 2. Firebase email/password + Google SSO, silent refresh, role routing, route guards. Tests pass locally; CI has never run. |
| **FR-ONB** — Onboarding & Permissions | **In Progress** | C-01's priming carousel is **not built**. FR-CHK-01's camera/microphone verification *is* (Mission 3.8), via a camera open rather than a permission plugin. The two are separate obligations and only one is met. |
| **FR-ADM** — Admin Project & Task Mgmt | **Not Started** | `features/projects_tasks/` is `.gitkeep` beyond Mission 1.3's placeholder screens. The temporary invite-code Admin surface (ADR-036) is auth, not FR-ADM. |
| **FR-PT** — Collector Dashboard / Projects / Tasks | **Not Started** | Placeholder screens only. Blocks A-062's `project_id`/`task_id`, A-063 §2's `local_task_cache`, and the Task picker that would retire the debug button. |
| **FR-CHK** — Pre-Recording Checklist | **Built (unverified)** | Mission 3.8. Five rows — permissions, storage, battery, network, wide-angle (A-057's sixth item). Confirmed on a CPH2707: all five pass, `allPassed=true`. FR-CHK-05's remedy copy is total over every check and every `ErrorCode`. |
| **FR-REC** — Recording | **Built (unverified)**, one gap | Missions 3.1–3.3, 3.8, 3.12-PRE. Rear camera (BR-01), wide-angle 0.6x measured on device (BR-02), 1080p30 at ~8.17 Mbps against an 8.128 Mbps target, REC indicator and elapsed timer (FR-REC-04), chrome-free surface. **FR-REC-03's full-screen live preview is NOT rendered** — A-064 §5. |
| **FR-CHNK** — Chunking & Local Processing | **Built (unverified)** | Missions 3.4, 3.4.5, 3.5. Ten-minute boundary confirmed on device at 601 s; capture restarts while the previous chunk still hashes (A-061). Deterministic `{sequence_index:04d}.mp4` naming (FR-CHNK-05). |
| **FR-META** — Metadata Generation & Integrity | **In Progress** | Missions 3.6, 3.7. SHA-256 per chunk (FR-META-10) independently re-verified on device; FR-META-09's atomic chunk+metadata write confirmed by read-back. **Nine of twenty-one fields have no source** (A-062): GPS, battery and network are schema-only, and five identity fields carry the empty-string sentinel (A-064 §3). |
| **FR-UPL** — Upload | **Not Started** | Mission 4. The recording feature makes **no network calls at all** — verified by import sweep in Mission 3.11. `recoverableChunkIds()` exists and has no caller. |
| **FR-SES** — Session Lifecycle & Status | **In Progress** | FR-SES-02's `complete` transition confirmed on device (`SESSION-COMPLETE status=complete`). BR-12's "Complete only when every chunk is confirmed uploaded" needs FR-UPL and is not met. |
| **FR-SEC** — Secondary Features | **Not Started** | Phase 2 by design (V1 Ch. 1.10/1.11). `collector_authored` exists in the schema, empty at generation as Ch. 5.7 §2 requires. |

---

## What moved this mission

| Group | Before Mission 3 | After |
|---|---|---|
| FR-CHK | Not Started | Built (unverified) |
| FR-REC | Not Started | Built (unverified), FR-REC-03 gap |
| FR-CHNK | Not Started | Built (unverified) |
| FR-META | Not Started | In Progress |
| FR-SES | Not Started | In Progress |
| FR-ONB | Not Started | In Progress (FR-CHK-01 only) |

FR-ADM, FR-PT, FR-UPL and FR-SEC are unchanged.

---

## Last updated

**2026-08-15**, Mission 3.12, at commit `09f40ac`. Every status above was checked against the repository in the session that wrote it, not carried forward from a sub-mission report.
