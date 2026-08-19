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

- **2026-08-20** — **The upload pipeline is wired end to end for the first time.** `SessionRegistrarImpl` registers a recording session against Chapter 4.6 §4's `POST /v1/tasks/{id}/sessions`, closing the seam that has thrown since Mission 4.2 and that is the reason **no chunk has ever reached `uploading` on a device**. The Task now travels from C-06 through the session row to the upload queue, so `project_id` and `task_id` carry real values for the first time and A-068's Guard 1 stops refusing every chunk. ADR-051, A-209. Mission 7.4 step 5.

  **Nothing here has run against the deployed backend.** Every request shape is proven against a scripted adapter, which is a claim about a payload and not about a round trip. The device checkpoint is what turns it into one.

- **2026-08-19** — **The mobile app reads and writes the real backend for Projects and Tasks.** `ProjectTaskRepositoryImpl` and `ProjectTaskAdminRepositoryImpl` call Volume 4 Chapter 4.6 §3's seven routes, and `main.dart` binds them in place of the two fakes it has bound since Mission 5.1.1. **Volume 11 Chapter 11.1's M8 gate — *"no fake/mock repository remains wired into a release build"* — is met.** The fake classes survive as test doubles only; seven test files drive screens through them, and their removal conditions are rewritten to say what actually happened rather than being left to read later as unmet. A-204. Mission 7.4 step 4.

- **2026-08-19** — **Cursor pagination reaches the client, closing A-184.** `GET /v1/projects` and `GET /v1/projects/{id}/tasks` have returned at most one page plus a `meta.nextCursor` since Mission 7.3, and the client discarded `meta` entirely — an org with 51 Projects rendered 50, with nothing on either side reporting the truncation. Four screens now offer the next page, and the repositories return a `PagedResult` that can say *"and there is more"*. ADR-051, A-199.

  **`VumpApi` could not have read a list at all**, which A-184 did not know: a list route's `data` is a JSON array and `_unwrap` required an object, so the first call would have been refused rather than truncated. `getList` is new and `get`/`post`/`patch` are untouched, because those three have callers already exercised against the real backend.

  **The cursor stops at the notifier.** Repositories return a page; the notifiers hold `nextCursor` privately and still publish a plain `List`, so none of the seven consumers of `projectsProvider` and `tasksProvider` changed type.

- **2026-08-19** — **"Load more" is an explicit control rather than infinite scroll**, and a failed page becomes a retry on that row rather than an error over the whole list. Appending must not blank a list of 200 while the 201st arrives, and must not discard rows a Collector is reading because *more* of them could not be fetched.

- **2026-08-19** — **Chunks now carry a real Collector, device id and device model.** Three of `ChunkMetadata`'s identity fields have returned `MetadataIdentity.unsourced` since Mission 3.8, because there was no backend to send them to and no decision about what to send. All three are now supplied by the composition root: `collector_id` from the auth notifier (watched, not read — a read would freeze the unauthenticated state that holds while `_restoreSession` runs, and every chunk of the session would carry a blank Collector), `device_id` from a new install-scoped store, `device_model` from a new platform channel. ADR-050. Mission 7.4 step 3.

  **`project_id` and `task_id` are still unsourced**, so A-068's Guard 1 still refuses every chunk and nothing uploads end to end yet. They come from the selected Task, and the repository that supplies one is step 4.

- **2026-08-19** — **All thirteen stubbed API routes are implemented.** Projects, Tasks and assignments; session registration and listing; chunk registration, status, and metadata read/write. Every `NOT_IMPLEMENTED` refusal is gone, so all fifteen of Volume 4 Chapter 4.6's endpoints now have real behaviour. Mission 7.3.

  **Migration 0010 is what made eight of them possible.** Migration 0007 was written against Chapter 4.6's *route list* and not Chapter 4.8 §3's *scope filters* — and a scope filter is a join, which needs `SELECT` on every table in it. BR-19's *"Collector: only Projects with an assigned Task"* was not merely unimplemented but unimplementable, and A-119 had recorded the scope difference as *"real and untestable until Mission 7"* without knowing that. Chapter 5.14 §1's deterministic S3 key was in the same state: three of its five components were unreachable by the role Chapter 4.10 §2 assigns to compute it.

  **Migration 0011** adds `chunks.upload_id`, so a retried registration resumes against the same multipart upload rather than restarting — NFR-REL-02 was unreachable without it — and `complete_session()`, because `sessions.status` permitted `'complete'` and nothing anywhere could set it (A-188).

