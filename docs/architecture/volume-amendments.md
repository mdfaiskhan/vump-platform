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

### A-055 — The Firebase refresh token cannot be stored in secure storage, because the SDK does not expose it

| | |
|---|---|
| **Volume** | 6 — Mobile App Architecture, Chapter 6.7 §2 and §3 |
| **Says** | What is stored in `flutter_secure_storage` is *"the Firebase refresh token"*, and *"the `AuthRepository` is the only caller — no feature module reads secure storage directly"* |
| **Should say** | Nothing is stored. The `firebase_auth` SDK persists its own credential in the platform keystore, and the refresh token is not obtainable through the Flutter API on any target platform |
| **Authority** | `firebase_auth 6.5.7`; ADR-008, ADR-034 |
| **Class** | Correction of fact |
| **Status** | Open |

**The plan is not implementable, and the reason is in the package's own documentation.** `User.refreshToken` states: *"This property will be an empty string for native platforms (android, iOS & macOS) as they do not support refresh tokens."* Android, iOS and macOS are every platform this application ships to. There is no value to write.

**The property Chapter 6.7 protects is nevertheless satisfied, by a different owner.** §4 justifies the chapter on the ground that *"the credential that could be used to impersonate a Collector or Admin against the backend is protected at least as strongly as the data it guards access to, using the platform's actual hardware-backed keystore rather than an ordinary file."* The native Firebase SDK persists its credential in exactly that keystore — the Keychain on iOS, Keystore-backed storage on Android. What changes is which code owns the write, not where the secret lands.

**Two consequences follow, and both are visible in the codebase.**

`SecureStorageService` has **no consumers**. It was built in Mission 0.7 for this purpose and every other candidate secret has since turned out to belong elsewhere. It is not dead by accident and should not be deleted on that reasoning alone — but nothing reads it today, and Chapter 6.7 §2's *"Nothing else, by design"* means nothing is queued behind it either.

**ADR-008's startup consequence still holds, for a different reason.** It records that *"the session cannot be known synchronously before `runApp`"* because secure storage is asynchronous. That remains true: resolving the session is asynchronous because `restoreSession` is, not because a Keychain read is. Mission 2.5 satisfies it by awaiting the session in the composition root before `runApp`, so the constraint is discharged rather than inherited.

**Chapter 6.7 §3's read-timing rule is followed as written.** *"Only at app cold-start, to attempt silent re-authentication before falling back to the Login screen — not read repeatedly during normal use"* describes exactly what `_restoreSession` does in `main.dart`. Only the storage mechanism named in §2 is wrong.

---

### A-056 — The invite code becomes optional, and Login links to sign-up

| | |
|---|---|
| **Volume** | 1 — Product Planning, Ch. 1.6 `FR-AUTH`; Volume 10 — Deployment, Ch. 10.4 §4; Volume 2 Ch. 2.4 `SH-02` |
| **Says** | Accounts are *"provisioned by the client organization, not public self-signup"*, and the login screen has no Sign Up option *"since there deliberately isn't one (FR-ADM-07)"*. **A-051** then made self-signup a product decision, but kept an organisation invite code as the thing that admits a person |
| **Should say** | Self-signup needs no invite code. Without one an account joins a single default organisation as a Collector; with one it joins that code's organisation, exactly as before. Login links to sign-up |
| **Authority** | Project owner's decision, 2026-08-14 |
| **Class** | Requirement change |
| **Status** | Open |

**The reason is distribution, and it is worth stating rather than implying.** Volume 1 specified enterprise onboarding for multiple client organisations, and A-051's invite code was the mechanism that made a person's organisation known at the moment they joined. The project's actual distribution today is informal APK sharing among a small trusted group — confirmed by the project owner. There is one organisation, everybody in it is trusted, and a code that everybody already has is a step that admits nobody it would otherwise exclude.

**This supersedes the invite-code half of A-051, not the whole of it.** A-051 remains the record that self-signup exists at all against Volume 10's *"there deliberately isn't one"*. What changes is that the code stops being the gate and becomes an optional way to say which organisation.

**Sign-up is now linked from Login, reversing Mission 2.7's decision** — and reversing it on its own terms rather than despite them. That decision routed `/signup` without a visible link because Volume 10 Ch. 10.4 §4 frames the absent Sign Up option as something to explain to an App Store reviewer, and an unadvertised route kept that framing literally true. A build shared as an APK among known people is not submitted to App Review, so the reasoning does not reach this distribution model. If the app is later submitted to a store, this entry is where to look: the link is the thing to reconsider, not the sign-up flow beneath it.

**The role stays hard-locked to Collector, and this amendment does not touch it.** Stated explicitly because it is the one security property that has to survive the relaxation. Every self-signup path — code or no code — sets `role: 'collector'` at a single site in the redemption function. There is no request field, no branch and no configuration that can produce an admin, and no invite code grants one. **Admin remains a manual bootstrap performed outside the application**, exactly as before.

**A default organisation needs no structure, and none is invented.** `org_id` is consumed in exactly two ways today: as an opaque string on the `User` entity, and as an equality comparison in `firestore.rules` (`request.auth.token.org_id == request.resource.data.orgId`). No `orgs` collection exists, nothing looks an organisation up, and no code reads it as a structured record. A literal constant is therefore sufficient, and creating a Firestore document to represent an organisation nothing queries would be structure ahead of need. When a real organisation model arrives — Volume 4 Ch. 4.4's `users` table is where it belongs — the constant becomes a row and this entry records what it stood in for.

**What this costs, recorded rather than discovered later.** Anyone who obtains the APK can create a Collector account and reach the Collector experience. That is the intended consequence of the owner's decision, not an oversight: the backend re-derives authorization on every request (Volume 4 Ch. 4.8 §1), a Collector sees only their own assigned Tasks (BR-19), and no Task is assigned to a new account by default. The exposure is the Collector shell with nothing in it. It stops being acceptable the moment the app is distributed beyond a trusted group, which is the same trigger as the App Review point above.

### A-057 — Wide-angle eligibility is a sixth checklist item, ~~cached per device rather than re-run live~~ cached only where the cache can answer exactly

> **Corrected 2026-08-15 by Mission 3.10's register audit.** The title and §"Should say" below claim the verdict is *"decided once per install and cached, not re-run before each session like the other five."* **That is no longer true, and on the project's primary platform it is never true.**
>
> Mission 3.8 found that `WideAngleEligibilityCache` stores a `WideAngleTier` and nothing else, which cannot express a Tier 2 verdict: the ladder resolves `primarySensorZoom` to 0.5 on a device that reaches 0.5 and to 0.6 on one that stops at 0.6, and the stored tier is identical in both cases. Reconstructing a factor from it would hand a 0.5-capable device 0.6 on every session after its first — exactly what Chapter 5.2 §2 forbids.
>
> So `checklist_notifier.dart:250` returns null for a cached `primarySensorZoom` and **the probe re-runs every session**. Because Android can never answer Tier 1 (`lensType` is always `unknown`, per the table below), **every Android device is Tier 2 and therefore re-probes on every checklist run** — including the CPH2707, the only handset this project tests on.
>
> What survives unchanged: the item is still checklist-visible, still blocks per FR-CHK-05, and is still cached exactly where the cache is lossless — Tier 1 (always `zoomFactorOptical`) and `unsupported` (no factor). What is wrong is the unqualified claim that it is not re-run per session.
>
> The cost is a camera open before every session on most devices, which is the shutter delay this amendment argued against. The fix is to store the factor beside the tier, which changes a port and a persisted format committed in Mission 3.1. Recorded in **A-064 §6** and not taken.

