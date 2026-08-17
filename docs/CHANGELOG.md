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

- **2026-08-17** — **The development AWS environment is described in Terraform, and nothing has been applied.** ADR-043 closes Volume 4 Chapter 4.9 §5's infrastructure-as-code deferral — which pointed at Volume 7, where the choice was never made — and `infrastructure/terraform/` now holds three modules (network, database, iam) and one root module per environment, of which only `dev` exists.

  The plan is **32 to add, 0 to change, 0 to destroy**: a `10.0.0.0/16` VPC with two private database subnets and no gateway of any kind, an Aurora Serverless v2 PostgreSQL 16.14 cluster scaling 0–2 ACU with a single writer, and six Lambda execution roles, one per ADR-015 resource domain, with no function attached to any of them.

  `terraform validate`, `terraform fmt -recursive -check` and `tflint --recursive` are all clean. **`terraform apply` has not been run**, so none of this exists in AWS. A-141. Mission 6.1.

- **2026-08-17** — **The two IAM policy templates are rendered by something for the first time.** `infrastructure/aws/iam/*.json.tmpl` have carried `__ENV__` and `__BUCKET__` placeholders since Mission 0.17 with no tool that substituted them; the Terraform root module now does, so they are the single definition of the chunk S3 grants rather than a declaration nothing read. Renamed to sit under ADR-015's `chunks` domain: `chunks-presign-upload-s3-policy.json.tmpl` and `chunks-verify-object-s3-policy.json.tmpl`. A-141. Mission 6.1.

- **2026-08-17** — **Chapter 2.10's accessibility guidelines are now enforced by machine, not by review.** Three sweeps run across all ten screens Mission 5 built: `androidTapTargetGuideline`, whose `Size(48, 48)` is the same number Chapter 2.10 §3 states, so the threshold is not this project's to restate in a third place; `labeledTapTargetGuideline` for §4; and `textContrastGuideline` for §2.3, in **both themes**, because §2.3 asks for dark mode as *"a validated second pass … never an automatic filter"*.

  All three ship inside `flutter_test`. **No dependency was added**, and a hand-rolled bounds assertion was rejected for the reason that it would restate a published threshold with nothing tying the copies together. This closes open item 105, where `AppSizes.minTouchTarget` held the number and nothing checked it.

  Results: labelling **10/10**, contrast **20/20**, tap targets **9/10**. The one failure is real — C-06's `SelectableText` reference URLs measure 768×28dp and carry a `longPress` action, breaching both §3's table and §3's bullet forbidding *"a precise long-press"*. It is skipped with the reason in the test name so it prints on every run, and recorded as open item 108 rather than fixed, because every fix is a product decision entangled with open item 80. A-136. Mission 5.6. (`04dea7a`)


- **2026-08-16** — A-01 Admin Dashboard, built as a placeholder given its specified job rather than as a partial dashboard. Volume 2 Chapter 2.2's Admin flow step 2 assigns it one concrete, fully satisfiable duty — *"Selects 'New Project' or an existing Project"*, with the branch *"No Projects yet → empty state prompting Project creation"* — and it is the screen the Role Router lands every Admin on. Until now it rendered its own name.

  It carries the one tile with an honest source: the managed-Projects count, from `fetchProjects()` under Chapter 4.6 §3's Admin scope. *"All managed"* rather than *"active"*, so unlike C-03 it needs no `archivedAt` reading.

  **The other two tiles render nothing** — no zero, no placeholder, no label. *"Collector activity summary"* has no source under any reading (open items 92, 89, 36), and *"outstanding Task counts"* is undefined in the Volumes **and underivable**, because Chapter 4.4 §3's `tasks` table has six columns and no status of any kind (open item 94). C-03 set the precedent for omitting silently, and Chapter 2.9 supplies no vocabulary for *"this data has no source"*.

  **No functional requirement governs this screen.** FR-ADM-01 through 08 contain no dashboard, and FR-PT-01 is the Collector's with no Admin counterpart (open item 93). Also recorded: `core/queue/` is always the *local device's* chunks, so no Admin screen can read it — which means open item 81 is Collector-side only and is not among A-07's blockers (A-123). 10 tests; the suite moves 938 → 948. Mission 5.2.4.

