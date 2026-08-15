# Changelog

Volume 11 Chapter 11.5's Keep a Changelog format, tied to Volume 10 Chapter 10.1's `MAJOR.MINOR.PATCH` `versionName`. This file introduces no second numbering scheme.

**Categories** (Ch. 11.5 §2): `Added` · `Changed` · `Fixed` · `Security` · `Deprecated` / `Removed`. **Security** means *"anything touching auth, storage, or data handling (Volume 8)"*.

---

## About this file's first entries

**It was started late, and that is the first thing it records.**

Chapter 11.5 §4 requires every entry be written *"the day the change merges, not batched at release time — batching is the single most common way changelogs go stale."* No changelog existed until Mission 3.11.2, so Missions 3.1–3.10 shipped without one. Mission 3.11's security review found the omission (finding S3); this file is the correction, and the backfill below is exactly the batching §4 warns against — done once, to establish the file, not as a pattern.

**Two honesty notes about the dates.**

Every Mission 3 commit carries the same author date, **2026-08-15**, because the whole block was committed in one working session. The per-mission dates below are therefore identical rather than a spread, and they are commit dates read from `git log`, not invented.

Nothing here has **merged** yet. All of it sits on the `mission-0.18.4-ci` branch and `main` does not contain it. Chapter 11.5 §4 counts from the merge day, so these entries are dated from the commit that introduced the change and will be accurate the moment the branch merges.

Chapter 11.5 §4 also states that pre-1.0.0 builds *"may log only against `[Unreleased]`"*, with the first dated section being v1.0.0 itself. Everything is therefore under `[Unreleased]`, with each entry carrying its own commit date inline.

---

## [Unreleased]

### Security

- **2026-08-15** — `shared_preferences` gains the composition root as a second permitted owner, and the `Architecture boundaries` CI job is enforcing again. It had been failing since Mission 3.8 introduced the import in `main.dart` without widening the rule. Mission 3.11.1, A-067. (`0eae8bc`..)
- **2026-08-15** — Local storage of session, chunk and metadata records begins. Three Isar collections (`local_sessions`, `local_chunks`, `local_chunk_metadata`) persist to the app-private documents directory, and chunk `.mp4` files are placed under `<app-documents>/recordings/{session_id}/`. Both rely on OS-level app-sandbox encryption as Volume 8 Chapter 8.2 §3 decides; no app-level encryption layer is added. Chunk and metadata are written in one transaction, so a chunk file cannot exist locally without its metadata (FR-META-09). Mission 3.7. (`64e9d60`)
- **2026-08-15** — Device-context and identity handling reaches persistent storage. `MetadataIdentity` carries `collector_id`, `device_id`, `project_id`, `task_id` and `session_id`; five of those have no source and are stored as the empty-string sentinel `MetadataIdentity.unsourced` rather than a plausible placeholder. `isIdentityComplete` exposes the gap to consumers. Two guards are owed before this data can leave the device — see A-068. Missions 3.6 and 3.8. (`7263b74`, `83d2a48`)
- **2026-08-15** — GPS, battery and network fields enter the stored metadata schema. Volume 8 Chapter 8.6 §1 names GPS *"the single most sensitive field this system collects"*. **No GPS value is captured or stored today** — `capture_conditions` is written uniformly absent pending A-062 §3's unresolved conflict between Chapter 5.7 §2 and NFR-META-01. The schema exists; the collection does not. Mission 3.6. (`7263b74`)
- **2026-08-15** — Camera and microphone permission verification added to the Pre-Recording Checklist (FR-CHK-01), by opening a camera with audio enabled rather than by querying permission state. Refusals are distinguished per grant so the remedy names the correct Settings toggle. No permission plugin was admitted. Mission 3.8. (`83d2a48`)
- **2026-08-15** — Battery level and network type are read on device via `battery_plus` and `connectivity_plus` (FR-CHK-03/04). Both are read for the Checklist only and are **not** written into stored metadata, pending the same A-062 §3 decision. Both packages are confined to `features/recording/data/` (invariants I44, I45). Mission 3.8. (`83d2a48`)
- **2026-08-15** — First platform channel in the project: `vump/free_space` reads available bytes for a supplied path via Android `StatFs`. The path is validated non-empty on the native side and originates from the app's own documents directory, never from user input. Reviewed for injection risk in Mission 3.11 (finding S7, no issue). Mission 3.3. (`dd29abb`)
- **2026-08-15** — SHA-256 integrity checksums are computed over every finalized chunk and stored alongside it (FR-META-10), off the UI isolate. Verified on real hardware by independent re-hash, including a 633 MB file. Mission 3.4. (`390c170`)
- **2026-08-15** — Per-device wide-angle eligibility is cached in `shared_preferences` — a tier name and two version strings. No secret, no credential, and no identifier of any person or device; ADR-008 governs secrets and this holds none. Mission 3.1, A-057. (`4c7f3d1`)

### Added

- **2026-08-15** — Pre-Recording Checklist (C-07/C-08) and the chrome-free Recording Screen (C-09), with Local Processing (C-10). BR-04 is enforced at the route by `RecordingGuard`, not only by a disabled button. Mission 3.8. (`83d2a48`)
- **2026-08-15** — Recording lifecycle state machine, capture pipeline, 10-minute chunk boundary, and background chunk processing decoupled from capture. Missions 3.2, 3.3, 3.4, 3.4.5. (`09e7fbe`, `dd29abb`, `390c170`, `b37ebf2`)
- **2026-08-15** — Camera module, capability ladder and fixed capture specification (BR-01/BR-02). Mission 3.1. (`4c7f3d1`)

### Fixed

- **2026-08-15** — A fully compliant device reporting a 0.6 zoom minimum was wrongly refused, because a Java `float` widened to a Dart `double` as 0.6000000238418579. Normalised at the data boundary. Found on the first physical device the ladder ever ran against. Mission 3.1.6, A-057. (`bc81a07`)
- **2026-08-15** — Android build failure: `concurrent-futures` was missing from `camera_android_camerax`'s compile classpath. Mission 3.1.4. (`11d3ef4`)

### Changed

- **2026-08-15** — LiDAR depth capture removed from Mission 3's scope. ARKit requires exclusive camera ownership and cannot run beside the AVFoundation pipeline. Mission 3.9, A-065. (`5ceb8eb`)
