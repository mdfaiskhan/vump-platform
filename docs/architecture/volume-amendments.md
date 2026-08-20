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
| **Status** | **CLOSED in code 2026-08-16 by Mission 4.4.** `ChunkUploadPipeline._classify` now maps HTTP 429 to `transportFailure` — transient — ahead of the blanket 4xx branch, so it takes Chapter 5.13 §2's backoff instead of surfacing as Failed. Two halves remain open: the Volume text still reads as a blanket 4xx rule, and `Retry-After` is **not** honoured because Dio's exception does not carry response headers through the S3 transfer path. §2's jitter already separates a batch that rate-limited together, so the header would refine the delay rather than enable the retry |

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

> **Mission 4.1, 2026-08-15.** Chapter 5.9's Upload Queue was built against **Isar** on this entry's authority. Chapter 5.9 §3's *"a live view … over `local_chunks.status` in Drift"* is the third instance of the stale name recorded above; no new amendment was raised for it, because duplicating a finding across two entries is how a register goes stale. `ChunkQueueSource` reads the Isar collections ADR-039 placed in `features/recording/data/collections/`, and ADR-040 records the contract that lets `features/upload/` see them.

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

#### ~~`local_chunks.s3_object_key` is stored null~~ — PREMISE CORRECTED

> **Corrected 2026-08-15 by Mission 4.2. The column is still null; the reason recorded below is wrong.**
>
> This entry, and open item 3, both assume **the client composes the S3 key**. It does not, and no chapter ever said it did.
>
> - **Volume 4 Chapter 4.10 §2 step 1:** *"Mobile app calls `POST /v1/sessions/{id}/chunks` (Chapter 4.6); **the Lambda computes the deterministic key (Volume 5.14)** and returns a set of presigned multipart upload URLs."*
> - **Volume 4 Chapter 4.6 §5** shows `s3_object_key` as a **response** field. The request body is `{ "sequence_index", "file_size_bytes", "checksum_sha256" }` — no `org_id`, no `project_id`, no `task_id`.
> - **Volume 5 Chapter 5.14 §1** is authoritative for the pattern *on both sides*, but §2 gives the client's own use of it: `<app-documents>/recordings/{session_id}/{sequence_index:04d}.mp4`, which *"omits org/project/task since those are already implied by the session (a lookup, not a duplication)"*.
>
> So the missing `org_id`/`project_id`/`task_id` were never a blocker for the key. **The column is null because registration has not happened yet**, and `ChunkUploadSource.recordObjectKey` fills it from the response.
>
> **The gap is real but it sits one level up, and it is harder than the one described.** Chapter 5.10 §1 step 1's URL needs a *backend* session id, from `POST /v1/tasks/{id}/sessions` (Ch. 4.6 §4) — an endpoint Chapter 5.10 never mentions, nested under a Task. `LocalSession.taskId` is null on every row this application has written. `SessionRegistrar` names that port; nothing in `lib/` implements it, and `features/projects_tasks/` still owns closing it.
>
> The "Blocked on" row below is therefore right about the blocker and wrong about the mechanism. `org_id` in particular is **not** the harder half — it is not the client's problem at all.
>
> `ChunkRecordMapper.toLocalChunk`'s doc carried the same wrong premise and is corrected in place, struck through, at the same date.

<details>
<summary>Original entry, retained</summary>

| | |
|---|---|
| **Why deferred** | Chapter 5.14 §1's key is `{org_id}/{project_id}/{task_id}/{session_id}/{sequence_index:04d}_{chunk_id}.mp4`. Three of the five components — `org_id`, `project_id`, `task_id` — have no source in this application (A-062). |
| **Why null rather than a placeholder** | A key composed from placeholders would look deterministic, index as unique, and be wrong — and Chapter 5.13 §4 requires every retry to reuse *"the exact same deterministic S3 key"*, so a wrong key minted once would be reused forever by design. Null is the value that cannot be mistaken for a real key. Volume 4 Chapter 4.4 §6 marks the column UNIQUE and NOT NULL, which is a **backend** constraint; the row is only sent once the key exists. |
| **Owner** | **Chapter 5.10 (Upload Pipeline) §1 step 1**, *"Register `POST /v1/sessions/{id}/chunks` → presigned multipart URLs"* — the step that needs the key and the first that cannot proceed without it. Projected Mission 3.9. |
| **Blocked on** | `features/projects_tasks/`, which is unbuilt — its `domain/`, `data/` and `application/` are still `.gitkeep`. `TaskContext` is the port that would supply `project_id` and `task_id`; `org_id` has no identified source at all and is the harder half. |
| **Consequence of leaving it** | The column is unreadable by anything today, because no upload path exists. It becomes blocking exactly when Chapter 5.10 runs, and not before. |

</details>

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
> **Re-measured 2026-08-15 by Mission 4.1.** `recording/data` has fallen further, to **69.25% (223/322)**, and the cause is this mission's own code: `IsarChunkStore` gained 32 lines implementing `ChunkQueueSource`, none of which a unit test can reach for the reason §"the whole shortfall is one file" already gives — they need a live Isar engine. **Excluding that file the data layer is still 92.02%**, unchanged, because every new uncovered line landed in it.
>
> The miss is therefore wider in the number and identical in cause. No network-downloading test dependency was added, and the exemption reasoning is not re-argued here.
>
> Mission 4.1's own new code is covered: `core/queue/` 100% (30/30), `features/upload/application/` 96.15% (25/26 — the uncovered line is the port's `UnimplementedError`, which by design nothing reaches).
>
>
> **Re-measured 2026-08-15 by Mission 4.2, and the number moved again.** `recording/data` is now **63.82% (284/445)**. Same cause, larger: `IsarChunkStore` grew from 52 lines to **146** implementing `ChunkUploadSource` and `ChunkMetadataSource`, and measures **2.74% (4/146)**. Every one of those lines needs a live Isar engine.
>
> **Excluding that file the data layer is 93.65% (280/299)** — *higher* than the 92.02% recorded at 4.1, because `ChunkMetadataDocumentMapper` landed at 100% (50/50). So the layer's testable half improved while its headline fell, which is exactly the shape this entry has described since Mission 3.10.
>
> Mission 4.2's own new code: `core/upload/` **92.50% (111/120)** — the nine uncovered lines are `upload_ports.dart`'s three `UnimplementedError` throws, which by design nothing reaches; `core/network/` **89.90%**, with `vump_api.dart`, `transfer_handle.dart` and every `core/upload/metadata/` file at **100%**; `features/upload/` **83.08%**, of which `chunk_registration.dart` is 100% and the remainder is presentation screens Mission 4.4 owns.
>
> **Two gaps were found by reading uncovered lines rather than accepting a percentage, and closed rather than excused**: `chunk_registration.dart` was at 11.76% (2/17) — a `domain/` file, against Chapter 9.5 §2's 90% target — and `vump_api.dart` at 64.58%. Both are now 100%. This is the third re-measurement and the second time the read found real gaps; open item 23's argument holds.
>
> This is the **second** time the register cross-check has found drift, after A-057 and A-063 §5 at Mission 3.10. It is the argument for open item 23: a percentage recorded in prose goes stale the moment anyone adds a test, and only a scheduled re-check catches it.

**Chapter 9.5 §2 names three layers and gives `application/` no numeric target.** Chapter 9.6 §1 instead requires *"every Riverpod Notifier's state transitions, using ProviderContainer overrides"*, which is a completeness rule and is satisfied — `RecordingNotifier` and `ChecklistNotifier` both have transition suites built that way. The 86.36% is reported for information, not against a target.

### The whole shortfall is one file

~~`isar_chunk_store.dart` measures **7.69% (4/52)**. Excluding it, the data layer is **92.02% (219/238)**~~ — **as of Mission 4.2, 2.74% (4/146) and 93.65% (280/299)** — comfortably past the target either way, and error-path-weighted as Chapter 9.1 requires. The file has tripled in size across 4.1 and 4.2 and its coverage has fallen accordingly; the cause has not changed.

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

### Guard 1 — client-side, owed to Mission 4 — **CLOSED 2026-08-15 by Mission 4.2**

~~`ChunkMetadata.isIdentityComplete` exists for exactly this and **has no caller**. Volume 5 Chapter 5.10 §1 step 1 is *"Register `POST /v1/sessions/{id}/chunks` → presigned multipart URLs"*, and Chapter 5.14 §1's key embeds `project_id`, `task_id` and `session_id`. Registration must check `isIdentityComplete` **before composing a key** or sending a metadata document, and refuse rather than send blanks.~~

> **Corrected and closed 2026-08-15, Mission 4.2.**
>
> **The wording above is wrong in one clause.** *"Before composing a key"* assumes the client composes the S3 key. It does not — Volume 4 Chapter 4.10 §2 step 1 has the Lambda compute it and return it, and Chapter 4.6 §5's registration body carries no ids at all. See A-063 §5's correction.
>
> **Restated:** the check happens **before registration** — before Chapter 5.10 §1 step 1, and therefore before any network call of any kind.
>
> **As built.** `ChunkUploadPipeline._run` claims the chunk, loads its metadata document, and checks `ChunkMetadataDocument.isIdentityComplete` before touching `SessionRegistrar` or the API. A chunk that fails is marked `failed` with the named cause `UploadFailureCause.identityIncomplete` — Chapter 5.13 §1's **terminal, device-side** class, *"not retried automatically … surfaces immediately as Failed with a specific, named cause"*. Not silently skipped, not silently sent, exactly as this entry required.
>
> The refusal names each missing field individually (`project_id, task_id, collector_id, device_id`), because Chapter 2.9 §2 treats a failure that does not *"name the specific cause"* as a defect.
>
> **The check is on the projection, not on `ChunkMetadata`.** `ChunkMetadataDocument.identity` carries nullable fields, so a stored blank stays blank and a stored null stays null; nothing is substituted anywhere on the read path. That is what let the reverse mapper `ChunkRecordMapper` refused to write be written safely — see A-071.
>
> **So `ChunkMetadata.isIdentityComplete` — the domain getter this entry originally pointed at — still has no caller, and that is correct rather than an oversight.** It guards the object at generation time, where every field is non-null by construction and the check can only ever be about the sentinel. The upload path reads a stored row, not a generated object, and `features/upload/` may not name `ChunkMetadata` at all under ADR-022 R3. Two getters, one rule, two sides of the storage boundary. Verified uncalled by grep at Mission 4.2's close.
>
> **It currently refuses 100% of chunks recorded on a device**, because four of `MetadataIdentity`'s five fields still carry the unsourced sentinel. That is the guard working, and it is the honest state of the feature. Tested against both a synthetic complete-identity chunk and a real unsourced one.
>
> **Guard 2 remains open.** Client-side checks are a correctness measure, not a security boundary; this closing does not discharge the server-side rule below.

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

### Widened 2026-08-15 by Mission 4.1 — the collision is systemic, not one number

This is not confined to Volume 8. **Volume 3 Chapter 3.2 carries its own inline ADR sequence** that collides across the board:

| Volume 3 Ch. 3.2's inline ADR | This repository's ADR |
|---|---|
| ADR-001 — State Management Library | ADR-001 — Clean Architecture |
| ADR-002 — Local Persistence Engine | ADR-002 — Top-Level Project Structure |
| ADR-003 — Background Upload Mechanism | ADR-003 — Riverpod |

Volume 5 Chapter 5.8's own header compounds it, citing *"Drift (SQLite) — **ADR-002**, Volume 3, Chapter 3.2"* — a database decision pointed at this repository's project-structure ADR.

**The general rule, stated once so it is not re-litigated volume by volume: no `ADR-NNN` citation appearing inside any Volume can be assumed to mean this repository's ADR-NNN.** Always resolve against `docs/architecture/decisions/ADR-*.md` by subject, never by number.

Sweeping every Volume for this collision is recorded as open item 34 and is deliberately not attempted here.

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

### A-071 — Chapter 5.10 §1 step 1 does not compose the S3 key, and the register said it did

| | |
|---|---|
| **Volume** | 5, Chapter 5.10 §1 step 1 and Chapter 5.14 §1/§2; Volume 4, Chapter 4.6 §5 and Chapter 4.10 §2/§5 |
| **Says** | Ch. 5.14 §1 gives the key as `{org_id}/{project_id}/{task_id}/{session_id}/{sequence_index:04d}_{chunk_id}.mp4` and calls itself *"its authoritative source, since it must be computed identically on the mobile client … and the backend"* |
| **Should say** | Nothing — **the chapters are correct**. What was wrong is this register's reading of them |
| **Class** | Correction to A-063 §5 and open item 3 |
| **Status** | Corrected; the underlying gap re-scoped and still open |

**Found by Mission 4.2 while tracing Chapter 5.10 before writing any code.**

Ch. 5.14 §1's sentence about computing the key identically on both sides was read as *"the client composes the key"*. It does not. Both sides compute the **pattern** identically; they use it for different things. Ch. 5.14 §2 gives the client's use — a local path that *"omits org/project/task since those are already implied by the session (a lookup, not a duplication)"*.

Volume 4 settles it twice, unambiguously:

- **Ch. 4.10 §2 step 1:** *"the Lambda computes the deterministic key (Volume 5.14) and returns a set of presigned multipart upload URLs."*
- **Ch. 4.6 §5:** `s3_object_key` is a **response** field. The request body is three fields — `sequence_index`, `file_size_bytes`, `checksum_sha256`.

So `org_id`, `project_id` and `task_id` were never inputs the client had to supply for the key. `org_id` in particular was recorded as *"the harder half"* and is not the client's problem at all.

### The gap is real, and it moved up a level

`s3_object_key` is still null locally, because registration has not happened. What blocks registration is not the key:

**Chapter 5.10 §1 step 1's URL is `POST /v1/sessions/{id}/chunks`, and `{id}` is a backend session id.** That comes from `POST /v1/tasks/{id}/sessions` — Volume 4 Ch. 4.6 §4, an endpoint Chapter 5.10 never mentions — which is nested under a Task. `LocalSession.taskId` is nullable and null on every row this application has ever written.

`SessionRegistrar` (`core/upload/interfaces/`) names that port. Nothing in `lib/` implements it; `sessionRegistrarProvider` throws, a fake satisfies it in the test suite, and `features/projects_tasks/` owns closing it.

### Two places carrying the wrong premise, both corrected at the same date

- **A-063 §5 / open item 3** — struck through with the correction above them, entries retained.
- **`ChunkRecordMapper.toLocalChunk`'s doc comment** — the paragraph explaining why `s3ObjectKey` stays null is struck through in place and replaced.

### What this changes about Mission 4.2's design

Nothing was built on the wrong premise, because the trace ran first. `UploadableChunk.s3ObjectKey` is documented as *received*, `ChunkUploadSource.recordObjectKey` stores it from the registration response, and a test asserts the request body carries no `org_id`, `project_id` or `task_id`.

**The reason this was worth catching before writing code**: composing a key from four unsourced ids would have produced a plausible-looking value, and Chapter 5.13 §4 makes every retry reuse *"the exact same deterministic S3 key"* — so a wrong key minted once would be reused forever, by design.

### The read-back mapper `ChunkRecordMapper` declined to write

Separate finding, recorded here because it was resolved by the same work. That class states there is no `fromLocal*` *"and that is a decision"*, because a reverse mapper *"would have to substitute empty strings, and an empty `collector_id` that reached an upload would be indistinguishable from a real one"*, naming the Upload Queue as the consumer that would eventually need one.

Mission 4.2 is that consumer, and the hazard was answered rather than overruled: `ChunkMetadataDocumentMapper` produces a `ChunkMetadataDocument` whose identity fields are **nullable**, so a stored null arrives as null and a stored blank arrives as blank. Nothing is substituted, and A-068 Guard 1 is what refuses it. The unsafe direction — a domain object with five required fields built from a row with five nullable ones — is still unwritten, and should stay that way. `ChunkRecordMapper`'s doc carries a dated note saying so.

---

### A-072 — No field bandwidth-floor NFR exists, so the S3 upload has no send timeout

| | |
|---|---|
| **Volume** | 1, Chapter 1.4 (the whole NFR table); Volume 9, Chapter 9.4 §1; Volume 5, Chapter 5.13 §1 |
| **Says** | Nothing. The word *timeout* appears **once in all fifteen Volumes** — Ch. 5.13 §1's failure table, as an example of a transient failure, with no value |
| **Should say** | A minimum field connection speed, from which a transfer timeout could be derived |
| **Class** | Missing requirement — a product decision, deferred |
| **Status** | Open, deliberately not raised inside an implementation mission |

**Searched before implementing, at Mission 4.2's explicit instruction: all fifteen PDFs, for `mbps`, `kbps`, `bandwidth`, `throughput`, `connection speed`, `upload speed`, `minimum connection`, `2G`/`3G`/`4G`/`LTE`, and `timeout`.** Nothing.

The nearest requirements answer different questions. **NFR-AVL-02**'s *"< 30 seconds"* is how fast an upload **resumes** after connectivity returns, not how fast it transfers. **Volume 9 Ch. 9.4 §1** has no throughput row at all. **Volume 0 Ch. 0.1 §4** lists chunk upload latency as a metric to be *measured after launch* *"under normal network conditions"* — a phrase it never defines. Volume 1 Ch. 1.4's own preamble concedes its targets are *"initial engineering targets … tightened or relaxed once a pilot cohort of Collectors provides real usage data"*.

### It could not have come from a byte count either

Volume 4 Ch. 4.6 §5 returns `upload_urls` as a **list**, and Ch. 4.10 §2 confirms the Lambda generates the set. **The backend chooses the part count**, so part size is `fileSizeBytes / uploadUrls.length` — a runtime value, different per chunk. No compile-time constant can describe it.

### The decision, and why a guess would have been worse than none

`NetworkConstants.uploadSendTimeout` is `null` — Dio's "no send timeout". `connectTimeout` still bounds reaching the host, `receiveTimeout` still bounds S3's response, and `TransferHandle` gives explicit cancellation.

Ch. 5.13 §1 classifies a timeout as **transient**, and §2 grants six automatic attempts. A value set too low against a slow but working field connection would not present as a configuration mistake — it would silently consume the retry budget and surface to the Collector as *"Failed"*, with the true cause invisible. An absent timeout fails visibly, when it fails at all.

**What is genuinely unbounded**: a socket that accepts bytes forever without completing. Named, not solved.

### Deferred, not resolved

Establishing a field bandwidth floor is a product decision about the conditions Collectors work in, not an engineering one, and it belongs in its own conversation rather than inside an implementation mission. This constant becomes derivable the moment that NFR exists. **No number was proposed and none was guessed.**

---

### A-073 — The local `complete` is written after step 4, and Chapter 5.10 §1 puts it at step 3

| | |
|---|---|
| **Volume** | 5, Chapter 5.10 §1 steps 3–5; Volume 4, Chapter 4.6 §4; Volume 1, BR-08; Volume 5, Chapter 5.15 |
| **Says** | Step 3: *"Confirm `PATCH /v1/chunks/{id}/status` `'uploading'` → `'complete'`"*. Step 5: the device's queue *"observes `chunks.status='complete'` via its next sync and updates the local row to match"* |
| **Should say** | The **local** row reaches `complete` only after step 4's metadata POST succeeds |
| **Class** | Deliberate divergence from the chapter's literal ordering |
| **Status** | Implemented and recorded |

**Two problems with following §1 literally.**

First, **step 5's "next sync" does not exist**. No sync mechanism is built and none is in Chapter 5.10's scope. Read strictly, nothing would ever write the local `complete` at all.

Second, and the reason for the divergence: **BR-08 makes `complete` the point a chunk becomes eligible for local deletion**, and Chapter 5.15 owns acting on that. If the local row were marked `complete` at step 3 and the step 4 metadata POST then failed, the chunk's file would become deletable while its metadata had never reached the backend. Volume 4 Ch. 4.5 §4 makes that unrecoverable: BR-22 rejects any later PATCH of system-generated metadata, so the record could not be completed afterwards.

### Why this is a divergence and not a contradiction

Volume 4 Ch. 4.6 §4 makes `'complete'` *"gated server-side"*, so a success on step 3's PATCH **is** the backend confirming — the chapter is right that step 3 is where the authoritative transition happens. What Mission 4.2 changes is only when the **device** writes its copy of that fact, and it costs nothing to wait one call.

`ChunkUploadPipeline` therefore calls `markComplete` after step 4. A metadata failure leaves the chunk `failed`, retryable, with its file intact. Two tests pin it: one asserts `complete` is the last transition and follows the metadata call; the other scripts a step 4 failure and asserts the chunk is `failed` and never `complete`.

### What this does not do

It does not invent a reconciliation pass. Step 5's sync — reconciling a local row against the backend after a dropped response — is still unbuilt, and belongs to Chapter 5.12 or Chapter 5.15 rather than here.

---

### A-074 — A presigned S3 URL is a bearer credential, and nothing in this project strips a query string

| | |
|---|---|
| **Volume** | 4, Chapter 4.10 §2/§3; Volume 8, Chapter 8.2; Volume 5, Chapter 5.10 §1 step 2 |
| **Says** | Ch. 4.10 §2: *"the mobile app never holds a raw AWS credential"*. Ch. 4.10 §3: *"presigned URLs are HTTPS and time-limited"* |
| **Should say** | And they must never be logged — a presigned URL **is** a credential, in the query string |
| **Class** | Security consideration, designed against before the risk existed |
| **Status** | Mitigated at design time; **flagged for re-verification in Mission 4.8's security review** |

**Raised in Mission 4.2's design report, before any code was written, and recorded here at the mission's instruction rather than left as design-report prose.**

### The exposure

`LoggingInterceptor` writes `options.uri` **in full** — query string included — on request (line 42), response (line 58) and error (line 72). A presigned S3 URL carries `X-Amz-Signature` and `X-Amz-Credential` as **query parameters**. Anyone holding that URL can write to the bucket until it expires.

`NetworkConstants.redactedHeaders` redacts seven header names. **Nothing in this project redacts a query string**, and nothing ever needed to before: no code outside `core/network/` had made an HTTP request.

There is a second path to the same leak. `ErrorInterceptor.mapToNetworkException` builds its message from `err.requestOptions.uri`, and `AppException.toString()` writes its `cause` — which for a `DioException` prints the request URI again. Either would put a live signature into a log line or an error surface.

### The mitigation

`S3TransferClient` installs **no interceptors at all**:

- **No `AuthInterceptor`** — for a different reason: S3 rejects a presigned request carrying a conflicting `Authorization` header. It also means the client structurally cannot send a Vump credential to Amazon.
- **No `LoggingInterceptor`** — it logs through `AppLogger` directly, with every URL passed through `S3TransferClient.redactUrl`, which reduces it to scheme, host and path.
- **No `ErrorInterceptor`** — `_convert` reuses `mapToNetworkException` for its **classification only**, then rebuilds the exception with a redacted message and **no `cause`**.

**Dropping `cause` is a real diagnostic loss and is deliberate.** The status code, the Dio failure type and the redacted URL are kept, which is what a failed upload is actually diagnosed from.

`ChunkRegistration.toString()` prints the part count and never the URL list, for the same reason.

### Why this is recorded rather than treated as a finding

No shipped code leaked anything: this is a design decision taken before the surface existed. It is written down so it can be **re-verified against real code later rather than assumed from the mission that wrote it** — the same discipline open item 32 argues for.

**Owed to Mission 4.8's security review as a confirmed-safe item**, with the reasoning above to check against. What it must re-verify: that `redactUrl` is still applied at every log site in `S3TransferClient`; that no interceptor has been added to it; that no other code path prints a presigned URL, including through an exception's `cause`; and that `ChunkRegistration.toString()` still omits the list.

### A related gap this leaves open

**`LoggingInterceptor` still logs full URIs for every other request.** No Vump endpoint puts a secret in a query string today, and Ch. 4.6 §1 uses cursor pagination rather than tokens-in-URLs, so nothing is exposed. But the redaction mechanism is header-only, and a future endpoint taking a signed parameter would leak it silently. Not fixed in Mission 4.2 — out of scope, and a change to a verified path — but named here so 4.8 can decide.

---

### A-075 — The confinement check matched text, not imports, and failed on a true statement

| | |
|---|---|
| **Volume** | Not a Volume finding — a defect in this repository's own CI |
| **Class** | Enforcement precision |
| **Status** | Fixed 2026-08-15 by Mission 4.2, verified by deliberate breakage |

The `Architecture boundaries` job's `check()` grepped for the bare string `package:<name>` anywhere in a `.dart` file.

Mission 4.2's full sweep tripped it **twice in one run**, on two files whose **doc comments stated that they deliberately do not import the confined package**:

- `features/upload/data/chunk_upload_api_impl.dart` — a comment stating the file imports no dio
- `features/recording/data/chunk_metadata_document_mapper.dart` — a comment stating it names the `Embedded*` types but never isar itself

Both statements were true, and both failed the check.

**A rule that fails on a true statement about itself teaches people to stop writing the statement** — which is exactly the documentation this project relies on to explain why a boundary holds.

The matcher now anchors on `import`/`export` directives. No coverage is lost: a package can only be used by importing it, and `export` is checked so a re-export cannot smuggle one across a boundary. Verified by injecting a real dio import into `features/upload/data/` — still `EXIT=1` — and removing it — back to `EXIT=0`.

**Worth noting for the register's own sake**: this is a false *positive*, the opposite of S1 (A-067)'s false negative. Both come from the same place — a rule whose implementation is not quite the rule it states.

---

### A-076 — `DioClient`'s own signature leaked Dio, and the rule was green only because nothing used it

| | |
|---|---|
| **Volume** | Not a Volume finding — ADR-007 and ADR-030's confinement, against Mission 0.10's client |
| **Class** | Latent boundary violation, surfaced by the first real consumer |
| **Status** | Resolved by ADR-041's `VumpApi`; recorded because of what it says about the check |

`DioClient.post` and its siblings return `Future<Response<T>>`. `Response` is a Dio type, so **any caller outside `core/network/` must import `package:dio`** — which the confinement job forbids.

This has been true since Mission 0.10. It was never detected because **nothing outside `core/network/` had ever called `DioClient`**: `features/auth/data/` talks to Firebase, and Mission 3.11's review confirmed the recording feature makes *"no `dio`, no `http`, no socket"*. Mission 4.2 is the first feature consumer and hit it immediately.

### The pattern this belongs to

**Fourth instance of "a whole checked in parts"** (cf. open items 23, 26, 32). The confinement rule was not holding — it was untested, and a rule with no subject passes trivially. Same shape as ADR-022 R3, which A-040 recorded as *"binding in writing and unenforced in fact"* while there were no features to check.

The general lesson, stated once: **a green check over an empty set is not evidence.** Worth asking, at each mission that introduces a first consumer of anything, which dormant rules that consumer has just woken up.

### The resolution, not a widening

`core/network/` publishes `VumpApi`, which returns plain maps. `DioClient` is unchanged. ADR-041 has the full argument, including why widening `dio`'s confinement to `features/upload/data/` was rejected.

---

### A-077 — Chapter 5.11's header cites Volume 3's internal ADR-003, which is this repository's Riverpod record

| | |
|---|---|
| **Volume** | 5, Chapter 5.11 header — *"Expands ADR-003 (Volume 3, Chapter 3.2)"* |
| **Says** | ADR-003 |
| **Means** | Volume 3 Chapter 3.2's **own** ADR-003 — Background Upload (Android) — summarised in Volume 3 Chapter 3.1 §2's stack table |
| **This repository's ADR-003** | State management (Riverpod) |
| **Class** | Citation collision. **Third instance in three missions** |

Volume 3 Chapter 3.1 §2's table is the actual authority Mission 4.3 implements against, and it names the package outright: *"A foreground service (`flutter_foreground_task`) driving Dio multipart uploads, with a persistent, dismissible-only-on-completion notification."* The package choice is therefore **transcribed, not taken** by this mission.

Volume 3's internal sequence, read off that table for anyone who hits this again: ADR-001 state management, ADR-002 local persistence, **ADR-003 background upload (Android)**, ADR-004 Dio, ADR-005 go_router, ADR-006 dependency injection.

### The pattern, now proven by repetition rather than argued

Four missions, four collisions — the first three found by whichever chapter happened to be read, the fourth by consulting this table:

| Mission | Citation | What it means here |
|---|---|---|
| 4.1 | V8 Ch. 8.2 §3's "ADR-011" | Not this repo's ADR-011 (S3 storage) — A-069 |
| 4.2 | V5 Ch. 5.10 §2/§4's "ADR-004" | Real record is ADR-007 (network), not GoRouter — open item 34 |
| 4.3 | V5 Ch. 5.11's "ADR-003" | Real record is V3 Ch. 3.2's own ADR-003, not Riverpod |
| **5.1.1** | **A mission brief's "ADR-006 (fake repository / provider interface pattern)"** | **Real record is V3 Ch. 3.2's own ADR-006 — Dependency Injection Approach. This repo's ADR-006 is Centralised Application Configuration** |

Open item 34 recommended a single sweep listing every inline `ADR-NNN`. That recommendation is now **four-for-four** and is restated with more force below. Not attempted here — out of scope for 4.3 as it was for 4.1 and 4.2, and for 5.1.1.

### The fourth instance, 2026-08-16, Mission 5.1.1

The brief for 5.1.1 named *"ADR-006 (fake repository / provider interface pattern)"* as governing a new feature's fake repository. **This repository's ADR-006 is Centralised Application Configuration** — `app/config/`, `AppInfo`, `AppEnvironment` — and has nothing to do with repositories, fakes or providers.

The record actually meant is **Volume 3 Chapter 3.2's internal ADR-006, Dependency Injection Approach**, which names the pattern outright: *"Repositories (Auth, Projects/Tasks, Recording, Upload, Metadata) need to be constructed once and made available throughout the app, and swapped for fakes in tests"*, resolved as *"Riverpod providers double as the app's dependency injection layer."*

This repository's records for that decision are **ADR-003** — whose own Consequences say *"Overriding a repository with a fake in tests is a first-class Riverpod feature (ProviderScope overrides)"* — and **ADR-022**, which forbids `application/` importing `data/` and so forces the composition-root override.

**Three things separate this instance from the first three, and each matters:**

- **It was resolved by reading this table, not by stumbling into a chapter.** The lookup sequence above was already written down, so the collision cost about a minute instead of a mission. That is the first evidence A-077's table pays for itself, and the first argument for item 34's full sweep that is not purely theoretical.
- **The collision arrived in a mission brief, not in a Volume.** The Volumes are a fixed corpus a single sweep could close. Briefs are written fresh every mission, so **the trap regenerates**: a sweep fixes the source but not the channel.
- **Three ADRs were cited and none of them governed.** The brief also named ADR-035 and ADR-040. ADR-035 governs authenticated requests and binds at Mission 7, not at a fake. ADR-040 governs feature↔feature contracts and does not bind at all in a sub-mission that is entirely intra-feature. The brief's own instruction — *"confirm which of these actually govern … do not assume all three apply equally"* — was right, and the answer was **none of the three as cited**; the governing set is ADR-001, ADR-003 and ADR-022.

**The generalisation worth carrying past the Volumes:** any `ADR-NNN` written outside `docs/architecture/decisions/` — in a Volume, a brief, a commit message or a doc comment — is ambiguous until resolved against the real files. The same failure has now reached shipped code once: `session_registrar.dart` cited *"Volume 11's M12 gate"* for the no-fakes-in-a-release-build rule, which is **M8 — APIs Integrated**; M12 is Store-Ready and says nothing about fakes. Corrected this mission in its own commit.

### A secondary, smaller mismatch in the same chapter

§1 attributes the persistent notification to *"Chapter 2.9's honest-signal principle"*. **No such phrase exists in Chapter 2.9.** The nearest real clause is §2 principle 3, *"Background work stays visible, never invisible"*, which supports the requirement fully. Cited as §2 principle 3 in code rather than by the invented name.

---

### A-078 — Chapter 5.11 §3's concurrency bound has no number, and two is provisional

| | |
|---|---|
| **Volume** | 5, Chapter 5.11 §3 |
| **Says** | *"Uploaded with limited concurrency (a small fixed number in parallel, not all at once) to avoid saturating a constrained field connection and starving the Recording Pipeline (Ch.5.4) of CPU/network priority"* |
| **Omits** | The number. No Volume states one |
| **Decision** | **Two**, provisional, recorded rather than derived |

### Why two, stated as a choice and not as a derivation

Two is the smallest number that is still parallel. It satisfies §3's requirement — *"not all at once"* — while conceding the least to a field connection nobody has measured. There is no calculation behind it, and this entry exists so nobody later reads `defaultConcurrency = 2` as if there were.

### Why A-061's three was not reused, explicitly

A-061 fixed a concurrency bound of three for **chunk processing**, and derived it: a 600 s chunk boundary against roughly 12 s of processing, plus Chapter 5.4 §2's low-storage path forcing an early boundary at Mission 3.3's 5 s poll. Every term in that derivation is about disk and CPU during capture. None of it says anything about upload bandwidth.

Transcribing three here would have looked like a citation and been a coincidence. That is the failure mode A-071 caught in time on the S3 key — a plausible-looking value, minted once, then reused forever by design.

### What would replace it

A pilot measurement on a real field connection, or the bandwidth-floor NFR open item 35 is already waiting on (A-072). Either turns the constant into a derived value. Until one exists, `UploadDispatcher.defaultConcurrency` is a named constant with this entry behind it, and the bound is constructor-injected so a measurement can be applied without touching the dispatcher's logic.

---

### A-079 — The wake lock is held for the service's active life, not per transfer

| | |
|---|---|
| **Volume** | 5, Chapter 5.11 §1 |
| **Says** | *"The service holds a partial wake lock only while actively transferring bytes — not for its entire lifetime — to limit battery impact during any idle gaps between chunks"* |
| **Divergence** | The lock is held for the service's active life |
| **Class** | Deliberate divergence, not an omission |

### The mechanical constraint

`allowWakeLock` is a field on `ForegroundTaskOptions`, fixed when the service starts. The only way to change it on a running service is `FlutterForegroundTask.updateService(foregroundTaskOptions: …)`.

### Why the literal reading was rejected

Honouring §1's wording means an `updateService` call around **every chunk** — which re-enters the notification flicker §1 itself names two bullets earlier as the reason the service is *"not restarted per chunk"*. The chapter's two requirements point in opposite directions at this granularity.

The saving is also smaller than the sentence implies. §1 scopes the cost to *"idle gaps between chunks"*, and the dispatcher only holds the service open while it is actively draining a queue: the gaps in question are the milliseconds between one `claimNext` and the next, not idle stretches. A device with nothing to upload has no service running and no lock held at all, because the service stops the moment the batch drains.

### What is bounded instead

The lock's lifetime is bounded by the **drain**, not by the app's lifetime. That is the property §1 is protecting — a lock held while nothing is happening — and it is delivered by the service's stop condition rather than by the flag.

### What would change this

A measured battery cost attributable to the inter-chunk gaps, or a plugin release exposing a wake lock independent of the notification. Neither exists today.

---

### A-080 — Manual upload mode has no source, and the dispatcher reads Chapter 5.9 §4's other branch

| | |
|---|---|
| **Volume** | 5, Chapter 5.9 §4; FR-UPL-02 |
| **Says** | *"When a device is configured for manual upload … Chapter 5.11's Background Upload dispatcher does not automatically claim them; it waits for an explicit Collector-triggered upload action instead"* |
| **Reading taken** | Always automatic |
| **Class** | Unimplementable clause — the condition has no source |

Chapter 5.9 §4 makes the dispatcher's behaviour conditional on a device being *"configured for manual upload"*. **Nothing in this application holds that configuration.** There is no `UploadMode`, no setting, no remote flag, and FR-UPL-02 has no surface in Chapter 2.7's screen inventory that would set one. `features/settings/` exists as a directory and is empty.

`UploadDispatcher` therefore always claims automatically, which is §4's other branch and the one every device is on today. §4's own last sentence makes this safe: *"The queue's own model is identical in both modes"* — so adding the condition later changes when `claimNext` is called and nothing about the stored rows.

### No port was built, deliberately

The reflex is a `ManualUploadModeSource` port alongside the other three. Declined: `SessionRegistrar`'s precedent is a port declared for a requirement a **named** chapter states concretely, owed to a **named** future feature. This has neither — no chapter says where the setting lives, and no feature is assigned it. A port here would be a guess about a shape nobody has specified, and open item 21's `recoverableChunkIds()` is the standing example of a method declared before its question was settled and left uncalled for two missions.

Recorded so the gap is visible rather than inferred from an absence.

---

### A-081 — Chapter 5.12 §2's ConnectivityService is implemented by the feature that does not consume it

| | |
|---|---|
| **Volume** | 5, Chapter 5.12 §2 |
| **Says** | *"A dedicated platform service (Volume 3, Chapter 3.4) subscribes to the OS-level network reachability API and exposes a simple online/offline signal to the rest of the app — the Upload Queue (Chapter 5.9) and Background Upload dispatcher (Chapter 5.11) both listen to it, but neither polls it independently, avoiding duplicated battery cost"* |
| **Class** | Placement decision, recorded rather than corrected |
| **Date** | 2026-08-16, Mission 4.4 |

`connectivity_plus` has been confined to `features/recording/data/` since Mission 3.3, because FR-CHK-04's Pre-Recording Checklist was its only consumer. Chapter 5.12's consumer is `features/upload/`, and ADR-022 R3 forbids it importing a sibling feature.

**Resolution: ADR-040's pattern, a fifth time.** `core/connectivity/` holds `ConnectivityStatus` and `ConnectivitySource`; `features/recording/data/ConnectivityPlusConnectivitySource` satisfies it; `features/upload/`'s dispatcher consumes it; neither feature imports the other. `core/connectivity/` is added to the CI check that a contract module names no feature, verified by deliberate breakage.

### The asymmetry, stated rather than glossed

**`features/recording/` now supplies a signal it does not itself consume through this contract.** That is the most lopsided instance of ADR-040 so far — the other four had the implementing feature as a genuine stakeholder in the data.

It was accepted rather than corrected. The alternative is moving the package to `core/connectivity/`, which V3 Chapter 3.4's "Platform Services" layer would suggest — except that layer is the five-layer model **A-038 already superseded**, and the move would edit the checklist path Mission 3 verified on hardware in order to relocate a dependency that is already behind a port. The asymmetry is a naming discomfort; the edit is a risk to working code.

### §2's "neither polls it independently" is satisfied at the plugin, not at the port

There are two ports above `connectivity_plus`, and they ask different questions. `NetworkReader.current()` returns a *kind* (wifi/cellular/none) once, because FR-CHK-04's sentence differs by kind. `ConnectivitySource.watch()` streams a *transition*, because §4's trigger is reconnection and nothing in 5.12 or 5.13 branches on kind.

The composition root passes **one `Connectivity` instance to both**, so there is a single plugin channel and a single platform subscription beneath the two ports. That is the cost §2 is actually about. `connectivity_plus` therefore gains `main.dart` as a second owner in the confinement rule, on exactly the precedent `shared_preferences` set in A-067.

---

### A-082 — Two fields were added to `local_chunks` without a schemaVersion bump

| | |
|---|---|
| **Volume** | Not a Volume finding — `DatabaseConstants.schemaVersion` against ADR-009's migration mechanism |
| **Class** | Decision recorded, so the absent migration is not read as an oversight |
| **Date** | 2026-08-16, Mission 4.4 |

Chapter 5.13 §2's six-attempt budget needs somewhere to live. `local_chunks` gains `uploadAttemptCount` (defaulted `0`) and `nextAttemptAt` (nullable).

**No `schemaVersion` bump, and no migration**, because `DatabaseConstants.schemaVersion`'s own doc says not to: *"Increment only when a change requires existing data to be transformed. Adding a collection or a nullable property does not qualify — Isar handles those implicitly."* Both additions are that kind — Isar returns the default for a property absent from an existing record.

The mission's brief originally specified a bump to 2 with a migration, and it was withdrawn on the ground above. Two further reasons made the withdrawal easy: there are **zero** `Migration` implementations in this project, so the first would have been a no-op written to satisfy a version number and would have established the precedent that additive fields bump the version; and it would have run untested against real chunk rows already on a device Mission 3 verified.

### Why the counter is persisted at all

In-memory would have needed no schema change. It was rejected because the budget would reset on every launch: a chunk that had spent all six attempts would silently receive six more after a restart, which on a crash-looping device is an unbounded retry loop wearing a bounded one's clothes. NFR-REL-04 already requires the queue's state to survive a force-close, and the attempt count is part of that state.

---

### A-083 — Chapter 5.13 §2's five-minute cap cannot be reached, and must not be "fixed"

| | |
|---|---|
| **Volume** | 5, Chapter 5.13 §2 |
| **Says** | *"Exponential backoff: 5s, 10s, 20s, 40s, capped at 5 minutes between attempts. Up to 6 automatic attempts per chunk"* |
| **Class** | Inert clause, recorded so it is not repaired into a behaviour change |
| **Date** | 2026-08-16, Mission 4.4 |

Six attempts have **five** gaps between them, so the delays actually drawn are 5, 10, 20, 40 and 80 seconds. The largest is **80 s against a 300 s cap**. The cap is unreachable by construction.

It is implemented exactly as written anyway. The clause is not wrong, it is inert — and a schedule that ever grew past six attempts would need it. This entry exists because the natural reaction to noticing a dead clause is to make it live, and doing that here would mean stretching agreed retry behaviour to satisfy an arithmetic curiosity. A test pins the largest reachable delay at 80 s and asserts it is below the cap.

**An off-by-one was found and fixed by writing that test.** The first implementation treated `attemptsSoFar` as a zero-based index, so the first failure waited 10 s rather than §2's 5 s. The chapter's own sequence is what caught it.

---

### A-084 — NFR-REL-02's "resume without restarting from zero" is not satisfied

| | |
|---|---|
| **Volume** | 1, Chapter 1.4 §2 (NFR-REL-02); Volume 5, Chapter 5.13 §4 |
| **Says** | NFR-REL-02: *"Chunk uploads shall be resumable after any interruption (app kill, network loss, device restart) — 100% of interrupted uploads resume without restarting from zero."* Ch. 5.13 §4: every retry reuses *"where possible the same in-progress multipart upload ID"* |
| **Reality** | Every retry restarts from part 1 |
| **Class** | Requirement not met, named rather than discovered later |
| **Date** | 2026-08-16, Mission 4.4 |

Nothing stores a multipart upload ID or a record of which parts completed. `ChunkRegistration` carries `uploadUrls` and nothing else, and `ChunkUploadApiImpl` uploads from index 0 on every attempt.

**Deliberately not built in Mission 4.4.** Resuming a multipart upload requires the backend to return an existing `uploadId` and the set of parts it already holds — Volume 4 territory, reachable only through `SessionRegistrar`, which has no implementation (open item 36). Local part-tracking alone would be state with no counterpart on the other side, which is the state-without-policy mistake `ChunkUploadSource`'s own contract warns against.

**What *is* satisfied**: the retry reuses the exact same `chunk_id` and the same deterministic S3 key, so BR-11's no-duplicate guarantee holds. What is missed is only the "without restarting from zero" half — a retry re-sends bytes it already sent. On a 610 MB chunk over a field connection that is the expensive half.

### Two chapter-level citation drifts found alongside it

Distinct from open item 34, which is about inline `ADR-NNN` numbers colliding with this repository's ADRs. These are Volume-to-Volume **chapter** references that point at the wrong chapter:

| Where | Points at | Should point at |
|---|---|---|
| V3 Ch. 3.3 §6 — *"Exact retry/backoff timing and duplicate-prevention mechanism"* | Volume 5.10 | **5.13** (retry) and **5.14** (the key) |
| V1 NFR-REL-03's Target column — *"Verified via idempotency checks"* | Volume 5.10 | **5.13 §4** and **5.14 §3** |

Volume 5.10 is the Upload Pipeline and contains neither the backoff schedule nor the key derivation. Two independent documents making the same wrong reference suggests a single stale source rather than two typos. Recorded here rather than as a new open item, because the fix is a documentation pass someone will do once.

---

### A-085 — Connectivity does not revive a `failed` chunk, because nothing stores why it failed

| | |
|---|---|
| **Volume** | 5, Chapter 5.13 §2; Chapter 5.12 §4 |
| **Says** | An exhausted chunk *"waits for either connectivity/context to change (Chapter 5.12) or a manual retry (FR-UPL-07)"* |
| **Implemented** | An online transition clears backoff deadlines on **`queued`** rows only |
| **Class** | Partial implementation, with the blocker named |
| **Date** | 2026-08-16, Mission 4.4 |

§2's wording reads as connectivity reviving a `failed` chunk as well as releasing a deferred one. Only the second is implemented.

**The reason is that `local_chunks` stores a status but not a failure cause.** Reviving every `failed` chunk on every reconnection would re-attempt the terminal ones too — a 4xx rejection, a missing local file, A-068's incomplete identity — against Chapter 5.13 §1's *"not retried automatically"*. Reviving only the transiently-failed ones needs a stored cause, and adding one now would be a third field with no consumer beyond a clause this mission is not otherwise implementing.

**The Collector is not stuck.** FR-UPL-07's manual Retry Chunk resets the counter and clears the deadline (§3), which is the escape §2 offers alongside connectivity. What is missing is the automatic half.

Closing it needs a `failureCause` column on `local_chunks` and a rule for which causes are revivable — which is the same information C-11 would need to render a specific cause per row, so the two are worth doing together rather than separately.

---

### A-086 — Cleanup trusts the backend's PATCH response, not an observed `verified_at`

| | |
|---|---|
| **Volume** | 5, Chapter 5.15 §2; Volume 4, Chapter 4.5 and 4.6 §4 |
| **Says** | A chunk is eligible *"the instant the Upload Queue (Chapter 5.9) observes its status reach Complete — i.e. the backend has confirmed both the S3 object and its metadata (Volume 4, Chapter 4.5's `verified_at`)"* |
| **Class** | Assumption made explicit, because it is the one place BR-08 could be violated by correct-looking code |
| **Date** | 2026-08-16, Mission 4.5 |

**The device never reads `verified_at`.** It writes `complete` itself, after Chapter 5.10 §1 step 4, on the strength of step 3's `PATCH /v1/chunks/{id}/status` having returned success. Chapter 5.10 §1 step 5 has verification observed *"via its next sync"*, and no sync mechanism exists or is planned in Volume 5.

The chain is coherent on Volume 4's terms. The checksum is sent at registration, so the backend can verify after the S3 PUT; V4 p.15 has the backend set `chunk_metadata.verified_at` and only then allow `chunks.status` to become `'complete'`. A successful PATCH therefore *implies* verification happened.

### The assumption, stated so future backend work must honour it

**A 2xx on that PATCH is taken as permission to delete the only local copy.**

If a Lambda is ever written that returns success on that endpoint without having verified the checksum — during development, behind a feature flag, as a stub — this application will delete the Collector's only copy of footage the backend never checked. BR-08 would be violated by client code that is doing exactly what it was told.

Nothing is at risk today: `SessionRegistrar` has no implementation (open item 36), so no chunk has ever reached `complete` on a device and the sweep has never had anything to do.

**BR-08 itself is satisfied on either reading.** BR-08 says only *"until its upload to S3 is confirmed"*; §2 is strictly tighter. Following §2 satisfies BR-08 with room to spare — the exposure is entirely in whether the backend's gate is real.

### The contradiction this trace found in our own code

`ChunkUploadStatus.complete` carried, since Mission 4.1: *"**Nothing writes this yet**, and nothing should until the backend actually confirms."* Mission 4.2 then wrote it, and the sentence was never updated.

Two missions of drift in a doc comment that Chapter 5.15 keys **file deletion** off. Corrected in place rather than deleted, so the ordering decision (A-073) and the `verified_at` gap are both stated where the next reader will look. Behaviour unchanged: the pipeline still writes `complete` after step 4, for A-073's reason.

---

### A-087 — `localDeletedAt` is the authoritative marker; `localFilePath` is kept

| | |
|---|---|
| **Volume** | 5, Chapter 5.15 §2 |
| **Says** | *"Only the raw video file (and its `local_chunks` row's file reference) is removed"* |
| **Divergence** | The path is left as written; `localDeletedAt` records that the file is gone |
| **Date** | 2026-08-16, Mission 4.5 |

`localFilePath` is `late String`. Blanking it would put an empty string in a column that is otherwise always a real path — the ambiguity A-068 exists to condemn, where a sentinel is indistinguishable from a real value. Making it nullable is a schema change for no gain.

So the path is retained as a record of where the file *was*, and `localDeletedAt != null` is what every consumer tests. Both `cleanableChunks` and `orphanedChunkIds` filter on it, so no code path treats the retained path as live.

**§2's intent is met**: the row no longer references a live file. Only its literal wording diverges.

### A stale engine name, third instance in Volume 5

§3 says *"the local **Drift** copy is retained defensively"*. It is Isar. A-062 §4 found the same name in Chapter 5.7 and A-063 §1 in Chapter 5.8; this is the third. Cosmetic here — §3 changes no behaviour — and recorded only so a fourth discovery is not filed as new.

---

### A-088 — Chapter 5.15 §2 gives no sweep interval and no batch size

| | |
|---|---|
| **Volume** | 5, Chapter 5.15 §2 |
| **Says** | *"a low-priority background sweep, not synchronously at the moment of eligibility … batching it avoids competing with an active Recording Pipeline (Ch.5.4) for I/O"* |
| **Omits** | Both numbers. Nothing in any Volume supplies either |
| **Date** | 2026-08-16, Mission 4.5 |

### The interval is derived, and needs no open item

`StorageCleanupSweep.defaultInterval` delegates to `RecordingLifecycle.chunkDuration`.

The sweep's job is to keep pace with completions. A completion cannot arrive faster than a chunk is produced, and chunks are produced one per chunk boundary — so one sweep per that period keeps pace **by construction**, and §2's *"low-priority"* rules out running more often to do nothing.

Delegated rather than restated, the way `ChecklistOutcome.minimumFreeBytes` already delegates to `RecordingLifecycle.oneChunkBytes`: if the chunk period changes, the sweep follows instead of drifting.

### The batch size is chosen, and does

`StorageCleanupSweep.defaultBatchSize = 10`, **provisional**.

NFR-SCL-01 fixes the depth the system must absorb — *"queue depth of 50+ pending chunks without UI slowdown"* — and ten clears a fifty-chunk backlog in five sweeps while keeping each write short.

**Ten is a fraction of fifty, not a consequence of it.** A file unlink is a directory-metadata operation whatever the 610 MB behind it, so the bound is precautionary rather than measured. Same shape as A-078's concurrency of two: a named constant, an entry saying it was chosen, and an open item for a real measurement. Constructor-injected, so a measurement lands without touching the sweep's logic.

Observed on device: nine chunks and 27.4 MB cleared in a single sweep with `more: false`, so the bound was not even reached in the one real trial available.

---

### A-089 — The status palette is separate from the Material 3 scheme

| | |
|---|---|
| **Volume** | 2, Chapter 2.10 §2.2 against ADR-005's theme |
| **Class** | Placement decision |
| **Date** | 2026-08-16, Mission 4.6 |

Chapter 2.10 §2.2 publishes four validated status colours — good `#0CA30C`, warning `#FAB219`, info/accent `#2A78D6`, critical `#D03B3B`. **Every one differs from the existing token that looks like its counterpart**: `successLight` is `#1B7F4B`, `warningLight` is `#8A5A00`, `primaryLight` is `#2D5BE3`, `errorLight` is `#BA1A1A`.

The existing values are ADR-005's Material 3 tonal palette, chosen before anyone read §2.2. They were **not** overwritten. The four are a *status palette* for Chapter 2.8 §6's pills, not the application's colour scheme: repainting `primary` and `error` app-wide would change every existing screen and re-open ADR-005 to satisfy a pill. `AppStatusColors` carries them as a separate `ThemeExtension` beside `AppSemanticColors`.

---

### A-090 — Chapter 2.8's Design System is not in this repository

| | |
|---|---|
| **Volume** | 2 — TOC, and every *"Component (Ch. 2.8)"* reference in Chapter 2.7 |
| **Says** | Chapters 2.6 and 2.8 are *"delivered as standalone interactive HTML mockups"* — `wireframes.html`, `design_system.html` |
| **Reality** | Neither file exists anywhere in this repository |
| **Class** | Missing authoritative source |
| **Date** | 2026-08-16, Mission 4.6 |

Chapter 2.8 is described as *"the living reference for every color, type style, spacing value, and component (buttons, pills, form fields, checklist items)"*. Chapter 2.7 names its components throughout — `pill-queued`, `pill-uploading`, `progress-track`, `progress-fill`, `btn-secondary` — and none of them can be looked up.

### What survived anyway, and what did not

**Survived.** Chapter 2.7's C-11 table fixes the *behaviour* of each pill, and Chapter 2.10 §2.2 preserves the four hex values. Together they were enough to build C-11 without guessing a colour.

**Did not.** No light/dark variants, and **no statement of whether a hue is the pill's fill, its text, or its border**. That is the rule this mission had to invent, and it is marked as invention in `AppStatusColors` rather than dressed as a citation.

### The measurement that shows the hues were validated for something else

§2.2 says the four were *"checked against color-vision-deficiency separation and contrast requirements"*. Used as **fills carrying body text**, three of the four fail WCAG AA:

| Hue | vs white |
|---|---|
| `#0CA30C` good | **3.35:1** ✗ |
| `#FAB219` warning | **1.79:1** ✗ |
| `#2A78D6` accent | **4.42:1** ✗ |
| `#D03B3B` critical | 4.62:1 ✓ |

The accent is the awkward one: white misses by 0.08, and every tinted near-black tried also lands below 4.5 — `#000B18` gives 4.48 — so pure black is the only foreground that clears it.

So the contrast check §2.2 refers to was for a different application, most likely the hue as text or as an accent **on** a light surface rather than as the surface. Found by the contrast test, not by eye; the test now pins all eight foreground/fill pairs at ≥ 4.5:1 in both themes.

---

### A-091 — Mission 4.4 created a conflict between Ch. 2.9 §4.3 and Ch. 5.13 §1; Mission 4.6 resolves it

| | |
|---|---|
| **Volume** | 2, Chapter 2.9 §4.3 against Volume 5, Chapter 5.13 §1 |
| **Date** | 2026-08-16, Mission 4.6 |

Ch. 2.9 §4.3: *"A failed upload never silently retries in a way the Collector can't see."*
Ch. 5.13 §1: a transient failure is *"never surfaced to the Collector as Failed until attempts are exhausted."*

Mission 4.4 implemented the second, and thereby created the first. A chunk in backoff sits at `queued` for up to 80 seconds while retrying — invisibly, because `queued` is also what an untried chunk looks like.

**Resolved rather than recorded.** `QueuedChunk` gains `attemptCount` and `nextAttemptAt`, and the pill reads *"Retrying in 18s"* instead of *"Queued"* whenever a deadline is pending. No schema change — Mission 4.4 already added both columns; this widened the *projection*.

ADR-040 required that widening be deliberate and named a failure cause and an attempt count as the likely candidates. This is that moment for the attempt count, and it is here to satisfy a chapter rather than because it was available.

**The countdown ticks on a one-second timer** — the only polling in this project. A chunk waiting out a backoff changes nothing in the database, so nothing wakes the screen; the timer polls a clock rather than storage.

---

### A-092 — Live progress is in memory; `QueuedChunk` carries only what survives a restart

| | |
|---|---|
| **Volume** | 2, Chapter 2.7's C-11 — *"accent-hue pill with live percentage; progress bar beneath the row, not inside the pill"* |
| **Date** | 2026-08-16, Mission 4.6 |

Byte progress arrives from Dio's send callback many times a second and is meaningless after a restart. Persisting it would be a write storm against a database whose queue is a live watch, and would put a field on `QueuedChunk` that is stale the moment it is read.

So `UploadProgressNotifier` holds it in memory, keyed by chunk id, cleared when a chunk stops uploading. `QueuedChunk` carries what survives a restart; this carries what does not.

`ChunkUploadProgress` is `core/network/`'s neutral stand-in for Dio's callback (ADR-041) and carries **two counters and no identity**, so the pipeline gained `onChunkProgress`, which binds the chunk id known only after the claim. The neutral type was not widened.

---

### A-093 — C-11 renders two of Chapter 2.9 §4.1's three states, deliberately

| | |
|---|---|
| **Volume** | 2, Chapter 2.9 §4.1 |
| **Says** | Network-dependent screens *"distinguish 'loading current status' from 'no data yet' from 'you're offline' as three distinct visual states, never collapsed into one spinner"* |
| **Built** | Loading and empty. **No offline state** |
| **Date** | 2026-08-16, Mission 4.6 |

Offline is not a state of this screen, and Chapter 5.12 §3 is why: offline *"is not a blocked state, only a waiting one"*. The queue keeps every row, and every row still shows its true status. A banner saying *"you're offline"* over a list that is already accurate adds a mode without adding information.

§4.1's rule is written for a screen whose data comes **from the network**. C-11's data is local — Chapter 5.9 §3 makes the queue *"a live view … over `local_chunks.status`"* — so the state §4.1 guards against, a screen that cannot say whether it is empty or merely disconnected, cannot arise here.

Recorded rather than silently skipped. If the Collector should be told the difference anyway, the signal exists: `ConnectivitySource` from Mission 4.4 is already in `core/`.

---

### A-094 — C-11's "uploads aren't running" banner cannot name a cause or a fix

| | |
|---|---|
| **Volume** | 2, Chapter 2.9 §2 principle 1 and §4.3 |
| **Says** | §2: *"Every failure state … must name the specific cause and the specific fix. A generic 'Something went wrong' is treated as a defect, not an acceptable fallback."* §4.3: *"Every error state pairs a plain-language cause with a single, specific recovery action … never an error with no action attached."* |
| **Shortfall** | The banner names what is not working, and can name neither why nor a fix |
| **Date** | 2026-08-16, Mission 4.6.5 |

Open item 60 was the defect this banner fixes: the dispatcher stopped on a wiring fault, logged it, and told the Collector nothing — a real chunk showed an amber `Queued` pill indefinitely, indistinguishable from one waiting its turn.

The banner now says:

> **Uploads aren't running.**
> Nothing is lost — recorded chunks stay on this device until uploads can start again. You can keep recording.

### Why it stops there

**The specific cause is not Collector-facing.** It is that `sessionRegistrarProvider` throws because `features/projects_tasks/` is unbuilt (open item 36). Putting a provider name in front of a Collector is a log line wearing copy's clothes, and it names an internal that will disappear the moment item 36 closes.

**There is no specific fix.** Nothing a Collector does — retrying, reconnecting, restarting — changes it. §4.3 assumes every error has a Collector-side action; this one has none, because the fault is that a feature has not been written yet.

### What it does honour

The system-level fact is knowable and stated exactly: uploads are not running, and no chunk will be attempted. The guarantee BR-08 and NFR-REL-04 actually make is stated too — nothing is lost, the files stay on the device — and the only true action available is given: keep recording.

It is also **not** a fifth chunk status. Chapter 5.9 §1 fixes four states and Chapter 2.10 §2.2 four colours; a dispatcher that cannot start is not a property of any chunk, and painting it onto every pill would say something false about each. The banner sits above the list, and every pill below keeps its own meaning — verified on device.

### Fork C's discipline is intact

Mission 4.6 ships a failed chunk as "Failed" plus Retry with **no** invented cause, because `local_chunks` stores none (open item 53). This banner is a different fact at a different level, not an exception to that rule: it says the *pipeline* is not running, never why a *chunk* failed.

**This shortfall closes with open item 36, not before.** When the upload path exists, the banner stops appearing in normal operation, and a genuine backend failure will have a real cause to name.

---

### A-095 — Golden tests are generated and verified on CI only

| | |
|---|---|
| **Volume** | 9, Chapter 9.7 §2; Chapter 9.5 §1's tooling column |
| **Says** | *"Every reusable Design System component … has a golden test capturing its rendered output in both light and dark theme"*, and *"a golden test failing on an unintentional pixel diff is a hard CI gate"* |
| **Class** | Mechanism decision, filling A-027's open question |
| **Date** | 2026-08-16, Mission 4.7 |

A-027 recorded that `golden_toolkit` is discontinued and that a maintained mechanism had to be chosen. It is chosen: **`matchesGoldenFile`, built into `flutter_test`, with no new dependency at all.** What `golden_toolkit` added was convenience — device configurations, font loading — not the capability. The requirement in §2 never needed the package.

### Why they do not run locally

Flutter renders text differently per host, so a baseline captured on a Windows machine may not match one rendered on `ubuntu-latest` — producing a gate that fails for a reason unrelated to what it guards.

> **Corrected 2026-08-16, same mission.** That reason is **overstated for these particular goldens**, and the correction is recorded rather than the original quietly edited. `flutter_test` loads no fonts, so every glyph and icon in the captured image renders as a **filled box** at exact glyph-advance width. There is no font rasterization to differ between hosts. What the images verify is colour, pill geometry, layout and label widths; the largest source of cross-platform divergence is absent.
>
> What remains genuinely platform-dependent is antialiasing on the rounded-rect edges and the Skia/Impeller version. That is enough to keep the CI-only rule — Flutter's own guidance still restricts goldens to one platform — but not enough to justify refusing to try. The first baselines were therefore generated on Windows and committed **to be judged by CI**, which is a cheap reversible experiment with a useful answer either way. If they mismatch, the job fails with a diff artifact and the bootstrap path below regenerates correct ones.

This repository has carried three checks that were hollow or misleading for structurally similar reasons — a rule with no subject (item 41), a scan pointed at the wrong subtree (item 50), a job that could not start (item 51). A gate that is red for the wrong reason trains people to ignore it, which is the same failure as a gate that is green for the wrong reason.

So the golden tests **skip themselves when `GITHUB_ACTIONS` is unset**. Locally `flutter test` reports them as skipped, which is visible in the runner output rather than silently absent.

### Outcome — closed on run #11, after two informative failures

| Run | Baselines present | Job did | Result |
|---|---|---|---|
| #9 | Windows-generated | verified | **failed** — hosts render differently |
| #10 | none | regenerated on `ubuntu-latest`, uploaded, failed deliberately | **failed by design** |
| #11 | Ubuntu-native | **verified** | **green** — all ten jobs |

The mechanism is proven in both directions: it verifies when baselines exist and regenerates when they do not, and run #10's step results are the exact inverse of #11's. A gate that took the same branch regardless would have looked identical on a green run and told nobody anything.

### The first CI verdict — mismatch, cause inferred rather than read

The Windows-generated baselines were committed and judged by CI on 2026-08-16. **They failed.**

**The cause is inferred, not confirmed, and that is stated rather than smoothed over.** Job logs return HTTP 403 and artifact downloads HTTP 401 without a token, and none was available. What is known from the public step-level API:

| Step | Result |
|---|---|
| Decide whether to regenerate or verify | success |
| **Verify goldens** | **failure** |
| Regenerate / Upload regenerated / Explain | skipped — correct, baselines existed |
| Upload failure diffs | success — `golden-failures`, 32,167 bytes |

`matchesGoldenFile` writes `_masterImage`, `_testImage` and `_maskedDiff` files only when a comparison actually ran and differed; a *missing* golden fails without producing them. 32 KB of diff images is therefore consistent with a real pixel mismatch — the anticipated antialiasing/Skia divergence — but **nobody read a line saying so.** If a future reader gets log access, this is worth confirming or correcting.

The experiment was still worth running: it cost one commit and one CI run, and the alternative was leaving the gate red indefinitely behind a dispatch that could not be triggered.

### A defect the same run exposed: the golden gate leaked into the unit-test job

The `Test` job failed too, and that one was not a mismatch — it was a mistake in how the split was built.

`flutter test --coverage` carried no tag filter. The golden tests skip on `GITHUB_ACTIONS` being **unset**, which is exactly the condition CI does not satisfy, so they ran inside the unit-test job as well as inside the golden job. One pixel diff failed both, and a visual regression would have been reported as a unit-test failure — sending whoever read it hunting for a logic bug that was not there.

Measured rather than inferred: `flutter test` reports 789 passed / 2 skipped locally, and 791 passed with `GITHUB_ACTIONS=true`. With `--exclude-tags golden` added it reports 789 under both.

**This is the third mechanism in one mission that was committed without being exercised**, after the dispatch that could not be triggered (above) and item 51's job that could not start. All three were designed carefully and none was run against the condition it was built for. The pattern is not carelessness about correctness — it is checking the artifact and not the environment it executes in.

### The bootstrap, and why CI cannot commit its own baselines

The original design put bootstrapping behind `workflow_dispatch`. **That was unusable**: GitHub only offers a manual trigger when the workflow exists on the default branch, and `ci.yml` is not on `main` (open item 48). The bootstrap depended on a button nobody can press — a mechanism in name only, and the second time this repository has shipped one (cf. item 51's job that could not start).

The job now decides for itself, on three triggers:

1. **No baselines exist** — regenerate. This is the bootstrap, and it needs no dispatch.
2. **The PR carries an `update-goldens` label** — regenerate. §2 requires an intentional visual change to be *"explicitly regenerating and committing the new golden image as part of that PR"*, which recurs. A commit-message marker cannot serve: a `pull_request` event carries no `head_commit`, and pushes to a mission branch trigger nothing at all.
3. A `workflow_dispatch`, if one ever becomes available.

**Regenerating is never a pass.** That path uploads the images and then exits 1 with instructions. A job that generated its own expected values and reported success would verify nothing — the vacuous-green shape open items 41, 50 and 51 have already cost this project three times.

The workflow stays `contents: read` and cannot commit the images itself, deliberately: **a gate that can rewrite its own expected values is not a gate.**

---

### A-096 — Chapter 9.5 §2's data-layer target is missed by one file, deliberately

| | |
|---|---|
| **Volume** | 9, Chapter 9.5 §2 |
| **Says** | *"Data layer (repositories): 80%+, focused on error-path coverage per Chapter 9.1's rule, not just the happy path"* |
| **Measured** | **68.3%** (505/739) |
| **Class** | Declared trade, not an oversight |
| **Date** | 2026-08-16, Mission 4.7 |

### The number, and what it is actually made of

| Layer | Measured | Target | |
|---|---|---|---|
| Domain | **98.7%** (230/233) | 90%+ | **met** |
| Data | **68.3%** (505/739) | 80%+ | **missed by 11.7 pts** |
| Presentation | 79.3% (660/832) | golden tests, not a percentage | see A-095 |
| `core/` | 85.1% | none stated | — |
| `app/` | 66.2% | none stated (item 24) | — |
| **Total** | **79.3%** (2586/3262) | — | — |

**The miss is one file.** `isar_chunk_store.dart` measures **1.9%** — 4 of 212 lines. Every other file in `data/` is at or above 75%, and **excluding it the layer reads 95.1%** (501/527). This is not a diffuse testing gap; it is one untestable file dominating an average.

It is also a regression: A-066 recorded 76.90% at Mission 3.10, and Missions 4.2–4.6 grew that same file substantially without adding a test to it.

### Why it is untestable, and the trade taken

`flutter test` cannot load `isar_flutter_libs`' native binaries. The only mechanism is `Isar.initializeIsarCore(download: true)`, which fetches a native binary at test time.

**That was considered and declined.** It would put a network dependency into a job that currently has none, add a recurring failure mode to every CI run and every offline developer build, and introduce a downloaded binary nobody has reviewed — a permanent operational cost to move one file's number. **Device verification is therefore the standard for this file**, and Mission 4.5's probe is what discharges it: every write path, including the file deletion Chapter 5.15 added, is exercised against a real Isar on real hardware.

This is a trade, not an oversight, and the cost is real on both sides: the number stays missed, and a regression in that file will be caught by a device pass rather than by CI.

### What would reopen it

- **A-029 / ADR-038's maintenance risk materialising.** Isar 3 is unmaintained and this project depends on an `@experimental` API for a uniqueness guarantee (item 13). If that forces an engine migration, the migration needs a test harness and this decision is void.
- **A defect escaping to a device** that a unit test would have caught — one instance is enough to change the arithmetic.
- **Isar shipping a test-host binary** that needs no download, which removes the objection entirely.

Chapter 9.5 §2's 80% figure is not amended down. The target stands and is recorded as missed; what is amended is the claim that the gap is a testing failure rather than a chosen one.

---

### A-097 — `Project` and `Task` are Chapter 4.4's tables, not Chapter 4.6's catalog

| | |
|---|---|
| **Volume** | 4, Chapter 4.6 §3 (the endpoint catalog) and Chapter 4.4 §2/§3 (the Data Dictionary) |
| **Says** | Ch. 4.6 §3 lists the Projects/Tasks routes; Ch. 4.6 §6 **defers** *"Full OpenAPI/Swagger schema with every field type — an implementation artifact generated in Volume 6"* |
| **Means** | Chapter 4.6 is **not** the authority on entity shape. Chapter 4.4 is |
| **Class** | Source selection, recorded so it is not re-litigated |
| **Date** | 2026-08-16, Mission 5.1.1 |

The obvious reading — trace the domain entities from the endpoint catalog, since that is what the app calls — produces nothing usable. Chapter 4.6 §3 is a table of methods, paths, roles and purposes; the only field list anywhere in the chapter is §5's three-field chunk-registration sample. §6 says outright that the field types are deferred to a Volume 6 artifact that does not exist.

So `Project` and `Task` are traced from **Chapter 4.4's Data Dictionary**, column for column, with nullability preserved:

| Entity | Columns carried | Source |
|---|---|---|
| `Project` | `id`, `org_id`, `name`, `description?`, `created_by`, `created_at`, `archived_at?` | Ch. 4.4 §2 |
| `Task` | `id`, `project_id`, `title`, `instructions`, `reference_examples?`, `created_at` | Ch. 4.4 §3 |

**Nothing was added and nothing was dropped**, with one recorded exception (§below). The point of tracing before typing is that Mission 7 replaces the fake with a repository that calls Ch. 4.6 §3's routes; a domain entity carrying fields the table does not have would make that a rewrite rather than a substitution.

`org_id` and `created_by` are carried although C-04 renders neither. They are non-null columns, and dropping a non-null column means the real repository discards data the backend sent — the first surface needing either (Admin's A-02, any BR-20 assertion) would then widen the entity and every mapper with it.

`archived_at` stays a timestamp rather than narrowing to `isArchived`. Chapter 4.2 §1 makes soft-delete a timestamp deliberately so archived data stays queryable, and no chapter says the Collector's list filters archived Projects — so the entity records the fact and decides nothing about it.

**`reference_examples` is the one reshaped column.** Chapter 4.4 §3 types it nullable `jsonb` and describes it in five words — *"Array of reference media URLs"* — so it is `List<String>` with no element structure invented, defaulting to empty rather than nullable. A null array and an empty array carry the same fact and no chapter distinguishes them, so C-05 and C-06 render one shape rather than branching on a difference that means nothing.

**Session is not this module's entity.** Chapter 4.3 §2 makes `tasks → sessions` 1:N and Chapter 4.6 §4 nests session creation under a Task, but `features/recording/` already owns `LocalSession` and `features/upload/` owns the remote-session port. This module supplies the `task_id` that `POST /v1/tasks/{id}/sessions` needs and stops there.

---

### A-098 — FR-PT-05's `requirements` has no column, and the drift is a product question

| | |
|---|---|
| **Volume** | 1, Ch. 1.3 FR-PT-05 and Volume 2 (C-06, A-05, Task Detail) against Volume 4 Ch. 4.4 §3 |
| **Says** | FR-PT-05: *"display Task Detail including instructions, reference examples, **and requirements**"*. Volume 2 names the same three, three separate times |
| **Omits** | Volume 4 Chapter 4.4 §3's `tasks` table has six columns and **none of them is `requirements`** |
| **Class** | Cross-volume drift. **Not resolved here** |
| **Date** | 2026-08-16, Mission 5.1.1 |

Two readings exist and both are defensible:

- `requirements` is prose already inside `instructions`, and Volume 2 is naming a **heading** rather than a field; or
- `requirements` is a real column Chapter 4.4 omits, and the schema is incomplete.

**Both are product answers dressed as engineering ones.** Folding it into `instructions` encodes the first reading into the type system permanently; adding a `requirements` field invents a column the backend does not have and Mission 7 could not populate. So the field is **omitted from `Task`** and the drift is recorded as open item 69 for a product decision.

The omission is made to fail loudly rather than fade: `task_test.dart` asserts that no `requirements` member exists, so a later mission that adds one without the product answer breaks a test that points here.

When it is settled, the cost is one field added or one doc comment deleted. Neither is a rework, which is why deferring it was cheap enough to be the right call.

---

### A-099 — The Collector's read path and the Admin's write path are two interfaces, decided now and built apart

| | |
|---|---|
| **Volume** | 1, Ch. 1.3 FR-ADM-07 and BR-18; Volume 3 Ch. 3.4 §2 (`ProjectTaskRepository`) |
| **Says** | FR-ADM-07: *"prevent a Collector from creating, editing, or deleting Projects or Tasks, or from assigning Collectors"*. BR-18: *"Only an Admin may create, edit, or delete Projects and Tasks, or assign Collectors"* |
| **Decision** | `ProjectTaskRepository` (read, built 5.1.1) and `ProjectTaskAdminRepository` (write, **declared as a decision, built by 5.2**) |
| **Class** | Design decision inside one feature — an amendment, not an ADR |
| **Date** | 2026-08-16, Mission 5.1.1 |

The split is not tidiness. **It turns BR-18 and FR-ADM-07 from a runtime check into a compile-time guarantee.** A Collector-side notifier that holds only the read interface *cannot* call a write path, because the methods are not on its type. One interface carrying all nine methods would make the same rule a role check somebody has to remember to write, in every notifier, forever — and FR-ADM-07 is phrased as a prevention, not a validation.

**Decided in 5.1.1 and built in 5.2, deliberately.** Retrofitting the split after five write methods have call sites means moving those call sites; declaring it now costs a sentence. But the write interface is **not** created as an empty or signature-only file: an `abstract interface class` with no implementer and no caller is dead code, which `CLAUDE.md` forbids, and writing it with the FR-ADM-01–04 signatures would be implementing Mission 5.2 inside 5.1.1, which `CLAUDE.md` also forbids. The decision is the artifact; the file follows when it has a consumer.

### The read interface has two methods, because the backend has two routes

`fetchProjects()` and `fetchTasks(projectId)`, and no `fetchTask(taskId)`. **Chapter 4.6 §3 has no `GET /v1/tasks/{id}`** — the three Task routes are `GET /v1/projects/{id}/tasks`, `POST /v1/projects/{id}/tasks` and `PATCH /v1/tasks/{id}`. Declaring a by-id fetch would put a method on the port that Mission 7 has no endpoint to satisfy, which is the breaking rework this interface was traced against Chapter 4.6 specifically to avoid.

The consequence is recorded as open item 70 rather than absorbed: C-06's route carries only a `taskId`, so a deep link or cold start straight into Task Detail has no Project to list from.

### `fetchProjects()` takes no `collectorId`, and this module needs nothing from `features/auth/`

Volume 4 Chapter 4.8: *"every endpoint in Chapter 4.6 re-derives role and scope from the verified token context."* Chapter 4.2 §3: the API layer always injects `WHERE task_assignments.user_id = :current_user`, *"never left optional."* Chapter 4.6 §3's own row: *"Collector: only Projects with an assigned Task (BR-19)."*

So BR-19 is enforced **server-side, from the bearer token**, which `AuthInterceptor` attaches one layer down under ADR-035. A `collectorId` parameter would be a client-supplied scope on a server-enforced rule — redundant at best, and at worst a value some future call site passes wrongly while the backend ignores it.

**This is stronger than Volume 3 Chapter 3.5 §4's *"projects_tasks depends on core and auth"***: for the read path it depends on neither. Recorded because the expected shape of this module was a cross-feature boundary needing ADR-040's treatment, and tracing it dissolved the boundary instead.

**Open item 11 is therefore untouched by this module.** That item's `collector_id` is `DeviceContext.collectorId` — a port `features/recording/` declares for chunk *metadata*, which `features/auth/` must satisfy at the composition root. It is independently closeable today and building `features/projects_tasks/` neither helps nor hinders it. The Mission 4.9 report's recommendation 4 pairs items 5 and 11 with this module; **that pairing is wrong for item 11** and is corrected here rather than inherited.

---

### A-100 — `SessionRegistrar` cannot be implemented by the feature it is assigned to

| | |
|---|---|
| **Volume** | 5, Ch. 5.10 §1 step 1 and Volume 4 Ch. 4.6 §4, via `core/upload/interfaces/session_registrar.dart` |
| **Says** | The port is *"owed to whichever mission builds `features/projects_tasks/`"*, and takes one argument: `remoteSessionId(String localSessionId)` |
| **Problem** | Satisfying it requires reading `LocalSession.taskId`, which `features/recording/` owns and **no `core/` contract exposes** |
| **Class** | Unexercised mechanism — Mission 4.9 §4's pattern, fifth instance |
| **Date** | 2026-08-16, Mission 5.1.1. **Recorded, not resolved** |

The port takes a **local** session id. Any implementation must look that row up to find its `task_id` before it can call `POST /v1/tasks/{id}/sessions`. `LocalSession.taskId` lives in `features/recording/data/collections/local_session.dart`; `core/queue/`'s `QueuedChunk` carries `sessionId` but no `taskId`, and `core/upload/`'s three interfaces expose neither.

So `features/projects_tasks/` implementing `SessionRegistrar` would have to import `features/recording/` — **exactly the ADR-022 R3 violation the port was declared on neutral ground to prevent.** The port as written is unsatisfiable by its designated owner.

### Why this belongs in Mission 4.9 §4's category

That section named three mechanisms *"reviewed carefully, read correctly, and committed without once being run where it would actually have to work"*, and predicted a fourth. This is not a fourth CI defect — it is the same shape in a different medium. `SessionRegistrar` was designed, argued for at length in its own doc comment, cross-referenced from three amendments and an open item, and **never once traced from its consumer to its assigned owner**. The tracing is what found it, and the tracing took one grep.

The lesson generalises past CI: *a port is not satisfiable because it is well-argued; it is satisfiable when someone follows it to the module that has to implement it and finds the data there.*

### Two resolutions, and this mission picks neither

1. **A new `core/` contract exposing `localSessionId → taskId`**, implemented by `features/recording/` and consumed by whoever registers.
2. **Change the signature** to take the `taskId` directly, moving the lookup to the caller.

**Recommendation only, not a decision:** option 1 is more consistent with ADR-040's established pattern — it is the same inversion `ChunkUploadSource`, `ChunkMetadataSource` and `ConnectivityService` already use, and it would be the fourth application rather than a new shape. Option 2 changes a `core/` contract's surface, which is governed by ADR-040 and needs its own treatment.

**Whichever sub-mission picks this up decides for real.** Both are out of 5.1.1's scope: this sub-mission builds domain, data and application against a fake repository and implements no port. Recorded as open item 36's second blocker so it is inherited rather than rediscovered.

---

### A-101 — `flutter test --coverage` silently redefines its own denominator

| | |
|---|---|
| **Volume** | 9, Ch. 9.5 §2's per-layer targets, and the `Test` CI job that measures them |
| **Behaviour** | `lcov.info` contains an `SF:` record only for files **reachable from the test suite's import graph** |
| **Consequence** | A file no test imports is **absent** from the report — not counted as 0% |
| **Class** | Standing measurement risk, not a one-off defect |
| **Date** | 2026-08-16, Mission 5.1.1 |

**This is not a claim that any previously reported number was wrong.** Every figure A-066 and A-096 record is accurate for the files it measured. The risk is structural and forward-looking: **the denominator is recomputed on every run from whatever the tests happened to import**, so untested code lowers the layer percentage far less than it should — and in the limit, not at all.

Measured this mission at commit-time: **90 of 227** hand-written `lib/` files carry no `SF:` record.

### The honest split, because most of those 90 are fine

| Category | Absent because | Is it a gap? |
|---|---|---|
| Pure `abstract interface class` files | No executable lines exist to instrument | **No** |
| `freezed` entity declarations | Every executable line is in the excluded `*.freezed.dart` | **No** |
| Enums and const-only files | Same | **No** |
| Files with real logic that no test imports | Nothing loaded them | **Yes** |

`features/auth/data/invite_code_repository_impl.dart` is in the fourth row. So were `features/projects_tasks/`'s fake and both notifiers, until this mission's tests were written.

### The sharper form, found by this mission's own numbers

Before tests, `features/*/domain` read **98.71% (230/233)** with three new untested domain files on disk. After 51 tests, it reads **98.71% (230/233)** — *identical*. Both times for a correct reason, and neither time because the target was actually re-tested: the entities are `freezed` declarations and the repository is a bare interface, so none of the three contributes an executable line either way.

**A feature whose `domain/` is entirely entities and interfaces cannot move the `domain` layer percentage at all** — not by being tested, and not by being untested. The number is real; what it measures is narrower than "the domain layer", and Chapter 9.5 §2's target is silent on the distinction.

### Why it is filed as a standing risk

It is item 41's *"a green check over an empty set is not evidence"* applied to the coverage report itself, and it is Mission 4.9 §4's pattern in a third medium: a measurement that is correct as written, read carefully every mission, and never once asked what it was failing to look at.

**Not fixed here.** A CI check that fails on files entirely missing from `lcov.info` — as distinct from files with low coverage — is recorded as open item 71, a candidate for a later testing/verification mission. Nothing about it is urgent; what mattered was writing down that the number does not mean what its name implies.

---

### A-102 — Chapters 2.6 and 2.8 are not in this repository, so no UI built to date is reconciled against them

| | |
|---|---|
| **Volume** | 2, front matter and Chapter 2.7's Companion Documents line |
| **Says** | *"Chapters Included 2.1–2.5, 2.7, 2.9, 2.10 (8 Word chapters); **2.6 and 2.8 delivered separately**"* — as standalone interactive HTML |
| **Fact** | Neither file exists under `docs/`. The only HTML in the repository is two Gradle build reports and `web/index.html` |
| **Class** | Missing source, not a specification defect |
| **Date** | 2026-08-16, Mission 5.1.2 |

Chapter 2.8 is the design system: *"the living reference for every color, type style, spacing value, and component (buttons, pills, form fields, checklist items)"*. Chapter 2.6 is the clickable wireframe tool covering 14 of the 23 screens. **Every component citation in Chapter 2.7 resolves to a document nobody building this has read.**

### What is reachable second-hand, and what is not

| Needed | Available? |
|---|---|
| The four status colours | **Yes** — Chapter 2.10 §2.2 lists them, adopted verbatim by A-089 and contrast-measured by A-090 |
| Spacing, radius, size, duration, opacity scales | **Yes** — transcribed into `lib/app/theme/` at Missions 0.7 and 4.6 |
| Type scale | **Partly** — `AppTextTheme` exists; Chapter 2.10 §6 defers the scale itself to *"Chapter 2.8, Section 3"* |
| What a `card container` (§5) actually looks like | **No** |
| What `btn-primary` / `btn-secondary` / `btn-disabled` look like | **No** |
| The `field` component and its `.error` state (§7) | **No** |
| The light/dark CSS custom properties Chapter 2.10 §2.3 cites | **No** |

So a screen can be built from the token set and from `Theme.of(context)` — which ADR-005 requires of a widget regardless — and it **cannot** be checked against the component definitions it was specified in terms of.

### Why this is recorded as its own amendment rather than a footnote

Mission 5.1.2 is the first mission to build a screen from a Chapter 2.7 table, and every UI mission after it will hit the same wall. Recording it once means 5.3's Design System audit inherits a known, bounded gap — *"these screens are token-correct and component-unverified"* — instead of discovering mid-audit that its reference document is missing and having to decide, alone and under time pressure, whether to invent one.

**The risk if it stays unrecorded** is the specific one Mission 4.9 §4 describes in a different medium: work that is correct as far as it was checked, presented as correct outright. A screen built from the right tokens looks finished.

Open item 74 carries it. Two things close it: the HTML arriving, or an explicit decision that `lib/app/theme/` **is** the design system of record and Chapter 2.8 is superseded by it — which would be an ADR, not an amendment.

---

### A-103 — FR-PT-01's four aggregates: three sources, one that does not exist

| | |
|---|---|
| **Volume** | 1, Ch. 1.3 FR-PT-01/02; Volume 2 Ch. 2.5's C-03 row |
| **Says** | FR-PT-01: *"a Home Dashboard showing **active projects, in-progress sessions, total recorded time, and sync status**"*. FR-PT-02: *"pending, uploading, and completed chunk counts"* |
| **Class** | Requirement partially unsatisfiable; two aggregates deferred with reasons |
| **Date** | 2026-08-16, Mission 5.1.2 |

Traced one at a time rather than as a group, because they turned out to have four different answers.

| Aggregate | Source | State |
|---|---|---|
| pending / uploading / completed counts | `core/queue/ChunkQueueSource.watchQueue()` | **Sourced** |
| sync status | the same stream | **Sourced** |
| active projects | `ProjectTaskRepository` + `Project.archivedAt` | **Sourced, on a reading** — A-104 |
| in-progress sessions | `LocalSession.status`, no `core/` contract | **Blocked** — open item 75 |
| total recorded time | nothing correct exists | **Gap** — open item 76 |

### FR-PT-02 crosses no boundary, and that is ADR-040 working

`core/queue/` is already a contract module. `features/projects_tasks/` consuming it alongside `features/upload/` is the arrangement ADR-040 exists to permit — the two features still never name each other. The only change needed was moving the *provider* onto the same neutral ground as its contract (A-107).

### In-progress sessions — the data exists and the contract does not

FR-SES-02's status is on `LocalSession.status` (`in_progress` | `complete`), owned by `features/recording/`. `QueuedChunk` carries `sessionId` and `sessionStartedAt` but **no session status**.

Counting distinct `sessionId`s in the queue was considered and rejected as **wrong rather than approximate**: it counts sessions with surviving chunk rows, which is a different question, and Mission 4.9's handoff warns in terms — *"DO NOT READ `local_sessions.status` AS AN UPLOAD SIGNAL … the session column is FR-SES-02's and means something different."*

**This is A-100's shape a second time**, three sub-missions later: a `features/projects_tasks/` surface needs data `features/recording/` owns, with no contract between them. That repetition is itself the finding — ADR-040's pattern is not a one-off resolution but the standing cost of ADR-022 R3, and each new cross-feature read pays it again.

### Total recorded time — the one that must not be approximated

A per-chunk duration exists: `MetadataTimingDocument.durationSeconds`, derived from `startedAt` and `endedAt` and deliberately not stored *"because a stored copy could disagree"*. It is reachable one chunk at a time through `ChunkMetadataSource.metadataDocument`.

**There is no aggregate, and summing the queue would be actively wrong.** `IsarChunkStore.currentQueue` skips every row with `localDeletedAt != null`, and Chapter 5.15's cleanup soft-deletes rows as chunks complete (open item 61). A total built that way **decreases as the Collector records more** — it would be at its highest before the first sweep and fall thereafter.

That is worse than absent. An incomplete number invites a reader to trust it; a number that moves the wrong way trains them to distrust the screen.

### What the screen does instead: nothing

**No tile is rendered for either.** `0` and `0h 0m` are claims about the Collector's work, and both would be false. An absent tile is an absence, and `collector_dashboard_screen_test.dart` asserts both absences so a later mission cannot add a plausible zero silently.

**FR-PT-01 is therefore partially satisfied and FR-PT-02 fully**, and the Feature Tracker says so rather than reading the pair as one green row.

---

### A-104 — "Active projects" means `archivedAt == null`, and that is a reading

| | |
|---|---|
| **Volume** | 1, FR-PT-01 — *"active projects"*; Volume 2 Ch. 2.5's C-03 row — *"Active Projects"* |
| **Omits** | Any definition of *active*, in either volume |
| **Decision** | Not archived. `Project.archivedAt == null` |
| **Date** | 2026-08-16, Mission 5.1.2 |

Two readings are available and only one is computable today.

**"Not archived"** — `archived_at` is the only activity signal Volume 4 Chapter 4.4 §2 gives a Project, and Chapter 4.2 §1 introduces soft-delete precisely so an archived row stays queryable and distinguishable rather than vanishing. The word *active* sitting opposite a column named *archived* is the natural pairing.

**"Has an assigned Task in progress"** — defensible, arguably closer to what a Collector means by "active", and **not computable**: it needs the session data open item 75 blocks.

So the first reading is adopted, and it is recorded rather than left implicit because the second is the one a product owner might have meant. If it was, the fix is not a UI change — it is open item 75 first.

---

### A-105 — C-01 has five cards; Chapter 2.7's own example says four

| | |
|---|---|
| **Volume** | 2, Ch. 2.7's C-01 table and Ch. 2.5's C-01 row; Volume 1 FR-ONB-01 |
| **Conflict** | Four statements across two chapters; three imply five cards, one implies four |
| **Decision** | **Five**, one per permission — confirmed as a product decision, not inferred |
| **Date** | 2026-08-16, Mission 5.1.2 |

| Statement | Implies |
|---|---|
| FR-ONB-01: *"Camera, Microphone, Location (When In Use), Notifications, and Files access"* | 5 |
| Ch. 2.5's C-01 row names the same five | 5 |
| Ch. 2.7 layout: *"one permission per card"* | 5 |
| Ch. 2.7 button rule: *"'Next' on cards 1–4, 'Get Started' on the final card"* | 5 |
| Ch. 2.7 example: *"Camera & Microphone — to record your walkthroughs"* | **4** |

The example is the only thing that combines two permissions, and it is also the only concrete copy the chapter provides — which is why it is worth recording rather than dismissing. It reads as illustrative phrasing for a card's *sentence*, not as a card boundary, and the same table's button rule contradicts it directly.

`OnboardingPermission.primaryLabel` derives the label from position rather than storing it per case, so a sixth permission cannot produce two cards both reading "Get Started". A test pins the five names and the label sequence.

---

### A-106 — The Dot row is a local widget, and ADR-022 R5 is why

| | |
|---|---|
| **Volume** | 2, Ch. 2.7's C-01 table and §6 |
| **Says** | *"Dot row (not in Design System v1.0 — flagged as a net-new component for the Ch. 2.8 v1.1 pass)"*, and §6: net-new components *"should be folded back into the Design System in its next revision rather than treated as one-offs"* |
| **Decision** | `features/onboarding/presentation/onboarding_dot_row.dart` — local, not shared |
| **Date** | 2026-08-16, Mission 5.1.2 |

Chapter 2.7 §6 is guidance for the **design document**, not licence to pre-promote the **code**, and ADR-022 R5 is binding and explicit in the other direction:

> Nothing enters `shared/` without a second consumer. Components are written inside the feature that needs them and *promoted* when a second feature needs them.

C-01 is the only consumer and `lib/shared/` does not exist. There is no v1.1 of Chapter 2.8 to check against either, since Chapter 2.8 itself is missing (A-102) — so "fold it into the Design System" has nowhere to land today.

**The tradeoff, stated rather than hidden:** local means whoever adds a second carousel does the promotion move. ADR-022's own Consequences names that cost and accepts it — *"the first reusable-looking widget is written inside a feature and moved later, which is one extra step at the moment someone believes they are being helpful."*

### One accessibility decision inside it, which runs against the obvious reading

Chapter 2.10 §4 requires every icon-only element to carry a screen-reader label, and §4 separately requires progress indicators to *"expose their state as a value a screen reader can read"*. Five individually-labelled dots would satisfy the letter of the first and defeat both.

The dots carry **no information the screen does not already state** — the card heading names the permission and the button label changes on the last card. So the row labels itself once (*"Step 3 of 5"*) and excludes its children from semantics. §4's progress-indicator rule governs upload progress and checklist re-runs, which report state the user cannot otherwise obtain; carousel position is not that.

---

### A-107 — `chunkQueueSourceProvider` moved to `core/queue/providers/`

| | |
|---|---|
| **Class** | Placement correction — ADR-040's pattern, applied to the module that had been missed |
| **Date** | 2026-08-16, Mission 5.1.2 |

Declared in `features/upload/application/upload_queue_notifier.dart` at Mission 4.1, when `features/upload/` was the queue's only reader. **A second reader made the placement visible**: C-03 belongs to `features/projects_tasks/` and FR-PT-02 needs the same rows C-11 renders, so reading them through a provider declared inside `features/upload/` would be the ADR-022 R3 import forbidden *"at any layer, in either direction"*.

`core/upload/providers/upload_ports.dart` and `core/connectivity/providers/connectivity_ports.dart` already sit on neutral ground for their own contracts. **`core/queue/` was the one ADR-040 contract module whose provider still lived inside a consumer**, and nothing had forced the question until now.

**A second provider was not declared alongside the first.** Two providers over one contract means two override sites and, the first time one is missed, two different answers to *"what is in the queue"* — the two-sources-of-truth failure ADR-018 exists to prevent. Pure move, 840 tests passing either side, committed alone so it is revertible on its own.

**The generalisation:** a contract on neutral ground is only half the inversion. If its provider lives in a consumer, the next feature to need that contract still cannot reach it — and the defect stays invisible while there is exactly one consumer, which is the same *"green check over an empty set"* shape as open item 41.

---

### A-108 — An `async*` provider that `await for`s a foreign stream reports its errors twice

| | |
|---|---|
| **Class** | Transferable mechanism risk, found by a test rather than by review |
| **Date** | 2026-08-16, Mission 5.1.2 |

`dashboardSummaryProvider` was first written as a `StreamProvider` with an `async*` body looping over the queue's stream:

```dart
await for (final List<QueuedChunk> queue in source.watchQueue()) {
  yield DashboardSummary(...);
}
```

When the source stream errors, `await for` **throws inside the generator**. Riverpod catches that and sets `AsyncError` correctly — the screen renders its error state exactly as intended — *and* the throw is reported again to the zone as an uncaught error. Two reports, one fault.

In a test that is a hard failure; in production it is noise in whatever `FlutterError.onError` is wired to, and the second report carries the generator's stack rather than the source's.

**The fix is one word of shape, not a suppression.** Mapping the source stream leaves errors untouched and exactly one handler:

```dart
return source.watchQueue().map((queue) => DashboardSummary(...));
```

`async*` is right when a provider *interleaves* sources, holds state between events, or emits more events than it receives. It is wrong when the body is a pure transform of one stream, which is the common case and the one that reads most naturally as a loop.

### Why it is recorded rather than just fixed

The wrong version worked. The screen rendered the right thing in every state, and a reviewer reading the provider would have seen an `AsyncError` being produced correctly. **It was caught by a test asserting the error copy, and only because the double-report is fatal in `flutter_test`.**

That is Mission 4.9 §4's lesson at small scale — an artifact correct as written, reviewed as correct, and wrong in the environment it runs in — and it is worth a paragraph because the next derived stream provider in this project will be written by someone reaching for the same loop. The fix was made in `lib/`, not worked around with `takeException()` in the test.

---

### A-109 — C-04 shows archived Projects and labels them

| | |
|---|---|
| **Volume** | 1, FR-PT-03; Volume 2 Ch. 2.5's C-04 row; Volume 4 Ch. 4.6 §3 and Ch. 4.2 §1 |
| **Omits** | Whether an archived Project appears in the Collector's list. **All four are silent** |
| **Decision** | Shown, marked with the word *"Archived"*, and still openable |
| **Date** | 2026-08-16, Mission 5.1.3 |

Checked for a signal before treating it as a choice. FR-PT-03 says *"the list of Projects assigned to the logged-in Collector"*; BR-19 is about assignment, not archival; Ch. 2.5's C-04 says *"Every Project assigned to this Collector"*; Ch. 4.6 §3's row says *"Collector: only Projects with an assigned Task (BR-19)"*. Ch. 4.2 §1 establishes only that an archived Project's data stays queryable. **None of them addresses the question.**

| Option | Cost |
|---|---|
| Hide archived | Drops a Project a Collector may have recorded against, with no explanation |
| Show undifferentiated | Lets someone begin work against a closed Project |
| **Show, labelled** | C-03's *active* count and C-04's list length differ |

The third was taken because it is the only one that neither hides work nor invites it. The count/length difference is legible from the two labels — *"Active projects"* on C-03 (A-104), *"Projects"* on C-04.

**The marker is a word, not a tint.** Ch. 2.10 §2.1 is written about status pills — *"A Collector with red-green color blindness must be able to tell 'Failed' from 'Complete' from the label and icon shape alone"* — and the principle transfers exactly. Greying an archived row would encode its state in hue alone.

**Archived Projects stay tappable.** Ch. 4.2 §1 keeps their data queryable deliberately, and a Collector who recorded against one still needs to reach its Tasks. Nothing about archival is enforced client-side, for the same reason nothing about assignment is: both are the backend's to decide.

---

### A-110 — C-06 renders two of the three things FR-PT-05 names, and neither shortfall is hidden

| | |
|---|---|
| **Volume** | 1, FR-PT-05; Volume 2 Ch. 2.5's C-06 row |
| **Says** | *"Task Detail including instructions, reference examples, **and requirements**"* |
| **Renders** | Instructions (in full) and reference examples (as text that opens nothing) |
| **Class** | Requirement partially satisfied, twice over, both recorded |
| **Date** | 2026-08-16, Mission 5.1.3 |

### `requirements` — absent, and absent visibly

Volume 4 Ch. 4.4 §3's `tasks` table has six columns and no `requirements` (A-098, open item 69). Three ways to make the screen look complete were available and all three were refused:

- **Add a `requirements` field** — invents a column Mission 7 could not populate.
- **Relabel `instructions` as "Instructions & Requirements"** — encodes one of two product readings into shipped copy.
- **Render an empty "Requirements" heading** — implies the data is coming when nobody has decided it exists.

So there is no section at all, and `collector_task_detail_screen_test.dart` asserts that no text matching *requirement* appears anywhere on the screen. A later mission that adds one without settling item 69 breaks a test that names it.

### Reference examples — rendered, and close to useless

Ch. 4.4 §3 types the column *"Array of reference media URLs"*. They are `SelectableText` and **nothing opens them**.

- A tappable link needs **`url_launcher`** — a new dependency, an ADR-030 decision, and the first outbound-navigation path in an app that currently opens no external URL. That is new capability, not layout.
- Inline previews need Ch. 2.8's component library, which is not in this repository (A-102, open item 74).

**This is not a finished feature and the register should not read as though it were.** A Collector standing in a field with a URL they cannot open has, in practice, no reference example. FR-PT-05's second clause is met in letter and missed in substance — open item 80.

The test asserts no `InkWell` or `GestureDetector` wraps a URL, scoped to the examples themselves. **The first draft of that test asserted no `InkWell` anywhere and caught Start Recording's button instead** — it would have passed for the wrong reason, and would have kept passing if the button were deleted. Worth recording because it is the ordinary way an absence-assertion goes wrong: the finder was correct about the widget and wrong about the subject.

---

### A-111 — The Record tab implements the second half of Chapter 2.4 §2, and only the second

| | |
|---|---|
| **Volume** | 2, Ch. 2.4 §2 |
| **Says** | Tab 3 *"jumps into the most relevant in-progress Task's checklist, **or prompts Task selection if none is obviously in progress**"* |
| **Built** | The prompt. Always |
| **Date** | 2026-08-16, Mission 5.1.3 |

Determining *"the most relevant in-progress Task"* means reading `LocalSession.status` — owned by `features/recording/`, with no `core/` contract exposing it to anything that knows about Tasks. That is **open item 75**, the same gap that leaves C-03 without an in-progress-sessions tile. Until it closes, *"none is obviously in progress"* is true by construction and the prompt is the whole of the specified behaviour that can run.

**This is a deliberate subset, not an approximation.** Deriving "most relevant" from the chunk queue would pick a Task from a session's chunk rows, which answers a different question — the identical substitution A-103 rejected for the dashboard, and Mission 4.9's handoff warns against in terms.

### The screen had to gain content, not just lose a button

`RecordingGuard.fallbackRoute` is `/collector/record`. A Collector who reaches `/recording/:id` without a live session is redirected **here**. The Mission 1.3 placeholder rendered its own name, which was tolerable while the debug button sat beneath it and would have become a dead end the moment that button was removed. Removing an affordance and leaving the guard pointing at an empty screen would have traded one defect for a quieter one.

### What the debug button's removal did and did not accomplish

**Did:** the temporary `/checklist/debug-test-task` affordance is gone, and the real path — C-04 → C-05 → C-06 → Start Recording — reaches `/checklist/:taskId` with a Task the Collector chose. Its removal condition, *"that picker existing"*, is met.

**Did not:** make any recording task-attributed. `PreRecordingChecklistScreen` declares `taskId` and reads it nowhere; neither does `ChecklistNotifier`, `RecordingNotifier` or `RecordingGuard`. `TaskContext` is still bound to `UnsourcedTaskContext`. **A recording started through the real picker is attributed to exactly nothing, precisely as one started through the debug button was** — open items 1 and 79, and A-068's Guard 1 still refuses 100% of recorded chunks.

The debug button was never a workaround for a missing *value*. It was a workaround for a missing *route into the screen*, and only the route has been supplied. Recorded at this length because the proximity of a real Task picker to an unattributed recording invites exactly the wrong conclusion.

---

### A-112 — C-11's session heading names a time, because a session has no name

| | |
|---|---|
| **Volume** | 2, Ch. 2.7's C-11 layout |
| **Says** | *"Vertical list of chunk rows grouped under the session **name**"* |
| **Fact** | Nothing in this project gives a recording session a name |
| **Decision** | The heading is when it was recorded |
| **Date** | 2026-08-16, Mission 5.1.4 |

`QueuedChunk` carries `sessionId` and `sessionStartedAt` and no label. `LocalSession` has no name field either, and no `core/` contract exposes it in any case (open item 75). Volume 4 Ch. 4.4 §5's `sessions` table has `id`, `task_id`, `collector_id`, `started_at`, `status` and `notes` — **no name column anywhere in the stack.**

Mission 4.6 rendered `Session 7f3a1c2e-…`, which satisfies the letter of the clause and tells a Collector nothing they can match against their own day. **When it was recorded is the only identifying fact a Collector actually holds**, so that is the heading: *"Today 09:05"*, *"Yesterday 14:30"*, *"3 Aug 07:15"*.

Relative for two days and absolute after: Today/Yesterday is what a person reasons in while an upload is still outstanding, and past that a date carries more than counting back does. The comparison is on **local calendar dates rather than elapsed hours** — a chunk recorded at 23:50 reads *Yesterday* at 00:10, which is what a person means by yesterday even though twenty minutes have passed.

### The timezone bug, recorded because of how it was found

The first draft converted `sessionStartedAt` with `.toLocal()` and compared it against an unconverted `now`. That puts the Today/Yesterday boundary at **UTC midnight rather than the Collector's** — wrong by a whole day for anyone far enough east or west of it.

**It was invisible to the test suite and would have stayed invisible.** Every clock in these tests is UTC, so the two agreed by accident; it was found by reading what `FakeClock` was set to before writing an assertion, not by a failure. Fixed at the source — both sides converted — with a test asserting that a UTC instant and its own local rendering produce the same heading, since they are the same moment.

This is A-108's category in a different mechanism: correct as written, correct under test, wrong in the environment it runs in. **A test suite in one timezone cannot see a timezone bug**, and this project has no other date arithmetic to have taught it that yet.

### Month abbreviations are English

Consistent with every other string in this application. No localisation exists anywhere, and this deliberately adds a dependency on none — `intl` is not in `pubspec.yaml` and admitting it would be an ADR-030 decision for three-letter month names.

---

### A-113 — C-11's per-session summary states no total, because the queue has none to state

| | |
|---|---|
| **Volume** | 2, Ch. 2.4 §2 — Tab 4 is *"upload/sync status **across all sessions**"* |
| **Decision** | *"2 uploaded · 1 waiting"*, never *"2 of 5 uploaded"* |
| **Date** | 2026-08-16, Mission 5.1.4 |

`UploadQueueSession.countOf` has existed and been unit-tested since Mission 4.1 with **no production consumer**. Ch. 2.4 §2's *"across all sessions"* was answered until now only by making the reader count rows.

**The wording is the decision.** A fraction is the obvious phrasing and it would be false: Chapter 5.15's cleanup soft-deletes completed chunks and `IsarChunkStore.currentQueue` excludes soft-deleted rows (open item 61), so a session's visible rows **shrink as housekeeping runs**. *"2 of 5"* states a denominator this screen cannot know, and it would drift downward — a Collector watching *"2 of 5"* become *"2 of 3"* would reasonably conclude footage had been lost.

Naming only what is present avoids claiming a total at all. It is a narrower statement and a true one.

**Failures are named last and never omitted.** Ch. 2.9 §4.1 forbids a failure that is not visible, and a summary reading *"3 uploaded"* while one chunk sat stuck would be exactly that.

---

### A-114 — FR-SES-04 is half-satisfied, and the half is the one that can be true

| | |
|---|---|
| **Volume** | 1, FR-SES-04 |
| **Says** | *"return the Collector to the Task List **or Dashboard** once a session is marked Complete"* |
| **Built** | The Dashboard |
| **Date** | 2026-08-16, Mission 5.1.4 |

C-10's Done button went to `/collector/record` under a comment reading *"That screen is `features/projects_tasks/`'s and unbuilt"*. **Mission 5.1.3 built it**, so the comment was stale and the Record-tab fallback unnecessary.

It now goes to `/collector/dashboard` and **stops there deliberately**. Returning to *the* Task List needs a `projectId`, and C-10 does not have one: the recording path carries a `sessionId`, the session's `taskId` is never wired through to anything (open item 79), and `TaskContext` is still `UnsourcedTaskContext`. **Guessing a Project would send a Collector to somebody else's work** — a worse outcome than the generic destination the requirement itself offers as an alternative.

So the requirement's own *"or Dashboard"* is what makes this honest rather than partial-by-compromise. The Task List half unblocks with item 79 and not before.

**A stale comment is what made this findable.** It asserted a fact — the Task List is unbuilt — that had been false for one sub-mission. Nothing checks comments, and this one had been true when written; the register's own item 23 is the same lesson about amendments, and it applies to doc comments that carry a dependency claim.

---

### A-115 — C-12 cannot be built as Chapter 2.7 specifies, and three of its four blockers are not item 36

| | |
|---|---|
| **Volume** | 2, Ch. 2.5's C-12 row and Ch. 2.7 §3's C-12 table |
| **Says** | *"Give an unambiguous, satisfying confirmation … every chunk and its metadata verified, **not just uploaded**"* |
| **Decision** | **Not built.** Mission 5.1.5 produced no `lib/` change, deliberately |
| **Date** | 2026-08-16, Mission 5.1.5 |

The obvious reading going in was that C-12 is blocked by open item 36 alone — no backend, so *"confirmed uploaded"* cannot be true. Tracing it found **four blockers, and only one of them is item 36.**

### Blocker 1 — Chapter 2.7's own table forbids the degraded version, in those words

The natural compromise is a C-12 that renders what is honestly knowable — *"your session is recorded, chunks are queued"* — with the verification claim omitted. **Chapter 2.7 rules that out by name:**

| Element | Rule, verbatim |
|---|---|
| Confirmation icon | *"Appears only once every chunk has cleared checksum verification (FR-META-12), **never on partial completion**."* |
| Supporting text | *"States the chunk count explicitly (e.g. 'All 6 chunks and their metadata are confirmed uploaded.') rather than a generic 'Done'."* |
| Primary action | *"Returns to Task List (C-06), **not the Dashboard**"* |

*"Never on partial completion"* is exactly the state a degraded C-12 would render. **The chapter anticipated the compromise and refused it**, so building one is not degrading C-12 — it is building a screen Chapter 2.7 says must not appear. That is a spec clause, not a judgement call available to an implementation mission.

BR-12 and BR-21 say the same thing in the business-rule register: *"'Complete' must mean the data is actually safe in cloud storage, not just recorded"*, and *"'Complete' must mean the footage is both present and fully described/verifiable, not just uploaded."*

### Blocker 2 — this client never observes `verified_at`, and would not after a backend existed

C-12's icon is gated on FR-META-12's checksum verification. **Nothing in this application can read that.** Two files already state the position, both written before this mission:

> *"**This device never observes `verified_at`.** It writes `complete` itself"* — `storage_cleanup_sweep.dart`
>
> *"Volume 4 Chapter 4.5's `verified_at` is set by the backend … the device never reads `verified_at` back"* — `chunk_upload_status.dart`

So **item 36 closing would not unblock C-12.** A deployed backend would set `verified_at` server-side and this client would still have no read path to it. That is a second, independent gap sitting *behind* the first — the same shape A-100 found when `SessionRegistrar` turned out to have a blocker behind its blocker. Recorded as open item 83.

### Blocker 3 — C-12 has no trigger and no place in the navigation model

C-12 is in Chapter 2.5's inventory and Chapter 2.7's spec. **It is in no part of Chapter 2.4.** §2's Collector modals are the Checklist, Checklist Failed and Permission Blocked; the stacks are Projects→…→Task Detail and Sessions→Session Detail→Chunk Detail. C-12 is in neither list, and §5's summary table does not mention it.

That gap matters because of *when* C-12's condition becomes true:

| Screen | Fires when | Delay after Stop |
|---|---|---|
| C-10 Local Processing | chunking and metadata generation finish | seconds |
| **C-12 Session Complete** | **the last chunk's checksum verifies server-side** | minutes to hours, over a field connection |

**A Collector is long gone from C-10 before C-12's condition holds** — on another screen, or with the app backgrounded or closed. So there is no moment at which the application can simply *show* C-12 as written. It would have to be reached from C-11, or driven by a push notification (FR-SEC-03/04, Phase 2, unbuilt), or surfaced on next launch. **Chapter 2.4 specifies none of the three.**

This is open item 82's class of defect, second instance: a screen the inventory names and the navigation model does not place. Recorded as open item 84.

### Blocker 4 — the specified return destination needs an id nothing supplies

Chapter 2.7 requires C-12's action to return to *"Task List (C-06), **not the Dashboard**"*. C-06 lives at `/collector/projects/:projectId/tasks/:taskId` and the recording path carries only a `sessionId`; the session's `taskId` is never wired through and `TaskContext` is still `UnsourcedTaskContext`. **Open item 79, already recorded, and it lands on C-12 too.**

A-114 took the Dashboard branch for C-10's Done under FR-SES-04's own *"or Dashboard"*. **C-12 has no such alternative** — Chapter 2.7 names the Dashboard and excludes it.

### Why nothing was built, stated as a decision rather than an absence

Two options were available and both were refused:

- **A degraded C-12** — forbidden by Blocker 1, above.
- **A shell or route only** — already covered by Volume 11 Chapter 11.2's **M4** exit criteria, *"layers, modules, routing, and DI graph exist and compile **with placeholder screens**"*. A placeholder cannot advance M7 without making M7 into M4, and it would add a second unreachable route beside open item 82's.

**The deliverable of this sub-mission is the blocker list.** Whoever picks C-12 up after item 36 closes would otherwise find three more things in the way and no record that they were known.

### Not the same shape as A-06, and the difference is worth carrying

Both are unbuilt screens with a backend gap behind them, and A-122 records why filing them together would lose something. **C-12 is blocked by its own specification** — Chapter 2.7 refuses the degraded form in the words *"never on partial completion"* — **and A-06 is not blocked by its specification at all.** A-06's table forbids nothing; its two missing reads are the whole of it, its writes already work, and closing it needs an endpoint rather than a product decision. C-12 needs a product decision, a backend, a trigger and an id.

**A-06 is the cheaper one.** Reading them as one category would hide that.

---

### A-116 — G3 resolves to Task-level assignment, and what that leaves unexpressed

| | |
|---|---|
| **Volume** | 1, FR-ADM-03/04, BR-14/15; Volume 4 Ch. 4.4 §4 and Ch. 4.6 §3 |
| **Says** | FR-ADM-03: *"assign one or more Collectors to a **Project** and to specific Tasks within it"* |
| **Has** | One table, `task_assignments`. Two routes, both Task-scoped |
| **Decision** | Task-level methods only; Project-level assignment is derived |
| **Date** | 2026-08-16, Mission 5.2.1 |

G3 was traced at Mission 5.1.1 and left open because nothing then needed it. The write interface needs it, and the sources split cleanly once laid side by side:

| Source | Scope it names |
|---|---|
| FR-ADM-03, FR-ADM-04, BR-14, BR-15 | Project **and** Task |
| **US-29** | *"a Project **or** Task"* |
| **US-30** | *"remove a Collector from **a Task**"* |
| **UC-07 main flow, step 3** | *"assigns them to **the Task**"* |
| **UC-07 alternate flow** | *"reassigns **a Task** from one Collector to another"* |
| **Ch. 4.4** | `task_assignments` only |
| **Ch. 4.6 §3** | `POST` / `DELETE /v1/tasks/{id}/assignments` only |

**Every source that specifies a mechanism is Task-only.** The ones naming a Project are summary statements — the requirement headline, the business rules, and US-29's *"or"*. The moment a chapter describes *how*, it describes a Task.

And Ch. 4.6 §3's own `GET /v1/projects` row states the derivation outright: *"Collector: only Projects with an assigned Task (BR-19)."* Assigning a Collector to any Task in a Project is what makes that Project theirs; BR-15's *"more than one Project concurrently"* follows with no second table.

### The residue, which is real and is not a technicality

Derivation gives *"assigned to this Project"* for any Project with at least one assigned Task. It **cannot** express a standing grant — *"assign this Collector to every Task in this Project, **including ones created later**"*.

**A Project-level assignment would be a rule. Task-level assignments are facts.** An Admin who adds a Task next month must assign Collectors again, and nothing in the system will prompt them; the new Task simply appears to nobody. UC-07's own flow never hits this, because it creates the Task first and assigns second — so the happy path hides the gap.

Recorded as open item 85 rather than resolved. An `assignToProject` method with no table behind it is the rework 5.1.1 refused when it declined `fetchTask(taskId)`, and inventing a client-side fan-out — assign to every current Task — would silently implement the *facts* reading of a question nobody has answered.

---

### A-117 — One shared store behind both fakes

| | |
|---|---|
| **Class** | Fake-infrastructure decision, taken because a write path arrived |
| **Date** | 2026-08-16, Mission 5.2.1 |

Mission 5.1.1's `FakeProjectTaskRepository` held its seed in two `static final` collections and was `const`. Correct for a read-only stand-in; unusable the moment anything writes.

**Two independent fakes would have been worse than one shared store**, and the failure mode is the argument: `FakeProjectTaskAdminRepository.createProject` would succeed, `FakeProjectTaskRepository.fetchProjects` would never show the result, and **the symptom would not look like a bug in either fake**. A Project created on A-04 that never appears on C-04 sends someone hunting through presentation code for a fault two layers down.

So the seed moved to `InMemoryProjectTaskStore` and both fakes take the same instance, introduced at the composition root exactly as the real repositories will be. `main.dart` already does this for `IsarChunkStore` — one instance behind four contracts, so every reader sees the same rows.

**It touched previously-closed work**, which is why it landed as its own commit: 894 tests passing either side, no write path in it, revertible without touching the interface that uses it.

### Assignments are recorded and never read back

`InMemoryProjectTaskStore.assignments` is written by the Admin fake and read by **no repository method**, because Ch. 4.6 §3 has no endpoint that reads one — only `POST` and `DELETE`. Tests inspect the store directly, which is legitimate for a fake's own state.

Ch. 2.7's A-06 nonetheless requires its checkboxes to *"reflect current assignment state on load"*. **That screen cannot be built as specified**, and it is Mission 5.2.2's first problem — open item 89.

---

### A-118 — `updateTask` carries `title`, and that is a judgement rather than a transcription

| | |
|---|---|
| **Volume** | 4, Ch. 4.6 §3's `PATCH /v1/tasks/{id}` row; Ch. 4.4 §3; Volume 1 FR-ADM-02 |
| **Says** | Ch. 4.6 §3's purpose column: *"Edit instructions/reference examples"* |
| **Built** | `title`, `instructions` and `referenceExamples`, all optional |
| **Date** | 2026-08-16, Mission 5.2.1 |

Every other signature in `ProjectTaskAdminRepository` is fixed by a table or a route. This one is not, and it is recorded because the register should be able to tell the two apart.

The purpose column names two fields. **Ch. 4.4 §3 makes `title` a column of the very row that route patches**, and FR-ADM-02 says *"create, edit, and remove Tasks … **including** instructions, reference examples, and requirements"* — *including*, not *only*. A `PATCH` on a resource whose title cannot be patched is also an odd shape to hand Mission 7.

So the purpose column is read as **descriptive prose rather than an exhaustive field list**, and `title` is included. Ch. 4.6 §6 already establishes that this chapter is not the authority on fields — it *"defers full field types"* to a Volume 6 artifact that does not exist, which is why A-097 traced the entities from Ch. 4.4 in the first place. The same authority ordering applies here.

**If that reading is wrong the cost is one parameter**, and a backend that rejects a title change surfaces it immediately at Mission 7. Recorded so that failure is diagnosed in one step rather than treated as a defect.

---

### A-119 — Admin and Collector share one read path, and the fake cannot show the difference

| | |
|---|---|
| **Volume** | 4, Ch. 4.6 §3 and Ch. 4.8 |
| **Says** | `GET /v1/projects`, role **Admin, Collector** — *"Admin: all Projects in their org. Collector: only Projects with an assigned Task (BR-19)."* |
| **Decision** | A-02 and A-03 use `ProjectTaskRepository` unchanged. No Admin variant |
| **Date** | 2026-08-16, Mission 5.2.2 |

One route serves both roles and **the scope difference is server-side**, derived from the verified token exactly as BR-19 is (Ch. 4.8: *"every endpoint re-derives role and scope from the verified token context"*). So there is no `fetchAllProjects`, no role parameter, and no second repository.

This is A-099's `collectorId` argument applied a second time: a client-supplied scope on a server-enforced rule is redundant at best, and at worst a value some call site passes wrongly while the backend ignores it.

### The consequence, recorded so it is not read as a bug

`FakeProjectTaskRepository` models **no scoping at all**, deliberately (5.1.1: *"a fake that filtered locally would be modelling a rule the real repository does not implement either"*). So **A-02 and C-04 render identically against the fake** — same three Projects, same order.

**The difference is real and untestable until Mission 7.** Nothing client-side can demonstrate it, because nothing client-side implements it. A later reader comparing the two screens and finding them identical is seeing the design working, not a missing filter — and open item 41's *"a green check over an empty set is not evidence"* is the nearest existing statement of why that distinction is worth writing down.

---

### A-120 — A-02's empty state is not C-04's, and Chapter 2.9 specifies them separately

| | |
|---|---|
| **Volume** | 2, Ch. 2.9 §4.2, against Ch. 2.7 §5 |
| **Class** | A divergence the cross-reference would have lost |
| **Date** | 2026-08-16, Mission 5.2.2 |

Ch. 2.7 §5 covers A-02 and A-03 by cross-reference — *"same pattern as their Collector counterparts, with Admin-only action buttons ('+ New Project', '+ New Task') added"*. Read alone, that says: copy C-04, add a button.

**Ch. 2.9 §4.2 says otherwise**, and names both cases in one breath:

> *"A Collector with no assigned Projects sees a plain-language explanation ('No Projects assigned yet — check back once your Admin adds you to one'), never a bare empty list.*
> *An Admin's Projects List before their first Project is created **leads directly into the "+ New Project" action**, since that empty state has an obvious, single next step."*

**C-04's empty state says *wait*. A-02's says *do this*.** One is an explanation of someone else's pending action; the other is the user's own next step, and §4.2 gives the reason — the Admin has one obvious thing to do and the Collector has none.

So A-02 renders the create action **inside** its empty state, not only in the floating button behind it. A test asserts both halves: that the Admin copy appears, and that C-04's does not.

**Recorded because the divergence lives in a different chapter from the screen's own specification.** Anyone implementing A-02 from Ch. 2.5 and Ch. 2.7 alone would produce C-04 with a button and never know they had missed a rule — which is the same failure mode as A-102's missing design system, at a much smaller scale.

---

### A-121 — A write goes through `application/` even though no layer rule forces it

| | |
|---|---|
| **Reference** | error-handling.md §26's propagation table |
| **Class** | Boundary decision, recorded because the obvious shortcut is legal |
| **Date** | 2026-08-16, Mission 5.2.2 |

A-04's form could read `projectTaskAdminRepositoryProvider` directly. It is declared in `application/` and typed as the domain interface, so **ADR-022 forbids nothing** — this is not the `presentation/ → data/` prohibition, and a reader checking the import matrix would find the shortcut clean.

**The conversion is what forbids it.** §26's table gives `application/` *"`AppException` — **the last layer that may**"* and gives `presentation/` *"Nothing"* in the same column, with `Failure`, by pattern-matching on `code`, as the only thing it may catch. A screen that awaited the repository and caught its own exception would put `Failure.fromException` in `presentation/` — legal by the import rules, forbidden by the error rules, and invisible to both the analyzer and the `Architecture boundaries` CI job.

So `AdminProjectTaskNotifier` exists to own one `try`. Its methods return `Failure?` — null on success — which is `AuthNotifier`'s shape since Mission 2.2, and for the reason that record already states: an action's outcome is not the feature's state, and pushing a failed create through an `AsyncError` would replace a good list with an error.

### It invalidates rather than inserting

A successful create invalidates the affected read provider instead of appending the returned entity to a local list. Both fakes share one store (A-117) and the real repositories will share a backend; **either way the list's source is authoritative and a locally-inserted copy is a second one that can silently disagree** — ADR-018's failure in miniature. Re-reading costs a rebuild and cannot drift.

`tasksProvider` is invalidated per key rather than family-wide, so creating a Task in one Project does not refetch every Project a session happened to have visited.

---

### A-122 — A-06 is blocked by DATA, not by its specification — and that is the opposite of C-12

| | |
|---|---|
| **Volume** | 2, Ch. 2.5's A-06 row and Ch. 2.7 §4's A-06 table; Volume 4 Ch. 4.6 entire |
| **Decision** | **Not built.** Mission 5.2.3 produced no `lib/` change |
| **Class** | Buildability trace. **Distinct in kind from A-115's, and filed so a reader can tell** |
| **Date** | 2026-08-16, Mission 5.2.3 |

**The distinction this amendment exists to preserve:** C-12 and A-06 are both unbuilt screens with a backend gap behind them, and it would be natural to file them identically. They are not the same problem and they do not have the same fix.

| | **C-12 — A-115** | **A-06 — this record** |
|---|---|---|
| Does its Ch. 2.7 table forbid a lesser version? | **Yes, explicitly**: *"never on partial completion"* | **No. It forbids nothing** |
| What blocks it | The spec, plus four other things | **Two missing reads. That is all** |
| Are its writes available? | No — nothing registers a session | **Yes.** `assignCollector` / `unassignCollector` work |
| What would unblock it | A product decision *and* a backend *and* a trigger | **One endpoint. Possibly two** |

**A-06 is the cheaper of the two to close, and nothing about it needs a product decision first.** Reading them as one category would lose that.

### Chapter 2.7's A-06 table contains no prohibition

Its two rules are positive requirements, each with a trailing rationale:

> **Collector row:** *"Checkbox reflects current assignment state on load; unchecked-and-saved triggers FR-ADM-04 removal, **not a silent no-op**."*
> **Confirm action:** *"Disabled if no change was made from the loaded state, to avoid a no-op write and **a false 'saved' confirmation**."*

Both trailing clauses are **anti-deception, not anti-degradation**. They forbid the screen lying about what it did. They do not forbid a smaller screen that lies about nothing. Compare A-115's C-12 clause, which names the degraded state and refuses it outright.

**One version *is* forbidden, and precisely by those clauses:** a default-unchecked checkbox set presented as A-06. Its checkboxes would claim to reflect current state and would not; unchecked-and-saved would silently no-op rather than trigger FR-ADM-04's removal; and the confirm button could not compute *"changed from the loaded state"* because no loaded state exists. That is the disguised version, and it is out.

**An honestly-labelled add-only screen violates neither clause** — see the fallback below.

### The roster has no source at any layer, and that is what blocks everything

Checked exhaustively rather than stopping at the endpoint catalog:

| Layer | Result |
|---|---|
| Ch. 4.6, **all 15 routes** | `GET /v1/users/me` — *"Current user's profile + role"*. **The caller only.** No listing |
| `firestore.rules` | One collection, `org_invite_codes`, `allow read: if false` — *"Nobody reads, ever"* |
| `functions/src/index.ts` | `COLLECTION = "org_invite_codes"`; its own comment: ***"no `orgs` collection exists"***, users table named as *"Volume 4 Ch. 4.4's"*, behind the unbuilt backend |
| `features/auth/` | `AuthRepository` yields the caller's own `Session`/`User`. No directory, no query |
| Every fake, `lib/` and `test/` | **Zero.** No user list in either tree |

`assignCollector({taskId, collectorId})` needs a `collectorId`. **The only user id this application can obtain is the signed-in Admin's own `uid`**, and Ch. 4.4 §4 annotates the assignment FK `role='collector'` — assigning an Admin as a Collector contradicts the schema.

**No stand-in was invented, and that was a decision.** Seeding a Collector roster into `InMemoryProjectTaskStore` would not be standing in for data with a known shape and a known endpoint — which is what every other fake in this project does — it would be **inventing a domain concept this project has never modelled**. The distinction is the difference between a fake and a fabrication.

### Chapter 2.9 has no vocabulary for "this data has no source"

Every empty state the chapter defines is a **runtime absence of data that could exist**: *"No Projects assigned yet — check back once your Admin adds you to one"* (§4.2), *"No sessions yet → empty state, 'no activity yet'"*, *"Metadata not yet confirmed by backend → shown as 'pending verification'"* (both Ch. 2.2).

So an A-06 rendering an empty roster would borrow that vocabulary and say something false — telling an Admin their organisation has no Collectors when the truth is that the application cannot ask. **Same class as A-094's halted banner**, which could not name its cause either; the difference is that A-094's screen still told the truth about what it knew.

### The fallback, recorded as an option and not a recommendation

Once a roster endpoint exists, **an honestly-labelled add-only screen is available without waiting for an assignment-read endpoint.** *"Add Collectors to this Task"*, no claim to show current state, no removal affordance. It violates neither Ch. 2.7 clause: nothing is silent, nothing is false, and `assignCollector` is idempotent so re-adding an already-assigned Collector is harmless.

**It is explicitly partial.** It satisfies **FR-ADM-03** (*"assign one or more Collectors"*) and **only half of FR-ADM-04** (*"reassign or remove"*) — reassignment works as add-then-remove only if removal exists, and removal needs the state read A-06's full form needs. It is **not A-06**; it is a smaller screen the chapter does not describe.

Noted so a future mission knows the option exists and what it costs, not as the recommended path.

---

### A-123 — A-01 was built as a placeholder given its specified job, not as a partial dashboard

| | |
|---|---|
| **Volume** | 2, Ch. 2.5's A-01 row and Ch. 2.2's Admin flow step 2; Volume 1 Ch. 1.1 §7.3 and §4.2 |
| **Built** | The managed-Projects count, and Chapter 2.2 step 2's navigation duty |
| **Omitted** | Collector activity summary; outstanding Task counts — **silently** |
| **Date** | 2026-08-16, Mission 5.2.4 |

### The framing is the decision, and it is why this was built when A-06 was not

Read as *"a three-tile dashboard with two tiles missing"*, A-01 looks like exactly the half-built thing 5.1.5 refused for C-12 and 5.2.3 refused for A-06. It is not that, and the difference is not a matter of degree.

**Chapter 2.2's Admin flow step 2 gives this screen a concrete, fully satisfiable responsibility:** *"Selects '**New Project**' or an existing Project"*, with the branch *"No Projects yet → empty state prompting Project creation."* That is a **navigation duty**, it is the Admin's first screen after the Role Router (step 1), and nothing blocks it. Until this mission the tab rendered its own name.

So A-01 exists to do the job a Volume assigns it, carrying the one tile that has an honest source. **A-06 had no such residual duty** — strip its unbuildable parts and nothing remains, because the screen *is* the checkbox list. Strip A-01's unbuildable tiles and its navigation duty is untouched.

**The test for a future reader:** does the screen have work left when the blocked parts are removed? A-01 does. A-06 and C-12 do not.

### The three tiles, traced individually

Chapter 1.1 §7.3: *"Admin view: all managed Projects, Collector activity summary, and outstanding Task counts."* Chapter 2.5's A-01 row transcribes it. **Chapter 1.1 §4.2 step 18 names only two of the three** — *"all Projects the Admin manages, and a summary of Collector activity"* — so the PRD is not internally consistent about this screen's own content.

| Tile | Source | Verdict |
|---|---|---|
| Managed Projects | `fetchProjects()`, Ch. 4.6 §3's Admin scope (A-119) | **Sourced** |
| Collector activity summary | None. Item 92 under every reading; item 89 for assignments; item 36 for org-wide sessions; **item 83 only under a "verified" reading** | **Blocked** |
| Outstanding Task counts | None, and not merely undefined — see item 94 | **Blocked** |

*"All managed"* rather than *"active"*, so unlike C-03 this needs no `archivedAt` reading (A-104): the count is what `fetchProjects()` returns, archived included.

**And no functional requirement governs the screen at all.** FR-ADM-01 through 08 cover create, edit, assign, reassign, view-status, view-metadata, prevent-Collector-writes and visibility. None is a dashboard. FR-PT-01 is the Collector's and has no Admin counterpart anywhere in Chapter 1.3. Recorded as open item 93.

### The two absent tiles render nothing, per C-03's precedent

No zero, no placeholder, no *"unavailable"* label. C-03 omitted its own two unsourced aggregates the same way (A-103), and A-122 established that **Chapter 2.9 supplies no vocabulary for *"this data has no source"*** — every empty state it defines is a runtime absence of data that could exist. Labelling these would need copy the chapter does not support and would say something false.

A test asserts that **no `0` appears anywhere on the screen**, which guards the specific regression the omission invites: a later mission "completing" the dashboard by showing zero for both.

### THE LOCAL QUEUE IS ALWAYS THIS DEVICE'S — stated once, for reuse

C-03 counts chunks through `core/queue/`, which Chapter 5.9 §3 defines as *"a live view … over `local_chunks.status`"*. Those are **the chunks on the device running the app**. A Collector's dashboard works because it summarises the work sitting on the phone in their hand.

**An Admin's device holds no Collector chunks.** *"Collector activity across them"* is about other people's devices, and nothing local can see it, ever.

This is **structural rather than a gap, and deliberately not an open item**: no fix on the client side would help, because the data has never been here. The consequence generalises and is written into `admin_dashboard_screen.dart`'s own doc so the next Admin trace inherits it:

> **Open item 81 — C-11 forgetting swept sessions in the local queue — does not apply to any Admin screen**, because no Admin screen can read the local queue in the first place.

That matters immediately for **A-07**, whose prior analysis cited items 81 and 83 together. **Item 81 drops out.** A-07's blockers are the backend (item 36) and, for anything claiming verification, item 83 — not the soft-delete blind spot, which is Collector-side by construction.

---

### A-124 — A-07 is the least-blocked screen in the project, and still nothing survives A-123's test

| | |
|---|---|
| **Volume** | 2, Ch. 2.5's A-07 row; Volume 1 FR-ADM-05; Volume 4 Ch. 4.6 §4 and Ch. 4.2 §3 |
| **Decision** | **Not built.** Mission 5.2.5 produced no `lib/` change |
| **Date** | 2026-08-16, Mission 5.2.5 |

### Item 83 does NOT block A-07, and the reasoning is BR-21's server-side gate

Prior analysis paired items 83 and 81 as A-07's blockers. **Item 81 dropped out at Mission 5.2.4 (A-123); item 83 drops out here.**

Item 83 is that *this client never observes `verified_at`*. **A-07 never needs to.** Volume 4 Chapter 4.2 §3:

> *"BR-21 (a chunk isn't Complete until metadata is confirmed): `chunks.status` can only transition to `'complete'` **via a stored procedure that first checks a matching, non-null `chunk_metadata` row exists** — not left to application code discipline alone."*

So a **server-supplied `complete` already encodes verification**. A-07 renders status the backend computed and never inspects the verification column itself.

**Item 83 blocks A-08**, whose Ch. 2.7 table requires a checksum *"paired with a verified/mismatch status label"*, and **it blocked C-12**, whose confirmation icon is gated on FR-META-12 directly. A-07 displays neither. The item's row is narrowed accordingly.

**A-07's blocker set is item 36 alone** — plus the entry-point gap below, which nothing had recorded.

### It is the least-blocked screen in the project

| | C-12 (A-115) | A-06 (A-122) | **A-07** |
|---|---|---|---|
| Spec forbids a lesser version? | **Yes** | No | **No** |
| Endpoint specified? | Partly | **None for either read** | **Yes — and it names the screen** |
| Data exists anywhere? | No | **Nowhere, at any layer** | **Yes, in an undeployed backend** |
| Governing FR? | FR-SES-02 | FR-ADM-03/04 | **FR-ADM-05, Must Have** |
| To unblock | Product decision + backend + trigger + id | One or two new endpoints | **A deployment** |

Chapter 4.6 §4 names it outright: `GET /v1/tasks/{id}/sessions` — Admin — *"**A-07** — session/chunk status across a Task."* **Nothing about this screen is undecided, unspecified or missing.** It is waiting on Volume 11's **M2 — Backend Live**.

### Applying A-123's test: nothing survives

*Does the screen have work left when the blocked parts are removed?*

**No.** Chapter 2.2's Admin flow step 7 gives A-07 exactly one duty — *"Views live status across all assigned Collectors"* — with the branch *"No sessions yet → empty state, 'no activity yet'."* **That branch is a state of the blocked content, not a separate responsibility.**

A-01 survived the same test because Chapter 2.2 step 2 gave it a *navigation* duty untouched by its blocked tiles. A-07 has no equivalent: strip the status view and the screen is empty. **So its outcome is A-06's, not A-01's** — and the test resolved it the same way it resolved A-01, in the opposite direction, which is the point of having a test rather than a judgement.

### A second blocker behind item 36: A-07 has no entry point, and its scope contradicts itself four ways

Even with the backend deployed tomorrow, **nothing could navigate to A-07**, and the reason is that four sources disagree about what it is:

| Source | A-07's scope |
|---|---|
| Ch. 2.5's row | *"for a given **Project/Task**"* |
| Ch. 2.2 step 7 | *"(per **Task**)"* |
| **Ch. 2.4 §3, Tab 3** | *"status + metadata **across managed Projects**"* |
| **Ch. 4.6 §4's only endpoint** | **per Task** |

**Tab 3 is org-wide; the screen and its only endpoint are per-Task.** A tab carries no `taskId` and cannot call a per-Task endpoint without a selection step — and no screen provides one. Chapter 2.4 §3's Admin stack ends at *Assign Collectors* and never reaches Session/Chunk Status; Chapter 2.5's A-03 lists its entry points as *create/edit* and *Collector assignment*, **not** status; and A-03's Task rows deliberately carry no `onTap` (Mission 5.2.2).

**Same shape as A-100 and item 83's own discovery:** a blocker with a blocker behind it, found only by tracing past the obvious one. Recorded as open item 96.

---

### A-125 — Mission 5.3 verified INTERNAL token consistency, which is not a Chapter 2.8 audit

| | |
|---|---|
| **Volume** | 2, Ch. 2.8 — **not in this repository** (A-102, open item 74) |
| **Scope run** | Every screen uses `lib/app/theme/`'s transcribed tokens rather than raw values |
| **Scope NOT run** | Whether those tokens match Chapter 2.8 |
| **Date** | 2026-08-16, Mission 5.3 |

### The claim this amendment exists to bound

Mission 5.3 was briefed as *"every screen pulls exclusively from Chapter 2.8's tokens"*. **That audit cannot be run and was not run.** Chapter 2.8's HTML is not in this repository, so there is no reference to compare against — the sweep was rescoped to verify that screens use the tokens **this project transcribed**, consistently.

**The two claims are easy to conflate and must not be.** `lib/app/theme/` is a *copy* of Chapter 2.8 made at Missions 0.7 and 4.6. A screen using `AppSpacing.lg` is provably consistent with every other screen; whether `AppSpacing.lg = 16` is what Chapter 2.8 says remains unknown and unknowable here. **Open item 74 is untouched by this sweep and a green check does not narrow it.**

### What the sweep found, and where

**38 raw values across 8 files, all built by Missions 1, 3 and 4.** Every screen built across Missions 5.1 and 5.2 was already clean — nine files in `projects_tasks/presentation/`, three in `onboarding/`.

**With one exception, and it is the reason a check now exists.** `collector_sessions_screen.dart` carried `SizedBox(height: 2)` from `b78d05a` — Mission 5.1.4, **in a sub-mission whose own close-out reported a clean sweep**. `AppSpacing.xxs` is exactly 2. The discipline held across twelve new files and slipped on the thirteenth, under close attention, in a mission that was measuring itself.

### Mechanical versus non-conforming — the split that made this safe

| Kind | Count | Fix |
|---|---|---|
| Raw value **equals** a token | **38** | Substitution. Pixel-identical by construction |
| Raw value has **no** token | **6** | **Not fixable.** Substituting a neighbour changes pixels |

The second kind is the important half. `size: 14` has no equivalent — `AppSizes.iconXs` is 16. Changing it is **a redesign performed by a compliance sweep**, and there is no Chapter 2.8 to design against. All six are marked `DESIGN-TOKEN-EXEMPT` on their own lines with reasons, and recorded as open item 98.

### Pixel-identity was proven rather than asserted

`chunk_status_pill` is golden-covered. The committed baselines are **Ubuntu-rendered** and this work was done on **Windows**, so comparing against them would have proven nothing — a mismatch would be the host difference Mission 4.7 already measured (A-095). Both sides were generated **locally instead**, isolating the variable:

```
before   dark eb0696a5d49440c65b6b259387a2134e   light 93e074a1139ac3c0db10a152f5dd9ebb
after    dark eb0696a5d49440c65b6b259387a2134e   light 93e074a1139ac3c0db10a152f5dd9ebb
```

Byte-identical, and re-verified after exemption markers forced `dart format` to rewrap lines. The committed Ubuntu PNGs were backed up, restored and hash-verified unchanged.

### C-09's colours are exempt as a whole file, and its red is an open question

Every other screen takes colour from `Theme.of(context)` per ADR-005. C-09 does not, and the sweep left it alone.

**The black is not a palette value** — Chapter 2.7's C-09 is a *"full-bleed camera preview … no status bar chrome"*, and the surround behind a camera feed is an absence of light. A themed surface colour would tint the letterbox around a live preview.

**The red is a genuine question and is deliberately unresolved.** Chapter 2.7 specifies the indicator as *"red, per Design System critical hue, but denoting 'live' not 'error' in this one context"*. `AppStatusColors`' critical is `#D03B3B`; `Colors.red` is `#F44336`. **They are different colours.** Switching is a visible change to a screen device-confirmed on a CPH2707, with no Chapter 2.8 to validate the result — so it belongs to whoever answers item 98, not to a token sweep.

### The check that now guards this, and what it cannot see

A `Verify design tokens` step in the `Architecture boundaries` job, scanning a **closed list** of layout-carrying constructors plus `Color(0x)`, the raw Material palette and `fontSize`. A closed list rather than *any number*, so `maxLines`, `flex`, `itemCount` and index arithmetic are not swept up.

**`Duration` is deliberately absent.** `AppDuration` is a *motion* scale; `Duration(days: 7)` for invite-code expiry and `Duration(seconds: 1)` for a timer tick are business and behavioural values. Flagging them would be a false positive, and a check that cries wolf is one people learn to skip.

**Two limitations, found while building it and written into the step:**

- **Line-granular exclusion** — a raw value beside a token on the same line is skipped. That is how `fromLTRB(72, 0, AppSpacing.lg, …)` initially passed.
- **`dart format` defeats it** — a constructor split across lines puts its numbers where no pattern matches.

So it catches the common single-line case and is **not a proof of absence**. Item 41's rule about a green check applies to this job as much as to any other, and the step says so in its own comment rather than leaving it to be discovered.

---


### A-126 — `core/onboarding/` applies ADR-040's pattern to a relationship ADR-040 did not name

| | |
|---|---|
| **ADR** | 040 — Cross-Feature Contracts in `core/` (Accepted) |
| **Relationship ADR-040 decides** | feature <-> feature |
| **Relationship recorded here** | `app/` <-> feature |
| **Status** | A stretch by analogy. **Not settled by citation.** |
| **Date** | 2026-08-16, Mission 5.4 |

### What was actually needed

`OnboardingGuard` answers *"has this Collector seen C-01"*, and the fact is owned by `features/onboarding/`. The guard runs inside `router.dart`'s `redirect`, so `lib/app/` must read it.

**ADR-022 R2 forbids exactly that path**: `app/` may import a feature's `presentation/` and nothing else. Declaring the contract or its provider inside `features/onboarding/application/` would have put `router.dart` across R2 — an eighth breach of a rule already broken seven times (open item 101), added by the sub-mission whose subject is the routing layer.

So the contract went to `core/onboarding/`: interface in `interfaces/`, throwing provider in `providers/`, implementation in `features/onboarding/data/`, the two introduced by the composition root. `app/` imports `core/`, which ADR-022 permits without qualification.

### Why this is recorded as a stretch and not as ADR-040 compliance

**ADR-040's stated shape is feature <-> feature**, and it says so in the sentence that distinguishes it from ADR-035:

> *"**This case is feature <-> feature.** Neither party is `core/`. Nothing in `core/` wants these rows; `core/` is being asked to hold a contract between two modules that must not know about each other."*

Here the consumer is `app/`, not a second feature. **The mechanism transfers exactly — neutral ground, dependency inversion, composition-root binding — and the justification does not**, because ADR-040's reasoning is about two features being mutually blind, which is not the property at issue when one party is the application shell.

**Citing ADR-040 as though it already covered this would be the failure mode the register exists to catch**: a decision that was never taken appearing settled because a nearby decision was. It is recorded as an analogy that held, with the gap named.

### The clarification this is owed

Whether `app/ <-> feature` belongs inside ADR-040, inside ADR-022 as a stated consequence of R2, or in a record of its own. **It is a real question because R2 forces it**: any fact `app/` needs from a feature and cannot get through `presentation/` has to land somewhere, and `core/` is currently the only legal answer. That answer is undocumented, so the next person hitting R2 will re-derive it or breach R2 instead — which is what the seven existing breaches look like from here.

Left open deliberately. **A new ADR is a decision to be approved, not a by-product of a wiring sub-mission**, and Mission 5.4's brief scoped it to route wiring.

---

### A-127 — `shared_preferences`' fourth owner is a named FILE, on ADR-039's self-declaring-filename convention

| | |
|---|---|
| **Artifact** | `.github/workflows/ci.yml`, `Architecture boundaries` job |
| **Rule changed** | `check shared_preferences <owner-regex>` |
| **Kind of change** | Applying an already-accepted dependency more broadly — **not** an ADR-030 decision |
| **Date** | 2026-08-16, Mission 5.4 |

### What changed, and what deliberately did not

Added: `lib/features/onboarding/data/shared_preferences_onboarding_seen_store\.dart`.

**Not added: `lib/features/onboarding/data/`.** The directory grant was the obvious form and is the wrong one. One boolean was needed; a directory grant permits every future file in that directory to reach the plugin for any purpose, and the permission would then be invisible at the point someone uses it.

### The rule already supported this granularity, and already argued for it

The existing owner list carries its own precedent in a comment:

> *"Both files are named individually — the permission is two FILES, not a directory or a glob, so a third entrypoint cannot acquire it by being added nearby."*

ADR-039 states the convention independently, for `isar`:

> *"the file that may import [the package] announces it in its own filename … greppable and self-declaring instead of a directory anyone can drop a file into."*

`shared_preferences_onboarding_seen_store.dart` satisfies both: the filename carries the permission, and a second file under `features/onboarding/data/` cannot acquire it by proximity.

### Why this is an amendment and not an ADR change

**No accepted ADR fixes the owner list.** It exists only in `ci.yml`. ADR-008 mentions the package once — *"`shared_preferences` is not currently a dependency, so the prohibition against using it for secrets is forward-looking rather than corrective"* — which is stale as to the dependency and silent as to ownership. ADR-039 cites the package only as a naming example. **Checked before assuming**, because the alternative was a fork.

ADR-030 governs *adding* a dependency. `shared_preferences` was added at Mission 3 and is already in `pubspec.yaml`, so this is the A-107 shape: an existing decided dependency applied to one more consumer.

**ADR-008's test was applied rather than assumed.** The flag holds no secret, no credential and no identifier of any person or account — one boolean about a device. Writing it into `flutter_secure_storage` would blur the rule that makes ADR-008 checkable, which is the argument `SharedPreferencesWideAngleEligibilityCache` already makes for the wide-angle verdict.

---

### A-128 — `router.dart`'s route table documented 9 of 23 routes, and three adjacent claims had gone false with it

| | |
|---|---|
| **Artifact** | `mobile/lib/app/router.dart`, class-level doc comment |
| **Written** | Mission 1.3, accurate then |
| **Found** | Mission 5.4, after eleven sub-missions of additions |
| **Family** | A-114 — a record true when written that nothing re-checks |
| **Date** | 2026-08-16, Mission 5.4 |

### The drift

The fenced block listing the application's routes named **nine**. The file declares **twenty-three**. Absent: every tab route, every stack route, `/signup`, `/admin/invite-codes` and the entry route. **A reader checking "what routes exist" against the most obvious place to look got less than half the answer**, from a file whose whole purpose (ADR-004) is being the one place routes are declared.

### Three adjacent claims in the same comment had also gone false

Found only because correcting the table meant reading the comment around it.

| Claim | State when found |
|---|---|
| *"only from a feature's `presentation/` layer — ADR-022 §2.2"* | **A claim of compliance the file does not have** — three of its own imports breach R2 (open item 101) |
| *"A single top-level `redirect` delegates to AuthGuard"* | Three guards since Mission 3.8; now four with `OnboardingGuard` |
| *"No modal routes beyond the checklist … Neither module is scaffolded"* | False since Mission 5.2.2 added two create modals, and `onboarding` is scaffolded |

All four corrected together. The R2 sentence was **replaced with a statement of the actual breach** rather than deleted, because a doc comment asserting compliance is worse than one asserting nothing.

### Why this is A-114's family and not a new failure mode

A-114 was a comment that outlived the fact it described; the Mission 5.2.1 off-by-one was a comment wrong on arrival. **This is the first: written true, never re-read.** Its distinguishing feature is that nothing could have caught it — no test asserts the doc matches the routes, no lint compares a comment to code, and the file passed every check in CI throughout.

**No test was added to prevent recurrence, and that is a gap rather than a decision.** A check that the table's rows match the declared `path:` values is mechanically possible; whether a doc-comment-versus-code assertion is worth its maintenance is a question this sub-mission did not have the scope to answer. The reconciliation was done by hand here — 23 declared paths, 23 rows, enumerated and compared rather than eyeballed.


---

### A-129 — Chapter 2.10 §8 names its own screen list, and it contains none of Mission 5's screens

| | |
|---|---|
| **Volume** | 2, Ch. 2.10 §8 — Verification Checklist |
| **Status of the chapter** | Draft — Pending Approval (**as are all nine Volume 2 chapters**; checked, not assumed) |
| **Class** | Scope settled by the specification, against the sub-mission's own framing |
| **Date** | 2026-08-16, Mission 5.5 |

### The list

> *"VoiceOver (iOS) and TalkBack (Android) manual pass completed on: **Login (SH-02), Pre-Recording Checklist (C-07/C-08), Recording Screen (C-09), Upload/Sync Status (C-11), Assign Collectors (A-06), Metadata Detail (A-08)**."*
>
> *"Text scaling verified at 100%, 150%, and 200% OS settings **on the same screen list above**."*

| Screen | Built by | Built in 5.1/5.2? |
|---|---|---|
| Login (SH-02) | Mission 2 | No |
| Pre-Recording Checklist (C-07/C-08) | Mission 3 | No |
| Recording Screen (C-09) | Mission 3 | No |
| Upload/Sync Status (C-11) | Mission 4 | No |
| Assign Collectors (A-06) | **never built** — item 89 | No |
| Metadata Detail (A-08) | **never built** — item 97 | No |

### Why this is recorded rather than resolved silently

Mission 5.5's brief scoped the pass to *"all new screens"* and asked explicitly whether Chapter 2.10 applies retroactively **the way Mission 5.3's token sweep turned out to need**. The honest answer is neither option as posed:

- **Not 5.3's shape.** 5.3's retroactive scope was a *discovery* — the token sweep found violations in older screens and widened to meet them. Nothing in Chapter 2.8 named a screen list.
- **Not "new screens only".** Chapter 2.10 §8 names six screens by identifier, and **zero of them were built in 5.1 or 5.2.** The list predates every screen in it.

**So the specification inverts the sub-mission's scoping**, and the device pass follows the chapter. The screens built in 5.1/5.2 stay in the code-verifiable bucket, where they do have findings.

**The chapter's Draft status was checked before leaning on it.** All nine Volume 2 chapters carry *"Draft — Pending Approval"*, so §8's status is the volume's normal state and not a reason to discount it. The rule that only *Accepted* records bind applies to ADRs; Volume chapters are the specification regardless.

---

### A-130 — Re-running the contrast check found a class A-090 never measured

| | |
|---|---|
| **Volume** | 2, Ch. 2.10 §2.2 / §2.3, against `AppStatusColors` and `AppColors` |
| **Pairs computed** | 40 |
| **Failures** | 3 — all in the class A-090 did not cover |
| **Date** | 2026-08-16, Mission 5.5 |

### What the earlier measurement holds, and the question it answered

A-090 measured the four published hues **as a fill carrying body text** and found three of four failing 4.5:1, which is the evidence that §2.2's *"checked against … contrast requirements"* referred to some other application.

Mission 5.5 re-ran everything and confirms A-090's derived foregrounds work: **all 8 status fill-vs-foreground pairs pass** (lowest 4.76:1) and **all 24 `ColorScheme` text pairs pass** (lowest 5.02:1).

### The class it did not measure — the pill against the surface behind it

WCAG 1.4.11 non-text contrast, 3:1, which decides whether a pill's **boundary is visible at all** rather than whether its text is readable:

| Theme | Pair | Ratio | |
|---|---|---|---|
| light | `warning` `#FAB219` vs `#FBFBFD` | **1.78:1** | ✗ |
| dark | `accent` `#215FAB` vs `#101317` | **2.92:1** | ✗ |
| dark | `critical` `#A62F2F` vs `#101317` | **2.72:1** | ✗ |

**Mitigated, not resolved.** §2.1 requires every pill to pair colour with an icon *and* a text label, and it does — so no information is lost when the edge is hard to see. The defect is that the shape is low-contrast, not that the meaning is unreadable.

**Not fixed, by decision.** Changing a published hue is what §2.2 forbids *"without re-validation"*, and A-090 already established there is nothing to re-validate against — Chapter 2.8 is not in this repository. Recorded as open item 102.

**The dark accent misses by 0.08.** That is worth its own sentence: it is a rounding-scale question rather than a design failure, and it is the one of the three most likely to disappear if Chapter 2.8 is ever recovered and the real dark-surface value turns out to differ from the transcription.

---

### A-131 — Chapter 2.10 §5's focus trap is satisfied by construction, and its second half cannot be

| | |
|---|---|
| **Volume** | 2, Ch. 2.10 §5 |
| **Outcome** | No production code written. One half held by the navigation model, the other structurally unavailable. |
| **Date** | 2026-08-16, Mission 5.5 |

§5: *"Modal screens (Checklist, Create/Edit forms, Metadata Detail) trap focus within the modal while open, and return focus to the triggering element on dismissal."*

### First half — stronger than asked, and proven rather than assumed

**Every screen Chapter 2.4 calls a modal is a full-screen `GoRoute` reached by `context.go`**, which replaces the location rather than pushing an overlay. Swept `lib/`: no `Navigator.push`, no `context.push`, and one `showDialog` (sign-out confirmation, where Flutter traps and restores focus itself).

So the triggering screen is not merely unfocusable — **it is not in the widget tree**, which is a stronger guarantee than a focus trap.

**No `FocusScope` was added.** It would have been redundant code implying the framework was not already doing this. The deliverable is a regression test that holds the property: the triggering screen proven absent, and twelve tab presses proven to land on real focus nodes all inside the modal — with the count asserted, because a tab that focuses nothing skips the check and twelve of those would look identical to twelve successes.

### Second half — unsatisfiable, and not by omission

*"Return focus to the triggering element on dismissal"* has **no referent** under `go`. Dismissal navigates to a route rebuilt from scratch, so the triggering element is a new widget with no focus history and nothing to restore to.

**This is a consequence of the navigation model, not a missing line in a form.** Satisfying it would mean either presenting these screens as pushed routes or overlays — a Chapter 2.4 change — or tracking a focus target across route rebuilds, which nothing in this project does. Recorded as open item 104, owned by whoever revisits how modals are presented, not by an accessibility pass.

---

### A-132 — `ListTile` merges descendant semantics, so an icon's label is not findable on its own

| | |
|---|---|
| **Artifact** | Test craft, applicable to every future accessibility assertion in this repository |
| **Found by** | An assertion that failed on its first run, not by reading documentation |
| **Date** | 2026-08-16, Mission 5.5 |

`Semantics(label: 'Checking')` on a `ListTile`'s `leading` widget does **not** produce a node labelled `Checking`. `ListTile` merges its descendants into one node, so the label arrives **concatenated with the row's title** — the checklist row reads as something like *"Camera and microphone Checking"*.

**`find.bySemanticsLabel('Checking')` therefore finds nothing**, and does so silently: it reports zero matches exactly as it would if the label had never been added. The first version of Mission 5.5's checklist test failed this way and the fix is `find.bySemanticsLabel(RegExp('Checking'))`.

**Recorded because the failure mode is invisible in the other direction.** A test written to match a merged label would keep passing if the label were deleted from a *different* child of the same tile. Anyone asserting on labels inside a merging widget — `ListTile`, `MergeSemantics`, a `Chip` — needs to know the node they are matching is the composite, not the part they wrote.

Two smaller findings from the same session, kept here rather than as their own records: **`pumpAndSettle` times out on an indeterminate `LinearProgressIndicator`** (it animates forever — use `pump`), and **`tester.binding.rootPipelineOwner` is not where a widget test's semantics tree lives**, so walking from it finds nothing. Asserting on a node obtained via `tester.getSemantics(finder)` avoids both the deprecated API and the wrong tree.


---

### A-133 — Mission 5.5's device pass, and the exact boundary of what adb can prove

| | |
|---|---|
| **Device** | CPH2707, Android 16, override density 480 → **devicePixelRatio 3.0** (1 dp = 3 px) |
| **Method** | `uiautomator dump` for bounds and accessible names; `screencap` for scaling; pixel sampling for rendered colour |
| **Date** | 2026-08-17, Mission 5.5 |

### Why uiautomator rather than Flutter's own semantics dump

`uiautomator dump` returns the **platform accessibility tree** — the same `AccessibilityNodeInfo` tree TalkBack consumes. `debugDumpSemanticsTree` returns Flutter's internal tree *before* the platform translation. For a question about what a screen reader receives, the platform tree is the authority and Flutter's is one step upstream.

**One prerequisite that is easy to get wrong:** Flutter builds no semantics tree at all until an accessibility client connects. The device had `accessibility_enabled=0` and no services, and the first dump returned only the view shell. `uiautomator`'s own connection is itself an accessibility client, so the tree appears from the second dump onward — no TalkBack install or `settings put` required, which also means touch exploration never interfered with `input tap` navigation.

### What this method proves

- **Rendered bounds in real pixels**, convertible to dp by a ratio the device reports. Not a token value, not a constraint — the measured node.
- **The exact accessible name string** on the exact node, including whitespace and codepoints. C-09's Stop control was confirmed as `Recording — tap to stop` by codepoint (`0x2014` is a true em-dash), not by eye.
- **Reflow behaviour under OS text scaling**, because bounds are re-measurable at each scale and clipping is visible in a screenshot.
- **Rendered colour**, by sampling the screenshot. The queued pill sampled `#C98C0A` on `#101317` for **6.42:1 — identical to the computed value in A-130**, which is what makes that table a description of the device rather than of the source.

### What this method CANNOT prove, and must never be reported as proving

- **Whether spoken audio is intelligible or well paced.** A correct string is not a good announcement; nothing here listened to anything.
- **Whether swipe order feels coherent.** Tree order is dumpable and "does this read sensibly to a person moving through it" is not.
- **Whether a node is a live region.** `uiautomator dump` has no `live-region` attribute. Login's error banner was confirmed to *carry its message as an accessible name*; that it is announced on appearance rests on the widget test asserting the flag, and on a human hearing it.

**So Chapter 2.10 §8's TalkBack requirement is NOT met by this pass.** §8 says *"manual pass completed"*, and this narrows what remains rather than closing it: content and geometry are now objectively settled, and audibility and navigation feel are exactly what a human session still has to judge.


---

### A-134 — Two defects that only a device could find, and what that says about the test suite

| | |
|---|---|
| **Found** | 2026-08-17, Mission 5.5's device pass, CPH2707 |
| **Fixed** | Same sub-mission — open items 106 and 107, both closed |
| **Date** | 2026-08-17 |

Mission 5.5 built four accessibility fixes against Chapter 2.10 and proved each with a widget test. The device pass that followed found **two further defects the suite could not have caught**, and the reason is the same in both cases: *the suite tests Flutter's own view of the app, and neither defect exists there.*

### Item 106 — invisible to every instrument except a platform-tree dump

`ChunkStatusPill` announced its label twice. The duplication happens when Flutter's semantics are **translated into Android's `AccessibilityNodeInfo` tree**, where a `Semantics(label:)` and its child `Text` merge into one node. Flutter's own tree holds them as parent and child, so:

- no widget test saw it — `tester.getSemantics` returned the composed node the test asked for;
- no golden saw it — nothing rendered differently;
- no screenshot saw it — the pixels were always correct.

**It existed only in the accessibility tree, which is the only tree a screen reader reads.**

### Item 107 — invisible because tests do not run at 200%

The tab bar clipped its labels at 150% and 200% OS text scale. Every widget test runs at scale 1.0 unless it says otherwise, and none did. The defect needed the OS setting changed and the result measured — `uiautomator` reported the destination's bounds as **byte-identical at 1.0, 1.5 and 2.0** while the label inside them was not.

### What this is evidence for

**Not that the widget tests were bad.** They caught what they were pointed at, and A-132's `ListTile` merge finding came out of one. The point is narrower and worth stating once: **an accessibility suite that never leaves the framework's own representation has a blind spot shaped exactly like the platform boundary**, and text-scale resilience is untested by construction unless a test opts in.

**Two cheap follow-ups this does not do**, recorded rather than performed: widget tests could pump at `TextScaler.linear(2.0)` and assert no overflow, which would have caught 107 without a device; and nothing yet asserts that a composed semantics label is not a concatenation of its children, which is the general form of 106.


---

### A-135 — A-134's test recommendation was WRONG for the defect it named

| | |
|---|---|
| **Corrects** | A-134, Mission 5.5 |
| **Class** | A recommendation that would have produced a passing test over a live defect |
| **Date** | 2026-08-17, Mission 5.6 |

A-134 closed by proposing two cheap follow-ups, the first being:

> *"widget tests could pump at `TextScaler.linear(2.0)` and assert no overflow, **which would have caught 107 without a device**"*

**It would not have.** Measured before building it:

```
NavigationBar(height: 80) + five labels + TextScaler.linear(2.0)
  → tester.takeException() == null
SizedBox(height: 56) + FilledButton + 'Start Recording' at 2.0
  → tester.takeException() == null
```

**`NavigationBar` clips a too-tall label silently.** No `RenderFlex` overflow, no `FlutterError`, nothing for an exception-based assertion to catch. Item 107 was a *clip*, not an *overflow*, and the two are different events in Flutter's rendering.

A genuine overflow does surface — a `Column` taller than its box reports *"A RenderFlex overflowed by 100 pixels"* — so the sweep is a real check for a real class. **It is simply not the class that produced 107.**

### Why this is recorded as a correction rather than quietly replaced

A-134's own subject was *defects the test suite could not see*, and it then recommended a test that could not see one of them. **Left unstated, the register would carry a plausible-sounding recommendation that produces a green test over a live defect** — which is worse than no recommendation, because it looks like coverage.

The correction is worth as much as the original finding: **"assert no exception" only detects failures Flutter chooses to report.** Silent clipping, truncation and overlap are not among them. A property that matters has to be asserted as a measurement, not inferred from the absence of an error.

### What replaced it

Two files, not one, and they are complementary rather than redundant:

- `test/app/navigation/tab_shell_test.dart` — asserts the bar's **height against the text scale** (80 / 92 / 104 dp at 1.0 / 1.5 / 2.0). It also asserts that the *old* fixed-height bar throws nothing, which is the assertion that justifies the file existing.
- `test/accessibility/text_scale_resilience_test.dart` — the sweep A-134 asked for, ten screens at 150% and 200%, **with its own doc stating the class it cannot see.**

A-134's second follow-up — *"assert that a composed semantics label is not a concatenation of its children"* — was **implemented as stated** and is correct: `chunk_status_pill_test.dart` asserts label equality rather than `contains`, which is exactly that property.

---

### A-136 — Chapter 2.10 §3's minimum is enforced by Flutter's own guideline, not a hand-rolled assertion

| | |
|---|---|
| **Closes** | Open item 105 |
| **Mechanism** | `meetsGuideline(...)` from `flutter_test` — no new dependency |
| **Date** | 2026-08-17, Mission 5.6 |

### The thresholds are not this project's to choose, which is the point

| Guideline | Value | Chapter 2.10 |
|---|---|---|
| `androidTapTargetGuideline` | **`Size(48, 48)`** | §3's Android minimum, exactly |
| `iOSTapTargetGuideline` | `Size(44, 44)` | §3's iOS minimum, exactly |
| `labeledTapTargetGuideline` | every tappable node has a label | §4 |
| `textContrastGuideline` | WCAG AA | §2.3 |

Open item 105 was that `AppSizes.minTouchTarget = 48` held the number and **nothing checked it**. Mission 5.5's device pass measured twelve element classes by hand and found none under 48dp — but a hand measurement does not survive the next padding change, and three of those twelve sat *exactly* on 48 with no margin.

A hand-rolled bounds assertion was the obvious alternative and is worse: it would have re-stated a threshold this project already got from Chapter 2.10, in a third place, with nothing tying the three together.

### What the sweep found — one real violation, and two clean results worth stating

Ten screens, all three guidelines:

- **`labeledTapTargetGuideline`: 10/10 pass.**
- **`textContrastGuideline`: 20/20 pass** — ten screens in *both* themes, which is what §2.3's *"dark mode is a validated second pass … never an automatic filter"* asks for.
- **`androidTapTargetGuideline`: 9/10.** C-06 fails — open item 108.

**The two clean results are a finding, not a non-event.** §4's labelling and §2.3's AA contrast now have machine evidence across everything Mission 5 built, where before they had a code review and a screenshot.

### A deliberate deviation from Volume 3 Chapter 3.6 §4

`test/accessibility/` **does not mirror a `lib/` path**, and §4 requires *"every test file at the identical path under `test/` as the file it tests"*.

**These files test a property across ten screens owned by two features**, not a file. Ten mirrored files would duplicate a provider harness ten times to assert one line each, and the eleventh screen added later would silently not be covered — which is the failure the single list prevents. The deviation is stated in the files themselves and here, rather than left to look like an oversight.

---

### A-137 — Mission 5's cumulative testing state against Volume 9, as one measurement

| | |
|---|---|
| **Volume** | 9, Chapters 9.5 / 9.6 / 9.7 |
| **Suite** | **1038 passing, 3 skipped** |
| **Measured** | 2026-08-17, re-run rather than inherited from close-out reports |
| **Date** | 2026-08-17, Mission 5.6 |

### Coverage against Chapter 9.5 §2

| Layer | Measured | Target | |
|---|---|---|---|
| **Domain** | **98.7%** (230/233) | 90%+ | **MET** |
| **Data** | **71.7%** (594/828) | 80%+ | **MISSED by 8.3 pts** |
| Application | 84.9% (569/670) | none stated | — |
| Presentation | 89.5% (1157/1293) | goldens, not a percentage | see item 109 |
| `core/` | 85.1% (521/612) | none stated | — |
| `app/` | 68.4% (182/266) | none stated (item 24) | — |
| **Total** | **83.4%** (3253/3902) | — | — |

**The data miss is still one file, and it is the same file A-096 already decided about.** `isar_chunk_store.dart` is **1.9%** — 4 of 212 lines, a quarter of the layer. **Excluding it, data reads 95.8%** (590/616). A-096 declined to fix it because the only mechanism is `Isar.initializeIsarCore(download: true)`, which would put a network fetch into every CI run and every offline build.

**The number moved the right way without anyone targeting it**: 68.3% at Mission 4.7 → **71.7%** now, because Mission 5 added data-layer code that came with tests while the untested file stayed the same size.

### The pyramid, and the half of it that cannot be measured here

Chapter 9.5 §1: Unit ~70%, Integration/Widget ~20%, Manual ~8%, Device Matrix ~2%.

**Measured — by declaration site**, a method with a stated limit: a test declared inside a `for` loop counts once here and many times at runtime.

| | Declarations | Share | Ch 9.5, renormalised to the automated 90% |
|---|---|---|---|
| Unit (`test(`) | 804 | **82.0%** | 77.8% |
| Integration/Widget (`testWidgets(`) | 176 | **18.0%** | 22.2% |

About four points unit-heavy, and **moving toward the target** — 82.6/17.4 before this sub-mission's additions.

**NOT measurable, and this is why open item 64 narrows rather than closes.** Manual (~8%) and Device Matrix (~2%) are *human* test cases. Chapters 9.8 and 9.9 enumerate none in this repository, so **two of the pyramid's four layers have no population to count.** Any "the pyramid is measured" claim would cover 90% of the pyramid while sounding like it covered all of it.

### What Mission 5 actually built, and whether it is tested

Confirmed against the sub-missions that ended without code — **5.1.5, 5.2.3 and 5.2.5's A-07 half produced no `lib/` change at all**, so nothing is owed there and the testing target is real code rather than specification text.

What Mission 5 did build: nine `projects_tasks` screens, `features/onboarding/` (presentation and data), `core/onboarding/`, `OnboardingGuard`, and Mission 5.5's accessibility edits. **Presentation sits at 89.5% and every one of the ten screens is now pumped by three guideline sweeps and a two-scale resilience sweep.**

### A correction to this sub-mission's own Part 1

Part 1 reported *"three tooling gaps Chapter 9.5/9.7 name that don't exist"*. Checking the register before writing them up showed **two of the three were already recorded, and the third is not a gap at all**:

- `mocktail` — **open item 63**, already recorded.
- `integration_test` — **open item 20**, already recorded.
- `golden_toolkit` — **not a gap.** Open item 19 closed it deliberately: `matchesGoldenFile` is built into `flutter_test`, and *"`golden_toolkit` supplied convenience … not capability"*.

**Only the golden-coverage count was genuinely new** (item 109). Recorded because the near-miss is instructive: a fresh measurement can rediscover a known item and present it as news, and the register is the thing that stops that.


---

### A-138 — Mission 5.7's security review: scope, method, and the three findings

| | |
|---|---|
| **Range** | `ccd6874..HEAD` — **58 commits, 93 files** (54 added, 39 modified) |
| **Method** | Working-tree scan **and** patch-history scan; boundary checks re-run rather than cited |
| **Outcome** | Two fixed under authorisation, one recorded for deliberate scheduling (open item 110) |
| **Date** | 2026-08-17, Mission 5.7 |

`ccd6874` was HEAD when Mission 5 began, so the range is exact rather than estimated.

### Why the history was scanned and not only the tree

The project's `Secret scan` job reads `git ls-files` — the **working tree**. A credential added in one commit and deleted in a later one passes that scan and is still disclosed permanently, which is the failure ADR-016 exists for.

So the review extracted all **11,156 added lines** across the 58 commits and ran the five committed patterns plus seven broader ones (`password=`, `secret=`, `api_key`, `client_secret`, `BEGIN CERTIFICATE`, bearer-shaped values, long token literals). **Zero hits.** The three `Bearer` matches are prose inside doc comments describing how `AuthInterceptor` works.

### What was clean, stated so the absence is evidence rather than silence

- **Storage.** Mission 5 added exactly one persistence writer: `onboarding_seen_v1`, a boolean written only ever as `true`. `features/auth/` was touched **only in `presentation/`** — no `core/storage/`, no `core/network/`, no `features/auth/data/`. The token path is untouched, and `StorageKeys` remains a typed registry whose API refuses a string literal at compile time.
- **Network.** The only URL literals added are four `https://example.invalid/...` seeds — RFC 2606 reserved and **guaranteed non-resolvable** — plus one documentation link in a comment. `url_launcher` appears exactly once in all of Mission 5: **in a doc comment explaining why it was not added.** It is not a dependency. `launchUrl`, `canLaunch`, `WebView`, `HttpClient`, `Dio(`, `Socket`, `WebSocket`: all zero. **No outbound capability was added despite open item 80's proximity**, which was checked explicitly because that item makes it plausible.
- **Boundaries.** 14 package confinements, **30 cross-feature pairs**, core-neutrality — re-run from `ci.yml` rather than cited from Mission 5.6. Exit 0.

### The two fixes

**Finding 2 — the core-neutrality check covered 3 of `core/`'s 12 modules.** Fixed by deriving the list from the filesystem. The comment beside the old list read *"adding a third contract module is one word rather than ten lines someone can forget to keep in step"* — Mission 5.4 added a fourth and **the one word was forgotten anyway**, which is the argument for removing the failure mode rather than patching the instance. No violation existed; all nine unchecked modules were verified clean by hand. Proven non-vacuous by planting an import in `core/time/` — a module the old list did not reach — and watching the check fail with a named path.

**Finding 3 — Mission 5 wrote 79 changelog lines, all under "Added", none under "Security."** Written now for the onboarding store.

### A labelling collision this review nearly created

The findings were drafted as **S-1, S-2, S-3**. Checking the register before writing them up found that **open items 27, 28 and 29 are already labelled S1, S2 and S3** — Mission 3.11's security review, using the same scheme for entirely different findings.

**So those labels are not used here.** This is the same hazard A-069 and open item 34 record for ADR numbers, appearing in a second namespace: a short label that reads as globally unique inside one document and is not. A future reader searching the register for *"S2"* would have found two unrelated things.

### And a rule the same check surfaced

Open item 29 names the governing requirement for finding 3: **Volume 11 Chapter 11.5 §2 requires Security entries for storage and data handling.** The changelog entry had been written citing only the *precedent* — this file's own persisted-chunk-fields entry — which is weaker. The rule is cited now. **Precedent shows an entry of this shape exists; the rule is why one was owed.**

---

### A-139 — Why open item 101 and A-126 stay architectural, with the reasoning rather than the verdict

| | |
|---|---|
| **Question** | Are the seven ADR-022 R2 breaches, or `core/onboarding/`'s `app/ ↔ feature` stretch, security-relevant? |
| **Answer** | **No, to both.** Purely architectural. |
| **Date** | 2026-08-17, Mission 5.7 |

Recorded with the argument attached, because **the verdict alone would be re-litigated by the next reviewer, and could be reversed by anyone who assumed a different premise.**

### Item 101 — the seven R2 breaches

**Reason 1: the breaches are inbound only.** All seven are `lib/app/` reading feature types — `AuthState`, `Role`, `User`, `RecordingState`. Nothing is exposed outward; no value crosses a boundary in the direction that would let one principal read another's data. A layering breach becomes an information-boundary issue when it lets data *escape*, and these move data toward the shell that already renders it.

**Reason 2, and the decisive one: `AuthGuard` is not a security control**, in its own words at `auth_guard.dart:71`:

> *"the backend refuses the data regardless (Volume 4 Chapter 4.8 §1), so this is a navigation correction and not a security boundary."*

BR-19 and BR-20 are enforced **server-side from the verified token**. The worst a compromised guard can do is send someone to a screen the server will not populate.

**The premise that would change this answer, stated so it can be checked rather than assumed:** if any guard ever became the *only* thing standing between a role and data — a client-side filter over a response the server scoped loosely, say — then its imports would become an information-boundary question and item 101 would need elevating. **That is not today's architecture**, and Volume 4 Chapter 4.8 §1 is what makes it not.

### The `core/onboarding/` stretch (A-126)

`core/onboarding/` carries **one boolean about whether a carousel has been shown**. It crosses no trust boundary, gates no access, and moves no data between principals. Forging it in either direction changes which informational screen renders and nothing else.

The stretch A-126 records is about **where a contract lives**, not about **what it protects**. Those are different questions and only the first is open.


---

### A-140 — Mission 5 cannot move a Feature Tracker row, and the rule that says so is this project's own

| | |
|---|---|
| **Volume** | 11, Chapter 11.6 §4 — the Verified bar |
| **Found** | 2026-08-17, Mission 5.8, while framing the status report |
| **Class** | A finding about project state, not a document edit |
| **Consequence** | Every Mission 5 status claim is *Built (unverified)* at best |

### The fact

    origin/mission-0.18.4-ci   67cd79b   2026-08-16   CI run #13, 10 of 10
    HEAD                       de5de9a   2026-08-17
                               67 commits ahead — 64 of them Mission 5

**CI has never executed a line of Mission 5.** Every check the mission
reported green — 1038 tests, 56 boundary checks, 7 token rules, 14 package
confinements, 5 secret patterns — was run on a developer machine, in most
cases by extracting the step from `ci.yml` and executing it directly, so that
the numbers would be real. They are real. They are not CI.

### Why that is a state finding and not a logistics note

Chapter 11.6 §4, which `docs/development/feature-tracker.md` quotes in full:

> *"A row moves to 'Verified' only once its Volume 9 test coverage (Chapters
> 9.6/9.7) actually passes in CI — **not on the developer's local machine**."*

The rule does not express a preference. **It makes the Feature Tracker unable
to record Mission 5's work as Verified at all** — ten screens, a navigation
graph, an accessibility pass verified on physical hardware, and 249 new tests,
none of which can move a row.

**The tracker's own text had gone false and was corrected rather than left
standing.** It read *"Run #13 — the current HEAD, `67cd79b` — reports 10 of
10. The suite it runs is 789 tests."* Neither clause is true now.

### The four Verified rows are annotated, not demoted

Mission 4 moved FR-AUTH, FR-CHK, FR-REC and FR-CHNK to Verified on run #13's
authority. **That run happened and its evidence is real for the code that
existed then.** What changed is that the evidence is now 64 commits old, and
Mission 5 modified files inside two of those groups — `recording_screen.dart`
and `pre_recording_checklist_screen.dart`.

They keep their status and carry **⚠ stale**. FR-CHNK was not touched at all
and is annotated anyway, because **the honest statement is about the age of
the evidence rather than the size of the change**, and a marker applied only
where a file happened to change would imply the others had been re-confirmed.

### There is specific reason to expect the first run not to be green

Not a hedge — three named risks:

1. **The golden tests have never seen this mission.** They skip locally by
   design (A-095), so they are 2 of the suite's 3 skips, and Mission 5.7
   changed `chunk_status_pill.dart` — **the one widget with committed
   baselines**. `excludeSemantics: true` should be pixel-neutral; "should" is
   what a golden exists to check.
2. **Sixty new accessibility tests render text on a host that has never run
   them**, and open item 19 already recorded Windows and Ubuntu producing
   different bytes for these widgets.
3. **Mission 4's report predicted it**, under *"EXPECT A FOURTH UNEXERCISED
   MECHANISM"*.

### Why this is recorded as an amendment and not only in the report

The status report is gitignored — a working artifact, not a governed one. This
finding outlives it: **any future reader of the Feature Tracker needs to know
that four rows read Verified against a 64-commit-old run**, and that the rule
forbidding local verification is the reason Mission 5's output shows nowhere in
the table. Recorded here so it survives the report being deleted.

**It resolves on one action** — push the branch and get a green run — which is
recommendation 1 of the Mission 5 handoff, ahead of every product decision.

## ⚠ THE SOFT-DELETE BLIND SPOT — one root cause, three symptoms, one fix

**This is a recommendation, not a cross-reference. It is placed here rather than inside an open-item row because three items now point at it and each reads, on its own, like a small local wart.**

### The cause, stated once

`IsarChunkStore.currentQueue` skips every row with `localDeletedAt != null`, and `watchQueue` is built on it. Chapter 5.15's cleanup soft-deletes a chunk once the backend has it. **So the only query this application has over chunk rows is one that forgets completed work**, and there is no read path over all rows including swept ones.

That is correct for the queue's own purpose — Chapter 5.9's queue is a work list, and finished work does not belong on it. It is wrong for every other question anyone has asked of that data since.

### The three symptoms, and what each one costs

| Item | Symptom | What it costs |
|---|---|---|
| **61** | A completed chunk vanishes from C-11 once swept | Chapter 2.7 has no "how long does done stay visible" rule, so the screen answers "not at all" |
| **76** | *Total recorded time* cannot be computed | A queue-sum **decreases as the Collector records more**, peaking before the first sweep |
| **81** | A fully-swept session disappears from C-11 entirely | FR-SES-01 asks the system to *"track the state of every session … end to end"*; a view that forgets finished sessions does not |

They were found in three different missions, by three different people-shaped tasks — a device probe (4.5), a dashboard aggregate (5.1.2), a session heading (5.1.4) — and each was recorded where it was found. **Read as three items, each looks like a UI omission worth a small local fix.** Read together, none of them is a UI problem at all.

### Why three local workarounds would be worse than one fix

Each symptom has an obvious cheap answer, and every one of them encodes the defect a little more deeply:

- **61** — keep completed rows in the queue for N hours. Puts finished work back on a work list and gives Chapter 5.9's ordering a new class of row to reason about.
- **76** — sum durations before cleanup and cache the running total. A second source of truth for a number derivable from the rows, which is the failure ADR-018 exists to prevent.
- **81** — group by session before filtering, so an empty session still shows. Renders a session with no chunks and no status, which is a heading over nothing.

Three separate patches, three new invariants, and the underlying fact — *this application cannot read its own completed work* — still true afterwards and now harder to see.

### The fix, and why it is small

**One history-capable read path over `local_chunks`, including soft-deleted rows**, exposed through a `core/` contract the way `ChunkQueueSource` already is. The rows are all still there — `localDeletedAt` is a marker, and A-087 records that soft delete *"never removes"*. Nothing needs migrating and nothing needs re-recording; what is missing is a second query and the contract to reach it.

It closes 61, 76 and 81 together, and it is the only thing that closes 76 at all.

### **RECOMMENDATION, for whichever mission owns it**

**Build the history read path before building anything else that reads chunk rows.** Every surface added since Mission 4.5 has hit this, the count is rising by one per sub-mission, and each new consumer that works around it locally makes the eventual fix touch one more screen.

**The fourth consumer is already identifiable: A-07 Admin Sessions asks *"what has this Collector done"*, which is a history question, not a queue question.** Written down at Mission 5.1.4 rather than left for Mission 5.2 to rediscover — the first three were each found by whoever happened to be building that week, and predicting the fourth is the cheapest way to stop that being four for four. Mission 4.9 §4 set the same precedent by predicting its own fourth instance instead of waiting to be surprised by it.

This belongs in Mission 5's status report as a ranked recommendation in its own right — **not as three cross-referenced open items**, which is how it currently reads and which is precisely how a shared cause gets mistaken for a coincidence. Mission 4.9 §4 named its pattern rather than listing three unrelated CI defects, and the same instrument applies here.

---

## ⚠ M7 — "UI COMPLETE" — IS NOT MET AND MUST NOT BE CLAIMED

**Recorded 2026-08-16 at Mission 5.1.5, in the same form and for the same reason Mission 4.9 wrote *"M6's 'Upload Engine Working E2E' milestone is NOT met and must not be claimed"* while most of the upload engine existed.**

Volume 11 Chapter 11.2 §1 fixes the exit criteria:

> **M7 — UI Complete.** *"Every screen in Volume 2, Chapter 2.5's inventory is built and matches the Design System (Chapter 2.8) and Wireframes (Chapter 2.6)."*

**Three independent reasons. Any one of them is sufficient on its own.**

### 1. C-12 cannot be built as specified, and will not be by item 36 alone

A-115 has the full argument: Chapter 2.7's table forbids the partial version in the words *"never on partial completion"*; this client never observes `verified_at` and would not after a backend existed (item 83); C-12 has no trigger and no place in Chapter 2.4's navigation model (item 84); and its specified return destination needs the `taskId` item 79 does not supply.

### 2. Chapters 2.6 and 2.8 are not in this repository

M7's criteria require every screen to **match** the Design System and the Wireframes. Neither document is here (A-102, item 74). **The clause cannot be evaluated at all** — not failed, not passed, unevaluable — and a criterion nobody can check is not a criterion that has been met.

### 3. Screens in the inventory remain placeholders or absent

**Restated 2026-08-16 at the close of Mission 5.2, against actual state.** C-02 (Permission Blocked) is unbuilt and blocked on item 78; C-13 and C-15 are Phase 2; C-12 is traced and unbuildable (A-115). On the Admin side, **A-01, A-02 and A-03 are built**, **A-04 and A-05 have their create halves** with their edit halves blocked on items 87 and 90, **A-06 and A-07 are traced and correctly not built** (A-122, A-124), and **A-08 is deferred with cited reasoning** — it needs the `metadata` module Volume 3 Chapter 3.5 §2 assigns it, which does not exist (item 97).

**The conclusion is unchanged and this reason remains independently sufficient**: Chapter 2.5's inventory is 23 screens, several are unbuilt or unbuildable, and that is not a rounding error. What changed is only the evidence — the previous wording said *"A-01 through A-08 are Mission 1.3 placeholders awaiting Mission 5.2"*, which was true when written and outlived its fact. **A section that exists to prevent premature checking should not be inaccurate in the pessimistic direction either**, and A-114 records the same failure mode in a doc comment: nothing checks a claim that was correct on the day it was made.

### The trap this section exists to prevent

Chapter 11.2 §2 names it, using M7 as its own worked example:

> *"A milestone is not marked complete until its exit criteria is fully met — **partial completion (e.g. 'most screens built' for M7)** is tracked as in-progress against Chapter 11.3's sprint backlog, not prematurely checked off here."*

**The volume picked this milestone, by name, as the illustration of premature checking.** Missions 5.1.1–5.1.4 built seven Collector screens, which is real progress and is exactly the condition under which a gate starts looking closer than it is. Building *something* named C-12 would have made the inventory read complete while moving the gate not at all — which is why 5.1.5 built nothing.

### What would change this

All three reasons, not any one: item 36 and items 83, 84 and 79 for C-12; item 74 for the match clause; Mission 5.2 and beyond for the remaining screens. **Until then M7 is in progress, and any status report that reads otherwise is wrong.**

---

## Consolidated open items — A-057 through A-140

Every carried-forward item, in one place. Accurate as of **Mission 4.3**; originally the seed for Mission 3.12's status report, and re-checked at the close of each sub-mission block per item 23.

### Blocked on an unbuilt feature module

| # | Item | Owner | Source |
|---|---|---|---|
| 1 | `project_id`, `task_id` unsourced — stored as `MetadataIdentity.unsourced` | `features/projects_tasks/` (unbuilt) | A-062 §1, A-064 §3 |
| 2 | `local_task_cache` table not implemented | `features/projects_tasks/` | A-063 §2, ADR-039 §3 |
| 3 | ~~`s3_object_key` stored null — key needs `org_id`/`project_id`/`task_id`~~ **Premise corrected 2026-08-15 (Mission 4.2): the client never composes the key — the Lambda does and returns it (V4 Ch. 4.10 §2). The column is null because registration has not happened.** The real blocker is one level up: Ch. 5.10 §1 step 1's URL needs a **backend session id** from `POST /v1/tasks/{id}/sessions`, which needs a `task_id`. `SessionRegistrar` names the port; nothing implements it. | `features/projects_tasks/` (unbuilt) | A-063 §5, A-071 |

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
| 14 | ~~`battery_plus` applies~~ **Three plugins apply** the legacy Kotlin Gradle Plugin | **Widened 2026-08-16 by Mission 4.3, from a build rather than from a reading.** `flutter build apk --debug` names `battery_plus`, `cloud_functions` **and** `flutter_foreground_task`. `cloud_functions` was already in the tree and this item never mentioned it, so the item understated the exposure before 4.3 added to it. Builds today; a future Flutter will refuse it. Mitigating: `cloud_functions` retires with ADR-036 at Mission 6/7 | A-064 §4a, ADR-042 |
| 15 | Software-encoder fallback and unmeasurable flush interval | Silent by nature | A-058 |
| 16 | An in-flight chunk is unrecoverable after a crash | Structural to the plugin; at most one chunk per crash | A-063 §3, A-064 §1 |
| 17 | Android 16 KB page-size support unverified for Isar | Release-blocking rather than development-blocking | ADR-009 |

### Testing and verification

| # | Item | State | Source |
|---|---|---|---|
| 18 | Data-layer coverage vs Chapter 9.5 §2's 80% | **Still missed, still one file, and the trade is already decided — see A-096.** Re-measured 2026-08-17: **71.7%** (594/828), up from 68.3% at Mission 4.7 and 76.90% at Mission 3.10. `isar_chunk_store.dart` is **1.9%** (4/212 lines) and is a quarter of the layer; **excluding it the layer reads 95.8%** (590/616). A-096 declined the only available fix — `Isar.initializeIsarCore(download: true)` — because it puts a network fetch into every CI run and every offline developer build. **Not re-opened for a decision already taken**; this row carries the current number so the figure in A-096 is not read as today's. | A-096, A-137, A-066 |
| 19 | ~~Golden tests for Design System components~~ **CLOSED 2026-08-16 — verified green on CI run #11** | A-027's open question is answered without adding a dependency: `matchesGoldenFile`, built into `flutter_test`. `golden_toolkit` supplied convenience — device configs, font loading — not capability, and Chapter 9.7 §2's requirement never needed it. Four status pills in both themes, tagged `golden`, skipping off CI so a developer-rendered baseline cannot be committed (A-095). **Closed on a run that verified rather than generated.** Run #11 reports `Verify goldens: success` with `Regenerate` and `Explain` skipped — the inverse of run #10, which skipped verification and regenerated. The job discriminates rather than doing one thing regardless, which is what makes the gate real. All ten jobs green. It took three runs, and the two failures were both worth having: #9 established that Windows and Ubuntu render these widgets differently even with no fonts rasterized, and #10 exercised the bootstrap path for the first time. The `workflow_dispatch` design this replaced could never have run at all (open item 48). Corroborating the host difference that made CI-only generation necessary: the Ubuntu baselines differ in size from the Windows ones (7,351 vs 7,367 bytes dark; 7,513 vs 7,527 light), so the two hosts genuinely render these widgets differently even with no fonts rasterized. **Editorial note, Mission 4.9:** this row carried an orphaned *"Still not closed"* paragraph and a duplicated source column, left behind when 4.7.11 closed the item without removing the pre-closure text — a row that asserted both states at once. Removed here; the evidence it carried is folded in above. | A-027, A-095, Ch. 9.7 §2, open item 48 |
| 20 | `integration_test` end-to-end flows (Ch. 9.7 §1's five) | Package not installed | A-028 |
| 21 | ~~`recoverableChunkIds()` has no caller~~ **Half closed 2026-08-16 by Mission 4.5** | `orphanedChunkIds()` now has a caller and a fixed bug: Chapter 5.15's sweep reports it, and the method excluded nothing before, so **every successfully cleaned chunk would have reported itself as an orphan**. Verified on device — after nine cleaned rows and one file deleted behind the store, it reports exactly **1**, not 10. `recoverableChunkIds()` is still uncalled and still deliberately so: it answers which *queued* chunks still have a file, which is neither the queue's question (Ch. 5.9 §3 just re-reads the rows) nor cleanup's. It is owed to a dedicated integrity pass, and nothing has needed one yet. | A-064 §2, Mission 4.2, Mission 4.5 |
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
| 28 | **S2** — the empty-string identity sentinel is ambiguous on the wire | **Half closed.** **Guard 1 CLOSED 2026-08-15 by Mission 4.2** — `ChunkMetadataDocument.isIdentityComplete` is checked before Ch. 5.10 §1 step 1, and a failing chunk is marked `failed` with a named terminal cause. It refuses every chunk recorded on a device today, which is the guard working. **Guard 2 remains open**: Ch. 8.3 §2's server-side rule rejecting blank identity fields, owed whenever Lambda handlers exist. A client-side check is a correctness measure, not a security boundary — V4 Ch. 4.8's *"never client-trusted"* applies to attribution too. | A-068 |
| 29 | **S3** — no changelog existed, despite Ch. 11.5 §2 requiring Security entries for storage and data handling | **CLOSED** by Mission 3.11.2 (`4f992da`) — `docs/CHANGELOG.md` started and Missions 3.1–3.10 backfilled. The backfill is itself the batching Ch. 11.5 §4 warns against, done once to establish the file. | Ch. 11.5, A-068 |
| 30 | Volume 8 Ch. 8.2 §3's inline "ADR-011" collides with this repository's ADR-011 | **Open** — documentation hazard. Cite it as "Volume 8 Chapter 8.2 §3", never as ADR-011. The decision itself is satisfied: OS-level sandbox encryption, no app-level layer owed. | A-069 |
| 31 | CameraX `GRAPH_ERROR(ERROR_GRAPH_CONFIG)` on every session close | **Open, uninvestigated.** Fires after a successful `stopChunk()`, during `closeSession()`. Affected no run — chunk written, row committed, session completed each time. May be teardown noise or an unclean close that leaks across repeated sessions. Not assumed harmless. | A-070 §6 |
| 32 | A device harness that drives the notifier cannot see UI wiring | **CLOSED for this case** by Mission 3.12-PRE (`09f40ac`)'s widget test; the general lesson stays open. **Third instance of "a whole checked in parts"** (cf. items 23, 26). Mission 3.8.1 returned `RESULT pass` twice while nothing in `lib/` called `start()`. Closed for this case by a widget test that taps the button; the general lesson is that an unattended harness proves the layer it drives and silently assumes the layer above calls it. | A-070 §3 |
| 33 | `flutter install` deploys a stale artifact | **Use `flutter run`, or `flutter build` immediately before `flutter install`.** It installed Mission 3.8's pre-fix APK and reported success, causing a fix to be reported as on-device when it was not. "Install succeeded" is not evidence the change is on the device. | A-070 §4 |
| 34 | Volumes' inline ADR citations collide with this repository's ADR numbers | **Sweep all Volumes, rather than fixing each as it is hit.** Confirmed in Volume 8 Ch. 8.2 §3, across Volume 3 Ch. 3.2's whole inline sequence, and inherited by Volume 5 Ch. 5.8's header. **Second instance found 2026-08-15 by Mission 4.2: Volume 5 Ch. 5.10 §2 and §4 both cite "ADR-004" for Dio's progress callbacks and cancellation tokens — this repository's ADR-004 is GoRouter; the real record is ADR-007 (network configuration).** Two missions running, a citation collision has been found by whichever chapter happened to be read, which is the pattern rather than the exception. A single pass listing every inline `ADR-NNN` and what it actually means would turn a recurring trap into a lookup table. Not attempted in 4.1, 4.2 or 4.3 — out of scope for all three. **Third instance found 2026-08-16 by Mission 4.3: Volume 5 Ch. 5.11's header cites "ADR-003", which is Volume 3 Ch. 3.2's own Background Upload record; this repository's ADR-003 is Riverpod.** Three missions, three collisions, each found only because someone happened to read that chapter. The recommendation is unchanged and now three-for-three. A-077 carries Volume 3's internal sequence as a partial lookup table. **Fourth instance found 2026-08-16 by Mission 5.1.1, and it is the first one A-077's table caught in advance rather than after the fact: a mission brief's "ADR-006 (fake repository / provider interface pattern)" is Volume 3 Ch. 3.2's own Dependency Injection record; this repository's ADR-006 is Centralised Application Configuration.** Two findings change the recommendation's shape. **First, the trap is not confined to the Volumes** — this one arrived in a *brief*, and briefs are written fresh every mission, so a one-off sweep fixes the fixed corpus but not the regenerating channel. **Second, it has now reached shipped code**: `core/upload/interfaces/session_registrar.dart` cited *"Volume 11's M12 gate"* for the no-fake-in-a-release-build rule, which is **M8 — APIs Integrated**; M12 is Store-Ready and says nothing about fakes. Corrected 2026-08-16 in a standalone commit. The sweep should therefore cover `lib/` doc comments as well as the Volumes, and the rule to carry is that **any `ADR-NNN` or milestone id written outside `docs/architecture/decisions/` is ambiguous until resolved against the real files.** | A-069, A-077, A-099 |
| 35 | **No field bandwidth-floor NFR exists** (Volume 1 Ch. 1.4) — `S3TransferClient` consequently has no send timeout | **Raising this NFR is a product decision, not an engineering one, and belongs in its own conversation rather than inside an implementation mission.** Deferred, not resolved. No number was proposed and none was guessed. The constant becomes derivable the moment the NFR exists. | A-072 |
| 36 | Backend session registration has no implementation — `SessionRegistrar` is a named, unowned port | **Owed to whichever mission builds `features/projects_tasks/`.** Ch. 5.10 §1 step 1's URL needs a backend session id from `POST /v1/tasks/{id}/sessions`, which needs a `task_id`. `sessionRegistrarProvider` throws; a fake satisfies it in tests only. **Until this lands the pipeline cannot upload anything**, which is why 4.2's verification is against the fake rather than a real endpoint. | A-071, Ch. 4.6 §4 |
| 37 | Guard 1 refuses 100% of chunks recorded on a device | **Correct behaviour, not a defect — and the reason it fires is items 1, 5 and 11.** Four of `MetadataIdentity`'s five fields carry the unsourced sentinel, so no real chunk can be uploaded until `features/projects_tasks/`, the `collector_id` inversion and a `device_id` source all exist. Named here so nobody reads an empty upload log as a broken pipeline. | A-068 Guard 1, A-062 §1 |
| 38 | `LoggingInterceptor` logs full request URIs, and redaction is header-only | **Decide in Mission 4.8.** No Vump endpoint puts a secret in a query string today and Ch. 4.6 §1 uses cursor pagination, so nothing is exposed. But a future endpoint taking a signed parameter would leak it silently. `S3TransferClient` avoids the problem by not installing the interceptor at all; the general mechanism is unchanged. Not fixed in 4.2 — a change to a verified path, out of scope. | A-074 |
| 39 | Presigned-URL redaction is a design-time mitigation and has not been re-verified against shipped code | **Mission 4.8 must confirm it as a confirmed-safe item, not assume it from Mission 4.2's report.** Four things to check: `redactUrl` applied at every log site in `S3TransferClient`; no interceptor added to it; no other path prints a presigned URL, including via an exception's `cause`; `ChunkRegistration.toString()` still omits the URL list. | A-074 |
| 40 | `integration_test` and Ch. 9.7 §1's local mock server are still not installed | **Belongs in Mission 4.7**, and **M6's "Upload Engine Working E2E" claim in the 4.9 report depends on 4.7 actually building it.** Mission 4.2's two-tier fake is the nearest available substitute — a scripted `HttpClientAdapter` under the real client stack — but it runs in `flutter_test`, not against a server, and it is not what Ch. 9.7 §1 specifies. Explicitly not built in 4.2. | Ch. 9.7 §1, open item 20 |
| 41 | A green check over an empty set is not evidence | **Ask, at each mission that introduces a first consumer of anything, which dormant rules it has just woken up.** `dio`'s confinement passed for eleven missions because nothing outside `core/network/` made an HTTP request; ADR-022 R3 was *"binding in writing and unenforced in fact"* while there were no features. **Fourth instance of "a whole checked in parts"** (cf. items 23, 26, 32). Asked and answered in 4.3: the dormant rules woken were the fourteenth package confinement, the first foreground service, the first isolate entry point and the first manifest permission. | A-076 |
| 42 | ~~The `Format` CI job is red on `mission-0.18.4-ci`~~ | **FIXED 2026-08-16 by Mission 4.3.3 (`97e1aca`)** — `dart format` applied to the 16 flagged files (6 in `lib/features/recording/`, 9 in `test/features/recording/`, 1 from Mission 4.1). Formatting only, and checked rather than trusted: each file compared against its parent with whitespace removed and optional trailing commas normalised away, all 16 identical. Generated sources excluded, matching the job's own file list. **Fifth instance of "a whole checked in parts"** (cf. items 23, 26, 32, 41) — found by running the full sweep instead of the touched subset, exactly as item 26 recommends. **Confirmed by local replay of the job's logic (261 files, exit 0), NOT yet by a real CI run — see item 48.** | Mission 4.3 verification, 4.3.3 |
| 43 | The concurrency bound is 2, chosen rather than derived | **Replace with a measurement, not with a different guess.** A pilot on a real field connection, or the bandwidth-floor NFR item 35 already waits on, turns it into a derived value. Constructor-injected so a measurement lands without touching dispatcher logic. | A-078 |
| 44 | Manual upload mode (FR-UPL-02, Ch. 5.9 §4) has no configuration source | **Owed to whichever mission gives FR-UPL-02 a surface.** No `UploadMode`, no setting, no chapter saying where it lives; `features/settings/` is empty. The dispatcher always claims automatically. Safe to add later because §4 states the queue's model is identical in both modes — only the claim trigger changes. No port was built, deliberately. | A-080 |
| 45 | `flutter_foreground_task` merges `RECEIVE_BOOT_COMPLETED` and an **exported** `RebootReceiver` into the app manifest | **Security review, not a self-fix.** Confirmed in the merged debug manifest. `autoRunOnBoot` and `autoRunOnMyPackageReplaced` are both `false`, so the receiver has nothing to start — but the permission is requested and the receiver is `android:exported="true"`. Removable with `tools:node="remove"`; not attempted in 4.3 because a manifest-merger change is a build-wide risk that belongs in a commit that can be reverted on its own. Also visible in the same merged manifest and pre-existing: `READ_EXTERNAL_STORAGE`, `USE_BIOMETRIC`, `USE_FINGERPRINT`, `c2dm.permission.RECEIVE`. | Mission 4.3, ADR-042 |
| 46 | `applicationId` is still `com.example.mobile` | Untouched by 4.3 and noted once. The notification channel, the service and any future FCM registration all key off it. A release blocker rather than a development one, and it belongs with signing config (`build.gradle.kts` still signs release with debug keys). | Mission 4.3, V10 Ch. 10.1 |
| 47 | ~~The `AWS credential isolation` CI job is red on `mission-0.18.4-ci`~~ | **FIXED 2026-08-16 by Mission 4.3.4 (`a835112`)** — the `amazonaws\.com` **endpoint** grep is scoped to `lib/`. It looks for a design defect (shipped code that stopped waiting for a presigned URL), which can only exist in shipped code. **The three credential-material greps still cover `lib test`**, deliberately: a real access key, secret or session token under `test/` is exactly as disclosed as one under `lib/`, and narrowing those would have traded a real guarantee for a green tick. The four flagged lines were read before the change — presigned-URL fixtures whose assertions are `isNot(contains('X-Amz-Signature'))`, using an `AKIAEXAMPLE` placeholder deliberately too short to match the job's own AKIA pattern. **The job was failing on the evidence that the rule it protects is being followed**, which is A-075's fault exactly. Verified by deliberate breakage in both directions, including a fake key planted in `test/` to prove the narrowed scope opened no hole. **Confirmed by local replay only — see item 48.** | Mission 4.3 verification, 4.3.4, A-075 |
| 48 | ~~No CI run has ever executed against this repository's work~~ **The pipeline ran for the first time on 2026-08-16, at Mission 4.3.7 — 7 of 9 green** | **RESOLVED as a question, and it paid for itself immediately.** The run was obtainable only by a pull request from `mission-0.18.4-ci` into `main`: the `push` trigger does not cover this branch; `workflow_dispatch` is unusable because `.github/workflows/ci.yml` does not exist on the default branch (`main` predates it by ~78 commits); and `pull_request` is scoped to `[main, develop]` while **`develop` does not exist on the remote** — A-022's missing-`develop` gap surfacing as a broken trigger rather than as a topology question. Those three facts remain true and are the substance of this item. **Green (7):** Format, Analyze, Test, Generated code drift, Architecture boundaries, Secret scan, AWS credential isolation — confirming the local-replay claims made across Missions 1, 3, 4.1, 4.2 and 4.3 were accurate, including items 42 and 47's fixes. **Red (2):** `Environment consistency` (item 49) and `Commit convention` (PR-title only; no repository content involved). **And one of the greens was hollow** — item 50. Twelve missions of reasoning about this pipeline produced two jobs that had never worked and one that had never looked where it claimed to. | Mission 4.3.5, 4.3.7, A-022, ADR-019 |
| 49 | ~~The `Environment consistency` job has never been capable of passing~~ | **RESOLVED 2026-08-16 by Mission 4.3.10 (`3eec42e`)** — the job now overrides the workflow default with `working-directory: .`, so its repo-root-relative paths resolve. Broken from the commit that created it (`63d97e5`) until now: `infrastructure/aws/config/environments.json` became `mobile/infrastructure/…` and `mobile/lib/app/config/app_environment.dart` became `mobile/mobile/lib/…`, and it died on `FileNotFoundError` before evaluating a single assertion — so across ~78 commits it never once compared Dart, JSON and shell. **Now verified to actually check**, not merely to pass: a planted region drift (`ap-south-1`→`us-east-1`) and a planted bucket drift (staging→production) are each caught, and the clean tree passes either side. The model it guards was correct all along. | Mission 4.3.7, 4.3.10, `63d97e5` |
| 50 | ~~SECURITY — the `Secret scan` job reports green while scanning 79% of the repository~~ | **RESOLVED 2026-08-16 by Mission 4.3.10 (`3eec42e`)** — same one-line override. `git ls-files` and `git grep -- .` are both cwd-scoped, so under the `mobile` default the job saw **444 of 561** tracked files and **zero** under `infrastructure/`, where the AWS configuration lives, while reporting green. It now sees **561 files, 18 of them under `infrastructure/`**. **Verified by planting secrets where the job previously could not look**: a fake `AKIA…` key and a PEM private-key banner line, each added to `infrastructure/aws/env.sh`, are each caught; both removed and the tree re-verified clean. (The banner is described rather than quoted: spelling it out here made this file itself match the scan — the same self-matching fault as A-075 and item 47, and the third time a check has fired on a true statement about itself.) No real credential was ever present — the finding was the absent coverage. Item 41's *"a green check over an empty set is not evidence"* in its most literal form, and the reason a hollow green is worse than a red. | Mission 4.3.7, 4.3.10, ADR-016 |
| 51 | ~~Root cause of 49 and 50 — the workflow-level `working-directory` default~~ **Root cause of 49, 50 and a third manifestation: `Commit convention`** | **RESOLVED 2026-08-16 by Mission 4.3.10 (`3eec42e`), option (a).** Each of the three repo-scoped jobs overrides the default with `working-directory: .`; the default is untouched for the six Flutter jobs. **The third manifestation, found 2026-08-16 by Mission 4.3.9**: `Commit convention` is the only job with no checkout — by design, with `permissions: {}` — so `mobile/` did not exist on the runner and the step **could not start at all**. It failed with a process-start error that reads as *"your PR title is wrong"*, and the title (`feat(features/upload): implement Volume 5 Chapters 5.9-5.11`) was confirmed byte-for-byte correct against the validator extracted verbatim from `ci.yml` — 59 chars, no non-ASCII, exit 0. **A check that reports the author's mistake when the fault is its own is worse than one that simply crashes.** Option (b), dropping the default, would have touched all nine jobs to fix three. Option (c), mobile-relative paths, would not have fixed `Commit convention` at all and would have encoded the repo layout into a security scan's path strings — which is how item 50 happened. **No checkout was added**: `$GITHUB_WORKSPACE` is created by the runner before any step, so `.` is a real directory with nothing checked out, and adding one would have forced `permissions: {}` to widen to `contents: read`, contradicting the job's stated design. Verified in an empty temp directory containing no repository. All three fixes were verified by deliberate breakage in both directions, as this item required. | Mission 4.3.7, 4.3.9, 4.3.10 |
| 52 | **NFR-REL-02 is not met — every retry re-sends the whole chunk** | **Blocked on open item 36**, the same `SessionRegistrar`/backend gap that blocks the pipeline itself. Resuming a multipart upload needs the backend to return an existing `uploadId` and the parts it already holds; local part-tracking alone would be state with no counterpart. BR-11's no-duplicate guarantee **is** met — same `chunk_id`, same deterministic key. What is missed is the cost half: a 610 MB chunk re-sends from byte zero on every attempt. | A-084, open item 36 |
| 53 | Connectivity does not revive a `failed` chunk | **Needs a `failureCause` column on `local_chunks`** and a rule for which causes are revivable. Ch. 5.13 §2 says an exhausted chunk waits for *"connectivity/context to change … or a manual retry"*; only the manual half is automatic-free today. Reviving blindly would re-attempt terminal failures against §1. Worth doing together with C-11's per-row cause display, which needs the same column. | A-085 |
| 54 | The `Volume 5.10` chapter reference is wrong in two documents | **A documentation pass, distinct from open item 34.** V3 Ch. 3.3 §6 and V1's NFR-REL-03 Target both cite *Volume 5.10* for retry/backoff and duplicate prevention; those live in **5.13** and **5.14**. Item 34 is about inline `ADR-NNN` collisions — this is a chapter-number drift, and two documents sharing one wrong reference suggests a single stale source. | A-084 |
| 55 | `dart format` over `lib/` and `test/` silently reformats generated sources | **Format only the CI file list, never the whole tree.** The `Format` job excludes `*.g.dart` and `*.freezed.dart`, but `Generated code drift` compares them — so a blanket `dart format lib test` turns a green format run into a red drift run. Cost 33 files and ~6,200 lines of spurious diff in Mission 4.4 before it was caught and reverted. The safe command is the job's own: `git ls-files '*.dart' \| grep -v '\.g\.dart$' \| grep -v '\.freezed\.dart$' \| xargs dart format`. **REFRAMED 2026-08-16 by Mission 5.3, after a THIRD occurrence in a single session.** Missions 5.2.1, 5.2.2 and 5.3 each ran `dart format <directory>` and each reformatted every generated file beneath it — 5.3's run touched roughly 7,000 lines across 30 files. All three were caught before commit, two of them in the same command chain. **Three misfires under close attention, by someone who had read this item each time, is evidence about the mitigation rather than about the people.** The recommendation asks a human to remember not to type the natural thing: `dart format lib/features` is what anyone reaches for, and the safe form is a four-stage pipeline nobody types from memory. A rule whose only enforcement is recall has the same standing as the changelog discipline that failed twice before item 66 was raised — and item 66's own conclusion was that *"every enforcement this project actually trusts lives in CI"*. **The question the next person should inherit is not "how do we remember?" but "how do we make the unsafe command fail loudly?"** Candidates, none attempted here: a `format.sh` in `scripts/` that is the only documented way to format, so the pipeline is typed once and never again; a pre-commit hook rejecting a staged diff that touches `*.g.dart` or `*.freezed.dart` without a `build_runner` run behind it; or accepting the churn and letting `Generated code drift` be the backstop, which is the status quo and has caught it every time — at the cost of a revert each occurrence. **Deliberately not solved by Mission 5.3**, which had no business changing the tooling contract mid-sweep; reframed so the item states the right problem. | Mission 4.4 verification, Missions 5.2.1/5.2.2/5.3, item 66 |
| 56 | ~~Chapter 5.13 §2's six-attempt exhaustion path has not been seen on hardware~~ | **CLOSED 2026-08-16 by Mission 4.7.2.** Observed end to end on a CPH2707 with the radio off: attempt 2 waited 5s, 3 waited 9s, 4 waited 20s, 5 waited 40s, 6 waited 90s — every draw inside §2's ±20 % of 5/10/20/40/80 — and after the sixth the chunk logged *"failed after 6 attempts (transportFailure). It now waits for a manual retry or for the network to change."* 166 seconds end to end. The budget, the doubling, the jitter and the terminal transition are all now device-observed rather than unit-tested only. | Mission 4.4.3, 4.7.2, A-083 |
| 57 | Cleanup's batch size is 10, chosen rather than measured | **Replace with a measurement, not a different guess.** NFR-SCL-01's 50-chunk depth is the anchor it was chosen against; what is unmeasured is whether ten unlinks per sweep ever competes with the Recording Pipeline for I/O, which is the thing §2 asks the batching to prevent. Constructor-injected. The interval needs no such item — it is derived from `RecordingLifecycle.chunkDuration`. | A-088 |
| 58 | ~~`IsarChunkStore` has no unit tests at all~~ **Device verification is the declared standard for this one file** | **DECIDED 2026-08-16 by Mission 4.7.** `Isar.initializeIsarCore(download: true)` was considered and declined: a network dependency in a job that has none, a recurring failure mode for CI and offline builds, and an unreviewed downloaded binary — a permanent operational cost to move one file's number. The consequence is stated rather than softened: `data/` reads **68.3%** against Chapter 9.5 §2's 80%, entirely because this file measures **1.9%**; excluding it the layer is **95.1%**. A regression here will be caught by a device pass, not by CI. A-096 names the three things that would reopen it, the first being A-029's Isar maintenance risk materialising. | A-066, A-096, Mission 4.5, 4.7 |
| 59 | The cleanup probe claims and deletes **pre-existing** queued chunks | **Observed, not theoretical.** Mission 4.5's device run seeded 4 chunks and marked **9** complete: five real chunks from Mission 3's recording sessions were still `queued` on the device, and `claimNext` legitimately claimed them too. It then deleted all nine. Harmless on a test device and it made the evidence stronger — real recorded files, 27.4 MB, not just 4 KB placeholders — but the probe is destructive to anything already queued, and a device holding footage someone wanted should not run it. | Mission 4.5.4 |
| 60 | ~~A real chunk shows `Queued` forever, never `Failed`~~ | **FIXED 2026-08-16 by Mission 4.6.5.** The dispatcher now publishes when it halts, and C-11 shows a system-level banner — *"Uploads aren't running."* — above the list. Wired to the two real fault paths (pipeline construction, broken queue stream) and deliberately **not** to `shutDown()`, so normal teardown is silent. `main.dart`'s start-failure path reports too. The underlying cause is unchanged: Guard 1 still never runs, because `chunkUploadPipelineProvider` throws at construction before any chunk is claimed. What changed is that the Collector can see it. The banner names no cause and no fix, because neither exists while open item 36 is open — A-094. Confirmed on device. | Mission 4.6.3, 4.6.5, A-068, A-094, open item 36 |
| 61 | Cleaned chunks disappear from C-11 entirely | `watchQueue` excludes rows soft-deleted per BR-08, so once Chapter 5.15's sweep runs a completed chunk vanishes from the Collector's Upload status rather than staying visible as `Complete`. Observed on device: after Mission 4.5's sweep the screen was empty. Chapter 2.7 does not say how long a completed chunk stays on C-11, and Chapter 5.15 §3 keeps *metadata* queryable without saying anything about this screen. A product question — how long should 'done' remain visible — not a defect. **Reframed 2026-08-16 by Mission 5.1.4: this is not a standalone product question, it is the first of three symptoms of one cause.** Items 76 and 81 trip on the same `currentQueue` filter, and the recommendation is a single history-capable read path rather than three local fixes — see **"⚠ THE SOFT-DELETE BLIND SPOT"** above. Keeping completed rows on the queue for N hours, the obvious local answer here, puts finished work back on a work list and gives Chapter 5.9's ordering a new class of row to reason about. | Mission 4.6.3, Ch. 5.15 §3, items 76 and 81 |
| 62 | ~~Three of C-11's four pill states have never been seen on a device~~ | **CLOSED 2026-08-16 by Mission 4.7.2**, in both themes, against real Isar rows driven through the real `ChunkUploadSource`. Every clause of Chapter 2.7's C-11 table was visible at once: the accent pill reading *Uploading 42%* with the progress bar **beneath the row rather than inside the pill**, the failed row carrying a critical-coloured border with *Retry Chunk* revealed, the good-hue *Complete* row inert, and amber *Queued*. Two of the states landed on genuinely recorded chunks rather than seeded ones, because `claimNext` honours Chapter 5.9 §2's ordering and took the oldest sessions first. The probe deliberately does not start the dispatcher, so the 4.6 banner is absent — the banner was device-confirmed separately in 4.6.6, and the two have still never been seen in one frame. | Mission 4.6.3, 4.7.2 |
| 63 | `mocktail` is named as project tooling and has never been installed | Volume 3 Chapter 3.1 p.5 lists *"mocktail (mocking)"* and Volume 9 Chapter 9.5 §1 repeats it in the tooling column. This project has hand-written every fake instead, across every mission, and the suite is 789 tests. **Recommendation: amend the tooling list rather than adopt the package.** Hand-written fakes have been more readable than mocks would have been here — several carry the reasoning for their own behaviour in doc comments, which a generated mock cannot — and adopting a mocking library now would be a second way to do a thing this project already does consistently. Recorded so the divergence is declared rather than silently persistent. | V3 Ch. 3.1, Ch. 9.5 §1, Mission 4.7 |
| 64 | **NARROWED — the automated ratio IS measured (82.0% unit / 18.0% widget); Manual and Device Matrix remain unmeasurable here** | Chapter 9.5 §1 fixes Unit ~70%, Integration/Widget ~20%, Manual ~8%, Device ~2%. Nothing measures the split, and the shape is visibly different from the target: the suite is overwhelmingly unit and widget tests in one `flutter test` run, with **no integration tier at all** (item 20) and manual/device testing recorded only in mission reports and this register. Not obviously worth fixing — the proportions are a design heuristic rather than a gate, and Chapter 9.5 §3 gates on *"the full unit + integration suite"* passing rather than on its shape. Recorded so the pyramid is not cited as satisfied. | Ch. 9.5 §1, Mission 4.7 |
| 65 | `SecureStorageService` is written, doc-commented, and has zero production callers | ADR-008 names Flutter Secure Storage as where tokens and secrets live, and the service exists to serve that. **Nothing calls it.** Every reference in `lib/` is a doc comment pointing at it. Session persistence today is entirely `firebase_auth`'s own SDK storage, which is a defensible place for a Firebase session to sit — the finding is not that tokens are stored unsafely, because Mission 4.8 confirmed no token is written to disk by this project's code at all. The finding is that **ADR-008's storage path has never been exercised**, so the first mission that needs it will be the first to discover whether it works, on a path that handles credentials. Not urgent: no capability currently depends on it. Worth resolving before anything does — either by wiring it where FR-AUTH needs persistence, or by recording that Firebase's own storage discharges ADR-008 and the service is redundant. | ADR-008, Mission 4.8 |
| 66 | Nothing mechanically ties a security-relevant commit to a changelog entry | Volume 11 Chapter 11.5 §4 requires an entry *"the day the change merges"*, and §2 puts anything touching auth, storage or data handling under `Security`. The discipline has now failed twice: Missions 3.1–3.10 shipped with no changelog at all (found by Mission 3.11's review, finding S3), and Missions 4.4–4.7 shipped with no entry of any category (found by Mission 4.8, after 3,300 lines of `lib/` including the project's first data-deleting code). Both times it was caught by a review reading `git log` against the file, months of work apart. **Every enforcement this project actually trusts lives in CI; this one lives in a mission checklist, and a checklist has lost to it twice.** A plausible gate — fail a PR whose diff touches `data/`, `core/storage/`, `core/network/interceptors/` or auth without touching `docs/CHANGELOG.md` — is a workflow change, not a documentation fix, so it is recorded here rather than bundled into Mission 4.8.1's docs commit. | V11 Ch. 11.5 §2/§4, Mission 3.11, Mission 4.8 |
| 67 | ~~`docs/CHANGELOG.md` has two `### Added` headings under one `## [Unreleased]`~~ **CLOSED 2026-08-17 by Mission 5.8** | Keep a Changelog, which Chapter 11.5 §1 adopts by name, gives each release section one heading per category. This file has `### Added` in two places under `[Unreleased]` — the Mission 4.x entries under the first, the Mission 3 backfill under the second, with `### Security` sitting between them. **Real but cosmetic**: no entry is missing, misfiled or wrong, and every entry carries its own inline date, so nothing is harder to find than it would be if merged. Deliberately not fixed in Mission 4.8.1, because merging the sections would have moved unrelated lines and buried that commit's actual diff — the entries it existed to add. Fold the two together the next time this file is opened for a substantive reason, so the cleanup rides along with a change being reviewed anyway rather than becoming a churn commit of its own. | V11 Ch. 11.5 §1, Mission 4.8.2 |
| 68 | ADR-040, ADR-041 and ADR-042 carry `Implementation Status` tables that are snapshots of the mission that wrote them | Each table describes the code as it stood at Mission 4.1, 4.2 and 4.3 respectively, and Missions 4.4–4.6 have since applied all three patterns further: `core/connectivity/` is a fourth application of ADR-041's neutral-type inversion, `core/time/` is a new contract module, `core/upload/` gained attempt accounting, and `core/queue/`'s projection was widened to carry retry state. **No decision changed** — these are instances of decided patterns, recorded as amendments A-081–A-096 — so nothing is owed a superseding ADR and none was written. What is stale is the factual status table, not the decision above it. **Deliberately not corrected in place**: `CLAUDE.md` and this project's practice treat an accepted ADR as not rewritten, and a status table edited on every subsequent mission would make the ADR a living document rather than a dated decision. The alternative, if this becomes annoying, is to drop the tables from future ADRs and let the register carry implementation state — which is what it already does. | ADR-040/041/042, Mission 4.9 |
| 69 | FR-PT-05 and Volume 2 name a Task `requirements` field that Volume 4 Ch. 4.4 §3's `tasks` table does not have | **A PRODUCT question for Faisal, not an engineering interpretation to pick.** FR-PT-05 asks for *"instructions, reference examples, and requirements"*, and Volume 2 names the same three at C-06, at A-05 and in the Task Detail section list. Chapter 4.4 §3 has six columns and no `requirements`. Either it is prose already inside `instructions` and Volume 2 is naming a heading, or it is a real column the Data Dictionary omits. **Both readings are defensible and both are product answers**, so `Task` omits the field rather than folding it into `instructions` or inventing a column Mission 7 could not populate. `task_test.dart` asserts the omission, so a later mission that adds the field without the answer breaks a test that points here. Cost to settle: one field added, or one doc comment deleted. | A-098, FR-PT-05, V4 Ch. 4.4 §3 |
| 70 | There is no `GET /v1/tasks/{id}`, so C-06 cannot resolve a bare `task_id` | **Owed to Mission 5.1.2, which is where a route first has to resolve one.** Chapter 4.6 §3 offers exactly three Task routes — `GET /v1/projects/{id}/tasks`, `POST /v1/projects/{id}/tasks`, `PATCH /v1/tasks/{id}` — so a single Task is reachable only through its Project's list. `ProjectTaskRepository` therefore declares no `fetchTask(taskId)`, because a method Mission 7 has no endpoint to satisfy is the breaking rework the interface was traced to avoid. The gap is real but narrow: C-06's route path carries only a `taskId`, so a deep link or a cold start straight into Task Detail has no Project to list from. Closing it needs either a backend route that does not exist or `local_task_cache`, which ADR-039 §3 assigns here and open item 2 defers. **Not a defect in the interface — a consequence of the catalog, recorded so 5.1.2 inherits it.** | A-099, V4 Ch. 4.6 §3, open item 2 |
| 71 | No check catches a source file that is **entirely absent** from `lcov.info`, as distinct from one with low coverage | **A candidate for a later testing/verification mission. Deliberately not built in 5.1.1.** `flutter test --coverage` emits an `SF:` record only for files reachable from the test suite's import graph, so a file no test imports is missing from the report rather than counted as 0% — the denominator is recomputed every run from whatever the tests happened to load. Measured 2026-08-16: **90 of 227** hand-written `lib/` files carry no record. Most are legitimately line-free (bare interfaces, `freezed` declarations whose code lives in excluded `*.freezed.dart`, enums); some, like `invite_code_repository_impl.dart`, are not. A check would have to distinguish the two, which is why it is a mission rather than a one-line CI edit. **The standing risk is the point, not the check**: this is item 41's *"a green check over an empty set is not evidence"* aimed at the coverage report itself, and Mission 4.9 §4's unexercised-mechanism pattern in a third medium. | A-101, open item 41, Ch. 9.5 §2 |
| 98 | **Six spacing/icon values and C-09's indicator red have no token equivalent and need a design decision** | **Blocked on the same missing Chapter 2.8 as item 74, but a distinct and much more specific claim.** Item 74 is *"we cannot verify any screen against the design system"*; this is *"these seven things are known to sit off the scale and someone must choose."*<br><br>**The six values**, each marked `DESIGN-TOKEN-EXEMPT` in place with its reason: `SizedBox(width: 10)` (between `AppSpacing.sm` 8 and `md` 12); `SizedBox(width: 6)` (between `xs` 4 and `sm` 8, **golden-covered**); `Icon(size: 14)` (`AppSizes.iconXs` is 16, **golden-covered**); `Icon(size: 18)` (between `iconXs` 16 and `iconSm` 20); `Icon(size: 40)` (C-09's stop control); and `EdgeInsets.fromLTRB(72, …)` (a computed offset aligning copy under a row's icon column, not a step on any scale).<br><br>**The seventh is a real contradiction rather than a rounding question.** Chapter 2.7 specifies C-09's recording indicator as *"red, per Design System critical hue"*. `AppStatusColors`' critical is `#D03B3B`; the code uses `Colors.red`, which is `#F44336`. **Those are different colours**, so one of the two is wrong and the chapter cannot say which. Changing it is a visible change to a screen device-confirmed on a CPH2707 (Mission 3), and A-125 records why a compliance sweep is the wrong instrument to make it with.<br><br>**Not fixable by rounding to the nearest token**, which is the tempting non-answer: every substitution here changes rendered pixels, two of the values are covered by committed golden baselines, and there is no Chapter 2.8 to validate the result against. Closing it needs either the design system recovered (item 74) or an explicit decision that `lib/app/theme/` is the scale of record and these seven are amendments to it. | A-125, item 74, Ch. 2.7 C-09, Ch. 2.10 §2.2 |
| 95 | **Chapter 2.7 specifies three MVP screens in neither its table list nor its cross-reference, contradicting its own coverage claim** | **A documentation gap in the chapter that Volume 6 and the widget tree are told to implement from.** Ch. 2.7 §1 states the rule: *"Not every one of the 23 screens in the inventory is specified individually here — screens that are pure list/detail restatements of an already-specified pattern … **are covered by cross-reference rather than a duplicate table**."* So the chapter claims total coverage by one route or the other. It does not have it.<br><br>**Specified in full (§1):** C-01, C-07, C-08, C-09, C-11, C-12, A-06, A-08. **Covered by cross-reference (§5):** C-03, C-04, C-05, C-06, A-01, A-02, A-03, A-04, A-05, SH-01, SH-02, SH-03. **In neither: C-02 Permission Blocked, C-10 Local Processing, and A-07 Session/Chunk Status.**<br><br>A-07's only Ch. 2.7-adjacent mention is Ch. 2.9 §4.1 treating it as C-11's twin — *"Network-dependent screens (C-11, A-07) distinguish 'loading current status' from 'no data yet' from 'you're offline' as three distinct visual states"* — which is a behaviour rule, not a component specification. **C-10 was nonetheless built (Mission 3) and C-02 is blocked on item 78**, so the practical cost has been absorbed twice without being recorded; this row records it. Closing it is an edit to Ch. 2.7 §5's bullet list, not engineering work. | A-124, Ch. 2.7 §1/§5, item 74 |
| 96 | **A-07's scope contradicts itself across four sources, and no screen provides the Task selection its only endpoint requires** | **A second blocker sitting behind item 36 — deploying the backend would not make A-07 reachable.** Ch. 2.5's row says *"for a given Project/Task"*; Ch. 2.2 step 7 says *"(per Task)"*; **Ch. 2.4 §3 makes Tab 3 *"status + metadata across managed Projects"*, which is org-wide**; and Chapter 4.6 §4's only endpoint, `GET /v1/tasks/{id}/sessions`, is **per Task**.<br><br>A tab carries no `taskId`, so Tab 3 cannot call a per-Task endpoint without a selection step, and **nothing provides one**: Ch. 2.4 §3's Admin stack ends at *Assign Collectors* and never reaches Session/Chunk Status; Ch. 2.5's A-03 lists its entry points as *create/edit* and *Collector assignment* only; and A-03's Task rows carry no `onTap` by decision (Mission 5.2.2), because at the time both destinations a row could offer were unbuilt — **status was not counted as a third, because nothing specified it as one.**<br><br>Resolving it needs a product decision about what Tab 3 shows: an org-wide rollup (needing an endpoint that does not exist), or a per-Task drill-down (needing an entry point some screen must own). **Same shape as A-100 and item 83's own discovery** — a blocker found only by tracing past the obvious one. | A-124, item 36, item 82, Ch. 2.2/2.4/2.5, Ch. 4.6 §4 |
| 97 | **A-08 Metadata Detail / Export is deferred, not traced — `features/metadata/` does not exist as a module** | **Explicitly deferred by Mission 5.2.5's brief rather than left implicitly untouched, because A-08's blocker is architectural rather than a screen-level gap.** Volume 3 Chapter 3.5 §2 assigns A-08 to a **`metadata`** module — *"Metadata Detail/Export (A-08); `MetadataRepository`, the full FR-META-01–07 field model (freezed classes)"* — with the justification that metadata *"has independent integrity rules (BR-21/BR-22) that outlive both the recording and upload processes"*. **That module has never been created.** `lib/features/` holds six: `auth`, `onboarding`, `projects_tasks`, `recording`, `settings`, `upload`.<br><br>**Building it is a real architectural step, not a trace outcome.** A seventh feature module takes the `Architecture boundaries` job's cross-feature sweep from **30 ordered pairs to 42** (item 77 records the 20 → 30 move for the same reason), and Volume 3 Ch. 3.5 §4 places `metadata` in the dependency graph with two readers — *"read by recording (to write metadata) and by upload/admin_shared (to display and export it)"* — so its creation is a module-boundary decision with existing consumers, not a screen build.<br><br>A-08's other blockers are already recorded and neither is subtle: no deployed backend (item 36) and no client path to verification state (item 83, which **does** apply here). **Owed to whichever mission builds the metadata module.** No trace was run and none is needed to know that. | Item 36, item 83, item 77, V3 Ch. 3.5 §2/§4, Ch. 2.5 A-08 |
| 93 | **A-01 Admin Dashboard is in Chapter 2.5's inventory and no functional requirement governs it** | **Third instance of the surface-with-no-backing family, and the first at SCREEN scale.** FR-ADM-01 through 08 cover create, edit, assign, reassign, view-status, view-metadata, prevent-Collector-writes and visibility. **None is a dashboard.** FR-PT-01 — *"The system shall display a Home Dashboard showing active projects, in-progress sessions, total recorded time, and sync status"* — is the Collector's, and Chapter 1.3 gives it no Admin counterpart. A-01's only descriptions are narrative: Chapter 1.1 §7.3's three-tile sketch, Chapter 1.1 §4.2 step 18's **two-tile** sketch (the PRD disagreeing with itself about this screen's content), Chapter 2.5's row transcribing §7.3, and Chapter 2.2 step 2's navigation duty.<br><br>**The family, now three rows and three scales:** item 88 is `archived_at`, a **column** that is live, rendered and read with no requirement behind it; item 91 is *"Project-level settings"*, a **field group** a screen names with no column behind it; this is a **whole screen** the inventory names with no requirement behind it. Kept separate for the reason item 91 was: different owners, different scales, and different decisions will answer them.<br><br>**Not a blocker.** Mission 5.2.4 built A-01 to Chapter 2.2 step 2's navigation duty and the one sourced tile (A-123); this row records that the screen rests on inventory and narrative rather than on a requirement, so a future scope review knows what it is looking at. | A-123, items 88 and 91, Ch. 2.5 A-01, Ch. 1.1 §7.3/§4.2 |
| 94 | **`tasks` has no status column, so "outstanding" is underivable — and so is any notion of Task progress or completion** | **Recorded independently of A-01, because any future specification touching Task state hits the same wall.** Volume 4 Chapter 4.4 §3's `tasks` table has **six columns — `id`, `project_id`, `title`, `instructions`, `reference_examples`, `created_at` — and no status of any kind.** `sessions` has a status; `chunks` has a status; **Tasks do not.**<br><br>The immediate consequence is that Chapter 1.1 §7.3 and Chapter 2.5's A-01 both ask for *"outstanding Task counts"* and the word **is never defined** — it appears three times in Volumes 1 and 2 (Ch. 1.1 §7.3, Ch. 2.5's A-01 row, and US-05, which is a *Collector* story using it colloquially). **But undefined is the lesser half.** Even once someone defines it, there is no field to compute it from: *"has no sessions yet"* needs sessions per Task (item 36), *"has no assigned Collector"* needs assignments (items 89, 92), and *"not yet complete"* needs a completion concept Tasks do not have at any layer.<br><br>**Why it is not folded into A-01's record:** a Task-progress indicator on A-03, a "done" filter on C-05, an FR-ADM-05 rollup, or any Phase 3 QA workflow would each hit this identically. Closing it means adding a column and deciding its lifecycle — a schema decision in Chapter 4.4, not a screen's problem. | A-123, item 93, Ch. 4.4 §3, Ch. 1.1 §7.3 |
| 111 | **FR-PT-01's *"active projects"* count is unanswerable once the Projects list is paginated** | **Third of FR-PT-01's four aggregates to go absent, and the first to go absent because of something this project built rather than something a chapter omitted.** `DashboardSummary.activeProjectCount` counted `projectsProvider`'s Projects, which was a total until Mission 7.4's F20 made that provider hold *the pages loaded so far* — one, until a Collector opens C-04 and presses "Load more".<br><br>**Closing it needs a total, and there is nowhere to get one.** Chapter 4.6 §1's envelope carries `data` and `meta.nextCursor` and no count; walking every page to render one tile is an unbounded number of requests; and "200+" would be a third display convention on a screen that already has exactly one rule for an unanswerable aggregate — omit the tile, per A-110. The tile is therefore dropped on that precedent, leaving **one of FR-PT-01's four things rendered**.<br><br>**It is a product/spec question, not an engineering one:** either the dashboard stops promising a count, or Chapter 4.6 §1 gains a total on list envelopes. The second is a change to a route catalog Mission 7.3 closed and should not be made for a tile alone — but it would also close items 75 and 76's shape if a general aggregate endpoint were ever specified. | A-200, ADR-051, Ch. 4.6 §1, FR-PT-01 |
| 112 | **Chapter 4.6 §6 defers field types to a generated OpenAPI schema that does not exist, and its absence has now cost three defects in one mission** | **The client and the backend both derive their wire shapes by interpreting the same chapters, separately.** A-206, A-207 and A-211 are each a seam where both halves were internally consistent, thoroughly tested, and correct against their own reading — and disagreed. Unit tests on either side are structurally incapable of catching it: a client test asserts the payload the client builds, a backend test asserts the payload the backend expects, and the two are never the same object.<br><br>**What would close it** is a contract artifact both halves derive from rather than both interpret — Chapter 4.6 §6 names one. Generating types for the mobile client from the same source the Lambdas validate against would make a disagreement a compile error rather than a device-checkpoint discovery. That is a mission, not a patch. | A-206, A-207, A-211, Ch. 4.6 §6 |
| 113 | **`writeMetadata` reports only the first validation issue, so a document with several problems costs one round trip each** | `const [first] = parsed.issues;` — and `v.safeParse` collects all of them. After A-211's refusal there was no way to tell whether GPS was the only blocker or the first of several, which is exactly the question a device checkpoint needs answered before it retries.<br><br>Cheap to fix — render every issue, or at least the count — and deliberately **not** fixed during Mission 7.4's checkpoint, because changing error rendering under a run in flight is its own risk. | A-211, Ch. 2.9 §2 |
| 114 | **`numericParam` and `nullableNumeric` are private to `functions/metadata/` while every other parameter helper lives in `packages/shared/src/row.ts`** | `uuidParam`, `jsonParam`, `textParam`, `longParam` and `optionalTextParam` are all in `row.ts`; the two numeric ones are not, and they are the two that omitted the type hint A-212 fixed. `row.ts` is where the next person looks and where a fourth numeric column would go wrong again.<br><br>Not moved during Mission 7.4's device checkpoint — relocating a shared helper under a run in flight is its own risk. | A-212 |
| 115 | **Four CI corrections are queued from Mission 7.3 and were recorded nowhere until now** | **The batch existed only in conversation**, which is the failure this register exists to prevent — and the second instance of the pattern Mission 7.4 was asked to watch for at its start: *work that is supposed to be carried forward automatically, needing reconstruction from memory instead.* Written down here so the batch is a thing a later mission can pick up rather than remember.<br><br>**1. `pipefail`.** A piped step in `ci.yml` can fail silently because the shell reports only the last command's status.<br>**2. Probe cleanup.** Mission 7.3's throwaway measurement Lambda and its `probe.tf` are still in the tree; they were deliberately temporary and outlived their measurement (F4).<br>**3. `bootstrap-describe-log-groups`.** The narrow grant added to bootstrap `terraform-apply` past its own missing `logs:DescribeLogGroups` permission. It did its job and is now dead surface, along with `boundary.tf`'s withdrawn patch.<br>**4. `types: [opened, synchronize, reopened, edited]`** on the `pull_request` trigger — one line. The **Commit convention** job reads `github.event.pull_request.title` from the **event payload** and never checks out the repo, so re-running a job replays the original payload and re-validates the OLD title. `edited` is absent from the default types, so correcting a title in the UI fires nothing at all, and the only ways out are an empty commit or closing and reopening the PR. Mission 7.4 hit this on PR #1 and pushed empty commit `893b2cd` to work around it.<br><br>**5. A formatting exclusion for `*.g.dart` and `*.freezed.dart`.** `dart format lib/` sweeps generated files; CI's format job already excludes them and its drift job diffs the generator's **raw** output, so formatting them breaks the build by construction. **Three occurrences in one session** — twice caught and reverted, once committed (A-214). Discipline has been tried and has failed three times; the fix is tooling that makes the sweep impossible. Options: a `.gitattributes` marker, a repo-local format wrapper that filters the file list the way `ci.yml` already does, or a pre-commit hook. Whichever is chosen, the CI format job's existing `grep -v` list is the specification.<br><br>**Deliberately not fixed during Mission 7.4**: every one is a CI change, and 7.3's branch was under review while 7.4's checkpoint was mid-flight. They belong together, in one pass, on their own branch. | A-205, A-214, ADR-019, `ci.yml` |
| 116 | **The free-space floor is derived from a nominal bitrate and undercounts a real chunk by ~23 MB** | `RecordingLifecycle.oneChunkBytes = 610 * 1000 * 1000`, derived in its own comment as *(8,000 kbps video + 128 kbps audio) / 8 = 1,016 kB/s, times 600 s = 609.6 MB*. **The chunk Mission 7.3's F4 actually measured on CPH2707 was 633.2 MB** — the encoder overshoots its nominal bitrate, as encoders do.<br><br>So the Pre-Recording Checklist can pass FR-CHK-02's *"sufficient free local storage for at least one full chunk"* with about **23 MB less than one full chunk**. The same constant is `_lowStorageThresholdBytes` for Chapter 5.4 §2's mid-recording backpressure, so both floors are short by the same amount — *"by construction rather than by two copies agreeing"*, which is the comment's stated virtue working against it here.<br><br>**Invisible at short durations.** Every recording before Mission 7.4's scale test was seconds long; only a full 10-minute chunk reaches the size the floor is supposed to cover.<br><br>**Not fixed during the checkpoint**, deliberately: changing a domain constant that two safety floors depend on is not a mid-run edit, and the fix is a decision rather than a number — raise it to the measured figure, derive it with a margin over nominal, or measure per device. One real measurement is not a distribution. | F4, FR-CHK-02, Ch. 5.4 §2 |
| 117 | **C-05 and A-05 never re-fetch their Task list, so a Collector cannot see a Task assigned to them without restarting the app** | `tasksProvider` is a plain `AsyncNotifierProviderFamily` with **no `autoDispose` and no `keepAlive`** — nothing in the whole feature uses either — so a family member lives for the container's lifetime and `build(projectId)` runs **once per Project id, ever**. Re-navigating re-reads cached state and issues no request. That much is deliberate and documented: *"Riverpod keeps one instance per Project, so navigating back to a Project already visited does not refetch it."*<br><br>**What is not deliberate is that nothing else refreshes it either:**<br><br>| Path | Refreshes? |<br>|---|---|<br>| In-app Task creation | **Yes** — `AdminProjectTaskNotifier.createTask` calls `ref.invalidate(tasksProvider(projectId))` |<br>| Projects list, C-04 and A-03 | **Yes** — `RefreshIndicator` calls `refresh()` |<br>| **Task list, C-05 and A-05** | **No** — no `RefreshIndicator`, no pull-to-refresh, no external invalidation |<br><br>So a change made **server-side** — an Admin assigning a Collector to a new Task, which is FR-ADM-03's whole purpose — is invisible to that Collector until the app is restarted. `TasksNotifier.refresh()` exists, is implemented and is unit-tested; **it has no caller.**<br><br>**Found during Mission 7.5's F2 device session**, where 201 seeded Tasks did not appear. That turned out to be a missing `task_assignments` seed rather than the cache — but tracing it surfaced this, which is real independently.<br><br>**The fix is small**: a `RefreshIndicator` on both Task lists, matching what C-04 already does, calling the `refresh()` that is already there. Not done during a verification session, per the standing rule that Testing and Verification states the position rather than closing it. | FR-ADM-03, C-05, A-05, `tasks_notifier.dart` |
| 92 | **No endpoint anywhere in Chapter 4.6 returns an organisation's Collectors — a catalog-level omission that four separate specifications assume away** | **Recorded as its own row rather than inside A-06's, because it is not one screen's problem.** Chapter 4.6's complete catalog is **15 routes**, and its only user-facing one is `GET /v1/users/me` — *"Current user's profile + role"*, the caller and nobody else. **Four specifications assume a Collector directory exists and none of them can be satisfied:** FR-ADM-03 (*"assign one or more Collectors"* — an Admin must identify them); UC-07's exception flow (*"If the Admin attempts to assign a Collector who does not have an account or is deactivated, the system blocks the assignment and explains why"* — presupposes the Admin picked from something); Chapter 2.2's Admin flow step 6 (*"Collector(s) **selected** and confirmed"* — selected from what?); and Chapter 2.7's A-06, which lists Collector rows.<br><br>**The gap is total, not merely endpoint-level.** Verified at every layer this project has: Firestore holds one collection, `org_invite_codes`, with `allow read: if false` (*"Nobody reads, ever"*); `functions/src/index.ts` states in its own comment that *"no `orgs` collection exists"* and names the users table as *"Volume 4 Ch. 4.4's"*, behind the unbuilt backend; `features/auth/` yields the caller's own session and nothing else; and **no fake in `lib/` or `test/` holds a user list**. So the only user id this application can obtain is the signed-in Admin's own `uid`, which Chapter 4.4 §4's `role='collector'` annotation makes the wrong one.<br><br>**Closing it needs a route added to Chapter 4.6** — something like `GET /v1/users?role=collector`, org-scoped per BR-20 — and that is a backend/spec decision, not an engineering one. **No stand-in was invented**: seeding a roster into a fake would be inventing a domain concept this project has never modelled rather than standing in for one with a known shape, which is the line between a fake and a fabrication (A-122). | A-122, item 89, FR-ADM-03, UC-07, Ch. 2.2 step 6, Ch. 4.6 §2 |
| 90 | **Chapter 2.9 contradicts itself about editing a Task: §2 principle 4 requires a confirmation, §4.4 forbids one** | **A PRODUCT/SPEC DECISION FOR FAISAL — a genuine authorial contradiction inside one chapter, not something derivable.** Both sentences name the same action explicitly and state opposite rules.<br><br>**§2, principle 4:** *"Admin actions that affect a Collector are never destructive-by-default. Removing a Collector from a Task, or **editing Task instructions after Collectors are already assigned, always confirms the action and states its effect in plain language before it takes effect**."*<br><br>**§4.4:** *"Reversible actions (reassigning a Collector, **editing Task instructions**) **do not require a confirmation dialog** — they save immediately and can be changed again just as easily."*<br><br>**This is unlike G3.** There the sources disagreed in emphasis and one class of them specified a mechanism, so the resolution was derivable by asking which sources were normative (A-116). Here both sentences are behavioural rules in the same chapter, at the same level of authority, naming the same action — and §2 P4 even supplies the reasoning (*"affect a Collector"*) that §4.4's *"reversible"* framing rejects. **There is no reading that satisfies both.** Mission 5.2.2 therefore held A-05's **edit** half back entirely rather than pick one: `updateTask` exists and works, and shipping either behaviour would encode an answer nobody has given into UI a Collector depends on. Settling it needs one sentence struck or amended, not an implementation judgement. | A-121, Ch. 2.9 §2 P4, Ch. 2.9 §4.4, FR-ADM-02 |
| 91 | **Chapter 2.5's A-04 names "Project-level settings"; the phrase appears exactly once in all of Volume 2 — in that row** | **Third instance of one shape, and kept as a separate row so the family stays visible.** Ch. 2.5's A-04: *"Name, description, and **Project-level settings**."* Nothing defines them: `projects` has seven columns and none is a setting (Ch. 4.4 §2), `POST /v1/projects` carries no such field, no FR mentions one, and no other chapter uses the phrase. So A-04 renders name and description with **no settings section and no empty placeholder implying one is coming** — the treatment C-06 gave `requirements` (A-110), and a test asserts the absence.<br><br>**The family, three rows and three owners:** item 69 is FR-PT-05/A-05's `requirements` — a **Task** field named by a requirement with no column. This is A-04's **Project-level settings** — a **Project** field group named by a screen with no column. Both are *"a surface names something the schema does not have"*, and they are separate items because they have different owners, different chapters and will be answered by different decisions. Folding them would make one product answer look like it closed both. | A-110, item 69, Ch. 2.5 A-04, Ch. 4.4 §2 |
| 85 | **Assignment is Task-level, so there is no way to say "this Collector gets every Task in this Project, including future ones"** | **A product question, not an engineering one — and the residue G3 leaves after A-116 resolves it.** Task-level assignment gives *"assigned to this Project"* for any Project with at least one assigned Task, which is what Ch. 4.6 §3's derivation already states. What it cannot express is a **standing grant**: a Project-level assignment would be a *rule* that future Tasks inherit, while Task-level assignments are *facts* about Tasks that exist. **An Admin who adds a Task next month must assign Collectors again, and nothing prompts them** — the new Task appears to nobody until someone remembers. UC-07's own flow never hits this because it creates the Task first and assigns second, so the happy path hides it. Closing it needs either a `project_assignments` table and a route (a backend change), or an explicit product decision that per-Task assignment is the intended model and the Admin UI should make the omission visible. **Not resolved by inventing a client-side fan-out** — assigning to every current Task would silently implement the facts reading of a question nobody has answered. | A-116, G3, FR-ADM-03, BR-15, UC-07 |
| 86 | **FR-ADM-02 and MVP §2.2 both say an Admin can *remove* a Task; there is no `DELETE /v1/tasks/{id}`** | **A backend/spec gap, stated plainly rather than softened.** FR-ADM-02: *"create, edit, and **remove** Tasks within a Project"*, Must Have. MVP §2.2 repeats it verbatim in the in-scope list. Chapter 4.6 §3's Task routes are `GET /v1/projects/{id}/tasks`, `POST /v1/projects/{id}/tasks` and `PATCH /v1/tasks/{id}` — **no delete of any kind.** `ProjectTaskAdminRepository` therefore declares no `removeTask`, on 5.1.1's `fetchTask(taskId)` precedent: a port method Mission 7 has no endpoint to satisfy is breaking rework, and declaring one hides the gap behind an interface that looks complete. Closing it needs a route added to Chapter 4.6 — and a decision about whether removal is a hard delete or a soft one, since `tasks` has no `deleted_at` column while `projects` has `archived_at` and `task_assignments` has `removed_at`. **The absence is not test-guardable**: Dart offers no runtime assertion over a class's method set, so if a later mission adds `removeTask` nothing breaks. This row is the guard. | A-118, FR-ADM-02, MVP §2.2, Ch. 4.6 §3 |
| 87 | **MVP §2.2 and Chapter 2.5's A-04 both assume an Admin can edit a Project; there is no `PATCH /v1/projects/{id}` and no FR either** | **Two gaps stacked, and the second is the surprising one.** MVP §2.2: *"Create, edit, and remove Projects."* Chapter 2.5's screen **A-04 is literally named "Create / Edit Project"** and described as *"Name, description, and Project-level settings."* Chapter 4.6 §3 has `POST /v1/projects` and nothing else for a Project. **And Chapter 1.3 has no requirement for it at all** — FR-ADM-01 is *"create a new Project"*, full stop; no FR-ADM covers editing one. So a named screen and an MVP scope line rest on a capability that has neither a route nor a requirement behind it. Closing it needs both: an FR, and a route. Until then `ProjectTaskAdminRepository` has no `updateProject`, and A-04 can implement only its "Create" half. | A-118, MVP §2.2, Ch. 2.5 A-04, Ch. 4.6 §3 |
| 88 | **`projects.archived_at` is live, rendered and read — and the word *archive* appears nowhere in Volume 1 or Volume 2** | **A column with no requirement: the inverse of items 69 and G3, and worth naming as that shape.** Item 69 is a requirement (`requirements`) with no column; G3 is a requirement (assign-to-Project) with no table; **this is a column with no requirement.** Volume 4 Chapter 4.4 §2 declares `archived_at timestamptz Yes — Soft-delete`, Chapter 4.2 §1 explains the soft-delete pattern *"after a Project is archived"*, `Project.archivedAt` carries it (A-097), **C-04 renders an "Archived" label from it (A-109)**, and **C-03's active count is defined by it (A-104)**. Meanwhile a full-text search of Volumes 1 and 2 finds the word *archive* only inside the product name *Human Archive* — **no FR, no BR, no user story, no use case, no MVP scope line, no screen.** So the field is read in three places and **nothing specifies who sets it, when, or what it means for a Collector mid-session against an archived Project.** MVP §2.2's *"remove Projects"* is the nearest thing and it says *remove*, not *archive*, with no route either way (item 87). Needs a product decision before any Admin surface can write it. | A-104, A-109, item 87, Ch. 4.4 §2, Ch. 4.2 §1 |
| 89 | **Chapter 2.7's A-06 requires checkboxes that "reflect current assignment state on load"; no endpoint returns assignments** | **Mission 5.2.2's first problem, and it blocks a screen rather than a nicety.** Chapter 4.6 §3 offers `POST /v1/tasks/{id}/assignments` and `DELETE /v1/tasks/{id}/assignments/{userId}` — **write only.** Nothing returns who is currently assigned to a Task, and `GET /v1/projects/{id}/tasks` returns Tasks, not assignments. So A-06 can be rendered but **cannot be initialised**: its own spec says *"Checkbox reflects current assignment state on load; unchecked-and-saved triggers FR-ADM-04 removal, not a silent no-op"*, and both halves of that sentence need a read. `ProjectTaskAdminRepository` declares no assignment read for the usual reason, and `InMemoryProjectTaskStore.assignments` is written and never read back through any repository — tests inspect the store directly. **This also has a second missing piece:** A-06 lists *Collectors* to check, and no endpoint returns the org's Collectors either (Chapter 4.6 §2 has `GET /v1/users/me` and nothing else). Two reads missing, one screen. **Traced in full 2026-08-16 by Mission 5.2.3 (A-122), which changes what this row means in two ways.** First, **the second missing read is not this screen's problem** — a Collector directory is assumed by FR-ADM-03, UC-07's exception flow and Chapter 2.2 step 6 as well, and it is missing at every layer of the project rather than only from the catalog. **Split out as open item 92.** Second, **Chapter 2.7's A-06 table forbids nothing** — unlike C-12's, which refuses its degraded form outright. A-06 is blocked by data alone, its writes already work, and closing it needs endpoints rather than a product decision. It is the cheaper of the two blocked screens and should not be filed alongside C-12 as though it were the same shape. | A-117, A-122, item 92, Ch. 2.7 A-06, Ch. 4.6 §2/§3, FR-ADM-03/04 |
| 83 | **This client never observes `verified_at`, so FR-META-12's verification is unreadable — and closing item 36 would not change that** | **A second blocker sitting behind item 36, found 2026-08-16 by Mission 5.1.5 tracing C-12.** FR-META-12 requires a chunk's uploaded checksum to be verified against the local one *"before marking that chunk Complete"*, and Chapter 2.7 gates C-12's confirmation icon on exactly that. **Nothing in this application can read it.** Two files already state the position — `storage_cleanup_sweep.dart`: *"This device never observes `verified_at`. It writes `complete` itself"*; `chunk_upload_status.dart`: *"the device never reads `verified_at` back"* — and both were correct for their own purpose, which is why neither is a defect. The finding is what they imply together: **a deployed backend would set `verified_at` server-side and this client would still have no path to it**, so item 36 closing unblocks the upload and not the confirmation. Closing this needs a read path for verification state — `GET /v1/chunks/{id}/metadata` exists in Chapter 4.6 §3 but is Admin-scoped, so it is not simply a call the Collector's client can make. **Same shape as A-100**: a port whose blocker turned out to have a blocker behind it. **SCOPE NARROWED 2026-08-16 by Mission 5.2.5 (A-124). This applies to A-08 and C-12, NOT to A-07** — a correction to this row's own earlier claim that A-07 would be the first surface to hit it. A-07 renders status the backend computed and never inspects the verification column, because Chapter 4.2 §3 gates it server-side: *"`chunks.status` can only transition to `'complete'` via a stored procedure that first checks a matching, non-null `chunk_metadata` row exists."* **A server-supplied `complete` already encodes verification.** What still hits this wall is a surface that must display verification *as its own fact*: **A-08**, whose Chapter 2.7 table requires a checksum *"paired with a verified/mismatch status label"*, and **C-12**, whose confirmation icon is gated on FR-META-12 directly. | A-115, A-124, item 36, item 97, FR-META-12, BR-21 |
| 84 | **C-12 is in Chapter 2.5's inventory and Chapter 2.7's spec, and in no part of Chapter 2.4's navigation model** | **Second instance of open item 82's class: a screen the inventory names and the navigation model does not place.** Chapter 2.4 §2's Collector modals are the Checklist, Checklist Failed and Permission Blocked; its stacks are Projects→…→Task Detail and Sessions→Session Detail→Chunk Detail; §5's summary table names neither C-12 nor a route to it. **The gap is not cosmetic, because of when C-12's condition becomes true:** C-10 fires seconds after Stop, when local chunking and metadata generation finish, while C-12 fires when the *last chunk's checksum verifies server-side* — minutes to hours later over a field connection. **A Collector is long gone from C-10 by then**, on another screen or with the app closed, so there is no moment at which the application can simply show C-12 as written. It would have to be reached from C-11, or driven by a push notification (FR-SEC-03/04, Phase 2, unbuilt), or surfaced on next launch — and Chapter 2.4 specifies none of the three. **Inserting it after C-10 is the obvious wrong answer**: it would fire at the moment local processing ends, which is precisely when the claim BR-12 forbids would be false. Needs a product decision about where C-12 lives before it needs any code. | A-115, item 82, Ch. 2.4, Ch. 2.5 |
| 81 | **C-11 forgets a session once all its chunks are swept, so FR-SES-01's end-to-end tracking is not served** | **Third symptom of one cause — see "⚠ THE SOFT-DELETE BLIND SPOT" above, and do not fix this one locally.** C-11's sessions are derived by grouping `QueuedChunk` rows, and `currentQueue` excludes `localDeletedAt != null`. So a session whose chunks have all uploaded **and** been cleaned disappears from the screen entirely — not shown as complete, shown as nothing. FR-SES-01 requires the system to *"track the state of every session (recording, chunking, uploading, complete) end to end"*, and a view that forgets finished sessions does not do that: **C-11 is an upload-queue view wearing a session-history label.** The obvious local patch — group before filtering — renders a heading over no rows, which is worse. Closes together with items 61 and 76 once a history-capable read path exists. Note that C-11 remains **correct for its own stated purpose**: Chapter 2.5 calls it *"Upload / Sync Status"*, and finished, cleaned work has no upload status. The gap is that nothing else answers the session-history question. **Scope clarified 2026-08-16 by Mission 5.2.4 (A-123): this item is COLLECTOR-SIDE ONLY and does not apply to any Admin screen.** `core/queue/` is a live view over `local_chunks.status` — the chunks on the device running the app — so an Admin's device, which holds no Collector chunks, cannot read it at all. Prior analysis paired items 81 and 83 as A-07's blockers; **81 drops out**, and A-07's are the backend (item 36) plus 83 for anything claiming verification. | A-112, A-123, items 61 and 76, FR-SES-01 |
| 82 | Chapter 2.4 §2 names *Session Detail* and *Chunk Detail*; Chapter 2.5's authoritative inventory has neither | **A product call between two chapters, not something a screen should settle by being built.** Ch. 2.4 §2's stack sentence — *"Sessions → Session Detail → Chunk Detail"* — is **the only occurrence of either name in all of Volume 2**. Chapter 2.5 calls itself *"The master, authoritative list of screens"* and its fifteen Collector entries include no such screens; Chapter 2.7 gives neither a component table; no FR names either. **C-11's own inventory line already covers both levels** — *"Per-session, per-chunk status"* — and Mission 4.6 built exactly that, flattened into one screen with sessions as group headings and chunks as rows. The consequence in code is a live but unreachable route: `/collector/sessions/:sessionId` is a Mission 1.3 placeholder and **nothing in the application navigates to it**, because C-11 has nowhere to drill down *to*. **Deliberately left in place rather than deleted** at Mission 5.1.4: removing a route Chapter 2.4 names is as much a product decision as building the screen it names, and leaving it costs one unreachable placeholder while keeping both options open. Resolving it means either amending Ch. 2.4's stack to match the inventory, or adding two screens to Ch. 2.5 — and the second needs someone to say what they would show that C-11 does not. **SECOND INSTANCE FOUND 2026-08-16 by Mission 5.2.5, in the Admin half of the same chapter.** Ch. 2.4 §3's Admin stack reads *"Projects → Project Detail → **Task List → Task Detail** → Assign Collectors"*, and Chapter 2.5's Admin inventory — A-01 through A-08 — contains **no Admin Task List and no Admin Task Detail**. So the defect is not a one-off slip in §2: **both halves of Chapter 2.4's navigation model name screens the authoritative inventory does not have**, which makes this a chapter-level inconsistency rather than two isolated omissions. A fix should reconcile Ch. 2.4 against Ch. 2.5 as a whole rather than patching either instance. | Ch. 2.4 §2/§3, Ch. 2.5, A-124, Missions 5.1.4 and 5.2.5 |
| 79 | **A real Task picker exists and no recording is attributed to a Task** — the picker's `taskId` is never wired through to `TaskContext` | **Separate work in `features/recording/`. Explicitly NOT closed by Mission 5.1.3's proximity to it.** C-06's Start Recording passes a real `taskId` into `/checklist/:taskId`, and there the trail ends: `PreRecordingChecklistScreen` declares the parameter and reads it nowhere, and neither does `ChecklistNotifier`, `RecordingNotifier` nor `RecordingGuard`. `TaskContext` remains bound to `UnsourcedTaskContext`, which returns `MetadataIdentity.unsourced` — the empty string — for both `project_id` and `task_id`. **So a recording started through the real picker is attributed to exactly nothing, precisely as one started through the removed debug button was**, and A-068's Guard 1 still refuses 100% of recorded chunks. The work is: carry the `taskId` (and the `projectId` C-06 already holds) from the route into a `TaskContext` implementation that reads them, and bind it at the composition root in place of `UnsourcedTaskContext`. That closes **open item 1** and removes two of Guard 1's five missing fields; items 5 and 11 supply two more. **Nothing about building the picker made this easier or harder** — it was always a `features/recording/` wiring job — but the picker's existence makes it look done, which is why it is written down at length. | A-111, open items 1, 37, A-062 §1, A-068 |
| 80 | C-06 renders reference-example URLs as text that opens nothing, so FR-PT-05 is met in letter and missed in substance | **Needs `url_launcher`, which is an ADR-030 dependency decision and the first outbound-navigation path in this app — new capability, not layout.** Volume 4 Ch. 4.4 §3 types the column *"Array of reference media URLs"*; C-06 renders them as `SelectableText`. **A Collector standing in a field with a URL they cannot open has, in practice, no reference example**, so this should not be read as a finished section. The alternative — inline image/video previews — needs Chapter 2.8's component library, which is not in this repository (open item 74), so it is doubly blocked. Deliberately not built in 5.1.3: adding a package and an outbound navigation surface inside a layout sub-mission would be exactly the scope drift these missions have avoided elsewhere. A test asserts no tap target wraps a URL, so wiring one in breaks a test that names this item. | A-110, FR-PT-05, ADR-030, open item 74 |
| 74 | **Chapters 2.6 and 2.8 are not in this repository, so every screen built to date is token-correct and component-unverified** | **Owed to Mission 5.3's Design System audit, which currently has no reference document to audit against.** Volume 2's front matter says both are *"delivered separately"* as interactive HTML; neither file is under `docs/`. Chapter 2.7 specifies every screen in terms of Chapter 2.8 components (`card container` §5, `btn-primary` §5, `field.error` §7), and Chapter 2.10 §2.3 and §6 defer the light/dark CSS custom properties and the type scale to it. What is reachable second-hand: the four status colours (Ch. 2.10 §2.2, adopted by A-089), and the spacing/radius/size/duration/opacity scales transcribed into `lib/app/theme/` at Missions 0.7 and 4.6. What is not: what any component actually looks like. **C-01 and C-03 are therefore built from tokens and `Theme.of(context)` and are unreconciled against the definitions they were specified in terms of.** Two things close this: the HTML arriving, or an explicit decision that `lib/app/theme/` **is** the design system of record and Chapter 2.8 is superseded — the second is an ADR, not an amendment. Recorded now because a screen built from the right tokens looks finished, which is Mission 4.9 §4's shape in a visual medium. | A-102, Ch. 2.7, Ch. 2.8 |
| 75 | FR-PT-01's *"in-progress sessions"* has no `core/` contract, so C-03 shows no tile for it | **Needs a new `core/` contract over `LocalSession.status` — ADR-040's pattern, out of scope for a UI sub-mission.** FR-SES-02's status is owned by `features/recording/`; `QueuedChunk` carries `sessionId` and `sessionStartedAt` but no session status. Counting distinct `sessionId`s in the queue was **considered and rejected as wrong rather than approximate**: it counts sessions with surviving chunk rows, and Mission 4.9's handoff warns in terms against reading the session column as an upload signal. **No tile is rendered**, and a test asserts its absence, because `0` would be a claim about the Collector's work. **This is A-100's shape a second time** — a `features/projects_tasks/` surface needing data `features/recording/` owns — which is the standing cost of ADR-022 R3 rather than a one-off. | A-103, A-100, Ch. 2.5 C-03 |
| 76 | FR-PT-01's *"total recorded time"* has **no correct source anywhere in the project** | **Do not approximate it. A queue-sum is actively wrong, not merely incomplete.** A per-chunk duration exists — `MetadataTimingDocument.durationSeconds`, derived from `startedAt`/`endedAt` and deliberately unstored — but only one chunk at a time through `ChunkMetadataSource.metadataDocument`, with no aggregate. Summing over the queue fails because `IsarChunkStore.currentQueue` skips every row with `localDeletedAt != null` and Chapter 5.15's cleanup soft-deletes rows as chunks complete (open item 61): **the total would decrease as the Collector records more**, peaking before the first sweep. That is worse than an absent number — an incomplete figure invites trust, one that moves the wrong way trains distrust of the whole screen. Closing it needs an aggregate over *all* chunk rows including soft-deleted ones, which is a new method on a `features/recording/`-owned store exposed through a new `core/` contract. **No tile is rendered**, and a test asserts its absence. **Second of three symptoms of one cause** — items 61 and 81 trip on the same `currentQueue` filter. This is the one that cannot be fixed locally at all: caching a running total before cleanup would be a second source of truth for a number derivable from the rows, the failure ADR-018 exists to prevent. See **"⚠ THE SOFT-DELETE BLIND SPOT"** above; a history-capable read path is the only thing that closes this item. | A-103, items 61 and 81, Ch. 5.15 |
| 77 | The cross-feature confinement sweep grew from 20 ordered pairs to 30 | **Informational, and the sweep needs no edit — but the number in every report does.** `features/onboarding/` was created at Mission 5.1.2, taking `lib/features/` from five modules to six; the `Architecture boundaries` job derives its pairs from `ls -1 lib/features`, so it picked the ten new pairs up with no change. Recorded because "20 feature pairs" is quoted as a verification figure in the Mission 4.9 report and in several amendments, and a stale count in a later report would read as a narrowed sweep — which is exactly the failure open item 26 exists to prevent. The next module makes it 42. | Mission 5.1.2, open item 26, ADR-022 R3 |
| 78 | C-01 exists but requests nothing — **FR-ONB-01 is not satisfied**. ~~and onboarding has no first-launch trigger~~ **(trigger CLOSED, Mission 5.4)** | **Needs a permission plugin, which is an ADR-030 dependency decision, and it should be taken together with C-02.** FR-ONB-01 requires the system to *"request Camera, Microphone, Location (When In Use), Notifications, and Files access during first launch"*. Mission 5.1.2 built the carousel that explains all five and requests none. **This project has no permission plugin at all** — the only permission machinery is `CameraPermissionProbeImpl`, which infers camera and microphone grants by opening a camera with audio and disposing it, a side-effect probe rather than a permission API; nothing can read or request Location, Notifications or Files. C-02 (FR-ONB-02's blocking explainer and settings deep link) needs the same package, so deciding them apart would take the same decision twice. **Two things were missing, and ONE is now fixed.** The **trigger** closed at Mission 5.4: `OnboardingSeenStore` persists the flag and `OnboardingGuard` sends an unprimed Collector to `/onboarding` on first launch (A-126, A-127, item 99). That work also revealed the sharper form of the problem — the route had **no inbound edge from anywhere in `lib/`**, so C-01 was not merely un-triggered but unreachable by any path.<br><br>**The request is still missing, and it is the half that decides this item.** Making a screen reachable ships it; it does not make it function. A Collector now sees the carousel and is asked for nothing, so FR-ONB-01 remains unsatisfied and this item stays OPEN on the plugin decision alone. A test walks the whole carousel with a mock handler on the camera channel and asserts zero platform calls, so wiring a real request in breaks a test that names this item. | A-105, A-126, A-127, item 99, FR-ONB-01/02, ADR-030 |
| 73 | **`features/upload/application/chunk_upload_pipeline.dart` imports `features/upload/data/`, which ADR-022 forbids outright** | **Found 2026-08-16 by Mission 5.1.1's full layer sweep. Reported, not fixed — `features/upload/` is on this sub-mission's explicit do-not-touch list, and rewiring a verified upload path is not a documentation-mission change.** ADR-022 names this one of *"the two most consequential prohibitions in the matrix"*: *"`presentation/` and `application/` may not import `data/`. The repository interface is in `domain/`; the implementation is in `data/`. A layer that imports `data/` has bound itself to one implementation, which breaks test substitution."* Line 19 imports `ChunkUploadApiImpl` and line 440's `chunkUploadPipelineProvider` constructs it directly. **Every other repository in this project already does the opposite** — `authRepositoryProvider`, `chunkUploadSourceProvider`, `chunkQueueSourceProvider` and now `projectTaskRepositoryProvider` all throw and are overridden at the composition root, precisely so `application/` never names a `data/` class. This one provider is the exception and carries no `ignore`, no doc comment and no amendment explaining why. **Why no check caught it:** the `Architecture boundaries` CI job enforces package confinement (14 rules), cross-feature imports (20 pairs) and `core/` contract neutrality — **it does not enforce ADR-022's intra-feature layer matrix at all**, so this prohibition has been binding in writing and unenforced in fact since Mission 4.2, exactly as R3 was before ADR-040 made it checkable. The fix is one throwing provider plus one `uploadOverrides()` entry; the check is one `grep` per direction. Both belong to whichever mission owns `features/upload/` next. | ADR-022 (import matrix), open item 26, Mission 5.1.1 |
| 72 | `features/auth/domain/` has no `analysis_options.yaml`, so `public_member_api_docs` has never been enforced there | **A one-file fix, deliberately not made in 5.1.1 — `features/auth/` is outside this sub-mission's scope and a lint widening is a change to a verified layer.** ADR-022 §6.1 step 7 requires the file for **every** feature's `domain/` and `data/`. Present for `auth/data`, `recording/domain`, `recording/data`, `upload/domain`, `upload/data`, and now `projects_tasks/domain` and `projects_tasks/data` — missing only for `auth/domain`, which holds five entities and two repository interfaces. Whichever mission takes it should expect new lint findings on files that have never been checked, which is why it belongs in a commit of its own rather than folded into unrelated work. | ADR-022 §6.1 step 7, A-025, Mission 5.1.1 |
| 99 | **`/onboarding` had no inbound navigation edge anywhere in `lib/` — C-01 was declared, buildable and reachable by nobody** | **CLOSED by Mission 5.4, and recorded because the finding is reusable, not because it is open.** Mission 5.1.2 built C-01 and logged it as *"not wired to a first-launch trigger"*, which is true and files the gap as a missing feature. **Stated as a navigation fact it is sharper and worse: a route with no inbound edge is unreachable, and an unreachable screen is not shipped.** No tab, no button, no redirect and no deep link reached it; the only references to the route string in `lib/` were its own declaration and comments.<br><br>It was found by a mechanical sweep — for each declared route, count the navigation sites that target it — run because Mission 5.4's subject was the navigation graph rather than any one screen. Tabs correctly show zero `context.go` calls (`TabShell` uses `navigationShell.goBranch`), which is the one false positive the sweep produces and the reason it needs a human reading rather than a CI rule as written.<br><br>**The fix is `OnboardingSeenStore` + `OnboardingGuard`** (A-126, A-127). **It does not satisfy FR-ONB-01**, which is item 78 and stays open: the carousel is now reachable, and it still requests no permission. *Shipped* and *functional* are different claims and this closes only the first. | A-126, A-127, item 78, item 100 |
| 100 | **Chapter 2.4's navigation model places neither C-01 nor C-10, and two shipping screens are in no Volume 2 inventory at all** | **The structural inverse of item 82, kept as its own row rather than folded in, because the direction determines the fix.** Item 82 is *Chapter 2.4 names a screen Chapter 2.5's inventory lacks* — Session Detail, Chunk Detail, Admin Task Detail. This is the reverse: **screens that exist and ship, which Chapter 2.4 never places.**<br><br>**In Chapter 2.5, absent from Chapter 2.4:** C-01 Onboarding and C-10 Local Processing. Verified against Chapter 2.4's full text — neither appears in any tab list, stack or modal list in §2 or §3.<br><br>**In neither Chapter 2.4 nor Chapter 2.5:** `/signup` and `/admin/invite-codes`. These are not omissions but consequences — self-signup (A-051, A-056) and ADR-036's invite codes were both decided after Volume 2 was written, and Volume 2 has not been revised since.<br><br>**C-01's unreachability (item 99) is plausibly a downstream effect of this.** Chapter 2.4 is where a screen's entry point is specified; a screen the chapter never places has no specified entry point, so building it from Chapter 2.7 alone produces exactly what happened — a correct screen nothing reaches. **That causal link is why the two items cross-reference and why neither belongs inside item 82**, whose phantom screens have the opposite problem and a different fix (build them, or delete the reference). | Item 82, item 99, A-051, A-056, ADR-036, Ch. 2.4 §2/§3, Ch. 2.5 |
| 101 | **ADR-022 R2 is breached seven times in `lib/app/`, and the CI check ADR-022 assigned to "the first feature mission" was never added** | **One item, not two, because the missing check is the reason the breaches exist — ADR-022 predicted this outcome in writing and nothing acted on the prediction.** R2: *"`app/router.dart` is the only file in `app/` permitted to import from `features/`, and only from `features/<name>/presentation/` … it may not import a feature's `domain/`, `data/` or `application/`."*<br><br>**The seven**, from a full sweep of `lib/app/` (30 feature imports, 23 legal): `auth_guard.dart` → `auth/application/auth_state.dart`, `auth/domain/entities/role.dart`, `auth/domain/entities/user.dart`; `recording_guard.dart` → `recording/domain/entities/recording_state.dart`; `router.dart` → `auth/application/auth_notifier.dart`, `auth/application/auth_state.dart`, `recording/application/recording_notifier.dart`.<br><br>**ADR-022 called it.** Its Consequences record R3, R4, the `data/` prohibitions and the `app/`↛`features/` rule as *"binding in writing and unenforced in fact"*, and assign the fix explicitly: *"extending the `Architecture boundaries` job belongs to the mission that creates the first feature."* That mission arrived; the check did not. **Nothing in this register recorded the breaches before Mission 5.4**, so they were undetected drift rather than an accepted deviation — the state ADR-022 wrote that sentence to prevent.<br><br>**Explicitly NOT opened as a sub-mission by 5.4.** The fix touches `auth_guard.dart` and `recording_guard.dart`, which belong to two closed features, and choosing between *move the types to `core/`*, *pass primitives*, or *amend R2* is a trace of its own. Mission 5.4 did the one thing it could do without that trace: **it added no eighth breach.** `OnboardingGuard` takes a plain `bool` rather than an `AuthState`, and `core/onboarding/` exists so `router.dart` reads a `core/` provider instead of a feature's `application/` (A-126). | A-126, ADR-022 R2 + Consequences, `lib/app/` |

| 102 | **Three status hues fail WCAG 1.4.11 against the surface behind them — a contrast class A-090 never measured** | **Not fixable without Chapter 2.8, and mitigated enough that fixing it blind would be worse than recording it.** Non-text contrast (3:1) decides whether a pill's *boundary* is visible, which is a different question from whether its text is readable — and the text pairs all pass (A-130: 8/8 fills, 24/24 scheme pairs).<br><br>**light `warning` `#FAB219` vs `#FBFBFD` — 1.78:1. dark `accent` `#215FAB` vs `#101317` — 2.92:1. dark `critical` `#A62F2F` vs `#101317` — 2.72:1.**<br><br>**No information is lost**, because Chapter 2.10 §2.1 requires every pill to carry an icon and a text label alongside its colour and every pill does. What is lost is edge definition.<br><br>**The dark accent misses by 0.08**, and that is worth separating from the other two: it is a rounding-scale question rather than a design failure, and **it is the one most likely to resolve on its own if Chapter 2.8 is ever recovered** — the dark surface value it is measured against is a Mission 0.7/4.6 transcription, and a small difference in the real published value flips it. The other two miss by margins no transcription error explains.<br><br>Changing a hue is what §2.2 forbids *"without re-validation"*, and A-090 established there is nothing to re-validate against. Closing it needs item 74.<br><br>**The computation was validated against rendered pixels on 2026-08-17**, which matters because a token table can be right about the source and wrong about the device: the queued pill sampled `#C98C0A` on a `#101317` surface for **6.42:1, identical to the computed figure**. **The three FAILING pairs were not reachable on the device** — light theme was not exercised, and `accent`/`critical` need an uploading or failed chunk, which needs a running dispatcher (item 36, no backend). So the arithmetic is trustworthy and the three failures remain unobserved in the flesh. | A-130, A-090, A-133, item 74, item 36, Ch. 2.10 §2.1/§2.2 |
| 103 | **Chapter 2.10 §8's verification checklist can never be completed as written — two of its six screens do not exist** | **Recorded so that a future "accessibility verified" claim cannot be made against a list that was only ever four-sixths runnable.** §8 requires a TalkBack pass and a 100/150/200% text-scaling pass on six named screens. **Assign Collectors (A-06)** and **Metadata Detail (A-08)** have never been built.<br><br>Both blockers are already on this register and neither is close: **item 89** — Chapter 2.7 requires A-06's checkboxes to *"reflect current assignment state on load"* and no endpoint returns assignments or the org's Collectors; **item 97** — A-08 belongs to a `metadata` module that does not exist, whose creation takes the cross-feature sweep from 30 ordered pairs to 42.<br><br>**Stays open until BOTH close.** Not partially closable: §8 is a checklist, and four of six is a checklist that failed. When Mission 5.5's device pass completes, the correct statement is *"§8's four buildable screens pass"* — never *"§8 passes"*. | Item 89, item 97, A-129, Ch. 2.10 §8 |
| 104 | **Chapter 2.10 §5's "return focus to the triggering element" is structurally unsatisfiable under `context.go`** | **Not an omission and not fixable inside an accessibility pass.** §5 asks modals to *"trap focus within the modal while open, and return focus to the triggering element on dismissal."*<br><br>**The first half is satisfied more strongly than §5 asks** and is now held by a regression test (A-131): every screen Chapter 2.4 calls a modal is a full-screen `GoRoute` reached by `context.go`, so the triggering screen is not in the widget tree at all.<br><br>**That same fact is what makes the second half impossible.** `go` replaces the location; dismissal rebuilds the previous route from scratch, so the triggering element is a **new widget with no focus history** and there is nothing to return focus to. No amount of code in a form changes that.<br><br>Satisfying it needs one of: presenting these screens as pushed routes or overlays (a Chapter 2.4 change, and A-04/A-05 are specified as *modals* while being built as replacements — worth noticing), or tracking a focus target across route rebuilds, which nothing in this project does. **Owned by whoever revisits how modals are presented.** | A-131, Ch. 2.10 §5, Ch. 2.4 §2/§3, ADR-004 |
| 105 | **CLOSED — the 48dp minimum is now enforced by `meetsGuideline(androidTapTargetGuideline)` across every screen Mission 5 built** | **MEASURED ON DEVICE 2026-08-17 (CPH2707, dpr 3.0). Twelve element classes, ZERO violations** — so the risk this item was opened against did not materialise, and what remains is that nothing holds it that way.<br><br>`Login email/password/buttons 144px = 48.0dp` · `AppBar back 144×144px = 48×48dp` · `tab bar item 216×240px = 72×80dp` · `C-04 project rows 264–294px = 88–98dp` · `C-05 task rows 216px = 72dp` · `checklist rows 216px = 72dp` · `C-06/checklist Start Recording 168px = 56dp` · `C-09 Stop 240×240px = 80×80dp` (§3 asks ≥64 — **passes**) · `Settings row 168px = 56dp` · `dialog buttons 144px = 48dp` · `C-11 session group 306px = 102dp`.<br><br>**Three elements sit exactly ON 48dp** — Login's controls, the AppBar back button and the dialog buttons — so they meet §3 with **zero margin**. A single padding change regresses them, and nothing would fail.<br><br>**The status pill measures 24dp high and that is NOT a violation**: it is `clickable=false`, and §3 scopes its minimum to *"standard buttons, list rows, tab bar items"*. Recorded so a future reader does not 'fix' it.<br><br>**The token exists, which is what makes this easy to miss.** A reader finding `minTouchTarget` in `lib/app/theme/app_sizes.dart` reasonably concludes the minimum is handled. Swept `lib/` and `test/`: **zero occurrences outside its own declaration.**<br><br>Chapter 2.10 §3 sets **44×44pt (iOS) / 48×48dp (Android)** for *"standard buttons, list rows, tab bar items"*, with the Recording Screen's Stop at **≥64** and the checklist's retry action **full-width, ≥44pt height**. Only C-09's Stop is verifiably compliant by inspection — `SizedBox.square(dimension: 80)`, checked during Mission 5.5.<br><br>**Everything else relies on Material's defaults**, which usually do meet 48dp and are not a guarantee anyone has checked: a `ListTile` with reduced `contentPadding`, an `IconButton` with a constrained box, or a `Chip` can all render under it. `AdminProjectDetailScreen`'s rows already set a custom `contentPadding`.<br><br>**Two separable pieces of work**, and neither was in Mission 5.5's scope: measure the real rendered sizes on device (Bucket B), and add a check — a widget test asserting a minimum tap-target size, or a lint — so the token means something. **CLOSED 2026-08-17 by Mission 5.6.** `flutter_test` ships `androidTapTargetGuideline` at `Size(48, 48)` — **the same number Chapter 2.10 §3 states** — so the threshold is not this project's to restate and no new dependency was added. Ten screens are swept in `test/accessibility/screen_accessibility_sweep_test.dart`; `labeledTapTargetGuideline` (§4) and `textContrastGuideline` (§2.3) ride along and pass 10/10 and 20/20.<br><br>**The sweep immediately found a violation the hand measurement had missed** — C-06, open item 108 — which is the argument for the mechanism rather than a mark against it. §3 no longer holds by luck. | A-136, A-129, A-133, item 108, Ch. 2.10 §3 |

| 106 | **CLOSED — every `ChunkStatusPill` announced its own label TWICE; found on device and fixed in the same sub-mission** | **A defect no widget test caught and no screenshot shows, because it exists only in the accessibility tree.** Dumped from C-11 on CPH2707: `content-desc='Queued\nQueued'`.<br><br>**Cause.** `ChunkStatusPill` wraps its content in `Semantics(label: _semanticLabel(), container: true, …)` while the child `Text(_label())` still contributes its own text, and the two merge. `_semanticLabel()` returns `_label()` verbatim for every state except `failed`, so **all four states double**: *Queued Queued*, *Uploading 62% Uploading 62%*, *Complete Complete*, and *Failed. Retry available. Failed*.<br><br>**The intent was the opposite of the effect.** The widget's own comment says *"The visual label already carries the state; this adds the retry detail for a screen reader"* — the author meant to ADD the retry sentence, not to repeat the word. The bug is that adding a label to a node whose child already has text does not replace it.<br><br>**FIXED 2026-08-17**: `excludeSemantics: true` on the `Semantics`, so the composed label is the only thing announced. Five tests added, asserting **equality rather than `contains`** — the defect was a label that *contained* the right word twice, so a substring assertion passes on the bug. The failed case asserts the retry sentence **survives**, which is what makes excluding the child correct rather than lossy, and one test asserts the visible word is still rendered, because `excludeSemantics` removing text from the screen would cost every sighted Collector the pill's word while the other assertions stayed green. Verified to fail without the fix.<br><br>**C-11 is on Chapter 2.10 §8's TalkBack list**, so this sat on a screen the specification names. **The lesson outlives the fix**: this existed only in the accessibility tree — invisible to every widget test, every golden and every screenshot — and only a platform-tree dump could see it. | A-133, A-132, Ch. 2.10 §4, Ch. 2.10 §8, `chunk_status_pill.dart` |
| 107 | **CLOSED — tab bar labels were clipped at 150% AND 200% OS text scale; found and fixed in the same sub-mission** | **Measured, not estimated.** At `font_scale` 1.0, 1.5 and 2.0 the tab item's bounds are **identical — `[0,2138][216,2378]`, 240px = 80dp**. The bar does not grow; the label does. *"Dashboard"* wraps to *"Dashboa / rd"* and the second line falls outside the node and off the bottom of the screen. Visible in screenshots at both scales.<br><br>§6: *"Layouts … **reflow vertically rather than truncating or overlapping** when text is scaled up to at least 200%, per WCAG 1.4.4"*, and *"no critical information is conveyed only through truncated text with no way to view the full value"*. A tab whose name reads *"Dashboa"* is both.<br><br>**It fails at 150%, not only at 200%**, so the threshold is at or below the midpoint of the range §8 requires testing.<br><br>**Everything else reflowed correctly** at both scales, which is what isolates this to the bar: C-11's banner grew 234→669px, its session group 306→453px, C-04's rows 294→687px, C-06's instructions 216→756px — all without truncation. **C-06's AppBar title truncates to "East embankment…" at 200%**, which is a lesser instance: the full title is on the row that led there, so no information is unreachable.<br><br>**Affected every tabbed screen for both roles** — nine `NavigationDestination`s across the Collector's five tabs and the Admin's four.<br><br>**FIXED 2026-08-17** in `TabShell`: the bar's height is now a function of `MediaQuery.textScalerOf`, floored at Material's own 80dp so **100% is unchanged and every committed golden stays pixel-identical** — growth only ever adds.<br><br>**Two rejected alternatives, recorded because they look cheaper.** *Shorter labels* would rename tabs that Chapter 2.4 §2 and §3 name, making a specification change for a layout reason. *`labelBehavior: onlyShowSelected`* hides information without fixing anything — the selected label still wraps inside the same fixed space.<br><br>**Verified by the method that found it**: `1.0 → 240px = 80.0dp` (unchanged), `1.5 → 276px = 92.0dp`, `2.0 → 312px = 104.0dp`, with both scaled states screenshotted showing the full label on screen.<br><br>**RESIDUAL, not hidden**: *"Dashboard"* still wraps mid-word to *"Dashboa / rd"* at both scales. That is reflow — what §6 asks for — and it is no longer truncation, but it reads poorly. Removing the wrap needs a narrower font or a shorter label, neither of which is an accessibility fix, so it is left as a cosmetic note rather than reopened. | A-133, A-134, Ch. 2.10 §6, Ch. 2.10 §8, `tab_shell.dart` |

| 108 | **C-06's reference-example URLs are 28dp long-press targets — Chapter 2.10 §3 forbids both the size AND the interaction** | **Found by `androidTapTargetGuideline` on its first run, on a screen Mission 5.5's device pass had already measured by hand and passed.** The dump: `Rect.fromLTRB(16.0, 176.0, 784.0, 204.0)`, `actions: [longPress]`, `flags: [isTextField, isMultiline, isReadOnly]` — **768×28 dp, twenty under the minimum**.<br><br>**Two distinct breaches, and the second is the worse one.** §3's table sets 48×48dp for interactive elements. §3's bullet then says: *"No interactive element on any Collector screen requires a multi-finger gesture, **a precise long-press**, or a drag to operate."* `SelectableText` makes a precise long-press the ONLY way to use these URLs. **Enlarging the target satisfies the table and leaves the bullet broken.**<br><br>**Not fixed, because every fix is a product decision.** Replacing `SelectableText` with `Text` removes the only way to copy a URL and makes **open item 80** worse — those URLs already open nothing, pending an ADR-030 `url_launcher` decision. Padding to 48dp enlarges a target whose interaction §3 prohibits at any size. Adding a real tap action is item 80's fix, and it would close this item as a side effect — which is the strongest argument that **these two should be resolved together**.<br><br>The sweep records it as `skip: true` **with the reason in the test name**, so it prints on every run rather than hiding in a comment. Delete the skip when this closes. | A-136, item 80, Ch. 2.10 §3, `collector_task_detail_screen.dart` |
| 109 | **Golden tests cover ONE component; Chapter 9.7 §2 asks for every Design System component** | **Distinct from open item 19, which closed the mechanism rather than the coverage.** Item 19 answered *can this project do golden tests without `golden_toolkit`* — yes, `matchesGoldenFile` — and delivered the status pill in both themes on a CI run that verified rather than generated. It never claimed the set was complete.<br><br>Chapter 9.7 §2: *"Every reusable Design System component (Volume 2, Chapter 2.8 — **buttons, status pills, checklist items, form fields**) has a golden test capturing its rendered output in both light and dark theme."* **One test file, two committed images, one component.**<br><br>**Bounded by item 74, and that is what stops this being a simple to-do.** Chapter 2.8 is not in this repository, so *"every reusable Design System component"* has no enumerable membership — the four named in §2's parenthesis are examples, not the list. Building goldens for four guessed components would produce a number without producing the coverage §2 means.<br><br>**Closing it needs item 74 first**, or an explicit decision that the components named in §2's parenthesis ARE the list. | Item 19, item 74, A-095, Ch. 9.7 §2 |

| 110 | **SECURITY — recorded GPS coordinates and video files sit in app data that Android backs up by default; Volume 8's threat model never considered backup** | **The most serious finding of Mission 5.7's security review, and deliberately NOT fixed there.** Pre-existing, from Missions 3–4; surfaced because Mission 5.4 added a new consumer of device storage.<br><br>**The state.** `mobile/android/app/src/main/AndroidManifest.xml` sets **no `android:allowBackup`, no `android:dataExtractionRules`, no `android:fullBackupContent`**, and no backup-rules XML exists anywhere under `android/`. Android's default therefore applies.<br><br>**What is in scope of that default.** Both live under `getApplicationDocumentsDirectory()`: the **Isar database**, whose `EmbeddedGpsFix` persists `latitude` and `longitude`, and the **recorded `.mp4` chunk files** themselves (`main.dart` passes the same `documents.path` to `databaseDirectoryProvider` and to `recordingOverrides`).<br><br>**Why the existing decision does not cover it.** Volume 8 Chapter 8.2 §3 chose OS-level app-sandbox encryption over app-level AES, reasoning that *"no other app can read this app's sandbox without root/jailbreak"* — **an app-to-app threat model**. Backup and device-to-device transfer copy data *out of* the sandbox that reasoning depends on. **The word "backup" appears nowhere in Volume 8** — searched across all 18 pages, not sampled.<br><br>**Secondary, and independent of disclosure:** `flutter_secure_storage` on Android uses `EncryptedSharedPreferences`, whose master key lives in the Android Keystore and is **not** backed up. A restored install therefore reads back undecryptable blobs rather than tokens — a correctness failure that arrives through the same mechanism.<br><br>**Why it was not fixed in a review sub-mission.** The fix is not one attribute. It is a decision about *what* to exclude versus disabling backup entirely, taken against Volume 8's threat model and Volume 1's data-handling commitments, and it belongs to whoever revisits that model. Setting `allowBackup="false"` unilaterally would also silently change device-transfer behaviour for any existing install.<br><br>**Worth deliberate scheduling given what is at stake — GPS coordinates and recorded video of third parties. Not urgent-today; not indefinitely deferred either.** Distinct from open item 45, which is about merged *permissions* and an exported receiver in the same file — same manifest, different subject. | A-138, A-069, item 45, V8 Ch. 8.2 §3, `AndroidManifest.xml` |


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

---

### A-141 — Volume 4 Chapter 4.9 §5's IaC deferral is closed: Terraform

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.9 §5 |
| **Says** | *"Infrastructure-as-code tooling (CDK/Terraform/CloudFormation) choice — Volume 7."* |
| **Should say** | Terraform. The deferral to Volume 7 was never discharged there. |
| **Authority** | ADR-043 |
| **Class** | Deferral closed |
| **Status** | Open |
| **Date** | 2026-08-17, Mission 6.1 |

Volume 7, Chapter 7.8 is the chapter the deferral points at. It covers per-developer IAM users, CLI profile naming and credential hygiene, and **never makes the choice**. The deferral has been outstanding since Volume 4 was written, and `infrastructure/aws/README.md` has carried the consequence in its own words: *"This is not infrastructure-as-code. There is no state file and nothing detects drift."*

That README's sentence is now wrong for anything provisioned from this mission onward, and it has been corrected in place rather than left to mislead.

### What Mission 6.1 provisioned — as a plan, not as infrastructure

**All 35 resources are live.** The mission planned first and applied second, in two attempts — see A-146 for why there were two. `terraform plan` now reports `No changes` at `-detailed-exitcode` 0. What was provisioned:

| Module | Resources | Notes |
|---|---|---|
| network | 8 | VPC `10.0.0.0/16`, two private DB subnets in `ap-south-1a`/`1b`, one route table with only the local route, two associations, the Aurora security group, the emptied default security group |
| database | 4 | Aurora Serverless v2 PostgreSQL 16.14, one writer, DB subnet group, cluster parameter group |
| iam | 23 | Seven roles across ADR-015's six domains + seven log policies + seven Data API policies + two S3 policies, one on each chunks role |

The plan was **32** as first written, with a single `chunks` role holding both S3 policies. Mission 6.1.3 split that role in two (A-143), which added one role and its two attendant policies.

Live counts, read from AWS rather than from state: 1 VPC, 2 subnets, 1 custom route table, 2 associations, 2 security groups, 1 DB subnet group, 1 cluster parameter group, 1 cluster, 1 instance, 7 roles, 16 inline role policies. **0 internet gateways, 0 NAT gateways, 0 VPC endpoints.**

Two things were provisioned outside Terraform, deliberately and documented:

- **`vump-platform-tfstate`** — the state bucket, created by four `aws s3api` calls (create, versioning, encryption, public-access-block). It cannot be created by the configuration that stores its state in it. The commands are in `infrastructure/terraform/README.md`.
- **Account-level S3 Block Public Access** — see A-145.

### The two `.tmpl` policies are rendered for the first time

`infrastructure/aws/iam/*.json.tmpl` have existed since Mission 0.17 with `__ENV__` and `__BUCKET__` placeholders that **nothing ever substituted**. The Terraform root module now renders them, so they are load-bearing rather than declarative. They were renamed to sit under ADR-015's `chunks` domain:

| Was | Is |
|---|---|
| `chunk-registration-s3-policy.json.tmpl` | `chunks-presign-upload-s3-policy.json.tmpl` |
| `chunk-verification-s3-policy.json.tmpl` | `chunks-verify-object-s3-policy.json.tmpl` |

Their contents are unchanged apart from the `Id` field, which tracked the old names.

---

### A-142 — Volume 4 Chapter 4.9 §2 and Volume 8 Chapter 8.4 §1 describe different database access paths

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.9 §2, against Volume 8 — Security, Chapter 8.4 §1 |
| **Says** | V4.9 §2: Aurora *"reachable only from the Lambda functions (via a VPC-attached execution role)"*. V8.4 §1: every function's permission is `rds-data:ExecuteStatement`. |
| **Should say** | The RDS Data API. V4.9 §2's mechanism clause is superseded; its intent — never exposed to the public internet — is preserved and strengthened. |
| **Authority** | ADR-044 |
| **Class** | Contradiction resolved |
| **Status** | Open |
| **Date** | 2026-08-17, Mission 6.1 |

A VPC-attached function opens a TCP connection to port 5432. A Data API caller makes a signed HTTPS request to an endpoint **outside** the VPC and never joins it. The two designs need different subnets, different security groups, a different execution role, and — decisively — one needs a NAT gateway and the other does not.

This is the same shape as ADR-015: two accepted documents disagreeing, discovered because implementation could not begin without an answer. Neither half was a typo. V8.4 §1's action names are specific enough to have been written against the Data API deliberately.

### Why the CLI cannot verify Data API availability, recorded so it is not re-attempted

`aws rds describe-db-engine-versions --engine aurora-postgresql` returns **no `SupportsHttpEndpoint` field at all** for any version in `ap-south-1`. The obvious reading is "unsupported", and it is wrong: the same query against `us-east-1` and `ap-southeast-1`, where the Data API demonstrably works, also returns no such field. The attribute is simply no longer emitted. The CLI was current (`aws-cli/2.36.17`), so this is not a stale client.

**What answers it:** the AWS region-and-version table, which lists Asia Pacific (Mumbai) as supported at PostgreSQL 17.4+, 16.1+, 15.3+, 14.8+ and 13.11+; corroborated by `rds-data.ap-south-1.amazonaws.com` resolving.

**PostgreSQL 18 is offered in `ap-south-1` and is absent from that table.** An upgrade to 18 would silently remove the only access path this backend has, and `describe-db-engine-versions` would report 18.4 as perfectly available.

---

### A-143 — Consolidating the two chunk policies onto one role widens what a presigned URL can do

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.9 §2; Volume 8, Chapter 8.4 §1 |
| **Concerns** | ADR-015's six-domain decomposition against per-function S3 narrowness |
| **Authority** | ADR-015 (domain count), Volume 4 Ch. 4.9 §2 (narrowness) |
| **Class** | Least-privilege regression, found and closed within the same mission |
| **Status** | **Closed** — fixed in Mission 6.1.3, before anything was applied |
| **Date** | 2026-08-17, Mission 6.1 |

ADR-015 fixes **six** resource domains. Volume 8, Chapter 8.4 §1 and `docs/architecture/aws-sdk-integration.md` describe **two separate S3 permission sets** for chunk work — one that presigns uploads, one that reads objects to verify integrity — and both belong to the `chunks` domain.

Six roles means both sets attach to one principal. `vump-dev-chunks` therefore holds `s3:PutObject` **and** `s3:GetObject` on `vump-platform-dev/*`.

### Why that is not merely untidy

`aws-sdk-integration.md` states the mechanism it breaks:

> *"A presigned URL carries the signer's permissions. This is the part that catches people out: if the registration role held `s3:GetObject`, a presigned URL it generated could be crafted to read objects. Withholding `GetObject` from that role is what makes the narrowness real rather than conventional."*

The registration role now holds `s3:GetObject`. The property that document describes as *"real rather than conventional"* has become conventional again: it now depends on the handler code not presigning a `GetObject`, rather than on the role being unable to.

**Concrete failure:** a defect or an injection in the chunk-registration path that reaches the presigner with a `GetObject` command produces a URL that reads raw footage — a URL that can leave the trust boundary, since presigned URLs are handed to devices by design. Under the previous split the same defect produces an `AccessDenied` from S3.

### The fix, taken in Mission 6.1.3

**The `chunks` domain now carries two roles**, and ADR-015's six domains are unchanged:

| Role | Actions | Cannot |
|---|---|---|
| `vump-{env}-chunks-upload` | `s3:PutObject`, `s3:AbortMultipartUpload`, `s3:ListMultipartUploadParts` | read any object — no `s3:GetObject` |
| `vump-{env}-chunks-verify` | `s3:GetObject`, `s3:GetObjectAttributes`, `s3:GetObjectVersionAttributes` | write any object — no `s3:PutObject` |

Neither holds `s3:DeleteObject`; no role in this project does.

**A domain is a unit of code decomposition; a role is a unit of privilege, and
nothing requires them to be one-to-one.** That is the whole of the fix. The
module's map is keyed by role rather than by domain, each entry naming the domain
it serves, so two roles sharing a domain needs no special case.

The property `aws-sdk-integration.md` calls *"real rather than conventional"* is
real again: the upload role cannot presign a read, however the handler is
written.

### What this obliges Mission 6.2 to do

**A Lambda function has exactly one execution role.** Two chunks roles therefore
mean the chunks domain deploys **two functions**, not one — which is a
refinement of ADR-015's *"one function per resource domain"* rather than a
contradiction of it, and it is the shape the volumes already describe: Volume 8,
Chapter 8.4 §1 tabulates `chunk-registration` as its own function, and
`aws-sdk-integration.md` lists chunk-registration and chunk-verification
separately.

Recorded here because the alternative reading — one chunks function that somehow
holds both roles — is not implementable, and 6.2 should not discover that while
writing handlers.

### Caught before anything existed

Nothing had been applied when this was found, so the fix is a plan diff rather
than an IAM change against a live role. **That is the argument for stopping at
`plan` rather than applying and reviewing after.** Had 6.1 applied, closing this
would have meant detaching a policy from a role a function was already using.

---

### A-144 — Volume 7 Chapter 7.8 §2's CLI profiles do not exist, and the live principal is an administrator

| | |
|---|---|
| **Volume** | 7 — Development Environment, Chapter 7.8 §1 and §2 |
| **Says** | §2: profiles `human-archive-dev` / `-staging` / `-prod`. §1: *"Each developer gets their own IAM user… scoped to the dev environment only."* |
| **Should say** | One profile exists, `default`, and it resolves to `arn:aws:iam::929570731524:user/faisal-admin`. |
| **Authority** | Observation — no ADR grants this; it is a divergence, not a decision |
| **Class** | Unimplemented requirement |
| **Status** | Open — own open item, not blocking |
| **Date** | 2026-08-17, Mission 6.1 |

Three names are in play and none agrees with another:

| Source | Profile |
|---|---|
| Volume 7, Ch. 7.8 §2 | `human-archive-dev` |
| `backend/.env.example:64` | `vump-dev` |
| `aws configure list-profiles` | `default` |

The naming half is cosmetic — the volume's is pre-rename (A-002), and `.env.example` uses the current project name.

**The scope half is not cosmetic.** V7.8 §1 requires a per-developer user scoped to dev. The live principal is an administrator, and every read in this mission — and every `terraform plan` and future `apply` — runs with administrative rights in an account that also holds `vump-platform-prod`. ADR-014 already records that in a single-account model IAM is the only thing preventing a development context from reaching production. That statement is about service roles; it applies at least as strongly to the human.

Not fixed in Mission 6.1, whose IAM scope is roles rather than users.

---

### A-145 — Volume 8 Chapter 8.4 §3's account-level Block Public Access was absent, and is now set

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.4 §3 |
| **Says** | *"S3 bucket public access is blocked at the account level (AWS's Block Public Access setting), not just at the individual bucket policy level, so a future misconfiguration can't accidentally expose it."* |
| **Was** | Not configured. `get-public-access-block` returned `NoSuchPublicAccessBlockConfiguration` for account 929570731524. |
| **Is** | All four settings `true` at the account level. |
| **Authority** | Volume 8, Chapter 8.4 §3 — an accepted requirement, unimplemented |
| **Class** | Requirement implemented |
| **Status** | **Closed** |
| **Date** | 2026-08-17, Mission 6.1 |

### What was and was not exposed

Nothing was public. All three chunk buckets already carried **per-bucket** Block Public Access with all four settings enabled, and `get-bucket-policy-status` reported `IsPublic: false` for each.

What was missing is exactly what V8.4 §3 justifies the account-level control by: the **future** bucket. A bucket created without per-bucket BPA — by a script, by a console click, by a Terraform resource that omits it — would have had no backstop. `vump-platform-tfstate`, created in this same mission, is precisely such a bucket; it was given per-bucket BPA explicitly, which is the kind of step that gets forgotten once.

### Why this was fixed rather than reported

Mission 6.1's standing instruction is to **report** security findings and not fix them. This one was fixed under **explicit, specific authorisation**, recorded here so the exception is not read as precedent. The reasoning that earned the authorisation: a documented requirement in an accepted volume, unimplemented; one idempotent API call; and zero functional risk, since no bucket policy in the account is public and CloudFront — the one service that would need an exception — is not provisioned and uses Origin Access Control rather than public access when it is (ADR-011).

It was applied as its own commit, touching no infrastructure code.

---

### A-146 — The AWS account moved from the Free plan to the Paid plan mid-mission, and why that appears in the history

| | |
|---|---|
| **Volume** | 7 — Development Environment, Chapter 7.8 |
| **Concerns** | Account plan as a precondition for provisioning — a class of constraint no volume names |
| **Was** | `accountPlanType: FREE`, $120 credits, expiring 2027-02-09 |
| **Is** | `accountPlanType: PAID`, `ACTIVE`, credits carried over, no expiration |
| **Authority** | Observation, plus the owner's decision to upgrade |
| **Class** | Precondition recorded |
| **Status** | **Closed** |
| **Date** | 2026-08-17, Mission 6.1 |

Mission 6.1's first `terraform apply` created 26 of 35 resources and then failed:

> `Error: creating RDS Cluster (vump-dev-aurora): api error FreeTierRestrictionError: The specified backup retention period exceeds the maximum available to free tier customers. To remove all limitations, upgrade your account plan.`

Recorded because **an account-plan error in a mission's history reads as a configuration mistake, and this was not one.** `backup_retention_period = 7` was a deliberate decision; it was never changed to work around the restriction, and the eventual apply used the same value.

### Why `terraform plan` could not have caught it

Account-plan restrictions are invisible to the AWS provider. They are not in any resource schema, no data source exposes them, and `plan` computes a diff without calling `CreateDBCluster`. **The plan was correct and the apply still failed** — which is a real limit on what a clean plan proves, and worth knowing before treating one as a safety gate.

What did work as intended: the failure was atomic per resource. No partial cluster existed, Terraform state matched AWS exactly at 26 resources, and the remaining 9 applied later with no edit to any `.tf` file.

### The reason the upgrade mattered more than the retention number

The retention cap was the visible symptom. The disqualifying property was in AWS's own description of the Free plan:

> *"Your free account plan ends after six months or when your credits are fully used — whichever occurs first. After your free account plan expires, your account closes automatically, and you lose access to your resources and data."*

ADR-014 places **all three environments, production included, in this single account**. An account that deletes its own contents on a date is not a foundation for evidentiary footage held under Volume 8, Chapter 8.7's retention obligations. The upgrade removed a constraint that would have expired the platform, not merely a limit on a backup setting.

### What this adds to Volume 7, Chapter 7.8

Chapter 7.8 covers IAM users, CLI profiles and credential hygiene — everything about *who* may call AWS, and nothing about *what the account is permitted to run*. Those are different preconditions and only the first was written down. **The account plan is now a checkable precondition** for any mission that provisions:

```bash
aws freetier get-account-plan-state
```

`PAID` / `ACTIVE` is the state this project requires. It is one call and belongs beside the credential checks rather than being discovered by a failed apply.

---

### A-147 — ADR-019's squash-into-`develop` rule is suspended once, for the reconciliation merge

| | |
|---|---|
| **Record** | ADR-019 — Branching Strategy, "Merge strategy — and why it differs per target" |
| **Says** | *"Into `develop` — **Squash** — One unit of work, one commit."* |
| **Exception** | This one merge uses a **merge commit**. The rule is not changed and applies to every other pull request. |
| **Authority** | ADR-019 remains binding; this is a recorded deviation, not an amendment to it |
| **Class** | One-time exception |
| **Status** | **Closed** on merge |
| **Date** | 2026-08-17, Mission 6.1.7 |

`develop` was created in Mission 6.1 by branching from `main`, and `main` predates Mission 0.17. The result is that `develop` is **189 commits behind the work** — `infrastructure/`, `backend/`, ADR-011 through ADR-042, `docs/volumes/` and every Flutter feature from Missions 1 through 5 exist only on `mission-0.18.4-ci`. This is deferred item 7.

This pull request closes that gap. It is not a feature change and contains no new work beyond this entry.

### Why squashing here would be wrong

ADR-019's reason for squashing into `develop` is stated plainly: *"One unit of work, one commit. `develop`'s history reads as a list of completed changes, not of the fumbling that produced them."*

**This is not one unit of work.** It is 189 commits spanning Missions 0.17 through 5 — a CI pipeline, an authentication feature, a recording engine, an upload pipeline, ten screens, thirty-two ADRs and a hundred and forty amendments. Squashing them would produce a single commit containing 83,000 lines and would erase, permanently:

- **Which mission introduced which change.** Every `git blame` on 398 Flutter files would resolve to one reconciliation commit dated today, rather than to the mission that wrote the line and the message explaining why.
- **The traceability ADR-019 itself depends on.** The same record requires history to be *"written for the person doing archaeology"* and every commit on a shared branch to build and pass tests. One 83,000-line commit satisfies neither.

ADR-019 already contains the argument against doing this, in its own alternatives: *"**Squash everything, including into `main`** — rejected. It would collapse a release into one commit and erase which changes it contained."* The reasoning is about `main`, and it applies with more force to 189 commits than to one release.

### Why this is an exception and not a new rule

The squash rule is correct for what it governs: a feature branch representing one unit of work. This branch is not that, and it exists only because `develop` was created late and from the wrong base. **Once merged, the situation cannot recur** — `develop` will be current, and every subsequent pull request will be a normal feature branch that squashes.

The exception is recorded rather than taken quietly because a rule bypassed without a record is a rule that erodes. ADR-019 says as much about its own review requirement: *"a rule that is routinely ignored teaches that rules are optional."*

### Numbering, so the gap is not read as a loss

This entry is **A-147**, and A-141 through A-146 do not exist on this branch. They are Mission 6.1's, written on `mission/6.1-aws-foundations`, and they land in `develop` when that pull request merges. The gap is reserved, not missing.

---

### A-148 — CI had no gate on infrastructure, and the first Terraform pull request is what showed it

| | |
|---|---|
| **Record** | ADR-019 — required status checks; ADR-043 — Terraform |
| **Was** | Ten jobs, every one Dart-scoped. `grep -E "terraform|\.tf\b"` over `ci.yml` returned nothing. |
| **Is** | Eleven jobs. A `Terraform` job runs `fmt -check`, `validate` and `tflint`; `Environment consistency` reads `.tf` variable defaults as a fourth language. |
| **Authority** | ADR-019 (required checks), ADR-043 (Terraform as the IaC tool) |
| **Class** | Enforcement gap closed |
| **Status** | **Closed** |
| **Date** | 2026-08-17, Mission 6.1.7 |

Mission 6.1.6 pushed the first branch carrying a Terraform change and watched the suite run over it. Every job passed, and the passing was the finding: **six of the seven required checks would have passed exactly the same way over a diff that was Terraform and nothing else.** `Format` and `Analyze` read `mobile/`. `Test` re-runs the Dart suite. `Architecture boundaries`' 63 checks are all `lib/`-scoped. `AWS credential isolation` reads `mobile/pubspec.yaml` and `lib/`.

A green pipeline over an unexamined change is worse than no pipeline, because it reads as verification.

### What CI would not have caught

Three concrete things from Mission 6.1's own history:

- **`terraform validate`, `fmt` and `tflint` failures.** All three were run by hand. tflint found six real issues on its first run — every module missing `required_version` and `required_providers` — and nothing in CI would have.
- **A `.tf` region or bucket disagreeing with `environments.json`.** ADR-043 made Terraform a **fourth** language holding values that Dart, JSON and shell already hold, and `Environment consistency` — the job written precisely to stop those three drifting — did not read it.
- **The A-143 privilege regression**, where one role held both `s3:PutObject` and `s3:GetObject`. Still not caught, and deliberately so: see below.

### Two changes, and one thing deliberately not changed

**A `Terraform` job.** `fmt -recursive -check`, then `init -backend=false` and `validate` per environment root, then `tflint --recursive`. `-backend=false` is what makes it runnable with no credentials — a real `init` reaches the S3 backend in `ap-south-1`, and `ci.yml`'s header commits to a workflow that uses no secrets. Validation needs the provider schema and the module sources, not the state.

**`Environment consistency` extended, not duplicated.** That job already owns cross-language agreement for the environment model; Terraform is a fourth holder of the same values. A second job would have split one invariant across two places, which is the failure the job itself exists to prevent.

**The Dart-scoped jobs are untouched.** `Architecture boundaries` and `AWS credential isolation` are about `lib/`, and teaching either to reason about an IAM policy would make them two jobs wearing one name. **The consequence is that no CI job checks IAM least-privilege**, so the A-143 class of defect is still caught only by review. That is a known, named gap rather than an oversight.

### Proven non-vacuous before it was committed

A check that passes is not evidence until it has been shown to fail. The extended script was extracted from `ci.yml` and run against three planted drifts, each of which failed it with a named path and value:

| Planted | Result |
|---|---|
| `chunk_bucket` default set to `vump-platform-prod` in the `dev` root | ✅ failed — *"chunk_bucket default 'vump-platform-prod' != environments.json chunkBucket 'vump-platform-dev' for development"* |
| `region` default set to `us-east-1` | ✅ failed — *"region default 'us-east-1' != environments.json 'ap-south-1' (ADR-011)"* |
| `environment_slug` default set to `staging` in the `dev` directory | ✅ failed — *"environment_slug default 'staging' != directory 'dev'"* |

The unmodified tree passes. The first of those three is a staging-or-worse build pointed at the production bucket, which is the exact defect class `Environment consistency` was created for — expressed in the one language it could not read until now.

---

### A-149 — Two claims Mission 6.2 tested instead of trusting, and both held

| | |
|---|---|
| **Claims** | (a) ADR-036: `verifyIdToken` needs no service-account secret. (b) `aws-sdk-client-mock` works under Vitest. |
| **Result** | **Both confirmed by experiment**, before either was built on. |
| **Authority** | ADR-036 line 35; ADR-045 (test framework) |
| **Class** | Verification |
| **Status** | **Closed** |
| **Date** | 2026-08-18, Mission 6.2 |

### (a) Firebase token verification needs no credential

ADR-036 records an asymmetry, in the middle of an ADR about something else:

> *"token **verification** does not need this. `verifyIdToken` can be satisfied with Google's public certificates and no secret at all … Writing claims is the operation that needs privilege."*

Mission 6.2's whole auth scope depended on that being true, so it was tested rather than cited. A throwaway probe initialised `firebase-admin` 14.2.0 with `{ projectId }` and **no credential**, with `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_CONFIG`, `GCLOUD_PROJECT` and `GOOGLE_CLOUD_PROJECT` all explicitly deleted, then called `verifyIdToken` twice:

| Input | Result |
|---|---|
| `'this-is-not-a-jwt'` | `auth/argument-error` — *"Decoding Firebase ID token failed."* |
| A well-formed **unsigned** JWT with the correct `iss` and `aud` | `auth/argument-error` — ***"Firebase ID token has `kid` claim which does not correspond to a known public key."*** |

**The second result is the finding.** That error is only reachable after the SDK has fetched Google's public certificate set and compared the token's `kid` against it. `initializeApp` returned normally; no credential was configured; verification still reached signature-key lookup. A missing-credential failure would have surfaced at initialisation or as an ADC error, and neither happened.

### What that resolves

Mission 6.2's trace flagged an apparent conflict: Chapter 4.7 §1 step 3 requires *"each Lambda function verifies the token"*, but Mission 6.1's IAM grants `vump/dev/firebase-service-account-*` to `auth-verify` **only** — verified live, the other six roles hold the Aurora secret and nothing else.

**There is no conflict.** Verification needs no secret, so all seven functions satisfy Chapter 4.7 §1 step 3 with the IAM already applied. `auth-verify`'s Firebase grant is for the claims-*writing* path that ADR-036 identifies as the privileged one — the operation that arrives when `functions/` is retired, not one 6.2 uses.

So `auth-verify`'s token verification is **built for real**, not stubbed. Only the `users`-table lookup behind it is stubbed, and that is 6.3's because the table does not exist.

**One dependency worth naming:** the certificate fetch is an outbound HTTPS call. ADR-044's Shape B is what makes it free — no function joins a VPC, so none needs a NAT gateway to reach `googleapis.com`. Under the VPC-attached design this call is precisely what would have forced one.

### (b) `aws-sdk-client-mock` under Vitest

The library is Jest-shaped by reputation, and it is how a Data API test gets written in Mission 6.3 — so choosing Vitest without checking would have deferred the risk to the mission least able to absorb it.

Tested against Vitest **4.1.10** and `aws-sdk-client-mock` **4.1.0**, exercising the four things a Data API test actually needs: stubbing `ExecuteStatementCommand` to resolve, inspecting `commandCalls` for SQL and parameters, rejecting to drive an error path, and `reset()` between tests. **4 of 4 passed.**

One incidental: `vitest run --reporter=basic` fails on Vitest 4 — that reporter was removed. Noted because the failure output is a module-resolution stack trace that reads like a compatibility problem and is not one.

---

### A-150 — "Cannot modify any table" means no UPDATE and no DELETE; first-login INSERT is permitted

| | |
|---|---|
| **Volume** | 8 — Security, Chapter 8.4 §1, against Volume 4 — Backend Architecture, Chapter 4.7 §1 step 4 |
| **Says** | V8.4 §1: `auth-verify` has *"No database write access — read-only lookup on users by firebase_uid"*, and *"Cannot modify any table; a compromised token-verification path can't be leveraged into a data-write path."* V4.7 §1 step 4: *"the backend looks up (**or creates, on first login**) the matching users row via firebase_uid."* |
| **Should say** | Both, read narrowly: **no UPDATE, no DELETE**. `INSERT` of the caller's own row on first login is permitted. |
| **Authority** | Project owner's decision, Mission 6.2.1 |
| **Class** | Contradiction resolved |
| **Status** | Open — enforcement owed by Mission 6.3 |
| **Date** | 2026-08-18, Mission 6.2 |

One record says the token-verification path cannot write; the other requires it to create a row. Taken literally, a first login is impossible — Chapter 4.7 §1 step 4 has nowhere to put the user, and no other function is assigned the job.

### Why the narrow reading is the right one

V8.4 §1 states its own purpose in the same sentence: *"a compromised token-verification path can't be leveraged into a data-write path."* The threat is **an attacker using auth-verify to alter data** — escalating a role, reassigning an org, deleting an audit trail. Every one of those is an UPDATE or a DELETE.

An INSERT of a row **keyed by the `firebase_uid` of a token the function has just verified** does not serve that threat. The attacker would be creating their own account, having already authenticated as themselves. What they cannot do under this reading is touch a row that already exists — which is exactly the escalation V8.4 §1 is protecting against.

The broad reading would satisfy the sentence and defeat the chapter it appears in: no first login could ever succeed, so either the rule gets quietly ignored in code or the product does not work.

### Enforcement is 6.3's, and it is not IAM's

**This cannot be expressed in IAM.** ADR-044 records why: `rds-data` actions are scoped to the *cluster*, so V8.4 §1's per-table intent is not enforceable at that layer at all. The 6.1 report and ADR-044's status table both carry this as a known gap.

The enforcement point is PostgreSQL, in Mission 6.3's schema work:

```sql
GRANT SELECT, INSERT ON users TO vump_auth_verify;
-- deliberately no UPDATE, no DELETE, and no grant on any other table
```

**Flagged for 6.3, not implemented here.** Mission 6.2 owns no schema, and a grant against a table that does not exist is not a partial implementation — it is a statement that fails.

Until then the constraint is documentation. `resolveCaller` in `backend/packages/shared/src/handler.ts` is stubbed and issues no statement of any kind, so nothing violates it today — but nothing enforces it either, and that is the honest position.

---

### A-151 — The Lambda runtime was chosen from AWS's deprecation table, not from either available precedent

| | |
|---|---|
| **Record** | ADR-015 (Node on Lambda, version unstated), ADR-045 (this decision) |
| **Was** | Two precedents pointed different ways and neither was checked: local Node is v24.18.0, and `functions/package.json` pins `"node": "22"`. |
| **Is** | `nodejs24.x`, with `engines: ">=24 <25"` and esbuild targeting `node24`. |
| **Authority** | ADR-045 |
| **Class** | Toolchain decision |
| **Status** | **Closed** — revisit before 2028-04-30 |
| **Date** | 2026-08-18, Mission 6.2 |

ADR-015 fixes *"Node.js on AWS Lambda"* and names no version. Two obvious defaults were available and **both would have been wrong**:

| Runtime | Status today | Deprecation |
|---|---|---|
| `nodejs20.x` | **Deprecated** | 2026-04-30 — already past |
| `nodejs22.x` | Supported | **2027-04-30** |
| `nodejs24.x` | Supported | 2028-04-30 |
| `nodejs26.x` | **Public preview** | Not scheduled |

**Following `functions/`'s precedent would have shipped a new backend onto a runtime with roughly eight months of support left.** That is the kind of decision that looks like consistency and is actually a migration scheduled for someone else.

`nodejs26.x` is excluded on AWS's own words: *"Preview runtimes are not covered by the Lambda SLA or Technical Support, and should not be used for production workloads."*

### Two things this also settles

**AWS's `create-function` API accepts identifiers it will not support.** `aws lambda create-function help` lists `nodejs10.x` through `nodejs26.x` — including six deprecated runtimes and one preview. **The CLI's accepted values are not a list of supported runtimes**, and reading them as one is how a deprecated runtime gets chosen. The supported set lives in the documented deprecation table and nowhere queryable.

**Three places hold this version and must move together:** `backend/package.json`'s `engines`, `backend/scripts/build.mjs`'s esbuild `target`, and the `runtime` variable in `infrastructure/terraform/modules/api-gateway`. Nothing checks that they agree. That is a small, real gap — the same shape as the cross-language drift the `Environment consistency` CI job exists to catch, and a candidate for it.

`functions/` stays on Node 22 and is not changed: it is a Firebase Cloud Function on Google's runtime schedule, not Lambda's, and ADR-036 retires it (deferred item 10).

---

### A-152 — The Mission 6.2 scaffold: fifteen routes, seven functions, and nothing that pretends to work

| | |
|---|---|
| **Record** | ADR-015 (six domains), ADR-043 (Terraform), ADR-044 (Data API), ADR-045 (toolchain), A-143 (two chunks roles) |
| **Class** | Scaffold recorded |
| **Status** | Open — Mission 6.3 replaces the stubs |
| **Date** | 2026-08-18, Mission 6.2 |

`backend/` was empty from ADR-015 until now. It holds an npm workspace: a shared package, seven function packages, and a REST API in front of them.

### The route map, and the rule that produced it

Volume 4, Chapter 4.6's catalogue is **fifteen endpoints**, distributed across seven functions by **resource type rather than URL nesting**:

| Function | Routes | Note |
|---|---|---|
| `auth-verify` | `POST /v1/auth/verify`, `GET /v1/users/me` | "users" is not one of ADR-015's six domains; the caller's own profile is part of the auth surface |
| `projects` | `GET`/`POST /v1/projects` | |
| `tasks` | 5, incl. `GET /v1/projects/{projectId}/tasks` | **nested under projects, served by tasks** — the thing listed is a task |
| `sessions` | `POST`/`GET /v1/tasks/{taskId}/sessions` | same rule |
| `chunks-upload` | `POST /v1/sessions/{sessionId}/chunks` | |
| `chunks-verify` | `PATCH /v1/chunks/{chunkId}/status` | |
| `metadata` | `POST`/`GET /v1/chunks/{chunkId}/metadata` | holds no S3 permission at all |

**A-143's two chunks roles map cleanly onto two of Chapter 4.6's routes**, which is the confirmation the trace was looking for: registration (`POST …/chunks`, presigns an upload) and verification (`PATCH …/status`, which Chapter 4.10 §2 step 3 gates on the object's size and checksum) were already separate endpoints. The split was not retrofitted onto the specification — the specification already had two routes, and Mission 6.1 gave them two principals.

### What is real and what is not

**Real:** token verification (A-149), the Chapter 4.6 §1 envelope, the error taxonomy, cursor parsing, the router, and all of the infrastructure.

**Stubbed:** every one of the fifteen handlers, and the `users`-row lookup.

**How the stubs behave is the part that matters.** Each returns a named `NOT_IMPLEMENTED` refusal, 501, inside a real envelope — **after real token verification**. So an unauthenticated request gets `AUTH_TOKEN_MISSING` and an invalid token gets `AUTH_TOKEN_INVALID`, and neither reaches the stub. The authentication path is demonstrable today; the queries behind it are visibly absent.

Nothing returns invented data. `execute()` in the Data API client throws rather than returning an empty result set, because an empty result is a plausible answer that would let a caller believe the database had been consulted. `resolveCaller` returns `undefined` for `userId` and `orgId` rather than fabricating them, so a handler needing an org scope must fail rather than silently query a fabricated one.

### Pagination is in the contract before any query exists

Chapter 4.6 §1 fixes cursor pagination — *"`?cursor=…&limit=…` on every list endpoint"* — and ADR-044's **1 MiB Data API ceiling** turns that from a convention into a correctness requirement.

The next cursor is returned as a **sibling `meta` key**, not inside `data`. `data` stays exactly the resource the caller asked for, which matters because the mobile client's `VumpApi` returns `data` and nothing else to its callers — a cursor buried inside it would be a field every DTO has to know to ignore.

This had to be settled now rather than at 6.3: adding a required parameter later is a breaking change, and Chapter 4.6 §1 says a breaking change *"bumps to `/v2` rather than mutating existing contracts"*. The client does not consume cursors yet, so the backend defines the contract and the client inherits it.

### Three things this scaffold is bound by, that it did not choose

**The mobile client already implements three of these endpoints.** `chunk_upload_api_impl.dart` sends `{sequence_index, file_size_bytes, checksum_sha256}` to `POST /sessions/{id}/chunks` and reads `{chunk_id, s3_object_key, upload_urls}` back, throwing if `s3_object_key` is missing. Those shapes are a contract 6.3 must satisfy, not a design space.

**`CHUNK_ALREADY_REGISTERED` is load-bearing on both sides.** A Mission 4.2 test scripts that exact code against `VumpApi`. It is in the taxonomy and asserted by a test, so renaming it fails here rather than in the client.

**Function names are fixed by Mission 6.1's IAM.** The logs grant is scoped to `/aws/lambda/vump-{env}-*`, so a function named anything else runs and writes nothing. The Terraform creates the log groups explicitly rather than letting Lambda create them implicitly, which also gives them a retention period instead of "never expire".

### REST API, and the two later missions that decided it

The volumes never name the product tier — Chapter 4.6's "REST" is the architectural style (ADR-009). Two Volume 8 requirements settle it, and both are REST-API-only features: usage plans for Chapter 8.3 §1's per-user rate limiting, and WAF attachment for Chapter 8.4 §3. **Neither is built in 6.2.** Choosing the cheaper HTTP API now would have to be undone to satisfy either, and that migration is not a configuration flag.

### The cold-start cost, measured rather than assumed

Each bundle is **~1.6 MiB**, dominated by `firebase-admin`.

Tree-shaking works — `RDSDataClient` is provably absent from `auth-verify`'s bundle, because that function's routes never reach the Data API client. So the workspace layout is not what costs the size.

**Chapter 4.7 §1 step 3 is.** *"Each Lambda function verifies the token"* means every one of the seven carries the Firebase Admin SDK, and a package-per-function layout would produce the same seven copies. If cold starts become a measured problem, the lever is that requirement, not the layout — and the alternative would be an API Gateway authorizer, which is an architectural change and would need its own record.

---

### A-153 — The backend's standard is enforced, and the Node major now checks itself

| | |
|---|---|
| **Record** | ADR-045 (backend standards), A-148 (the same gap, for infrastructure), A-151 (which named this drift risk) |
| **Was** | Twelve files of backend standard and zero CI jobs reading them. Four files restating the Node major, with nothing comparing them. |
| **Is** | A `Backend` job — the twelfth — and a fourth agreement check inside `Environment consistency`. |
| **Authority** | ADR-045; Volume 8, Chapter 8.3 §4 |
| **Class** | Enforcement gap closed |
| **Status** | **Closed** |
| **Date** | 2026-08-18, Mission 6.2 |

This is A-148 happening a second time, in a second directory, for the same reason: **a standard was written and nothing executed it.** A-148 closed it for `infrastructure/terraform/`; ADR-045 created the identical exposure for `backend/` on the day it was accepted, and Mission 6.2 shipped a scaffold whose entire verification story was `npm run verify` on one laptop.

Worth naming as a pattern rather than as two incidents: **this project's failure mode is not writing the standard, it is that writing it feels like enforcing it.** Both times the gap was found by asking what a grep of `ci.yml` returns, and both times the answer was nothing.

### The `Backend` job

Six steps, scoped to `backend/`: `prettier --check`, `eslint`, `tsc --build`, `vitest run`, `npm audit`, `npm run build`.

**`npm ci`, not `npm install`** — it installs exactly the committed lockfile and fails when `package.json` and the lockfile disagree, which is the property ADR-045 commits the lockfile for in the first place.

**The audit step closes Volume 8, Chapter 8.3 §4**, which named the tool and had no implementation: *"an automated vulnerability scan (npm audit or an equivalent SCA tool) gating CI"*. Gated at `high`, one level stricter than the chapter's `critical` floor. The tree currently carries six moderate advisories, all transitive through `firebase-admin` — visible, below the line, and not blocking.

**The build step is not redundant with type-check.** The esbuild bundles are what Terraform packages; a configuration that type-checks and cannot bundle is still broken, and this is the only step that exercises esbuild at all.

### The Node major, in four places

ADR-045 pins Node 24 and A-151 explains why it is 24 rather than either available precedent. A-151 also recorded the drift risk and left it as an observation:

> *"Three places hold this version and must move together … Nothing checks that they agree. That is a small, real gap — the same shape as the cross-language drift the `Environment consistency` CI job exists to catch, and a candidate for it."*

It is now four places, because the CI job added its own pin, and the check exists:

| File | Holds |
|---|---|
| `backend/package.json` | `engines.node` |
| `backend/scripts/build.mjs` | esbuild `target` |
| `infrastructure/terraform/modules/api-gateway/variables.tf` | Lambda `runtime` |
| `.github/workflows/ci.yml` | `BACKEND_NODE_VERSION` |

**Extended rather than added as a job**, for the reason the Terraform check was in 6.1.7: `Environment consistency` already owns agreement between values that no compiler spans, and this is exactly that shape — now across JSON, JavaScript, HCL and YAML.

### Why this particular drift is worth a check

The failure is unusually badly-shaped. **Bundling for one Node major and deploying onto another produces syntax the runtime rejects at invocation, not at build.** The pipeline stays green, the deploy succeeds, and the defect surfaces as a function that returns a 502 on its first real request — the furthest possible point from the one-character change that caused it.

### Proven non-vacuous at every site

A check that passes proves nothing until it has been made to fail. Each of the four sites was moved in turn:

| Planted | Result |
|---|---|
| esbuild target left at `node22` | ✅ failed — named `build.mjs (esbuild target) -> Node 22` against three 24s |
| Terraform runtime at `nodejs22.x` | ✅ failed — named `variables.tf (Lambda runtime) -> Node 22` |
| `engines` bumped to `>=26 <27` | ✅ failed — named `package.json (engines.node) -> Node 26` |
| CI pin left behind at `22` | ✅ failed — named `ci.yml (BACKEND_NODE_VERSION) -> Node 22` |

The unmodified tree passes with `ok  Node major agrees in 4 places: 24`.

The output prints **all four paths and values**, not just the disagreement — so the message says which one moved, rather than only that they differ. With four sites and one wrong, the useful information is which.

### What is still not checked

The `Backend` job does not run against `mobile/` or `infrastructure/`, and the Terraform job does not run against `backend/`. That is correct — but it means **no job checks that the two agree about anything except the Node major**. The route templates in `modules/api-gateway/main.tf` and the route table in each handler are the same strings, and nothing compares them; a route added to one and not the other is a 404 discovered at runtime. Named here rather than fixed, because it needs a check that parses both HCL and TypeScript, and that is a larger piece of work than this mission.

---

### A-154 — `orgs` is Chapter 4.3's ninth table, and Chapter 4.4 never defined it

| | |
|---|---|
| **Volume** | 4 — Backend Architecture, Chapter 4.4 |
| **Says** | Eight tables. `users.org_id uuid No FK → orgs.id`, `projects.org_id uuid No FK → orgs.id`. |
| **Should say** | Nine. `orgs` is referenced by two NOT NULL foreign keys and has no section of its own. |
| **Authority** | Project owner's decision, Mission 6.3.1 |
| **Class** | Missing definition |
| **Status** | **Closed** — defined in migration `0002` |
| **Date** | 2026-08-18, Mission 6.3 |

Chapter 4.3 is titled *"How the **Nine** Core Tables Connect"*. Its ERD opens `orgs ──< users ──< task_assignments …`, and its relationship table carries two rows for it: `orgs → users 1:N` (*"BR-20 — an Admin belongs to exactly one org; scopes every query"*) and `orgs → projects 1:N`.

Chapter 4.2 §2 lists eight tables. Chapter 4.4 defines those same eight. Eight plus `orgs` is the nine Chapter 4.3 counts — so the omission is a gap in one chapter rather than a disagreement between two.

**It is not cosmetic.** Two `NOT NULL` foreign keys point at it, so the schema is not creatable without it, and BR-20 — the entire tenant-isolation rule — hangs off the column it keys.

Defined as the minimum the references require:

```sql
CREATE TABLE orgs (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

Nothing more was invented. There is no `slug`, no `settings`, no `plan` — Chapter 4.6 has no route that reads or writes an org, so **no function is granted any privilege on it** (0007). A column added now would be a guess about a shape no chapter states.

**This is the third gap of its class.** Mission 6.1 found the chunk-registration naming mismatch; 6.2 found V8.4 §1 naming four functions where ADR-015 gives six domains; this is a table two chapters use and a third never defines. The pattern is consistent: the volumes are internally consistent about *concepts* and inconsistent about *inventories*, and the inconsistency only surfaces when something tries to enumerate them.

---

### A-155 — Chapter 4.5's metadata shape has three fields Chapter 4.4 has no column for

| | |
|---|---|
| **Volume** | 4, Chapter 4.4 §7 against Chapter 4.5 §2 |
| **Says** | Ch 4.4's `chunk_metadata` has 17 columns, including `bitrate`. Ch 4.5 §2's canonical JSON carries `identity.device_id`, `capture.camera` and `capture.bitrate_kbps`. |
| **Should say** | `device_id` and `camera` need columns; `bitrate` is in kbps and only one chapter says so. |
| **Authority** | Project owner's decision, Mission 6.3.1 |
| **Class** | Missing definition / unit ambiguity |
| **Status** | **Closed** — migration `0004` |
| **Date** | 2026-08-18, Mission 6.3 |

Chapter 4.5 §2 is the wire format the mobile app already sends, and §4 makes every field except `collector_authored` *"written once, at creation"* — so these are not optional extras that can arrive later.

| Chapter 4.5 field | Chapter 4.4 | Resolution |
|---|---|---|
| `identity.device_id` | **no column** | Added, `text NOT NULL` |
| `capture.camera` (`"rear-wide"`) | **no column** | Added, `text NOT NULL` |
| `capture.bitrate_kbps` (`8000`) | `bitrate integer` | Renamed `bitrate_kbps` |
| `timing.duration_seconds` | no column | **Not added** — derivable from `captured_start_at`/`captured_end_at`, and a stored copy is a second source of truth that can disagree |
| `identity.session_id`/`project_id`/`task_id`/`collector_id` | no columns | **Not added** — reachable by joining `chunks → sessions → tasks → projects` |

**The rename is the one worth noticing.** Chapter 4.4 called it `bitrate` with no unit; Chapter 4.5 gives `bitrate_kbps: 8000`, which is the only place the unit appears anywhere. A column called `bitrate` holding kbps is a value whose meaning lives in a different document — the class of ambiguity that produces a number off by a factor of 1000 and no error.

---

### A-156 — The Data API client had no retry for a cluster that scales to zero

| | |
|---|---|
| **Record** | ADR-044 (Data API), ADR-043 (`min_capacity = 0`) |
| **Was** | `@vump/shared`'s client had no handling for `DatabaseResumingException`. |
| **Is** | Bounded retry on that condition only, shared by the handlers and the migration runner. |
| **Authority** | ADR-044 |
| **Class** | Defect in prior-mission code, found by this one |
| **Status** | **Closed** |
| **Date** | 2026-08-18, Mission 6.3 |

Mission 6.1 set `min_capacity = 0`, so the dev cluster auto-pauses after 300 seconds idle. Mission 6.2 shipped a Data API client with no handling for the exception that produces. **Mission 6.3 found it by hitting it on its very first probe of the live cluster:**

> `DatabaseResumingException: The Aurora DB instance db-S2RSCTAOWSVVCXIMAKAMGQKMTE is resuming after being auto-paused. Please wait a few seconds and try again.`

Nothing was broken by it, only because no handler issues a statement yet. It would have broken the moment one did.

### Why it is fixed in the shared client, not in the runner

The migration runner hit it first, and fixing it there would have left the same defect in seven Lambda functions. It belongs where every caller inherits it.

### Only one condition is retried

`DatabaseResumingException` and `DatabaseNotFoundException` — the latter because a resuming cluster briefly reports its database as absent. **Nothing else.** A `BadRequestException` or a constraint violation is a defect, and retrying converts a deterministic failure into an intermittent one, which is strictly harder to diagnose. Idempotency does not arise: the statement never reached the database, which is what the exception means.

Six attempts over roughly 30 seconds, then the error escapes. A caller may still time out on a cold cluster — that is the honest behaviour, and better than hanging for the full resume and returning nothing either way.

**Proved by the fix working live.** The first real migration run began against a paused cluster and logged three retries before succeeding:

```
{"level":"info","message":"cluster resuming, retrying","attempt":1,"delayMs":1000}
{"level":"info","message":"cluster resuming, retrying","attempt":2,"delayMs":2000}
{"level":"info","message":"cluster resuming, retrying","attempt":3,"delayMs":4000}
```

### A second defect found while fixing the first

`dataApiClient()` read the whole backend configuration to obtain a region, which quietly coupled every caller to the Lambda environment: the migration runner resolves its own target from AWS and has no `CHUNK_BUCKET`, yet could not construct a client without one. A client needs a region; requiring six unrelated variables to get it was the defect. It now takes the region from the SDK's own provider chain, which Lambda always populates.

---

### A-157 — BR-22 read literally forbids the write Chapter 4.5 §3 requires

| | |
|---|---|
| **Volume** | 4, Chapter 4.2 §3 against Chapter 4.5 §3 |
| **Says** | Ch 4.2 §3: a trigger "rejects any change to a system-generated column, allowing only the notes/tags column to change". Ch 4.5 §3: the backend sets `chunk_metadata.verified_at` after verifying the checksum. |
| **Should say** | No column may change except `notes_tags`, and `verified_at` may transition NULL → a value exactly once. |
| **Authority** | Mission 6.3, by the same reasoning A-150 used |
| **Class** | Contradiction resolved |
| **Status** | **Closed** — migration `0006` |
| **Date** | 2026-08-18, Mission 6.3 |

Read literally, "allowing only the notes/tags column to change" blocks `verified_at`, which Chapter 4.5 §3 requires the backend to set after insert — and without which no chunk can ever reach `complete`, because BR-21's gate depends on it. The two chapters cannot both be satisfied by the literal reading.

Resolved the way A-150 resolved the auth-verify contradiction: **narrowly, by what the rule protects.** BR-22 protects the *captured* record from being rewritten — NFR-META-03's *"zero exceptions, enforced server-side"*. `verified_at` is not part of the capture; it is the backend's own attestation about it, written once by the backend and never by a Collector.

So the trigger allows `notes_tags` freely, allows `verified_at` to go from NULL to a value once, and freezes the other fifteen columns. Verified behaviourally against the live database: changing `resolution` or `device_id` is refused, re-setting `verified_at` to a different time is refused, clearing it to NULL is refused, and `notes_tags` succeeds.

**One test-writing trap worth recording.** The first attempt to prove the `verified_at` rule appeared to fail. It did not: `now()` in PostgreSQL is the **transaction** timestamp and does not advance, so `SET verified_at = now()` inside the same transaction wrote the identical value and the trigger correctly saw no change. The schema was right and the test was wrong — an offset was needed to make it a real mutation.

---

### A-158 — The per-function GRANTs, against V8.4 §1 line by line

| | |
|---|---|
| **Volume** | 8, Chapter 8.4 §1 |
| **Class** | Specification implemented, with three tightenings and one widening |
| **Status** | Open — the widening is carried |
| **Date** | 2026-08-18, Mission 6.3 |

V8.4 §1 tabulates four functions; ADR-015 and A-143 give seven. Migration `0007` implements it, and every departure is below rather than in a commit message.

### Honoured exactly

| V8.4 §1 | Implemented as |
|---|---|
| `chunk-registration` → chunks, sessions | `vump_chunks_upload`: SELECT+INSERT chunks, SELECT sessions |
| `metadata-write` → chunk_metadata only | `vump_metadata`: SELECT+INSERT chunk_metadata |
| `projects-tasks` → projects, tasks, task_assignments | split across `vump_projects` and `vump_tasks` |
| `auth-verify` → users, read-only + A-150's INSERT | `vump_auth_verify`: SELECT+INSERT users |

### Three tightenings

1. **`projects-tasks` split in two.** Each function gets only its own resource, so `projects` cannot touch `tasks` and vice versa. Tighter than the chapter, which grants all three to one principal.
2. **`chunks-verify` holds no UPDATE on `chunks` beyond one column.** Completion goes through `complete_chunk()`, which is `SECURITY DEFINER`, so the role needs EXECUTE and not UPDATE. The queued → uploading → failed transitions are a **column-level** `GRANT UPDATE (status)`, so the role cannot alter `s3_object_key`, `checksum_sha256` or `file_size_bytes` even on a row it may transition. `verified_at` is granted the same way.
3. **`sessions` is not granted SELECT on `tasks`.** A foreign-key check does not require SELECT on the referenced table, so INSERT works without it.

### One widening, and Chapter 4.5 §5 is the reason

`vump_metadata` holds **SELECT on `chunks`**, which V8.4 §1's *"chunk_metadata only"* does not allow. Chapter 4.5 §5 requires it: `GET /v1/chunks/{id}/metadata` *"returns the same JSON shape above plus verified_at and **the chunk's current status**"*, and status lives on `chunks`. Read-only, one table, and recorded here rather than taken quietly.

### What no role holds

No DELETE anywhere. No UPDATE or DELETE on `audit_log` — Chapter 4.2 §2's *"append-only"*, enforced by withholding the grant rather than by a trigger, because a grant never issued cannot be bypassed. No privilege of any kind on `orgs`. And no role but `auth-verify` touches `users`, which is A-159's subject.

### Two gaps in Chapter 4.6 this surfaced

- **`audit_log` has no writer specified anywhere.** Chapter 4.2 §2 scopes it to *"Admin actions on Projects/Tasks/Assignments"*, which is what decided the INSERT grants for `projects` and `tasks` — but no chapter says so directly.
- **FR-META-07's collector-editable notes/tags has no route.** Chapter 4.5 §4 refers to *"any subsequent PATCH"* of metadata; Chapter 4.6 lists no PATCH for it. So `vump_metadata` holds no UPDATE, and the grant waits for the route.

---

### A-159 — `org_id` becomes a Firebase custom claim: decided, and deliberately not implemented

| | |
|---|---|
| **Volume** | 4, Chapter 4.7 §2 (extension), against Chapter 4.7 §1 step 4 and Volume 8, Chapter 8.4 §1 |
| **Says** | Ch 4.7 §1 step 3: every Lambda verifies the token. Step 4: it looks the caller up and attaches `role + org_id`. V8.4 §1: `chunk-registration` "cannot touch users/projects/tasks tables". |
| **Should say** | `org_id` travels in the token as a custom claim alongside `role`, so a function needs no `users` read to scope by org. |
| **Authority** | Project owner's decision, Mission 6.3.1 |
| **Class** | Target architecture decided, implementation deferred |
| **Status** | Open — blocked on Mission 6.5 |
| **Date** | 2026-08-18, Mission 6.3 |

Only `auth-verify` may read `users`. Every other function therefore cannot perform Chapter 4.7 §1 step 4's caller lookup, and cannot obtain the `org_id` that BR-20 requires it to scope every query by. The three tables are consistent with each other and jointly unimplementable.

Chapter 4.7 §2 already puts `role` in the token as a custom claim, for a reason that applies identically to `org_id`: *"a client can never claim its own role"*, and *"the backend can check it without an extra database round-trip on every request"*. Extending that to `org_id` resolves the conflict without weakening V8.4 §1 — no function gains a `users` grant.

**Not implemented, and the reason is the same trap Mission 6.2 avoided.** Writing a custom claim needs the Firebase Admin SDK acting on the project, which needs a service-account key — the operation ADR-036 line 35 identifies as *"the operation that needs privilege"*, as distinct from verification, which needs nothing. That key is Mission 6.5's, or arrives with `functions/`'s retirement (deferred item 10). Implementing it here would pull 6.5 forward.

So `resolveCaller` in `backend/packages/shared/src/handler.ts` **stays stubbed**, returning `undefined` for `userId` and `orgId` rather than inventing them. A handler that needs an org scope must fail rather than silently query a fabricated one — which is the property that makes this safe to leave open.

---

### A-160 — The backend is live, and per-function isolation is enforced at two layers rather than one

| | |
|---|---|
| **Record** | ADR-043 (Terraform), ADR-044 (Data API), ADR-016 (secrets), ADR-046 (migrations) |
| **Was** | 6.2's 24 resources and 6.3's 7 secret containers were both planned and neither applied. The seven database roles existed `NOLOGIN`, so Volume 8 Chapter 8.4 §1's per-function restrictions were written but not reachable. |
| **Is** | 31 resources applied, 7 IAM policies repointed, 7 credentials generated and stored. Every role authenticates, and only as itself. |
| **Authority** | Project owner's decision, Mission 6.3.2 |
| **Class** | Implementation applied to a live environment |
| **Status** | **Closed** for development. Staging and production do not exist |
| **Date** | 2026-08-18, Mission 6.3 |

`terraform apply` reported **31 added, 7 changed, 0 destroyed**, and the follow-up plan reported no changes. 6.2's resources and 6.3's applied in a single operation with no ordering conflict — expected rather than lucky, because the only edge between them is the IAM policy's reference to the secret ARNs, and Terraform's graph orders that edge itself.

### What the seven changes actually changed

Each function's role previously fell back to the **master** credential, because `lookup(var.db_credential_secret_arns, each.key, var.master_user_secret_arn)` had an empty map to look in. Applying the containers populated the map, so the change is every Lambda losing its access to the master secret and gaining access to exactly one credential. Verified with `iam simulate-principal-policy` for `vump-dev-chunks-upload`:

| Resource | Decision |
|---|---|
| its own `vump/dev/db-chunks-upload` | `allowed` |
| `vump/dev/db-chunks-verify` | `implicitDeny` |
| the Aurora master secret | `implicitDeny` |

### The isolation holds twice, and the layers fail differently

This is the property worth recording, because either layer alone would be weaker than it looks.

**IAM decides which credential a function can read.** **PostgreSQL decides what that credential may then do.** A defect in the first is contained by the second, and the reverse. Proved live, as the roles themselves rather than by reading the catalogue:

| Attempt, using `chunks-upload`'s own secret | Result |
|---|---|
| `SET ROLE` to each of the other six roles | `42501 permission denied to set role` — six times |
| `SET ROLE vump_admin` | `42501 permission denied to set role` |
| `SELECT FROM users` / `orgs` | `42501 permission denied for table` |
| `UPDATE` or `DELETE` on `chunks` | `42501 permission denied for table` |
| `INSERT INTO audit_log` | `42501 permission denied for table` |
| `CREATE TABLE` in `public` | `42501 permission denied for schema public` |

No `vump_` function role is a member of any other role. The only membership in the database is `vump_admin → rds_superuser`, which RDS creates for the master user and no migration touches.

### `complete_chunk()` is still exactly one role's to call

Attempted from all seven roles in turn. Six were refused at the permission layer; `chunks-verify` was refused **by the function body** — `BR-21: no such chunk` — which is a different failure and the one that proves the grant.

```
complete_chunk(p_chunk_id uuid) :: vump_admin=X/vump_admin , vump_chunks_verify=X/vump_admin
```

`has_function_privilege('public', 'complete_chunk(uuid)', 'EXECUTE')` is **false**, so migration `0008` holds after the apply.

### The deployed Lambdas do not contain the retry fix, and that is correct

Mission 6.3.1 answered the redeploy question with *"no redeploy is needed, because nothing is deployed."* True then, and no longer the whole answer now that seven functions are live. The precise position, established by downloading the deployed artifact rather than reasoning about it:

```
vump-dev-chunks-verify  index.mjs
  DatabaseResumingException   -> ABSENT
  withResumeRetry             -> ABSENT
  RDSDataClient               -> ABSENT
  verifyIdToken               -> PRESENT
```

**esbuild removed it, because nothing reaches it.** `@vump/shared` exports `withResumeRetry` and `execute`, but no handler calls either — `resolveCaller` is still stubbed (A-159) and no route issues a query. Unreachable code is eliminated, taking `@aws-sdk/client-rds-data` with it. `verifyIdToken` survives in the same bundle because `auth.ts` *is* reached, which is what makes this tree-shaking rather than a build defect.

So the retry fix costs nothing today and enters the artifact at the exact moment it becomes necessary: the first handler that calls `execute()` pulls `resume.ts` and the Data API client into its bundle **in the same build that adds the call**. That build is a redeploy of that function regardless, because the handler itself changed. **The fix therefore never creates a deployment of its own** — which is the property 6.3.1 was asked about, reached by a different route than the one stated then.

Worth recording because the plausible misreading is load-bearing: someone reading A-156 would reasonably assume the live functions carry the retry. They do not, and nothing is wrong.

### One earlier claim, restated more precisely

Mission 6.3.1 reported that PUBLIC holds no table grants. Re-checked without scoping it to a schema, PUBLIC holds **189** — 127 in `pg_catalog` and 62 in `information_schema`, all PostgreSQL's own. On schema `public` it holds **none**, which is what the original claim meant and what matters. PUBLIC does retain `USAGE` on the schema, and that is deliberate: `0001` revokes everything and then re-grants `USAGE` on the following line. `USAGE` permits name resolution and no object access, which the `CREATE TABLE` and `SELECT` refusals above demonstrate.

---

### A-161 — Nothing runs migrations except a person, and closing that is a credential decision, not a missing check

| | |
|---|---|
| **Record** | ADR-046 (*"Run deliberately, never by CI"*), `folder-structure.md` §1.3, A-148 and A-153 (the same *shape* of gap, resolved differently) |
| **Says** | ADR-046: a migration is applied by a developer running `npm run db:migrate`. |
| **Should say** | Undecided. Nothing detects a merged migration that was never applied, and the obvious fix has a cost the obvious fixes for A-148 and A-153 did not. |
| **Authority** | Deferred to a future mission by the project owner, Mission 6.3.2 |
| **Class** | Enforcement gap — **open**, and deliberately not closed here |
| **Status** | Open. Deferred item 11 |
| **Date** | 2026-08-18, Mission 6.3 |

A migration can be written, reviewed, merged and released without ever reaching a database. Nothing in CI, and nothing in the runner, notices. The schema and the repository can disagree indefinitely, and the first symptom is a handler failing on a column that exists in `git` and not in Postgres.

### Why this is filed apart from A-148 and A-153, which look identical

All three are the same sentence — *a standard was written and nothing executed it*. The resemblance stops at the remedy.

| | A-148 | A-153 | **A-161** |
|---|---|---|---|
| What was unenforced | `terraform fmt`/`validate`/`tflint` | `npm run verify` | applying a merged migration |
| What closing it required | a CI job | a CI job | **a decision about credentials** |
| New access granted to CI | none | none | **AWS write access to a live database** |
| Closed in | Mission 6.1.7 | Mission 6.2.2 | not closed |

A-148 and A-153 were reflexive: both closed by running, in CI, a command that already existed and that reads without writing. **Their remedy cost nothing but minutes.** A runner that migrates must hold a credential that can `CREATE`, `ALTER` and `DROP` on a live database — which is precisely what ADR-046 and `folder-structure.md` §1.3 refuse, in the same words used of `terraform apply`: *"a pipeline that can migrate a database is a pipeline that can drop one."*

So closing this one means overturning an accepted decision, and the question underneath it is not about migrations at all: **should CI ever hold AWS write credentials?** That governs deployment, `terraform apply` and the Firebase service-account key of Mission 6.5 alongside migrations, and answering it inside a schema mission would settle a platform-wide question as a side effect.

### What was deliberately not done here

Not a reflexive CI job, and not a partial one. Three options were visible and none is obviously right:

- **A read-only drift check** — CI compares `schema_migrations` against the files and fails when they differ. Needs only read access, so it is the cheapest, and it detects the problem without being able to fix it.
- **CI applies migrations** on merge to `develop`, with a scoped role. Fixes it, and grants CI the write access ADR-046 refuses.
- **A release checklist item** — no credential, no automation, and the failure mode ADR-036 already names: *"no CI check can detect that it has happened"*.

The first is likely the answer and is still not taken here, because a check that reads a production database from CI needs a principal that does not exist — deferred item 8's unscoped `faisal-admin` is the only one that does, and CI must never use it.

**A trace/decide for a future sub-mission.** Logged so the gap is tracked rather than closed badly.

---

### A-162 — One Firebase project became three, and what that did and did not fix

| | |
|---|---|
| **Volume** | 7, Chapter 7.7 §1 |
| **Says** | *"Three Firebase Projects, Not One … a bug in a dev build must never be able to send a real push notification to a production Collector's device or pollute production Crashlytics data."* |
| **Was** | One project, `vump-platform-f86af`, serving development, staging and production. Deferred item 3. |
| **Is** | `vump-platform-f86af` (development), `vump-staging`, `vump-prod`. |
| **Authority** | Project owner's decision, Mission 6.4.1 |
| **Class** | Specification implemented |
| **Status** | **Closed** — deferred item 3 |
| **Date** | 2026-08-18, Mission 6.4 |

### What exists, verified by reading each project rather than by the create command succeeding

| | `vump-platform-f86af` | `vump-staging` | `vump-prod` |
|---|---|---|---|
| Project number | 434336914712 | 1095961928374 | 277590490895 |
| Android package | `com.vump.humanarchive.dev` | `…​.staging` | `com.vump.humanarchive` |
| iOS bundle | same as Android, per project | | |
| Firestore | `(default)`, **asia-south1**, STANDARD | same | same |
| Delete protection | pre-existing, unchanged | **ENABLED** | **ENABLED** |
| Auth | **enabled**, Email/Password + Google | none | none |
| Billing | **Blaze** | none | none |
| `redeemInviteCode` | deployed | not deployed | not deployed |
| Security rules | released | released | released |

`asia-south1` matches the existing project and ADR-011's `ap-south-1`, and Chapter 7.7 §1's separation argument is what the split satisfies.

### The location was set wrongly first, and the recovery is worth recording

`firebase firestore:databases:create --location asia-south1` fails on a new project: the Firestore API is not enabled, and no read-only CLI command enables it. `firebase deploy --only firestore` **does** enable it — and creates the database as a side effect, in **`nam5`**, a US multi-region, without asking.

ADR-036 already warned about exactly this: *"The Firestore location is a one-time, irreversible choice … it should be made deliberately rather than accepted as a console default."* The deploy accepted a default on the mission's behalf.

Recovered by deleting each database and recreating it in `asia-south1`. That worked only because the databases were seconds old and empty; `(default)` is also reserved for roughly five minutes after deletion, so the recovery is not instant. **Had this been noticed after data existed, it would not have been recoverable at all** — which is the reason it is written down rather than quietly fixed.

### The development project was created, then deleted, and the original kept instead

**Planned (Mission 6.4):** create `vump-dev`, verify it, then retire `vump-platform-f86af`.

**Actual (Mission 6.4.2):** `vump-dev` was created, never used by any build that mattered, and **deleted**. `vump-platform-f86af` is the development environment.

The reversal is not a change of taste. Mission 6.4 finished with two blockers, both console-only: the three new projects had **no Authentication** — `accounts:signInWithPassword` returned `CONFIGURATION_NOT_FOUND`, meaning Auth had never been initialised — and **no billing**, so Cloud Functions could not deploy. Neither can be fixed from the Firebase CLI, which offers no command to initialise Auth and none to link a billing account.

`vump-platform-f86af` already had both, because it has been the working project since Mission 0.15. Repurposing it made the development environment complete immediately; keeping `vump-dev` would have meant performing two console actions to reach a state that already existed one project over.

What this cost, stated plainly:

- **The four pre-split accounts remain in the development environment.** They were going to be left behind in a retired project; they are now dev's user table. Each still carries `org_id: "vump-default"` — deferred item 12, unchanged and unfixed by this mission.
- **Development shares a project number with everything Missions 0.15 to 5 created**, including the deployed `redeemInviteCode` and the `org_invite_codes` collection. Nothing was migrated because nothing moved.
- **Chapter 7.7 §1's separation argument still holds**, which is the thing that actually mattered: a dev build cannot reach staging or production data, because those are separate projects. The chapter asks for three projects, not for three *new* ones.

The dev app identifiers were registered into `f86af` alongside the existing `com.example.mobile` app, so its `google-services.json` now lists two clients and the Gradle plugin selects by package name. `redeemInviteCode` was unaffected by that registration and remains deployed, verified after the fact.

**Nothing references `vump-dev` any more.** The alias, both config files, three ADRs, the changelog and the deferred-items log were swept. The `vump-dev-*` strings that remain are AWS resource names — `vump-dev-aurora`, `AWS_PROFILE=vump-dev` — which predate Firebase and are a genuine name collision rather than a leftover.

### No user data was migrated, and the reason is a schema incompatibility rather than a limitation

The brief for this mission stated that Firebase cannot move users between projects. **That is not correct, and it was worth checking:** `firebase auth:import` consumes exactly what `auth:export` emits — `localId`, `passwordHash`, `salt` and `customAttributes` — so UIDs, working passwords and custom claims all survive a move. The project's scrypt signer key is the one input not in the export, and it is readable from the console.

Migration was therefore available and was still declined, for a better reason. All four accounts in `vump-platform-f86af` carry `org_id: "vump-default"`, a literal string. Mission 6.3 defines `users.org_id uuid NOT NULL REFERENCES orgs(id)`. Importing them would have copied a value that cannot exist in the schema into three projects instead of one. See deferred item 12.

The four accounts are unverified, were created within 47 minutes of each other on 2026-08-13, and all hold `role: collector` — test accounts, on a product that has not shipped. All three environments are seeded fresh.

### Staging and production are deliberately incomplete

Both have Firestore in `asia-south1`, delete protection and released rules. Neither has Authentication or billing, so `redeemInviteCode` cannot deploy to them and the Artifact Registry cleanup policy cannot be applied.

**That is the correct state, not a gap.** ADR-014 provisions an environment when there is something to put in it; no release branch has been cut, nothing deploys to staging or production, and enabling Auth on a project no build points at would create user tables nobody uses. The work is one console visit each, at the moment it is first needed.

### The WIF-versus-key question was not touched, and following Volume 7 literally would have touched it

ADR-036 defers *"how the ported endpoint obtains claim-writing privilege without a long-lived key"*. This mission created **no service accounts, no keys and no Workload Identity Federation pools**, and nothing it provisioned presupposes either answer.

That required departing from Chapter 7.7 §3 — see A-164. Generating the per-environment service-account key that chapter asks for would have decided the deferred question as a side effect of a provisioning step, which is the one thing the scope boundary existed to prevent.

---

### A-163 — A-159 was stale the day it was written: the `org_id` claim is already live

| | |
|---|---|
| **Record** | A-159, ADR-036, Volume 4 Chapter 4.7 §2 |
| **Said** | *"`org_id` becomes a Firebase custom claim: decided, and deliberately not implemented … blocked on Mission 6.5."* |
| **Should say** | The claim is written today, by `redeemInviteCode`. What is unimplemented is the backend **reading** it, and a writer that survives `functions/`'s retirement. |
| **Authority** | Live state of `vump-platform-f86af`, Mission 6.4 |
| **Class** | Correction to a prior amendment |
| **Status** | **A-159 amended**, not withdrawn |
| **Date** | 2026-08-18, Mission 6.4 |

`functions/src/index.ts` has done this since Mission 2.9:

```ts
await getAuth().setCustomUserClaims(uid, { role: "collector", org_id: orgId });
```

All four live accounts carry `{"role":"collector","org_id":"vump-default"}`. A-159 asserted the claim was not implemented while four accounts in the project it describes were already carrying it.

**A-159's reasoning was right and its scope was wrong.** Writing a claim needs a credential *only when the writer runs outside Google*. Inside Cloud Functions the runtime authenticates through the metadata server, so the Firebase-side half needs nothing — and was built two missions before A-159 claimed it could not be.

What genuinely remains open is narrower than A-159 stated:

- `resolveCaller` in `backend/packages/shared/src/handler.ts` still returns `undefined` and trusts no claim. **Unchanged by this mission.**
- The writer is a Cloud Function ADR-036 marks temporary. When it retires, claim-writing moves to AWS and *then* needs the deferred credential decision.

The distinction matters because A-159 as written would have let a reader conclude that Mission 6.5 must build claim-writing from nothing. It must instead **port** a working implementation across a trust boundary, which is a different job with a different risk.

---

### A-164 — Chapter 7.7 §3 requires a service-account key for an operation that does not take one

| | |
|---|---|
| **Volume** | 7, Chapter 7.7 §3 |
| **Says** | *"A Firebase Admin SDK service account key is generated per environment for the backend's token-verification step (Volume 4, Chapter 4.7) — stored as an encrypted secret in the CI/CD system."* |
| **Should say** | Token verification needs no credential. A key is needed only for privileged operations such as **writing** a custom claim. |
| **Authority** | Measured in Mission 6.2 and unchanged since |
| **Class** | False premise in a specification |
| **Status** | Open — the chapter is wrong; no key was created |
| **Date** | 2026-08-18, Mission 6.4 |

`verifyIdToken` validates a signature against Google's **public** certificates. Mission 6.2 established this by running it rather than by reading about it, and shipped `@vump/shared`'s `verifyToken` with no credential of any kind. Chapter 4.7 §1 step 3 — which §3 cites as its justification — describes only verification.

**The cost of following it literally would have been three long-lived keys**, one per environment, each able to mint an `admin` claim on any organisation. ADR-036 describes exactly that credential as *"a silent, total authorization bypass"* if leaked, and it is the credential whose necessity ADR-036 deliberately left undecided.

So Chapter 7.7 §3 does not merely over-provision. **It would have silently resolved a question another record explicitly deferred**, by making the key exist before anyone decided it should — and the mission that created it would have had no reason to notice, because it was following the specification.

Recorded independently of Mission 6.4's outcome: the premise is wrong whether or not three projects exist, and it will mislead the next reader of Chapter 7.7 unless it is contradicted here.

**What is true**: verification needs nothing. Claim-writing needs privilege. Those are different operations on the same SDK, and ADR-036 line 35 already draws the line — Chapter 7.7 §3 draws it in the wrong place.

---

### A-165 — The Workload-Identity-versus-key question is answered by not asking it

| | |
|---|---|
| **Record** | ADR-036 (the deferral), Volume 4 Chapter 4.9 §3, ADR-016 |
| **Said** | ADR-036: the ported endpoint must obtain claim-writing privilege *"without a long-lived key — Workload Identity Federation from AWS to GCP is the shape that avoids one, and it is not free to set up."* |
| **Decides** | Neither. `redeemInviteCode` is **not ported**, so no credential is needed on either side. |
| **Authority** | Project owner's decision, Mission 6.5.1 |
| **Class** | Deferred decision resolved |
| **Status** | **Closed.** Reopens only if claim-writing moves to AWS |
| **Date** | 2026-08-18, Mission 6.5 |

Chapter 4.9 §3 defines the boundary between the two clouds and how much may cross it:

> *"The seam: **the only integration point between the two clouds is Chapter 4.7's token verification** — the AWS-side Lambda functions call the Firebase Admin SDK to verify a token, **and nothing else crosses the boundary.** This keeps the seam narrow and easy to reason about."*

Verification needs no credential — A-149 measured it, A-164 records that Chapter 7.7 §3 is wrong to require one. So the seam is credential-free **today**, and the only thing that would change that is moving claim-writing to AWS.

**Porting was the premise, not the goal.** ADR-036 wants `functions/` retired; deferred item 10 tracks it. But retiring it means the claim writer moves to a runtime outside Google, and *that* is what forces a credential to exist — either a WIF trust relationship or a long-lived key. The question ADR-036 deferred only has to be answered if the port happens.

Inside Cloud Functions the runtime authenticates through the metadata server. **No credential exists anywhere**, and A-163 established that this has been working since Mission 2.9. Leaving the writer where it is keeps Chapter 4.9 §3's seam exactly as narrow as the chapter specifies, and costs nothing to run.

### What it costs instead

**Deferred item 10 stays open, and that is now a decision rather than an omission.** ADR-036's *"retired at Mission 6/7"* is not honoured, and this record is why: retiring it would trade a credential-free seam for a credential, in order to delete a small function that works. The trade is available whenever someone wants it; nobody wanted it here.

### The recommendation if it is ever taken

**WIF, not a key.** A key is cheaper on the day it is created and more expensive every day after: ADR-036 calls it *"a silent, total authorization bypass"* if leaked, ADR-016 records that the seven database secrets already rotate manually with nothing scheduling them, and a disclosed key is permanent. WIF's cost is one-time and bounded — a workload identity pool, a provider, a trust policy and an external-account config.

### One provisioning artefact was removed

`vump-dev-auth-verify`'s IAM policy granted `secretsmanager:GetSecretValue` on `vump/{env}/firebase-service-account-*`, added in Mission 6.1 on the assumption that verification needs a key. No secret ever existed behind it, so it conferred nothing — but a permission shaped like the key answer is a quiet vote for it, and the question was still open. Removed in Mission 6.5.

---

### A-166 — Chapter 4.7 contradicts itself, and reading it as one component would have locked everyone out

| | |
|---|---|
| **Volume** | 4, Chapter 4.7 §1 step 4 against Chapter 4.7 §4 |
| **Says** | §1 step 4: the backend *"looks up **(or creates, on first login)** the matching users row"*. §4's pseudocode: `user = db.users.findByFirebaseUid(...)` / **`if user is null: reject(401)`**. |
| **Should say** | Both, of different components: the authorizer rejects; `POST /v1/auth/verify` creates. |
| **Authority** | Project owner's decision, Mission 6.5.2 |
| **Class** | Contradiction resolved |
| **Status** | **Closed** — ADR-048 |
| **Date** | 2026-08-18, Mission 6.5 |

Create-on-first-login and reject-on-missing are different behaviours for the same condition, and the chapter states both a page apart. Mission 6.5.1 decided **reject**, on the grounds that §4's pseudocode is the executable form.

**Applied uniformly, that decision would have bricked the platform**, and the trace found it before anything was built:

| | |
|---|---|
| Firebase accounts in dev | **4**, all carrying `role` and `org_id` claims |
| Aurora `users` rows | **0** |
| Anything that inserts into `users` | **nothing** — verified by grep across `backend/` |
| `redeemInviteCode` writing an Aurora row | **never** — it only touches Firebase Auth and Firestore |

With an authorizer in front of every route and reject-on-missing inside it, every one of those accounts is refused at every endpoint — **including `POST /v1/auth/verify`, whose stated job in Chapter 4.6 §2 is to exchange a token for session context.** The route that would create the row sits behind the check that requires the row. And it does not heal: a new signup produces a Firebase account with claims and still no Aurora row.

### The resolution is that the chapter is describing two things

§4's pseudocode is **the authorizer**, in front of fourteen routes. §1 step 4's *"or creates"* is **`POST /v1/auth/verify`**, the one exempt route. Neither sentence is wrong; the chapter predates the split and reads as contradictory because it assumes one component does both.

That also gives the exemption a reason beyond convenience: a first-time caller needs exactly one door that is not locked against them, and this is it.

### The exemption is enforced, not asserted

A second exemption would open an endpoint with nothing in front of it. A Terraform `check` asserts the exempt list is exactly `["POST /v1/auth/verify"]` and fails the plan otherwise. It fired on its first run — on a defect in the assertion itself rather than in the configuration: `sort()` returns `list(string)` and a literal `[...]` is a tuple, so HCL collection equality was false even though the contents matched.

Verified against live AWS rather than against the configuration that produced it: **15 routes, 14 `CUSTOM`, one `NONE`**, attached per-method.

---

### A-167 — Mission 6.3's per-function credentials were never in effect at runtime

| | |
|---|---|
| **Record** | A-158 (the GRANTs), A-160 (the two-layer isolation claim), ADR-016 |
| **Was** | Every Lambda's `DATABASE_CREDENTIALS_SECRET_ARN` named the **master** secret, while its IAM policy allowed only its own per-function secret. |
| **Is** | Each function's environment names its own credential. |
| **Class** | Defect in prior-mission work, found by the first real request |
| **Status** | **Closed** |
| **Date** | 2026-08-18, Mission 6.5 |

Mission 6.3 created seven database credentials, granted seven PostgreSQL roles, and repointed seven IAM policies. It did not repoint the seven Lambda **environments**, which still carried the master secret ARN from Mission 6.1.

The result was a configuration that could not work: IAM allowed exactly one secret, and the runtime was told to read a different one.

```
assumed-role/vump-dev-auth-verify is not authorized to perform:
secretsmanager:GetSecretValue on resource: …secret:rds!cluster-…
```

### Why nothing caught it

**No handler had ever issued a query.** Mission 6.3.2 verified isolation thoroughly and in two places — `simulate-principal-policy` for IAM, `SET ROLE` refusals for PostgreSQL — and both were correct. Neither exercises the value the Lambda actually reads at runtime, because that value is only consulted when a query runs, and the first one ran in Mission 6.5.

This is the same shape as A-153 and A-161: a property asserted in one layer and never executed end to end. A-160 recorded that per-function isolation was *"enforced twice"*, and that was true of IAM and of PostgreSQL — and beside the point, because the function could not authenticate at all. **The isolation was correct and unreachable.**

### What makes the fix load-bearing rather than cosmetic

The per-function map is threaded into the module and each function is given `var.db_credential_secret_arns[each.key]`. Naming any other secret now produces an `AccessDenied` on the first query rather than a privilege escalation — the IAM policy is what makes a wrong environment variable safe, and the environment variable is what makes the IAM policy reachable. Neither is sufficient alone, which is the point A-160 was making and could not yet demonstrate.

---

### A-168 — The AWS endpoint check is narrowed to S3, which is what it always meant

| | |
|---|---|
| **Record** | `.github/workflows/ci.yml`, `AWS credential isolation`; ADR-007; open item 47; A-075 |
| **Was** | `grep -rn 'amazonaws\.com' lib` — any AWS hostname in the shipped source failed the build. |
| **Is** | `grep -rnE 's3[.-][a-z0-9-]*\.amazonaws\.com' lib` — S3 hostnames only. |
| **Authority** | Project owner's decision, Mission 6.5.7 |
| **Class** | Check narrowed to its stated intent |
| **Status** | **Closed** |
| **Date** | 2026-08-18, Mission 6.5 |

The check states the rule it protects, in its own comment:

> *"This one looks for a hardcoded **endpoint**, which is a design defect rather than a disclosure: shipping code that names an **S3 host** has stopped waiting for the backend to presign a URL."*

The rule is about S3. The pattern was about `amazonaws.com`, and the two were the same set for as long as every AWS hostname the mobile app could name was an S3 bucket.

**Mission 6.3.2 ended that.** API Gateway's invoke URL is `{restApiId}.execute-api.{region}.amazonaws.com`, so the backend's own address is now under the same domain as the thing the rule forbids. Mission 6.5 put the real one in `NetworkConfig` and the check failed:

```
lib/core/network/network_config.dart:87:
  'https://32mar2hwsk.execute-api.ap-south-1.amazonaws.com/dev',
```

### Why this is a narrowing rather than an erosion

Three reasons, and the third is the one that settles it.

**The rule's own words exclude it.** Naming the backend's base URL is not *"stopping waiting for the backend to presign a URL"* — it is how the app reaches the endpoint that issues presigned URLs. The value that failed is the opposite of the thing the rule prohibits.

**ADR-007 already permits it, explicitly.** *"Base URLs"* sit in that record's **Permitted in source code** table, next to timeouts and retry counts, and `core/network/` is where ADR-007 assigns them. A CI check that fails an accepted ADR's named example is the check disagreeing with the architecture, and `docs/architecture/README.md` decides that case: where code and an accepted ADR disagree, the ADR is correct.

**This exact fault is already on file, twice.** Open item 47 records this check failing on four Mission 4.2 test fixtures whose assertions — `isNot(contains('X-Amz-Signature'))` — exist to *prove* credentials are stripped. A-075 records the confinement rule matching a comment that said a package was deliberately not imported. The check's own comment draws the conclusion: *"A check that fires on its own proof is the same fault A-075 recorded."* This is the third instance, and the first where the false positive is a value an ADR names as permitted.

### What was deliberately not touched

**The three credential-material checks are unchanged and still run over `lib test`** — the `AKIA|ASIA` pattern, the `aws_secret_access_key` family, and the repository-wide `git grep` for key material. The check's comment already explains why they are wider than this one:

> *"They look for credential **material** … and a real one of those committed under `test/` is every bit as disclosed as one under `lib/`. Narrowing them would trade a real guarantee for a green tick."*

That reasoning is untouched, because it is about disclosure and this one is about design. **Only the design rule moved, and only to the boundary it already declared.**

### Proven non-vacuous rather than assumed

The new pattern was run against a planted S3 URL and against the real configuration:

```
s3 host   lib/_probe.dart:1: 'https://vump-platform-dev.s3.ap-south-1.amazonaws.com/x'   → MATCHED
api gw    lib/core/network/network_config.dart:87 (execute-api…amazonaws.com)            → not matched
```

So it still fails on the thing it exists to catch, and no longer fails on the thing ADR-007 permits. The probe file was deleted after the check.

### The accepted tradeoff, stated rather than implied

**The endpoint check now catches S3-host patterns only.** `execute-api` hostnames — and every other `amazonaws.com` host that is not S3 — are **structurally invisible** to it. That is the cost of the narrowing and it is accepted, not overlooked.

It is acceptable because **this check was never the thing preventing credential leakage.** It bounds a *design* rule: do not hardcode an S3 host, because doing so means bypassing the presigned-URL flow. Disclosure is guarded by three separate checks, and the narrowing does not touch any of them:

| Check | Pattern | Scope | Changed? |
|---|---|---|---|
| Access key IDs | `\b(AKIA\|ASIA)[0-9A-Z]{16}\b` | `lib test` | **No** |
| Secret material | `aws_secret_access_key\|aws_access_key_id\|aws_session_token` | `lib test` | **No** |
| Repository-wide key scan | `\b(AKIA\|ASIA)[0-9A-Z]{16}\b` | whole repo, `git grep` | **No** |

So a credential committed anywhere still fails the build, exactly as before. What changed is that naming the backend's own base URL — a value ADR-007 lists as permitted — no longer does.

### The residue

`execute-api` hostnames are now invisible to this job. If someone hardcodes a *different* environment's API Gateway URL into `lib/`, nothing here objects — `NetworkConfig` is trusted to be the only place base URLs live, and that trust is not machine-checked. It is the same class of gap A-153 and A-161 record: a rule stated in one place and executed in another, or not at all. A custom domain would remove the ambiguity entirely by moving the backend off `amazonaws.com`, and is deferred for want of a registered domain.

---

### A-169 — A password cannot reach CloudWatch on this path, and that was tested rather than assumed

| | |
|---|---|
| **Record** | ADR-016, `backend/packages/migrate/src/bootstrap.ts` |
| **Claimed** | Mission 6.7's review: a failed `ALTER ROLE … PASSWORD` writes its plaintext to CloudWatch, because Aurora exports `postgresql` logs and `log_min_error_statement = error`. |
| **Found** | It does not. Statements issued through the RDS Data API do not surface their text into the Postgres error log. |
| **Class** | Reported finding, retracted on testing |
| **Status** | **Closed — no change made** |
| **Date** | 2026-08-18, Mission 6.7 |

### What was claimed, and why it was plausible

`bootstrap.ts` interpolates the generated password into a SQL literal, because a Postgres utility statement takes no bind parameters:

```sql
ALTER ROLE vump_auth_verify WITH LOGIN PASSWORD '<48 bytes base64url>'
```

Two facts were read from live configuration and are true: the cluster exports `postgresql` logs to CloudWatch (`EnabledCloudwatchLogsExports: ["postgresql"]`), and `log_min_error_statement` is at its default `error`, which in an ordinary Postgres session logs the **text** of any statement that errors. From those two, the conclusion followed that a failed bootstrap would write a plaintext password into a log group.

**The conclusion was never run before it was reported.**

### What testing found

A control and a protected case, each with a unique marker, then every event in the log group for the following hour pulled and grepped locally — rather than through a CloudWatch filter pattern, whose tokenisation had already produced one misleading result:

| Statement | Protection | In the log group |
|---|---|---|
| `ALTER ROLE no_such_role_ctl WITH LOGIN PASSWORD '<marker>'` | **none** | **absent** |
| `ALTER ROLE no_such_role_fix WITH LOGIN PASSWORD '<marker>'` | `SET LOCAL log_min_error_statement = 'panic'` | absent |
| `SELECT * FROM no_such_table_<marker>` | none | **absent** |
| `ALTER ROLE` or `PASSWORD` anywhere in 25 events | — | **absent** |

**The control is the result that matters.** With no protection at all, the failing statement's text does not appear — and neither does an ordinary failing `SELECT`. So statement text is not reaching the error log on this path at all, and the mechanism the finding depended on is not in play. The Data API is the only path `bootstrap.ts` uses.

No change was made. A `SET LOCAL` around the bootstrap would have been a real change carrying a false justification, which is worse than leaving it alone.

### The reasoning gap is real even though the channel is closed

**ADR-016 enumerates where a password may exist**: *"The value exists in that process, in PostgreSQL and in Secrets Manager, and nowhere else."* The design work behind it considered source control and Terraform state, and stopped. **Logs were never enumerated as a channel to check.**

That gap survives this retraction. This particular path is closed, by measurement — but it was closed by a property of the Data API that nobody chose, recorded nowhere, and could change. A future caller that reaches PostgreSQL some other way would not inherit it.

So the useful residue is not a fix but a question ADR-016 should have asked and did not: **where else can a secret be written, besides the places we decided to write it?**

### Recorded because retractions are evidence too

The finding was reported alongside tested ones, in the same voice, and a fix was authorised for it. `docs/development/security-finding-rubric.md` exists because of this: it requires the evidence class — tested, inferred, or reported — to be stated before the severity, so an inference cannot be read as an observation.

---

### A-170 — ADR-043's resource count was 66 and the account held 67

| | |
|---|---|
| **Record** | ADR-043, Implementation Status table |
| **Says** | *"All 66 managed resources live in `ap-south-1`"* — 35 from Mission 6.1, 31 from Mission 6.3.2 |
| **Should say** | 67 at the close of Mission 6. **79 after Mission 7.1**, which adds twelve |
| **Authority** | Observation, `terraform state list` against the live backend |
| **Class** | Stale documentation |
| **Status** | **Closed** by this entry. ADR-043's table is not edited in place |
| **Date** | 2026-08-18, Mission 7.1 |

ADR-043's table was written during Mission 6.3.2 and its arithmetic was correct then. Mission 6.6 added one resource — the API Gateway authorizer work behind ADR-048 — and the table was not revisited, so it understated the account by one for the rest of Mission 6. The gap register and the Mission 6 report both say 67 and are right.

**Recorded rather than corrected in place**, because the table is a dated statement of what was true at 6.3.2, and rewriting it would erase the fact that the count drifted unnoticed across four sub-missions. The count is now 79 and will drift again; the covering practice is `terraform state list`, not a number in prose.

---

### A-171 — The GitHub OIDC subject is the immutable-identifier form, not `repo:OWNER/REPO`

| | |
|---|---|
| **Record** | ADR-049 |
| **Assumed** | `repo:mdfaiskhan/vump-platform:environment:ci-plan`, the form in GitHub's and AWS's published examples |
| **Measured** | `repo:mdfaiskhan@76160659/vump-platform@1326922888:environment:ci-plan` |
| **Authority** | Measurement — a CI job printed its own token's claims |
| **Class** | Documented behaviour diverging from the live system |
| **Status** | **Closed.** The trust policies are built from the measured form |
| **Date** | 2026-08-18, Mission 7.1 |

The numbers are the owner's and the repository's GitHub database IDs, confirmed independently against the REST API (`owner.id` 76160659, `id` 1326922888).

**The failure mode is what makes this worth a record.** A trust policy written from documentation does not warn, degrade, or name the offending condition. It returns `Not authorized to perform sts:AssumeRoleWithWebIdentity` — the same message produced by a wrong audience, a wrong repository, a wrong workflow ref, or a provider that does not exist. Mission 7.1 spent a full CI round-trip on it and closed it only by adding a temporary step that decoded the token and printed its claims. **That step is the technique worth keeping, not the string**: any future OIDC condition should be written against measured claims rather than documented ones.

The form is a security improvement rather than a quirk. Renaming the account or the repository does not free the old name for someone else to register and inherit this trust. The corollary is recorded in ADR-049: if either is ever deleted and recreated, federation breaks, and breaking is the correct outcome.


### Where the format comes from — added 2026-08-18, Mission 7.1 Part 2d

The observation above was challenged on review, correctly: it contradicts the subject format in GitHub's and AWS's published examples, and an unexplained observation is a weak basis for a trust policy. The mechanism is now identified and is not a quirk of this account.

**GitHub changed the default.** Immutable subject claims embed the owner's and the repository's numeric IDs in the `repo:` segment, in the form `repo:OWNER@OWNER-ID/REPO@REPO-ID:…`. They are the default for **every repository created after 2026-07-15**, and pre-existing repositories are unaffected unless they opt in via `use_immutable_subject`. `mdfaiskhan/vump-platform` was created **2026-08-07**, three weeks after the cutoff, so it received the new default and never had the old one.

GitHub's own API reports the effective prefix for this repository:

```
GET /repos/mdfaiskhan/vump-platform/actions/oidc/customization/sub
{
  "use_default": true,
  "use_immutable_subject": false,
  "sub_claim_prefix": "repo:mdfaiskhan@76160659/vump-platform@1326922888"
}
```

**`use_default: true` is the load-bearing field.** Nothing in this account customised the subject; this is the platform default, and the `sub_claim_prefix` field is GitHub stating what it will mint. Note that `use_immutable_subject: false` reads as a contradiction and is not one — that flag is the opt-in switch for repositories created *before* the cutoff, and it stays `false` on a repository that gets the format by default. Reading it alone would give exactly the wrong answer.

**Three independent lines of evidence, recorded because one was not enough:**

1. **The token itself.** Run 32123773224 printed `sub = 'repo:mdfaiskhan@76160659/vump-platform@1326922888:environment:ci-plan'`, 69 bytes, SHA-256 `ddb6af00…`, byte-identical to the live trust policy's `StringEquals` value.
2. **A controlled experiment.** The trust policy was first written with the documented `repo:OWNER/REPO:…` form and the assumption was **denied** (run 32122955317). Commit `790cb75` changed the subject string and nothing else, and the next run **succeeded**. Had the documented form been correct, that change would have broken federation rather than fixed it.
3. **First-party configuration**, quoted above, plus the creation date against the published cutoff.

**The policy was briefly wrong, and it failed closed.** This was not a comment-only error. Commit `11d73b9` applied the documented format, the run was refused, and `790cb75` corrected it — all before merge, and the refusal was visible rather than silent. What lagged longest was the *comment* in `ci.yml`, which still described the documented form after the policy had been corrected; it was fixed last. The ordering is worth recording: the executable artefact was right before the prose was, which is the safer of the two ways to be inconsistent.

Sources: GitHub Changelog, *Immutable subject claims for GitHub Actions OIDC tokens* (2026-04-23); GitHub Docs, *OpenID Connect reference*.

---

### A-172 — Gap 8 does not close with a read-only CI principal; the proofs write

| | |
|---|---|
| **Record** | `docs/development/mission-6-gap-register.md`; `mission-6-report.txt` §11 |
| **Says** | *"**8** is open because the check needs live AWS and CI has none. A read-only credential would close it."* And §11: *"A read-only principal closes gap 8 … and gap 16"* |
| **Should say** | A read-only principal closes gap 16 only. Gap 8 needs a principal that can write to the database |
| **Authority** | Observation — the Mission 6 report's own §12 |
| **Class** | Mischaracterisation in a hand-off record |
| **Status** | **Closed** by this entry and by ADR-049's two-role split |
| **Date** | 2026-08-18, Mission 7.1 |

The Mission 6 report describes the proofs in its own measurement table as *"committed transactions against the live cluster, seeded and then deleted, counts verified to zero"*. Those are writes. The register's summary and the report's ranked hand-off both compressed "a CI credential" into "a **read-only** CI credential", and the compression was carried forward into Mission 7.1's Part 1 trace before it was caught.

**The consequence was structural, not cosmetic.** Sized from the register, gap 17 would have produced one read-only role, and gap 8 would have remained open with its reason misfiled as "not built yet" rather than "wrong capability". ADR-049 provisions two roles precisely because the capabilities differ: `plan-reader` reads, `db-prover` writes, and merging them would give every pull-request job the ability to write to the database.

Neither source record is rewritten. The register is a dated hand-off and the report is a dated artefact; this entry is the correction, and the gap register's row for item 8 now points at it.

---

### A-173 — No database role can delete, so the behavioural proofs cannot tear down

| | |
|---|---|
| **Record** | Migration `0007_function_roles.sql`; gap register item 8; ADR-049 |
| **Says** | Gap 8 closes when CI can run the BR-08/11/21/22 proofs |
| **Should say** | The credential now exists. The proofs still cannot run in CI, for a reason that is not about credentials |
| **Authority** | Observation — `0007` grants no `DELETE` to any of the seven roles |
| **Class** | Blocked commitment, cause identified |
| **Status** | **Open.** No owning mission |
| **Date** | 2026-08-18, Mission 7.1 |

Migration `0007` grants `SELECT`, `INSERT`, `UPDATE` and one `EXECUTE` across the seven per-function roles. It grants `DELETE` to none of them. The uncommitted scratchpad script therefore performed its teardown as the **master user**, and ADR-049 denies `db-prover` the master credential explicitly — on correctness grounds, because a proof run as master bypasses every `GRANT` it is meant to be testing and would pass while proving nothing.

So the proofs can seed and assert, and cannot clean up. Three shapes are available and none was taken in Mission 7.1, because each is a database-design decision rather than a credential one:

- **A dedicated `vump_ci_proof` role** with `DELETE` on the test tables. Clean, and it is a new migration — ADR-046 territory.
- **Rollback-only proofs.** Complicated by each per-function secret being a separate Data API session, so one transaction cannot span the roles a cross-role proof needs.
- **A disposable database per run.** Correct and slow, and the cluster auto-pauses at `MinCapacity 0` (A-156).

**Gap 8 therefore closes to "the credential exists, the proofs are not running in CI", and it is logged exactly that way rather than rounded up.** The strongest evidence Mission 6 produced is still the least repeatable, and the reason has moved rather than gone.

---

### A-174 — `job_workflow_ref` pinned to a branch rejects every pull request, not only those editing the workflow

| | |
|---|---|
| **Record** | ADR-049; Mission 7.1 Part 2a |
| **Said** | Part 2a: pinning `job_workflow_ref` to `@refs/heads/develop` means *"a PR that modifies `ci.yml` itself cannot assume the role"* |
| **Should say** | It means **no pull request at all** can assume the role |
| **Authority** | Measurement — `job_workflow_ref` on PR #11 was `…/ci.yml@refs/pull/11/merge` |
| **Class** | Self-correction of a Mission 7.1 record |
| **Status** | **Closed.** The condition permits `refs/pull/*/merge` |
| **Date** | 2026-08-18, Mission 7.1 |

A `pull_request` run does not use the workflow file from the base branch — it uses the file at the PR's **merge** commit, so its `job_workflow_ref` sits in `refs/pull/<n>/merge` for every PR, whether or not the PR touches `ci.yml`. Pinning to `refs/heads/develop` alone would therefore have rejected plan-on-PRs entirely, which is the whole of gap 16.

**Recorded rather than quietly fixed**, because the wrong version was stated to the project owner as a deliberate, accepted trade-off, and was explicitly asked to be carried into ADR-049's Consequences. Carrying it would have documented a constraint that does not exist, and hidden the one that does.

The real trade is the inverse and is now in ADR-049: because `refs/pull/*/merge` is trusted, **a pull request may edit `ci.yml` and assume `plan-reader` in the same run**. Someone with write access can exercise the role from an unmerged branch. That is acceptable for a read-only role explicitly denied the evidentiary buckets, and it should be re-argued for `db-prover`, which writes, when its CI job is built.

---

### A-175 — The `ref`-shape role assumption is unproven until this merges to `develop`

| | |
|---|---|
| **Record** | ADR-049, Implementation Status |
| **Says** | The environment-scoped subject is identical across trigger shapes |
| **Verified** | The **claim** is measured on both shapes. The **assumption** succeeded on `pull_request` only |
| **Authority** | Two live CI runs, 32123773224 and 32124059624 |
| **Class** | Verification gap, time-bounded |
| **Status** | **Closed 2026-08-18.** Run 32128742979, the first push to `develop` after PR #11 merged, assumed the role and planned successfully |
| **Date** | 2026-08-18, Mission 7.1 |

`ci.yml` on `develop` has no OIDC job, so a `workflow_dispatch` against `develop` runs the old file and proves nothing. Dispatching against the mission branch instead produced:

| | `pull_request` (run 32123773224) | `workflow_dispatch` (run 32124059624) |
|---|---|---|
| `sub` | `repo:mdfaiskhan@76160659/vump-platform@1326922888:environment:ci-plan` | **identical** |
| `event_name` | `pull_request` | `workflow_dispatch` |
| `ref` | `refs/pull/11/merge` | `refs/heads/mission/7.1-credential-mechanisms` |
| `job_workflow_ref` | `…/ci.yml@refs/pull/11/merge` | `…/ci.yml@refs/heads/mission/7.1-…` |
| Assumption | **succeeded** | **denied** |

**Both results are the design working.** The subject is byte-identical across two different triggers, which is the central claim of the environment-scoped design and is now measured rather than argued. The denial is a negative control: the dispatch ran from a branch matching neither permitted `job_workflow_ref` value, and was refused — so that condition is not vacuous.

What remains unproven is narrow and should not be rounded up: that a `ref`-form run **from `develop`** assumes successfully. It cannot be tested before the merge that puts the job on `develop`. The first post-merge run on `develop` is that test, and it is the thing to watch rather than assume.

**Closed by the merge, as designed.** PR #11 squash-merged as `6623e69`, and the resulting push to `develop` ran with `job_workflow_ref = …/ci.yml@refs/heads/develop` — the first permitted value — and assumed `vump-dev-ci-plan-reader` successfully. Run **32128742979**: `Assume the plan-reader role`, `terraform plan (dev)` and `Fail on any failed check block` all green.

Both trigger shapes are therefore exercised end-to-end against live AWS: `pull_request` (run 32123773224) and `ref` (run 32128742979), with a byte-identical `sub` and two different `job_workflow_ref` values, both permitted. The denial recorded above from `refs/heads/mission/7.1-…` remains the negative control.

**One thing not to read off this run.** It reports 12 passed and **1 skipped** — `Commit convention` is gated on `pull_request` and does not run on a push. That is the same distinction the Mission 6 report insisted on: a skipped job is not a passed job. The full 13 ran on PR #11's final run, 32124775073.

---

### A-176 — `faisal-dev`'s first access key was exposed, and was killed before it was ever used

| | |
|---|---|
| **Record** | ADR-049 D-2; `docs/development/secrets-management.md` §"If a secret is committed" |
| **Event** | The first access key created for `faisal-dev` (id ending `LXBX`) was disclosed in an unrelated chat transcript shortly after creation |
| **Response** | Deactivated and **deleted**, and a replacement generated. Both actions by the project owner, directly against AWS |
| **Authority** | Project owner, Mission 7.1 Part 3 |
| **Class** | Credential incident, contained |
| **Status** | **Closed** |
| **Date** | 2026-08-18, Mission 7.1 |

**The response followed the order this project already wrote down.** `secrets-management.md` says *"Rotate first. Always"*, and ADR-016 says the same at more length: *"The first action is always to rotate the credential, not to rewrite history… A team that reverses that order spends its first hour on the part that does not stop the bleeding."* The key was killed first and the transcript dealt with afterwards, which is the correct order and worth recording as the first time the rule was actually exercised rather than merely stated.

### What was verified, and how

| Claim | Evidence |
|---|---|
| The exposed key is **deleted**, not merely deactivated | `aws iam list-access-keys --user-name faisal-dev` returns exactly one key, `AKIA…RNOF` (created 2026-08-18T10:13:08Z, Active). `AKIA…LXBX` does not appear in any state |
| The exposed key was **never used** | `aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<the exposed key id>` returns **0 events** |
| That zero is not a vacuous zero | The identical query against the replacement key returns **6 `AssumeRole` events** — the MFA verification calls. The query demonstrably detects usage when usage exists |

**The blast radius was structurally small before any of that mattered, and this is the part worth carrying forward.** Under ADR-049's D-2 the key grants *nothing on its own*: `faisal-dev` holds `sts:AssumeRole` and no other permission, and both roles it may assume require `aws:MultiFactorAuthPresent`. A holder of the disclosed key, without the `2_dev_faisal` MFA device, could not read, write or describe anything — the same `AccessDenied` the negative half of the human-path proof produced deliberately.

**A key disclosed under the pre-ADR-049 design would have been a different event.** The credential it replaces, `faisal-admin`'s, carries `AdministratorAccess` directly. This incident is the argument for D-2 arriving as an unplanned live test rather than as a paragraph in the Alternatives Considered.

### Why the key ids are truncated here

CI's secret scan matches `(AKIA|ASIA)[0-9A-Z]{16}`, and the first draft of this amendment failed it — correctly, by the scanner's own terms. An access key **id** is not a secret under ADR-016's capability test; it grants nothing without the secret half. But the scanner cannot make that distinction, and adding an exception so a document could carry the pattern would trade a working control for a nicety. The ids are truncated to their last four characters, which is enough to identify them against `aws iam list-access-keys`, and the full values stay where they belong: in AWS.

Recorded because this is the second time in Mission 7.1 that a check proved non-vacuous by failing on this mission's own work — the `pull_request_target` guard was the first.

### The one caveat, stated rather than smoothed over

**CloudTrail Event history is not a durable audit trail.** A-019 records that no trail is configured, so the 90-day Event history is all there is: not exportable, not retained beyond the window, and not the account-wide trail Volume 8 Chapter 8.4 §4 requires. The finding is sound here only because the key's entire life was roughly one hour on the day of the query, far inside the window. **The same investigation ninety-one days later would return zero events for a key that had been used every day**, and nothing would distinguish the two answers. A-019 is now a gap with a worked example attached.

---

### A-177 — Gap 11 is fixed: one cold start, one token exchange

| | |
|---|---|
| **Record** | `docs/development/mission-6-gap-register.md` item 11; ADR-048 |
| **Said** | *"`POST /v1/auth/verify` fires twice per app launch… Harmless (idempotent, `ON CONFLICT DO NOTHING`) but doubled"* |
| **Now** | Once. `AuthNotifier.build` resolves the first session from its single `sessionChanges` subscription and no longer calls `restoreSession` |
| **Authority** | Project owner, Mission 7.2 |
| **Class** | Defect fixed |
| **Status** | **Closed**, proven on device |
| **Date** | 2026-08-18, Mission 7.2 |

`build` did two things that both reached `AuthRepositoryImpl._toUser`: it subscribed to `sessionChanges`, and it called `restoreSession()`. Each performed the Chapter 4.7 §1 step 2 exchange, concurrently.

**The second call bought nothing.** The comment that justified it claimed awaiting the stream *"would stall `build()` for as long as the restore takes"* — but both wait on the same exchange, and the stream already yields `Session.unknown()` first, so the UI has its `AsyncLoading` either way. The restore was a duplicate of work already in flight.

The first session is now resolved through the existing subscription rather than a second read of `sessionChanges`. That distinction is load-bearing: the getter is a stream that subscribes to Firebase and maps every event through `_toUser`, so reading it twice would have reintroduced the duplicate in a new place.

### Measured, before and after, on CPH2707

Pre-fix build, one cold start:

```
20:07:47.818  ✗ 502 POST …/v1/auth/verify (15876ms)
20:07:47.819  ✗ 502 POST …/v1/auth/verify (15889ms)
```

Post-fix build, four cold starts:

| Run | `am start -W` TotalTime | `/auth/verify` calls | Exchange |
|---|---|---|---|
| 0 | 2516ms | **1** | 513ms |
| 1 | 2007ms | **1** | 346ms |
| 2 | 1988ms | **1** | 325ms |
| 3 | 2699ms | **1** | 669ms |

### The splash is not slower, and the reason is in the old timestamps

The two pre-fix calls were **one millisecond apart** — concurrent, never serialised. Removing one therefore returns duplicated server work and a duplicated `users` upsert, **not wall-clock time**. Cold start measures 1988–2699ms post-fix, and the OS splash covers it.

**Stated as a limitation rather than smoothed over: there is no clean pre-fix `TotalTime` baseline.** The only pre-fix launch captured hit the 502 path and took 15.9 seconds, which is not comparable. Building a pre-fix APK purely for an A/B was considered and declined by the project owner: the concurrency argument stands on the timestamps above, and the post-fix numbers are measured. So "no slower" is *reasoned from evidence*, not *measured against a baseline*, and a future reader should not cite it as the latter.

### What made it survivable for three missions

Nothing could see it. `grep -rn "auth/verify" test/` returned **nothing** before this mission — every test asserted what the session *was* and none asserted what it *cost*. It shipped in 6.5, passed 6.6's audit and 6.7's security review. `test/features/auth/application/auth_cold_start_exchange_test.dart` now counts, and was proven non-vacuous by reinstating the defect (`Expected: <0> Actual: <1>`) before reverting.

**Eight test fakes had to be migrated**, and the shape of that work is worth recording. Each had a silent `sessionChanges`, which under the new contract leaves `build` awaiting forever — so they **timed out rather than failed**, surfacing one full-suite run at a time. A fake that models a stream nothing emits on is not a cheap fake; it is a fake of a repository that does not exist.

---

### A-178 — A transient backend failure no longer destroys the session, and gap 9 has a confirmed consequence

| | |
|---|---|
| **Record** | ADR-035; gap register item 9; `AuthNotifier._discardUnusableSession` |
| **Was** | Any error on the session stream signed the user out |
| **Is** | Only a genuinely unusable identity does |
| **Authority** | Project owner, Mission 7.2 |
| **Class** | Defect fixed — pre-existing, not introduced by A-177 |
| **Status** | **Closed** |
| **Date** | 2026-08-18, Mission 7.2 |

Observed on CPH2707 before any of this mission's changes: two 502s from `POST /v1/auth/verify` at ~15.9s each, after which the app was sitting on the Sign in screen. `_toUser` threw a `NetworkException`, that reached the stream's `onError`, and `_discardUnusableSession()` called `signOut()`.

**A working credential was destroyed because a server was briefly unavailable.** Recovery then required the person's password rather than a working backend — the one response that makes a transient failure worse.

### The distinction is real, and rests on something the platform guarantees

`_discardUnusableSession` now fires only for `AuthenticationException` carrying `authUnauthenticated` or `authAccountDisabled`.

The obvious worry is that this masks a genuinely dead session — a revoked refresh token, a deleted account. **It cannot, because those never reach this path.** Firebase emits a *null user* for a revocation, identically to a deliberate sign-out; `AuthRepositoryImpl` says so in its own comment, and `_classify` turns it into `unauthenticated` or `expired`. Nothing arriving as a stream *error* is a revocation.

What did arrive there:

| Error | Meaning | Discard? |
|---|---|---|
| `AuthenticationException(authUnauthenticated)` | Signs in, no usable `role` claim, or no org. Returns every cold start | **Yes** — the case the discard was written for |
| `AuthenticationException(authAccountDisabled)` | Permanent | **Yes** |
| `NetworkException(*)` | 502, timeout, no connectivity | **No** |
| `AuthenticationException(unknown)` | Firebase failed to initialise (ADR-017) | **No** — a local fault; `signOut` could not succeed either |

Proven in both directions, because a fix that never signs anyone out would be no fix: *"a 502 during startup does not sign the user out"* and *"an unprovisioned account IS still signed out"*.

**The state a transient error produces is deliberately unchanged.** `AuthGuard.redirect` treats a null `AuthState` as "not yet known" and returns no redirect, so surfacing `AsyncError` at cold start would leave the person on `/`, which renders nothing. Not signing out is the half that matters: the Firebase credential survives, so the next launch signs them straight back in.

### Gap 9 is no longer hypothetical

Item 9 reads *"the first request after idle **can** exceed the Lambda's 15-second timeout while the resume ladder runs to ~30 seconds"* — a possibility, filed under availability.

It happened, ~~twice~~ **three times** (see the correction below), in one launch: **15876ms and 15889ms against a 15000ms timeout**, because Aurora was resuming from `MinCapacity 0`. And until this amendment its consequence was not slowness but **an ended session**.

Fixing the resume is out of this sub-mission's scope. What changes here is the record: gap 9 is **confirmed, with a reproduced user-facing consequence**, not a risk awaiting evidence. Its severity is 7.x's to reassess.

### Correction — a third observation existed and was not written down

*(Added 2026-08-18, Mission 7.3 Part 4, on the project owner's report.)*

A third occurrence was observed during Mission 7.2's F5 self-heal verification and **never entered any record**:

| Time | Duration | Context |
|---|---|---|
| 20:07:47.818 | 15876ms | Pre-fix cold start, 502 |
| 20:07:47.819 | 15889ms | Pre-fix cold start, 502 — concurrent with the above |
| **21:02:37** | **15428ms** | **F5 self-heal. Observed at 7.2, recorded nowhere until now** |

**It changes no conclusion and that is exactly why it went missing.** 15428ms is *below* both figures already recorded, so the worst case stays 15889ms, and Mission 7.3's timeout derivation — which is driven by AWS's own documented resume figures rather than by ours — is unaffected either way. A number that moves nothing is the easiest kind to not bother writing down.

**What it is evidence of is not what the other two are evidence of.** The first two were pre-fix and ended the session; this one is post-fix and *did not* — the app self-healed, which is this amendment's own fix working on an occurrence nobody logged. So the record was missing a data point for gap 9 **and** a demonstration of A-178.

**Three occurrences, not two, also changes how the frequency reads.** Two in one launch one millisecond apart is a single event observed twice. A third, 55 minutes later in a separate launch, makes it recurrent rather than a one-off — which is the shape gap 9's severity reassessment turns on.

Filed as a correction rather than an edit to the paragraph above, per this register's rule that history is appended to. The strikethrough marks where the count changed; the original figures are untouched.

---

### A-179 — `VumpApi` is required, and the stale-claim fallback is gone

| | |
|---|---|
| **Record** | ADR-048; ADR-016; `AuthRepositoryImpl.backend` |
| **Was** | `final VumpApi? backend` — when null, `org_id` came from the Firebase claim |
| **Is** | `final VumpApi backend`, required. No claim fallback exists |
| **Authority** | Project owner, Mission 7.2 |
| **Class** | Latent divergence removed |
| **Status** | **Closed** |
| **Date** | 2026-08-18, Mission 7.2 |

ADR-048 made `POST /v1/auth/verify` authoritative for `org_id`, retiring the claim because *"a claim written once goes stale the moment an account moves organisation"*. The retired path stayed in the code as the null branch, documented as "the test path".

**It was unreachable by convention, not by construction** — every `main.dart` construction supplied a backend. That is the same shape as Mission 6.5's `authTokenSourceProvider` defect: correct in isolation, wrong at the composition root, and invisible until something reaches it. A type is a guarantee; a convention has to be got right again by every future call site.

Tests now pass `FakeVumpApi` rather than omitting the dependency, which also makes the exchange **observable** — that fake is what A-177's regression guard counts. The three tests that asserted rejection of a missing/empty/non-string `org_id` **claim** were rewritten to assert rejection of an org the **backend** does not return, because that is where the decision now lives, and one was added asserting a valid-looking claim is ignored when the table disagrees.

`_orgIdClaim` and the `claims` parameter of `_resolveOrgId` were deleted rather than left unused.

---

### A-180 — A sign-in performs one token exchange, not two

| | |
|---|---|
| **Record** | A-177; gap register item 11 |
| **Says** | Item 11 describes the duplicate as *"twice per app launch"* |
| **Should say** | Cold start was one instance. **Sign-in was a second, with a different cause**, and item 11's wording does not cover it |
| **Authority** | Measurement on CPH2707, Mission 7.2 |
| **Class** | Defect fixed |
| **Status** | **Closed** |
| **Date** | 2026-08-18, Mission 7.2 |

Captured on the **A-177-fixed** build, during a real sign-in:

```
20:49:48.523  → POST /auth/verify
20:49:48.527  → POST /auth/verify
20:49:48.893  ← 200 (366ms)
20:49:49.408  ← 200 (884ms)
```

Cold start was down to one, and sign-in was still two. Different cause: `signInWithEmailPassword` calls `_toUser` to satisfy its `Future<User>` return type, then Firebase emits that same user on `authStateChanges` and `sessionChanges` calls `_toUser` again.

### The smaller fix was the wrong one

The returned `User` is genuinely unused — `AuthNotifier._attempt` takes a `Future<void> Function()` and discards it — so deleting the sign-in call looks like the minimal answer.

**It would have moved a user-visible error off the screen.** `_toUser` also *validates*, and on the sign-in path a thrown `AuthenticationException` becomes a `Failure` that puts *"this account is not provisioned"* on the login form. Move that to the stream and it arrives as `authUnauthenticated`, which **A-178 correctly treats as an unusable session and signs out — silently, with no message**. The two fixes interact, and the interaction only appears if both are held in view at once.

So the exchange is **coalesced** instead: overlapping resolutions share one in-flight request, the same single-flight `AuthInterceptor._refreshInFlight` already uses for concurrent 401s. Every semantic is preserved and only the duplicate request is removed.

**It shares the in-flight future and never a completed result**, so there is no cache to go stale — once the request settles the field clears and the next resolution is a fresh call. A test asserts exactly that (*"a later resolution is a fresh call, not a cached one"*), because a single-flight that quietly became a cache would hide an org change forever. Non-vacuity was proven by removing the coalescing and watching the guard fail: `Expected: <1> Actual: <2>`.

---

### A-181 — A re-assignment is a resurrection, because the composite primary key leaves no other option

| | |
|---|---|
| **Record** | `mobile/lib/features/projects_tasks/domain/repositories/project_task_admin_repository.dart`, `unassignCollector`'s doc comment; migration `0003_projects_tasks.sql` |
| **Says** | *"a later re-assignment is a new row rather than a resurrection, and neither call needs to know which"* |
| **Should say** | A second row is impossible. `task_assignments` is `PRIMARY KEY (task_id, user_id)`, so a re-assignment can only be an `UPDATE` that clears `removed_at` |
| **Authority** | Observation — the schema, read against the comment |
| **Class** | Documentation correction. **Backend-visible only** |
| **Status** | **Open** — the comment stands until a mission is editing that file for another reason |
| **Date** | 2026-08-18, Mission 7.3 Part 1, recorded Part 4 |

Found while tracing `POST /v1/tasks/{taskId}/assignments` for Mission 7.3, not by reading the mobile code for its own sake.

The comment's premise is Chapter 4.4 §4's soft removal, and that half is right: FR-ADM-04 keeps the row *"for audit rather than hard-deleted"*, `removed_at` exists, and `0007` grants `UPDATE` on `task_assignments` for exactly that. The inference from it is wrong. Migration `0003` closes with:

```sql
PRIMARY KEY (task_id, user_id)
```

One row per (task, collector) pair, forever. Assigning a Collector who was previously removed cannot insert a second row — it collides — so the only implementation available to the handler is

```sql
INSERT INTO task_assignments (task_id, user_id, assigned_by)
VALUES (...)
ON CONFLICT (task_id, user_id) DO UPDATE
   SET removed_at = NULL, assigned_by = EXCLUDED.assigned_by, assigned_at = now()
```

which is a resurrection in the precise sense the comment rules out.

**Nothing on the device is wrong, which is why this is filed as backend-visible only.** The comment's *conclusion* — that `assignCollector` and `unassignCollector` are both idempotent and *"neither call needs to know which"* — holds exactly as written, and is what A-116 and Chapter 2.7's A-06 depend on. The client cannot observe the difference between a new row and a revived one, because Chapter 4.6 §3 has no route that reads an assignment back (A-117, open item 89). Only the handler can see it, and the handler is the thing being written.

**The audit consequence is the part worth having written down.** A resurrection *overwrites* `assigned_by` and `assigned_at`, so the record of who first assigned this Collector and when is gone the moment they are re-assigned. FR-ADM-04's *"kept for audit"* survives for the removal and not for the assignment history. Whether that matters is a product question about what the audit trail is for; `audit_log` is the obvious place to answer it, since `0007` already grants `tasks` an `INSERT` there and Chapter 4.2 §2 scopes it to *"Admin actions on Projects/Tasks/Assignments"* — this being one.

**Not fixed in place.** The file is `mobile/lib/`, Mission 7.3 is backend-only by its own scope, and a one-line doc edit is not worth crossing that boundary on its own. Recorded here so the next mission touching that file corrects the comment rather than propagating it, and so the handler's `ON CONFLICT` is read as forced by the schema rather than as a liberty taken.

---

### A-182 — `Caller`'s optional fields described a state ADR-048 had already made unreachable

| | |
|---|---|
| **Record** | `backend/packages/shared/src/handler.ts`'s `Caller` interface |
| **Said** | `userId`, `orgId` and `role` are `string \| undefined` |
| **Says now** | All three are `string` |
| **Authority** | ADR-048 — the authorizer resolves the row, and `callerFromContext` throws when any is missing |
| **Class** | Type correction |
| **Status** | **Closed** |
| **Date** | 2026-08-19, Mission 7.3 Batch 1 |

The optionality is a fossil of Mission 6.2, when `resolveCaller` was a stub that genuinely could not produce those values. ADR-048 replaced the stub and made `callerFromContext` **fail closed** — *"a detached authorizer must not silently become an open endpoint"* — so a `Caller` with an absent field can no longer reach a handler at all.

**A type that lies in the safe direction is not free.** ADR-045 adopts `strictTypeChecked`, which forbids `no-non-null-assertion`, so each of the fourteen authorized routes would have had to re-narrow three fields the wrapper already guarantees. Seven of those routes exist as of this batch; the other seven are coming. Every one of those guards would be dead code asserting something proven one frame up, and **a reader cannot tell a ceremonial guard from a real one** — which is how a genuine check eventually gets deleted as noise.

Nothing outside `handler.ts` consumed the optionality, so the change was confined to the type and its own tests.

---

### A-183 — Cursor pagination had a validating half and no producing half, and choosing a sort order fell out of fixing it

| | |
|---|---|
| **Volume** | 4, Ch. 4.6 §1 — *"Pagination: cursor-based (`?cursor=…&limit=…`) on every list endpoint"* |
| **Was** | `parsePageRequest` validated an incoming cursor; `EnvelopeMeta.nextCursor` was in the envelope; `REQUEST_INVALID_CURSOR` was a published code. **Nothing produced or decoded a cursor** |
| **Is** | `cursor.ts` — opaque base64url keyset on `(created_at, id)` |
| **Class** | Unbuilt half of a shipped contract |
| **Status** | **Closed** for the two list routes in Batch 1 |
| **Date** | 2026-08-19, Mission 7.3 Batch 1 |

Three missions shipped the reading half of this contract without the writing half, and nothing detected it because every list endpoint was a `NOT_IMPLEMENTED` stub — the code with no producer had no consumer either.

**Keyset rather than `OFFSET`, and the reason is correctness before performance.** An offset re-reads and discards every row it skips, and a row inserted between two requests shifts every later page by one, so the reader silently sees a duplicate or misses a row. ADR-044's 1 MiB response ceiling makes pagination mandatory here rather than optional, so the pages have to be trustworthy as well as cheap.

### The sort order is a decision this forced, and no chapter makes it

A cursor needs a **total** order or pages overlap. No volume specifies one, and the mobile `ProjectTaskRepository` says so outright: *"Returns them in the order the backend supplied. No chapter specifies a sort, so none is imposed."*

`created_at DESC` is not a total order — two rows created in one transaction share a timestamp — so the key is `(created_at DESC, id DESC)`, with `id` breaking the tie. Recorded here rather than as its own entry because it is not an independent finding: building a keyset cursor is what forced it.

**The cursor is opaque so this stays changeable.** Callers are told nothing about the contents, which means the sort key can change later without it being the breaking change Ch. 4.6 §1 would send to `/v2`.

---

### A-184 — The mobile client cannot read past the first page, and will not notice

| | |
|---|---|
| **Record** | `mobile/lib/features/projects_tasks/domain/repositories/project_task_repository.dart` |
| **Says** | `Future<List<Project>> fetchProjects()` and `Future<List<Task>> fetchTasks(String projectId)` |
| **Problem** | Neither takes a cursor, returns one, or reads `meta` — so the client sees **page one and stops** |
| **Class** | Unexercised mechanism — the contract is now one-sided |
| **Status** | **Open.** Owed to Mission 7.4 |
| **Date** | 2026-08-19, Mission 7.3 Batch 1 |

With A-183 built, `GET /v1/projects` and `GET /v1/projects/{id}/tasks` return at most `DEFAULT_LIMIT` — 50 — rows and a `meta.nextCursor` saying there are more. **The client discards `meta` entirely**, because `VumpApi` returns `data` and nothing else to its callers, which `envelope.ts` records as a deliberate choice made when no cursor existed.

So an org with 51 Projects renders 50, with no error, no empty state and nothing on either side reporting a truncation. `pagination.ts` predicted exactly this in Mission 6.2 — *"The client does not consume cursors yet… so this side defines the contract and the client inherits it"* — and inheriting it is the part that has not happened.

**Not fixable from the backend.** Widening the page size only moves the number at which it silently truncates. It needs the repository signatures to carry a cursor, which is `mobile/lib` and out of this sub-mission's scope by its own terms.

---

### A-185 — Archived Projects are excluded by default, and no chapter said either way

| | |
|---|---|
| **Volume** | 4, Ch. 4.2 §1 (soft-delete) and Ch. 4.6 §3's `GET /v1/projects` row |
| **Says** | Nothing about whether an archived Project appears in either role's list |
| **Does now** | `WHERE p.archived_at IS NULL`, in both the Admin and Collector branches |
| **Class** | Stated default filling a specification silence |
| **Status** | **Open as a product question**, closed as an implementation default |
| **Date** | 2026-08-19, Mission 7.3 Batch 1 |

Ch. 4.2 §1 makes soft-delete a timestamp deliberately, *"so that archived data stays queryable"* — which settles that the row survives and settles nothing about who sees it. The mobile `Project` entity carries `archivedAt` and is explicit that it *"records the fact and decides nothing about it"*.

Excluding matches what archiving is for, and it is the reversible direction: the timestamp is still on every row, so a later `?include_archived=` widens this **without** the `/v2` bump Ch. 4.6 §1 requires for a breaking change. Defaulting the other way and later narrowing would be the breaking one.

**There is no such parameter today**, and FR-ADM-01 defines no archive route either — `archived_at` is written by nothing, so the filter currently excludes an empty set. That is worth knowing before anyone reads the clause as tested.

---

### A-186 — A resource outside the caller's org is reported absent, not forbidden

| | |
|---|---|
| **Volume** | 4, Ch. 4.8 §3 — *"an Admin can never read or write another org's data, regardless of guessed IDs"* |
| **Says** | That the access is refused. Not with which status |
| **Does now** | `404 RESOURCE_NOT_FOUND`, uniformly, for cross-org projects, tasks and collector ids |
| **Class** | Security-shaped decision, applied across every scoped route |
| **Status** | **Closed** |
| **Date** | 2026-08-19, Mission 7.3 Batch 1 |

`403` and `404` both refuse. They leak different amounts: **403 confirms the id exists**, which is precisely what a guessed id is asking. Ch. 4.8 §3's *"regardless of guessed IDs"* is about guessing, so answering the guess would satisfy the letter of the rule and defeat its purpose.

The sharpest case is `POST /v1/tasks/{taskId}/assignments`. Its assignee check has three failure modes — no such user, wrong role, wrong org — and **two of the three answer 404**. A wrong role is a 400, because the caller already knows that user exists inside their own org, so nothing is disclosed by saying why.

The cost is honest and worth stating: an Admin who fat-fingers a real id inside their own org gets the same 404 as one probing another tenant, and the log is the only place the difference is visible.

---

### A-187 — Batch 1's grants were proved against live Aurora, including two negative probes

| | |
|---|---|
| **Record** | Migration `0010`; gap register items 8 and 15; A-173 |
| **Class** | Verification, positive and negative |
| **Status** | **Closed for Batch 1's seven routes.** Gap 8 itself is untouched |
| **Date** | 2026-08-19, Mission 7.3 Batch 1 |

The mocked suite — 128 tests, two defects reinstated and caught — proves the SQL, the scope branch, the validation and the envelope, and is **structurally incapable of seeing a missing GRANT**: a scripted client returns what the test says regardless of what PostgreSQL would do. Migration `0010` exists because of exactly that blind spot, so the batch was also run against the real cluster as `vump-dev-operator`, authenticating as each function's own role.

| # | Probe | Role | Result |
|---|---|---|---|
| 1 | BR-19's three-table join | `vump_projects` | Succeeded, `[]` |
| 2 | `SELECT id, org_id, role FROM users` | `vump_tasks` | Succeeded, real row |
| 3 | `projects` org check | `vump_tasks` | Succeeded, `[]` |
| 4 | `INSERT INTO tasks` | `vump_projects` | **Refused — 42501** |
| 5 | `SELECT *` on `users` | `vump_tasks` | **Refused — 42501** |

Probe 1 is the one A-119 said was *"real and untestable until Mission 7"*: an empty result with **no permission error** is the proof, because the failure being ruled out is `42501`, not an empty set.

Probe 5 is the one worth keeping. F6's `users` grant is column-level, and until this ran, *"column-level"* was a claim in a migration comment. A refused `SELECT *` alongside a successful three-column read is the difference between a documented restriction and an enforced one — the same distinction `0008` had to learn the hard way when `ALTER DEFAULT PRIVILEGES` recorded nothing and PUBLIC kept `EXECUTE` on `complete_chunk()`.

### Negative permission probes need no teardown, which sidesteps A-173

A-173 blocks gap 8 because the BR-08/11/21/22 proofs seed rows and **no role can delete them**. Probes 4 and 5 assert that an operation is *refused*, so nothing is written and there is nothing to clean up — and probes 1–3 are reads.

**This does not close gap 8**, whose proofs are behavioural and do write. It does mean a useful class of check — every "role X cannot do Y" assertion in `0007` and `0010` — is available in CI today, ahead of whatever resolves the teardown question.

---

### A-188 — Nothing can complete a session, and every session will sit at `in_progress` forever

| | |
|---|---|
| **Volume** | 4, Ch. 4.4 §5 — `sessions.status` is *"'in_progress' \| 'complete' — FR-SES-02; transition gated by stored procedure (Chapter 4.2)"* |
| **Says** | A stored procedure gates the transition |
| **Is** | **There is no such procedure, and no route calls one.** `0006` defines `complete_chunk(uuid)` and nothing else; Chapter 4.6's catalogue has no endpoint that completes a session |
| **Class** | Unreachable state — a specified lifecycle with no mechanism |
| **Status** | **Open.** Carried into Batch 2b as its fourth fork |
| **Date** | 2026-08-19, Mission 7.3 Batch 2a |

Found while tracing `POST /v1/tasks/{taskId}/sessions`, not by reading the schema for its own sake.

Chapter 4.2 §3 describes exactly one such gate and it is about chunks: *"chunks.status can only transition to 'complete' via a stored procedure that first checks a matching, non-null chunk_metadata row exists."* Migration `0006` implements that as `complete_chunk()`, with a `BEFORE UPDATE` trigger making it the only path. **Sessions got the sentence and not the procedure.**

The consequence is concrete rather than theoretical:

- `sessions_status_check` permits `'complete'`, `sessions.status` defaults to `'in_progress'`, and **nothing anywhere issues an UPDATE**;
- `vump_sessions` holds `SELECT, INSERT` and deliberately **no UPDATE**, so even a handler that wanted to would be refused with `42501`;
- so A-07's *"Live status across all Collectors"* will show every session as in progress indefinitely, including sessions whose chunks are all `complete`.

### Why this is not fixed in Batch 2a

The interesting question is not how to write the procedure, it is **what completion means**. The plausible definition — a session is complete when all of its chunks are — is only knowable at the moment the last chunk completes, which is `PATCH /v1/chunks/{chunkId}/status`'s business and lives in Batch 2b. Building a session-completion path in 2a would either be a route nobody calls, or a guess at a rule 2b is about to need anyway.

`complete_chunk()` is the shape to follow if that reading holds: `SECURITY DEFINER`, granted `EXECUTE` to exactly the role that needs it, with a `BEFORE UPDATE` trigger making it the only path — which is also how the transition gets made without granting `vump_sessions` an UPDATE it should not otherwise hold.

**FR-SES-02 is the requirement to check it against**, and it should be read before the rule is chosen rather than after.

---

### A-189 — Batch 2a's grants were proved live, and the negative probe is the one that mattered

| | |
|---|---|
| **Record** | Migration `0010`; `backend/functions/sessions`; A-187's pattern |
| **Class** | Verification, positive and negative |
| **Status** | **Closed for Batch 2a's two routes**, with one path stated as mock-only |
| **Date** | 2026-08-19, Mission 7.3 Batch 2a |

`vump_sessions` had never been exercised — Batch 1's probes covered `vump_projects` and `vump_tasks` only. Run as `vump-dev-operator`, authenticating with the `sessions` function's own credential:

| # | Probe | Result |
|---|---|---|
| 1 | The GET's `sessions ⋈ tasks ⋈ projects` join | Succeeded, `[]` |
| 2 | The chunk-status aggregate, `GROUP BY session_id, status` | Succeeded, `[]` |
| 3 | **`UPDATE sessions SET status='complete'`** | **Refused — 42501** |
| 4 | **`INSERT INTO audit_log`** | **Refused — 42501** |

### Probe 3 converted a design correction into a proof

Part 17's trace found that `vump_sessions` holds `SELECT, INSERT` on `sessions` and no `UPDATE`, and that PostgreSQL requires **both** for `ON CONFLICT … DO UPDATE`. The Part 16 sketch had proposed exactly that form, copied from A-181's `task_assignments` shape — which would have failed at runtime with `42501`, **the same defect class migration `0010` exists to fix, reintroduced one batch after fixing it.**

The registration is `ON CONFLICT DO NOTHING` plus a re-read instead — `provisionCaller`'s pattern, needing no migration and no widening. Probe 3 is the live half of that: PostgreSQL refusing the alternative is what makes the choice evidence rather than a reading of a grant file.

Probe 4 confirms the other absence. Chapter 4.2 §2 scopes `audit_log` to *"Admin actions on Projects/Tasks/Assignments"*, and a Collector starting a session is none of those — so unlike all five of Batch 1's writes, `POST /v1/tasks/{taskId}/sessions` needs no transaction, because there is no second row that must commit with the first. The chapter and the grant agree independently, and now both are demonstrated.

### What is NOT proved, stated so the coverage is not read as complete

**The `ON CONFLICT` resurrection path is mock-only.** Proving it live means inserting a session and re-registering it, and A-173 means no role can delete the row afterwards.

This is worse than the `task_assignments` case A-187 sidestepped, and the difference is worth naming: **`chunks.session_id` references `sessions`**, so a stray session is not inert — it becomes permanent fixture data in a shared development database, and one that later chunk work could attach rows to. The idempotency, the 200-versus-201 distinction and the `SESSION_ALREADY_REGISTERED` refusal are covered by mocked tests and by nothing else.

The caveat is in `functions/sessions/src/index.test.ts`'s own header, not only here, so a reader of the suite meets it before the assertions rather than after.

---

### A-190 — A retried chunk registration must succeed; `CHUNK_ALREADY_REGISTERED` is for a mismatch, not a repeat

| | |
|---|---|
| **Volume** | 5, Ch. 5.10 §3; Volume 4 Ch. 4.6 §5; `backend/packages/shared/src/errors.ts` |
| **Says** | Ch. 5.10 §3: *"Step 1's registration always returns the same deterministic S3 key for a given chunk_id — **a retried registration call is safe to repeat**"* |
| **Was read as** | Mission 7.3 Part 1 traced `CHUNK_ALREADY_REGISTERED` as the answer to a second registration of the same `chunk_id` |
| **Should say** | A repeat **succeeds** and returns the same key with fresh presigned URLs. The named refusal is for a *genuine mismatch* — the same `chunk_id` presented with a different session, sequence index or checksum |
| **Class** | Correction to this mission's own earlier reading |
| **Status** | **Corrected before implementation.** No code was written on the wrong premise |
| **Date** | 2026-08-19, Mission 7.3 Batch 2b |

The error code's own comment says *"The chunk is already registered"*, which reads as though registration is a once-only operation. Chapter 5.10 §3 says the opposite in the same breath as explaining why: the key is deterministic precisely **so that** a retry is safe.

Refusing a repeat would break the thing the chapter is describing. Chapter 5.13 §2 grants a chunk six automatic attempts; a device that uploads some parts, loses connectivity and returns needs new presigned URLs against the **same** multipart upload — which is exactly Chapter 5.13 §4's *"the same in-progress multipart upload ID where possible"*. A registration that refused the second call would make NFR-REL-02's resumability unreachable by construction.

### The shape, which 2a already built once

This is `SESSION_ALREADY_REGISTERED`'s pattern one level down, and the symmetry is worth stating because it means the rule is now consistent across both identity-bearing routes:

| | Repeat with matching fields | Repeat with a conflicting field |
|---|---|---|
| `POST /v1/tasks/{taskId}/sessions` | 200, the existing session | 409 `SESSION_ALREADY_REGISTERED` |
| `POST /v1/sessions/{sessionId}/chunks` | 200, same key, **fresh URLs** | 409 `CHUNK_ALREADY_REGISTERED` |

The mobile side is unaffected either way: Mission 4.2's test asserts only that `VumpApi` surfaces the code, and its own comment records that *"the envelope is the contract, not the status code."*

**Recorded separately rather than inside Batch 2b's report** because it corrects a reading this mission itself published in Part 1, and a correction folded into the report of the work it changed is the kind that stops being findable.

---

### A-191 — Chapter 5.10's step order puts the metadata POST after the status PATCH, and BR-21 makes that order impossible

| | |
|---|---|
| **Volume** | 5, Ch. 5.10 §1's pipeline steps; Volume 4 Ch. 4.2 §3 (BR-21) and Ch. 4.5 §3 |
| **Says** | Ch. 5.10 §1: *"3. Confirm — `PATCH /v1/chunks/{id}/status` → 'uploading' → 'complete'. 4. Metadata — `POST /v1/chunks/{id}/metadata`"* |
| **Should say** | Metadata must be **step 3** and the status PATCH **step 4**. In the order as written, step 3 can never succeed |
| **Authority** | BR-21, as implemented by `complete_chunk()` in migration `0006` |
| **Class** | Sequencing defect in a specification, found by tracing the handler against the gate |
| **Status** | **Open.** No code is written on either order yet |
| **Date** | 2026-08-19, Mission 7.3 Batch 2b |

Chapter 4.2 §3 requires that *"chunks.status can only transition to 'complete' via a stored procedure that first checks a matching, non-null chunk_metadata row exists"*, and Chapter 4.5 §3 adds the second half — the backend sets `verified_at` *"and allowing chunks.status → 'complete'"*. Migration `0006` implements both: `complete_chunk()` raises `restrict_violation` when `chunk_metadata.verified_at IS NULL`, and a `BEFORE UPDATE` trigger makes the procedure the only path.

So a client following Chapter 5.10 §1 literally would, at step 3, ask for a transition the database is built to refuse — **every time, for every chunk** — and would only POST the metadata that makes it possible at step 4, after the call it needed it for had already failed.

### This is not the divergence A-073 already records

A-073 records the mobile side calling `markComplete` **after** step 4 rather than step 3, and its reasoning is about local deletion: *"BR-08 makes complete the point a chunk becomes eligible for local deletion, and deleting a chunk whose metadata never reached the backend would be unrecoverable."*

That is the **local** status write, and the conclusion happens to agree with this one. What A-073 does not say — because Mission 4.2 had no backend to try it against — is that the *remote* order in the chapter is not merely suboptimal but unsatisfiable. Two different writes, two different reasons, one shared answer.

### What the backend does about it, which is nothing

A handler cannot reorder its caller. `PATCH …/status` → `'complete'` with no metadata row will be refused; the only choice is **how legibly**. It surfaces as `RESOURCE_NOT_FOUND` naming the absent metadata rather than letting `restrict_violation` arrive as `INTERNAL_ERROR`, so a client hitting this reads a sentence that names the cause instead of a 500 — Chapter 4.6 §1's named-cause rule applied to a mistake the specification actively invites.

**Recorded before Mission 7.4 writes the client's call sequence**, because that mission is where the order becomes real, and the chapter it will be written from is the one that is wrong.

---

### A-192 — Batch 2b's grants and both completion gates were proved live

| | |
|---|---|
| **Record** | Migrations `0010` and `0011`; `functions/chunks-upload`, `chunks-verify`, `metadata`; A-187 and A-189's pattern |
| **Class** | Verification, positive and negative |
| **Status** | **Closed for Batch 2b's four routes**, with the upload round trip stated as mock-only |
| **Date** | 2026-08-19, Mission 7.3 Batch 2b |

Three roles that had never been exercised end to end — `vump_chunks_upload`, `vump_chunks_verify`, `vump_metadata` — plus the two `SECURITY DEFINER` gates the schema has carried since Mission 6.3 without either ever being fired.

| # | Probe | Role | Result |
|---|---|---|---|
| 1 | The Chapter 5.14 §1 key-composition join | `vump_chunks_upload` | Succeeded |
| 2 | The `chunks ⋈ sessions` ownership join, reading `upload_id` | `vump_chunks_verify` | Succeeded |
| 3 | The Chapter 4.5 §2 identity join | `vump_metadata` | Succeeded |
| 4 | `UPDATE chunks SET checksum_sha256` | `vump_chunks_verify` | **Refused — 42501** |
| 5 | `UPDATE sessions SET status='complete'` directly | master | **`restrict_violation` — FR-SES-02** |
| 6 | `SELECT complete_session(…)` | `vump_metadata` | **Refused — 42501** |
| 7 | `UPDATE chunks SET status='complete'` directly | master | **`restrict_violation` — BR-21** |

**Probe 1 is the one that closes open item 36's root cause.** Volume 4 Chapter 4.10 §2 step 1 makes `chunks-upload` compute the deterministic key, and until `0010` that role could read `sessions` and nothing above it — three of the key's five components were unreachable. The single most load-bearing value in the upload path was not computable by the role assigned to compute it, and now is.

**Probes 5 and 7 are the first time either completion gate has ever fired.** `chunks_completion_guard_trg` has existed since Mission 6.3 and BR-21's claim that `complete_chunk()` is *"the only path"* had never been tested against a live database — the strongest evidence Mission 6 produced for it was an uncommitted scratchpad. `sessions_completion_guard_trg` is new in `0011` and was exercised the day it landed.

### Why probes 5 and 7 ran as master, and why that is correct here

A-172 is emphatic that a proof run as master *"would pass while proving nothing"* — the master bypasses every `GRANT` in `0007`. That objection is exactly right for probes 4 and 6, which are privilege checks and were run as the constrained roles.

**It does not apply to a trigger.** A `BEFORE UPDATE` trigger fires for every principal including the master, so master is a valid witness. It is also the *only* possible one: no role holds `UPDATE` on `sessions` at all — Batch 2a's probe 3 proved that with a `42501` — so any function credential would be stopped one layer earlier, at the grant, and never reach the trigger being tested.

The distinction is worth keeping: **a grant proof must run as the constrained role; a trigger proof cannot.**

### Not proved, stated so the coverage is not read as complete

The full upload round trip — register, upload 38 parts, finalise, hash, complete — is **mock-only**. It needs a real 633 MB object and a real chunk row, `chunk_metadata`'s foreign key is `ON DELETE RESTRICT`, and A-173 means nothing can remove any of it. The seam, the ordering, the checksum comparison and both refusal paths are covered by 50 mocked tests and by nothing else.

---

### A-193 — Seed inside a transaction and roll back: a teardown-free proof, and a candidate for Gap 8

| | |
|---|---|
| **Record** | Gap register item 8; A-173; ADR-049's `db-prover` |
| **Class** | Technique, demonstrated |
| **Status** | **Open as a proposal.** Gap 8 is unchanged until someone builds the job |
| **Date** | 2026-08-19, Mission 7.3 Batch 2b |

A-173 states the blocker precisely: migration `0007` grants `DELETE` to no role, so the BR-08/11/21/22 behavioural proofs *"can seed and assert, and cannot clean up"*, and ADR-049 denies `db-prover` the master credential on correctness grounds. Three shapes were listed — a `vump_ci_proof` role with `DELETE`, rollback-only proofs, a disposable database per run — and rollback-only was set aside as *"complicated by each per-function secret being a separate Data API session, so one transaction cannot span the roles a cross-role proof needs."*

**That objection is real and narrower than it reads.** Mission 7.3 needed rows to fire two triggers, and used the Data API's own transaction control:

```
BeginTransaction → INSERT the whole FK chain in one CTE statement
                 → UPDATE, observe the trigger raise
                 → RollbackTransaction
```

Both trigger proofs ran this way and **nothing persisted**. There was no teardown because there was nothing to tear down.

### What it does and does not unblock

It works for any proof whose assertions live **inside one session**: a trigger, a constraint, a `SECURITY DEFINER` function's own logic. That covers BR-21 and BR-22 directly, which are two of the four proofs Gap 8 is waiting on.

A-173's objection still stands for the rest. A proof of the form *"role X cannot do Y to a row role Z created"* needs two credentials and therefore two sessions, and a transaction cannot span them. **BR-08 and BR-11 are that shape**, so this closes part of Gap 8 rather than all of it.

Worth noting alongside A-187's observation that **negative permission probes need no teardown either**, because they write nothing. Between them, the two techniques cover a useful proportion of what Gap 8 wants without answering the `DELETE` question at all:

| Proof shape | Technique | Teardown needed |
|---|---|---|
| "role X may not do Y" | Negative probe (A-187) | None — nothing is written |
| "the trigger/constraint refuses this" | Seed-and-rollback (here) | None — nothing is committed |
| "role X cannot touch role Z's row" | Neither | **Still blocked** — A-173 |

Recorded as a proposal rather than a closure. **Gap 8 remains open**, and its status is unchanged: the credential exists, the proofs are not a CI job. What has changed is that two of the three shapes it needs now have a demonstrated method.

---

### A-194 — Two of this mission's self-corrections never reached the register, and one of them was ruled on

| | |
|---|---|
| **Record** | Mission 7.3's own reports, Parts 3, 20, 21 and 25 |
| **Class** | Findability failure — the correction was made, and made only in conversation |
| **Status** | **Closed by this entry** |
| **Date** | 2026-08-19, Mission 7.3 closing gate |

Mission 7.3's close-out claimed *"three are corrections to this mission's own earlier readings (A-190, A-191, and Part 21's budget claim)"*. Audited at the Testing & Verification gate, **that count was wrong twice over**: the register holds **two** such corrections, not three, and one of the three named is not a self-correction at all.

| Claimed | Actually |
|---|---|
| A-190 | ✅ Self-correction, in the register — corrects Part 1's reading of `CHUNK_ALREADY_REGISTERED` |
| A-189 | ✅ Self-correction, in the register — **not claimed.** Records that Part 16 proposed `ON CONFLICT DO UPDATE` against a role with no `UPDATE` |
| A-191 | ❌ Not a self-correction. It is a defect in Volume 5 Chapter 5.10, found by this mission but not made by it |
| Part 21's budget claim | ❌ **Not in the register at all** |

### The one that matters, because a decision was taken on it

Part 20 recommended Fork 1 option B on two grounds: it preserves A-143, and *"the completion moves to a different invocation and the budget separates cleanly again"*. The second was wrong — a different **invocation** is not a different **request budget**, because one client `PATCH` waits for MPU assembly and the hash however many Lambdas are involved.

**The project owner's Part 21 ruling cited that reasoning back verbatim** when re-affirming B. Part 21 opened by correcting it, the ruling was re-affirmed on the corrected premise, and the measurement that followed made the point moot — `completeMs` came in at 99ms against a 21-second margin.

So the outcome is unaffected and the record was still incomplete: **a reader of the register would find no trace that a fork was first recommended on a premise that did not hold.** The correction lives in one doc comment inside `probe/index.mjs` and in a conversation.

A smaller instance, recorded for completeness rather than because it changed anything: Part 3 stated *"no new Secrets Manager entries — eight before, eight after"*, and corrected it in the same report once F7's `vump_ci_proof` role turned out to need a ninth. That one never reached the register either.

### Why this is worth an entry rather than a shrug

This register exists because *"an architectural decision that is not recorded here does not exist"*, and the same standard has to apply to a decision's **rejected premises**. A-172 makes exactly this argument about a Mission 6 hand-off that compressed "a CI credential" into "a read-only CI credential": the compression was carried forward into a later trace before it was caught, and the correction was worth its own record.

The pattern to keep: **a correction made in a report is not recorded.** Reports are dated artefacts and are not searched; the register is. Both of the corrections above were made promptly and visibly at the time — what failed was the step after.

---

### A-195 — The Fork 1 seam validated nothing, and three records said it did

| | |
|---|---|
| **Record** | `functions/chunks-upload/src/index.ts`'s `finalizeUpload`; `modules/iam/main.tf`'s `chunks_verify_invoke_upload` comment; Mission 7.3 Parts 20 and 22 |
| **Said** | *"The invoked function validates the chunk before acting, so this cannot create an object at an arbitrary key"* |
| **Was** | `finalizeUpload` passed `request.key` and `request.uploadId` **straight from the invoke payload to S3**. `chunkId` appeared only in an error message. No database read, no ownership check, nothing |
| **Class** | Security defect — a claimed control that did not exist |
| **Status** | **Closed.** Validation added, three tests, two proved non-vacuous |
| **Date** | 2026-08-19, Mission 7.3 security review |

Found by the closing gate's security review, reading the function instead of the IAM policy.

### What a compromised `chunks-verify` could actually do

The seam gives that role `lambda:InvokeFunction` on one ARN, and `isFinalizeRequest` routes any payload carrying `action: 'finalize-upload'` to the finaliser. With no validation, the reachable capability was:

**Finalise any in-progress multipart upload in the bucket, at any key, for any upload id it could name.** And it could name plenty: `chunks-verify` holds `SELECT` on `chunks`, which is **not org-scoped at the grant level**, so it could read the `s3_object_key` and `upload_id` of every registered chunk in the system.

The concrete harm is truncation. `CompleteMultipartUpload` assembles whatever parts have arrived so far, so finalising an upload still in flight produces a **short object that S3 then treats as complete** — and the multipart upload is consumed, so the remaining parts have nowhere to go. Against footage that is mid-upload, that is silent evidence loss.

### What it still could not do, which is why the choice was right

Even unvalidated, the capability was narrower than `s3:PutObject` on `bucket/*` in ways that matter:

- **It cannot create an object where no upload exists.** `CompleteMultipartUpload` requires a live `UploadId`, and only `chunks-upload` can call `CreateMultipartUpload`.
- **It cannot overwrite a completed object.** A finished upload has no id left to finalise.
- **It cannot choose content.** The bytes are whatever the device actually sent; there is no path to injecting attacker-authored footage.
- **It cannot presign anything**, so it cannot hand a reader URL to a third party — which is the specific harm A-143 exists to prevent, and the reason `chunks-verify` must never hold `PutObject`.

So Fork 1 option B remains the right call and A-143's property held throughout. **The gap was between what the code did and what three records claimed it did**, which is its own category of problem: a reviewer reading the IAM comment would have concluded the control existed and stopped looking.

### The fix

`finalizeUpload` now reads the chunk row and refuses unless the supplied key **and** upload id are the ones that chunk owns. It needs no new grant — `chunks-upload` already holds `SELECT` on `chunks` for registration — so the capability narrows from *"finalise anything"* to *"finalise this specific registered upload"*, which is what the comment always claimed.

Three tests cover it: a foreign key, a foreign upload id, and an unknown chunk id. Two were proved non-vacuous by removing the check and watching them fail. The IAM comment is rewritten to say that the control lives in the function and to name this entry, rather than asserting a property the reader cannot verify from where it is written.

### The lesson, which is not "add validation"

The IAM boundary was reviewed carefully and the handler was not. A capability's real extent is the **intersection** of what IAM permits and what the invoked code does with it, and reviewing one half thoroughly reads as diligence while proving nothing about the other. This is Mission 4.9 §4's pattern again — *"reviewed carefully, read correctly, and committed without once being run where it would actually have to work"* — in the security-review medium.

---

### A-196 — Chapter 5.7 §2's device identifier, decided at last

| | |
|---|---|
| **Record** | Volume 5, Chapter 5.7 §2 |
| **Says** | The device identifier is *"cached, stable"* |
| **Left open** | What it **is**. Mission 3 flagged the gap and bound `MetadataIdentity.unsourced` behind it for four missions |
| **Now** | A v4 UUID, minted on first access, persisted in `shared_preferences`, scoped to the **install** rather than to the device |
| **Recorded in** | ADR-050 |
| **Date** | 2026-08-19, Mission 7.4 step 3 |

The full argument is in ADR-050 and is not repeated here. What belongs in the register is the shape of the gap, because it is a recurring one: **a spec adjective with no referent.** *"Cached, stable"* reads like a requirement and is satisfiable by at least two things that behave very differently under a factory reset, and nothing in Volume 5 chooses between them. Mission 3 was right to leave it open and right to make the absence loud — `unsourced` plus A-068's Guard 1 meant four missions of recording could not silently upload unattributed footage while the question sat unanswered.

The honest cost is recorded rather than buried: **a reinstall mints a new device id.** `ANDROID_ID` would not have avoided that — it resets on factory reset — so the choice was between two identifiers that both break, one of which also carries OS-wide correlation surface.

### A-197 — F23's move was half a move, and that was the point

| | |
|---|---|
| **Ruling** | *"Move `RandomUuidGenerator` to `core/`, don't duplicate"* — Mission 7.4 Part 6 |
| **Done** | The **minting** moved to `core/identity/uuid_v4.dart`. The **class** stayed in `features/recording/data/` as an adapter over it |
| **Why not the whole class** | `RandomUuidGenerator implements SessionIdGenerator, ChunkIdGenerator` — both `features/recording/domain/` contracts. A `core/` class implementing them would be `core/` → `features/` |
| **Date** | 2026-08-19, Mission 7.4 step 3 |

ADR-022 R3 is usually cited for the sideways import, and invariant I41 forbids `core/` → `features/` separately, but the two are the same rule in practice: **a shared module may not name the thing that consumes it.** Moving the class wholesale would have satisfied the letter of the ruling and broken the constraint the ruling exists to serve.

So the source is shared — one implementation of RFC 4122 §4.4, which is what *"don't duplicate"* asks for — and the ports stay where their callers are. Both `ChunkIdGenerator` and `SessionIdGenerator` still resolve to the same instance at the composition root, so the property the ruling was protecting is intact.

Recorded because the ruling and the implementation do not look identical on inspection, and a reader finding the class still in `features/` should find the reason here rather than concluding the ruling was ignored.

### A-198 — `core/identity/` takes the fifth `shared_preferences` grant

| | |
|---|---|
| **Record** | `.github/workflows/ci.yml`, the `Architecture boundaries` job |
| **Was** | Four owners: `features/recording/data/`, `main.dart`, `main_cleanup_probe.dart`, and one named onboarding file |
| **Now** | Plus `lib/core/identity/device_id_store.dart` |
| **Date** | 2026-08-19, Mission 7.4 step 3 |

Granted per-**file**, not per-directory, on the precedent A-067 set and ADR-039 states: *"the file that may import [the package] announces it in its own filename … greppable and self-declaring instead of a directory anyone can drop a file into."* `core/identity/` also holds a platform channel and two contracts, none of which has any business reaching a key-value store, so a directory grant would have handed the permission to three files that must not have it and to every file added there afterwards.

`core/` owning a confined plugin is not itself new — `core/storage/` owns `flutter_secure_storage`, `core/network/` owns `dio`, `core/database/` owns `isar`. What is new is that this package now has an owner **above** the feature layer, which follows from ADR-022 R3: a device id is needed by two features and belongs to neither.

**The rule was verified non-vacuous before this entry was written.** The violation was found by running the check locally *after* the code was written and passing analysis and tests — the import was already in place, the suite was green, and only the boundary job caught it. That is the job doing exactly what Mission 4.3's open item 41 asked of it.

---

### A-199 — A-184 is closed, and the fix reached further than the port

| | |
|---|---|
| **Was** | A-184: `fetchProjects()` and `fetchTasks(id)` returned `List`, discarded `meta`, and *"saw page one and stopped"* |
| **Now** | Both return a `PagedResult` carrying `nextCursor`; the notifiers thread it; four screens offer the next page |
| **Status** | **Closed** |
| **Date** | 2026-08-19, Mission 7.4 step 4 |

Recorded because the fix was **not** confined to the two methods A-184 named, and a reader tracing it from that entry alone would miss half of it.

**`VumpApi` could not read a list endpoint at all.** A list route's `data` is a JSON array, `_unwrap` required an object, and it raised `NETWORK_SERIALIZATION` on anything else. That was correct for what `get` promises, and it meant `GET /v1/projects` would have failed on its first call — not truncated, *refused*. So A-184's *"the client discards `meta`"* was the visible half of a client that could not have consumed the rows either.

`getList` is separate from `get` rather than a widening of it, because `get`, `post` and `patch` have three callers between them that have been exercised against the real backend, and giving them a `meta` field none of them has would edit a verified request path for nothing.

**The cursor stops at the notifier.** F25: the repository returns a page, the notifier keeps `nextCursor` privately, and the published state is still `List<Project>`. Seven consumers, no type change. Pagination is a property of the read, not of what a screen renders.

### A-200 — FR-PT-01's third aggregate goes absent, for the reason the other two did

| | |
|---|---|
| **Volume** | 1, FR-PT-01 — *"active projects, in-progress sessions, total recorded time, and sync status"* |
| **Was** | Two of four absent: *in-progress sessions* and *total recorded time* |
| **Now** | *Active projects* joins them. Only *sync status* survives |
| **Cause** | F20's pagination, not a new discovery about the data |
| **Status** | Open item 111 |
| **Date** | 2026-08-19, Mission 7.4 step 4 |

`DashboardSummary.activeProjectCount` counted `projectsProvider`'s Projects. That was a total while the provider held every Project; after F20 it holds **however many pages have been loaded**, which is one until a Collector scrolls C-04 and presses "Load more". The tile did not become wrong so much as it stopped being about what its label says.

**There is no cheap honest fix, and each rejected option is rejected for its own reason:**

- *Count what is loaded and label it differently.* There is no honest label. "Projects on the pages you have loaded" is not a dashboard statistic.
- *Walk every page to count them.* An unbounded number of requests to render one tile, on a screen whose other numbers are local.
- *Render "200+".* This screen already has exactly one rule for an aggregate it cannot answer — omit the tile — and A-110's argument is that an absent tile beats a false one. A third convention would make the two existing absences look like oversights rather than decisions.
- *Add a total to the envelope.* Chapter 4.6 §1 has no `total`, and adding one is a backend change to a catalog Mission 7.3 closed, for a tile.

So the tile is dropped on the precedent the same screen already set. The honest summary is that **FR-PT-01 is now one-quarter rendered**, and that is a product gap rather than an implementation one — recorded rather than made to look smaller.

### A-201 — Three screens select a row out of a page, and 200 is a bound not a fix

| | |
|---|---|
| **Record** | C-06 Task Detail; C-05 and A-05 Project Detail |
| **Shape** | Each selects one row **out of a list**, because Chapter 4.6 §3 has no `GET /v1/tasks/{id}` and no `GET /v1/projects/{id}` |
| **Was about to be** | At `DEFAULT_LIMIT` = 50, the 51st Task in a Project renders *"This Task isn't available to you"* |
| **Now** | Page size raised to `MAX_LIMIT` = 200 |
| **Residual** | The 201st Task reproduces it exactly |
| **Status** | **Open**, with a revisit trigger |
| **Date** | 2026-08-19, Mission 7.4 step 4 |

The failure is worth naming precisely, because it is not a truncated list. That copy was written to mean BR-19 — *"not assigned to you"*, deliberately indistinguishable from *"does not exist"* — so pagination would make the app **state an authorization fact that is false**. A Collector would be told they lack access to their own assigned Task.

200 is the backend's own ceiling: `parsePageRequest` **rejects** an out-of-range `limit` rather than clamping it, so this cannot be raised further without changing `MAX_LIMIT`, and `MAX_LIMIT` was chosen against ADR-044's 1 MiB response ceiling.

**Revisit trigger, stated so it is not a standing invitation:** a real `GET /v1/tasks/{id}` route, *if and when a mission actually approaches one*. Chapter 4.6's catalog was closed by Mission 7.3, and opening it now for a case no real org is near would be scope creep into finished territory. What makes this recordable rather than deferred-and-forgotten is that the trigger is a route, not a date.

### A-202 — `MAX_LIMIT` times a maximal row exceeds ADR-044's ceiling, and already did

| | |
|---|---|
| **Record** | `pagination.ts`'s `MAX_LIMIT = 200`, justified as *"a generous row is on the order of a few kilobytes, so 200 leaves roughly an order of magnitude of headroom"* |
| **Holds for** | `projects` — seven short columns |
| **Does not hold for** | `tasks` — the backend accepts `instructions` up to **20,000 characters** |
| **Status** | Open, raised not created by A-201 |
| **Date** | 2026-08-19, Mission 7.4 step 4 |

200 maximal Task rows is roughly 4 MiB against ADR-044's 1 MiB ceiling. The arithmetic that matters, though, is that **50 maximal rows is already about 1 MiB** — the exposure exists at `DEFAULT_LIMIT` and predates this mission. A-201 makes it four times more reachable; it did not introduce it.

Two things keep it recordable rather than blocking. It **fails loudly** — the Data API terminates the call and the client sees a refused read, not a silently short list. And it needs a Task with instructions near the schema cap, a length no real Task has been observed to approach, because the cap was set as a bound rather than measured.

What would settle it is the measurement `pagination.ts` itself defers — *"the measurement belongs to Mission 6.3, when real rows exist"* — and real rows still do not exist. Recorded so that the first org with long instructions is a known case rather than a mystery.

### A-203 — Two `vumpApiProvider` declarations, and the third consumer is what found it

| | |
|---|---|
| **Was** | `core/network/providers/dio_provider.dart` and `features/upload/application/chunk_upload_pipeline.dart` each declared `final Provider<VumpApi> vumpApiProvider` |
| **Effect** | Two `VumpApi` instances over one shared `DioClient`; which one a file got depended on which it imported |
| **Status** | **Closed.** The `features/upload/` one is deleted |
| **Date** | 2026-08-19, Mission 7.4 step 4 |

Harmless in effect — `VumpApi` holds only its client and no state — and that is exactly why it survived two missions. Both providers worked, both suites were green, and nothing distinguished them at a call site.

**It was found by needing a third consumer.** `features/projects_tasks/data/` cannot import the `features/upload/` one at all under ADR-022 R3, so the duplicate would have presented as *"the provider I need is unreachable"* rather than as *"there are two"*. A reader who resolved that by declaring a third in `features/projects_tasks/` would have been following the local precedent exactly.

The fix touched one file and no test — the import that resolves the surviving provider was already present, so deleting the declaration was sufficient, and the upload suite passed unmodified at 184 tests. Recorded because *"the duplicate that does not matter yet"* is a shape worth recognising: the cost is not the second instance, it is that the second declaration is a template.

### A-204 — M8's gate is met, and the fakes outlive the condition that named them

| | |
|---|---|
| **Gate** | Volume 11, Ch. 11.1 M8 — *"Every repository reads/writes the real backend — no fake/mock repository remains wired into a release build"* |
| **Condition as written** | The three fake classes *"and their `main.dart` overrides are deleted together"* |
| **What happened** | The overrides are deleted. The classes are not |
| **Status** | Gate **met**; the conditions rewritten in all three files |
| **Date** | 2026-08-19, Mission 7.4 step 4 |

`FakeProjectTaskRepository`, `FakeProjectTaskAdminRepository` and `InMemoryProjectTaskStore` were bound in `main.dart` from Mission 5.1.1 because M8 comes after M7 and there was no deployed endpoint to read. Mission 7.3 deployed all thirteen routes; `main.dart` now binds the real repositories, and no composition root names a fake.

**The classes stay, and the removal conditions were rewritten rather than reinterpreted.** Seven test files drive screens through them — both accessibility sweeps among them — and M8 is a rule about what a *build* reaches, not about whether a test double exists. Deleting them would take seven test files with it for nothing the gate asks for.

The reason this is an entry rather than a comment edit is the failure it avoids: a removal condition that is met in substance but not in letter reads, on a later audit, as **unmet**. Mission 7.3's closing gate spent real effort on exactly that shape — a claim in a record that the code did not match. Three doc comments now say what actually happened, and this entry says why they differ from what they used to say.

One divergence is now labelled rather than left implicit: `FakeProjectTaskRepository.fetchTasks` answers an unknown Project with an **empty list**, and the real repository raises A-186's `RESOURCE_NOT_FOUND`. The fake keeps the old answer so the screen tests that predate the real repository still describe what they were written to describe, and the 404 path is covered against the controllable double instead.

---

### A-205 — Two reports called the APK build green, reading a file no build had produced

| | |
|---|---|
| **Record** | Mission 7.4 step 3 and step 4 reports; the `flutter build apk --debug` line in both |
| **Said** | *"Kotlin compiles — `assembleDebug` built the APK"*, and *"`assembleDebug` builds"* |
| **Was** | The command **fails**. Gradle builds all three flavours and the tool then looks for `app-debug.apk`, which no flavour produces |
| **Why it looked green** | A stale `app-debug.apk` from before ADR-047 was sitting in `build/app/outputs/flutter-apk/`, and the tool found it |
| **Class** | Verification defect — a check that could not fail |
| **Status** | **Closed.** The command is `flutter build apk --debug --flavor dev` |
| **Date** | 2026-08-19, Mission 7.4 step 4 verification |

ADR-047 made Gradle product flavours the environment selector — *"One flag. It selects four things that must agree, and they cannot be selected separately"* — so there is no unflavoured debug variant. `flutter build apk --debug` therefore runs `assembleDebug`, which produces `app-dev-debug.apk`, `app-prod-debug.apk` and `app-staging-debug.apk`, and then fails to locate the single artefact it expected.

```
Running Gradle task 'assembleDebug'...                             27.6s
Gradle build failed to produce an .apk file.
```

Against the corrected command it succeeds in 11.1 seconds from an emptied output directory, exit code 0.

### What was actually true, and what was not

**The compilation was genuinely succeeding.** Both earlier runs produced real flavour APKs, and the thing those runs were cited for — that the new Kotlin in `DeviceModelChannel.kt` compiles — was true. The Dart and Kotlin compile is shared across flavours, so nothing built on that conclusion is wrong.

**The evidence for it was not.** The line quoted in both reports, `√ Built build\app\outputs\flutter-apk\app-debug.apk`, named a file dated before ADR-047. A stale artefact reported as the product of the run is not weaker evidence than a fresh one; it is evidence of nothing, because it would have appeared identically had the build produced no output at all.

### How it was found, which is the transferable part

By **emptying the output directory before re-running**. Nothing else changed — same command, same tree, same toolchain. The check had been passing for two steps and would have kept passing for as long as that file survived, including through a build that had started failing for an unrelated reason.

This is A-195's shape in the build medium. There the IAM boundary was reviewed carefully and the handler was not, and *"reviewing one half thoroughly reads as diligence while proving nothing about the other"*. Here the command was run carefully and its **output directory** was not — and a verification whose success does not depend on the run is the same defect as a control that does not exist.

### The rule this leaves

**A build check must start from an absent artefact.** Otherwise its green is a claim about the filesystem rather than about the build. The same question is worth asking of every check whose evidence is a file rather than an exit code — and the corrected invocation is now stated in the step reports and carried into Mission 7.4's device checkpoint, where the APK actually has to install.

---

### A-206 — Step 3 wired `collector_id` to the Firebase uid, and the backend checks it against `users.id`

| | |
|---|---|
| **Record** | Mission 7.4 step 3; `main.dart`'s `deviceContextProvider` override |
| **Does** | `collectorId: ref.watch(authNotifierProvider).valueOrNull?.user?.uid` |
| **`User.uid` is** | The **Firebase** uid — `_toUser` builds it from `fb.User.uid` |
| **The backend checks it against** | `sessions.collector_id`, which is `users.id`, a database uuid |
| **Consequence** | **Every metadata POST would be refused**, for every chunk, forever |
| **Class** | Implementation defect — a value of the right shape from the wrong namespace |
| **Status** | **Closed**, Mission 7.4 step 5 |
| **Date** | 2026-08-19, Mission 7.4 step 5 trace |

`functions/metadata/src/index.ts` resolves a chunk's *true* identity from a join and refuses a document that disagrees: `check('identity.collector_id', document.identity.collector_id, truth.collectorId)`, where `truth.collectorId` is `s.collector_id`. That column holds `users.id`. The client was sending a Firebase uid.

Both are opaque strings, so nothing in the type system, the analyzer or any unit test could tell them apart — the step 3 tests assert that the composition root *passes through* whatever the auth notifier holds, which it does, correctly.

### The right value was already available, in a class that says so

`backendProfileProvider` has existed since Mission 6.5 and its `BackendProfile.userId` is documented, verbatim, as *"`users.id` — the backend's own identifier, not the Firebase uid."* `POST /v1/auth/verify` returns `{ userId, orgId, role }` and `AuthRepositoryImpl._fetchOrgId` **reads `orgId` and discards `userId`**.

So this was not a missing capability. The distinction was known, written down, and available at the exact moment the wrong field was chosen.

### Why the step 3 trace did not catch it

The trace asked *"where does `collectorId` come from"* and answered *"`features/auth/`, via the auth state"*, which is right. It did not ask **which of that feature's two identifiers the backend compares against**, because at the time nothing compared anything — the metadata POST had no consumer, `TaskContext` was unsourced, and Guard 1 refused every chunk before a request was built.

That is the recurring shape rather than a one-off: **a field is wired correctly with respect to its source and never checked against its destination**, and the destination is unreachable so nothing complains. A-195 is the same defect in the security medium — *"a capability's real extent is the intersection of what IAM permits and what the invoked code does with it"* — and here it is the intersection of what the client sends and what the server joins on.

### What it says about the other four identity fields

Checked, since one was wrong: `project_id` and `task_id` now come from real `Project` and `Task` rows fetched from the backend (step 4), so they are backend uuids and match. `device_id` is **stored, not checked**, so its namespace is the client's to choose and A-196's install-scoped UUID is correct. `session_id` is checked — and is also wrong, for a different reason, recorded as A-207.

---

### A-207 — `identity.session_id` is the local session id, and the backend joins on its own

| | |
|---|---|
| **Record** | `ChunkMetadataAssembler` — `sessionId: session.sessionId` |
| **Sends** | `LocalSession.sessionId`, the UUID Chapter 5.3 mints on the device at session start |
| **Backend checks it against** | `s.id` — the `sessions` row's own primary key, generated server-side |
| **Consequence** | **Every metadata POST would be refused**, independently of A-206 |
| **Class** | Design gap, not a slip: the value is right for where it is written and wrong for where it is sent |
| **Status** | **Closed**, Mission 7.4 step 5 |
| **Date** | 2026-08-19, Mission 7.4 step 5 trace |

F5 made these two ids deliberately distinct. `sessions.client_session_id` is the device's UUID, `sessions.id` is the backend's, and the pair plus `UNIQUE (collector_id, client_session_id)` is what makes `POST /v1/tasks/{id}/sessions` idempotent. `SessionRegistrar` exists precisely because *"that `{id}` is **not** the local session UUID this app mints at session start"*.

The metadata document was assembled before any of that existed and carries the only session id the device had.

### Why it cannot be fixed at the assembler

The document is written at **chunk finalization**, which happens while recording and may happen with no network at all. The backend session id does not exist yet and may not exist for hours — Chapter 5.13's deferred-upload case is exactly that. An assembler that waited for one would block finalization on connectivity, which is the opposite of what the local-first queue is for.

The two ids are therefore both correct and both necessary: the local one is what the device stores and retries against, and the backend one is what the wire needs. **The translation belongs at the boundary that already performs it** — the pipeline, which holds the remote id from step 1 and posts the document at step 4.

### Why this is worth an entry rather than a quiet fix

`SessionRegistrar`'s doc has said since Mission 4.2 that the local and backend session ids are different things, and the metadata document was still built with one and validated against the other. The knowledge existed in one file and the defect in another, with no path between them that any test could traverse — the metadata POST had no reachable caller, because `sessionRegistrarProvider` threw.

This is A-206's shape a second time in one trace: **a field correct with respect to its source, never checked against its destination, and the destination unreachable so nothing complained.** Two instances in the same identity group, found by reading the backend's join rather than by running anything, is the argument for tracing a payload against its validator before the first end-to-end attempt rather than after it.

---

### A-208 — A syntax the SDK parses and the code generator does not

| | |
|---|---|
| **Record** | `analysis_options.yaml`; invariant I49 |
| **Syntax** | Null-aware collection elements — `{'cursor': ?cursor}`, `[?value]` |
| **`flutter analyze`** | Accepts it, and `use_null_aware_elements` actively **asks** for it |
| **`build_runner`** | Cannot parse it. **Every** generator then refuses to run |
| **Status** | **Closed.** The lint is silenced; the two uses are rewritten; I49 records the rule |
| **Date** | 2026-08-20, Mission 7.4 step 5 |

`build_runner` bundles its own analyzer rather than using the SDK's, and that one is older. Meeting a null-aware element it reports the **file** as having syntax errors, and freezed, `json_serializable` and `isar_generator` all decline — against files unrelated to the one containing the syntax:

```
[SEVERE] freezed on lib/core/network/vump_api.dart (cached):
This builder requires Dart inputs without syntax errors.
```

So the rule is not merely unhelpful here. **Following it breaks the build**, which is why the lint is silenced project-wide rather than suppressed per line.

### The part worth recording is the detection delay

The syntax entered `lib/` in **step 4**, in `VumpApi.getList` and the admin repository. Step 4 then ran `flutter analyze` (clean), the full suite (1123 green), the boundary checks (all five), and committed. Everything was true. Nothing in that verification touches a code generator.

It surfaced in **step 5**, on the first line of the first phase, because adding `backendUserId` to a `@freezed` class needed codegen — and the failure named `vump_api.dart` and `project_task_admin_repository_impl.dart`, two files step 5 had not touched.

**A green verification that cannot fail on a defect is the same shape as A-205**, one step earlier: there, a build check read a stale artefact and would have passed through a broken build. Here, a lint-clean suite passes through a syntax that has already broken the generator for whoever runs it next. Both are checks whose success did not depend on the thing they appeared to be checking.

### Why an invariant and not a comment

Because the cost is paid by a **different mission than the one that incurs it**. A comment in `analysis_options.yaml` is read by someone editing `analysis_options.yaml`; the person who needs the rule is writing a map literal three files away, with a linter that has been told to stay quiet. I49 puts it where the other cross-cutting rules are, and states plainly that nothing enforces it.

The revisit trigger is concrete and outside this project's control: **`build_runner`'s bundled analyzer catching up to the SDK's.** When it does, the `errors:` entry and I49 both come out. Until then the rule holds, and it is the only invariant in the register imposed by a tool rather than by a decision.

---

### A-209 — A-100 is closed, and the port it named could never have been implemented

| | |
|---|---|
| **Was** | A-100: `SessionRegistrar` *"owed to whichever mission builds `features/projects_tasks/`"* |
| **Now** | `SessionRegistrarImpl` in `features/upload/data/`, bound at the composition root |
| **Status** | **Closed** |
| **Date** | 2026-08-20, Mission 7.4 step 5 |

The port was declared in Mission 4.2 and `sessionRegistrarProvider` threw for three missions. That is the reason **no chunk has ever reached `uploading` on a device**: constructing the pipeline threw, which is why `UploadDispatcher` holds it behind a function rather than a field, so the throw landed on the first claimable chunk instead of on startup.

### The port could not be implemented as declared, by anyone

`remoteSessionId(String localSessionId)` had to produce a Task id from a local session id, and the only source is `LocalSession.taskId` — owned by `features/recording/`. The nominated implementor, `features/projects_tasks/`, could not reach it under ADR-022 R3. **The owner named in the doc was the one owner structurally incapable of satisfying it.**

F17 had already resolved the underlying problem by putting the Task on the chunk, so the caller holds it by the time it reaches step 1. F32 passes it. That is not a widening of the port's responsibility — it is the port asking for what its caller was given.

### And that moved the implementation

With the Task arriving as a `String`, an implementation needs **nothing** from `features/projects_tasks/`: it posts to a URL and reads an id back, which is what `ChunkUploadApiImpl` beside it already does four times over. So it lives in `features/upload/data/` (F33), and the port's doc — which had said the opposite since Mission 4.2 — is rewritten rather than left contradicting the code.

The port stays in `core/upload/`, because `features/upload/application/` declares the need and may not import `data/` (ADR-022 §5.3).

### One design point that reads as an omission and is not

**Nothing is cached** (F34). The pipeline calls this once per chunk — 38 for a full recording, more with retries — and each call is a real `POST`. That is deliberate twice over.

It costs two Lambda invocations and about four Data API calls against an upload moving 633 MB in 38 parts, which is noise on the critical path.

And `startSession` re-runs `assertAssigned` every time. Chapter 4.8 §3: a removed assignment *"immediately excludes that Task from all future queries, even if the mobile app's local cache hasn't refreshed yet."* **Each registration is therefore a live authorization re-check**, and caching the id — in memory or in a column — would let a Collector whose assignment was revoked mid-session upload the remaining thirty chunks. The repetition is the feature.

### What remains unproven

Everything above is proven against a scripted HTTP adapter. `POST /v1/tasks/{id}/sessions` has never been called by this client against the deployed backend, and the 200-on-repeat path — the one the whole no-caching argument rests on — has never been observed outside the backend's own tests. Both are device-checkpoint items.

---

### A-210 — The device checkpoint's fixture was seeded by direct insert, and the API could not have produced it

| | |
|---|---|
| **What** | One Project, one Task, one `task_assignments` row, one `audit_log` row, in the dev database |
| **Ids** | Project `4889ca14-11d6-4142-8ae3-c5e96be62f7f`; Task `208f416c-a707-4df4-a25c-5b45707803b0` |
| **How** | Four `rds-data execute-statement` calls, committed |
| **Not** | Through `POST /v1/projects`, `POST /v1/projects/{id}/tasks`, `POST /v1/tasks/{id}/assignments` |
| **Date** | 2026-08-20, Mission 7.4 device checkpoint |

Recorded because rows that exist in a real database with no request behind them are indistinguishable, later, from rows a route created — and because the reason the routes were not used is a **structural property of the API**, not a convenience.

### The API cannot express "assign this account to a Task" for a single account

`assignCollector` validates the **assignee's** role, not the caller's:

```ts
if (readString(row, 2, 'users.role') !== 'collector') {
  throw ApiError.invalidRequest('That user is not a Collector.');
}
```

The checkpoint has one account. To call `POST /v1/tasks/{id}/assignments` it must be `admin`; to be the assignee it must be `collector`. **No ordering satisfies both**, and flipping `users.role` between the two calls does not help — the caller's role is re-read by the authorizer on every request (`authorizerResultTtlInSeconds = 0`), so the account is never both at once.

So the options were a second Firebase identity provisioned purely to create three rows, or a direct insert. The second was chosen.

**This is not a defect in the API.** Assigning yourself to your own Task is not a real workflow — FR-ADM-03 is an Admin assigning *Collectors*, plural, from a directory. It is a limitation that only a single-account test rig encounters, and it is recorded here so that a later reader does not mistake it for one.

### What the seed proves, and what it does not

**Proves:** BR-19's Collector-scoped join, live, through the real app — *"Checkpoint Project"* rendered in C-04 from `GET /v1/projects`, which is the first time that join has returned a row to a device rather than to a probe.

**Does not prove:** the three write routes. `createProject`, `createTask` and `assignCollector` have **no caller anywhere in `lib/`** — Mission 7.4 step 4 recorded that when it implemented them, and their correctness still rests on unit tests alone. Seeding by hand leaves that exactly where it was, and it is owed to whichever mission builds Chapter 2.7's A-06 and the Task edit form.

The rows were shaped to match what the routes produce rather than to the minimum the columns allow: `org_id` and `created_by` derived from the `users` row rather than typed in, and the `audit_log` entry written, because Chapter 4.2 §2 makes that table an *"append-only record of Admin actions"* and a Project with no trail is a record of nothing.

**Cleanup is `archived_at = now()`, never a delete.** The sessions and chunks the checkpoint produces reference these rows, and no role in this backend holds SQL `DELETE` — deliberately.

---

### A-211 — Chapter 4.5 §2 never says what "no GPS fix" looks like, and the two halves chose differently

| | |
|---|---|
| **Volume** | 4, Ch. 4.5 §2 — nests `lat`/`lng` under `capture_conditions.gps`, and stops there |
| **Says** | Nothing about how an absent fix is spelled |
| **Client sends** | `{gps: {lat: null, lng: null}}` — object always present, members null |
| **Backend accepted** | `gps: null` or the key absent. A present object required **both** members to be numbers |
| **Result** | `400 REQUEST_INVALID` on **every** metadata POST from a device without a fix |
| **Fixed by** | Widening `lat` and `lng` to `v.nullish` individually |
| **Date** | 2026-08-20, Mission 7.4 device checkpoint |

Found by the first real upload this project has ever performed: session registered, chunk registered, three parts in S3, and then the metadata refused.

### Neither half was careless, and both cited the requirement

FR-META-05 makes these fields *"nullable where permission/condition dependent"*, and migration `0004` quotes that line directly above `gps_lat numeric, gps_lng numeric`. Both sides knew GPS was optional.

The client's document type argues its shape in writing: *"The `gps` object is always present, with null members when `hasFix` is false — omitting the key entirely would make 'no fix' and 'field not implemented' the same wire value."* That distinction is real.

The backend's schema wrapped the object in `v.nullish` and left the members strict, which is the natural reading of a chapter that nests them.

**Two defensible readings of a chapter that decides neither.** Each half's tests sent its own shape, so each was green, and nothing compared them until a device did.

### The storage model was the tie-breaker, and it had already decided

`chunk_metadata.gps_lat` and `gps_lng` are **two independently nullable columns**, not a composite. A validator requiring both-or-neither is therefore **narrower than the table it writes to** — it rejects a half-fix the schema permits, which is not a policy choice anybody made. Widening the members restores the validator to the shape of its own storage.

The read path needed no change: `nullableNumeric('gpsLat', gps?.lat)` already treats `null` and `undefined` identically, so all four spellings — absent, null object, null members, real fix — bind correctly. **Checked before the change, not after.**

### The third instance this mission, and the pattern is now worth a name

| | Where | How found |
|---|---|---|
| A-206 | `collector_id` — Firebase uid vs `users.id` | Reading the backend's join |
| A-207 | `session_id` — local vs backend session | Reading the backend's join |
| A-211 | `gps` — absence spelled two ways | The first real request |

**Each half was internally consistent, thoroughly tested, and correct with respect to its own source. The seam between them had never been exercised.** That is not three coincidences; it is one structural property of how this project is built — a client and a backend developed against the same chapters, by the same reasoning, in separate missions, each verified against its own reading.

Unit tests on either side are **structurally incapable** of catching this class. A client test asserts the payload the client builds; a backend test asserts the payload the backend expects; both pass, and the two payloads are never the same object. The only artifact that compares them is a real request.

A-195 is the same shape in the security medium — *"a capability's real extent is the intersection of what IAM permits and what the invoked code does with it"* — and A-205 and A-208 are the same shape in the toolchain medium, where a check's green did not depend on the thing it appeared to check.

**What would actually close it** is a contract artifact both halves derive from rather than both interpret: Chapter 4.6 §6 defers exactly this to *"a generated OpenAPI schema"* that does not exist, and the absence has now cost three defects in one mission. That is a real proposal for a later mission, not something to retrofit here. Recorded as open item 112.

### One diagnostic weakness noticed while tracing, not fixed here

`writeMetadata` renders **only the first validation issue**: `const [first] = parsed.issues;`. `v.safeParse` collects all of them. So a document with three problems is refused three times, one round trip each — and after tonight's refusal there was no way to tell whether GPS was the only blocker or the first of several. Reporting every issue would have answered that in one request. Left alone because this mission's device checkpoint is mid-flight and changing error rendering under it would be its own risk; recorded as open item 113.

---

### A-212 — Two numeric helpers omitted the type hint every other parameter carries

| | |
|---|---|
| **Record** | `functions/metadata/src/index.ts` — `numericParam`, `nullableNumeric` |
| **Did** | `{ name, value: { stringValue: String(value) } }` — no `typeHint` |
| **Postgres said** | `column "zoom_factor" is of type numeric but expression is of type text` — SQLState **42804** |
| **House pattern** | `uuidParam` sends `typeHint: 'UUID'`; `jsonParam` sends `'JSON'` |
| **Fixed by** | `typeHint: 'DECIMAL'` on both |
| **Status** | **Closed** |
| **Date** | 2026-08-20, Mission 7.4 device checkpoint |

Every metadata POST that passed validation then failed with `500 INTERNAL_ERROR`. The client sees Chapter 2.9's generic message by design, so the cause was only visible in the Lambda's own CloudWatch log.

### A-211 did not cause this — it unmasked it

`gps_lat`, `gps_lng` and `zoom_factor` are the **only three `numeric` columns in the entire schema**, and all three are bound by these two helpers. Before A-211, a device with no GPS fix was refused at validation, so the INSERT never ran. After it, the INSERT ran — and `gps_lat`/`gps_lng` bound as **typed nulls** (`isNull: true`), which Postgres accepts for any column, so they passed. `zoom_factor` is `NOT NULL` and always carries a value, so it was the first to hit the untyped path.

The defect predates both. **Any successful metadata POST would have failed on `zoom_factor` at any point since migration `0004`** — there had simply never been one.

### Why no test could have caught it, and what changed

Every backend test uses `aws-sdk-client-mock`. The statement is asserted to be **sent**; it is never **accepted** by a real Postgres. No INSERT in this project had ever reached a database until tonight.

That is not a gap in test coverage so much as a limit on what a mocked test can mean — and it has a partial remedy, now applied: **assert the properties of the send that determine whether it will be accepted.** The new test checks that `zoom`, `gpsLat` and `gpsLng` each carry `typeHint: 'DECIMAL'`, which is checkable under the mock and fails the moment the hint is removed. A type mismatch is not fully preventable this way, but the specific class — *a non-text column bound as a bare string* — now is.

### The sweep, done by reading rather than by a third device failure

Asked whether other columns share the defect, before redeploying:

- **Three `numeric` columns exist in the whole schema**, all in `chunk_metadata`, all bound by these two helpers. No other function touches one.
- `integer` columns use `longParam` — `{ longValue }`, a typed number, correct.
- `timestamptz` columns are cast in the SQL (`:startedAt::timestamptz`), correct.
- `jsonb` uses `jsonParam`'s `'JSON'` hint; `uuid` uses `uuidParam`'s `'UUID'`.

**So the blast radius is exactly these three bindings**, and the fix is at the helper rather than at the call site — a cast in this one INSERT would have left the trap armed for the next numeric column anyone adds.

### One thing deliberately not done

These two helpers are private to `functions/metadata/`, while every other parameter helper lives in `packages/shared/src/row.ts` beside `uuidParam` and `jsonParam`. That is where the next person will look, and where a fourth numeric column would go wrong again. Moving them is the consistent change and it is **not** made here: this is a live device checkpoint, and relocating a shared helper mid-run is its own risk. Open item 114.

### Third and fourth of a pattern

A-206, A-207 and A-211 were each a **seam between two halves** that were individually correct. This one is different in shape and identical in cause: **a claim verified against a stand-in rather than against the real thing.** A-205's build check read a stale artefact; A-208's syntax passed an analyzer that was not the one that mattered; this passed a mock that cannot reject. In every case the green was real and measured the wrong object.

---

### A-213 — The first end-to-end upload in this project's history, and what it cost to get there

| | |
|---|---|
| **What** | One chunk recorded on CPH2707, uploaded to S3, verified, and completed in Aurora |
| **When** | 2026-08-20, Mission 7.4 device checkpoint |
| **Previously** | **Zero.** No chunk had ever reached `uploading` on a device; no metadata POST had ever succeeded, in any environment, by any client |
| **Bugs found live** | Two, both real, both fixed and redeployed during the run — A-211, A-212 |

### The chain, as observed

| Stage | Evidence |
|---|---|
| Sign-in | `200 POST /v1/auth/verify`, real `userId` (a `users.id` uuid, not the Firebase uid — A-206's fix, live) |
| BR-19's join | `GET /v1/projects` returned `data: []` before seeding and the seeded Project after — **the empty answer is half the proof**, since it shows the join ran and matched nothing rather than failing open |
| Session | `201 POST /v1/tasks/{taskId}/sessions`, and a repeat answered **200** — F5's idempotency and F34's no-caching argument, confirmed against the real backend rather than a scripted adapter |
| Chunk | `201`, `s3_object_key` composed from real org/project/task/session ids |
| Transfer | 3 presigned `PUT`s to S3, all 200 |
| Metadata | `201` — **after** A-211 and A-212 |
| Status | `200 PATCH .../status`, **14,457 ms** |
| Backend | `sessions.status = complete`, `chunks.status = complete`, `chunk_metadata.verified_at` populated |

Every one of those had been proven in isolation and none of them together. The database state is the part that matters: `verified_at` populated means `chunks-verify` downloaded the object, recomputed the hash, matched it against what the device registered, and then `complete_chunk()` and `complete_session()` both ran — BR-21 and FR-SES-02 satisfied by the machinery rather than by assertion.

### Gap 9's resume, observed rather than inferred

The status `PATCH` took **14,457 ms**. Mission 7.3 Part 3 set the Lambda timeout to 28 seconds from three measured Aurora resume times — 15876, 15889 and 15428 ms — and A-178 recorded them. Tonight's figure is a fourth measurement of the same phenomenon, from a real device on a real network, and it sits inside the same band.

That is worth recording for two reasons. It is the first confirmation that the 28-second decision holds against a **client** request rather than a probe, and it is a reminder that the margin is roughly 13 seconds — comfortable, not generous. A resume plus a cold start plus the chunk hash is the stacked case A-186's timing note put near 40 seconds, and that case has still never been observed.

### The two bugs, and what they have in common

Full traces are in A-211 and A-212. The property worth stating here is the one they share with A-206 and A-207 before them, and with A-205 and A-208 in the toolchain medium:

**Every one was a claim verified against a stand-in rather than against the real thing.**

- A-206, A-207 — each half correct against its own reading; the seam never exercised.
- A-211 — two defensible readings of a chapter that decides neither.
- A-212 — a mock asserts what was **sent**, never what Postgres would **accept**. No INSERT in this project had reached a real database, so a defect dating to migration `0004` survived every green suite for four missions.

Six amendments, one shape: the verification was real and measured the wrong object. **The device is the first artifact in this project that could not be substituted for**, which is why one evening of it produced two defects that 203 backend tests and 1150 mobile tests could not.

### What is genuinely proven, and what is not

**Proven end to end, once:** the full Chapter 5.10 pipeline against the deployed backend, with real identity on every field, for a chunk of **3 parts**.

**Not proven, and stated plainly rather than implied by the milestone:**

- **The 38-part case.** Tonight's chunk was short. Part count, presigned-URL expiry across a long transfer, and `chunks-verify`'s hash of a 633 MB object inside its timeout are all untouched. F4 measured 7780 ms for the hash at 1769 MB against a *seeded* object; a cold start plus S3 first-byte latency on top of it remains the unmeasured stacked case.
- **The foreground service across a long upload** with the screen off and Android's battery optimiser active. Nothing in either suite exercises it.
- **A failed part, mid-transfer.** The retry ladder and the resume path ran clean tonight because nothing went wrong at step 2.
- **Three checklist items, deferred by decision rather than forgotten:** `deviceId` persistence across relaunch and reinstall, a second page via a small `?limit=`, and a real 404 firing the new copy. All three are covered by unit tests and each needed either a relaunch cycle or a temporary code change; the project owner deferred them once the core proof was in hand. **`nextCursor` has therefore still never been produced and consumed by anything real** — A-199's closure remains code-complete and device-unconfirmed.

### One process note

Both live-found bugs were fixed at the **root** rather than at the symptom, and the second was swept before redeploying: asked whether other numeric columns shared A-212's defect, the answer came from reading the schema — three numeric columns in total, all in one table, all through the same two helpers — rather than from a third device failure. That is the check that stopped this being three deploy cycles instead of two.

---

### A-214 — `dart format <directory>` swept 27 generated files into a commit, and the check that would have caught it had already run

| | |
|---|---|
| **Record** | Commit `d76acea`, Mission 7.4 Phase 2 |
| **Should have touched** | 2 generated files — `local_session.g.dart`, `recording_session.freezed.dart` |
| **Actually touched** | **29**, at +6090/−4904 |
| **Caught by** | CI's *Generated code drift* job, on PR #17 |
| **Status** | **Closed.** Raw generator output recommitted; committed now equals generated |
| **Date** | 2026-08-20, Mission 7.4 |

`dart format lib/` formats every Dart file under `lib/`, generated ones included. CI's format job **deliberately excludes** `*.g.dart` and `*.freezed.dart`, with a comment saying why — they would be reformatted by the next `build_runner` run — while the drift job diffs the generator's **raw** output. Formatting them therefore breaks the drift check by construction.

### The verification failure is the part worth recording

**The right check was run, at the wrong moment.** Mid-phase, after regenerating, `git diff --numstat -- '*.g.dart' '*.freezed.dart'` returned exactly the two genuinely-changed files. That was true when it ran.

A later step in the **same phase** ran `dart format lib/` after further edits, which re-swept all 29. Nothing re-checked. `git add -A` then committed them, and the phase was reported complete with the earlier verification still standing as though it described the commit.

So the sequence was: **verified correctly → invalidated by a later step → reported as still valid.** A stale check is not a weaker check; it is a statement about a state that no longer exists, which is exactly A-205's shape — there a build check read an artefact from a previous run, here a diff check described a working tree from earlier in the same phase.

### And the diagnosis it produced was wrong

Asked to investigate, the first conclusion offered to the project owner was that this was **a pre-existing `develop` condition**, on the reasoning that the 35 failing files included Mission 3-era ones — `gps_fix.freezed.dart`, `device_fingerprint.freezed.dart` — that Mission 7.4 never touched.

That reasoning was backwards. **Those files were in the list precisely because `dart format lib/` had touched them.** The evidence cited for "not mine" was the defect itself.

It was settled by testing rather than by argument: branching from `origin/develop`, clearing `.dart_tool/build`, and regenerating produced **zero diff**. `develop` has always been clean. The correction was issued before any fix was proposed on that false premise — but a whole plan (a separate PR to `develop`, then a rebase) had already been agreed on it.

### Third occurrence in one session, and the first to survive

| # | Where | Outcome |
|---|---|---|
| 1 | `prettier --write` on a glob, Mission 7.3 | Caught, 18 files restored |
| 2 | `dart format lib/ test/` during Step 4 | Caught by `git diff --numstat`, 33 files restored |
| 3 | `dart format lib/` during Step 5 Phase 2 | **Committed.** Caught by CI, two days of work later |

The first two were caught because the check ran **last**. The third was not, because it ran in the middle.

**Discipline is evidently not sufficient.** Three occurrences in one session, by the same hand, knowing about the trap, having already reverted it twice. The durable fix is tooling that makes the sweep impossible rather than a habit of checking afterwards — recorded as the fifth entry on open item 115.

### One consequence worth stating

No content was lost or altered. The two states differ **only** in whitespace, confirmed by formatting the regenerated output and observing a zero diff before deciding what to commit — and the entire history is recoverable either way, since both forms are generated from the same sources by the same pinned toolchain.

What it cost was not correctness but **trust in a green check**: PR #17's drift failure was read first as a version-pinning problem, then as a `develop` condition, before it was read as what it was.

---

### A-215 — The upload chain at full 38-part scale, and the case it still does not cover

| | |
|---|---|
| **What** | A 15-minute recording on CPH2707 → two chunks → S3 → Aurora, all complete |
| **Chunk 1** | 38 parts, ~633 MB, `chunks-verify` **Duration 8,681 ms**, `Init Duration` **383 ms** |
| **Chunk 2** | 19 parts, ~305 MB, **Duration 4,596 ms**, fully warm |
| **Aurora** | **Warm on both.** No resume in either measurement |
| **Ceiling** | 28,000 ms Lambda timeout, API Gateway 29 s behind it |
| **Date** | 2026-08-20, Mission 7.4 scale checkpoint |

A-213 recorded the first end-to-end upload, at three parts. This is the same chain at the size it was designed for. Both chunks show `status = complete` with `chunk_metadata.verified_at` populated, and the session `complete` — confirmed in the database, not inferred from a log.

### What two chunk sizes bought that one could not

Two measurements of the same code path at different sizes is a fit, and it answers the variable Mission 7.3's F4 could not measure — `CompleteMultipartUpload` on a real 38-part object, which F4 had timed only against a small one:

| | |
|---|---|
| **Hash throughput** | **77–81 MB/s** (chunk 2's size is inferred from its part count, hence the range) |
| **Fixed overhead** | **~450–870 ms** — S3 assembly, `complete_chunk()` and `complete_session()` combined |

**F4 independently measured 81.4 MB/s** at 1769 MB against a seeded object. Two unrelated measurements of the same operation, agreeing — which is worth more than either alone, and retires the worry that assembling 38 parts might cost seconds. It does not: the hash dominates and everything else is under a second.

### The stacked worst case is still unobserved, and tonight makes it *more* interesting rather than less

Aurora was warm both times. **Gap 9's resume is the largest single term in the stack and it did not occur.** So the numbers above are the floor of the distribution, not its tail.

Composing tonight's real figures with Gap 9's four measured resumes (13,877 / 15,428 / 15,889 ms, plus the 14,457 ms whole-request figure from A-213):

```
init 383 ms + warm work 8,681 ms + resume  →  22,941 – 24,953 ms
                                   margin  →   5,059 –  3,047 ms
```

**Three to five seconds of margin against a 28-second ceiling.** That is an arithmetic composition of observed parts, not an observation — nothing has yet run cold-Aurora *and* full-size in one invocation. It is the closest thing this project has to a prediction of the case that fails, and it is thin enough that a slower-than-measured resume, a colder start, or a larger chunk would cross it.

**Why the margin cannot simply be widened:** the Lambda timeout is 28 s because API Gateway's REST integration timeout is 29 s. Raising one without the other achieves nothing, and raising the quota is the request already queued from Mission 7.3.

### The foreground service survived an unattended, un-exempted run

**Exactly one `starting —` line in the entire 15-minute capture** — the initial launch. No relaunch during recording or during the 38-part upload, with the app **not** exempted from battery optimisation on a OnePlus running OxygenOS, whose battery management is among the more aggressive.

That was the deliberate choice: test *"works as shipped"* rather than *"works when the OS cooperates."* It held for this run.

**The screen state is genuinely unknown, and the result must be read accordingly.** Screen state during the run was **not actively monitored**. The device was not touched during recording, which makes an idle/screen-off period likely at some point in a 15-minute run — but this was not confirmed, and the timing is unknown.

So the survival result reads as **"survived an unattended, un-exempted 15-minute run"**: evidence in the right direction, and *not* a confirmed test of the specific screen-off case Chapter 5.11 targets. An idle, screen-off device is what Android's battery management actually goes after, and whether the device reached that state — or for how long — is not in evidence.

**A future run with an explicit, timestamped screen-off/screen-on log line would close this precisely.** Until then the distinction is not pedantry: the un-exempted choice was made specifically to test the harder condition, and an unattended run may or may not have reached it.

### Everything else held, and two of them were never in doubt

- **Presigned URLs** — 57 parts, no `403 SignatureDoesNotMatch`, nowhere near the 3,600 s window. The floor required to fit 608 MiB is ~1.4 Mbit/s sustained; a normal connection uses under a tenth of the budget. This was arithmetic before it was a test.
- **Part sequencing** — 38 then 19, no gaps and no retries, confirmed against the S3 key sequence numbers `0000` and `0001`.
- **`complete_session()` across two chunks** — the session completed only after both, which is FR-SES-02 working over a multi-chunk session rather than the single-chunk case A-213 covered.

### What this entry is for

So that a later reader finding *"38-part scale test passed"* does not conclude the timeout question is closed. It is not. **The chain works at full scale under warm-Aurora conditions, and the condition under which it might not has still never occurred.** Tonight moved that from "unmeasured in every term" to "measured in every term but one, composed to a 3–5 second margin" — which is real progress and is not the same as coverage.

---

### A-216 — A cursor was produced and consumed for the first time, closing A-199

| | |
|---|---|
| **Was** | A-199 closed A-184 in code. `nextCursor` had **never been produced and consumed by anything real** — proven on each side separately, never across the seam |
| **Now** | Two live requests, the second carrying the cursor the first returned |
| **Status** | **Closed** |
| **Date** | 2026-08-20, Mission 7.5 F2 |

```
→ GET .../v1/projects/4889ca14-.../tasks?limit=200
← 200   meta: { nextCursor: WyIyMDI2LTA4LTIwIDA5OjIxOjUzLjc0OTU2NCIs… }
→ GET .../v1/projects/4889ca14-.../tasks?cursor=WyIyMDI2…&limit=200
← 200   2 rows, meta: { nextCursor: null }
```

### The cursor's contents confirm the whole design, not just the round trip

Base64url-decoded, the value the client sent back is:

```json
["2026-08-20 09:21:53.749564", "01453c85-a147-41cb-b1da-71be23735f01"]
```

`cursor.ts`'s `(created_at, id)` keyset pair, verbatim, in the Data API's own timestamp format. **The client neither parsed nor modified it** — which is the property opacity exists to protect: *"callers are told nothing about the contents"*, so the sort key can change later without a `/v2` under Chapter 4.6 §1.

Three further things are confirmed by the same two requests:

- **The ordering is total and correct.** `created_at DESC, id DESC` put *Checkpoint walkthrough* — seeded a session earlier than everything else — on the last page. A-183 chose a total order because *"a cursor needs one or pages can overlap"*; this is that order behaving.
- **`nextCursor: null` ends the list**, so the client stopped rather than requesting an empty third page. `pageMeta`'s fetch-one-extra design is what avoids that, and it worked.
- **Base64url survived a query string** unmangled — the specific failure this test existed to rule out, since a `+` or `/` from standard base64 would have been corrupted in transit.

### What it took to reach, which is the part worth recording

Three attempts, and the first two failed for reasons that were not the client's:

1. **One Project, page size 200.** No second page exists, so no *Load more* control renders — the absence of the control was the control working, and read as a missing feature.
2. **201 Tasks seeded with no `task_assignments` rows.** `listTasks`'s Collector branch joins assignments **per Task** — Chapter 4.8 §3 scopes a Collector to *"their own `task_assignments` rows"*, not to the Projects those imply — so the server correctly returned the one assigned Task. BR-19 working, read as a caching fault.
3. **A cached family member.** `tasksProvider` has no `autoDispose`, so re-navigating served state from the first load and issued no request. Deliberate and documented — but tracing it surfaced open item 117, which is not.

**Each failure looked like a client defect and was not.** That is the shape worth carrying: at a seam this well guarded, *"the data isn't showing"* is more often the guard than the bug, and the cheapest first question is whether the row is visible to the *route's own query* rather than whether the client fetched it.

---

### A-217 — A-186's 404 drove its copy on a device, and the screen is sufficient evidence

| | |
|---|---|
| **Was** | The 404 → copy path added by F28/F29 after A-207. Unit-tested on both sides; the deployed backend had never driven it |
| **Now** | C-05 rendered *"This Project isn't available to you."* against a live `RESOURCE_NOT_FOUND` |
| **Method** | A temporary probe pointing `tasksProvider` at `00000000-0000-4000-8000-000000000000` — well-formed, so it passes `pathUuid` and fails `assertProjectVisible` |
| **Status** | **Closed** |
| **Date** | 2026-08-20, Mission 7.5 F3 |

The log capture was lost to buffer rotation. **The on-screen result is still conclusive**, and the reason is worth writing down rather than asserting.

### Why the copy entails the backend's answer

That sentence is reachable from exactly two places in `collector_project_detail_screen.dart`:

1. **Line 73** — the `AsyncError` branch, when `classifyReadFailure(error)` returns `notVisible`.
2. **Line 105** — inside `_TaskList`, when `project == null`.

Path 2 is excluded twice over: `_TaskList` builds only on `AsyncData`, and the probe changed only the `tasksProvider` **argument**, leaving the widget's own `projectId` intact — with Checkpoint Project confirmed present on C-04, `project` was non-null.

So path 1 fired, and it is a chain of implications rather than an inference:

```
copy rendered
  → classifyReadFailure(error) == notVisible
  → error.backendCode == 'RESOURCE_NOT_FOUND'
  → the response carried an envelope error with that code
  → ApiError.notFound(), which is status 404
```

`backendCode` is populated only from an envelope's `error.code` (F29), and `RESOURCE_NOT_FOUND` is emitted only by `ApiError.notFound`. **Nothing else in the codebase can put that string on that screen.**

**What was not directly observed** is the HTTP status line itself. It is entailed by the above rather than read, and that distinction is recorded rather than glossed — the four failure signatures were all absent, which is corroboration, not proof.

### What it closes

The last of A-186's chain to reach a device. The backend's decision to report a resource outside the caller's reach as **absent rather than forbidden** — because *"403 confirms the id exists, which is precisely what a guessed id is asking"* — now has a client that renders it correctly, in copy that claims neither *"not assigned"* nor *"does not exist"*, as BR-19 requires.

Before F28, this case rendered *"Check your connection"* — pointing a Collector at a working network over a stale link. That regression would have been the most valuable thing this test could find, and it did not occur.

### A note on evidence standards

This is the first checkpoint item in the project closed on **on-screen behaviour** rather than a captured log line. That is acceptable here **because the rendering path is deterministic and single-sourced** — one string, two call sites, one of them excluded by construction. It would not be acceptable for a claim about timing, ordering, or anything the UI summarises rather than reflects. The distinction is the point: behavioural evidence is sufficient exactly when the behaviour has one possible cause.
