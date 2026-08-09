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

---

## Confirmed correct — no amendment

Recorded so they are not re-litigated.

| Volume | Subject | Verdict |
|---|---|---|
| V5, Ch. 5.14 §1 | S3 object key schema | **Authoritative and implemented.** Unchanged by any ADR in this cycle. |
| V4, Ch. 4.10 §4 | Standard → Standard-IA → Glacier IR ladder | Correct. Adopted verbatim by ADR-012. |
| V8, Ch. 8.4 | SSE-S3, upgradeable to SSE-KMS only on contractual trigger | Correct and implemented. Not a placeholder — do not "upgrade" without the trigger. |
| V4, Ch. 4.10 §3 | No public access | Correct and implemented. |
| V4, Ch. 4.9 §4 | One bucket per environment | Correct and implemented, at the permitted minimum tier. |
