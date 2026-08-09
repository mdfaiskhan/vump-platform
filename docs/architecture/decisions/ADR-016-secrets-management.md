# ADR-016 — Secrets Management

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Reconciles Volume 7, Chapter 7.10 §2 with ADR-007 — see `docs/architecture/volume-amendments.md`.

## Context

Secrets are governed in three places that were written independently and do not fully agree.

**Volume 8, Chapter 8.4 §2** is unambiguous and correct: the Firebase Admin service account key and the Aurora credentials live in **AWS Secrets Manager**, referenced by ARN from each Lambda's configuration, *"never baked into a Lambda's plaintext environment variables, which would be visible to anyone with read access to the function's configuration."*

**Volume 7, Chapter 7.10** covers the Flutter side: `--dart-define-from-file` reading a per-environment `.env` file that is never committed, with only `.env.example` in the repository.

**ADR-007** independently decided that environment selection happens through `--dart-define=APP_ENV`, and that the API base URL belongs to `NetworkConfig` in `core/network/` rather than to configuration.

The conflict is narrow but real. V7.10 §2 lists `API_BASE_URL` and `S3_BUCKET_NAME` as variables supplied through the `.env` file. ADR-007 and ADR-011 place both in code — the base URL in `NetworkConfig`, the bucket in `environments.json`. Implemented as written, the base URL would have two sources of truth that could disagree per build, which is exactly the class of defect that produces a staging binary pointed at production.

A second gap emerged while implementing: nothing states what may *never* be a secret. The rule "don't hardcode secrets" is necessary and insufficient — it says where secrets may not go, not which of the three tiers a given value belongs to.

## Decision

### Three tiers, and a value belongs to exactly one

| Tier | Definition | Where it lives |
|---|---|---|
| **Public** | Extractable from a shipped binary or observable in traffic. Concealing it protects nothing. | Source control |
| **Configuration** | Non-secret, varies per environment. | `.env` files and Lambda environment variables |
| **Secret** | Possessing the value grants capability. | **AWS Secrets Manager only** |

The test for the third tier is capability, matching ADR-008: *if holding the value lets someone act as the user or as the application, it is a secret.*

Firebase client identifiers, S3 bucket names, base URLs, ARNs and region names are **not** secrets — they fail the capability test, and ADR-007 and ADR-010 already record why. A secret ARN is an identifier; it grants nothing without IAM permission to read what sits behind it.

### The mobile application holds no secret of any kind

Not an AWS credential, not a Firebase service account, not an API key. A Flutter binary is distributed to devices outside our control and can be decompiled, so anything compiled into it is published.

`mobile/.env.*` therefore contains **`APP_ENV` and nothing else**. This is the reconciliation of V7.10 with ADR-007: V7.10's *mechanism* is adopted — `--dart-define-from-file` is better than a stack of bare `--dart-define` flags, and it is already wired into the launch configuration — but the file's *contents* are reduced to the single value ADR-007 defines. API base URL, bucket name and timeouts continue to be derived in code from that one input.

One input, not four. There is no build in which the environment and the base URL can disagree, because there is nothing to disagree with.

The files stay uncommitted, per V7.10, even though they hold no secret. They are per-developer, and a committed `.env` becomes a habit-forming place for someone to later add something that should not be there.

Anything the app genuinely needs and must not hold is fetched from the backend, authenticated with the user's Firebase ID token. That is the same principle as the presigned upload flow: the device receives a scoped capability, never an identity.

### The backend uses IAM roles in AWS and the provider chain locally

In AWS, credentials come from the **Lambda execution role**, resolved by the SDK's default provider chain. Locally, the same chain resolves a named CLI profile. **The code path is identical**; there is no local-mode branch, so nothing can behave differently in the place it is hardest to observe.

`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` appear nowhere — not in `.env.example`, not in CI, not in Lambda configuration. Any task that appears to require them requires a profile or a role instead.

### Secret values come from Secrets Manager, never from environment variables

Per V8.4 §2. Lambda environment variables carry the **ARN**; the function resolves the value at runtime through its execution role.

Two secrets are known today: the Firebase Admin service account key, rotated manually on an annual cadence or immediately on suspected compromise, and the Aurora credentials, rotated automatically by Secrets Manager's native RDS rotation. Naming convention: `vump/{environment}/{secret-name}`.

### Compromise means rotate first

A committed secret is disclosed permanently. Deleting it in a later commit does not remove it from history, and history is readable by everyone with repository access, including anyone who cloned before the deletion.

**The first action is always to rotate the credential, not to rewrite history.** Rewriting history is cleanup; rotation is containment. A team that reverses that order spends its first hour on the part that does not stop the bleeding.

## Alternatives Considered

- **Secrets in Lambda environment variables** — rejected by V8.4 §2. They are visible to anyone with `lambda:GetFunctionConfiguration`, which is a much wider set of principals than those who can read a specific secret.
- **Secrets in SSM Parameter Store (SecureString)** — a reasonable alternative and cheaper, but it lacks the native RDS rotation V8.4 §2 relies on for Aurora credentials. Splitting secrets across two services to save a small amount would give two places to audit.
- **`API_BASE_URL` in the `.env` file, per V7.10 §2 as literally written** — rejected. It creates a second source of truth for a value ADR-007 assigns to `NetworkConfig`, and the failure mode is a build pointed at the wrong environment.
- **`flutter_dotenv` loading a runtime `.env` asset** — rejected, and V7.10 §4 already rejected it: compile-time values cannot be swapped by a config file that shipped in the bundle by mistake.
- **Committing `mobile/.env.*` since they hold no secret** — tempting and defensible, rejected. The files are per-developer, and a committed one invites a future secret.
- **A hosted secret-scanning service on the repository** — not rejected, deferred. GitHub secret scanning and push protection should be enabled; that is an account setting rather than an architecture decision.

## Consequences

- Every value has exactly one home, and the tier test decides which.
- A leaked `mobile/.env.prod` discloses the string `production`. That is the whole blast radius, by construction.
- Secrets rotate without a deployment, because nothing holds a copy.
- Every secret read costs a Secrets Manager API call. Functions should cache within an invocation and across warm invocations, and must never log the result.
- Local development requires a configured AWS profile. This is friction, and it is the friction that keeps access keys out of the repository.
- V7.10 §2's variable table is now wrong in the repository's view. The amendment register records it.
- The backend does not exist yet, so its half of this decision is a contract rather than a verified implementation.
- Nothing here prevents a determined person from pasting a secret into a file. CI scanning narrows the window; it does not close it.

## Related Missions

- Mission 0.17.15 — AWS SDK Integration, which established the credential strategy this extends.
- Mission 0.17.16 — Secrets Management, which produced this ADR.

## Implementation Status

**Partially implemented.**

| | Decision | Current state |
|---|---|---|
| Mobile holds no secret | Required | ✅ Verified, and enforced by CI |
| `mobile/.env.example` | `APP_ENV` only | ✅ Created |
| `--dart-define-from-file` | Mechanism adopted | ✅ Implemented in Mission 0.17.17 |
| Backend uses IAM roles | Required | ⬜ Backend does not exist |
| Secrets Manager for values | Required | ⬜ No secret created; no Lambda to read one |
| `backend/.env.example` | Contract documented | ✅ Created |
| `.gitignore` blocks secrets | Required | ✅ Verified against 9 patterns |
| CI secret scanning | Required | ✅ Implemented |

The `--dart-define` mechanism this ADR depends on was implemented in Mission 0.17.17. The outstanding items are backend-side and blocked on the backend not existing.
