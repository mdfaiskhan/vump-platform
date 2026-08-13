# Volume Amendment Register

Corrections to the architecture volumes (Volumes 1–12), each one traced to the ADR that supersedes it.

---

## Why this register exists

The volumes are distributed as **PDFs**. They cannot be edited in this repository, so a correction discovered during implementation has nowhere to go — it either lives in an ADR that the volumes never reference, or it is lost.

This register is the join between the two. Every entry names the exact volume, chapter and section that is now wrong, states the correction, and cites the ADR that carries authority for it.

**Precedence.** Per `CLAUDE.md`, architecture documentation is the single source of truth, and accepted ADRs are the binding form of it. Where a volume and an accepted ADR disagree, **the ADR governs and the volume is out of date.** This register makes that disagreement explicit rather than latent.

**Discharging an entry.** When a volume is reissued with a correction applied, mark the entry `Applied` with the new volume version. An entry is never deleted — the trail from original to correction is the point, exactly as with a superseded ADR.

---

## Open amendments

### A-001 — Bucket naming

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.10 §1 |
| **Says** | `s3://human-archive-{env}/` |
| **Should say** | `s3://vump-platform-{env}/` |
| **Authority** | ADR-011 |
| **Class** | Documentation update |
| **Status** | Open |

S3 bucket names are immutable. The buckets are correct; the volume is not.

### A-002 — Project name throughout

| | |
|---|---|
| **Volume** | 1–12, all volumes, all chapters |
| **Says** | "Human Archive" |
| **Should say** | "Vump Technologies" |
| **Authority** | ADR-011 |
| **Class** | Documentation update |
| **Status** | Open |

Affects document headers, the `human_archive_app/` repository name in Volume 6 §6.2, and the `HumanArchiveApp` root widget class in Volume 6 §6.1. The implemented names are `mobile/` and `VumpApp`.

This is the widest amendment in the register and the least urgent — it changes no behaviour. It should be applied in a single editorial pass rather than piecemeal.

### A-003 — Multipart upload abort window

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.10 §4 |
| **Says** | Nothing — incomplete multipart uploads are not addressed |
| **Should say** | Incomplete multipart uploads are aborted after 14 days in all environments |
| **Authority** | ADR-012 |
| **Class** | Documentation update (gap) |
| **Status** | Open |

Orphaned parts are billed and invisible to an object listing. Correctness is unaffected by the value chosen: Volume 5 §5.13 §4 and §5.14 §3 make idempotency a property of the deterministic key, not the upload ID.

### A-004 — Bucket versioning

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.10 §3 |
| **Says** | Nothing — versioning is not addressed |
| **Should say** | Versioning is enabled on all environment buckets; noncurrent versions expire at 90 / 14 / 7 days (prod / staging / dev) |
| **Authority** | ADR-011, ADR-012 |
| **Class** | Documentation update (gap) |
| **Status** | Open |

Adopted as protection against accidental overwrite. It creates a storage cost the volumes never accounted for.

### A-005 — Environment lifecycle behaviour

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.10 §4; Volume 8 — Chapter 8.7 §1 |
| **Says** | Retention is described for production data only |
| **Should say** | Dev expires objects at 30 days, staging at 90; neither receives the storage-class ladder |
| **Authority** | ADR-012 |
| **Class** | Documentation update (gap) |
| **Status** | Open |

Applying a 24-month production retention policy to disposable test data is expensive and serves no purpose.

### A-006 — Legal hold cannot be enforced by native lifecycle rules

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.7 §3 and §4 |
| **Says** | §3: a held object is excluded from "every automated deletion/lifecycle job… regardless of age". §4: "native S3 lifecycle rules… handle… eventual object expiration automatically — no custom deletion Lambda needed" |
| **Should say** | Legal hold is enforced in S3 by a `legal_hold` object tag that the expiration rule filters on. S3 Object Lock is deferred until the production compliance review; the tagging implementation is designed to remain compatible with adopting it. The Aurora `legal_hold_at` column remains the system of record and the audit trigger, but is not the enforcement mechanism |
| **Authority** | ADR-013 |
| **Class** | **Architecture decision** |
| **Status** | Open — **highest severity in this register** |

The two sections are mutually incompatible. An S3 lifecycle rule cannot read a database column, so §4 implemented as written destroys the data §3 protects. Volume 8.7's preamble already flags the chapter as requiring legal review before being treated as final; this amendment should be part of that review.

### A-007 — Object expiration is deferred

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.7 §1 |
| **Says** | Raw video chunks are deleted at 24 months from capture |
| **Should say** | The 24-month retention policy stands unchanged as an architecture decision. The corresponding S3 expiration rule is not enabled until ADR-013's enforcement mechanism is in place and verified |
| **Authority** | ADR-012, ADR-013 |
| **Class** | Architecture decision |
| **Status** | Open |

**The policy is not weakened.** This amendment separates the architecture decision (24 months, per V8.7 §1) from the current infrastructure implementation (no expiration rule configured). The gap errs toward over-retention, never under-retention, and closes when enforcement exists.

### A-008 — Derived and annotation data — reserved for future architecture

| | |
|---|---|
| **Volume** | 4 — Chapter 4.10; Volume 5 — Chapter 5.14 |
| **Says** | Nothing — the key schema covers raw video chunks only |
| **Should say** | Storage for AI inference output, annotation data and exports is **reserved for future architecture**; no bucket or layout is decided |
| **Authority** | ADR-011 |
| **Class** | Documentation update (gap) |
| **Status** | Open — reserved, no action required |

Volume 5 §3 places transcoding and thumbnails outside MVP, so this is correctly absent rather than an omission. Registered only to record the constraint that will shape the eventual decision: the chunk key schema begins at `{org_id}/` with no reserved namespace and carries a single bucket-wide lifecycle policy, so a second object class cannot simply be added alongside chunks. **No infrastructure decision is made for a feature that does not yet exist.**

### A-009 — CloudFront is absent from the documented architecture

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.9 §1 |
| **Says** | Nothing — no volume mentions CloudFront or a CDN |
| **Should say** | CloudFront is part of the production architecture, provisioned in Mission 0.17, reaching S3 through Origin Access Control. It may remain unused until media delivery requires it. Presigned URLs remain the access path for chunk upload and retrieval |
| **Authority** | ADR-011 |
| **Class** | **Architecture decision** |
| **Status** | Open |

The volumes describe the storage architecture without a CDN. CloudFront is provisioned ahead of need so that the distribution, its Origin Access Control and the matching bucket-policy grant are established as one unit, rather than retrofitted onto a settled access policy later. Volume 4, Chapter 4.9 §1's topology diagram and Chapter 4.10 §3's access section both need updating.

### A-010 — AWS region is unspecified

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.9 |
| **Says** | Nothing — no volume names an AWS region |
| **Should say** | All environments are in `ap-south-1` (Mumbai) |
| **Authority** | ADR-011 |
| **Class** | Architecture decision |
| **Status** | **Resolved** — decision taken; volume text still to be applied |

Confirmed in Mission 0.17.9. Data residency is India, which Volume 8, Chapter 8.6's privacy policy must state explicitly, and against which any client contract with a residency clause will be read.

### A-011 — Environment and AWS account strategy

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.9 §4 |
| **Says** | Separate AWS accounts "or at minimum, separate VPCs/Aurora clusters and S3 buckets"; exact structure deferred to Volume 7 |
| **Should say** | **Current implementation:** a single AWS account. **Target architecture:** separate accounts for Development, Staging and Production. **Migration:** deferred until production scale. Environment purpose, promotion workflow, deployment flow and release strategy are defined in ADR-014 |
| **Authority** | ADR-014 |
| **Class** | Architecture decision |
| **Status** | Open |

Volume 4.9 §4 deferred the structure to Volume 7, which does not define it either. ADR-014 fills the gap and should be reflected in both volumes.

### A-012 — Flutter environment variables

| | |
|---|---|
| **Volume** | 7 — Development Environment, Chapter 7.10 §2 |
| **Says** | The per-environment `.env` file supplies `API_BASE_URL`, `FIREBASE_PROJECT_ID` and `S3_BUCKET_NAME` |
| **Should say** | The file supplies **`APP_ENV` only**. Base URL, bucket and timeouts are derived in code from that value, per ADR-007 and ADR-011. The `--dart-define-from-file` mechanism of §1 is unchanged and correct |
| **Authority** | ADR-016 |
| **Class** | Architecture decision |
| **Status** | Open |

As written, §2 gives the API base URL two sources of truth — the `.env` file and `NetworkConfig` — which can disagree per build. The failure mode is a staging binary pointed at production. Reducing the file to one input removes the possibility.

### A-013 — Account-level Block Public Access is not configured

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.4 §3 |
| **Says** | "S3 bucket public access is blocked at the account level (AWS's Block Public Access setting), not just at the individual bucket policy level, so a future misconfiguration can't accidentally expose it" |
| **Should say** | Unchanged — the volume is correct |
| **Authority** | Volume 8, Chapter 8.4 §3 |
| **Class** | **Infrastructure update** |
| **Status** | **Open — implementation gap, not a documentation error** |

Verified in Mission 0.17.16: `get-public-access-block` on account `929570731524` returns `NoSuchPublicAccessBlockConfiguration`. Per-bucket Block Public Access is enabled on all three buckets, but the account-level control the volume requires is absent. A bucket created later would not inherit the protection.

### A-014 — One Firebase project serves all three environments

| | |
|---|---|
| **Volume** | 7 — Development Environment, Chapter 7.10 §2; Chapter 7.7 |
| **Says** | `FIREBASE_PROJECT_ID` varies per environment (`human-archive-dev`) |
| **Should say** | Unchanged — the volume is correct |
| **Authority** | Volume 7, Chapter 7.10 §2 |
| **Class** | **Infrastructure update** |
| **Status** | **Open — implementation gap, not a documentation error** |

Only one Firebase project exists, `vump-platform-f86af`, and `firebase_options.dart` is generated for it. All three environments therefore resolve to the same project, so production analytics, crash reports and auth users are indistinguishable from development ones.

Surfaced by `EnvironmentProfile.firebaseProjectId` (ADR-018), which exposes the value rather than fabricating a per-environment one. Closing it means running `flutterfire configure` against two further projects and regenerating the native config files.

### A-015 — MFA Delete is not enabled on any bucket

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.4 §3 |
| **Says** | Nothing — MFA Delete is not addressed |
| **Should say** | Whether MFA Delete is required on the production bucket, and if so that it is enabled |
| **Authority** | — decision required |
| **Class** | **Architecture decision — unresolved** |
| **Status** | Open |

Verified 2026-08-09: `MFADelete=Disabled` on all three buckets. Versioning is the entire basis of object recovery, and without MFA Delete any principal with `s3:DeleteObjectVersion` can permanently remove a version — defeating recovery for the object it targets.

Not a pure win: MFA Delete can only be enabled by the bucket-owner root account with an MFA device, and it makes lifecycle-driven version expiry harder to operate. It is a genuine trade-off, which is why it needs a decision rather than a default.

### A-016 — No cross-region replication

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.10 |
| **Says** | Nothing — regional durability is not addressed |
| **Should say** | Whether production chunk storage is replicated to a second region, and the accepted consequence if not |
| **Authority** | — decision required |
| **Class** | **Architecture decision — unresolved** |
| **Status** | Open |

