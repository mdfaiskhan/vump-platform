# ADR-014 — Environment Strategy

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Extends Volume 4, Chapter 4.9 §4, which defers the exact account structure to Volume 7.

## Context

Three environments now exist in AWS as S3 buckets, and three exist in the mobile application as `AppEnvironment` values (ADR-006, ADR-007). Nothing yet says what each is *for*, how code moves between them, or what may be true in one and not another.

Volume 4, Chapter 4.9 §4 states the preference — separate AWS accounts per environment — and defers the structure to Volume 7. Mission 0.16 defined the Git branching strategy and the promotion path through `develop` → `release/*` → `main`, but stopped at the repository boundary. The gap between "a branch was merged" and "an environment changed" is undefined, and that gap is where deployment accidents live.

This record closes it. It does not decide CI/CD tooling — that is Mission 0.18 — only what the environments are and what promotion means.

## Decision

### Purpose of each environment

| | Development | Staging | Production |
|---|---|---|---|
| **Purpose** | Build and integrate | Verify a release candidate | Serve real Collectors |
| **Data** | Synthetic, disposable | Synthetic, production-shaped | Real field recordings |
| **Deployed from** | `develop` | `release/*` | `main` |
| **Deploys** | On merge to `develop` | On release branch cut | On tag, with approval |
| **Stability** | May be broken | Must be releasable | Must not break |
| **Audience** | Engineers | Engineers, QA, stakeholders | Collectors and Admins |
| **S3 bucket** | `vump-platform-dev` | `vump-platform-staging` | `vump-platform-prod` |
| **`APP_ENV`** | `development` | `staging` | `production` |
| **Object retention** | 30 days | 90 days | 24 months (ADR-012) |

**Development** absorbs breakage. It is the only environment where a broken state is acceptable, and it holds no data anyone would mourn.

**Staging is the rehearsal, not a second development environment.** Its value comes entirely from resembling production — same configuration mechanism, same IAM shape, same lifecycle behaviour where affordable. Every divergence introduced for convenience reduces what a staging pass actually proves. It still holds synthetic data: staging is not a place to debug against real recordings.

**Production** holds evidentiary footage under the retention and legal-hold obligations of Volume 8, Chapter 8.7. It is the only environment where deletion is irreversible in a way that matters.

### Promotion workflow

Promotion moves an **artifact**, never a rebuild:

```
feature/* ──► develop ──────────► release/x.y.z ──────────► main ──► tag vx.y.z
                 │                      │                              │
              Development            Staging                      Production
              (automatic)           (automatic)                (manual approval)
```

1. Work merges to `develop` and deploys to Development automatically.
2. Cutting `release/x.y.z` deploys that commit to Staging automatically.
3. Staging is verified. Fixes commit to the release branch and redeploy to Staging.
4. The release branch merges to `main` and is tagged.
5. Production deploys from that tag, **after explicit human approval**.
6. The release branch merges back into `develop` so fixes are not lost.

**The same build artifact is promoted at each stage.** Rebuilding per environment means the thing verified in Staging is not the thing that reaches Production — the difference may be a dependency resolved a day later, and it will be discovered in Production. Environment differences come from configuration injected at deploy time, never from a separate build.

`--dart-define=APP_ENV` (ADR-007) is the mobile-side mechanism. Its value is set by the pipeline, never by a developer's local default.

### Deployment flow

| Environment | Trigger | Approval | Rollback |
|---|---|---|---|
| Development | Merge to `develop` | None | Redeploy previous commit |
| Staging | Release branch push | None | Redeploy previous release |
| Production | Tag on `main` | **Required, human** | Redeploy previous tag |

Every deployment records what was deployed, from which commit, by whom, and when. A production deployment that cannot be attributed cannot be audited, and Volume 8 treats auditability as a security property rather than an operational nicety.

Production is never deployed from a branch. Only a tag, which is immutable and points at a reviewed, released commit.

### Release strategy