- **2026-08-19** — **Cursor pagination actually produces a cursor.** `parsePageRequest` had validated an incoming one since Mission 6.2, `EnvelopeMeta.nextCursor` was in the envelope, and `REQUEST_INVALID_CURSOR` was a published code with no producer. Keyset on `(created_at DESC, id DESC)`, opaque base64url, and no chapter specifies a sort order so choosing a total one was forced by the cursor rather than preferred (A-183). ADR-044's 1 MiB response ceiling makes this correctness rather than convenience.

  **The client cannot consume it yet** and will silently render page one — recorded as A-184 and owed to Mission 7.4, because widening the page size only moves the number at which it truncates.

- **2026-08-18** — **Firebase is three projects, and the build flavor picks one.** `vump-platform-f86af` (development), `vump-staging` and `vump-prod`, each with its own Firestore in `asia-south1` and delete protection on. Volume 7 Chapter 7.7 §1 asked for this so that a dev build cannot touch production data; deferred item 3 is closed.

  ADR-047 is new: Gradle product flavors select the environment, and `APP_ENV` is *derived* from the flavor rather than passed beside it. One flag picks the Firebase project, the application ID, the launcher name and `AppConfig.environment` together, so they cannot disagree — the defect ADR-007 rejected for the base URL, applied one level up. The application identifier is now `com.vump.humanarchive`, with `.dev` and `.staging` suffixes that let all three install side by side. Mission 6.4.

  The development environment is the pre-existing project rather than a new one: a fresh `vump-dev` was created and then deleted, because `f86af` already had Authentication and billing that the CLI cannot enable. Amendment A-162. Mission 6.4.

- **2026-08-18** — **The backend is live.** `terraform apply` created 31 resources — Mission 6.2's seven Lambdas, REST API, stage, log groups and invoke permissions, which had been planned and never applied, alongside Mission 6.3's seven credential containers — and repointed seven IAM policies. 66 managed resources now, and `terraform plan` reports `No changes`.

  `npm run db:bootstrap` gave each of the seven database roles a password and wrote it to that function's secret. Per-function isolation is now enforced **twice**: IAM decides which credential a Lambda can read, PostgreSQL decides what that credential may do. Both were proved live rather than read from configuration — `simulate-principal-policy` returns `implicitDeny` for another function's secret and for the master, and `SET ROLE` between function roles is refused `42501`. A-160. Mission 6.3.

- **2026-08-18** — **The Aurora schema exists.** Nine tables, three functions, two triggers and seven database roles, applied to the development cluster through the Data API. `orgs` is Volume 4 Chapter 4.3's ninth table, which Chapter 4.4 referenced from two NOT NULL foreign keys and never defined (A-154).

  Volume 4 Chapter 4.2 §3's business rules are enforced by the database rather than by handler discipline, as that chapter requires: BR-08 and BR-11 as constraints, BR-21 as a `SECURITY DEFINER` procedure with a trigger that makes it the *only* path to `complete`, BR-22 as a `BEFORE UPDATE` trigger. Each was proved behaviourally against the live database — a direct `UPDATE … status='complete'` is refused, and so is changing `resolution` after insert.

  ADR-046 is new: numbered `.sql` files applied by a TypeScript runner over the Data API. `node-pg-migrate` and Flyway were both ruled out because neither can reach a cluster that has no network path (ADR-044). Mission 6.3.

- **2026-08-18** — **Each Lambda gets its own database credential**, so Volume 8 Chapter 8.4 §1's table-level restrictions are enforced rather than described. ADR-044 records that `rds-data` scopes to the cluster, so the restrictions are PostgreSQL `GRANT`s against seven roles — and since the Data API authenticates as whichever user its secret names, one shared credential would have made every GRANT decoration.

  Nine secrets now, not two (ADR-016 amended). No password reaches Terraform state or source control: Terraform creates empty containers, the migration creates the roles `NOLOGIN`, and `npm run db:bootstrap` generates and sets each one. A-158. Mission 6.3.

