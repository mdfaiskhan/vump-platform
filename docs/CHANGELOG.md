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

## It went stale a second time

**2026-08-16.** The paragraph above says the backfill was *"done once, to establish the file, not as a pattern."* It became a pattern.

Missions 4.1, 4.2 and 4.3 each wrote their entries as they landed. Missions **4.4, 4.5, 4.6 and 4.7 wrote none at all** — the file's last edit before this one was `07ae25c`, and thirty-nine files and roughly 3,300 lines of `lib/` changed after it. Among them was the first code in this project that deletes a Collector's recorded footage from a device, which is exactly the kind of change Chapter 11.5 §2 puts under `Security`.

Mission 4.8's security review found it, by reading `git log` against this file rather than trusting a memory of having written the entries. The entries below are the correction and are a second instance of the batching §4 warns against.

**The dates are honest but not informative.** All nine commits carry the author date 2026-08-16, because Missions 4.4 through 4.7 were committed in one working session — the same thing that happened across Mission 3. They are commit dates read from `git log`, not invented, and per the convention above they will be accurate as merge dates the moment `mission-0.18.4-ci` merges.

**What would actually stop this**, and is not built: nothing mechanically ties a commit touching `data/`, `core/storage/` or auth to a changelog edit. Every enforcement this project trusts lives in CI; this discipline lives only in a mission checklist, and has now failed the two times it was left there. Recorded as open item 66 rather than fixed here, because a CI gate is a change to the workflow and not a documentation fix.

---

## [Unreleased]

### Added

- **2026-08-16** — `features/projects_tasks/` has a `domain/`, `data/` and `application/` layer for the first time. `Project` and `Task` are traced column-for-column from Volume 4 Chapter 4.4's Data Dictionary — **not** from Chapter 4.6's endpoint catalog, which §6 says defers every field type to a Volume 6 artifact that does not exist (A-097). `ProjectTaskRepository` serves FR-PT-03/04/05 with two methods, `fetchProjects()` and `fetchTasks(projectId)`, matching the two routes Chapter 4.6 §3 actually offers.

  **Neither method takes a `collectorId`.** Chapter 4.8 has every endpoint re-derive scope from the verified token, and Chapter 4.2 §3 injects the assignment filter server-side, so BR-19 is enforced by the backend rather than by this client — which means the read path needs nothing at all from `features/auth/` (A-099).

  **The write path is a separate interface that does not exist yet.** `ProjectTaskAdminRepository` is decided but unbuilt: keeping FR-ADM's writes off the Collector's type makes BR-18 and FR-ADM-07 a compile-time guarantee rather than a role check every notifier has to remember. It is declared as a decision rather than as an empty file, because an interface with no implementer is dead code and one with the FR-ADM signatures would be Mission 5.2 (A-099).

  **`Task` has no `requirements` field, deliberately.** FR-PT-05 and Volume 2 name it three times; Chapter 4.4 §3's table has no such column. Both readings — prose inside `instructions`, or a missing column — are product answers, so the field is omitted and the drift is recorded as open item 69 rather than guessed (A-098).

  **Nothing here reads a backend.** `FakeProjectTaskRepository` is bound in `main.dart` with its removal condition written into the override: it is deleted when a real repository calls Chapter 4.6 §3's endpoints, at Volume 11 Chapter 11.1's **M8** gate. Binding it now is what the milestone order sanctions — M8 follows M7, the "UI Complete" gate this mission serves, and no Volume 4 endpoint is deployed for it to call instead. 51 tests; `domain` holds at 98.71%, `data` moves 68.34% → 69.45%. Mission 5.1.1, ADR-001/003/022.

- **2026-08-16** — Volume 5 Chapter 5.11's Background Upload (Android). A single foreground service starts when a chunk enters `Uploading` and stops when the queue drains — one persistent notification for the whole batch, showing aggregate progress ("Uploading 2 of 5 chunks."), never restarted per chunk. Up to two chunks upload in parallel (§3's *"small fixed number"*; the number is chosen rather than derived — A-078).

  **The upload runs in the app's main isolate, not in the service's task isolate**, and ADR-042 records why: the plugin's `TaskHandler` runs in a separate isolate that cannot hold the single `IsarChunkStore` instance ADR-040 requires, and `firebase_auth` does not serve tokens to a background isolate. An Android foreground service keeps its host process alive, which is the whole of what Chapter 5.11 §3 asks for.

  **Nothing uploads yet.** `sessionRegistrarProvider` still throws (open item 36) and A-068's Guard 1 refuses every chunk a device has recorded (open item 37), so the dispatcher logs a wiring fault and stops. That is the honest state of the feature and it fails visibly rather than silently. Mission 4.3, ADR-042.

### Security