Verified 2026-08-09: no replication configuration on any bucket. S3 durability is per-region, so loss of `ap-south-1` destroys all production footage with no recovery path.

Interacts with ADR-011's data-residency position: replicating to a second region moves recordings of identifiable people outside India, which Volume 8 Chapter 8.6's privacy policy and any client residency clause must permit. A second Indian region is not available, so this may be a genuine conflict rather than an omission.

### A-017 — No RTO or RPO is defined

| | |
|---|---|
| **Volume** | 1 — Product Planning, Chapter on NFRs; Volume 10 |
| **Says** | Reliability NFRs cover device-side behaviour (NFR-REL-01 to 04). No backend recovery objective exists |
| **Should say** | A recovery time objective and recovery point objective per data class |
| **Authority** | — decision required |
| **Class** | **Architecture decision — unresolved** |
| **Status** | Open |

`docs/operations/disaster-recovery.md` proposes targets, explicitly marked unratified pending the project owner's sign-off — the same pattern Volume 8 Chapter 8.7 uses for retention windows.

One number is already real and enforced: accidental deletion is recoverable for **90 days in production**, set by ADR-012's noncurrent-version expiry.

### A-018 — No database backup strategy

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.9 |
| **Says** | Aurora Serverless v2 in a private VPC. Backups, retention and restore are not addressed |
| **Should say** | Automated backup retention, point-in-time recovery, snapshot policy before migrations, and a tested restore procedure |
| **Authority** | — decision required |
| **Class** | **Architecture decision — unresolved** |
| **Status** | Open — no cluster exists yet |

Verified 2026-08-09: 0 Aurora clusters. Volume 8 Chapter 8.7 retains `chunk_metadata` for 7 years against 24 months for video, making metadata the more durable record and its loss the more serious failure — yet it is the one with no written backup plan.

### A-019 — CloudTrail is not enabled

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.4 §4 |
| **Says** | "CloudTrail is enabled account-wide, capturing every API call against AWS resources (who generated a presigned URL, who touched Secrets Manager) — a separate, infrastructure-level audit trail from the application-level `audit_log` table" |
| **Should say** | Unchanged — the volume is correct |
| **Authority** | Volume 8, Chapter 8.4 §4 |
| **Class** | **Infrastructure update** |
| **Status** | **Open — implementation gap, not a documentation error** |

Verified 2026-08-09: `describe-trails` returns an empty list; no trail and no event data store exists in `ap-south-1`.

CloudTrail's 90-day Event history is available without a trail, but it is not durable, not exportable, and not the account-wide audit trail V8.4 §4 describes. Volume 8 Chapter 8.7 relies on this trail for the audit evidence that outlives the video itself.

Creating a trail requires a destination bucket, whose name, lifecycle and retention are not covered by ADR-011 or ADR-012 — so this needs a decision, not improvisation.

### A-020 — GuardDuty is not enabled

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.4 §4 |
| **Says** | "GuardDuty is enabled for automated threat detection (anomalous API calls, credential exfiltration patterns) across the account" |
| **Should say** | Unchanged — the volume is correct |
| **Authority** | Volume 8, Chapter 8.4 §4 |
| **Class** | **Infrastructure update** |
| **Status** | **Open — implementation gap; may also be account-blocked** |

Verified 2026-08-09: `list-detectors` fails with `SubscriptionRequiredException`, the same class of account-verification restriction that blocks CloudFront (Mission 0.17.11).

Cost is a real consideration: the account budget is **USD 8/month**, and GuardDuty's baseline can approach that on its own. Enabling it is a cost decision as much as a security one.

### A-021 — No IAM account password policy

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.5 |
| **Says** | Chapter 8.5 covers *application-level* authentication hardening; the AWS console password policy is not addressed |
| **Should say** | Whether an IAM account password policy is required, and its parameters |
| **Authority** | — decision required |
| **Class** | Architecture decision — unresolved |
| **Status** | Open — low severity |

Verified 2026-08-09: `get-account-password-policy` returns `NoSuchEntity`, so AWS defaults apply. Low severity today — one console user, MFA enabled — and it grows with the team.

### A-022 — Branch strategy omits `develop` and release branches

| | |
|---|---|
| **Volume** | 7 — Development Environment, Chapter 7.6 §1 |
| **Says** | "`main` is always deployable; feature branches (`feature/<short-description>`) are short-lived and merged via pull request, never pushed to directly" |
| **Should say** | Two permanent branches, `main` and `develop`, plus temporary `feature/`, `fix/`, `chore/`, `docs/`, `refactor/`, `release/` and `hotfix/` branches. Full topology, merge strategy, protection rules and tagging in ADR-019 |
| **Authority** | ADR-019 |
| **Class** | **Architecture decision** |
| **Status** | Open |

Volume 7 §7.6 §1 describes trunk-based development on `main` alone. That is a reasonable strategy and the right one for a single deployed environment, but ADR-014 defines three environments and assigns each a branch. Without `develop` there is no branch representing "everything merged but not yet a release candidate", so either `main` destabilises or staging verifies a state that never existed.

The rest of Chapter 7.6 is unaffected and correct: pull-request-only merges, the pre-commit hook, the `.gitignore` rules including committed `*.g.dart`, and conventional commit messages.

### A-023 — Commit message example predates Conventional Commits

| | |
|---|---|
| **Volume** | 7 — Development Environment, Chapter 7.6 §4 |
| **Says** | "Conventional, imperative-mood messages referencing the requirement/chapter they implement where relevant (e.g. `Add checklist retry action (FR-CHK-05, C-08)`)" |
| **Should say** | Conventional Commits format — `type(scope): subject` — with requirement IDs moved from the subject into the footer. The example becomes:<br>`feat(features/recording): add checklist retry action`<br>`Implements FR-CHK-05, C-08` |
| **Authority** | ADR-020 |
| **Class** | Documentation update |
| **Status** | Open |

The chapter's *intent* is unchanged and fully preserved: imperative mood, and traceability to a Volume 1 requirement ID. Only the placement changes — the ID moves to the footer, where it does not consume the 72-character header and is machine-readable.

The word "conventional" in §4 is ambiguous between "tidy" and "Conventional Commits", and the example given would fail the latter. ADR-020 resolves the ambiguity in favour of Conventional Commits, because a machine-readable type is what lets Volume 11 Chapter 11.5's changelog be derived from history rather than remembered.

### A-024 — fvm is not adopted; the SDK version is pinned in CI instead

| | |
|---|---|
| **Volume** | 7 — Development Environment, Chapters 7.5 and 7.13 §2; Volume 3, Chapter 3.8; Volume 6, Chapter 6.2 |
| **Says** | The Flutter SDK is pinned via **fvm**, "not installed as a single loose 'stable channel' copy". Volume 6 §6.2 lists `.fvmrc` at the repository root. Volume 7 §7.13 §2 requires CI to use "the same pinned Flutter version as local development" |
| **Should say** | Either that fvm is adopted and `.fvmrc` exists, or that the version is pinned by another mechanism |
| **Authority** | — decision required |
| **Class** | **Architecture decision — unresolved** |
| **Status** | Open |

Verified 2026-08-09: **no `.fvmrc` exists** at the repository root or under `mobile/`, and fvm is not installed. The local toolchain is a bare `stable` install at Flutter 3.44.9.

Mission 0.18.4 addressed the half of §7.13 §2 that CI controls — the workflow now pins `FLUTTER_VERSION: 3.44.9` instead of tracking `channel: stable`, so CI cannot silently move when stable does. **That does not close the amendment**: the pin is asserted in one file rather than derived from a shared source, so CI and a developer's machine can still diverge, just no longer silently on Google's release schedule.

Adopting fvm would close it properly and is deliberately not done here — introducing a toolchain manager is a decision with its own cost, not a side effect of a CI audit.

### A-025 — `public_member_api_docs` cannot be scoped from the root config

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.7 §2 |
| **Says** | `public_member_api_docs` is required, annotated "domain/ and data/ layers only (Section 5)" |
| **Should say** | The scoping mechanism — a nested `analysis_options.yaml` inside each feature's `domain/` and `data/` directory, since the Dart analyzer cannot restrict a lint to a subdirectory from the root file |
| **Authority** | Volume 3, Chapter 3.7 §2 |
| **Class** | Documentation update (gap) |
| **Status** | Open — no action possible yet |

Verified in Mission 0.18.5: enabling the rule at the root produces **122 issues** in `core/` and `app/` — layers the chapter deliberately exempts. The requirement is correct; only the mechanism is unstated.

`lib/features/` is empty (ADR-001), so neither `domain/` nor `data/` exists. The rule must be enabled by the first feature, via a nested config; `mobile/analysis_options.yaml` documents the exact form.

### A-026 — import-boundary enforcement uses CI, not `custom_lint`

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.7 §2 |
| **Says** | "This project addresses it with a `custom_lint` / `import_lint` rule set, configured to fail CI (Volume 7) rather than relying on reviewer memory alone" |
| **Should say** | Boundary enforcement is implemented by the `Architecture boundaries` CI job, which fails the build if a package is imported outside the layer that owns it |
| **Authority** | ADR-019 (required status checks) |
| **Class** | Documentation update |
| **Status** | Open |

The chapter's **purpose is met**: enforcement fails CI rather than depending on review. Only the mechanism differs.

`custom_lint` was checked and **does resolve** against the current pinned toolchain, so this is not an infeasibility. It is declined because the `Architecture boundaries` job already enforces the same four rules; adopting `custom_lint` would add seven dependencies and a second mechanism for one outcome. The CI job additionally covers `isar`, which the chapter still names as Drift (ADR-009).

Revisit if boundary rules grow beyond what a grep can express — per-layer import direction, for instance, rather than per-package confinement.

### A-027 — `golden_toolkit` is discontinued

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.1; Volume 9, Chapter 9.5 §1 |
| **Says** | Golden testing uses `golden_toolkit` ("visual regression"), listed as project tooling |
| **Should say** | The golden-testing *requirement* stands unchanged (V9.7 §2). The named package does not — a maintained mechanism must be chosen, most likely Flutter's built-in `matchesGoldenFile` |
| **Authority** | — decision required |
| **Class** | **Architecture decision — unresolved** |
| **Status** | Open — no action possible yet |

Verified 2026-08-09: `flutter pub add --dev golden_toolkit --dry-run` resolves **`golden_toolkit 0.15.0 (discontinued)`**. pub.dev marks the package discontinued.

Nothing about V9.7 §2's requirement changes — every Design System component still needs a golden test in both themes, and an unintentional pixel diff must remain a hard CI gate. Only the tool must be reselected.

Not urgent: **no Design System component exists yet.** `lib/shared/` is empty and the only screen renders two `Text` widgets, so there is nothing to capture. The decision belongs to the mission that builds the first component.

### A-028 — Required test tooling is not installed

| | |
|---|---|
| **Volume** | 3 — Chapter 3.1; Volume 9, Chapter 9.5 §1 |
| **Says** | The test toolchain is `flutter_test`, `mocktail`, `integration_test`, `golden_toolkit` |
| **Should say** | Unchanged — the volumes are correct |
| **Authority** | Volume 3 Chapter 3.1 |
| **Class** | **Infrastructure update** |
| **Status** | Open — deferred until each has a consumer |

Verified 2026-08-09: only `flutter_test` is declared. `mocktail 1.0.5` resolves cleanly; `integration_test` ships with the SDK; `golden_toolkit` is discontinued (A-027).