- **2026-08-18** — **CI gained a twelfth job, and the Node version now checks itself in four places.** ADR-045 wrote a backend standard and nothing executed it — the same gap A-148 recorded for infrastructure, in a second directory. The `Backend` job runs prettier, eslint, `tsc --build`, Vitest, `npm audit` and the esbuild bundle.

  `Environment consistency` was **extended rather than duplicated**, gaining a fourth agreement check: the Node major restated in `engines`, the esbuild target, the Terraform `runtime` variable and `BACKEND_NODE_VERSION` must agree. Proven non-vacuous by moving each of the four sites in turn; each failed with all four paths and values printed, so the message names which one moved.

  The drift is worth a check because of its shape: bundling for one Node major and deploying onto another produces syntax the runtime rejects **at invocation, not at build**, so the pipeline stays green and the defect surfaces as a 502 on the first real request. A-153. Mission 6.2.

- **2026-08-18** — **`backend/` exists.** ADR-015 fixed the runtime as AWS Lambda with Node and TypeScript in August and left the directory empty; Mission 6.2 filled it with an npm workspace, a shared package and seven functions behind a REST API. Fifteen routes, matching Volume 4 Chapter 4.6's catalogue exactly and asserted against it by test.

  **Seven functions across six ADR-015 domains.** The `chunks` domain deploys two, because A-143 gave it two execution roles — one that can write an object and not read it, one the reverse — and a Lambda has exactly one execution role. Chapter 4.6 already had the two routes; the split was not retrofitted onto the specification.

  ADR-045 is the new record governing backend dependencies and toolchain, filling the gap ADR-030 and ADR-021 each named and each declined to fill. A-152. Mission 6.2.

- **2026-08-18** — **Token verification is real; everything behind it is a visible refusal.** Every handler answers `NOT_IMPLEMENTED` with a 501 inside a real Chapter 4.6 §1 envelope — **after** the bearer token has actually been verified. An unauthenticated request gets `AUTH_TOKEN_MISSING` and an invalid token gets `AUTH_TOKEN_INVALID`, and neither reaches the stub.

  Nothing returns invented data: the Data API client throws rather than returning an empty result set, because an empty result is a plausible answer that would let a caller believe the database had been consulted. A-152. Mission 6.2.

- **2026-08-18** — **Cursor pagination is in the contract before any query exists.** Chapter 4.6 §1 fixes `?cursor=…&limit=…` on every list endpoint, and ADR-044's 1 MiB Data API ceiling makes it a correctness requirement rather than a convention. The next cursor is returned as a **sibling `meta` key**, not inside `data`, so `data` stays exactly the resource asked for — the mobile client's `VumpApi` hands `data` to its callers untouched.

  Settled now because adding a required parameter later is a breaking change, and Chapter 4.6 §1 says a breaking change bumps to `/v2`. A-152. Mission 6.2.

- **2026-08-17** — **CI gained an eleventh job, because the first Terraform pull request proved the other ten could not see it.** `grep -E "terraform|\.tf"` over `ci.yml` returned nothing: `fmt`, `validate` and `tflint` were run by hand, and six of the seven required checks would have passed identically over a diff that was Terraform and nothing else.

  The new `Terraform` job runs `fmt -recursive -check`, `init -backend=false` + `validate` per environment root, and `tflint --recursive`. `Environment consistency` was **extended rather than duplicated** — ADR-043 made Terraform a fourth language holding the region and bucket names that Dart, JSON and shell already hold, and that job already owns their agreement.

  Proven non-vacuous before commit: three planted drifts each failed it with a named path and value, including a `vump-platform-prod` bucket in the `dev` root. **No CI job checks IAM least-privilege** — the A-143 class of defect is still caught only by review, and that is named rather than left implied. A-148. Mission 6.1.7.