- **2026-08-16** — A-02 Projects List (Admin), A-03 Project Detail (Admin), and the **create halves** of A-04 Create Project and A-05 Create Task. FR-ADM-01 is satisfied; FR-ADM-02 in its create half.

  **Admin reuses the Collector's two read methods unchanged.** Volume 4 Chapter 4.6 §3 serves both roles from one route — *"Admin: all Projects in their org. Collector: only Projects with an assigned Task"* — and scopes server-side from the verified token, so there is no Admin variant and no role parameter (A-119). Against the fake, which models no scoping deliberately, A-02 and C-04 therefore render identically; the difference is real and untestable until Mission 7.

  **A-02's empty state is not C-04's.** Chapter 2.9 §4.2 specifies them separately: a Collector *"sees a plain-language explanation"*, while an Admin's list *"leads directly into the '+ New Project' action, since that empty state has an obvious, single next step."* C-04 says wait; A-02 says do this. The divergence lives in a different chapter from the screen's own spec, which is how it would have been missed (A-120).

  **Five things are deliberately absent, each tested.** A-03 has no Collector-assignment entry point, because A-06 needs two reads no endpoint provides (item 89). A-04 has no edit affordance — item 87 is worse than a missing route, since FR-ADM-01 is create-only and no FR covers editing at all — and renders no *"Project-level settings"*, a phrase appearing exactly once in all of Volume 2, in its own row (item 91). A-05 renders neither `requirements` (item 69) nor a reference-examples field, which needs a component Chapter 2.8 would specify (item 74).

  **A-05's edit half is held back entirely**, although `updateTask` works: Chapter 2.9 §2 principle 4 requires editing a Task to confirm before saving, and §4.4 says it must not, naming the same action in both (item 90). Shipping either reading would encode an answer nobody has given.

  Writes go through an `application/` notifier rather than a screen reading the repository — legal by the import rules, forbidden by error-handling.md §26, and invisible to both the analyzer and CI (A-121). 19 tests; the suite moves 919 → 938. Mission 5.2.2.

- **2026-08-16** — `ProjectTaskAdminRepository`, the Admin write path A-099 decided at Mission 5.1.1 and deliberately left unbuilt. Five methods against Volume 4 Chapter 4.6 §3's five write routes: create a Project, create and update a Task, assign and unassign a Collector. Fake-backed like its read counterpart, with the same **M8** removal condition.

  **Nothing holds both interfaces**, which is the point: BR-18 and FR-ADM-07 — *"prevent a Collector from creating, editing, or deleting Projects or Tasks"* — are now a compile-time guarantee rather than a role check every notifier has to remember.

  **Three required capabilities have no route and are deliberately absent.** FR-ADM-02 and MVP §2.2 both say an Admin can *remove* a Task, and there is no `DELETE /v1/tasks/{id}` (open item 86). MVP §2.2 and Chapter 2.5's A-04 — a screen literally named *"Create / Edit Project"* — both assume Project editing, which has no route **and no requirement either**, since FR-ADM-01 is create-only (open item 87). And `projects.archived_at` is a live column that C-04 renders and C-03's active count is defined by, while the word *archive* appears nowhere in Volumes 1 or 2 (open item 88). Declaring methods for any of them would have hidden the gap behind an interface that looks complete.

  **Assignment is Task-level only.** FR-ADM-03 says *"to a Project and to specific Tasks within it"*, but every source that specifies a mechanism — Chapter 4.4's tables, Chapter 4.6's routes, US-29/30, UC-07's own main flow — is Task-only, and Chapter 4.6 §3 states the derivation: *"Collector: only Projects with an assigned Task."* What derivation cannot express is a standing grant covering Tasks created later (open item 85, A-116).

  Both fakes now share one in-memory store, so a Project created through the Admin path is immediately readable through the Collector's. Two independent fakes would have failed in a way that looked like a bug in whichever screen was being built (A-117). 25 tests; the suite moves 894 → 919. Mission 5.2.1.