- **2026-08-16** — **Chunk files are now deleted from device storage.** Volume 5 Chapter 5.15's cleanup is the first code in this project that destroys a Collector's recorded footage, and everything about the design is chosen so that it cannot destroy footage the backend has not got.

  Deletion is not driven by age, by free space, or by a sweep's own judgement. A chunk becomes eligible only once its stored status says the backend has it, and `deleteChunkFile` **unlinks the `.mp4` first and writes `localDeletedAt` second**. That order is deliberate: a crash between the two leaves a row marked present whose file is gone, which the orphan filter already handles, whereas the reverse order would leave a file nothing will ever collect. BR-08's crash-survival guarantee was checked against the trigger rather than assumed — a chunk that has not been confirmed is never a deletion candidate at any point in the sweep.

  The row is soft-deleted, never removed. `localDeletedAt` is authoritative and the record survives as evidence that the chunk existed and where it went.

  **A defect in the orphan filter was fixed in the same change**: `orphanedChunkIds` did not exclude rows with `localDeletedAt != null`, so every already-deleted chunk was reported as an orphan forever. Scoped into this commit because it is on the deletion path and shipping the sweep without it would have produced a permanently growing false-positive list.

  **This code is verified on hardware and not by CI.** `IsarChunkStore` measures 1.9% line coverage and cannot be unit-tested without downloading a native binary at test time (A-096, open item 58). Mission 4.5's device probe exercised every write path including the file deletion, on a real device against a real Isar. Chapter 11.5 §2, Volume 8. Mission 4.5. (`ade2971`, `b6a3df8`, `ff6eb6b`)

- **2026-08-16** — **Two new fields are persisted on every stored chunk record**, and no schema version bump accompanies them. `uploadAttemptCount` (`int`, defaulted 0) and `nextAttemptAt` (`DateTime?`) carry Chapter 5.13 §2's retry budget across process death, so a chunk cannot get a fresh six attempts by the app being restarted.

  **The absent bump is the documented rule, not an oversight.** `DatabaseConstants.schemaVersion` says to increment *"only when a change requires existing data to be transformed. Adding a collection or a nullable property does not qualify — Isar handles those implicitly."* Both additions are of that kind. Bumping to 2 was considered and rejected: there are no `Migration` implementations in this project yet, so the first one would have been a no-op written to satisfy a version number, and it would have run against real chunk rows already sitting on a verified device. A-082.

  Rows written before Mission 4.4 read back as `uploadAttemptCount: 0` and `nextAttemptAt: null` — eligible now, no attempts spent — which is the correct reading of a chunk that predates the counter. No stored value is rewritten and no existing row is touched. Chapter 11.5 §2, Volume 8. Mission 4.4. (`44a32ba`)

- **2026-08-16** — Volume 5 Chapters 5.12 and 5.13, Offline Mode and Retry Strategy. No new network destination and no new credential — what changes is *when* the existing S3 and backend calls are allowed to happen.

  Uploads are gated on observed connectivity rather than attempted-and-failed, so a device with the radio off stops generating requests instead of burning its retry budget against a known-dead network. Backoff is 5/10/20/40/80 seconds with ±20% jitter over a six-attempt budget (§2); the jitter exists so that a fleet of devices regaining signal together does not arrive at the backend as one synchronised burst. Exhaustion is terminal and visible: the chunk is marked `failed` and waits for FR-UPL-07's manual retry or for the network to change, rather than retrying forever in the background.

  `connectivity_plus` stays confined to `features/recording/data/` and the composition root; `features/upload/` reads connectivity through a contract in `core/connectivity/` and still imports no feature, per ADR-022 R3 and ADR-040. The attempt accounting likewise lives on the `core/upload` contract rather than on either feature's own type.

  Device-verified on a CPH2707 with the radio off: all six attempts observed end to end, every interval inside §2's tolerance, terminal transition reached at 166 seconds (open item 56, closed). Chapter 11.5 §2, Volume 8. Mission 4.4, A-083. (`af9a317`, `4d2e23c`, `02faba4`)

- **2026-08-16** — The `core/queue` projection is widened to carry Chapter 5.13's retry state — attempt count and next-attempt time — so C-11's UI can show a chunk's real position in the retry cycle without `features/upload/` reaching into `features/recording/`'s schema.

  This is more data crossing a feature boundary, which is the surface ADR-040 exists to govern, so it is recorded rather than treated as an internal refactor. The projection still carries **no file path and no checksum**; what was added is scheduling state the UI must show, not stored content. Soft-deleted rows (BR-08) remain excluded from the view. Chapter 11.5 §2, Volume 8. Mission 4.6, ADR-040. (`c95264f`)

- **2026-08-16** — Two new Android permissions reach the shipped manifest. `FOREGROUND_SERVICE_DATA_SYNC` is declared deliberately — Android 14 requires the permission matching the service's `foregroundServiceType`, and `dataSync` is Google's documented type for transferring data to the cloud. The service itself is `android:exported="false"`; nothing outside the app can start it.

  **Three permissions and two receivers arrive by manifest merge rather than by choice**: `flutter_foreground_task` contributes `FOREGROUND_SERVICE`, `WAKE_LOCK`, `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED`, the last alongside an **exported** `RebootReceiver`. Boot-restart is configured off (`autoRunOnBoot: false`), so the receiver has nothing to start, but the permission is requested and the receiver is reachable. Reported rather than removed — see open item 45.

  Notification permission is requested at the moment the first service starts, not at app launch, so the prompt appears when the thing it protects is about to happen. A refusal does not stop the upload: the notification is how the work stays visible (Ch. 2.9 §2 principle 3), and losing visibility is not a reason to stop transferring chunks the Collector already recorded. Mission 4.3.

  No new network call, no new stored field, and no change to any verified path from Missions 3.x, 4.1 or 4.2.