- **2026-08-17** — **The development AWS environment exists, and it is described in Terraform.** ADR-043 closes Volume 4 Chapter 4.9 §5's infrastructure-as-code deferral — which pointed at Volume 7, where the choice was never made — and `infrastructure/terraform/` now holds three modules (network, database, iam) and one root module per environment, of which only `dev` exists.

  **35 resources applied**: a `10.0.0.0/16` VPC with two private database subnets and no gateway of any kind, an Aurora Serverless v2 PostgreSQL 16.14 cluster scaling 0–2 ACU with a single writer, and seven Lambda execution roles across ADR-015's six resource domains, with no function attached to any of them. `terraform plan` reports `No changes`; every resource was also confirmed by reading AWS directly rather than the state file.

  **The Data API path is proven, not just configured.** `SELECT 1` through `rds-data execute-statement`, authenticating with the RDS-managed master credential by ARN, returns `1` from a cluster that has no network route to anything.

  `terraform validate`, `terraform fmt -recursive -check` and `tflint --recursive` are clean. A-141, A-146. Mission 6.1.

- **2026-08-17** — **The AWS account moved from the Free plan to the Paid plan, and that is a precondition nobody had written down.** The first apply created 26 of 35 resources and then failed with `FreeTierRestrictionError` — the Free plan caps RDS backup retention below the seven days ADR-014's model calls for.

  `backup_retention_period` was never changed to work around it; the account was upgraded and the remaining 9 resources applied with the same value. The retention cap was only the visible symptom: a Free-plan account *"closes automatically"* when its credits run out or its term ends, deleting its resources — and ADR-014 puts production in this same account.

  **`terraform plan` cannot catch this.** Account-plan restrictions are in no resource schema and no data source; they surface only on the create call. `aws freetier get-account-plan-state` must report `PAID` / `ACTIVE`, and it now belongs beside the credential checks in Volume 7 Chapter 7.8. A-146, deferred item 9. Mission 6.1.

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

- **2026-08-19** — **The device identifier is install-scoped and self-minted, and `ANDROID_ID` was rejected.** A v4 UUID generated on first launch and persisted, rather than the OS identifier the platform offers. Two grounds: `ANDROID_ID` resets on factory reset, so it does not provide the stability Volume 5 Chapter 5.7 §2 asks for, and it is an OS-scoped identifier that outlives the app, carrying correlation surface this project has no use for. The app needs to answer one question — *"did these chunks come from the same install?"* — and a self-minted UUID answers exactly that and nothing else.

  **It is stored in `shared_preferences`, not the Keychain**, and that is deliberate rather than an oversight. ADR-008 scopes `flutter_secure_storage` to secrets; a device id travels in plaintext metadata to an unencrypted column, so secure storage would imply a confidentiality property the value does not have anywhere else in its life. The stated cost: a reinstall mints a new id. Nothing treats `device_id` as a key. ADR-050, A-196. Mission 7.4 step 3.

- **2026-08-19** — **The Fork 1 seam validated nothing, and three records said it did.** `chunks-verify` gains `lambda:InvokeFunction` on one ARN so it can ask `chunks-upload` to finalise a multipart upload — `CompleteMultipartUpload` needs `s3:PutObject`, and A-143 keeps that away from the role that downloads evidentiary footage. The IAM policy's own comment claimed the invoked function *"validates the chunk before acting"*. **It did not**: the key and upload id went straight from the invoke payload to S3.

  A compromised `chunks-verify` could therefore have finalised any in-progress upload in the bucket — and it holds `SELECT` on `chunks`, which is not org-scoped, so it could read every registered key and upload id. Finalising an upload still in flight produces a **short object S3 then treats as complete**, with the upload consumed and the remaining parts nowhere to go: silent evidence loss.

  Fixed — `finalizeUpload` now refuses unless the supplied key **and** upload id are the ones the named chunk owns, which needs no new grant. Found by the closing gate's security review, reading the function instead of the IAM policy. A-195. Mission 7.3.

