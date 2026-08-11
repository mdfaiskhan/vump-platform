# Vump Technologies

A production-grade platform for large-scale egocentric video data collection — a Flutter application for field Collectors, a serverless backend, and the storage and processing infrastructure behind them.

**Status: foundation.** No feature has been built yet. The mobile application starts, resolves its environment, and renders a placeholder screen. The backend does not exist.

---

## Repository layout

```
.
├── .github/          CI workflows, PR and issue templates
├── backend/          AWS Lambda + Node.js + TypeScript (ADR-015) — not yet implemented
├── docs/             Architecture decisions, source volumes, operations
├── infrastructure/   Version-controlled AWS configuration
├── mobile/           Flutter application
├── CLAUDE.md         Engineering constitution and governance rules
└── LICENSE
```

Each top-level directory is a deployment or governance boundary, not a grouping of convenience. `infrastructure/` holds declared AWS state and no application code; `backend/` holds code that runs and no AWS state; `mobile/` holds the Flutter app and no infrastructure; `docs/` holds decisions and never code.

There is no `scripts/` or `assets/` directory. Both are reserved with a defined purpose and trigger — and a root `assets/` can never hold the app's runtime assets, since Flutter resolves `pubspec.yaml` asset paths relative to `mobile/`. See [`docs/architecture/folder-structure.md`](docs/architecture/folder-structure.md) for the full rules, the import matrix, and how to add a feature.

---

## Documentation

| Path | Contents |
|---|---|
| [`docs/architecture/README.md`](docs/architecture/README.md) | **Start here.** How architectural decisions are recorded, changed and retired |
| [`docs/architecture/decisions/`](docs/architecture/decisions/) | ADR-001 to ADR-031 — every binding decision |
| [`docs/development/performance-standards.md`](docs/development/performance-standards.md) | The ten performance targets, what measures each, and what is unmeasured (ADR-031) |
| [`docs/development/dependency-management-standards.md`](docs/development/dependency-management-standards.md) | Pinning tiers, adding a package, review cadence, current staleness (ADR-030) |
| [`docs/development/testing-standards.md`](docs/development/testing-standards.md) | The testing pyramid, fakes, determinism, coverage, and what is absent (ADR-029) |
| [`docs/development/review-checklist.md`](docs/development/review-checklist.md) | How every change is reviewed, and what CI already gates (ADR-028) |
| [`docs/architecture/logging-standards.md`](docs/architecture/logging-standards.md) | Log levels, sinks, redaction, and what must never be logged (ADR-027) |
| [`docs/architecture/architecture-guardrails.md`](docs/architecture/architecture-guardrails.md) | Every architectural invariant, its authority, and what enforces it (ADR-026) |
| [`docs/architecture/folder-structure.md`](docs/architecture/folder-structure.md) | Folder architecture, import rules, and how to add a feature (ADR-022) |
| [`docs/architecture/error-handling.md`](docs/architecture/error-handling.md) | The error model — exceptions, failures, codes, logging, propagation (ADR-025) |
| [`docs/architecture/naming-conventions.md`](docs/architecture/naming-conventions.md) | The naming standard — suffix vocabulary, every category, known deviations (ADR-023) |
| [`docs/architecture/volume-amendments.md`](docs/architecture/volume-amendments.md) | Corrections to the source volumes, with the ADR that supersedes each |
| [`docs/volumes/`](docs/volumes/) | Source specification volumes 1–12 (PDF) |
| [`docs/git/`](docs/git/) | Branching strategy and commit conventions |
| [`docs/development/documentation-standards.md`](docs/development/documentation-standards.md) | How every document here is written (ADR-024) — read before adding one |
| [`docs/development/`](docs/development/) | Secrets management |
| [`docs/operations/`](docs/operations/) | Disaster recovery |

**Architecture documentation is the single source of truth.** Where code and an accepted ADR disagree, the ADR is correct and the code is a defect. Where a source volume and an accepted ADR disagree, the ADR governs and the amendment register records why.

---

## Getting started

### Mobile

```bash
cd mobile
cp .env.example .env.dev          # holds APP_ENV and nothing else
flutter pub get
flutter run --dart-define-from-file=.env.dev
```

Three environments — `development`, `staging`, `production` — selected by `APP_ENV`. Everything else (API base URL, S3 bucket, logging level, feature flags) is derived from that one value. See [ADR-018](docs/architecture/decisions/ADR-018-environment-profile.md).

```bash
flutter analyze
flutter test
dart format .
```

### Infrastructure

```bash
cp .env.example .env              # AWS profile and region for the scripts
aws s3api put-bucket-lifecycle-configuration --bucket vump-platform-dev \
  --lifecycle-configuration file://infrastructure/aws/s3/lifecycle-dev.json
```

See [`infrastructure/aws/README.md`](infrastructure/aws/README.md) for the full apply and verify procedure.

---

## Stack

| Layer | Technology | Decision |
|---|---|---|
| Mobile | Flutter, Riverpod, GoRouter, Dio, Isar | ADR-001, ADR-003, ADR-004, ADR-009 |
| Backend | AWS Lambda, Node.js, TypeScript, API Gateway | ADR-015 |
| Database | Aurora Serverless v2 (PostgreSQL) | Volume 4 Ch. 4.9 |
| Storage | S3, `ap-south-1` | ADR-011, ADR-012 |
| Auth & messaging | Firebase | ADR-010 |
| Secrets | AWS Secrets Manager | ADR-016 |

---

## Contributing

Read [`docs/git/branching-strategy.md`](docs/git/branching-strategy.md) and [`docs/git/commit-conventions.md`](docs/git/commit-conventions.md) before your first commit.

`main` and `develop` are protected. Every change arrives through a pull request with CI green: analyze, test, format, architecture boundaries, secret scan, environment consistency.

**Before implementing anything**, read `docs/architecture/README.md` and every accepted ADR. This is not a formality — it is rule 1 of `CLAUDE.md`, and several ADRs forbid patterns that would otherwise look reasonable.

---

## Security

No credential belongs in this repository. See [`docs/development/secrets-management.md`](docs/development/secrets-management.md) for what counts as a secret, where each value lives, and what to do if one is committed — **rotate first, rewrite history second.**

The mobile application holds no AWS or Firebase service credential of any kind, and CI enforces it.