Deliberately not installed in Mission 0.18.6, because **each would be an unused dependency today**:

- **`mocktail`** — V9.6 §1 requires mocked repositories and Riverpod notifiers. Neither exists; `lib/features/` is empty. The current suite uses hand-written fakes, which is appropriate at this size.
- **`integration_test`** — all five flows in V9.7 §1 (login, checklist, record, admin assignment, retry) depend on features that do not exist.
- **`golden_toolkit`** — no Design System component exists, and the package is discontinued.

Each should be added by the mission that creates its first consumer, not before. An installed-but-unused test dependency is weight in the lockfile and an invitation to use the wrong tool for the current problem.

### A-029 — Android build is broken: `isar_flutter_libs` is incompatible with the current toolchain

| | |
|---|---|
| **Volume** | 3 — Chapter 3.1 (Isar as local persistence); ADR-009 |
| **Says** | Isar is the local database engine |
| **Should say** | Either that Isar is replaced, or that a supported version exists for the current Android Gradle Plugin |
| **Authority** | — decision required; **ADR-009 anticipated this exact failure** |
| **Class** | **Architecture decision — unresolved. BUILD BLOCKER.** |
| **Status** | **Partially resolved (Mission 0.18.8A)** — Android builds again via a scoped Gradle shim. The engine decision remains open |

Verified 2026-08-10 by `flutter build apk --debug`:

```
A problem occurred configuring project ':isar_flutter_libs'.
> Namespace not specified. Specify a namespace in the module's build file:
  .../isar_flutter_libs-3.1.0+1/android/build.gradle
BUILD FAILED
```

Android Gradle Plugin 8+ requires every module to declare a `namespace`. `isar_flutter_libs 3.1.0+1` was published in 2023, before that requirement, and has not been updated.

**This is not a new risk.** ADR-009's Consequences recorded it verbatim: *"Compatibility with Flutter 3.44 and Dart 3.12, including the Android Gradle and NDK toolchain, given the gap between the package's release and the current SDK"* — listed as unverified and requiring settlement before implementation. It has now been verified, and it fails.

ADR-009 also stated the consequence: *"If either fails, the engine choice must be revisited — which contradicts `CLAUDE.md` and would require both a new ADR and an amendment to the constitution."*

Scope: **Android only.** Web builds successfully in all three environments. The pure-Dart `isar` package compiles; only the Android native module fails.

### Resolution applied — Mission 0.18.8A

A scoped Gradle shim in `mobile/android/build.gradle.kts` patches **two** properties of `isar_flutter_libs`, and nothing else:

1. `namespace`, absent because the module predates AGP 8.
2. `compileSdk` 30 → 36. Namespace injection alone was **not sufficient**: it produced 21 AAR-metadata errors, because the module's own transitive dependencies (for example `androidx.fragment 1.7.1`) require compileSdk 34 or later.

Verified from a clean tree: `flutter build apk --debug` and `flutter build apk --release` both succeed.

The shim is scoped to that one module **by name**. A blanket patch across all subprojects would silently absorb the next incompatible plugin rather than failing loudly.

**This is a bridge, not a cure.** It keeps the documented engine building; it does not make Isar maintained. `compileSdk 36` is forced on code written for API 30 — it compiles, but that combination was never tested by the package author.

**ADR-009's other Android risk is untouched: 16 KB page size support**, which Google Play requires and which these prebuilt native libraries predate. It remains unverified and is the next likely release blocker.

### Options still open for the engine decision

1. **Keep Isar with the shim** — current state. Zero architectural change, ongoing patching of a package nobody maintains.
2. **Move to `isar_community`** — verified to resolve at **3.3.2**, a maintained fork of the same engine with the same API and generated-code format. Changes import URIs in `core/database/` and the package name in ADR-009 and the CI boundary check. Needs authorisation.
3. **Adopt Drift**, which Volume 3's own ADR-002 originally chose and ADR-009 called "the strongest alternative". Requires a superseding ADR and a `CLAUDE.md` amendment.

### A-030 — Build flavors are not configured

| | |
|---|---|
| **Volume** | 7 — Chapter 7.11 §2; Volume 10, Chapter 10.1 §4 |
| **Says** | "dev / staging / prod flavors are configured in `android/app/build.gradle` and iOS's scheme configuration, each pointing at the matching Firebase project and API base URL — selecting a flavor is enough". V10.1 §4: only the `prod` flavor is ever built for Play Store upload, and "dev/staging flavors are never accidentally shippable since they use entirely separate Firebase projects and app IDs" |
| **Should say** | Environment selection uses `--dart-define=APP_ENV` (ADR-007, ADR-016, ADR-018), not Gradle product flavors and Xcode schemes |
| **Authority** | ADR-007, ADR-016, ADR-018 |
| **Class** | **Architecture decision** |
| **Status** | Open |

Verified 2026-08-10: `android/app/build.gradle.kts` contains **no `productFlavors` block**, and `ios/Runner.xcodeproj` has a **single scheme** (`Runner.xcscheme`). `flutter run --flavor dev`, which V7.11 §3's first-run checklist requires, cannot work.

The accepted ADRs took a different route deliberately: one build artifact whose behaviour is fixed at compile time by `APP_ENV`. ADR-014 requires that the artifact promoted to production be **the same artifact verified in staging**, which flavors would break by producing three distinct binaries.

**One protection is genuinely lost, and it should be recorded rather than glossed.** V10.1 §4 relies on separate Firebase projects and application IDs to make a wrong-flavor upload "immediately obvious in the Play Console". With a single `applicationId` and a single Firebase project (A-014), **a build made with the wrong `APP_ENV` is indistinguishable in the Play Console.** The safeguard V10.1 §4 depends on does not exist.

Mitigations available without adopting flavors: assert `APP_ENV=production` in the release pipeline before upload, and surface the resolved environment in the app's about screen. Neither is implemented.

### A-031 — Chapter 3.7 §2's lint set is a floor, not the whole configuration

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.7 §2 |
| **Says** | A six-rule lint set, chosen "to enforce the layer and module boundaries fixed in Chapters 3.4 and 3.5" |
| **Should say** | Those six rules are the boundary-enforcement floor and are all retained. The project's full static-analysis configuration is fixed by ADR-021 — 176 explicit lint rules, three type-system strictness flags, and a severity promotion map — recorded in `mobile/analysis_options.yaml` |
| **Authority** | ADR-021 |
| **Class** | **Architecture decision** |
| **Status** | Open |

Nothing in §2 is weakened. All six rules remain enabled, and the chapter's stated purpose — boundary enforcement the analyzer performs rather than a reviewer — is unchanged.

The correction is one of scope. §2's list was written for a single purpose and does that job; it was never a claim that nothing else matters. Read as exhaustive — which is how Mission 0.18.5 correctly read it, given the governance rule — it left `strict-casts` off, `dynamic` flowing through every JSON boundary, unawaited futures silent, and `BuildContext` usable across an `await`. Six rules is a boundary check, not a production configuration.

`public_member_api_docs`, the seventh rule §2 names, is still unimplementable from the root config and remains scoped as A-025 describes. ADR-021 does not change that; it documents the nested-config recipe alongside it.

Timing is part of the decision. `lib/features/` is empty and the codebase is 63 files of consistently written infrastructure, so adopting the strict set surfaced 22 findings, 18 of them fixed in a single pass. The same adoption after twenty features would be a mechanical rewrite of thousands of lines — the point at which a team concludes the rules are not worth it.

### A-032 — Documentation-file naming does not cover in-repository markdown

| | |
|---|---|
| **Volume** | 0 — Project Foundation, Chapter 0.2 (Project Constitution) §5 |
| **Says** | Documentation files: `Chapter_<volume>.<chapter>_<Title>.docx`, "matching this document's own naming" |
| **Should say** | That convention governs the **volume deliverables** — the `.docx`/`.pdf` chapters. Markdown documents inside the repository are a different artifact class and are named `kebab-case.md` per ADR-023 §1.4, with `ADR-NNN-kebab-case-title.md` for decision records per `docs/architecture/README.md` |
| **Authority** | ADR-023, ADR-024 |
| **Class** | Documentation update (gap) |
| **Status** | Open |

Not a contradiction so much as a scope the Constitution never contemplated: Volume 0 was written before the repository existed, and every documentation artifact it had in view was a Word chapter. `Chapter_0.2_Project_Constitution.docx` is correct for that class and unusable for a file that lives beside code, is linked by relative path and is read in a diff.

Registered because §5 reads as universal. ADR-023 fixed repository documentation filenames in Mission 0.19.3 **without recording the divergence**, which is precisely the latent disagreement this register exists to make explicit.

The volumes' own naming is unaffected and unchallenged.

### A-033 — Document Control blocks do not transfer to version-controlled markdown

| | |
|---|---|
| **Volume** | 0 — Project Foundation, Chapter 0.2 (Project Constitution) §8 |
| **Says** | "Every document carries a version number and status (Draft / Approved / Superseded) in its Document Control block, so the current source of truth is always identifiable at a glance" |
| **Should say** | For the volume deliverables, unchanged and correct. For markdown in this repository, git is the version record: `git log --follow` gives every revision with its author, date, reason and diff. ADRs carry `Status` and `Date` because status is a binding-or-not lifecycle state, not a version. Reference documents carry neither and name their governing ADR instead |
| **Authority** | ADR-024 |
| **Class** | Documentation update (gap) |
| **Status** | Open |

The requirement is right for its subject. A `.docx` circulated by email has no history of its own, so a Document Control block is the only way to tell which copy is current.

A file in git has that history exactly, and a hand-maintained version field beside it is a second source of truth that goes stale the first time someone edits without bumping it — at which point the block is confidently wrong, which is worse than absent.

**§8's substance is preserved and is not weakened.** "The documentation set is the single source of truth", "if code and documentation diverge the documentation governs", and "superseded documents are retained, not deleted, with a pointer to the replacement" are all in force — the last is implemented by the ADR lifecycle in `docs/architecture/README.md` and by this register's rule that an entry is never deleted. Only the mechanism for identifying the current version differs.

### A-034 — Doc-comment coverage: the Constitution is broader than Volume 3, and outranks it

| | |
|---|---|
| **Volume** | 0 — Chapter 0.2 (Project Constitution) §4, against Volume 3 — Chapter 3.7 §2 |
| **Says** | **V0 §4:** "Every public class, method, and non-trivial function carries a documentation comment explaining intent, not just mechanics." **V3.7 §2:** `public_member_api_docs`, annotated "domain/ and data/ layers only (Section 5)" |
| **Should say** | The Constitution's requirement is repository-wide and governs. Chapter 0.2's Precedence clause states it *"overrides any conflicting instruction in later volumes unless formally amended under Section 9"*, and Volume 3 is a later volume. `public_member_api_docs` therefore belongs in `core/` and `app/` as well as `domain/` and `data/` |
| **Authority** | Volume 0, Chapter 0.2 (Precedence clause and §4) |
| **Class** | **Architecture decision — unresolved** |
| **Status** | Open — supersedes the framing of A-025 |

**A-025 was written on the wrong assumption.** It recorded Volume 3 §3.7 §2's `domain/`-and-`data/` scoping as the binding requirement, and treated the issues the rule produces in `core/` and `app/` as evidence that those layers are "deliberately exempt". They are not exempt: the Constitution requires the comments everywhere, and it outranks Volume 3.