- **2026-08-19** — **One documented exception to Volume 8 Chapter 8.4 §1's *"no role but auth-verify touches users"***, and it is column-level: `GRANT SELECT (id, org_id, role) ON users TO vump_tasks`. Without it, `POST /v1/tasks/{taskId}/assignments` could not tell a Collector from an Admin, could not tell a real user from a guessed uuid, and — the reason it was granted — **could not stop an Admin assigning a Collector belonging to another organisation**, which was a live BR-20 tenant-isolation hole rather than a cosmetic gap.

  `firebase_uid` and `email` are deliberately outside the grant; withholding the first means a compromised `tasks` function cannot correlate an Aurora row to an identity-provider account. Proved live: the three-column read succeeds and `SELECT *` on the same table is refused `42501`. Mission 7.3, A-187.

- **2026-08-19** — **A resource outside the caller's organisation is reported absent, not forbidden.** Chapter 4.8 §3 requires the refusal *"regardless of guessed IDs"*, and `403` answers the question a guess is asking — it confirms the id exists. Every cross-org path returns `404`, uniformly, across projects, tasks, sessions, chunks and collector ids. The cost is stated rather than hidden: an Admin who mistypes a real id inside their own org gets the same answer, and only the log distinguishes them. A-186. Mission 7.3.

- **2026-08-19** — **Both completion gates fired for the first time.** BR-21's `chunks_completion_guard_trg` has existed since Mission 6.3 and its claim that `complete_chunk()` is *"the only path"* had never met a live database; FR-SES-02's equivalent for sessions is new in 0011 and was exercised the day it landed. Both refused a direct `UPDATE` with `restrict_violation`, proved by seeding inside a transaction and rolling back — which leaves nothing to tear down and is a candidate for unblocking gap 8 (A-193). Sixteen live permission probes in total across the mission. Mission 7.3, A-192.

- **2026-08-18** — **Every route but one now authenticates at the edge, not in the handler.** Chapter 4.8 §2 requires the middleware chain to attach `user`, `role` and `org_id` before any endpoint runs, and Chapter 8.4 §1 gives the `users` grant to `auth-verify` alone — so six functions were required to attach an org they were forbidden to read. ADR-048 resolves it with an API Gateway REQUEST authorizer served by `auth-verify` itself: one function reads `users`, fourteen routes receive the result in their request context, and no function gains a grant.

  **A failed lookup is an explicit `Deny`**, so API Gateway refuses before the target function is invoked; a handler that finds no authorizer context fails rather than falling back, so a detached authorizer cannot silently become an open endpoint. `authorizerResultTtlInSeconds = 0` — caching a policy caches an authorization decision, and a removed user would keep working for the window.

  **`POST /v1/auth/verify` is the one exemption**, and it is a security property rather than a convenience: the authorizer refuses a caller with no `users` row, and that route is what creates the row. Verified against live AWS — 15 routes, 14 `CUSTOM`, one `NONE`, attached per method. The exemption is asserted by a Terraform `check` that **CI does not run** (ADR-048 records the correction; gap 16). Mission 6.5.

- **2026-08-18** — **The app takes `org_id` from the backend instead of from the token.** ADR-048 retires A-159's design, in which the `org_id` custom claim was to be authoritative for every function. Chapter 4.7 §2 says the opposite — the `users` table is *"the authoritative source if the claim and the table ever disagree"* — and a claim written once goes stale the moment an account moves organisation.

  After Firebase sign-in the app exchanges its ID token at `POST /v1/auth/verify` and reads `orgId` from the response; `role` still comes from the claim, which Chapter 4.7 §2 specifies. Proven on device rather than asserted: the response carried `orgId: 00000000-0000-4000-8000-000000000001` while every account's claim reads `"vump-default"`, so the value in the built `User` does not exist in the token and could only have come from the backend.

  **This also removed the only reason to write Firebase claims from AWS**, which is the credential question ADR-036 defers — A-165. Mission 6.5.