- **2026-08-16** — C-04 Projects List, C-05 Project Detail and C-06 Task Detail, replacing the three Mission 1.3 Collector placeholders. FR-PT-03, FR-PT-04 and FR-PT-07 are satisfied; **FR-PT-05 only in part**.

  **No repository method was added for any of them.** C-04 is `fetchProjects()`, C-05 is `fetchTasks(projectId)`, and C-06 selects its Task out of that same list — which works only because Mission 5.1.2 made it read the `projectId` its route already carried. C-05's title comes from `projectsProvider` rather than a second call, because Chapter 4.6 §3 has no `GET /v1/projects/{id}` either.

  **Archived Projects are shown and labelled**, not hidden. FR-PT-03, BR-19, Chapter 2.5 and Chapter 4.6 §3 are all silent on archival; hiding them would drop a Project a Collector may have recorded against, and showing them undifferentiated would let someone begin work against a closed one. The marker is the word *"Archived"* rather than a tint, per Chapter 2.10 §2.1 (A-109).

  **C-06 renders two of the three things FR-PT-05 names.** There is no `requirements` section, no empty slot implying one is coming, and `instructions` was not relabelled to cover the gap — Chapter 4.4 §3's table has no such column and open item 69 is a product question. Reference examples render as selectable text that **opens nothing**: a tappable link needs `url_launcher`, an ADR-030 decision and the first outbound-navigation path in this app. An unopenable URL is close to useless in the field, so that clause is met in letter and missed in substance (open item 80, A-110).

  Empty, not-found and failed are three distinct states on C-05 and C-06 rather than one blank list. BR-19 makes *"not assigned"* and *"does not exist"* indistinguishable from the client, so the copy claims neither. 25 tests; the suite moves 859 → 884. Mission 5.1.3.

- **2026-08-16** — C-01's permission-priming carousel, in a new `features/onboarding/` module, and C-03's Home Dashboard.

  **C-01 explains five permissions and requests none, so FR-ONB-01 is not satisfied.** The requirement is that the system *"shall **request** Camera, Microphone, Location (When In Use), Notifications, and Files access during first launch"*. This project has no permission plugin — the only permission machinery is a camera open that infers two grants as a side effect, and nothing can read or request Location, Notifications or Files. Adding one is an ADR-030 decision belonging with C-02, which needs the same package (open item 78). Five cards, not the four Chapter 2.7's worked example implies: three of the four statements across Chapters 2.5 and 2.7 say five, and the example contradicts its own table's button rule (A-105).

  **C-03 renders three of FR-PT-01's four aggregates and shows no tile for the other two.** Pending, uploading and completed counts (FR-PT-02, satisfied in full) come from `core/queue/` — the same rows C-11 reads, through the contract ADR-040 already put on neutral ground. *"In-progress sessions"* needs a `core/` contract over `LocalSession.status` that does not exist (open item 75). *"Total recorded time"* has **no correct source anywhere**: a per-chunk duration exists but no aggregate, and summing the queue would be actively wrong rather than incomplete, because cleanup soft-deletes completed rows and the queue excludes them — the total would decrease as the Collector records more (open item 76). Both tiles are absent rather than zeroed, and tests assert the absence.

  Neither screen's visuals are reconciled against Chapter 2.8, which is not in this repository (open item 74). Both are built from the tokens already transcribed into `lib/app/theme/`. 19 tests; the suite moves 840 → 859. Mission 5.1.2.