A-025's *mechanical* finding stands unchanged and is still correct — the Dart analyzer cannot scope a lint to a subdirectory from the root config, so a nested `analysis_options.yaml` is still how per-layer scoping would be done. What changes is the target: scoping the rule to two layers is not the goal, it is a narrowing the Constitution does not permit.

**Re-measured for this amendment**, on Flutter 3.44.9 with the ADR-021 configuration. Enabling `public_member_api_docs` at the root produces **167 findings**:

| Where | Count |
|---|---|
| Hand-written `lib/app/` and `lib/core/` | **122** |
| `lib/core/database/collections/database_metadata.g.dart` | **45** |

A-025's figure of 122 is confirmed correct for hand-written code. It did not state that it excluded generated output, and the generated 45 are the more awkward half.

**A second obstacle, not previously recorded.** `isar_generator`'s `ignore_for_file` header does not cover `public_member_api_docs`, so 45 findings land in a file nobody wrote and nobody may edit. ADR-021 analyses generated code deliberately — it ships, so it is analysed — and those 45 cannot be fixed at source. Enabling the rule repository-wide therefore requires an upstream `ignore_for_file` addition, a narrow per-file exclude, or accepting an `ignore_for_file` line that the generator would overwrite on the next build. This is exactly the trade-off ADR-021 refused for `cascade_invocations`, and it must be resolved before the rule can be enabled.

**Mitigating facts, which is why this is not a blocker.** The 122 hand-written findings are missing `///` comments on individual public members, not missing documentation in substance: `core/` is heavily commented, and files such as `dio_client.dart`, `app_exception.dart` and `failure.dart` carry class-level documentation well beyond what the lint asks for. The gap is member-level coverage, not absence of intent.

**Two caveats on this entry itself.** Chapter 0.2 carries `Status: Draft — Pending Approval`, as do Chapters 0.1 and 0.3, so a strict reading makes none of Volume 0 formally binding yet — which is part of why `CLAUDE.md` plus the accepted ADRs are the repository's operative governance. And enabling the rule is a code change across 167 findings, so it belongs to a mission of its own rather than to a documentation mission.

Resolving it means either enabling `public_member_api_docs` repository-wide — closing the 122 hand-written findings and deciding what to do about the 45 generated ones — or a new ADR that narrows the Constitution's §4 deliberately and says why.

### A-035 — Failure modelling: one code-bearing type, not sealed per-feature unions

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.9 §5 (Error Modeling); Volume 6 — Chapter 6.9 §1 |
| **Says** | "Each feature that can fail defines its own sealed error type (a freezed union) rather than throwing a bare Exception", with the example `sealed class ChecklistFailure` / `InsufficientStorage { final int freeBytes; }` / `BatteryTooLow { final int percent; }`. V6.9 §1 refers to "the sealed failure types from Volume 3, Chapter 3.9, Section 5" by name |
| **Should say** | Failures crossing out of infrastructure are represented by a single `final class Failure` carrying an `ErrorCode`, per ADR-025. Presentation pattern-matches on the code, not on a subtype. **The requirement §5 exists to serve is unchanged: every failure names a specific cause and fix, and a generic "Something went wrong" remains forbidden** |
| **Authority** | ADR-025 |
| **Class** | **Architecture decision** |
| **Status** | Open — **one capability is genuinely lost, see below** |

The implementation was built in Mission 0.10 and `failure.dart` states the reasoning: *"A hierarchy of failure subclasses would push infrastructure concerns back into the shape of the type."* A per-feature sealed union also has to be constructed somewhere, and the only place that knows the failure is the infrastructure boundary — which would then need to know about every feature's union.

**§5's purpose is met.** 28 distinct `ErrorCode` cases give presentation more to pattern-match on than a four-case union does, and the compiler still forces exhaustiveness over a Dart enum switch. "Never a single generic string" holds.

**One capability is lost, and it should be recorded rather than glossed.** The volume's model carries **typed payload data** — `InsufficientStorage { freeBytes }`, `BatteryTooLow { percent }` — and `Failure` has only a code and an optional `String?`. So copy of the form *"You need 2.3 GB free; you have 400 MB"* can currently only be produced by interpolating numbers into a message string, which is **not localisable** and defeats §21's rule that display text is resolved from the code.

This is not hypothetical: Volume 3's own example is the checklist, and Volume 2 §2.9's copy table is where the numbers would appear.

**Two options, both needing their own ADR:**

1. **Give `Failure` a typed payload.** A sealed payload type per code group, or a small generic parameter. Keeps one failure type and one conversion point; adds shape to the thing deliberately kept shapeless.
2. **Allow feature-level sealed unions in `domain/` alongside the core `Failure`.** Closer to §5 as written. Costs a second failure representation, and `domain/` may then need a mapper from `Failure` to its own union — which is the coupling ADR-025 avoided.

Deliberately unresolved while `lib/features/` is empty. **The cost of deferring is not zero:** it grows with each feature written against the current model, and the first feature needing a number in its copy will force the decision.

### A-036 — Global error handlers and the error reporting service do not exist

| | |
|---|---|
| **Volume** | 6 — Mobile App Architecture, Chapter 6.9 §2 |
| **Says** | "`FlutterError.onError` — catches framework/widget-layer errors… `PlatformDispatcher.instance.onError` — catches errors outside the Flutter framework's own zone… Both handlers funnel into one `ErrorReportingService`… so there is exactly one place that decides what happens next, not two independent logging paths" |
| **Should say** | Unchanged — the volume is correct |
| **Authority** | Volume 6, Chapter 6.9 §2 |
| **Class** | **Implementation update** |
| **Status** | **Open — implementation gap, not a documentation error** |

Verified 2026-08-11: `main.dart` installs neither handler, and no `ErrorReportingService` exists anywhere in `lib/`.

The **modelled** error path is complete and well covered — five exception types, 28 codes, five conversion boundaries, and `Failure` as the only thing crossing outward. The **unmodelled** path has nothing at all. An unanticipated platform exception on a Collector's device is handled by Flutter's default handler, printed to a console nobody is attached to, and reported nowhere.

Volume 6 §6.9 §1 is explicit that these are two different jobs: modelled failures *"never reach a global handler at all"*, and the global handlers exist precisely for *"anything a layer didn't anticipate"*. Having built the first and not the second leaves the class of error that is hardest to reproduce entirely invisible.

**Sequenced after A-037.** The handlers must funnel into one service, and what that service does depends on whether a crash reporter is adopted. Installing handlers that only log would satisfy the letter of §2 and none of its purpose — the point is field visibility, and `AppLogger` output does not leave the device.

### A-037 — Crash reporting is not adopted, and the volumes' ADR numbering collides with this register

| | |
|---|---|
| **Volume** | 6 — Chapter 6.9 §3; also Volume 3, Chapter 3.9 §1 |
| **Says** | V6.9 §3 presents "**ADR-010** — Crash Reporting / Diagnostics Tool", Status Accepted, Decision: **Firebase Crashlytics**, chosen because Firebase is already in the stack for Auth and FCM. V3.9 §1 refers to "**ADR-001** (Chapter 3.2) chose Riverpod" |
| **Should say** | Two separate corrections. **(a)** Crash reporting is not implemented: `firebase_crashlytics` is not a dependency. **(b)** The volumes' ADRs are numbered within Volume 3 Chapter 3.2 and that sequence is **independent of `docs/architecture/decisions/`**. A citation must name its register |
| **Authority** | ADR-010, ADR-003, ADR-025 |
| **Class** | **Implementation update** and **Documentation update** |
| **Status** | Open |

**(a) The tool.** Verified 2026-08-11: `pubspec.yaml` declares `firebase_core` and no Crashlytics. The volume's reasoning is sound and still holds — Firebase is already in the stack, so this adds no vendor relationship — and this repository's ADR-010 anticipates it, listing Crashlytics among the products that *"resolve the already-initialised default app through the SDK's own registry, so adding a product means adding a dependency and a provider for it."* Adopting it is therefore cheap and unblocks A-036.

Volume 6 §6.9 §3 also fixes a use that is easy to miss: Crashlytics' **non-fatal** logging is for *"the modeled-but-still-noteworthy cases (e.g. a chunk hitting its final retry attempt, Volume 5, Chapter 5.13)"* — so field patterns are visible even when nothing crashed. That is a requirement on the retry work, not only on crash reporting.

**(b) The numbering collision, which is the more insidious half.** Two concrete instances:

| Citation in a volume | Volume means | This register's ADR of that number |
|---|---|---|
| "ADR-010" (V6.9 §3) | Crash reporting — Firebase Crashlytics | **Firebase Platform Integration** |
| "ADR-001" (V3.9 §1) | Riverpod for state management | **Adopt Clean Architecture** (Riverpod is **ADR-003** here) |

A reader who follows "ADR-010" from Volume 6 into `docs/architecture/decisions/` arrives at a different decision and has no signal that anything is wrong — both numbers exist, both are Accepted, and the subjects are adjacent enough to seem plausible.

**Correction:** `docs/architecture/decisions/` is the authoritative register for this repository, and its numbering is not the volumes'. A citation of a volume's internal ADR must say so — "Volume 3 Chapter 3.2's ADR-010", never a bare "ADR-010". The volumes' Chapter 3.2 ADRs are historical proposals; where one has been re-decided here, this register governs and the numbers are unrelated.

**No renumbering is proposed.** ADR numbers in this register are permanent (`docs/architecture/README.md`), and the volumes are PDFs that cannot be edited. Naming the register at the point of citation is the only fix available, and it is sufficient.

### A-038 — Five layers with an uninverted arrow, against four with dependency inversion

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.4 §2 and §3 |
| **Says** | Five layers — Presentation, State, Domain, Data/Repositories, Platform Services — with the dependency arrow running **downward**: *"Presentation depends on State, State depends on Domain, Domain depends on Data"*, and *"an arrow only ever points downward"* |
| **Should say** | Four layers per feature — `domain/`, `data/`, `application/`, `presentation/` — with the dependency **inverted**: `domain/` declares repository interfaces and depends on nothing; `data/` implements them. Riverpod state lives in `presentation/`; platform services are `core/`. Per ADR-001 and ADR-022 |
| **Authority** | ADR-001, ADR-022 |
| **Class** | **Architecture decision** |
| **Status** | Open |

Two differences, and the second is the one that matters.

**Layer count and naming.** V3.4's five layers map onto the implemented four plus `core/`: its *Domain* (use-case classes) is `application/`; its *Data/Repositories* splits into `domain/`'s interfaces and `data/`'s implementations; its *State* is `presentation/`'s controllers; its *Platform Services* is `core/`. The same system, differently cut.

**Dependency direction, which is opposite.** V3.4 §3 has `Domain → Data/Repositories`. ADR-001 has `data/ → domain/`, stating that *"the direction of the dependency is the opposite of the direction of control"*. Under V3.4 a use case depends on a repository; under ADR-001 a use case depends on an interface its own layer declares, and the implementation depends inward.

**ADR-001 governs, and V3.4's own stated goal is better served by it.** V3.4 §5 claims testability as the reason for the shape — *"Domain use-cases and Repositories are pure Dart with no widget tree dependency, so Volume 9's testing strategy can unit-test every business rule without ever booting the Flutter engine."* Dependency inversion is what delivers that: `core/errors/failure.dart` is pure Dart **by necessity** precisely because `domain` consumes it and may depend on nothing outward.