- **2026-08-18** — **Development, staging and production no longer share one Firebase project.** Until Mission 6.4 a single project served all three, so development auth users and production auth users were the same records and a dev build could reach production data. Volume 7 Chapter 7.7 §1 requires three, *"a bug in a dev build must never be able to send a real push notification to a production Collector's device"*.

  `vump-platform-f86af` (development), `vump-staging` and `vump-prod` are now separate projects, each with its own Firestore in `asia-south1` and delete protection enabled, selected by the build flavor (ADR-047). Firestore security rules are byte-identical across all three and released to each; they contain no project ID or environment literal, so there is nothing per-environment to get wrong.

  **The separation is the boundary Firebase actually enforces** — a token issued by one project verifies in no other. Deferred item 3 closes. Mission 6.4.

- **2026-08-18** — **A stored procedure that gates chunk completion was executable by every role.** `complete_chunk()` is BR-21's gate, and migration `0007` claimed "the only role that can complete a chunk is the one granted EXECUTE". It was not: PostgreSQL grants `EXECUTE` on new functions to `PUBLIC` by default, and the `ALTER DEFAULT PRIVILEGES … REVOKE ALL ON FUNCTIONS` intended to prevent that recorded nothing — `pg_default_acl` was empty and the function's ACL read `{=X/vump_admin,…}`, where the empty grantee is PUBLIC.

  Found by verifying the applied schema against the specification **by reading the database**, not by re-reading the migration — the only way this surfaces, because the SQL was accepted and the statement succeeded. Fixed in a new migration rather than by editing the applied one. A-153's shape, one layer down. Mission 6.3.

- **2026-08-18** — **`auth-verify` may INSERT its own user row and nothing else**, enforced in PostgreSQL. A-150 resolved Volume 8 Chapter 8.4 §1's *"cannot modify any table"* against Chapter 4.7 §1 step 4's first-login creation as: no UPDATE, no DELETE, INSERT permitted. Verified live — `has_table_privilege('vump_auth_verify','users','UPDATE')` is false, and no role but this one can read `users` at all.

  `audit_log` is append-only by the same method: no role holds UPDATE or DELETE on it, so Chapter 4.2 §2's rule cannot be bypassed by a session variable. Mission 6.3.

- **2026-08-18** — **The Data API client had no retry for a cluster that scales to zero**, a defect in Mission 6.2's merged code that Mission 6.3 found by hitting it on its first probe. `min_capacity = 0` means the first call after idle fails with `DatabaseResumingException`; nothing handled it, and nothing broke only because no handler issues a statement yet.

  Fixed in `@vump/shared` rather than in the migration runner, so all seven functions inherit it. Only the resuming condition is retried — retrying a `BadRequestException` would turn a deterministic defect into an intermittent one. A-156. Mission 6.3.

  **The deployed functions do not contain this retry, and that is correct.** Downloading the live artifact shows `DatabaseResumingException`, `withResumeRetry` and `RDSDataClient` all absent while `verifyIdToken` is present: esbuild eliminated the Data API path because no handler calls `execute()` yet. The fix enters a bundle in the same build that first calls it — a build that is already a redeploy of the changed handler — so it never causes a deployment of its own. Recorded because the natural reading of the entry above is that the live Lambdas carry it. Mission 6.3.

- **2026-08-18** — **Volume 8 Chapter 8.3 §4's dependency scan is implemented.** It named the tool — *"an automated vulnerability scan (npm audit or an equivalent SCA tool) gating CI"* — and nothing ran it. `npm audit` now gates the new `Backend` CI job at `high`, one level stricter than the chapter's `critical` floor.

  Six moderate advisories currently sit below that line, all transitive through `firebase-admin`. They are visible and do not block. A-153. Mission 6.2.

- **2026-08-18** — **The backend verifies Firebase ID tokens with no service-account secret, and that was tested rather than assumed.** ADR-036 claimed `verifyIdToken` is satisfiable by Google's public certificates alone. A probe initialised `firebase-admin` with no credential and every ADC environment variable deleted, then verified a well-formed unsigned token: the SDK failed with *"`kid` claim which does not correspond to a known public key"* — an error only reachable after fetching Google's certificate set.

  **This resolves an apparent conflict rather than creating one.** Chapter 4.7 §1 step 3 requires every Lambda to verify tokens, but Mission 6.1 granted the Firebase secret to `auth-verify` alone. Verification needs no secret, so all seven functions satisfy the chapter with the IAM already applied, and `auth-verify`'s grant is for the claims-*writing* path that arrives when `functions/` retires. A-149. Mission 6.2.