- **2026-08-16** — `features/projects_tasks/` has a `domain/`, `data/` and `application/` layer for the first time. `Project` and `Task` are traced column-for-column from Volume 4 Chapter 4.4's Data Dictionary — **not** from Chapter 4.6's endpoint catalog, which §6 says defers every field type to a Volume 6 artifact that does not exist (A-097). `ProjectTaskRepository` serves FR-PT-03/04/05 with two methods, `fetchProjects()` and `fetchTasks(projectId)`, matching the two routes Chapter 4.6 §3 actually offers.

  **Neither method takes a `collectorId`.** Chapter 4.8 has every endpoint re-derive scope from the verified token, and Chapter 4.2 §3 injects the assignment filter server-side, so BR-19 is enforced by the backend rather than by this client — which means the read path needs nothing at all from `features/auth/` (A-099).

  **The write path is a separate interface that does not exist yet.** `ProjectTaskAdminRepository` is decided but unbuilt: keeping FR-ADM's writes off the Collector's type makes BR-18 and FR-ADM-07 a compile-time guarantee rather than a role check every notifier has to remember. It is declared as a decision rather than as an empty file, because an interface with no implementer is dead code and one with the FR-ADM signatures would be Mission 5.2 (A-099).

  **`Task` has no `requirements` field, deliberately.** FR-PT-05 and Volume 2 name it three times; Chapter 4.4 §3's table has no such column. Both readings — prose inside `instructions`, or a missing column — are product answers, so the field is omitted and the drift is recorded as open item 69 rather than guessed (A-098).

  **Nothing here reads a backend.** `FakeProjectTaskRepository` is bound in `main.dart` with its removal condition written into the override: it is deleted when a real repository calls Chapter 4.6 §3's endpoints, at Volume 11 Chapter 11.1's **M8** gate. Binding it now is what the milestone order sanctions — M8 follows M7, the "UI Complete" gate this mission serves, and no Volume 4 endpoint is deployed for it to call instead. 51 tests; `domain` holds at 98.71%, `data` moves 68.34% → 69.45%. Mission 5.1.1, ADR-001/003/022.

- **2026-08-16** — Volume 5 Chapter 5.11's Background Upload (Android). A single foreground service starts when a chunk enters `Uploading` and stops when the queue drains — one persistent notification for the whole batch, showing aggregate progress ("Uploading 2 of 5 chunks."), never restarted per chunk. Up to two chunks upload in parallel (§3's *"small fixed number"*; the number is chosen rather than derived — A-078).

  **The upload runs in the app's main isolate, not in the service's task isolate**, and ADR-042 records why: the plugin's `TaskHandler` runs in a separate isolate that cannot hold the single `IsarChunkStore` instance ADR-040 requires, and `firebase_auth` does not serve tokens to a background isolate. An Android foreground service keeps its host process alive, which is the whole of what Chapter 5.11 §3 asks for.

  **Nothing uploads yet.** `sessionRegistrarProvider` still throws (open item 36) and A-068's Guard 1 refuses every chunk a device has recorded (open item 37), so the dispatcher logs a wiring fault and stops. That is the honest state of the feature and it fails visibly rather than silently. Mission 4.3, ADR-042.

- **2026-08-15** — Pre-Recording Checklist (C-07/C-08) and the chrome-free Recording Screen (C-09), with Local Processing (C-10). BR-04 is enforced at the route by `RecordingGuard`, not only by a disabled button. Mission 3.8. (`83d2a48`)
- **2026-08-15** — Recording lifecycle state machine, capture pipeline, 10-minute chunk boundary, and background chunk processing decoupled from capture. Missions 3.2, 3.3, 3.4, 3.4.5. (`09e7fbe`, `dd29abb`, `390c170`, `b37ebf2`)
- **2026-08-15** — Camera module, capability ladder and fixed capture specification (BR-01/BR-02). Mission 3.1. (`4c7f3d1`)

### Security