**Cost of the divergence.** Two readable descriptions of the layer architecture are in circulation, and a reader who consults Volume 3 alone will build the wrong arrow. ADR-001 cites no Volume, so nothing in either document points at the other. This entry is that pointer.

### A-039 — Chapter 3.5 §4 contradicts itself on cross-feature dependency

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.5 §4 |
| **Says** | Both of these, in the same section: *"recording depends on core and projects_tasks"*, *"upload depends on core and recording"*, *"onboarding and settings depend on core and auth"*, *"admin_shared depends on core, auth, and projects_tasks"* — **and** *"no two feature modules depend on each other directly without going through core"* |
| **Should say** | The closing rule governs. No feature module imports another, at any layer, in either direction (ADR-022 R3). The listed inter-module dependencies are **conceptual ordering**, not permitted imports, and are expressed through `core/`, a shared abstraction, or state |
| **Authority** | ADR-022 |
| **Class** | Documentation update — **the chapter is internally inconsistent** |
| **Status** | Open |

The bullets name direct feature-to-feature dependencies; the sentence closing the same section forbids them. Both cannot hold.

**Two of Volume 3's three statements agree with ADR-022 R3.** Chapter 3.4 §1 independently requires *"never sideways across features without going through a shared layer"*, and §3.5 §4's own closing sentence calls its rule *"the same inward-only dependency rule from Chapter 3.4, applied across features instead of across layers."* The bullet list is the outlier within Volume 3, not ADR-022.

**The conceptual dependencies are real and the reasons given are good** — a recording session is tied to an assigned Task; a chunk exists only once recording produces it. What ADR-022 R3 forbids is expressing that relationship as an import, because one cross-feature import makes two features a single deployable unit while the folder tree still shows two. `folder-structure.md` R3 gives four ordered resolutions.

**Note on `metadata`.** §3.5 §4 already models this correctly: *"metadata depends on core, and is read by recording… and by upload/admin_shared… but metadata itself depends on nothing outside core, keeping its integrity rules isolated from both."* That is the pattern the other modules should follow, stated by the Volume itself.

**ADR-022 §6.2 predicted this exact case** — `recording` and `upload` were named as R3's test — without knowing §3.5 §4 existed on both sides of it.

### A-040 — The `core` module's scope includes composition and routing

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.5 §2; Chapter 3.6 §5 |
| **Says** | The `core` module owns *"the app's Riverpod `ProviderScope` setup, `go_router` configuration"* and the five-layer base classes; §3.6 §5 adds *"`core/router/` for go_router config"* |
| **Should say** | Composition — the `ProviderScope` and startup sequence — is `main.dart`'s (ADR-002). The route table is `app/router.dart`'s (ADR-004). `core/` is cross-cutting **infrastructure** only: network, database, storage, logging, errors, firebase, environment |
| **Authority** | ADR-002, ADR-004 |
| **Class** | **Architecture decision** |
| **Status** | Open |

Volume 3's `core` module is broader than this repository's `core/` directory: it covers what ADR-002 splits into `app/` and `core/`. ADR-002 rejected the merged form deliberately, recording that *"infrastructure (networking, storage, logging) and presentation helpers (widgets, formatters) have different dependency profiles and different reviewers"* — and the same argument separates configuration and routing from infrastructure.

The separation is load-bearing rather than cosmetic: it is what makes ADR-022 §5.2's rule expressible at all. `core/` may read `app/config/` and must not import `app/theme/`, and `app/config/` must never import `core/`. Under a merged `core` module none of those directions exists, and `DioClient` could reach a colour token.

**Volume 3 §3.6 §5's related instruction is correct and is implemented:** *"`core/` internally follows the same … shape where relevant (e.g. `core/theme/` … `core/router/`), rather than becoming an unstructured dumping ground."* The intent — `core/` is structured by concern, not a dumping ground — holds exactly; `core/` has seven concern-named modules. Only the placement of `theme/` and `router/` differs, and ADR-002 puts both in `app/`.

### A-041 — The State layer's suffix: `Notifier` or `Controller`