- **2026-08-18** — **`auth-verify` may INSERT its own user row but not UPDATE or DELETE anything.** Volume 8 Chapter 8.4 §1 says it *"cannot modify any table"*; Chapter 4.7 §1 step 4 has it creating a `users` row on first login. Resolved narrowly: the threat V8.4 §1 names is *"a compromised token-verification path … leveraged into a data-write path"*, and inserting a row keyed by a `firebase_uid` just verified does not serve it.

  **Not enforceable in IAM** — ADR-044 records that `rds-data` actions scope to the cluster, not the table. Enforcement is a PostgreSQL `GRANT SELECT, INSERT ON users`, flagged for Mission 6.3 and deliberately not written here against a table that does not exist. A-150. Mission 6.2.

- **2026-08-18** — **An error message never leaves the process.** Any unrecognised throw becomes `INTERNAL_ERROR` with a fixed string; the real message is logged and never returned, because an exception can carry a table name, a SQL fragment or a secret ARN. Asserted by a test that plants both a relation name and a Secrets Manager ARN in a thrown error and checks neither survives. Mission 6.2.

- **2026-08-17** — **Account-level S3 Block Public Access is set on account `929570731524`, where it had never been configured.** Volume 8 Chapter 8.4 §3 requires it *"not just at the individual bucket policy level, so a future misconfiguration can't accidentally expose it"*, and `get-public-access-block` returned `NoSuchPublicAccessBlockConfiguration`.

  **Nothing was exposed.** All three chunk buckets already carried per-bucket Block Public Access with all four settings on, and every bucket policy reported `IsPublic: false`. What was missing is the backstop for the *next* bucket — and `vump-platform-tfstate`, created in the same mission, is exactly that case. Applied as a one-time authorised exception to Mission 6.1's report-don't-fix rule, in its own commit. A-145. Mission 6.1.

- **2026-08-17** — **The chunks domain carries two execution roles, so no principal can both write and read a chunk.** `vump-{env}-chunks-upload` holds `s3:PutObject`, `s3:AbortMultipartUpload` and `s3:ListMultipartUploadParts`; `vump-{env}-chunks-verify` holds `s3:GetObject`, `s3:GetObjectAttributes` and `s3:GetObjectVersionAttributes`. Neither holds the other's actions, and neither holds `s3:DeleteObject`.

  This matters because **a presigned URL carries the signer's permissions**: the upload role *cannot* produce a URL that reads footage, however the handler that calls it is written. ADR-015's six resource domains are unchanged — a domain is a unit of code decomposition, a role is a unit of privilege, and the chunks domain needs two of the latter. The consequence for Mission 6.2 is that chunks deploys two functions, since a Lambda has exactly one execution role.

  Mission 6.1 first merged both policies onto a single `chunks` role. That was caught and corrected in 6.1.3 **before anything was applied**, so the widened role never existed in AWS. A-143, closed. Mission 6.1.

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

- **2026-08-20** — **Every metadata POST would have been refused, for two independent reasons.** `functions/metadata/` resolves a chunk's true identity from a database join and rejects a document that disagrees with it. The client disagreed twice.

  `identity.collector_id` was the **Firebase uid**; the backend joins `sessions.collector_id`, which is `users.id`. `POST /v1/auth/verify` has always returned both and the client read `orgId` and discarded `userId`. A-206.

  `identity.session_id` was the **local** session UUID; the backend joins its own `sessions.id`. That one is not a slip — the document is assembled at chunk finalization, possibly offline, when no backend session exists — so the pipeline now rewrites that one field at the POST, where both ids are in hand, and the stored row keeps the local id every device-side lookup joins on. A-207.

  Both were found by reading the backend's join rather than by running anything, and **neither was visible to any test on either side**: each half was internally consistent, and the metadata POST had no reachable caller because the session registrar threw. One pipeline test had been asserting the document was *"posted unchanged"* — encoding the second defect as intended behaviour, and it would have kept passing all the way to the device.