- **2026-08-15** — Volume 5 Chapter 5.10's Upload Pipeline is built, and it is the **first code in this project to make an HTTP request**. Four consequences worth recording as security, not as features.

  **Chunk bytes go direct to S3 and carry no Vump credential.** A presigned URL authorises itself, and S3 rejects a request that also presents a conflicting `Authorization` header — so the transfer runs on a separate client with **no token source at all**, which structurally cannot send a Firebase ID token to Amazon. A test asserts the S3 `PUT` carries no `Authorization` header while the same run's backend calls all do; it was verified to fail when the header is deliberately added.

  **A presigned URL is a bearer credential in a query string, and is never logged.** `LoggingInterceptor` writes URIs in full and this project redacts headers only, so the transfer client installs no interceptors and reduces every URL to scheme, host and path before logging. Error messages and `ChunkRegistration.toString()` omit it too. Design-time mitigation, flagged for re-verification in Mission 4.8. A-074.

  **A-068 Guard 1 is closed.** A chunk whose `identity` group does not name real things is refused before any network call and marked `failed` with a named terminal cause — not silently skipped, not silently sent. It currently refuses every chunk recorded on a device, because four of five identity fields still have no source; that is the guard working. Guard 2 (server-side) remains open. A-068.

  **The client never composes the S3 key.** The Lambda does, and returns it (V4 Ch. 4.10 §2). No `org_id`, `project_id` or `task_id` is sent at registration. The register carried the opposite premise since Mission 3.7 and is corrected. A-071.

  Also: `dio` stays confined to `core/network/` under its first real consumer, via neutral published types rather than a widened rule (ADR-041); backend refusals now keep their specific error code instead of a bare HTTP status, per Ch. 4.6 §1; and the confinement check now matches import directives rather than any mention of a package name (A-075). Mission 4.2, ADR-041.

- **2026-08-15** — Volume 5 Chapter 5.9's Upload Queue reads the locally stored chunk rows as a live view. It is read-only over data handling: no network call, no upload, and no new stored field. `features/upload/` reaches those rows through a contract in `core/queue/` rather than by importing `features/recording/`, so neither feature can see the other's schema — the projection carries a chunk id, session id, sequence index, session start time, status and byte count, and deliberately no file path or checksum. Soft-deleted rows (BR-08) are excluded from the view. ADR-022 R3 is now enforced in CI for every feature pair, having been binding in writing only since Mission 0.18. Mission 4.1, ADR-040.

- **2026-08-15** — `shared_preferences` gains the composition root as a second permitted owner, and the `Architecture boundaries` CI job is enforcing again. It had been failing since Mission 3.8 introduced the import in `main.dart` without widening the rule. Mission 3.11.1, A-067. (`958c0d8`)

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

- **2026-08-16** — `SessionRegistrar`'s doc comment cited *"Volume 11's M12 gate"* for the rule that a fake repository must not be wired into a release build. That rule is **M8 — APIs Integrated**; M12 is Store-Ready and says nothing about fakes. The rule is real and the code obeys it — only the citation was wrong — but it is load-bearing for Mission 7's exit criteria, and it pointed at a milestone six gates later than the one that actually binds. **The fourth instance of open item 34's citation collision, and the first found in this project's own shipped code rather than in a Volume** (A-077). Mission 5.1.1, standalone commit.

- **2026-08-16** — HTTP 429 was classified as a terminal failure, so a chunk the backend had asked to slow down was marked `failed` and stopped retrying — the opposite of what the status code means. It is now `transportFailure` and transient, which routes it into Chapter 5.13 §2's backoff where a rate-limit response belongs. Closes A-050. Mission 4.4. (`0ed322b`)

- **2026-08-15** — Recording never actually started. The Checklist reached `Ready` and navigated, but nothing called `RecordingNotifier.start()`, so the machine stayed in `Ready`, `isCapturing` was false, and the Recording Screen's Stop control rendered disabled and discarded every tap. Found by manual real-device testing; a unit test, a device harness and CI were all green throughout, because none exercised a UI tap. Mission 3.12-PRE, A-070. (`09f40ac`)
- **2026-08-15** — A fully compliant device reporting a 0.6 zoom minimum was wrongly refused, because a Java `float` widened to a Dart `double` as 0.6000000238418579. Normalised at the data boundary. Found on the first physical device the ladder ever ran against. Mission 3.1.6, A-057. (`bc81a07`)
- **2026-08-15** — Android build failure: `concurrent-futures` was missing from `camera_android_camerax`'s compile classpath. Mission 3.1.4. (`11d3ef4`)

### Changed

- **2026-08-15** — LiDAR depth capture removed from Mission 3's scope. ARKit requires exclusive camera ownership and cannot run beside the AVFoundation pipeline. Mission 3.9, A-065. (`5ceb8eb`)