- **2026-08-17** — **The `chunks` execution role holds `s3:PutObject` and `s3:GetObject` together, and that is a narrowing lost.** ADR-015 fixes six resource domains, so both chunk policy templates attach to one role. `aws-sdk-integration.md` records why the previous split mattered: a presigned URL carries the signer's permissions, so a registration role without `GetObject` *cannot* produce a URL that reads footage, however the handler is written.

  The role can now. A defect in the registration path that reaches the presigner with a `GetObject` command yields a URL that reads raw footage — and presigned URLs are handed to devices by design. Recorded rather than fixed, because six-roles-for-six-domains was the decision taken; the fix is two roles under one domain. A-143, carried to Mission 6.2.

- **2026-08-17** — **No database password exists in any file.** The Aurora cluster uses `manage_master_user_password`, so RDS creates and rotates the credential in Secrets Manager directly, per Volume 8 Chapter 8.4 §2. Nothing expresses a password in Terraform, so nothing writes one into Terraform state — which is why the state bucket's encryption and versioning were configured before the first `plan` ran. A documented exception to Mission 6.1's "create no Secrets Manager entries" scope line. ADR-043, ADR-044. Mission 6.1.

- **2026-08-17** — **A new key is persisted to `shared_preferences`, and `shared_preferences` gained a fourth owner.** `onboarding_seen_v1` is a single boolean recording that C-01's permission-priming carousel has run to completion on this device. It is written once, only ever as `true`, and read synchronously by `OnboardingGuard` inside GoRouter's redirect.

  **What it is not, stated because a flag invites being waved through.** It is device-scoped rather than account-scoped, so it reveals nothing about who is signed in. It is not a security control: it gates an informational screen, and forging it in either direction grants no access to anything — `true` skips a carousel, `false` shows it again. Under ADR-008's test it holds no secret, no credential and no identifier of any person or account, which is what makes `shared_preferences` the correct store rather than `flutter_secure_storage`.

  **The dependency grant is one FILE, not a directory.** CI confines `shared_preferences` to a closed list, and `shared_preferences_onboarding_seen_store.dart` joins `main.dart` and `main_cleanup_probe.dart` by name — so a second file added under `features/onboarding/data/` does not acquire the plugin by proximity. ADR-039's convention: the file that may import a package announces it in its own filename. A-127.

  **This entry exists because Volume 11 Chapter 11.5 §2 requires Security entries for storage and data handling** — the rule that started this file, recorded at open item 29. Persisted state earns one regardless of credentials or network, and the precedent for that shape is this file's own *"Two new fields are persisted on every stored chunk record"* entry, which is the same shape — new state written to device storage, no credential and no network involved. Mission 5.4 shipped without it and Mission 5.7's security review found the omission; the same gap has happened before, in Missions 4.4–4.7. Mission 5.4, recorded by Mission 5.7. (`84bf1cf`)

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

### Fixed

- **2026-08-17** — **Four accessibility defects, and two more that only a physical device could find.** Against Chapter 2.10: auth error banners are now live regions so a failed sign-in is announced rather than silent on SH-02 — the first screen §8 names; C-11's upload progress exposes its percentage as a value a screen reader can read; C-09's Stop control announces *"Recording — tap to stop"* while capturing, where a constant label had said nothing about whether capture was running; and the checklist's unmeasured row says *"Checking"* where it had been silent between its pass and fail siblings.

  **§5's modal focus trap needed no code.** Every screen Chapter 2.4 calls a modal is a full-screen route reached by `context.go`, so the triggering screen is not in the widget tree at all — stronger than a trap. A regression test holds the property instead of a `FocusScope` implying the framework was not already doing it. §5's *"return focus to the triggering element"* half is structurally unsatisfiable under `go` and is recorded as open item 104.

  **The device pass then found two defects the entire suite could not see.** Every `ChunkStatusPill` announced its label twice — `Semantics(label:)` does not replace a child `Text`'s contribution, so all four states doubled — and the tab bar clipped its labels at 150% **and** 200% text scale, because `NavigationBar` is a fixed 80dp that does not grow. Both existed only outside Flutter's own representation: one in Android's accessibility tree, one at a text scale no test set. Both fixed and verified by the same method that found them. A-133, A-134. Mission 5.5. (`359d857`, `d901a9d`, `f25e12d`, `8399242`)