| | |
|---|---|
| **Volume** | 1 — Product Planning, §5 (FR-CHK-01 … FR-CHK-05); Volume 5 Ch. 5.1 §3 "Interaction With the Checklist"; Volume 3 Ch. 3.1 (mobile stack, Camera & Capture row) |
| **Says** | The Pre-Recording Checklist has **exactly five** items, and every one is a live pre-flight check performed *"before recording starts"*: permissions (FR-CHK-01), free storage (FR-CHK-02), battery (FR-CHK-03), network (FR-CHK-04), and blocking with a remedy message when any fails (FR-CHK-05). Volume 5 Ch. 5.1 §3 discusses only permission and the BR-04 gate. Volume 3 Ch. 3.1 lists the camera stack as *"Flutter's official camera plugin, with a platform-channel extension for ultra-wide lens selection"* and defers the approach as *"an open engineering risk carried into Volume 6, not resolved here"* |
| **Should say** | The Checklist has **six** items. Wide-angle capability (Volume 5 Ch. 5.1 §2's Tier 3) is checklist-visible and blocks recording exactly as FR-CHK-05 requires — but it is **decided once per install and cached**, not re-run before each session like the other five. Volume 3 Ch. 3.1's engineering risk is now **resolved in part and confirmed in part**: reachable on iOS through the plugin, and requiring the platform channel on Android |
| **Reason** | Two independent reasons, one from the volumes and one from the platform |

**The Volumes already require the caching; they just require it somewhere else.** Volume 5 Ch. 5.2 §2 states that *"zoom factor selection (0.5x vs. 0.6x) is a fixed per-device-model decision made once at first launch and cached — not re-negotiated every session — so footage from the same device is always comparable to itself over time."* That decision **is** the Tier 1/2/3 verdict — the ladder is what produces the factor. So a checklist item that re-ran it live would contradict Ch. 5.2 §2 directly. This amendment does not introduce caching; it records that the cached decision is the same decision the Checklist has to display, and that FR-CHK's enumeration never accounted for an item of that shape.

**The other five checks measure things that change between sessions.** Battery drains, storage fills, permissions get revoked in Settings, connectivity comes and goes — each must be read at the moment recording starts or the answer is worthless. Wide-angle capability is a property of the hardware. It cannot change while the app is installed, and re-deriving it costs a camera open (below), so re-running it live would be slower, no more correct, and in conflict with Ch. 5.2 §2.

**Invalidation is by app version and OS version, not by a clock.** A verdict does not decay with age; it becomes wrong only when the code that produced it changes or the platform that answered changes. Both arrive as a version bump, so both are the trigger, and nothing else is.

**Probing costs a camera open, which is why this is correctness and not caching-as-optimisation.** Tier 2 reads the sensor's minimum zoom factor, and on Android that value comes from CameraX's `ZoomState`, which exists only once a camera is bound. So the probe must open the camera — after the Checklist has confirmed permission (Ch. 5.1 §3, BR-03), never before. A per-session probe would put a visible shutter delay in front of every recording and would risk two sessions on one device disagreeing about its own zoom factor, which is precisely what Ch. 5.2 §2 forbids.

**Volume 3 Ch. 3.1's engineering risk, now measured rather than anticipated.** Read from the packages, not assumed:

| Tier | iOS (`camera_avfoundation 0.10.2`) | Android (`camera_android_camerax 0.7.4+5`) |
|---|---|---|
| 1 — dedicated ultra-wide lens | **Reachable.** The discovery session includes `.builtInUltraWideCamera` and maps it to `CameraLensType.ultraWide` | **Not reachable.** `availableCameras()` constructs every `CameraDescription` without a `lensType`, so it is `CameraLensType.unknown` on every device whatever the hardware — zero occurrences of `lensType` in the package |
| 2 — primary sensor zoom-out | Effectively not: `minimumAvailableZoomFactor` is relative to the selected device, and iOS reaches ultra-wide by selecting the ultra-wide device instead | **Reachable.** `getMinZoomLevel()` returns CameraX `ZoomState.minZoomRatio`, which goes below 1.0 on devices whose bound logical camera includes an ultra-wide |

Each platform answers exactly the tier the other cannot. **The platform-channel extension Ch. 3.1 named is therefore confirmed necessary, and confirmed necessary on Android only** — which is the primary test target (Volume 0 Ch. 0.2). It is not built by this mission and is recorded as open.

**What the Android gap costs until that channel exists, decided by the project owner rather than inferred.** Tier 1 is represented as a **tri-state** — true, false, or null for *"the platform cannot say"* — and null is never collapsed into false. The ladder falls through an indeterminate Tier 1 to Tier 2, and **Tier 3 fires only on a positive Tier 2 failure**: a device that reported its minimum zoom factor and could not reach 0.6x. "We could not look" is not evidence of absence, and Tier 3 hard-blocks a Collector from working at all.

Two consequences follow, both accepted:

- **Tier fidelity is lost on Android.** A phone with a real ultra-wide lens is reported as `hybrid` rather than `optical`, because its Tier 1 answer is unavailable and its Tier 2 answer is affirmative. **The footage is unaffected** — the zoom factor is measured, not assumed, so BR-02 holds either way. Only the metadata's account of *how* the field of view was reached is imprecise. The platform channel closes this without changing the ladder.
- ~~**One false-block case remains.** An Android device that has an ultra-wide lens but whose bound camera will not report a minimum zoom factor at or below 0.6x is blocked at Tier 3, wrongly. This is the residue of the same gap and is the strongest argument for prioritising the channel.~~

  **Corrected 2026-08-15, on evidence from the first physical device tested.** The framing above is wrong in its central claim. The false block is **not a residue of the Tier 1 gap** and has nothing to do with whether a dedicated ultra-wide lens can be detected. It fires on any device whose reported zoom minimum widens across a permitted-factor boundary, and it fired immediately.

  A CPH2707 (Android 16) reports a minimum zoom ratio of exactly `0.6f` — a device that satisfies BR-02 precisely. CameraX's `ZoomState.minZoomRatio` is a Java **float**, and widening it to a Dart `double` yields **0.6000000238418579**, greater than 0.6 by 2.38e-8. The ladder's `minimum <= 0.6` comparison therefore failed, and a fully compliant phone was refused with *"This device doesn't support the required wide-angle capture"*.

  So the original entry understated this in both frequency and cause: not a narrow edge case behind an Android-only detection gap, but a defect reachable by any device sitting on a permitted factor — likely a large share of the fleet, since 0.5x and 0.6x are exactly the values BR-02 names and exactly the values hardware reports.

  Fixed at the data boundary — `CameraCapabilityProbeImpl` normalises the platform value to six decimal places before it reaches `domain/`, so the ladder's comparison stays an ordinary `<=` that reads the way BR-02 is written. The ladder itself was not modified.

- **What this says about the test suite, recorded because it will be asked.** 299 tests passed over this code, including a table covering the 0.6 boundary, and none of them could have caught it. Every test fed the ladder clean decimal literals — `0.5`, `0.6`, `0.55` — which are the values a Dart author writes and *not* the values a platform channel delivers. The defect lives entirely in the gap between those two, so no unit test written in Dart could reach it.

  It was found by the throwaway on-device harness of Mission 3.1.5, on the first real device the ladder had ever run against, minutes after the Android build was first made to work.

  **The general lesson, stated plainly for whoever reads this later: a value that crosses a platform channel cannot be verified by unit tests alone.** Its representation is decided on the other side of that boundary, by a language with different numeric types, and no amount of Dart-side coverage observes it. Any future capability read of this shape needs a real-device check before its verdict is trusted — which is now also the argument for prioritising the physical-device verification recorded as open against Mission 3.11.

**BR-02 is never violated in either direction.** The reported minimum is snapped to the nearer of the two factors BR-02 permits, and a device wider than 0.5x is clamped rather than given its extra reach — fleet comparability is BR-02's own stated rationale, and one unusually wide device defeats it.

**Volume 5 Ch. 5.1 and 5.2 are not edited.** Both are `Status: Draft — Pending Approval`, and both are PDFs in `docs/volumes/` rather than editable Markdown. This register is the correction, in the same way an Accepted ADR is corrected in place rather than rewritten. The specific sentence this amendment reaches is Ch. 5.1 §3's "Interaction With the Checklist", which discusses permission and the BR-04 gate and does not mention that the wide-angle verdict is also checklist-visible or that it is cached.

**No new ADR.** This extends Volume 5.1's existing decision rather than taking a new one; the ladder, the tiers and the caching are all the Volume's, and nothing here creates an architectural pattern the accepted ADRs do not already cover. The cross-feature question was checked and does not arise: probe, ladder, cache and the Checklist screen that consumes them are all `features/recording/`.

### A-058 — Chapter 5.4's pipeline stages are the camera plugin's internals, not this project's code

| | |
|---|---|
| **Volume** | 5 — Recording Engine, Chapter 5.4 §1 (Pipeline Stages) and §2 (Backpressure & Storage Checks) |
| **Says** | §1: *"Camera Module (5.1) → Hardware Encoder (5.2 params) → Muxer (video+audio → .mp4 container) → Buffered Writer → Local Filesystem (5.8)"*, with the encoder *"never a software encoder"* and *"a buffered writer flushes to the device filesystem periodically (not only at Stop) so that a crash mid-chunk loses at most the last buffer interval"*. §2: *"the buffered writer monitors remaining free space on every flush"* |
| **Should say** | The stages are real and happen in that order, but **inside CameraX's `Recorder`** — they are not stages this project builds, wires or can observe. The free-space check is driven by a timer, because there is no flush to hang it on |
| **Reason** | Volume 3 Chapter 3.1 already chose the stack, and that decision outranks a Draft chapter's implementation detail |

**The architecture decision was taken three chapters earlier.** Volume 3 Ch. 3.1's mobile stack table fixes capture as *"Flutter's official camera plugin, with a platform-channel extension for ultra-wide lens selection"* — a plugin, with a channel for **one** named gap. Chapter 5.4 then describes an encoder/muxer/writer chain as though the application owned those stages. It does not, and cannot: the plugin exposes `startVideoRecording()` and `stopVideoRecording()` and nothing between them. Its controller has **no flush, buffer, segment or split API of any kind** — verified by grep against `camera 0.12.0+2`, zero matches.

Building the chain literally would mean writing a MediaCodec/MediaMuxer bridge, which is not the extension Ch. 3.1 sanctioned, would be Android-only, and would reverse Volume 3's own stack decision from inside a downstream chapter. **When an architecture decision and a Draft-status chapter's implementation detail conflict, the decision wins and the chapter is corrected** — the same relationship A-057 established for Ch. 5.1 and 5.2.

What the chapter promises *observably* is delivered: a real-time mux to `.mp4`, incremental writing rather than a single flush at Stop, and one complete independent file per chunk. Those are properties of CameraX's `Recorder`. What changes is who guarantees them.

#### Two guarantees become unverifiable. **Both are OPEN RISKS, not resolved.**

**1. "Never a software encoder" — unverifiable, and not certain to hold.**

This is the more serious of the two and it is not merely a measurement gap. CameraX selects the encoder itself, and **it can fall back to a software encoder** on some devices and configurations. Nothing in the Dart API reports which was used, so the application cannot detect it, cannot refuse it, and cannot log it.

The chapter's stated reason for demanding hardware encoding is battery and thermal load across back-to-back 10-minute sessions. A silent software fallback would degrade both, and — for a business whose product *is* the footage — could degrade capture quality on an unknown subset of the fleet without any signal that it happened. **This is recorded as an accepted unknown, not a solved problem.**

**2. The flush interval is unobservable and unconfigurable.**

§1 promises a crash loses *"at most the last buffer interval"*. CameraX does write incrementally, so the shape of the promise holds — but its size is not ours to set, measure, or state. The crash-recovery behaviour Ch. 5.3 §5 builds on this is therefore bounded by a number nobody in this project knows.

#### §2's free-space check is timed, not flush-driven

With no flush hook, the check runs on a `Timer.periodic` at **5 seconds**. At Ch. 5.2 §1's bitrate — 8,000 kbps video plus 128 kbps audio, about 1.02 MB/s — that is roughly 5 MB written between checks, and `StatFs` is a single syscall. The chapter's *intent* (notice before the disk fills) is preserved; its *mechanism* is not available.

**The threshold is 610 MB, derived rather than invented.** FR-CHK-02 gates recording on *"sufficient free local storage for at least one full chunk"*, so one full chunk is the unit the product already reasons in, and the mid-recording rule reuses it — the pipeline never allows less headroom than the Checklist demanded before it started. One chunk at spec bitrate is (8,000 + 128) kbps ÷ 8 × 600 s = 609.6 MB, rounded to 610 MB.

**The early boundary reuses Chapter 5.3's existing pattern, exactly as §2 instructs**: *"the pipeline forces an early chunk boundary (treated exactly like the automatic 10-minute boundary, Chapter 5.3)"*. Same `ChunkBoundaryReason`, same edge, same finalization path. No new mechanism and no new enum case.

#### The project's first `MethodChannel`

`dart:io` exposes no free-space API, so reading it requires something native. A platform channel was chosen over a pub package, on the reasoning ADR-030 applies to packages:

- The two maintained candidates — `disk_space_2` (22,499 downloads/30 d, 150/160 points, built-in Kotlin) and `storage_space` (5,320 downloads, applies KGP at Kotlin 1.8.22) — **both return megabytes computed through a 32-bit float division**. This project shipped a defect days earlier caused by trusting a float32 across exactly this boundary (A-057's correction). The channel returns `Long`/`int` bytes end to end, with no floating point anywhere in the path.
- `storage_space` measures `Environment.getDataDirectory()`, a fixed partition, rather than the volume actually being written to.
- A package carries ADR-030's full admission — confinement entry, inventory row, conversion boundary, Volume record — for roughly twenty lines of platform code.
- The precedent is A-055's sibling reasoning and Mission 3.1's choice of `dart:io`'s `Platform.operatingSystemVersion` over `device_info_plus`. Ch. 3.1 already sanctions platform channels by name.

It is confined the way ADR-030 confines a package even though no package is involved: one Dart file owns it, `PlatformException` and `MissingPluginException` are both converted there, and the only types crossing are a `String` in and an `int` out.

**Android is verified on hardware.** On a CPH2707 the channel returned **86,695,772,160 bytes** for the app documents directory; the OS's own `df` reported 86,699,048,960 bytes for `/data` — a 0.004% difference, consistent with `StatFs.availableBytes` excluding reserved blocks. A non-existent path was rejected as `StorageException`, not as a raw platform type.

**The iOS half has never executed.** No Mac, no iOS device, no iOS configuration in this project. It uses `volumeAvailableCapacityForImportantUsageKey` — Apple's recommended key, which accounts for purgeable space, rather than the cruder `volumeAvailableCapacity` that would under-report and force early boundaries on a device with room. That is a reasoned choice, not a tested one.

#### The zoom write-back, carried from Mission 3.1.6 and now closed

3.1.6 flagged a hazard: the pipeline would call `setZoomLevel(0.6)` on a device whose platform floor reads 0.6000000238418579, fractionally higher, and CameraX might reject it. **Measured on the CPH2707, it does not.** `setZoomLevel` accepted 0.6, accepted the raw minimum, and also accepted **0.3 — half the reported floor.** That platform performs no range validation at all, so there was never a rejection to avoid.

That inverts the risk rather than removing it: an out-of-range value produces no error, no exception, and silently wrong footage. The only defence is not to compute one.

The pipeline therefore sends `max(verdictFactor, platformMinimum)`, reading the minimum from **its own controller binding** rather than the cached verdict. One expression covers two cases: a verdict of 0.5 on a device whose floor is 0.25 stays 0.5 (the ladder clamped deliberately, because fleet comparability is BR-02's rationale), and a verdict of 0.6 on a device reporting 0.6000000238418579 sends the platform's own number.

**This is belt-and-braces, not load-bearing.** On Android it changes nothing. It is kept because iOS *does* clamp `videoZoomFactor` to its available range, so a validating device is protected — and because it costs one comparison. **No change was needed to `CameraCapability` or to any code committed in 3.1 or 3.2**: the pipeline reads the floor from the controller it is about to configure, so the raw value never had to be retained.

#### Follow-up: the Volume 9 device matrix

Three items from this amendment need real hardware and cannot be closed from the repository. They belong with Volume 9 Ch. 9.8/9.9's manual and device-matrix testing:

1. **Encoder spot-check** — confirm on real devices whether CameraX selected a hardware encoder, by inspecting the produced file's encoder metadata or `MediaCodecInfo`. The only way this is ever settled either way.
2. **Crash-interval measurement** — kill the app mid-chunk and measure how much footage is actually lost, giving §1's "at most the last buffer interval" a number.
3. **The iOS free-space channel** — first execution of that branch on any Apple device.

### A-059 — Chapter 5.5 §2 charges the checksum to a budget NFR-META-01 does not cover, and the real cost raises a product question

| | |
|---|---|
| **Volume** | 5 — Recording Engine, Chapter 5.5 §2; Volume 1 §11 (NFR-META-01); Volume 2 Chapter 2.7 (C-10) |
| **Says** | *"NFR-META-01 (Volume 1) caps metadata generation at under 500ms of added overhead per chunk. **Checksum computation is the dominant cost here**, so it is streamed and runs on a background isolate/thread separate from the UI, so **the brief Local Processing state** (C-10) reflects genuine progress rather than blocking the main thread."* |
| **Should say** | NFR-META-01 caps **metadata generation**, which is Chapter 5.7's work, measured as overhead *added to* finalization. The checksum is part of finalization and is therefore part of the baseline, not part of the 500 ms. And it is not brief: measured at roughly **12.3 seconds** for a full chunk |
| **Reason** | The chapter misreads its own citation, and the real number contradicts the word "brief" |

**What NFR-META-01 actually says**, from Volume 1 §11 — *"Metadata Integrity (New)"*:

> **NFR-META-01** — Metadata generation for a chunk shall not measurably delay chunk finalization. — *< 500ms added overhead per chunk*

The subject is **metadata generation**, and the measure is overhead *added to* chunk finalization. Chapter 5.5 §2 folds the checksum into that cap by calling it *"the dominant cost here"*, but §1.1–§1.3 place the checksum inside finalization itself. Finalization is the thing the 500 ms is added *to*. Read correctly there is no contradiction and no violated requirement — but read as written, the chapter sets a budget the checksum was never inside and could never meet.

**~~"the brief Local Processing state"~~ — measured, and struck through 2026-08-15.**

Pure-Dart SHA-256 over a file, streamed in blocks exactly as §1.2 requires:

| Sample | Time | Throughput | Extrapolated to 610 MB |
|---|---|---|---|
| 200 MB, run 1 | 4,151 ms | 48.2 MB/s | **12,661 ms** |
| 200 MB, run 2 | 4,016 ms | 49.8 MB/s | **12,249 ms** |

610 MB is one full 10-minute chunk at the Chapter 5.2 §1 bitrate, derived in A-058. **These figures are from desktop hardware**, measured when the test handset was disconnected. A phone will be slower, not faster, so ~12.3 s is a floor rather than an estimate. Re-measuring on the CPH2707 is recorded below.

The §2 requirement that the work run on a background isolate is therefore **load-bearing, not precautionary**, and is implemented that way.

### The open PRODUCT question — not an engineering follow-up

**Will a Collector accept a 12-second-plus Local Processing state at every automatic chunk boundary?**

This is stated separately from the engineering list on purpose. Nothing is broken and no requirement is violated; the code does what Chapter 5.5 specifies. What is unresolved is whether the resulting experience is acceptable, and that is a judgement about the product, not about the implementation.

The shape of it: a session longer than ten minutes crosses a boundary automatically (BR-06), the Collector did not ask for it and cannot avoid it, and C-10 appears each time. An hour-long walkthrough crosses five boundaries. Volume 2 Chapter 2.7's C-10 and Chapter 5.5 §2 both describe this state as *brief*, which was written before anyone had measured it.

**This needs a decision from the project owner, not a ticket.** The engineering options are known and none is chosen here:

- **Accept it.** The work is off the UI thread and the screen can show real progress. Recording is not blocked; only the transition is visible.
- **Make it fast.** A SHA-256 platform channel over Android's `MessageDigest` and iOS's `CryptoKit` would use hardware SHA extensions, plausibly one to two orders of magnitude quicker. **This is deliberately not built.** It would be the project's second `MethodChannel` and its second untestable iOS half, and building it before anyone has said the duration matters would be optimising against a number nobody has objected to. The remedy is identified and available; it is not scheduled.
- **Hide it.** Let finalization proceed in the background while the Collector returns to the Task list, showing chunk state in the upload queue instead. This is the largest change and reaches into Chapters 5.3 and 5.9, so it is named only for completeness.

### How often C-10 appears — decided 2026-08-15

~~**Decision: C-10 is shown only when `Finalizing.reason == collectorStop`.**~~ **Field renamed 2026-08-15 — see below.** Automatic chunk boundaries are invisible to the Collector.

**Corrected 2026-08-15 (Mission 3.4.5.1).** `Finalizing.reason` no longer exists. Mission 3.4.5 removed it, on the assumption that `Finalizing` meant "the Collector stopped" — which stopped being true in the same change, because a capacity-forced end also lands there.

**The rule now reads: show C-10 when `RecordingState.sessionEndCause == SessionEndCause.collectorStop`.** The decision is unchanged; only the field it branches on is. `SessionEndCause` is carried on both `Finalizing` and `Idle`, so the check works during the drain and after it.

So the duration above is a **once-per-session** cost, not a five-or-six-times-an-hour one. That materially lowers the pressure behind the product question above, and it is the reason the native SHA-256 channel stays unbuilt.

**Why this was undecided until now — a Volume 2 / Volume 5 reconciliation gap.** Volume 2 describes C-10 three times and none of them distinguishes an automatic boundary from a manual Stop:

- The screen inventory: *"C-10 Local Processing — Brief transient state while chunking + metadata generation run **after Stop**."*
- Chapter 2.7 §4.1: *"Local Processing (C-10, **the gap between Stop and the chunk being ready**)…"*

Both are satisfied by either reading, because Chapter 5.3 §1 makes the automatic boundary *"identical in every way to a manual Stop"*.

The Collector flow explains the silence. Its steps 9–11 run Stop → Local Processing → Upload as a single linear pass, and step 10 reads *"Local Processing — **Automatic Chunking** + Metadata Generation"* — placing chunking **inside** Local Processing, after the recording has ended.

**That is the design Chapter 5.4 §3 explicitly rejected:** *"An alternative design would record one long file per session and slice it into 10-minute segments afterward. This was rejected."* Volume 2's flow still describes the pre-rejection model, in which there is exactly one finalization per session and the question could not arise. Volume 5 replaced that model with the internal-Stop pattern, creating one `Finalizing` per chunk, and C-10 was never revisited.

The decision costs nothing to implement: `RecordingStateFinalizing` already carries `reason` (Mission 3.2), so Mission 3.8 branches on a field that exists rather than needing new state.

**Volume 2 Chapter 2.7 §4.1 carries the same NFR-META-01 misreading corrected above** — *"NFR-META-01 budgets it at under 500ms"* — for the same reason, and is corrected by the same argument.

### The capture gap — HIGHER PRIORITY than the UI question, and NOT resolved here

**`isCapturing` is false for the whole of every automatic `Finalizing` — roughly 12 seconds, every ten minutes — so the camera is not recording during it.**

This is a separate problem from C-10 and a more serious one. The decision above hides the boundary from the Collector; it does nothing about the gap itself. A Collector walking through a site keeps walking, and that footage does not exist.

It matters more here than it would on most products. Volume 5's whole premise is a continuous egocentric walkthrough at a fixed wide-angle field of view (BR-01, BR-02), and the output is training data. A periodic, silent, unavoidable hole in the record is a data-quality defect, not a UX inconvenience — and because the boundary is system-triggered (BR-06), the Collector cannot work around it or even know it happened, least of all once C-10 is hidden for automatic boundaries.

The gap follows from two decisions that are each individually correct. BR-05 forbids mid-stream slicing, so a chunk boundary must be a real Stop; and BR-07 requires a chunk be fully persisted before anything proceeds, which is what the machine waits for. Neither should be reversed to close this.

~~**This needs its own architectural decision and does not get one here.** The question to answer is whether a new capture session may begin before the previous chunk's finalization completes — for example by starting the next recording as soon as the file handle is closed and letting checksumming proceed in parallel, rather than serialising finalization ahead of the next chunk. That reaches into Chapters 5.3, 5.4 and 5.5 together, changes what `Finalizing` means in the lifecycle, and may not be achievable with a single `CameraController` at all.~~

~~Recorded now, unresolved, and deliberately not designed inside an amendment.~~

### Corrected 2026-08-15 — the gap is not what the paragraphs above say it is

**This supersedes the framing above rather than replacing it.** The original text is committed in `390c170` and is left struck through, in the same way an Accepted ADR is corrected: it was wrong in a way worth being able to find later.

**Two things it got wrong.**

**The ~12 seconds is checksum time, not camera-blocked time.** It was attributed to the camera being unavailable throughout `Finalizing`. It is not. By the moment `stopVideoRecording()` returns, the moov atom is written, the file handle is closed, the file is fully persisted on disk, and CameraX has unbound the `videoCapture` use case. **The camera is free at that instant.** What follows is Mission 3.4's SHA-256 running while Mission 3.2's lifecycle holds the machine in `Finalizing` before re-entering `Recording`.

**And that serialisation is this project's choice, not the plugin's constraint — and it is stricter than BR-07 requires.** BR-07 reads *"Every chunk shall be persisted to local storage before any **upload** of that chunk begins"*. It governs upload, not the next recording. Chapter 5.3 §2's diagram labels the edge `chunk persisted + queued (BR-07)` and gates chunk N+1 on it, but persistence has already happened at `stopVideoRecording`; only queueing has not.

**What was investigated, and what the plugin actually forbids.** Overlapping capture sessions are genuinely impossible here, confirmed in `camera_android_camerax 0.7.4+5`'s source rather than inferred:

- `startVideoCapturing` opens with `if (recording != null) { /* There is currently an active recording, so do not start a new one. */ return; }`, and `recording` is cleared only after `stopVideoRecording` awaits `VideoRecordEventFinalize`. There is no window in which two recordings coexist.
- Two `CameraController`s would not help: `CameraPlatform.instance` is a single static instance and `AndroidCameraCameraX` holds `videoCapture`, `recorder`, `pendingRecording` and `recording` as fields on it, so two controllers share one mutable object. Beneath that, the Android camera device is exclusive.

**But overlap is not what closing the gap requires**, which is why the question as originally posed had no useful answer.

**The real residual gap** is one use-case bind cycle: `stopVideoRecording` (write moov, close, unbind `videoCapture`) followed by `startVideoRecording` (re-bind `videoCapture`, `prepareRecording`). **Unmeasured** — the test handset was disconnected — but a bind cycle rather than a 610 MB hash, so plausibly sub-second. *That* residue is structural under this plugin and cannot be removed without a native path.

**One detail that makes the gap worse than it sounds.** `stopVideoRecording` unbinds only `videoCapture`; the **preview use case stays bound**. The screen does not go black, so the Collector sees live camera throughout and has no cue that capture has stopped — which compounds the decision above to hide C-10 at automatic boundaries.

### The fix, and Mission 3.4.5

**Restart capture immediately after `stopVideoRecording()` returns, and run checksumming, metadata generation and upload queueing concurrently against the already-closed file.** Same controller, sequential camera calls, no unsupported API, and no reversal of BR-05 or BR-07.

**Scoped as its own sub-mission, 3.4.5, to run before Mission 3.8.** Not implemented here — it changes committed behaviour in Mission 3.2 and deserves its own trace-and-decide pass rather than an amendment's closing paragraph.

Mission 3.3's pipeline needs little or no change: `stopChunk()` and `startChunk()` are already separate calls on a persistent controller. Mission 3.4's processor needs none — it already runs on an isolate and takes a path. **The work is Mission 3.2's.** `RecordingLifecycle.onChunkPersisted` currently means "finalization finished, resume", and it would split into two independent facts — capture restarted, and chunk processed. The machine would be recording chunk N+1 while chunk N is still processing, which the current four states cannot express.

**Three problems 3.4.5 must resolve**, none of which the current design has an answer for:

1. **Failure attribution.** Chunk N's checksum fails while chunk N+1 is recording. Mission 3.2's parked-`Finalizing` dead end currently stops the whole machine, but with overlap there is a live recording that should not necessarily stop. Where that failure surfaces, and what it stops, is undesigned.
2. **Concurrency bound.** Boundaries arrive every 600 s and processing takes roughly 12 s, so queueing is not a practical risk — but nothing would enforce it, and a slow device plus a low-storage forced boundary (Chapter 5.4 §2) could stack them.
3. **Ordering against `sequence_index`.** Chapter 5.6 §2 increments it *"once per Finalizing transition"*. With overlap, increment timing and processing-completion order diverge, and the S3 key is deterministic and UNIQUE on that index (Chapter 5.14 §1).

**It should still be settled before Mission 3.8 builds a UI on a lifecycle whose timing may change.**

### Recorded for Volume 9's device matrix

Joining the list under A-058:

4. **Re-measure the checksum on the CPH2707** — the desktop figure above is an upper bound on speed and a lower bound on duration. The real number is what the product question should be decided against, and it also sets the true size of the capture gap above.

### A-060 — Chapter 5.6 is already satisfied, and Chapter 5.14 assigns it work it never mentions

| | |
|---|---|
| **Volume** | 5 — Recording Engine, Chapter 5.6 (Video Chunking); Chapter 5.14 §3 (File Naming Strategy) |
| **Says** | Ch. 5.6 states the chunking rules, the sequencing rules and three edge cases. Ch. 5.14 §3 states that *"`chunk_id`: a UUID generated locally the moment a chunk begins finalizing (**Chapter 5.6**)"* |
| **Should say** | Ch. 5.6 is correct and needs no change — every clause in it was implemented by Missions 3.2 and 3.4 before this chapter was read as a mission of its own. But Ch. 5.6 **never mentions `chunk_id`**, so Ch. 5.14 §3 assigns generation to a chapter that does not describe it |
| **Reason** | Two separate findings: a chapter with no remaining work, and a cross-chapter attribution gap |

**This amendment records no defect in Chapter 5.6.** It exists because a mission was opened against the chapter and found nothing to build, and because that outcome is worth being able to find later rather than inferring from an absent commit.

### Chapter 5.6 is fully satisfied by already-committed work

Checked clause by clause against the code rather than assumed:

| Ch. 5.6 clause | Where it is implemented |
|---|---|
| §1 BR-05 — a boundary is always an internal or Collector-initiated Stop, never a slice | `ChunkBoundaryReason` and the internal-Stop pattern — Mission 3.2 (`09e7fbe`) |
| §1 BR-06 — every chunk exactly 10 minutes, final may be shorter | `RecordingLifecycle.chunkDuration` — 3.2 |
| §1 BR-07 — written to local storage in full before reaching the Upload Queue | the notifier awaits `ChunkFinalizer` before taking the edge — 3.2; checksum after finalization — Mission 3.4 (`390c170`) |
| §2 — `sequence_index` starting at 0 | `RecordingLifecycle.firstSequenceIndex` — 3.2 |
| §2 — incremented once per Finalizing transition | `onChunkPersisted`, and nowhere else — 3.2 |
| §2 — `session_id` generated once at session start, never re-created by chunking | `SessionIdGenerator` on the Checklist edge — 3.2 |
| §3 — a very short final chunk is valid; no minimum duration | 3.2, asserted in `recording_lifecycle_test.dart` |
| §3 — the automatic timer is cancelled the instant a manual Stop begins finalization | 3.2, cancelled before the await, with a re-entrancy guard for the already-scheduled callback |
| §3 — app killed exactly at a boundary | **deferred to Mission 3.7**, already recorded — crash recovery needs Chapter 5.8's local storage |
| §4 — metadata record, file naming | deferred to Chapters 5.7 and 5.14 |

The overlap is not coincidental. Chapter 5.6 §3's timer-cancellation rule is stated **only** in this chapter — Chapter 5.3 omits it — and Mission 3.2 implemented it after reading 5.6 alongside its own chapter. §2's sequencing rules are what fixed `firstSequenceIndex` and the placement of the increment.

**Chapter 5.6 §2's `sequence_index` base is confirmed consistent** with the decision recorded in Mission 3.2: the chapter's *"starting at 0 (or 1, matching Volume 4's convention)"* defers to a Volume 4 convention that does not exist, so its stated default stands. The reasoning is in `RecordingLifecycle.firstSequenceIndex`'s documentation and in `09e7fbe`'s message.

### `chunk_id` — the attribution gap

Chapter 5.14 §3 assigns it plainly:

> `chunk_id`: a UUID generated locally the moment a chunk begins finalizing (**Chapter 5.6**) — never reused, never predictable, never assigned by a counter that could collide across devices.

**Chapter 5.6 does not mention `chunk_id` anywhere.** Its §2 "Sequencing" covers `sequence_index` and `session_id` only. So the requirement is real — the S3 object key is `{sequence_index:04d}_{chunk_id}.mp4` (Ch. 5.14 §1) — but it is attributed to a chapter that never describes it.

Same species as A-057 and A-058: a chapter deferring to a section that does not carry what the deferral claims. Recorded rather than silently absorbed, so the next reader of Chapter 5.6 does not conclude the id is generated somewhere they have not looked.

`chunk_id` is **not currently generated anywhere in the codebase** — confirmed by grep, which finds the term only inside a doc comment. Note that it is needed for the S3 key but **not** for the local path, which Ch. 5.14 §2 defines as `{sequence_index:04d}.mp4` with no id.

### Deferred to Mission 3.4.5, deliberately

*"The moment a chunk begins finalizing"* is the `Recording → Finalizing` transition, so the generated id has to be stored on **`RecordingStateFinalizing`** and survive until the chunk is named. Nothing else spans that interval, and no other component observes both ends of it.

That is the same state A-059 already schedules Mission 3.4.5 to restructure for the capture-overlap fix, where `onChunkPersisted` splits into two independent facts and the four-state union may no longer express what it needs to.

**Building `chunk_id` now would mean opening that state twice** — once to add a field, and again weeks later to change what the state means — with the second change landing on top of the first and re-testing the same union. It is folded into 3.4.5 instead.

The two also touch the same key. A-059 records that under overlap *"increment timing and processing-completion order diverge, and the S3 key is deterministic and UNIQUE on that index"*; `chunk_id` is the other component of that key. Deciding both together is more likely to produce a coherent answer than deciding them a mission apart.

**Closed 2026-08-15 by Mission 3.4.5.** `chunk_id` is minted at capture-stop, in the same call that fixes `sequence_index`, and stored on the `ChunkProcessingJob` that carries the chunk until it is named. Generated through a `ChunkIdGenerator` port — `uuid` is still absent from the dependency tree, so no package was added. See A-061.

### A-061 — Capture and chunk processing are separated; Chapter 5.3's Finalizing is redefined

| | |
|---|---|
| **Volume** | 5 — Recording Engine, Chapter 5.3 §2 and §3; Chapter 5.13 §1; Chapter 5.14 §3 |
| **Says** | Ch. 5.3 §2's diagram routes every chunk boundary through `Finalizing` before the next `Recording`, labelling the edge *"chunk persisted + queued (BR-07)"*. §3 defines `Finalizing` as *"the brief Local Processing state (C-10) — video is finalized, metadata is generated, and the chunk enters the Upload Queue"* |
| **Should say** | An **automatic** boundary returns to `Recording` immediately and never enters `Finalizing`; the chunk it just closed is processed in the background. `Finalizing` is entered only by a Collector-initiated stop, and means *the session is draining* |
| **Reason** | The serialisation was this project's, not the chapter's, and it cost roughly twelve seconds of lost capture at every boundary — see A-059's corrected capture-gap section |

**BR-07 is not weakened.** It reads *"Every chunk shall be persisted to local storage before any **upload** of that chunk begins"*, and persistence is complete before this change does anything: `stopVideoRecording()` returns only after `VideoRecordEventFinalize`, so the `.mp4` is closed on disk. What used to happen before the next chunk — checksumming — was never what BR-07 required.

### The state shape, and why there is no fifth state

**Four states, unchanged: `Idle`, `Ready`, `Recording`, `Finalizing`.** Processing is carried as a **field** on the states that can hold it, not as a variant.

The obvious move was a fifth state for "recording while processing". It is wrong because **capture and processing are orthogonal**: what the camera is doing and how many closed files are being hashed are independent facts, so encoding their combination as variants multiplies them — `recordingWithOnePending`, `recordingWithTwoPending`, and so on. A field says the same thing without the product, and keeps Chapter 5.3 §2's four names intact.

**The exhaustive transition matrix moved from four legal edges to five, deliberately.** Mission 3.2 wrote that test specifically to catch an unplanned state addition, so the revision was treated as a signal rather than a chore. What it caught is exactly one change: `onChunkProcessed` is now legal from `Recording` as well as `Finalizing`, because a background job can complete while the next chunk is being captured. The **state count is still four**, and a test now asserts that too.

### Failure attribution — cited, not invented

**A terminal processing failure marks the chunk and leaves the session alone.**

Chapter 5.13 §1 classifies *"Local file missing/corrupted, disk full"* as **Terminal (device-side)**, handled as *"Not retried automatically — surfaces immediately as Failed with a specific, named cause (Chapter 2.9's copy rules)"*. A checksum that cannot be computed is that class of failure, and the chapter puts the outcome on the **chunk**, not the session: a Failed chunk waits for the Collector's Retry (C-11, FR-UPL-07).

Chapter 5.13 is written about upload rather than local processing, so this applies its classification by analogy — stated plainly rather than presented as a direct ruling. Nothing in Volume 5 addresses a pre-upload processing failure explicitly.

The alternative — an emergency Stop of the live recording — was rejected because it destroys footage that is still being captured correctly in order to report footage that is not. That is a strictly worse outcome for a product whose output is the recording.

**This retires Mission 3.2's parked-`Finalizing` dead end.** That behaviour was correct while capture could not continue past a failure; it cannot survive a design where capture already has. The test asserting it said in its own comment that it was *"expected to change when that lands"*, and has been replaced rather than deleted quietly — two tests now assert the new outcome, and one records why the old assertion is gone.

### The concurrency bound — three, and why a bound exists at all

Normal operation has at most one job in flight: a boundary every 600 s against roughly 12 s of processing. That ratio does not justify a cap.

**A different path does.** Chapter 5.4 §2 forces an early boundary whenever free space is critically low, and Mission 3.3 polls that every 5 seconds. A device that stays below the threshold therefore produces a boundary *every poll*, each starting a job that outlives the next two boundaries. Nothing else bounds that, and the condition that triggers it — a nearly-full disk — is exactly when adding more files is most harmful.

At the cap, an automatic boundary is converted into a stop.

### What that means for the Collector, stated plainly

**The session ends. Involuntarily, mid-walkthrough, without them asking.** The camera is released (`closeSession`), the storage watch is cancelled, outstanding chunks drain, and the machine reaches `Idle`. The low-storage boundary is *not* refused or deferred until a slot frees — recording genuinely stops.

**Why a stop rather than a refuse-or-defer, stated precisely so it is not re-derived wrongly.** It is **not** to free disk space, and any future reader tempted by that explanation should stop: BR-08 keeps every chunk on disk until its upload is confirmed, so ending the session frees nothing at all. The actual justification is narrower — a device that is already losing the processing/recording race, on a disk already near its limit, risks an out-of-space write failure corrupting the **in-progress** chunk. Chapter 5.4 §2 forces the early boundary for exactly that reason. A clean forced stop loses the remainder of a session; a corrupted active file loses a chunk and leaves an ambiguous half-registered artefact, which Chapter 5.6 §3 names as the thing to avoid.

**The Collector must be told**, and Mission 3.4.5 originally made that impossible: both endings landed in `Finalizing` and the state recorded neither, so a forced stop was indistinguishable from a chosen one. Corrected by `SessionEndCause`, carried on `Finalizing` and through to `Idle` — the explanation is needed *after* draining, which is when the Collector is looking at a stopped recording. Volume 2 Chapter 2.9 §4.3 requires *"a plain-language cause with a single, specific recovery action"*; the domain now supplies the cause, and Mission 3.8 maps it to copy the way `AuthErrorCopy` maps `ErrorCode`.

**Three is chosen, not transcribed** — no chapter gives a number. One is normal, two is a transient hiccup, three sustained means processing is durably behind capture.

### Identity is minted at capture-stop

`sequence_index` and `chunk_id` are both fixed in the same call, at the moment capture stops, and neither depends on when processing finishes.

**Increment timing and completion timing are now different events**, which A-059 flagged as a risk to the deterministic S3 key. It is not one, and the reason is structural rather than defended: the index is read from the `Recording` state, which exists once per captured chunk, and captures are strictly serial because the plugin permits exactly one recording at a time — `startVideoCapturing` returns early while `recording != null`, and `stopVideoRecording` clears it only after finalization. One capture, one stop, one increment, in order. **No collision and no skip is possible**, and completion order may differ from start order without touching the index. Tests assert contiguity, uniqueness, and that out-of-order completion leaves the index alone.

`chunk_id` closes A-060's deferral. Chapter 5.14 §3 asks for *"a UUID generated locally the moment a chunk begins finalizing"* — the same instant under this design — and Chapter 5.13 §4 requires every retry to reuse *"the exact same `chunk_id`"*, so it is minted once and never recomputed.

**No dependency was added.** `uuid` is absent from the tree entirely, so generation goes through a `ChunkIdGenerator` port, exactly as Mission 3.2 did for `SessionIdGenerator` after the same check.

### No new ADR, and the reasoning rather than the default

Considered, because a tracked set of concurrent background jobs is a pattern this codebase did not previously have. Declined for three reasons: it introduces no new technology, dependency or layer rule; it is confined to one feature, where ADR-001 and ADR-022 already govern placement; and it refines a decision Volume 5 Chapter 5.3 already owns rather than taking a new one.

That makes it an amendment, which is the same instrument A-057, A-058 and A-059 used for the same relationship. An ADR would be right if this became a cross-feature convention — for example if the Upload Queue adopted the same shape — and that is the trigger to revisit.

---

### A-062 — Chapter 5.7's metadata cannot be completed by this application yet, and two of its clauses conflict

| | |
|---|---|
| **Volume** | 5 — Recording Engine, Chapter 5.7; Volume 4 Chapter 4.5 §2 (the schema it defers to); Volume 1 §11 (NFR-META-01) |
| **Says** | Ch. 5.7 §2 names a source for every field group, and §3 requires the assembled object be written *"to the local Drift `chunk_metadata` table … in the same transaction as the chunk's own local record"* |
| **Should say** | Nine of the twenty-one fields have no source in this application, one field group cannot be read within the budget another requirement sets, and §3 names an engine this project does not use and a layer that does not exist |
| **Reason** | Four separate gaps, none resolvable inside this mission |

**Twelve of twenty-one fields are sourced** and are implemented: `chunk_id`, `identity.session_id`, all of `timing`, all of `capture`, `device_context.os_version`, both `integrity` fields, and `collector_authored` (empty, as §2 requires). The rest are behind ports with no implementation, so the object assembles but is **factually incomplete and says so** — `ChunkMetadata.isComplete` reports it rather than leaving a consumer to inspect fields.

### 1. The `identity` group is mostly unreachable, and one field is a cross-feature import

`project_id` and `task_id` belong to `features/projects_tasks/`, whose `domain/`, `data/` and `application/` are still `.gitkeep` — only Mission 1.3's placeholder screens exist. Nothing in the recording feature knows which Task is being recorded.

`collector_id` is `features/auth/`'s `User.uid`, and reading it directly is the cross-feature import **ADR-022 R3 forbids** *"at any layer, in either direction"* — the same collision Missions 2.3, 2.4 and the sign-out mission each resolved by inversion. `TaskContext` and `DeviceContext` follow that resolution rather than inventing a fourth.

`device_id` is Ch. 5.7 §2's *"cached, stable device identifier"*. Nothing produces or caches one, and **what it should be is undecided** — an install id, a hardware id, or something derived. That is a decision, not an omission.

### 2. `capture_conditions` needs three dependencies and a permission FR-CHK does not have

GPS, battery percentage and network type have no source in `dart:io` or in any admitted package. Realistically `geolocator`, `battery_plus` and `connectivity_plus` — three ADR-030 admissions — plus a **location permission**. Volume 5 Ch. 5.1 §3 assigns permissions to the Pre-Recording Checklist, and FR-CHK-01..05 covers camera, microphone, storage, battery and network — **not location**. So granting it needs an FR-CHK extension of the same shape as A-057's.

Absence is represented explicitly rather than by omission. Defaulting to zeroes would be worse than null: `{"lat": 0.0, "lng": 0.0}` is a real place in the Gulf of Guinea, and a plausible wrong value is harder to catch than an obvious empty one.

### 3. GPS at finalization contradicts NFR-META-01 — UNRESOLVED, needs a product decision

Ch. 5.7 §2 requires these be *"read at the moment of chunk finalization, not session start"*, and §4 explains why: they are *"only meaningful as of the actual capture moment"*.

NFR-META-01 caps metadata generation at **under 500 ms of added overhead per chunk**, and per A-059's correction that budget genuinely does cover this work — unlike the checksum, which sits inside finalization rather than metadata generation. Assembling the JSON is microseconds.

**A cold GPS fix routinely takes several seconds.** The two clauses cannot both hold.

This is a contradiction between requirements, not an implementation problem, and it is **not resolved here**. The options each cost something different and the choice is the project owner's:

- **Await the fix** — honours §2 exactly, breaks NFR-META-01, and stalls the metadata for every chunk.
- **Use a cached position** — honours the budget, and weakens §4's *"as of the actual capture moment"* by however stale the cache is.
- **Drop GPS from the hot path** — read it once per session, or asynchronously after generation, which changes what the field means.

Recorded now so that whoever implements `CaptureConditionsReader` does not silently pick one.

### 4. §3's persistence names the wrong engine and a layer that does not exist

*"Written to the local **Drift** `chunk_metadata` table"* — but **ADR-009 chose Isar**, and Volume 3 Ch. 3.1's stack table naming Drift is a decision ADR-009 already superseded. Ch. 5.7 §3 inherits the stale name.

Separately, the requirement is atomic: *"in the same transaction as the chunk's own local record — both succeed or both fail together, so a chunk file can never exist locally without its metadata already alongside it"*. That transaction spans two records in a layer Mission 3.7 owns and which does not exist.

~~**So FR-META-09 is not satisfied by this mission**~~, and no substitute was invented — in particular, no JSON file is written to disk, because the chapter never asks for one and inventing a second persistence mechanism would be worse than having none.

**Section 4 closed 2026-08-15 by Mission 3.7.** The storage layer exists and **FR-META-09 is satisfied**: `IsarChunkStore.saveChunk` writes the chunk row and the metadata row in one Isar `writeTxn`, and the file is moved into Chapter 5.8 §2's layout before that transaction commits. The stale Drift name is carried forward into A-063, which finds it in Chapter 5.8 and Chapter 5.9 as well. **Sections 1, 2 and 3 above remain open** — the unsourced fields, the missing location permission, and the GPS/NFR-META-01 conflict are untouched by this mission.

### Not amendment-worthy, recorded for completeness

**The codec spelling differs between volumes.** Ch. 5.2 §1's capture table says `H.264 (AVC)` and `CameraSpecification.videoCodec` transcribes `'H.264'`; Ch. 4.5 §2's wire format says `"codec": "h264"`. Both are correct for their own side — one describes an encoder, the other fixes a JSON value a backend parses — so it is translated at the boundary by `CodecWireName` rather than changing either source.

**No LiDAR fields exist in Ch. 4.5's schema.** Checked because Mission 3.9 has not run: the canonical JSON contains no LiDAR group and no `has_lidar` field, so there is no forward dependency and nothing was stubbed.

### A-063 — Chapter 5.8 names the wrong engine, specifies a crash-recovery mechanism this project cannot build, and Chapter 5.3 contradicts Chapter 5.6 about discarding short chunks

| | |
|---|---|
| **Volume** | 5 — Recording Engine, Chapter 5.8 (all four sections); Ch. 5.3 §5; Ch. 5.6 §3; Ch. 5.7 §3 |
| **Says** | The tables are *"Local Drift Tables"* on an engine header reading *"Drift (SQLite) — ADR-002, Volume 3, Chapter 3.2"*; §2 specifies a `.mp4.tmp`-until-renamed layout as *"the concrete mechanism behind Chapter 5.3's crash-recovery rule"*; Ch. 5.3 §5 discards an unrecoverable partial *"per a minimum-duration threshold"* |
| **Should say** | The engine is **Isar** (ADR-009); the `.tmp` mechanism is **not implementable** with the camera plugin this project uses, so crash recovery covers completed chunks only; and the minimum-duration threshold both contradicts Ch. 5.6 §3 and has no number |
| **Authority** | ADR-009 (engine), ADR-038 (collection placement), A-058 (the plugin-boundary precedent) |
| **Class** | Documentation update, plus one unresolved product decision |
| **Status** | Open |

### 1. Drift, again — the same stale name A-062 §4 found in Chapter 5.7

Chapter 5.8's header names the engine as *"Drift (SQLite)"* and cites *"ADR-002, Volume 3, Chapter 3.2"*. **ADR-009 chose Isar**, and Volume 3 Chapter 3.1's stack table naming Drift is a decision ADR-009 already superseded. Chapter 5.8 inherits the stale name from the same source Chapter 5.7 §3 did, and Chapter 5.9 §3 repeats it a third time (*"a live view … over `local_chunks.status` in Drift"*).

Nothing else in the chapter depends on the engine. The three tables, their columns and the *"identical field shape to Volume 4, Chapter 4.5's JSON"* requirement all transfer unchanged — Isar stores the seven metadata groups as embedded objects, which preserves that shape more directly than a relational flattening would have.

**A-062 §4 is now discharged in part.** Its two complaints were the wrong engine name and the missing storage layer. The layer exists as of Mission 3.7 and **FR-META-09 is satisfied**: `IsarChunkStore.saveChunk` writes the chunk row and the metadata row inside one `writeTxn`, and the `.mp4` is moved into place before that transaction commits, so a committed row never names a file that is not there. A-062's other three sections — the unsourced fields, the permission gap and the GPS/NFR-META-01 conflict — remain open and untouched.

### 2. `local_task_cache` is not this feature's table

Chapter 5.8 §1 lists four tables. Three are implemented. The fourth, `local_task_cache`, mirrors `tasks` and `task_assignments` and exists so *"C-03–C-06 render offline from last-synced data"* — screens that belong to `features/projects_tasks/`, whose `domain/`, `data/` and `application/` are still `.gitkeep`.

Placing it in `features/recording/` would put one feature's read cache inside another's data layer, which is the cross-feature coupling ADR-022 R3 exists to prevent. It is **deliberately absent**, not overlooked, and it is assigned in the ADR-009 successor proposed by this mission.

### 3. §2's `.tmp` crash recovery cannot be built here — a structural limit, not an implementation gap

§2's layout is precise:

> `{sequence_index:04d}.mp4.tmp` — in-progress write (Ch.5.4) — never treated as a valid chunk until renamed … on app relaunch, any `.tmp` file is either completed (if enough of the encode is salvageable) or deleted.

**Every clause of that assumes this application chooses the in-progress path.** It does not. Chapter 5.4's encode is `camera`'s `startVideoRecording()`, and A-058 already established that the pipeline stages Chapter 5.4 describes are the plugin's internals rather than this project's code. The same boundary decides this: `VideoCaptureOptions` exposes **no output-path parameter**, so the plugin writes to a directory and a filename of its own choosing, and returns the path only when `stopVideoRecording()` completes. A partial file left by a crash therefore sits in the plugin's temp directory under a name carrying no `session_id` and no `sequence_index`.

There is consequently nothing to scan for and nothing to link a found file back to. **No `.tmp` scan was implemented**, because it would search this application's tree for files that can never appear in it — a check that always passes and proves nothing is worse than no check, since it reads as coverage.

What crash recovery does cover, and this is the honest split:

| Chunk state at crash | Recoverable? | Why |
|---|---|---|
| `stopChunk()` returned before the crash | **Yes, fully** | The file is at a deterministic path, its row and metadata are committed, and `recoverableChunkIds()` returns it for re-queueing on next launch. |
| Still recording at the crash | **No** | Unnamed, unlinked, in the plugin's temp directory. Nothing identifies it. |

The second row means NFR-REL-04's *"queue state fully restored on next launch"* holds for everything that reached the queue, and the in-flight chunk is lost. **At most one chunk per crash**, bounded by Chapter 5.6's ten-minute boundary. That is the real exposure and it is not reduced by pretending otherwise.

Closing it requires either an upstream `camera` change that admits an output path, a platform-channel recording implementation this project does not have, or a different plugin — the same class of choice A-058 recorded for the software-encoder guarantee, and not a decision Mission 3.7 can make alone.

### 4. The minimum-duration threshold — Ch. 5.3 §5 and Ch. 5.6 §3 contradict each other, and neither states a number — ESCALATED, NOT RESOLVED

Chapter 5.3 §5:

> … the in-progress chunk's partial file is either recovered and finalized on next launch (if enough of the encode is intact) or **discarded per a minimum-duration threshold** — never silently uploaded as if it were a complete, valid chunk.

Chapter 5.6 §3:

> … a very short final chunk is still valid and still fully processed (Chapter 5.5) — **there is no minimum chunk duration below which footage is discarded**, since even a short clip may be usable data.

Both cannot hold. §3's reasoning is also the stronger of the two and matches the Constitution's *"never lose a take"*: `error-handling.md` §1 states *"a failure that discards a recording is the worst outcome available"* and §"Never recover by discarding data" makes it absolute.

**No number is stated anywhere in Volume 5.** "A threshold" is not a specification, and a value invented in this mission would become the de facto rule the moment it shipped.

Three things are therefore true and are recorded rather than resolved:

- **It is moot today.** §5's threshold governs a partial file that, per §3 above, this project can never obtain. Nothing in the code needs a number to run.
- **It becomes live the moment recovery becomes possible.** Whoever closes §3 inherits this immediately.
- **The conflict is a product decision, not an implementation one.** The candidate readings — that §5 is scoped only to salvaged partials and §3 to intentionally-stopped ones, or that §5 is simply wrong and should be struck — differ in what happens to real footage, which makes it the project owner's call.

**Escalated. No threshold is implemented, and none is defaulted.**

**Status of this sub-item, stated separately because it outlives the mission that found it:**

| | |
|---|---|
| **Decided?** | **No.** Escalated to the project owner. Nothing in the codebase encodes a threshold, a default, or a placeholder constant. |
| **Blocking today?** | **No.** §5's threshold applies to a salvaged partial file, and §3 above establishes that this project cannot obtain one. There is no code path that would consult a number if it existed. |
| **When it becomes live** | The moment crash recovery for an **in-flight** chunk becomes achievable — which requires a native recording path (a platform channel that chooses its own output file, or a plugin that admits one). That work is **not deferred to a numbered mission**: no chapter assigns it and no mission owns it, so it is undeferred rather than scheduled. |
| **What must be decided then** | Whether Ch. 5.3 §5 is scoped only to salvaged partials while Ch. 5.6 §3 governs intentionally-stopped chunks, or whether §5 is simply wrong and should be struck. The readings differ in what happens to real footage. |
| **Default if never decided** | **Ch. 5.6 §3 governs** — no minimum, nothing discarded. It is the clause with stated reasoning, and it agrees with the Constitution's *"never lose a take"* and `error-handling.md`'s *"never recover by discarding data"*. This is the safe reading, not a decision. |

### 5. Two gaps this mission leaves open — why each is deferred, and who owns closing it

**Note on mission numbers below.** Missions have tracked Volume 5's chapters one for one — 5.1/5.2 → 3.1, 5.3 → 3.2, 5.4 → 3.3, 5.5 → 3.4, 5.6 → 3.5, 5.7 → 3.6, 5.8 → 3.7. Numbers given for unrun missions are **projections from that pattern, not assignments**; the chapter named in each row is the authoritative owner.

#### ~~`local_sessions.status` never becomes `complete`~~ — CLOSED

> **Closed 2026-08-15 by Mission 3.8, verified on device by Mission 3.8.1. Corrected here by Mission 3.10's register audit.**
>
> The table below described this as open, and **all three of its factual clauses are now false**:
>
> | Clause as written | Reality |
> |---|---|
> | *"`ChunkStore` is not injected anywhere yet"* | Injected at the composition root — `main.dart`'s `recordingOverrides` binds `IsarChunkStore` over the live Isar instance. |
> | *"Nothing calls `saveChunk`"* | `FinalizeChunkUseCase` calls it for every chunk; both 3.8.1 device passes wrote two chunks each. |
> | *"`RecordingSchemas.all` is not yet passed to `DatabaseConfig`"* | Passed via `databaseConfigProvider.overrideWith(... .withSchemas(...))`. The device log reads `database open collections=3`. |
>
> The gap itself is closed the way this entry predicted: `ChunkStore.markSessionComplete` is called when the drain reaches `Idle`, which is the one instant a session's end is known. Mission 3.8.1 read the row back from Isar on hardware twice — `db session=… status=complete` on both the fast and the full pass.
>
> The reasoning below is left standing because it is still correct about *why* the store cannot infer completion from a chunk write. Only the "what closes it" clauses were overtaken.

<details>
<summary>Original entry, retained</summary>

| | |
|---|---|
| **Why deferred** | Not a choice about the column — a consequence of what calls this layer. `saveChunk` is invoked per chunk and receives a `RecordingSession`, which carries `sessionId`, `zoomFactor` and `startedAt` and **nothing about whether the session has ended**. The store cannot infer completion from a chunk write; the last chunk of a session is indistinguishable from a middle one at this boundary. |
| **Why the row is not rewritten** | Deliberate, and separate from the above. Re-putting the session on every chunk would discard any `task_id` and `collector_id` back-filled by another path — they are null today only because their sources are unbuilt (A-062) and are stored nullable precisely so they can be filled in later. |
| **Owner** | **Chapter 5.3 (Recording Lifecycle), already implemented as Missions 3.2 and 3.4.5.** No chapter defers this; it is a gap in built code, not unbuilt work. FR-SES-02's transition belongs at the lifecycle's return to `Idle`, which is where the end of a session is actually known. |
| **What closes it** | A wiring mission. **`ChunkStore` is not injected anywhere yet** — verified: no file outside the port, its implementation and the schema list names `ChunkStore`, `IsarChunkStore` or `RecordingSchemas`. Nothing calls `saveChunk`, and `RecordingSchemas.all` is not yet passed to `DatabaseConfig`. The same mission that connects the lifecycle to this store is the one that can also mark a session complete, because it is the first point where both halves exist. |
| **Consequence of leaving it** | Bounded. No consumer reads the column: Chapter 5.9's queue reads `local_chunks.status`, not the session's. A stale `in_progress` misreports history rather than affecting any chunk's fate. |

</details>

#### `local_chunks.s3_object_key` is stored null

| | |
|---|---|
| **Why deferred** | Chapter 5.14 §1's key is `{org_id}/{project_id}/{task_id}/{session_id}/{sequence_index:04d}_{chunk_id}.mp4`. Three of the five components — `org_id`, `project_id`, `task_id` — have no source in this application (A-062). |
| **Why null rather than a placeholder** | A key composed from placeholders would look deterministic, index as unique, and be wrong — and Chapter 5.13 §4 requires every retry to reuse *"the exact same deterministic S3 key"*, so a wrong key minted once would be reused forever by design. Null is the value that cannot be mistaken for a real key. Volume 4 Chapter 4.4 §6 marks the column UNIQUE and NOT NULL, which is a **backend** constraint; the row is only sent once the key exists. |
| **Owner** | **Chapter 5.10 (Upload Pipeline) §1 step 1**, *"Register `POST /v1/sessions/{id}/chunks` → presigned multipart URLs"* — the step that needs the key and the first that cannot proceed without it. Projected Mission 3.9. |
| **Blocked on** | `features/projects_tasks/`, which is unbuilt — its `domain/`, `data/` and `application/` are still `.gitkeep`. `TaskContext` is the port that would supply `project_id` and `task_id`; `org_id` has no identified source at all and is the harder half. |
| **Consequence of leaving it** | The column is unreadable by anything today, because no upload path exists. It becomes blocking exactly when Chapter 5.10 runs, and not before. |

---

### A-064 — BR-13's crash promise is satisfied only under a stated reading, and Chapter 2.2's next-launch behaviour is not buildable

| | |
|---|---|
| **Volume** | 1 — Ch. 1.9, BR-13; 2 — Ch. 2.2 §2 step 9; 2 — Ch. 2.7 C-07 and C-09; 1 — §5 (FR-CHK), §6 (FR-REC-03) |
| **Says** | BR-13: *"A session that is interrupted (e.g. app killed mid-recording) shall preserve all footage recorded up to the last safely written point."* Ch. 2.2 step 9: *"App killed before Stop → footage recorded up to last safe write point is preserved (Chapter 1.9, BR-13); **resumes into Local Processing on next launch**"* |
| **Should say** | BR-13 holds, with *"last safely written point"* read as **the last finalized chunk**. Chapter 2.2's *"resumes into Local Processing on next launch"* does not hold and cannot be built with the current camera plugin |
| **Authority** | A-063 §3 (the plugin boundary), A-058 (the precedent for it) |
| **Class** | Documentation update, plus four implementation gaps recorded below |
| **Status** | Open |

### 1. BR-13 is satisfied, under a reading that must be stated rather than assumed

A-063 §3 established that an in-flight chunk is unrecoverable: `VideoCaptureOptions` exposes no output path, so a partial file sits in the plugin's temp directory under a name carrying no `session_id` and no `sequence_index`.

That sounds like a BR-13 violation and is not, because **chunked recording makes every finalized chunk a safe write point**. A session killed at minute 17 has its first chunk complete, checksummed, paired with metadata and queued; only the 7 minutes since the last boundary are lost. BR-13's *"all footage recorded up to the last safely written point"* is exactly what survives.

**The reading is load-bearing and is therefore recorded, not left implicit.** Under the other available reading — *"last safely written point"* meaning the last flushed encoder buffer — BR-13 is violated on every crash, and closing it needs a native recording path. The bound on the exposure is **at most one chunk per crash**, which Chapter 5.6's ten-minute boundary caps.

### 2. Chapter 2.2 step 9's next-launch behaviour is not implementable

*"Resumes into Local Processing on next launch"* has nothing to resume. Chunks finalized before the crash already completed Local Processing — checksum, metadata and storage all happen at the chunk boundary, not at Stop — so they are queued, not pending. The interrupted chunk cannot be found. **Both halves of the sentence are empty.**

Mission 3.8 therefore builds **no crash-recovery screen**, and no launch-time notice. Volume 2 specifies neither, and inventing copy for a state the volumes do not describe would be a product decision taken in a widget.

`ChunkStore.recoverableChunkIds()` exists and is correct — it returns exactly the finalized-and-queued chunks — and **nothing calls it yet**. Chapter 5.9's Upload Queue is its consumer, and re-queueing on launch is that mission's work.

### 3. `MetadataIdentity`'s four unsourced fields carry the empty string

Mission 3.6 made all five fields required and non-null, on the reasoning that *"a chunk that cannot say which Task it belongs to or who recorded it is not a valid record"*. Mission 3.8 had to record real footage anyway, and the two positions had to be reconciled.

**Decided: `MetadataIdentity.unsourced`, the empty string.** The alternative — stubs that throw — is more honest about the gap and loses footage: metadata assembly sits in front of `ChunkStore.saveChunk`, so a throw means no chunk is ever persisted. The Constitution's *"never lose a take"* and `error-handling.md`'s *"never recover by discarding data"* both outrank the tidiness of refusing to guess.

Nothing plausible is invented, following `MetadataCaptureConditions`' reasoning about `{0.0, 0.0}`: `'unassigned'` or a generated placeholder would read as data. An empty string reads as absence.

**Detectability is the condition of the decision.** `MetadataIdentity.isComplete` and `ChunkMetadata.isIdentityComplete` report it, and **Chapter 5.10's registration must check the latter before composing an S3 key** — Chapter 5.14 §1's key embeds three of these fields, so uploading an incomplete identity would write an object nobody can attribute. That check does not exist yet, because no upload path does.

Of the four, `collector_id` is the cheapest to close and the most damaging to leave: `features/auth/` already knows it, and the only obstacle is the ADR-022 R3 inversion — a `DeviceContext` supplied at the composition root from auth's own state. The other three need `features/projects_tasks/` (A-062) or a decision about what a device id is.

### 4. `battery_plus` and `connectivity_plus` are admitted, and `capture_conditions` is still not wired

FR-CHK-03 and FR-CHK-04 have no source in `dart:io`; both are now ADR-030 admissions confined to `features/recording/data/`, with invariants I44 and I45.

They make **two thirds of A-062 §2 reachable** — battery percentage and network type are now one line each. They are deliberately **not** wired into `MetadataCaptureConditions`. A-062 §3's conflict between Chapter 5.7 §2's *"read at the moment of chunk finalization"* and NFR-META-01's 500 ms budget is unresolved, and its resolution decides the shape of the whole group: awaited, cached, or off the hot path. Filling in two fields under one reading of a rule still being decided would half-commit the group to an answer nobody has given.

### 4a. `battery_plus` carries a dated build risk, named on the day it was admitted

The Android build prints, on every run:

> WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): `battery_plus`, `cloud_functions`. **Future versions of Flutter will fail to build** if your app uses plugins that apply KGP.

Verified rather than taken from the warning: `battery_plus 6.2.3`'s `android/build.gradle` applies `kotlin-android` and pins `ext.kotlin_version = '1.7.22'`. `connectivity_plus 6.1.5` does **not** — it uses the modern `settings.gradle` plugins block, which is why Flutter names only one of the two packages admitted by Mission 3.8.

`cloud_functions` is also named and is **not** a new exposure: ADR-036 makes it temporary and it leaves the project at Mission 6/7.

So one newly-admitted dependency builds today and will stop building on a future Flutter. It is not urgent — no date is announced, and the fix is a `battery_plus` release that migrates to Built-in Kotlin — but it is exactly the kind of thing that becomes invisible between the day it is noticed and the day it breaks a release. **Named, not resolved**, in the same register as A-029's unmaintained engine and ADR-038's experimental-API dependency. If no migrated release exists when Flutter enforces this, the alternative is the platform channel considered and rejected during 3.8's step 0.

### 4b. `oneChunkBytes` is about 4 % low against a measured chunk

`RecordingLifecycle.oneChunkBytes` derives 610 MB from Chapter 5.2 §1's bitrates: (8,000 + 128) kbps ÷ 8 × 600 s = 609.6 MB. It is the floor for **both** FR-CHK-02's Checklist row and Chapter 5.4 §2's mid-recording backpressure.

**Measured on a CPH2707, Mission 3.8.1's full-duration run: 633,232,477 bytes for a 601-second chunk** — 633 MB, or 8.43 Mbps against the 8.128 Mbps the constant assumes. About 3.8 % above the derivation.

The cause is ordinary: the encoder is variable-bitrate and the spec figure is a target, not a ceiling. Nothing is misconfigured — the fast pass measured 8.07 Mbps on a 91-second chunk, *below* target, which is the same variance in the other direction.

**Consequence, small but real.** A device sitting exactly at the 610 MB floor has slightly less headroom than one full chunk actually needs, so the Checklist could admit a session whose first chunk does not quite fit. The exposure is bounded by Chapter 5.4 §2's 5-second free-space poll, which forces an early boundary long before the volume fills, and by the fact that a device that close to full is minutes from being blocked anyway.

**Not changed here.** The constant is derived from the specification, and moving it to a measured number would replace a traceable derivation with a single device's sample. The right fix is a margin — the derivation times a stated safety factor — and choosing that factor is a product decision about how close to full a Collector may start recording. Recorded for whoever takes it.

### 5. FR-REC-03's live preview is not rendered

> *The system shall display a full-screen live camera preview during recording.* — FR-REC-03

The Recording Screen shows the recording indicator, the elapsed timer and the Stop control on a black surface. **There is no preview**, because `CameraRecordingPipeline` owns the `CameraController` and does not expose it — deliberately, since handing a controller to a widget would let the UI start and stop capture behind the state machine's back.

Closing it needs a deliberate seam: the pipeline exposing a preview widget, or a `Listenable` the screen can build a `CameraPreview` from, without exposing capture control. That is a design decision about the boundary Mission 3.3 drew, and it is recorded here rather than taken by breaking the boundary from the UI side.

### 6. Two seams that were wrong until this mission composed them

**`ChunkFinalizer.finalizeChunk` had no way to know when a chunk started.** `ChunkProcessingJob.startedAt` is the instant capture *ended* — Mission 3.4.5 named it for when processing became possible — and Chapter 5.7 §2's `timing.started_at` needs the other end of the interval. An implementation given only the job would have set `started_at` equal to `ended_at` and reported **every chunk as zero seconds long**, in the field Chapter 4.5 derives `duration_seconds` from. `chunkStartedAt` is now a parameter, passed from `RecordingStateRecording`.

Nothing could have caught this before 3.8: the port had no implementation, so no test exercised the pairing.

**`WideAngleEligibilityCache` cannot express a Tier 2 verdict.** It stores a `WideAngleTier` and nothing else. That is lossless for Tier 1 (always `zoomFactorOptical`) and for `unsupported` (no factor). It is **not** lossless for `primarySensorZoom`, which the ladder resolves to 0.5 on a device that reaches 0.5 and 0.6 on one that stops at 0.6 — the stored tier is identical in both cases.

Reconstructing a factor from it would hand a 0.5-capable device 0.6 on every session after its first, which is precisely what Chapter 5.2 §2 forbids: *"footage from the same device is always comparable to itself over time."*

**Mission 3.8 does not guess: a cached Tier 2 re-probes.** That is correct and slower than A-057 intended — a camera open before every session on exactly the devices the Android path produces most often, the CPH2707 among them, since Android cannot answer Tier 1 at all. The fix is to store the factor beside the tier, which changes a port and a persisted format committed in Mission 3.1 and is left for a decision rather than taken here.

### 7. Two smaller readings, recorded so they are not re-litigated

**C-07 has five rows against FR-CHK's four.** A-057 already added wide-angle as a sixth FR-CHK item; FR-CHK-05 is not a row but the rule that blocks when any row fails. Five rows, one gate.

**C-09's timer switches format at ten minutes, not at one hour.** *"Timer format mm:ss up to 9:59, then hh:mm:ss"*, read literally, so 10:00 renders `0:10:00`. Unusual, and it lines up with Chapter 5.6's chunk boundary — the moment a Collector has a reason to count in a larger unit.

---

### A-065 — LiDAR depth capture is dropped from Mission 3's scope

| | |
|---|---|
| **Volume** | None. This is the only entry in this register that corrects no volume — no chapter in Volumes 1–5 mentions LiDAR, depth capture, ARKit, scene reconstruction or point clouds |
| **Says** | Nothing |
| **Should say** | Nothing. Recorded here because a **decision was taken not to build something**, and a decision with no artefact leaves no trace anywhere else |
| **Class** | Scope decision |
| **Status** | Closed — revisitable, see the conditions below |

LiDAR depth capture was proposed as Mission 3.9, alongside the AVFoundation pipeline built by Missions 3.1–3.8. It is **not built**, and this records why, so the next person to suggest it starts from the finding rather than from the idea.

### 1. The technical reason: ARKit requires exclusive camera ownership

Depth from LiDAR is reachable only through an `ARSession` with the `.sceneDepth` or `.smoothedSceneDepth` frame semantic. An `ARSession` cannot run beside this project's capture session.

**Apple Staff, January 2026** ([Developer Forums 812818](https://developer.apple.com/forums/thread/812818)):

> There's no supported way for you to access the ultra wide camera while an ARSession is running with the APIs currently available.

In the same thread the reporting developer describes precisely this project's arrangement and its outcome: *"when you run an AVCaptureSession and then run an ARSession, the AVCaptureSession stops."*

**Apple Staff, DTS Engineer** ([Developer Forums 734782](https://developer.apple.com/forums/thread/734782)):

> There is no supported way to access both the front and rear facing camera streams during an ARSession, please file an enhancement request using Feedback Assistant.

**Both statements concern two *different* cameras, and this project's case is stricter still** — BR-01 fixes capture to the rear camera, so the `ARSession` and the recording session would contend for the *same* physical device. The underlying AVFoundation rule closes it: a plain `AVCaptureSession` takes one input per camera, and a physical capture device is actively used by one session at a time. `AVCaptureMultiCamSession` does not help — it multiplexes cameras *within* one AVFoundation session and cannot admit ARKit's session as a participant.

**What this project owns, read from the plugin source rather than assumed.** `camera_avfoundation 0.10.2`, the package Volume 3 Ch. 3.1 names:

- `CameraPlugin.swift:36` — `captureSessionFactory: { AVCaptureSession() }`
- `CaptureSession.swift` — a protocol documented as *"a direct passthrough to AVCaptureSession"*, carrying `startRunning()` and `stopRunning()`

The plugin **constructs, owns and runs its own `AVCaptureSession`** bound to the rear device. `captureSessionFactory` is an internal test seam and is not reachable from Dart. There is no API to give the plugin a foreign session and none to borrow its device. So starting an `ARSession` would stop capture mid-recording — from the operating system's point of view, silently.

### 2. Why it is not merely deferred: the alternative is a second capture pipeline

Concurrency being unavailable, LiDAR would require a **replacement** capture path on LiDAR-capable devices rather than an addition beside the existing one.

ARKit supplies `ARFrame.capturedImage` as a `CVPixelBuffer`, frame by frame, and **no recording facility of any kind**. Everything Missions 3.3–3.8 obtained from `startVideoRecording()` / `stopVideoRecording()` would have to be rebuilt in Swift: encoder configuration, H.264 muxing to `.mp4`, the Chapter 5.6 ten-minute boundary, and file finalization — before Chapter 5.5's checksum, Chapter 5.7's metadata and Chapter 5.8's storage could be reached at all.

That is a **second, iOS-only capture pipeline for one hardware tier**, and it would move A-058's boundary — *"Chapter 5.4's pipeline stages are the camera plugin's internals, not this project's code"* — back inside this project on iOS. Duplicating the encode/mux/chunk path is precisely the fork that would make every later recording change a two-implementation change.

This is recorded as a cost, not as a refusal. It is a real option; it is simply much larger than "add depth capture", and taking it silently would have been the error.

### 3. The second, independent reason: there is no iOS toolchain

Even with the fork approved, it could not be built or verified today:

| | |
|---|---|
| Development host | Windows. No macOS, no Xcode, no Swift toolchain |
| `mobile/ios/` | Scaffolded, `IPHONEOS_DEPLOYMENT_TARGET = 13.0`, **no `Podfile`** — `pod install` has never run |
| Physical devices | One: the CPH2707, **Android**, which has no LiDAR |

An iOS-only feature therefore has no compiler and no test device. Every mission in this project has been held to real-API checks **and** real-device verification — Mission 3.8.1's two full end-to-end passes being the most recent — and neither is reachable for iOS work under the current arrangement. Shipping unverifiable Swift would break that standard rather than extend it.

### 4. It costs nothing downstream — verified, not assumed

Checked directly against the source PDFs rather than carried over from A-062's earlier note:

| Volume | `lidar` | `arkit` | `scene reconstruction` | `point cloud` | `depth` |
|---|---|---|---|---|---|
| 1 — Product Planning | 0 | 0 | 0 | 0 | 1 — *"queue depth of 50+ pending chunks"* |
| 2 — Product Design | 0 | 0 | 0 | 0 | 1 — *"Depth & Reachability Rules"* (navigation) |
| 3 — Technical Architecture | 0 | 0 | 0 | 0 | 0 |
| 4 — Backend Architecture | 0 | 0 | 0 | 0 | 0 |
| 5 — Recording Engine | 0 | 0 | 0 | 0 | 0 |

Both `depth` hits are unrelated to depth capture.

**Volume 4 Chapter 4.5's canonical metadata schema contains no LiDAR group, no depth field and no `has_lidar` flag.** Its seven groups — `identity`, `timing`, `capture`, `device_context`, `capture_conditions`, `integrity`, `collector_authored` — are implemented in full by Mission 3.6 and stored by Mission 3.7, and none of them has a slot this decision leaves empty.

A matching sweep of `mobile/lib/` and `mobile/test/` returns **zero** occurrences of lidar, depth, ARKit or scene-depth in any form. So:

- **no stub**, because nothing calls into a depth port;
- **no placeholder field**, because Chapter 4.5's shape does not have one;
- **no forward dependency**, because nothing downstream — Chapter 5.9's queue, 5.10's upload, 5.14's key schema — reads or transmits depth.

This is the difference between this entry and A-062 or A-063. Those record gaps where something *is* expected and absent. This records a capability that was never specified, so dropping it leaves the specification exactly satisfied.

### 5. What would make this worth revisiting

Neither condition is scheduled, and neither is assumed to arrive:

- **Apple exposes a supported concurrent-access API** — an `ARSession` able to share, or to hand over, the capture device an `AVCaptureSession` is using. Both forum threads end with Apple staff directing developers to Feedback Assistant, which is the shape of a limitation Apple knows about and has not committed to changing.
- **This project gains real iOS development infrastructure** — a macOS host, an Xcode toolchain, and at least one LiDAR-capable device to verify against. Without the third, an implementation could be compiled and still not checked.

Until both hold, LiDAR depth capture is out of scope. If only the second arrives, the fork in §2 becomes buildable but stays expensive, and the decision to take it is still the project owner's.

**No ADR accompanies this**, deliberately. An ADR records an architectural decision that shapes the code; nothing was built, no pattern was established, and no existing decision changed. ADR-024 §"an ADR is not a design document, a specification, a tutorial or a task list" applies — this is a scope decision, and the register is where scope decisions against the volumes belong.

---

### A-066 — Volume 9's data-layer coverage target is missed, and the strongest evidence for that layer is not a unit test

| | |
|---|---|
| **Volume** | 9 — Quality Assurance, Chapter 9.5 §2 (coverage targets); Chapter 9.6 §4 (what unit tests deliberately don't cover) |
| **Says** | *"Data layer (repositories): 80%+, focused on error-path coverage per Chapter 9.1's rule, not just the happy path."* |
| **Should say** | The target is right and is **missed at 76.90%**. One file accounts for the whole shortfall, for a reason Chapter 9.6 §4 half-covers and should cover fully |
| **Class** | Measured result, recorded rather than corrected |
| **Status** | Open — the target is not met and is not being waived |

### Measured, Mission 3.10, 514 tests

| Layer | Ch. 9.5 §2 target | Measured | Verdict |
|---|---|---|---|
| `recording/domain` | 90%+ | **99.29%** (139/140) | **Met** |
| `recording/data` | 80%+ | **76.90%** (223/290) | **MISSED by 3.10 points** |
| `recording/application` | *none stated* | ~~86.36% (171/198)~~ **87.37% (173/198)** | n/a — see below |
| `recording/presentation` | golden tests, *"rather than a blanket coverage percentage"* | ~~22.22% (54/243)~~ **48.63% (124/255)** | n/a — see below |

> **Corrected 2026-08-15 by Mission 3.12's register cross-check.** The two figures above were measured at Mission 3.10 and were overtaken by Mission 3.12-PRE (`09f40ac`), whose widget test exercises `PreRecordingChecklistScreen` through a real tap. Presentation more than doubled; application gained two lines.
>
> **`domain` and `data` are unchanged and were re-measured, not assumed** — 99.29% and 76.90% still hold, so the data-layer miss and its `isar_chunk_store.dart` cause stand exactly as written.
>
> This is the **second** time the register cross-check has found drift, after A-057 and A-063 §5 at Mission 3.10. It is the argument for open item 23: a percentage recorded in prose goes stale the moment anyone adds a test, and only a scheduled re-check catches it.

**Chapter 9.5 §2 names three layers and gives `application/` no numeric target.** Chapter 9.6 §1 instead requires *"every Riverpod Notifier's state transitions, using ProviderContainer overrides"*, which is a completeness rule and is satisfied — `RecordingNotifier` and `ChecklistNotifier` both have transition suites built that way. The 86.36% is reported for information, not against a target.

### The whole shortfall is one file

`isar_chunk_store.dart` measures **7.69% (4/52)**. Excluding it, the data layer is **92.02% (219/238)** — comfortably past the target, and error-path-weighted as Chapter 9.1 requires.

Covering it needs a live Isar. `Isar.initializeIsarCore(download: true)` **fetches native binaries over the network**, so a unit test over this class would make the build depend on the internet. That dependency is not added.

Chapter 9.6 §4 exempts *"real camera behavior, real background upload, real platform-channel calls"*. Isar is a native library rather than a platform channel, so this sits **adjacent to the exemption rather than inside it** — which is why this is recorded as a miss rather than claimed as exempt.

### The evidence that does exist is stronger than the test would have been

Mission 3.8.1 ran the real `IsarChunkStore` on a CPH2707, twice, against a real database:

- **Independent re-hash.** Both chunks were re-read with `crypto` and compared against the checksum the store had written — `shaMatches=true`, `sizeMatches=true`, including on a 633 MB file.
- **Read-back from Isar.** `db session=… status=complete chunks=2 files=2/2 orphans=0`, confirming the `writeTxn` pairing, the file placement, and `markSessionComplete`.
- **Both durations.** A 90-second fast pass and a real 600-second boundary.

A unit test against a downloaded binary would exercise the same Dart with a *different* engine build than production ships, on a desktop filesystem rather than Android scoped storage, and could not verify a 633 MB checksum at all. **The device run is the better evidence, and it is what Chapter 9.9 assigns.** The gap is that Chapter 9.5's percentage cannot see it.

### Presentation is not measured against a percentage, and two files were still a real gap

Chapter 9.5 §2 asks for *"golden tests for every Design System component … rather than a blanket coverage percentage"*, so the 22.22% is not a target miss. `golden_toolkit` is **not installed**, so no golden test exists; adding it is an ADR-030 admission nobody has taken.

But `checklist_copy.dart` and `recording_error_copy.dart` are **pure functions in `presentation/`, not widgets** — outside the golden provision and trivially unit-testable. Both were at 0% and are now covered, including the property Chapter 2.9 §2 actually cares about: that **no `ErrorCode` and no `ChecklistCheck` can produce an empty or generic message**. That is a totality assertion over the whole taxonomy, not a percentage.

The three screens remain at 0% and are left there deliberately: writing widget tests for them would raise a number against a target Volume 9 does not set, while the thing Volume 9 does ask for — goldens — is blocked on tooling.

---

### A-067 — `shared_preferences` is confined to two owners, and the composition root is the second

| | |
|---|---|
| **Volume** | None directly. Extends A-057's confinement of `shared_preferences`, under ADR-030's admission rules |
| **Says** | A-057 confines `shared_preferences` to `features/recording/data/`, and `ci.yml` enforced exactly that |
| **Should say** | Two owners: `lib/features/recording/data/` **and** `lib/main.dart` |
| **Class** | Confinement rule change, enforced in CI |
| **Status** | Closed |

**Found by Mission 3.11's security review, as a failing check rather than a judgement call.** `lib/main.dart:41` imports `package:shared_preferences/shared_preferences.dart` while `ci.yml` permitted only `lib/features/recording/data/`, so the `Architecture boundaries` job was **failing at HEAD**.

Introduced by **Mission 3.8** (`83d2a48`) and undetected for two missions. The cause is worth recording because it is a process fault, not a reasoning fault: Mission 3.8 ran the confinement check for the three packages it had touched — `isar`, `battery_plus`, `connectivity_plus` — reported "confinement green", and never re-ran the full sweep. A per-package check cannot see a violation in a file the package was already allowed to be near. **The sweep is only meaningful run whole**, which is how Mission 3.11 found it.

### Why the composition root, and not an inversion

`SharedPreferences.getInstance()` is asynchronous. `SharedPreferencesWideAngleEligibilityCache` takes a resolved instance rather than resolving one, so it stays substitutable in tests — the same shape ADR-009 Caveat 2 already forces for the database directory, where `databaseDirectoryProvider` throws until the composition root supplies a path it resolved with `path_provider`.

So `main.dart` resolves the instance before constructing the container and supplies it through an override. Moving the resolution into the cache would remove the import from `main.dart` and take the substitutability with it.

**The permission is one file, not a directory.** `lib/main\.dart` is matched exactly, so nothing acquires the import by being added nearby — unlike a directory-scoped owner. That is the same narrowness ADR-039 chose for `isar`'s `data/isar_*.dart`.

### A false precedent, corrected

The instruction that authorised this fix described the composition root as *"already permitted for other async platform instance resolution (path_provider, database directory)"*. **It is not.** `grep -c path_provider .github/workflows/ci.yml` returns **0** — `path_provider` is not confined at all, so `main.dart` was never *permitted* to import it; the question was never asked.

The real precedent is ADR-039's regex owner for `isar`, which this reuses. Recorded so nobody later cites a permission that does not exist.

### A smaller gap this surfaced, not closed here

**`path_provider` has no confinement rule.** It is imported only by `lib/main.dart` today, but nothing prevents it spreading. Every other platform-touching package in this project is confined; this one was never added to the list. Not fixed here because adding a confinement rule is an ADR-030 decision rather than a CI edit, and this mission's scope was S1.

---

### A-068 — The empty-string identity sentinel needs two guards, and neither surface exists yet

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.3 §2 (input validation), Chapter 8.6 §2 (why identity is collected); Volume 5 Chapter 5.10 §1 (registration); Volume 1 BR-21/BR-22 |
| **Says** | Ch. 8.6 §2 collects identity *"to attribute footage to the correct Collector/device for BR-21/22's integrity and audit requirements"*. Ch. 8.3 §2 requires every Lambda handler to validate its request body against a strict schema, *"rejecting unexpected fields rather than silently ignoring them"* |
| **Should say** | The same rejection rule must cover **blank** values in identity fields, not only unexpected ones — and the client must not send them in the first place |
| **Class** | Two guards owed to future missions, neither buildable today |
| **Status** | Open — required when their surfaces exist |

**Found by Mission 3.11's security review of the A-064 §3 sentinel, deliberately while the pattern was fresh rather than when the risk surface appears.**

`MetadataIdentity.unsourced` is the empty string, and `PlatformDeviceContext` and `UnsourcedTaskContext` return it for `collectorId`, `deviceId`, `deviceModel`, `projectId` and `taskId`. A-064 §3 chose it over a placeholder because it cannot collide with a real id and fails `isComplete`, and that reasoning holds.

### The residual risk, stated precisely

**The empty string is safe in Dart and ambiguous on the wire.** `''` fails a null check, an emptiness check and `isIdentityComplete` — but once serialised into a metadata document, `"collector_id": ""` is indistinguishable from a value that was truncated, stripped by a proxy, or deliberately blanked. A backend receiving it cannot tell "this build had no source" from "something removed this".

That matters because BR-22 makes system-generated metadata immutable and rejected on any subsequent PATCH. **A chunk stored with a blank attribution could not be corrected afterwards** — it would be permanently unattributable evidence, which is the opposite of what Ch. 8.6 §2 collects identity for.

### Guard 1 — client-side, owed to Mission 4

`ChunkMetadata.isIdentityComplete` exists for exactly this and **has no caller**. Volume 5 Chapter 5.10 §1 step 1 is *"Register `POST /v1/sessions/{id}/chunks` → presigned multipart URLs"*, and Chapter 5.14 §1's key embeds `project_id`, `task_id` and `session_id`. Registration must check `isIdentityComplete` before composing a key or sending a metadata document, and refuse rather than send blanks.

### Guard 2 — server-side, owed whenever Lambda handlers exist

Ch. 8.3 §2's validation rule as written rejects *unexpected* fields. It must also **reject an expected field that is present and blank** in the identity group. Client-side checks are a correctness measure, not a security boundary — Volume 4 Chapter 4.8's principle that authorization is *"never client-trusted"* applies to attribution for the same reason.

**Both are required; neither is optional in favour of the other.** Guard 1 prevents a well-behaved client from producing unattributable evidence; Guard 2 is what holds if a client is modified, out of date, or replaced.

### Why nothing is built now

There is no upload path, no registration call, and `backend/` is empty (ADR-015). Mission 3.11's review confirmed the recording feature makes **no network calls at all** — no `dio`, no `http`, no socket. So the risk surface does not exist, and building a guard against a call that cannot happen would be untestable. This entry is the record that both are owed the moment either surface appears.

### A-069 — Volume 8 Chapter 8.2 §3 embeds an "ADR-011" that is not this project's ADR-011

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.2 §3 |
| **Says** | *"ADR-011 — Local (On-Device) Chunk Encryption at Rest"*, an Accepted decision to rely on OS-level app-sandbox encryption rather than adding app-level AES |
| **Should say** | The **decision** is correct and binding. Its **number** collides with this repository's `ADR-011 — S3 Storage Architecture` and must not be cited as "ADR-011" in code or documentation |
| **Class** | Documentation hazard |
| **Status** | Open |

Volume 8 numbers its own inline ADRs in a sequence that runs independently of `docs/architecture/decisions/`. This repository's ADR-011 is **S3 Storage Architecture**; Volume 8's is **local chunk encryption**. Same identifier, unrelated subjects.

**The risk is a citation, not a defect.** Anyone writing "per ADR-011" about on-device encryption would point a reader at an S3 bucket-naming decision, and the mistake reads as plausible in both directions. Nothing in the codebase currently makes that citation — checked.

**The substance is satisfied and is worth recording here so the decision is not lost with its number.** Volume 8 Ch. 8.2 §3 chose OS-level app-sandbox encryption as the MVP baseline and explicitly declined app-level encryption, on the grounds that it would add CPU and battery cost to a ten-minute continuous write and that BR-08 keeps the exposure window short. Mission 3.8.1's device run confirms compliance: chunks are written to `/data/user/0/com.example.mobile/app_flutter/recordings/…`, Android app-private internal storage covered by File-Based Encryption, and the Isar database shares that directory. **No app-level encryption is owed.**

The reopening trigger Volume 8 states — *"a future client contract or regulatory review requiring app-level encryption as a compliance checkbox regardless of the OS's own protection"* — is carried forward unchanged.

**Refer to it as "Volume 8 Chapter 8.2 §3"**, never as ADR-011.

---

### A-070 — Chapter 2.2 step 8's "Record tapped" is the Checklist's own button, and nothing called `start()` until this was found by hand

| | |
|---|---|
| **Volume** | 2 — Product Design, Chapter 2.2 §2 step 8; Chapter 2.7's C-09 |
| **Says** | Ch. 2.2 step 8: *"Recording Screen — **Record tapped** → Recording in progress, timer running"*. Ch. 2.7's C-09 lists a recording indicator and a Stop control, and calls Stop *"the only interactive element on screen"* |
| **Should say** | Both hold, under one reading: **"Record tapped" is the Checklist's own Start Recording button**, not a second control on the Recording Screen. C-09 keeps Stop as its only interactive element |
| **Class** | Specification conflict resolved, plus a defect it concealed |
| **Status** | Closed — fix confirmed on hardware |

### 1. The conflict, and the reading taken

Read literally, step 8 puts a Record control on the Recording Screen and C-09 forbids one. They cannot both be satisfied by a screen with two interactive elements.

**Resolved in C-09's favour.** The Checklist's Start Recording button drives both lifecycle edges — `Idle → Ready` (session minted, camera opened) and `Ready → Recording` (capture begins) — before navigating. One tap, both edges, and the chrome-free screen is entered already recording.

The alternative reading was rejected because C-09's design intent is the stronger claim: *"deliberately removes all navigation chrome so nothing can be tapped accidentally mid-recording"* (Ch. 2.4 §2). Adding a Record control to that screen would contradict the reason the screen exists. Step 8 is describing *when* recording begins in the flow, not *which widget* the tap lands on.

### 2. The defect this concealed

**Nothing in `lib/` ever called `RecordingNotifier.start()`.** Mission 3.8 wired `checklistPassed()` and navigation, and the second edge was simply never written — C-09 had no Record control to write it in, and the Checklist's button stopped at `Ready`.

The failure was silent and looked like a UI bug:

| Step | Value |
|---|---|
| State on arriving at the Recording Screen | `RecordingStateReady` |
| `RecordingState.isCapturing` | `this is RecordingStateRecording` → **false** |
| `_StopControl(enabled:)` | **false** |
| `InkWell.onTap` | **`null`** |

So the Stop button rendered, accepted presses, and discarded them before any handler ran. **Nothing was recording**, and with no live preview (A-064 §5) the only visual tell was that the REC dot was grey rather than red — while the timer, which derives from `session.startedAt`, ran normally. `logcat` showed no error because nothing failed; nothing executed.

`RecordingGuard` was not involved — it explicitly admits `Ready` on `/recording/`, which is why the screen loaded at all.

### 3. The verification-method lesson — the part worth keeping

**Every automated check passed while this was broken**, and none of them could have caught it:

- `recording_notifier_test.dart` calls `start()` itself. It proves the transition works *when invoked*; it cannot prove anything invokes it.
- **Mission 3.8.1's device harness did the same** and returned `RESULT pass` twice on real hardware, including a full 600-second boundary. It bound the production `recordingOverrides` and drove the notifier directly — deliberately, because that was the only way to run unattended.
- Mission 3.10's coverage audit measured `presentation/` at 22.22% and correctly declined to raise it, since Volume 9 Ch. 9.5 §2 asks for golden tests there rather than a percentage. Line coverage would not have found this either: the line was absent, not uncovered.

**The defect lived in the one seam every method bypassed — the UI's call into the notifier.** A person tapping the real button found it in seconds.

This is a gap in **how** verification was done, not in what was verified, and it generalises: *a harness that drives the layer beneath the UI proves that layer, and silently assumes the UI calls it.* Mission 3.10's item 23 recorded the same shape for amendment drift and item 26 for the confinement sweep — a whole checked in parts. This is the third instance.

**Closed by a widget test that taps the button**, `pre_recording_checklist_screen_test.dart`: five cases asserting the machine reaches `RecordingStateRecording`, that the pipeline receives `openSession` then `startChunk`, that navigation follows, that a capture failure keeps the Collector on the Checklist, and that the button is disabled until every row passes.

### 4. A tooling correction, recorded because it wasted a cycle

`flutter install` **installs an already-built artifact; it does not rebuild from source.** Told to install the fix, it deployed the `app-debug.apk` left over from Mission 3.8's `flutter build apk` — a binary predating the fix — and reported success. The fix was then reported as "installed on the device" when it was not, and the next manual test reproduced the original symptom exactly.

`flutter run` compiles from current source. **For verifying a change on a device, use `flutter run`, or `flutter build` immediately before `flutter install`.** "Install succeeded" is not evidence that the change is on the device.

### 5. Confirmed on hardware — observed, not inferred

CPH2707 / Android 16, session `da80b794-11e2-49c1-8f2c-eb2f36323b99`:

```
checklist after start()  failure=null state=Recording isCapturing=true
stopControl TAPPED       enabled=true
notifier._endChunk ENTER endingChunk=false state=Recording
stopChunk() RETURNED     path=…/cache/REC…mp4
notifier transitioning to Finalizing  →  navigated to /processing/…
store ROW   id=1c44f8ca-… seq=0 status=queued storedBytes=13275128
            sha=8af51048…bafc s3Key=null
store FILE  path=…/app_flutter/recordings/da80b794-…/0000.mp4
            exists=true actualBytes=13275128 sizeMatches=true pathAsExpected=true
store META  present=true seq=0 durationSec=13 zoom=0.6 collectorId=""
store SESSION-COMPLETE   status=complete
```

The row, the file, the size match, Chapter 5.8 §2's exact path, the 1:1 metadata pairing and FR-SES-02's `complete` were all **read back from the live database**, not deduced from the state machine. 13,275,128 bytes over 13 s ≈ 8.17 Mbps against Chapter 5.2 §1's 8.128 Mbps target.

`s3Key=null` and `collectorId=""` confirm A-063 §5 and A-064 §3 are intact — nothing invented a value under real conditions.

**One limit, stated rather than glossed:** these confirmation runs were seconds long, not the two minutes the verification asked for. They fully validate the row-and-file path; **sustained encoding rests on Mission 3.8.1's 600-second pass**, not on these.

### 6. Open and uninvestigated — CameraX graph error on session close

Every successful stop is followed immediately by:

```
GraphProcessor onGraphError(GRAPH_ERROR(cameraError=ERROR_GRAPH_CONFIG), willAttemptRetry=false)
CameraGraph-N state updated to GRAPH_ERROR
Updated current camera internal state to CombinedCameraState(state=CLOSING, error=StateError{code=4})
```

Native CameraX, not Dart. It appears **after** `stopChunk()` returns successfully, during `closeSession()`, and affected none of the runs — the chunk was written, the row committed and the session completed every time.

It may be ordinary teardown noise, or it may mean the capture session closes uncleanly and leaks something across repeated sessions. **Not investigated, and not assumed harmless.** Recorded as open.

---

## Consolidated open items — A-057 through A-070

Every carried-forward item, in one place, accurate as of Mission 3.10. This is the seed for Mission 3.12's status report.

### Blocked on an unbuilt feature module

| # | Item | Owner | Source |
|---|---|---|---|
| 1 | `project_id`, `task_id` unsourced — stored as `MetadataIdentity.unsourced` | `features/projects_tasks/` (unbuilt) | A-062 §1, A-064 §3 |
| 2 | `local_task_cache` table not implemented | `features/projects_tasks/` | A-063 §2, ADR-039 §3 |
| 3 | `s3_object_key` stored null — key needs `org_id`/`project_id`/`task_id` | Ch. 5.10 §1 step 1 | A-063 §5 |

### Blocked on a decision, not on work

| # | Item | What must be decided | Source |
|---|---|---|---|
| 4 | GPS at finalization vs NFR-META-01's 500 ms budget | Await, cache, or drop from the hot path | A-062 §3 |
| 5 | `device_id` — *"cached, stable device identifier"* | Install id, hardware id, or derived | A-062 §1 |
| 6 | Minimum-duration threshold — Ch. 5.3 §5 vs Ch. 5.6 §3 | Which clause governs; no number stated anywhere | A-063 §4 |
| 7 | `oneChunkBytes` is ~4% below a measured chunk (610 MB vs 633 MB) | A safety factor, or accept the derivation | A-064 §4b |
| 8 | FR-REC-03's live preview not rendered | The seam by which the pipeline exposes a preview without exposing capture control | A-064 §5 |
| 9 | `WideAngleEligibilityCache` cannot express Tier 2 → re-probes every session on Android | Whether to change a Mission 3.1 port and persisted format | A-057 (corrected), A-064 §6 |
| 10 | LiDAR depth capture out of scope | Revisit only on a supported ARKit concurrency API **and** iOS infrastructure | A-065 |

### Cheapest to close

| # | Item | Why it is cheap | Source |
|---|---|---|---|
| 11 | `collector_id` unsourced | `features/auth/` already knows it; needs only the ADR-022 R3 inversion — a `DeviceContext` supplied at the composition root | A-064 §3 |
| 12 | `local_sessions.status` → `complete` | **CLOSED** by Mission 3.8 (`83d2a48`), verified on device by 3.8.1 and again by 3.12-PRE-5 (`09f40ac`) — `SESSION-COMPLETE status=complete` read back from Isar | A-063 §5 (corrected) |

### Risks named and not resolved

| # | Risk | Why it is quiet | Source |
|---|---|---|---|
| 13 | Isar 3 is unmaintained; the project depends on an `@experimental` API for a uniqueness guarantee | The build no longer warns — ADR-038 silenced it | A-029, ADR-038 |
| 14 | `battery_plus` applies the legacy Kotlin Gradle Plugin | Builds today; a future Flutter will refuse it | A-064 §4a |
| 15 | Software-encoder fallback and unmeasurable flush interval | Silent by nature | A-058 |
| 16 | An in-flight chunk is unrecoverable after a crash | Structural to the plugin; at most one chunk per crash | A-063 §3, A-064 §1 |
| 17 | Android 16 KB page-size support unverified for Isar | Release-blocking rather than development-blocking | ADR-009 |

### Testing and verification

| # | Item | State | Source |
|---|---|---|---|
| 18 | Data-layer coverage 76.90% vs 80% | Missed; cause named; device evidence stronger | A-066 |
| 19 | Golden tests for Design System components | None; `golden_toolkit` not installed | A-066, Ch. 9.5 §2 |
| 20 | `integration_test` end-to-end flows (Ch. 9.7 §1's five) | Package not installed | A-028 |
| 21 | `recoverableChunkIds()` has no caller | Ch. 5.9's queue is its consumer | A-064 §2 |
| 22 | No iOS toolchain — no macOS host, no Xcode, no iOS device | Blocks any iOS verification | A-065 §3 |

### Process and specification

| # | Item | Recommendation | Source |
|---|---|---|---|
| 23 | Amendment drift went undetected for two missions | **Run the register cross-check at the close of every multi-sub-mission block, not only at a dedicated audit mission.** A-057 claimed the wide-angle verdict was cached per install; Mission 3.8 made it re-probe every session on Android, and the amendment still read as true through 3.8 and 3.9 until Mission 3.10 checked all nine side by side. Nothing in the workflow would have caught it sooner — each sub-mission verified its own work, and drift lives *between* them. Cheap to repeat: the check is a read of each amendment's claims against current code, and it found two in one pass. | A-057, A-063 §5 (both corrected by 3.10) |
| 24 | `app/` has no stated coverage target | **Candidate for a future Volume 9 amendment, not a code fix.** Chapter 9.5 §2 names domain, data and presentation only. `app/` currently measures **72.73%** and holds `router.dart`, `auth_guard.dart` and `recording_guard.dart` — the last of which is where **BR-04** is actually enforced, since a disabled button stops a tap but not a deep link. A business rule enforced in a layer with no coverage target is a gap in the specification rather than in the code. Not fixed here: inventing a target for a layer Volume 9 does not discuss would be this project deciding Volume 9's content by writing tests. | Ch. 9.5 §2, A-066 |
| 25 | `path_provider` has no confinement rule | **Add one, or record why it is exempt.** Every other platform-touching package is confined; this one was never listed. Imported only by `lib/main.dart` today, but nothing enforces that. An ADR-030 decision rather than a CI edit. | A-067 |
| 26 | Package-confinement checks were run per-package, not as a sweep | **Run the full sweep, never a subset.** Mission 3.8 checked the three packages it touched, reported green, and left the `Architecture boundaries` job failing for two missions. A subset check cannot see a violation involving a package it did not test. Same class as item 23's amendment drift: the fault is in checking part of a whole. | A-067 |

### Security review findings — Mission 3.11

| # | Finding | State | Source |
|---|---|---|---|
| 27 | **S1** — `shared_preferences` imported outside its confined layer; `Architecture boundaries` job failing since Mission 3.8 | **CLOSED** by Mission 3.11.1 (`958c0d8`) — `main.dart` named as a second owner, full 13-package sweep green | A-067 |
| 28 | **S2** — the empty-string identity sentinel is ambiguous on the wire | **Open.** Two guards owed: `isIdentityComplete` checked at Ch. 5.10 §1's registration (Mission 4), and a Ch. 8.3 §2 server-side rule rejecting blank identity fields (whenever Lambda handlers exist). Neither surface exists; no network call is made by this feature at all. | A-068 |
| 29 | **S3** — no changelog existed, despite Ch. 11.5 §2 requiring Security entries for storage and data handling | **CLOSED** by Mission 3.11.2 (`4f992da`) — `docs/CHANGELOG.md` started and Missions 3.1–3.10 backfilled. The backfill is itself the batching Ch. 11.5 §4 warns against, done once to establish the file. | Ch. 11.5, A-068 |
| 30 | Volume 8 Ch. 8.2 §3's inline "ADR-011" collides with this repository's ADR-011 | **Open** — documentation hazard. Cite it as "Volume 8 Chapter 8.2 §3", never as ADR-011. The decision itself is satisfied: OS-level sandbox encryption, no app-level layer owed. | A-069 |
| 31 | CameraX `GRAPH_ERROR(ERROR_GRAPH_CONFIG)` on every session close | **Open, uninvestigated.** Fires after a successful `stopChunk()`, during `closeSession()`. Affected no run — chunk written, row committed, session completed each time. May be teardown noise or an unclean close that leaks across repeated sessions. Not assumed harmless. | A-070 §6 |
| 32 | A device harness that drives the notifier cannot see UI wiring | **CLOSED for this case** by Mission 3.12-PRE (`09f40ac`)'s widget test; the general lesson stays open. **Third instance of "a whole checked in parts"** (cf. items 23, 26). Mission 3.8.1 returned `RESULT pass` twice while nothing in `lib/` called `start()`. Closed for this case by a widget test that taps the button; the general lesson is that an unattended harness proves the layer it drives and silently assumes the layer above calls it. | A-070 §3 |
| 33 | `flutter install` deploys a stale artifact | **Use `flutter run`, or `flutter build` immediately before `flutter install`.** It installed Mission 3.8's pre-fix APK and reported success, causing a fix to be reported as on-device when it was not. "Install succeeded" is not evidence the change is on the device. | A-070 §4 |

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