| | |
|---|---|
| **Volume** | 3 — Chapter 3.4 §2 (the State layer's `RecordingNotifier`); Chapter 3.6 §5 (files suffixed `_notifier.dart`) |
| **Says** | Riverpod state classes are `Notifier`s, in files named `*_notifier.dart` |
| **Should say** | ADR-023 §4.2 requires `<Subject>Controller`, with the provider `<subject>ControllerProvider` — so `RecordingController` in `recording_controller.dart` |
| **Authority** | ADR-023 |
| **Class** | Documentation update |
| **Status** | Open — **registered with a caveat against ADR-023, see below** |

ADR-023 governs, and no code is affected: no notifier or controller exists yet, because `lib/features/` is empty.

**The caveat, recorded rather than glossed.** ADR-023 §4.2 rejected `Notifier` on the grounds that *"`RecordingNotifier`/`RecordingViewModel`/`RecordingBloc` … ADR-003 makes Riverpod the sole mechanism; borrowing another framework's vocabulary implies a second one is in play."*

**That reason does not hold for `Notifier`.** `Notifier`, `AsyncNotifier` and `StreamNotifier` are Riverpod's own class names — the very API ADR-003 adopts. Under ADR-003, `Notifier` is *native* vocabulary, not foreign. The argument is sound for `ViewModel` (MVVM) and `Bloc` (flutter_bloc) and was over-applied to a third term that does not belong with them. Volume 3 uses `Notifier` consistently for precisely the right reason: it is what the framework calls the thing.

**ADR-023 remains binding until superseded** — an accepted ADR is not edited to change its meaning. But the divergence from Volume 3 rests on a justification that does not survive scrutiny, and `Controller` also loses the information `Notifier` carries: which of `Notifier`, `AsyncNotifier` or `StreamNotifier` a class extends, which Volume 3 §3.9 §3 makes a per-feature decision.

**Revisit before the first controller is written.** That is the last moment the choice is free; afterwards it is a rename across every feature. Resolving it means either a superseding ADR adopting `Notifier`, or ADR-023 §4.2's reasoning being restated on a ground that holds — a deliberate divergence from the framework's vocabulary is defensible, but it should be argued as one.

### A-042 — Chapter 3.7 §6's log levels are a floor; `fatal` is the fifth

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.7 §6 |
| **Says** | *"all diagnostic output goes through a single project-wide logger, with log levels (debug/info/warn/error) so Volume 7's CI and Volume 9's testing tooling can filter noise from signal"* |
| **Should say** | Those four are the floor. Five levels exist — `debug`, `info`, `warning`, `error`, `fatal` — as `LogLevel` in `core/logging/`. `fatal` is required by ADR-017's abort path. The third is spelled `warning`, matching the `logger` package's `Level.warning` |
| **Authority** | ADR-027, ADR-017 |
| **Class** | Documentation update (gap) |
| **Status** | Open |

**Nothing in §6 is weakened.** `print()` is banned and enforced as an analyzer error (ADR-021); all diagnostic output goes through one project-wide logger; levels exist and filter. The correction is one of completeness.

**`fatal` is not decoration.** ADR-017 makes a Firebase initialisation failure fatal in staging and production, and the implementation logs at `fatal` before rethrowing — *"so it surfaces as a crash with a cause rather than as an application that runs strangely."* Without a fifth level, aborting startup and failing an operation would log identically, which is the distinction the ADR exists to make.

**Why five and not more.** `LogLevel` records the bound: the `logger` package also offers `trace`, `all` and `off`, *"which are either redundant with [debug] or a filter setting rather than a severity."*

This is the same pattern as **A-031** for §2 of the same chapter: Chapter 3.7 states minimums that a reader can mistake for closed sets. `warn` versus `warning` is a spelling, recorded only so the difference is not read as a second level.

### A-043 — No log leaves the device, so §6's stated payoff is not achieved

> **Partly corrected by A-044.** This entry was written in Mission 0.19.7 without Volume 9 Chapter 9.2, which specifies the mobile log sink and **forbids off-device transmission**. The finding that no log is retained anywhere stands; the framing that a *remote aggregator* is missing does not. Read this entry together with A-044.

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.7 §6 |
| **Says** | *"as much debugging as possible should be diagnosable from structured logs rather than requiring a physical device in hand"* — the justification given for the whole logging rule, chosen for a Windows-first workflow |
| **Should say** | Unchanged — the Volume is correct, and this is the requirement |
| **Authority** | Volume 3, Chapter 3.7 §6 |
| **Class** | **Implementation update** |
| **Status** | **Open — implementation gap, not a documentation error** |

Verified 2026-08-11. Three findings, compounding:

**The console is the only sink, in every environment.** `AppLogger` accepts an optional `LogOutput`, documented as *"an injection point for tests and for future log destinations. When null, the underlying package writes to the console."* `loggerProvider` supplies none. No file sink, no remote aggregator, no crash reporter.

**Production emits `warning` and above only**, per `AppLogger.minimumLevelFor`. Correct in itself — *"logs record what went wrong rather than what happened"* — but combined with a console-only sink it means a production failure on a Collector's device leaves **no durable record anywhere**. The device is not merely convenient for diagnosis; it is required, and even then only while a console is attached.

**No contextual metadata is attached.** A log event carries a timestamp, a level, a message, an optional error and an optional stack trace. There is no correlation, request, session, Collector, device or app-version identifier on any line, so lines from one recording `Session` — the Glossary's central unit — could not be grouped even if a sink existed.

**On the word "structured".** The format is line-oriented and deliberately aggregator-friendly: ISO-8601 timestamps chosen because *"they sort lexicographically and parse without a format string"*, one event per line, and `PrettyPrinter` rejected because its *"boxes and colour codes are pleasant in a terminal and unreadable in a log aggregator."* It is **not** key-value structured — no JSON, no parseable field separation beyond the timestamp and level prefix. Whether §6's *"structured"* requires machine-parseable records or simply well-organised output is genuinely ambiguous in the text, and this entry does not resolve it by assertion: the sink gap defeats §6's purpose either way.

**Sequenced with A-036 and A-037.** Volume 6 §6.9 §2's global handlers must funnel into one `ErrorReportingService`, and §6.9 §3 selects Firebase Crashlytics — so the sink decision, the handler decision and this entry are one piece of work. Closing A-043 alone would produce a second logging path, which §6.9 §2 forbids by name.

**Not closed by anything already decided.** No Volume specifies a mobile log destination or a required log field, so the mechanism is an open decision needing its own ADR rather than an unimplemented specification.

### A-044 — Volume 9 Chapter 9.2 governs logging and was not consulted

| | |
|---|---|
| **Volume** | 9 — Quality Assurance, Chapter 9.2 (Logging), §1–§4. Extends Volume 3, Chapter 3.7 §6 |
| **Says** | Four things, none of which ADR-027 was written against. **§1:** `info` is for *"Normal lifecycle events worth seeing **in production logs** — Session started, chunk finalized, upload complete"*; `debug` is *"stripped from release builds"*. **§2:** *"Every log line touching a chunk or session includes its `chunk_id`/`session_id`… this is what makes it possible to reconstruct one Collector's one session's full journey"*. **§3:** mobile logs are *"kept in a local ring buffer (last N entries) attached automatically to a Crashlytics report if a crash occurs, and are **not otherwise transmitted off-device**"*. **§4:** GPS coordinates, device identifiers and Volume 8 §8.6 personal data are *"never logged at `info`/`debug` level"*, substituting a `chunk_id` the developer can join on |
| **Should say** | §1's production expectation, §2's correlation requirement and §3's sink are **not implemented**. §1's *"stripped from release builds"* is superseded by ADR-027's environment-based filtering. §4 is unimplementable until §2 is, and is enforced by review (`review-checklist.md` §4.6) |
| **Authority** | Volume 9, Chapter 9.2; ADR-027 for the build-mode point only |
| **Class** | **Implementation update**, and one **architecture decision** |
| **Status** | Open |

**This entry exists because Mission 0.19.7 did not read Volume 9.** That mission's brief named Volumes 3, 4 and 6; the chapter that governs logging in detail is in Volume 9, and it declares itself an extension of the chapter that mission did read. The four findings below were all missed, and `logging-standards.md` has been corrected in place with each correction marked.

**§1 — production suppresses the level the Volume wants visible.** `AppLogger.minimumLevelFor(production)` returns `warning`, so `info` never emits in production. §9.2 §1's examples of `info` — *session started, chunk finalized, upload complete* — are exactly the lifecycle events a Collector's session would need to reconstruct. **This is a direct contradiction, not a gap**, and resolving it is a decision: either production moves to `info`, accepting the volume, or a new ADR narrows §9.2 §1 and says why. It interacts with §3: a ring buffer of the last N entries makes `info` in production far cheaper than a console would, because nothing is transmitted.

**§1's other half is already superseded.** *"`debug` … stripped from release builds"* is build-mode gating, which ADR-027 rejects deliberately: *"build mode and environment are different questions, and a staging build is a release build."* Environment-based filtering achieves the same outcome for development while keeping staging honest. **ADR-027 governs this half**; §9.2 §1 is out of date on the mechanism, not the intent.

**§2 — the correlation requirement was recorded as a non-requirement.** `logging-standards.md` §7 previously stated that *"no Volume requires specific contextual fields"*, and that was **false**. The requirement is narrower and more useful than a general correlation ID: it applies to lines touching a chunk or session, and the identifiers are Volume 4 Chapter 4.4's, so a mobile line and a backend CloudWatch line join on the same value. Nothing implements it, and nothing can yet — no chunk or session exists.

**§3 — the sink is specified, and it is not a remote aggregator.** A-043 framed the gap as *"no log leaves the device"*, implying remote shipping was missing. §9.2 §3 **forbids** off-device transmission and separates telemetry into Chapter 9.3 as *"a deliberately separate concern"*. The real gap is narrower: **the local ring buffer and the crash-report attachment do not exist.** Sequenced behind A-037, since the attachment target is Crashlytics.

**§4 — a second class of forbidden value, enforced by review.** Personal data is as forbidden as a credential and easier to log by accident, because a GPS coordinate reads as diagnostic detail. §9.2 §4 names its own enforcement — *"the same review discipline as Volume 6 Chapter 6.9's crash-report scrubbing rule"* — so it appears in `review-checklist.md` §4.6. Note the dependency: the sanctioned substitute is logging a `chunk_id` and joining against the metadata store, which requires §2.

**§5 — retention is not a new number.** *"Log retention (90 days) already matches Volume 8, Chapter 8.7 §1's table."* It describes a CloudWatch log-group policy on the backend, so it is out of scope for the mobile layer and creates no mobile obligation.

### A-045 — The injectable-clock rule is cited to a chapter that does not contain it

| | |
|---|---|
| **Volume** | 9 — Quality Assurance, Chapter 9.6 §2, citing Volume 3, Chapter 3.7 |
| **Says** | *"A fake, injectable clock (never `DateTime.now()` called directly inside a use-case) is what makes a 10-minute business rule testable in milliseconds rather than requiring an actual 10-minute test run — this pattern is itself a Chapter 3.7 coding-standard requirement, not just a testing convenience."* |
| **Should say** | The requirement stands, but **Volume 3 Chapter 3.7 does not contain it.** Either §3.7 gains a section fixing time injection as a coding standard, or §9.6 §2 drops the cross-reference and owns the rule as a testing requirement |
| **Authority** | Volume 9, Chapter 9.6 §2 for the rule; ADR-029 records where it is enforceable |
| **Class** | Documentation update |
| **Status** | Open |

Verified 2026-08-11. Volume 3 Chapter 3.7 has nine sections — Static Analysis Configuration, Naming Conventions, Traceability Comments, Documentation Comments, Logging, Immutability & Null Safety, Widget & State Conventions, Code Review Checklist — and **none mentions a clock, `DateTime.now()`, time injection or determinism.** A full-text search of Volume 3 finds no clock rule in any chapter.

**The mis-citation is load-bearing, which is why it is registered rather than treated as a slip.** Calling it *"a Chapter 3.7 coding-standard requirement"* would make it binding on all production code, not merely on code that happens to be tested — a much stronger claim, and one that would be enforced by the §3.7 §9 review checklist. As things stand, nothing binding requires it: no accepted ADR and no Volume section carries the rule, so it rests on ADR-029's testing standard alone.

**Audit finding.** `DateTime.now()` is called directly in three files today — `LoggingInterceptor` (request elapsed time), `DatabaseService` and `FirebaseInitializer` (operation duration). **None is a use case**, so none violates §9.6 §2 as written, and all three produce a duration for a log line rather than a decision. No clock abstraction exists.

**The cost is narrow now and grows.** Those durations cannot be asserted, which is part of why `LogFormatter` and the network interceptors have no tests. It stops being cosmetic when Volume 9 §9.4's *metadata generation < 500ms* target — which §9.4 §1 says is measured by an *"instrumented timestamp diff"* — depends on exactly this kind of value being both produced and verifiable.

### A-046 — Coverage as measured cannot express Chapter 9.5 §2's targets

| | |
|---|---|
| **Volume** | 9 — Quality Assurance, Chapter 9.5 §2 |
| **Says** | Coverage targets per layer: *"Domain layer (use-cases): 90%+ line coverage… Data layer (repositories): 80%+, focused on error-path coverage… Presentation layer (widgets): golden tests for every Design System component rather than a blanket coverage percentage"* |
| **Should say** | Unchanged — the Volume is correct, and these are the targets |
| **Authority** | Volume 9, Chapter 9.5 §2 |
| **Class** | **Implementation update** |
| **Status** | **Open — measurement gap, not a documentation error** |

The targets are per-layer and error-path-weighted. **What CI measures is a single repository-wide line percentage**, computed in the `Test` job as `grep -c '^DA:.*,[1-9]'` over `grep -c '^DA:'`. Two consequences:

**No layer breakdown exists**, so neither the 90% nor the 80% target is computable from what CI reports. The presentation target is not a percentage at all, so it cannot be expressed this way even in principle — golden tests are the measure there (A-027 for the missing tool).

**The metric is blind to files no test imports.** `lcov.info` lists only files loaded during the run, so a file with no test does not appear as 0% — it does not appear. Measured against the committed `coverage/lcov.info` on 2026-08-11:

| | |
|---|---|
| Reported by CI | **146 / 224 lines = 65%** |
| Files that figure covers | **16** |
| Hand-written source files in `lib/` | **55** |
| **Files never loaded by any test** | **39** |

So the reported figure is computed over **29% of the source files**. It is not wrong; it answers a narrower question than it appears to.

**Modules with no test contact at all:** `app/theme` (8 files), `core/database` (7), `core/errors` (6), `core/network` (6), `app/config` (4), `core/storage` (4), `core/firebase` (2), `core/logging` (1), and `main.dart`. Four of those — `database`, `errors`, `network`, `storage` — are every module that converts a third-party error into the taxonomy ADR-025 governs.

**Why the gate is off, and where that reasoning stops.** The CI job states it: *"No threshold is enforced yet, deliberately: `lib/features/` is empty, so `domain/` and `data/` do not exist and any gate would be vacuous."* That is sound for the **layer** targets. It does not extend to the six `core/` modules above, which exist, ship, and are untested.

**A gate on the current metric would be actively harmful**, which is the sharpest point in this entry: because the denominator counts only imported files, the percentage *rises* as fewer files are imported. Gating on it would reward not writing tests. Closing this needs per-layer computation and a denominator that includes every source file, not a threshold on what is reported today.

### A-047 — Chapter 3.8 §5's review cadence has no mechanism, and the tree has aged

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.8 §5; deferral in §3.8 §7 |
| **Says** | *"`flutter pub outdated` is run and reviewed at the start of each development phase boundary… not continuously — batching upgrades avoids constant churn while still preventing the dependency tree from silently aging for a year or more."* And: *"Any dependency with a published security advisory is patched immediately, outside the normal cadence."* §3.8 §7 defers *"the exact CI step that runs `flutter pub outdated` / security scanning"* to Volume 7 |
| **Should say** | Unchanged — the Volume is correct, and this is the requirement |
| **Authority** | Volume 3, Chapter 3.8 §5 |
| **Class** | **Implementation update** |
| **Status** | **Open — implementation gap, not a documentation error** |

**Nothing implements either rule.** Verified 2026-08-11: no CI step runs `flutter pub outdated`, no Dependabot configuration, no Renovate configuration, and no advisory scanning of any kind. `dart pub audit` does not exist as a subcommand in this SDK, so there is no first-party command to run even if a job wanted to. Volume 7 does not specify the step §3.8 §7 defers to it, so the deferral has no destination.

**The predicted outcome has occurred.** §3.8 §5's stated purpose is preventing the tree from *"silently aging for a year or more"*. Measured from `flutter pub outdated`:

| Finding | Count |
|---|---|
| Direct dependencies constrained below a resolvable version | **7** |
| Discontinued packages in the tree | **4** |
| Packages with newer versions blocked by constraints | **26** |

| Package | Current | Latest | Note |
|---|---|---|---|
| `go_router` | 14.8.1 | 17.5.0 | 3 majors behind — **resolvable today, nothing blocks it** |
| `flutter_secure_storage` | 9.2.4 | 11.0.0 | 2 majors behind — **resolvable today** |
| `flutter_riverpod` | 2.6.1 | 3.4.2 | blocked, see A-048 |
| `freezed` | 2.5.2 | 3.2.5 | blocked, see A-048 |
| `freezed_annotation` | 2.4.4 | 3.1.0 | blocked |
| `build_runner` | 2.4.13 | 2.16.0 | blocked |
| `json_serializable` | 6.8.0 | 6.14.1 | blocked |

Discontinued, all transitive: `flutter_secure_storage_macos`, `js`, `build_resolvers`, `build_runner_core`. Three clear on upgrading `flutter_secure_storage` and `build_runner`.

**The two unblocked upgrades are the cheapest available improvement** and are the correct first action on this entry.

**Two further verification rules from §3.8 §4 also have no mechanism.** Licence compatibility (item 4) — all 16 pub packages are compliant today, checked by hand for ADR-030, but nothing re-checks, so a transitive arrival under a copyleft licence would pass unnoticed. And Windows buildability (item 2), which §3.8 §1 calls the constraint *"this project cares about more than most"* — CI runs `ubuntu-latest` only, so a native plugin that breaks the Windows build passes every check.

**Dependabot and Renovate are the wrong fix**, and ADR-030 declines them on the Volume's own terms: §3.8 §5 requires batching *"not continuously"*, and §3.8 §3 forbids bumping core packages *"on an automated schedule alone"*. What is missing is a **phase-boundary trigger**, not a bot.

### A-048 — `isar_generator` caps the code-generation toolchain

| | |
|---|---|
| **Volume** | 3 — Chapter 3.8 §4 item 3, and §3.8 §3's Flutter-SDK-support requirement |
| **Says** | A dependency must be *"actively maintained (a commit or release within the last 6–12 months, no unresolved critical issues)"* and must *"support the currently-pinned Flutter SDK version"* |
| **Should say** | `isar_generator 3.1.0+1` satisfies neither. It was published in 2023, declares `environment: sdk: ">=2.17.0 <3.0.0"` — **no Dart 3 support** — and caps `analyzer` below 6.0.0 and `source_gen` at 1.x, which blocks `freezed` past 2.5.7 and `flutter_riverpod` past 2.x |
| **Authority** | — decision required; **resolved by A-029's engine decision, not by a version bump** |
| **Class** | **Architecture decision — unresolved** |
| **Status** | Open — a new consequence of A-029 |

Verified 2026-08-11 by reading the published `pubspec.yaml` of `isar_generator 3.1.0+1` from the pub cache:

```yaml
environment:
  sdk: ">=2.17.0 <3.0.0"

dependencies:
  analyzer: ">=4.6.0 <6.0.0"
  source_gen: ^1.2.2
  dart_style: ^2.2.3
```

**It declares no support for Dart 3 and the project runs Dart 3.12.2.** It resolves only because pub relaxes the upper SDK bound of packages published before Dart 3. The generator that produces committed, shipped code is running outside its own declared support range.

**The caps propagate, and the resolver says so.** Asked to add `flutter_riverpod ^3.4.2`, pub reports: *"because `freezed >=2.5.8` depends on `source_gen ^2.0.0` and `isar_generator >=3.0.1` depends on `analyzer >=4.6.0 <6.0.0`… version solving failed"*, concluding *"because mobile depends on both `freezed ^2.5.2` and `isar_generator ^3.1.0+1`, version solving failed."*

Resolved consequences: `analyzer 5.13.0` against a current 14.1.0, `source_gen 1.5.0` against 4.2.4, `_fe_analyzer_shared 61.0.0` against 105.0.0. `freezed` cannot pass 2.5.7. `flutter_riverpod` cannot reach 3.x.

**This is a new consequence of A-029, not a restatement of it.** A-029 concerns `isar_flutter_libs` — a runtime package, an Android Gradle Plugin incompatibility, fixed by a scoped Gradle shim. This is `isar_generator` — a dev dependency, a version-solving cap, and the shim does nothing for it. A-029's status is *"partially resolved"*; on this axis nothing is resolved at all.

**`dependency_overrides` is the wrong fix.** Forcing `analyzer 6+` would run a 2023 generator against an analyzer nine majors newer than anything it was built for, and the failure would surface as subtly wrong generated code rather than as a resolution error — which the `Generated code drift` job detects as a difference, not as a wrongness. ADR-030 rejects it explicitly.

**The real fix is A-029's open engine decision.** Of the three options recorded there, moving to `isar_community 3.3.2` — verified to resolve, same API, same generated-code format — is the one that addresses this axis as well as the Android one.

**Not urgent, and it compounds.** No feature depends on `freezed 3` or `riverpod 3` today, so nothing is blocked in practice. The cost grows with every release of the four packages held back, and with every model written against `freezed 2`'s API.

### A-049 — Chapter 9.4 omits Volume 1's `NFR-PERF` and `NFR-SCL` targets

| | |
|---|---|
| **Volume** | 9 — Quality Assurance, Chapter 9.4, against Volume 1's NFR table |
| **Says** | Chapter 9.4 is subtitled *"Measurable Targets, Not Just Volume 1's Prose"* and declares it *"Expands NFR-META-01, NFR-AVL-02"*. Its table carries six targets |
| **Should say** | The table should also carry Volume 1's remaining numeric performance and scalability requirements, each with a measurement method: **`NFR-PERF-01`** — recording preview starts *"< 1.5 seconds on a mid-range device"*; **`NFR-PERF-02`** — chunking begins *"< 2 seconds"* after Stop; **`NFR-SCL-01`** — *"Queue depth of 50+ pending"* chunks without degrading device performance; **`NFR-SCL-02`** — backend scales to a concurrent fleet, *"Verified under load during Volume 9 — Testing"* |
| **Authority** | Volume 1, NFR table |
| **Class** | Documentation update (gap) |
| **Status** | Open |

Verified 2026-08-11 by substring search over the extracted text of Volume 9: **`PERF` occurs 0 times and `SCL` occurs 0 times** in the entire volume. `META` occurs twice and `AVL` three times, both in Chapter 9.4's table and its header.

So the chapter whose stated purpose is turning Volume 1's prose into measurable targets covers two of Volume 1's numeric requirements and silently omits four. Three of the four carry a concrete number in Volume 1 already — 1.5 seconds, 2 seconds, 50 chunks — so they are not prose awaiting quantification; they are quantified requirements with no assigned method.

**`NFR-SCL-02` is the mildest case:** Volume 1 assigns it to Volume 9 by name (*"Verified under load during Volume 9 — Testing"*), and no chapter of Volume 9 defines a load test. So the reference exists and its destination does not — the same shape as A-047's deferral to Volume 7.

**`NFR-PERF-01` and `NFR-PERF-02` are the substantive omissions.** Both are Recording Screen latencies on the Collector's critical path, both have a number, and neither appears in the chapter that assigns measurement methods. Chapter 9.4 §1's own methods column shows what they would need: a stopwatch during Chapter 9.9's device testing, or an instrumented timestamp diff of the kind it specifies for metadata generation.

**Nothing is violated today.** No preview, no chunking and no upload queue exists, so all four are unmeasurable in practice as well as in specification. The gap matters at the moment the Recording Screen is built, which is when someone will ask what "fast enough" means and find that two of the four answers have no method attached.

### A-050 — A 429 is retryable, which Chapter 5.13's blanket 4xx rule would forbid

| | |
|---|---|
| **Volume** | 5 — Recording Engine, Chapter 5.13 §1 |
| **Says** | Failure classification: *"Terminal (server-side) — Backend rejects with a 4xx (e.g. auth/permission error) — Not retried automatically; a repeated identical request would fail identically; surfaces as Failed"* |
| **Should say** | HTTP **429 Too Many Requests** is a 4xx that is explicitly a "try later", and is retryable with backoff, honouring `Retry-After`. Every other 4xx is terminal as the chapter states |
| **Authority** | ADR-025 |
| **Class** | Documentation update |
| **Status** | Open |

`error-handling.md` §16 classifies `NETWORK_RATE_LIMITED` — the code `ErrorInterceptor` maps HTTP 429 to — as **retryable**, on the ground that a 429 is *"explicitly a 'try later'"*. Chapter 5.13 §1's rule is written as a blanket statement about 4xx and would make it terminal.

**The chapter's reasoning does not apply to a 429.** Its justification is that *"a repeated identical request would fail identically"*, which is true of 400, 401, 403, 404 and 409 and false of 429 — the whole point of a 429 is that the identical request succeeds later. The examples it gives are *"auth/permission error"*, so 429 is very likely outside what the chapter meant; only the wording covers it.

**The divergence is small and worth registering because retry is safety-critical here.** Treating a 429 as terminal would surface a rate limit to the Collector as a permanently failed chunk requiring manual retry, when Chapter 5.13 §2's backoff — 5 s, 10 s, 20 s, 40 s, capped at 5 minutes, with ±20 % jitter — is exactly the correct response and already specified. Treating it as retryable costs nothing that the attempt cap does not already bound.

**Nothing implements retry yet** (ADR-025 §16, `AuthInterceptor`), so no behaviour is affected today. This entry exists so the retry ADR resolves it deliberately rather than inheriting whichever of the two documents its author happened to read.

### A-051 — Self-service sign-up with organisation invite codes, which the volumes say deliberately does not exist

| | |
|---|---|
| **Volume** | 10 — Deployment, Chapter 10.4 §4; and Volume 1 Chapter 1.6 `FR-AUTH-01`–`06`; and Volume 2 Chapter 2.4 `SH-02` |
| **Says** | Accounts are *"provisioned by the client organization, not public self-signup"*, and the login flow is not *"a consumer app missing a 'Sign Up' option, since there deliberately isn't one (FR-ADM-07)"*. `SH-02` is specified as *"Email/password fields, SSO entry point, error states"*. No `FR-AUTH` requirement covers registration |
| **Should say** | A Collector or Admin may register themselves by presenting an organisation invite code, which is validated and consumed server-side before the account is created |
| **Authority** | ADR-034 |
| **Class** | Requirement change |
| **Status** | Open — **blocking** |

**This is a product change, not a documentation correction, and it is registered as the project owner's decision rather than as a defect in the volumes.** The volumes are internally consistent on this point across three separate chapters, and Chapter 10.4 §4 does not merely omit sign-up — it names the omission as deliberate and plans to explain it to Apple's reviewer.

**What is now inconsistent is the code, not the volumes.** Mission 2.1 added `signUpWithEmailPassword`, `signUpWithGoogle`, an `inviteCode` parameter and an `OrgInviteCode` entity to `features/auth/domain/`. None of the four traces to a requirement, a screen or an endpoint. This entry is what gives them one.

**Three things are unspecified and must be before the flow can be built:**

1. **A redemption endpoint.** Volume 4 Chapter 4.6 §2 defines exactly two auth routes — `POST /v1/auth/verify` and `GET /v1/users/me` — and neither validates or consumes a code. `backend/` is empty (ADR-015), so there is nothing to call.
2. **Who issues a code, and against what lifecycle.** `OrgInviteCode` carries `expiresAt` and a nullable `remainingUses`, which implies both an issuing surface and a consumption record. No Admin screen in Volume 2 creates one.
3. **How role and `org_id` are set for an account nobody provisioned.** Volume 4 Chapter 4.7 §2 sets them *"at account provisioning time"* precisely so *"a client can never claim its own role"*. Self-registration has to answer where they come from without reintroducing that hole. See A-052.

**Until the endpoint exists, `AuthRepositoryImpl._redeemInviteCode` throws an `UnimplementedError`** and both sign-up methods are unreachable. It deliberately does not throw an `AuthenticationException`: that would be caught by `application/` and shown to a user as "that code is not valid", which is a false statement about a code nothing checked. A permissive stub would be worse still — it would open registration to anyone who can type a string.

### A-052 — `org_id` is carried as a Firebase custom claim, which Chapter 4.7 assigns to the backend

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.7 §2 and §4 |
| **Says** | *"Role (admin/collector) is set as a Firebase custom claim at account provisioning time"* — only the role. §4's pseudocode sources the organisation from the database: `user = db.users.findByFirebaseUid(decoded.uid)`, after which *"role, org_id now available"*. Chapter 4.6 §2 has `POST /v1/auth/verify` *"exchange a Firebase ID token for the app's session context (role, org_id)"* |
| **Should say** | `org_id` is also set as a Firebase custom claim at provisioning time, so the mobile app can build its `User` from the signed ID token alone |
| **Authority** | ADR-034 |
| **Class** | Design change |
| **Status** | Open |

**The mobile `User` entity requires `orgId` and the volumes give the app no way to obtain it.** `role` is a claim and readable from the token; `org_id` is specified as backend state reachable only through `/v1/auth/verify`, and `backend/` is empty. Without this change `AuthRepositoryImpl` cannot construct a `User` at all.

**Carrying it in the token does not weaken the property Chapter 4.7 §2 was protecting.** That property is that *"a client can never claim its own role"* — it holds because the claim is set at provisioning and the token is signed by Firebase, not because the value is unavailable to the client. An `org_id` claim inherits both. The backend continues to re-derive role and scope from its own tables on every request (Chapter 4.8 §1), so nothing server-side starts trusting the client.

**The cost is a second place the organisation is written.** A claim and a `users` row can disagree, and Chapter 4.7 §2 already names the resolution for exactly this case: *"falling back to the users table as the authoritative source if the claim and the table ever disagree."* This extends an existing rule rather than inventing one.

**The alternative was rejected on scope, not on merit.** Injecting `DioClient` and calling `/v1/auth/verify` is what the volumes actually specify, and it remains the more correct answer once a backend exists. It was not taken here because it puts a network round trip, a response DTO and a second error-conversion boundary into a mission scoped to the Firebase boundary. **This entry should be revisited when `backend/` is implemented.**

### A-053 — Google Sign-In as the `SH-02` SSO entry point, where `FR-AUTH-02` specifies enterprise SSO

| | |
|---|---|
| **Volume** | 1 — Product Planning, Chapter 1.6 `FR-AUTH-02`; Volume 2 Chapter 2.4 `SH-02` |
| **Says** | *"The system shall support enterprise SSO (SAML/OAuth) when enabled for a client organization"* — a per-organisation identity provider. `SH-02` calls it an *"SSO entry point"* |
| **Should say** | The MVP SSO entry point is Google Sign-In — a consumer Google account picker, not a per-organisation IdP. Enterprise SAML/OIDC remains open |
| **Authority** | ADR-034 |
| **Class** | Requirement narrowing |
| **Status** | Open |

**These are different mechanisms with different infrastructure.** A per-org SAML or OIDC provider is configured per client organisation and needs Firebase Identity Platform, a paid tier; Google Sign-In authenticates an individual Google account against one Firebase project and needs only the `google_sign_in` package. Reading the second out of the first is a narrowing worth recording, because a client organisation that expects to plug in its own IdP will not be served by an account picker.

**Registered so the choice is deliberate.** `google_sign_in ^7.2.0` is admitted on this basis and confined to `features/auth/data/`. If enterprise SSO returns as a requirement it is additive — `firebase_auth` reaches SAML and OIDC providers with no further package — and this entry marks where the narrowing was taken.

### A-054 — Per-feature sealed failure unions are superseded by `Failure` and `ErrorCode`

| | |
|---|---|
| **Volume** | 3 — Technical Architecture, Chapter 3.9 §5 |
| **Says** | *"Each feature that can fail defines its own sealed error type (a freezed union) rather than throwing a bare Exception, so the Presentation layer can pattern-match to the exact Chapter 2.9-specified message"*, illustrated with `sealed class ChecklistFailure` and its subtypes |
| **Should say** | A feature defines no error type of its own. `presentation/` receives a `Failure` and pattern-matches on its `ErrorCode`, which is the vocabulary ADR-025 fixes for the whole repository |
| **Authority** | ADR-025; project owner's decision, Mission 2.4 |
| **Class** | Design change |
| **Status** | Open |

**The chapter's goal is met; only its mechanism is superseded.** §5's actual requirement is that presentation can pattern-match to Chapter 2.9's copy rather than rendering *"a single generic 'Checklist failed' string"*. `ErrorCode` delivers exactly that — it is a closed enum, a `switch` over it is exhaustive, and `AuthErrorCopy.forFailure` is the Chapter 2.9 copy table §5 asks for. Nothing about the outcome changes; the type carrying the discriminator does.

**Two vocabularies for one set of conditions is the cost being avoided.** ADR-025 already defines `AUTH_INVALID_CREDENTIALS`, `AUTH_ACCOUNT_DISABLED`, `AUTH_SESSION_EXPIRED` and the rest, and `features/auth/data/` already maps every Firebase code onto them (ADR-034). A sealed `AuthFailure` union would restate those same conditions a second time, and every conversion between the two would be a place they could drift apart. §5 was written before ADR-025 existed and could not have known the taxonomy would be central.

**`Failure` is deliberately not extensible, and that is the direct conflict.** `failure.dart` states it: *"The class is `final`: there is exactly one failure type, distinguished by its `code`. A hierarchy of failure subclasses would push infrastructure concerns back into the shape of the type."* A per-feature union is that hierarchy. One of the two documents had to give, and ADR-025 is the accepted, binding one — `CLAUDE.md` and `docs/architecture/README.md` both make an accepted ADR govern where a volume disagrees.

**This is registered project-wide, not for `features/auth/` alone.** ADR-025 has been binding since Mission 0.10 and §26's propagation table already names `presentation/` as the layer that pattern-matches on `code`. Every feature was therefore already on the ADR's side of this disagreement; `auth` is simply the first with code to prove it. The entry exists so the next feature does not read §5, build a union in good faith, and have it rejected at review.

**Chapter 3.9's other requirements are untouched and were followed.** §2's `AsyncValue` pattern, §3's `AsyncNotifier<AuthState>` and its three named cases are all implemented as written. This amendment reaches §5 only.

---

## Confirmed correct — no amendment

Recorded so they are not re-litigated.

| Volume | Subject | Verdict |
|---|---|---|
| V3, Ch. 3.4 §1 | *"never sideways across features without going through a shared layer"* | **Correct**, and exactly ADR-022 R3. It is §3.5 §4's bullet list that conflicts, not this — see A-039. |
| V3, Ch. 3.4 §5 | Domain and repositories are pure Dart, unit-testable without booting the Flutter engine | **Correct and implemented.** `core/errors/failure.dart` is pure Dart by necessity for this reason. The dependency inversion of ADR-001 is what delivers it (A-038). |
| V3, Ch. 3.5 §3 | `metadata` as its own module rather than part of `recording` or `upload` | **Correct**, and justified in the chapter: BR-21–23 stay testable and auditable as a unit. |
| V3, Ch. 3.6 §4 | Every test file at the identical path under `test/` as the file it tests under `lib/` | **Correct and implemented.** Also fixed by ADR-022 §6.1. |
| V3, Ch. 3.6 §5 | Folders `snake_case`; files suffixed by role — `_screen.dart`, `_use_case.dart`, `_repository.dart`, `_service.dart` | **Correct** and consistent with ADR-023 §1.1 and §3. Only `_notifier.dart` diverges — see A-041. |
| V3, Ch. 3.6 §5 | Generated files never hand-edited, committed per Volume 7 | **Correct and implemented.** Enforced by the CI `Generated code drift` job. |
| V3, Ch. 3.7 §6 | `print()` banned; all diagnostic output through a single project-wide logger | **Correct and implemented.** `avoid_print` is an analyzer error (ADR-021); `AppLogger` via `loggerProvider` is the only mechanism, and `package:logger` is confined to `core/logging/`. Only the level list (A-042) and the sink (A-043) diverge. |
| V3, Ch. 3.7 §9 | The six-item code review checklist | **Correct and binding**, via ADR-019. Implemented by `docs/development/review-checklist.md` §3. Two items need reading against amendments taken since — item 2 against A-039, item 5 against A-025 and A-034. |
| V5, Ch. 5.2 §1–2 | Fixed capture parameters, and device-tier degradation that steps down bitrate *"never resolution or frame rate"* | **Correct and authoritative.** Adopted verbatim by ADR-031; the rationale is dataset comparability across the fleet, not device sympathy. |
| V5, Ch. 5.13 §2 | Backoff of 5 s / 10 s / 20 s / 40 s capped at 5 minutes, 6 attempts, ±20 % jitter | **Correct and authoritative.** The jitter's stated purpose — avoiding a thundering herd when a batch regains connectivity — is the specification ADR-025 §16 was missing. |
| V5, Ch. 5.13 §4 | Retry reuses the same `chunk_id`, deterministic key and multipart upload ID | **Correct.** *"Safe by construction rather than by discipline"* — consistent with ADR-011's key schema. |
| V9, Ch. 9.4 §1 | The six targets it does carry, and the method assigned to each | **Correct.** Four are manual by design; the omissions are A-049. |
| V3, Ch. 3.8 §2 | Single Flutter package, not a Melos-managed monorepo; module boundaries by folder convention and lint rules | **Correct and implemented.** No `melos.yaml` exists. The trigger it names for revisiting — a genuinely separate Admin web app — has not occurred. |
| V3, Ch. 3.8 §4 item 6 | Every dependency carries an explicit version constraint, *"never a bare, unconstrained dependency"* | **Correct and implemented.** All 16 pub packages are caret-constrained; the only unconstrained entries are the two SDK-provided ones. |
| V3, Ch. 3.8 §4 item 4 | MIT, BSD and Apache 2.0 pre-approved | **Correct and satisfied today** — 8 MIT, 5 BSD-3-Clause, 3 Apache-2.0. Nothing re-checks (A-047). |
| V3, Ch. 3.8 §6 | Minimal-surface principle — one package per real need | **Correct and implemented.** One state management library, one HTTP client, one router, one logger, one local database. |
| V9, Ch. 9.4 | Six measurable performance targets, four measured manually and two by in-app instrumentation | **Correct.** The absence of an automated performance test is therefore by design, not a gap; the instrumentation and the manual procedures are what is owed (ADR-029). |
| V9, Ch. 9.6 §1 | What gets a unit test — every use case, every repository's error paths, every notifier's state transitions via `ProviderContainer` overrides | **Correct**, and unexercised: `lib/features/` is empty, so no use case or notifier exists. |
| V9, Ch. 9.7 §1 | Five end-to-end flows, each against a fake backend rather than staging | **Correct.** All five depend on features that do not exist; `integration_test` is not installed (A-028). |
| V6, Ch. 6.4 §4 | Repository providers are designed to be overridden with a fake in tests | **Correct and adopted** as the default substitution mechanism by ADR-029. |
| V9, Ch. 9.1 §3 | *"No untested error path ships"* — a new failure mode adds its test in the same pull request | **Correct.** Enforced by review (`review-checklist.md` §4.4); no mechanism can detect a new failure mode automatically. |
| V9, Ch. 9.2 §5 | Log retention of 90 days matching Volume 8 Ch. 8.7 §1 | **Correct.** A backend CloudWatch log-group policy; creates no mobile obligation. |
| V4, Ch. 4.1 | Backend monitoring and logging is Amazon CloudWatch | **Correct.** `backend/` is empty (ADR-015), so nothing implements it yet. A separate sink from mobile logging, deliberately. |
| V5, Ch. 5.14 §1 | S3 object key schema | **Authoritative and implemented.** Unchanged by any ADR in this cycle. |
| V4, Ch. 4.10 §4 | Standard → Standard-IA → Glacier IR ladder | Correct. Adopted verbatim by ADR-012. |
| V8, Ch. 8.4 | SSE-S3, upgradeable to SSE-KMS only on contractual trigger | Correct and implemented. Not a placeholder — do not "upgrade" without the trigger. |
| V4, Ch. 4.10 §3 | No public access | Correct and implemented. |
| V4, Ch. 4.9 §4 | One bucket per environment | Correct and implemented, at the permitted minimum tier. |