- **2026-08-16** — C-06 ignored the `projectId` its own route carried. The route has been `/collector/projects/:projectId/tasks/:taskId` since Mission 1.3, but `CollectorTaskDetailScreen` took only the `taskId`, which made open item 70 — no `GET /v1/tasks/{id}` exists — look like it blocked the drill-down path too. It never did. Reading the parameter closes the narrow half of that item with no new endpoint, no cache and no client-side scan across every Project. `/checklist/:taskId` and Chapter 2.4 §2's Record tab still carry no Project and keep item 70 open. Mission 5.1.2, standalone commit.

- **2026-08-16** — A derived `StreamProvider` written as an `async*` body looping over another stream reported that stream's errors **twice** — once as the `AsyncError` Riverpod correctly produced, and once as an uncaught zone error, because `await for` re-throws inside the generator. The screen rendered correctly in every state, so review would not have caught it; a test asserting the error copy did. Replaced with a `.map` over the source, which passes errors through untouched and leaves one handler. Fixed in `lib/` rather than suppressed in the test. A-108 records the pattern for the next derived provider. Mission 5.1.2.

- **2026-08-16** — `SessionRegistrar`'s doc comment cited *"Volume 11's M12 gate"* for the rule that a fake repository must not be wired into a release build. That rule is **M8 — APIs Integrated**; M12 is Store-Ready and says nothing about fakes. The rule is real and the code obeys it — only the citation was wrong — but it is load-bearing for Mission 7's exit criteria, and it pointed at a milestone six gates later than the one that actually binds. **The fourth instance of open item 34's citation collision, and the first found in this project's own shipped code rather than in a Volume** (A-077). Mission 5.1.1, standalone commit.

- **2026-08-16** — HTTP 429 was classified as a terminal failure, so a chunk the backend had asked to slow down was marked `failed` and stopped retrying — the opposite of what the status code means. It is now `transportFailure` and transient, which routes it into Chapter 5.13 §2's backoff where a rate-limit response belongs. Closes A-050. Mission 4.4. (`0ed322b`)

- **2026-08-15** — Recording never actually started. The Checklist reached `Ready` and navigated, but nothing called `RecordingNotifier.start()`, so the machine stayed in `Ready`, `isCapturing` was false, and the Recording Screen's Stop control rendered disabled and discarded every tap. Found by manual real-device testing; a unit test, a device harness and CI were all green throughout, because none exercised a UI tap. Mission 3.12-PRE, A-070. (`09f40ac`)
- **2026-08-15** — A fully compliant device reporting a 0.6 zoom minimum was wrongly refused, because a Java `float` widened to a Dart `double` as 0.6000000238418579. Normalised at the data boundary. Found on the first physical device the ladder ever ran against. Mission 3.1.6, A-057. (`bc81a07`)
- **2026-08-15** — Android build failure: `concurrent-futures` was missing from `camera_android_camerax`'s compile classpath. Mission 3.1.4. (`11d3ef4`)

### Changed

- **2026-08-16** — **Thirty-eight raw spacing, radius, icon and colour values across eight files now read from `lib/app/theme/`**, and a CI step keeps them there. Six further values are exempted **in place, each with its reason**, because no token carries their value — recorded as open item 98 rather than rounded to the nearest token, since every substitution would change rendered pixels and two are covered by committed golden baselines.

  **The goldens were run BEFORE any change to establish the real baseline, then again after**, and proved pixel-identical by MD5 on both themes rather than assumed to be. Every file touched was built by Missions 1, 3 and 4; the nine screens Missions 5.1 and 5.2 built were already clean.

  **This verified INTERNAL consistency, which is not a Chapter 2.8 audit** — Chapter 2.8 is not in this repository, so no screen can be checked against the design system it was told to use. The two claims are easy to conflate and A-125 exists to keep them apart. Open item 74 stays open. Mission 5.3. (`b78d05a`)