Semantic versioning, `vMAJOR.MINOR.PATCH`, matching Mission 0.16's branching strategy — major for a breaking interface change, minor for backwards-compatible capability, patch for defect fixes.

`mobile/pubspec.yaml`'s version and `AppInfo` (ADR-006) match the tag. ADR-006 already records that all three move together until version is read from the platform bundle.

**Hotfixes** branch from `main`, deploy to Staging for verification, then to Production on a patch tag, and merge back into `develop`. The verification step is not skipped under pressure: an unverified hotfix is how one incident becomes two.

### Account strategy

**Current implementation:** a single AWS account holding all three environments, separated by bucket and by IAM policy.

**Target architecture:** separate AWS accounts for Development, Staging and Production.

**Migration:** deferred until production scale.

Volume 4, Chapter 4.9 §4 permits the current arrangement as the minimum, so this is a compliant intermediate state. The cost is blast radius — one account means a misapplied policy can reach production from a development context, and IAM is the only thing preventing it.

Two things make the eventual migration cheaper, and both apply from now: environment is always an explicit input, never inferred from context; and no resource name assumes a shared account.

## Alternatives Considered

- **Two environments — development and production** — rejected. It leaves no place to verify a release candidate against production-shaped configuration, so the first execution of a deployment path is always in production.
- **Separate AWS accounts now** — rejected as premature. It is the target, but it adds AWS Organizations, cross-account roles and consolidated billing before there is production data to protect. Volume 4.9 §4 explicitly permits deferral.
- **Rebuild per environment** — rejected. It breaks the guarantee that what was verified is what ships.
- **Deploy Production from `main` on merge, without approval** — rejected. A merge is a code-review decision; a release is an operational one, and they are not the same judgement.
- **Ephemeral per-pull-request environments** — attractive, rejected for now. Real value for review, but it requires infrastructure-as-code that does not exist yet (Volume 4.9 §5 defers the tooling choice). Revisit after Mission 0.18.
- **Production-data copies in staging for realistic testing** — rejected outright. It would place real recordings of identifiable people in an environment with weaker access control, contradicting Volume 8's posture.

## Consequences

- Every environment has a stated purpose, so "which environment should this go to" stops being a judgement call.
- Production cannot be deployed accidentally: it needs a tag and a human.
- The promoted artifact is the verified artifact.
- Three environments cost roughly three times the infrastructure. Dev and staging expire objects aggressively (ADR-012) specifically to hold that down.
- Staging's value decays if it drifts from production. Drift is a defect, not a convenience, and needs periodic checking.
- Single-account isolation depends entirely on IAM correctness until migration. IAM review is therefore load-bearing rather than routine.
- Nothing here is automated yet. Until Mission 0.18, promotion is a documented manual procedure — which is still better than an undocumented one.

## Related Missions

- Mission 0.16 — Git & GitHub Foundation, which defined the branching and release model this builds on.
- Mission 0.17 — AWS Foundation, which created the three environment buckets.
- Mission 0.18 — CI/CD & Development Workflow, which will automate the flows described here.

## Implementation Status

**Partially implemented.**

| | Architecture decision | Current infrastructure |
|---|---|---|
| Three environments | dev / staging / production | ✅ S3 buckets exist |
| `AppEnvironment` enum | Three values | ✅ Implemented (ADR-006) |
| `--dart-define=APP_ENV` | Pipeline-supplied | ✅ **Implemented** in Mission 0.17.17; verified for all three environments and a typo case |
| Branching and release model | `develop` → `release/*` → `main` → tag | ✅ Documented (Mission 0.16) |
| `develop` branch | Exists and protected | ❌ Not created |
| Automated deployment | All three environments | ❌ Not built — Mission 0.18 |
| Production approval gate | Required | ❌ Not enforced |
| Separate AWS accounts | Target | ❌ Single account; deferred |

`--dart-define` is now implemented, so the client side of this model is real. The remaining gaps are pipeline-side: no `develop` branch, no automated deployment, and no enforced production approval gate — all of which belong to Mission 0.18.