- **2026-08-20** — **A syntax `flutter analyze` accepts and the code generator cannot parse.** Null-aware collection elements (`{'k': ?value}`) entered `lib/` in Mission 7.4 step 4 and passed a full green verification — analyzer, 1123 tests, five boundary checks — because none of that runs a code generator. `build_runner` bundles its own, older analyzer; meeting one it reports the file as broken and **every** generator refuses to run, against files unrelated to the syntax. The lint that asks for it is now silenced project-wide, the two uses are rewritten, and the rule is invariant **I49** — the only one in the register imposed by a tool rather than a decision, and the only one whose violation is silent until an unrelated action. A-208.

- **2026-08-19** — **The app could have told a Collector they lack access to their own assigned Task.** C-06 Task Detail selects its Task out of the Project's list, because Chapter 4.6 §3 has no `GET /v1/tasks/{id}`, and renders *"This Task isn't available to you"* when it is absent — copy written to mean BR-19. Pagination at the backend's default page size of 50 would have produced that message for the 51st Task in a Project: **a false statement about authorization, not a truncated list.** Fixed by requesting the backend's `MAX_LIMIT` of 200. The residual gap above 200 is A-201, with a revisit trigger rather than a date. Mission 7.4 step 4.

- **2026-08-19** — **A stale link no longer tells a Collector to check their connection.** `FakeProjectTaskRepository` answered an unknown Project with an empty list, so *"couldn't be loaded — check your connection"* covered everything that could go wrong. The real backend answers A-186's uniform `404 RESOURCE_NOT_FOUND` for a Project outside the caller's reach, which is not a connection problem, and pointing a Collector at a network that is working is Chapter 2.9 §2's named-cause rule failing in the direction hardest to notice. C-05, C-06 and A-05 now distinguish the two. The invisible-Project copy claims neither *"not assigned"* nor *"does not exist"*, since BR-19 makes them deliberately indistinguishable.

- **2026-08-19** — **Two live `vumpApiProvider` declarations, now one.** `core/network/` and `features/upload/application/` each declared one, so which `VumpApi` a file received depended on which it imported. Harmless in effect — the class holds only its client — and that is why it survived two missions with both suites green. Found by needing a third consumer, which under ADR-022 R3 cannot import the `features/upload/` one at all. A-203.

- **2026-08-19** — **C-03's "Active projects" tile is removed.** It counted `projectsProvider`, which after pagination holds the pages loaded rather than every Project, so the number silently became *"active projects on page one"*. There is no total in Chapter 4.6 §1's envelope and walking every page to render one tile is unbounded, so the tile is dropped on the precedent this screen already set for two other FR-PT-01 aggregates: an absent tile beats a false number. **FR-PT-01 is now one-quarter rendered**, which is a product gap recorded as open item 111 rather than made to look smaller. A-200.

- **2026-08-19** — **Nine applied migrations could never be re-run.** The runner hashes the bytes on disk, and `core.autocrlf` had materialised CRLF after 0001–0009 were applied from LF files — invalidating every stored checksum at once, without changing a character of SQL. `git diff` could never show it, because git compares normalised content. A `.gitattributes` entry pins `*.sql` to LF. Mission 7.3.

- **2026-08-19** — **`logs:DescribeLogGroups` was granted on an ARN that can never match it.** It is a list call, so IAM evaluates it against an ARN with an empty log-group name; scoping it to `/aws/lambda/vump-dev-*` gave three principals an action none of them could use. Found when `terraform plan` was first run by hand as `terraform-apply`. Mission 7.3.

- **2026-08-19** — **Lambda timeout raised from 15s to 28s**, and made per-function. Gap 9 measured Aurora's resume at 15876ms, 15889ms and 15428ms against a 15000ms ceiling. **This does not close gap 9**: AWS documents a deep-sleep resume of *"30 seconds or longer"* after 24h idle, and API Gateway's REST integration ceiling is 29s — so AWS's own recommendation is unreachable through the API, and 28s is provisional pending a quota increase. `chunks-verify` runs at 1769MB, chosen against a measured 7780ms hash of a real 633,232,477-byte chunk versus 25908ms at 512MB, for the same MB-seconds. Mission 7.3.

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