- **2026-08-16** — **C-11's session headings name a time instead of a UUID, and each session now summarises its own progress.** Chapter 2.7 asks for chunk rows *"grouped under the session name"*; nothing in this project gives a session a name — not `QueuedChunk`, not `LocalSession`, not Volume 4 Chapter 4.4 §5's `sessions` table — so the heading is when it was recorded: *"Today 09:05"*, *"Yesterday 14:30"*, *"3 Aug 07:15"*. `Session 7f3a1c2e-…` satisfied the clause's letter and told a Collector nothing they could match against their own day (A-112).

  The summary uses `UploadQueueSession.countOf`, which had existed and been unit-tested since Mission 4.1 with no production consumer. It reads *"2 uploaded · 1 waiting"* and deliberately never *"2 of 5 uploaded"*: cleanup soft-deletes completed chunks and the queue excludes them, so a fraction would state a denominator this screen cannot know and would drift downward as housekeeping ran (A-113).

  **A timezone bug was caught before it shipped.** The first draft compared a localised `sessionStartedAt` against an unconverted `now`, putting the Today/Yesterday boundary at UTC midnight rather than the Collector's — wrong by a whole day for anyone far enough east or west, and **invisible to a test suite whose clocks are all UTC**. Found by reading what the fake clock was set to, not by a failure. Both sides are converted now, with a test asserting a UTC instant and its own local rendering agree. Mission 5.1.4.

- **2026-08-16** — C-10's Done button returns to the Dashboard rather than the Record tab. FR-SES-04 asks the system to *"return the Collector to the Task List **or Dashboard** once a session is marked Complete"*, and the button's comment had claimed the Task List was unbuilt — true when written, false since Mission 5.1.3. It stops at the Dashboard deliberately: returning to *the* Task List needs a `projectId` the recording path never carries, because the session's `taskId` is not wired through to anything (open item 79) and `TaskContext` is still `UnsourcedTaskContext`. Guessing a Project would send a Collector to somebody else's work. Mission 5.1.4, A-114.

- **2026-08-16** — **The temporary debug button is gone from the Record tab.** It navigated to `/checklist/debug-test-task` with a hardcoded fake Task id and had sat uncommitted in the working tree since Mission 3.12, carried forward through every mission report as a must-not-forget item. Its stated removal condition was a real Task picker existing; C-04/C-05/C-06 are that picker, and the real path now reaches `/checklist/:taskId` with a Task the Collector chose.

  In its place the tab implements Volume 2 Chapter 2.4 §2's *second* half — *"prompts Task selection if none is obviously in progress"*. The first half needs `LocalSession.status`, which no `core/` contract exposes (open item 75), so the prompt always shows. That subset is deliberate rather than approximate: guessing "most relevant" from the chunk queue would answer a different question, the same substitution A-103 rejected for the Dashboard. The screen also had to gain content rather than merely lose a button, because `RecordingGuard.fallbackRoute` points at it and would otherwise have redirected onto a dead end.

  **This changed nothing about attribution.** `PreRecordingChecklistScreen` declares its `taskId` and reads it nowhere, and neither does `ChecklistNotifier`, `RecordingNotifier` or `RecordingGuard`; `TaskContext` is still bound to `UnsourcedTaskContext`. A recording started through the real picker is attributed to exactly nothing, precisely as one started through the debug button was — open items 1 and 79, and A-068's Guard 1 still refuses every recorded chunk. Mission 5.1.3, A-111.

- **2026-08-15** — LiDAR depth capture removed from Mission 3's scope. ARKit requires exclusive camera ownership and cannot run beside the AVFoundation pipeline. Mission 3.9, A-065. (`5ceb8eb`)
