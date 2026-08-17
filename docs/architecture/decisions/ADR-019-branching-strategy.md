# ADR-019 — Branching Strategy

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Supersedes Volume 7, Chapter 7.6 §1 in part — see `docs/architecture/volume-amendments.md`. Complements ADR-014, which owns the environment model.

## Context

Two documents describe how work reaches production, and they do not agree.

**Volume 7, Chapter 7.6 §1** states: *"`main` is always deployable; feature branches (`feature/<short-description>`) are short-lived and merged via pull request, never pushed to directly."* That is trunk-based development — one permanent branch, no `develop`, no release branches.

**ADR-014**, accepted, maps branches to environments: `develop` deploys to Development, `release/*` to Staging, `main` to Production. That requires `develop` and `release/*` to exist.

Both are reasonable. They cannot both be followed.

Beyond that conflict, most of what a branching strategy has to decide is recorded nowhere binding. Merge strategy, review requirements, protection rules, status checks, conflict policy, branch deletion and tagging exist only in `docs/git/branching-strategy.md`, written in Mission 0.16 — a document, not a decision. Anyone may edit it without the governance an ADR imposes.

A third problem surfaced while auditing: that document requires *"at least one approving review"* on every pull request. **GitHub does not permit a pull request author to approve their own.** On a single-developer project that rule blocks every merge, so it would be quietly ignored — and a rule that is routinely ignored teaches that rules are optional.

## Decision

### Permanent branches

| Branch | Deploys to | Protected |
|---|---|---|
| `main` | Production, on tag, with approval | Yes |
| `develop` | Development, on merge | Yes |

**`develop` is retained**, so Volume 7 §7.6 §1 is superseded on this point. The reason is not preference: ADR-014 assigns each environment a branch, and staging exists to verify a release candidate that is no longer accumulating features. With `main` alone there is no branch that is "everything merged but not yet a release candidate", so either `main` becomes unstable or staging verifies something that was never a distinct state.

Trunk-based development is the better default for most teams and would be the right answer if there were one deployed environment. There are three (ADR-014), and the topology follows from that.

### Temporary branches

| Prefix | For | Cut from | Merges to | Typical life |
|---|---|---|---|---|
| `feature/` | New capability | `develop` | `develop` | Days |
| `fix/` | Defect, not urgent | `develop` | `develop` | Hours–days |
| `chore/` | Tooling, dependencies, config | `develop` | `develop` | Hours |
| `docs/` | Documentation and ADRs | `develop` | `develop` | Hours |
| `refactor/` | Structure, no behaviour change | `develop` | `develop` | Days |
| `release/` | Release stabilisation | `develop` | `main` **and** `develop` | Days |
| `hotfix/` | Urgent production defect | **`main`** | `main` **and** `develop` | Hours |

`hotfix/` is the only branch cut from `main`. Everything else starts at `develop`.

### Naming

```
<type>/<short-description>
<type>/<issue-number>-<short-description>
mission/<number>-<short-description>
```

Lowercase kebab-case, describing the change rather than the file touched. `mission/*` is a `feature/*` by another name, retained because this project is built in numbered missions.

Branch names are not secret and appear in logs and CI output. **Never encode a credential, customer name or personal data in one.**

### Merge strategy — and why it differs per target

| Into | Strategy | Reason |
|---|---|---|
| `develop` | **Squash** | One unit of work, one commit. `develop`'s history reads as a list of completed changes, not of the fumbling that produced them |
| `main` | **Merge commit** | Preserves the release branch and marks the release point as a distinct event |
| Back-merge to `develop` | **Merge commit** | Records that the back-merge happened; squashing would hide whether a hotfix reached `develop` |
| Updating a branch from `develop` | **Rebase** | Keeps the pull request diff honest — it shows what the change does, not what happened to the branch while it was open |

**Never rebase a branch someone else has pulled.** Rewriting shared history forces everyone else to recover by hand. If a branch is shared, merge into it instead.

The squash commit message is the one that survives, so it matters more than the commits it replaces. It follows `docs/git/commit-conventions.md`.

### Commit history philosophy

**History is written for the person doing archaeology, not for the person committing.**

Someone will one day run `git blame` on a line, find the commit, and need it to explain *why*. That reader is the audience. Two consequences:

- Every commit on a shared branch must build and pass tests. A commit that only works with the next one is one commit split by accident.
- `WIP`, `fixes`, `more changes` are save points, not history. Squash them before review, or rely on squash-merge — but write the squash message properly.

### Pull request requirements

Every change reaches a protected branch through a pull request. No exceptions, including for the sole maintainer — the point of the rule is that CI runs and the change is reviewable later, not that a second human is present.

A pull request must:

- Use the template in `.github/pull_request_template.md`.
- Pass every required status check.
- State the ADRs it implements or is constrained by, or that none apply.
- Satisfy the review checklist in **Volume 3, Chapter 3.7 §9** — layer direction, module boundaries, requirement traceability, clean static analysis, documented public APIs in `domain/` and `data/`, tests for the layer touched.
- Include documentation and ADR changes **in the same pull request**, per Volume 11 Chapter 11.8 — never as a follow-up task.

### Required reviewers — staged, because the team is one person

| Team size | Required approvals |
|---|---|
| 1 (today) | **0** — CI is the gate |
| 2+ | **1**, and never the author |
| 5+ | 1, plus a code owner for `infrastructure/` and `docs/architecture/` |

This is the honest position. GitHub forbids self-approval, so requiring one today would block every merge and the rule would be bypassed. Zero required approvals with mandatory CI is a real gate; a mandatory approval that must be routinely overridden is not.

**Raising this to 1 is the first thing to do when a second engineer joins** — before their first pull request, not after.

### Required status checks

All seven jobs from `.github/workflows/ci.yml`, on `main` and `develop`:

`Format` · `Analyze` · `Test` · `Architecture boundaries` · `Environment consistency` · `Secret scan` · `AWS credential isolation`

The last four are not conventional CI. They exist because ADR-011, ADR-016 and ADR-018 make claims — layer boundaries hold, no credential is committed, environments cannot drift — that would otherwise be enforced only by memory.

**Cross-reference:** three further required checks were added after this record.

- `Commit convention` (ADR-020) validates the pull request title. Pull requests only, since that title becomes the squash commit under this ADR's merge strategy.
- `Generated code drift` (Mission 0.18.4) re-runs `build_runner` and fails if the committed `*.g.dart` files are stale. Required by name in Volume 7, Chapter 7.13 §2.
- `Terraform` (Mission 6.1.7, ADR-043) runs `fmt -check`, `validate` and `tflint` over `infrastructure/terraform/`. Added because Mission 6.1.6 ran the suite over a Terraform change and found that **no job looked at it** — the seven checks above are all Dart-scoped, and infrastructure had no gate at all.

**Ten checks in total**, plus `Golden tests` — which this record has never listed and which has run since Mission 0.18.4. Eleven jobs.

`Environment consistency` was extended rather than duplicated at the same time: ADR-043 made Terraform a fourth language holding the region and bucket names, alongside Dart, JSON and shell, and that job already owns their agreement.

### Branch protection

On `main` and `develop`:

- Pull request required; no direct pushes
- Required status checks must pass, and the branch must be up to date first
- Conversations resolved before merge
- Force-push disabled
- Deletion disabled
- **Rules apply to administrators**

That last one is the one people disable, and disabling it makes the rest advisory. A protected branch an administrator can force-push is not protected.

### CI behaviour per branch

| Branch | On push | On pull request |
|---|---|---|
| `feature/*`, `fix/*`, `chore/*`, `docs/*`, `refactor/*` | None | Full suite |
| `develop` | Full suite | Full suite |
| `release/*` | **Full suite** | Full suite |
| `hotfix/*` | **Full suite** | Full suite |
| `main` | Full suite | Full suite |

Release and hotfix branches run on **push**, not only on pull request, because both are stabilisation branches that accumulate commits before their pull request opens — waiting until the PR is exactly the wrong time to discover a failure on a hotfix.

Short-lived branches run only on pull request, so a developer pushing work in progress is not billed for CI they did not ask for.

### Emergency production fixes

An emergency changes the timeline, not the gates.

1. Branch `hotfix/<description>` from `main`.
2. Fix, with a test that fails without it.
3. Open a pull request into `main`. **CI still runs. Protection still applies.**
4. Deploy to Staging and verify.
5. Merge to `main`, tag a patch version, deploy to Production with owner approval.
6. **Merge back into `develop`.**

Step 4 is the one skipped under pressure, and skipping it is how one incident becomes two. Step 6 is the one forgotten afterwards, and forgetting it means the fix disappears at the next release — the defect returns, having apparently been fixed.

If production is broken badly enough that even this is too slow, **roll back rather than fix forward**. Volume 10 Chapter 10.7 §3 covers the mechanics: halt the Play staged rollout; on iOS, expedite a fix release.

### Conflict resolution

- The author resolves conflicts in their own branch, by rebasing onto `develop`. Never a merge of `develop` into a feature branch.
- Conflicts are resolved by understanding both sides, not by taking one wholesale. `--ours` and `--theirs` are for cases you have actually reasoned about.
- After resolving, run the full suite locally. A resolved conflict that compiles is not a resolved conflict.
- If a conflict is large enough to be ambiguous, the branch lived too long. Split the work.
- Conflicts in generated files (`*.g.dart`) are resolved by regenerating, never by hand-editing.

### Branch deletion

Delete the branch on merge; GitHub does this automatically and should be configured to. The pull request preserves the history and the commits remain reachable from the target branch.

`main` and `develop` are never deleted — enforced by protection.

Stale branches, defined as merged or with no commit for 30 days, are deleted after checking with the author. A branch nobody has touched in a month is not work in progress.

### Version tagging

Semantic versioning with a `v` prefix: `v1.4.2`.

- **Major** — a breaking change to a published interface
- **Minor** — new capability, backwards compatible
- **Patch** — defect fixes only

Tags are created on `main` **after** the release merge, never before. A tag pointing at a commit that was later amended is worse than no tag.

`mobile/pubspec.yaml`'s version and `AppInfo` (ADR-006) must match the tag. ADR-006 records that all three move together until the version is read from the platform bundle.

### Environment mapping

Owned by **ADR-014** and not restated here. In summary: `develop` → Development, `release/*` → Staging, `main` + tag → Production with manual approval.

## Alternatives Considered

- **Trunk-based on `main` alone, as Volume 7 §7.6 §1 states** — rejected, and it is the strongest alternative. Simpler, and correct for one deployed environment. With three, there is no branch representing "merged but not yet a release candidate", so either `main` destabilises or staging verifies a state that never existed. Revisit if the environment count ever drops to one.
- **Full GitFlow, with permanent `release` and `hotfix` branches** — rejected. Permanent stabilisation branches accumulate divergence and back-merge debt. Both remain temporary here.
- **Require one approval now** — rejected as unenforceable. GitHub forbids self-approval; the rule would be bypassed on day one, and a bypassed rule is worse than an absent one because it normalises bypassing.
- **No protection while solo** — rejected. Protection prevents an accidental direct push and guarantees CI ran. Both matter more alone than in a team, because there is no one else to notice.
- **Squash everything, including into `main`** — rejected. It would collapse a release into one commit and erase which changes it contained.
- **Merge commits everywhere** — rejected. `develop` would carry every `WIP` commit from every branch.

## Consequences

- The path from idea to production is one documented route, and deviations are visible.
- Protection applies to administrators, so the sole maintainer is subject to the same gates as anyone else. This is friction, and it is the point.
- **Zero required approvals today is a real gap, not a solved problem.** CI catches what CI can check; nothing catches a bad decision that compiles. This is mitigated by staging verification, not eliminated.
- Four of the seven required checks are project-specific invariants. They will occasionally fail for reasons a newcomer finds surprising, which is why each emits an error naming the ADR it enforces.
- Release and hotfix branches consume CI minutes on every push. Accepted: they are the branches where a late failure costs most.
- `develop` **does not yet exist**, and CI already references it. Creating and protecting it is a prerequisite for this strategy operating at all.
- Volume 7 Chapter 7.6 §1 is now superseded in part and must be corrected at source.

## Related Missions

- Mission 0.16 — Git & GitHub Foundation, which produced the operational document this record makes binding.
- Mission 0.18.2 — Branch Strategy, which produced this ADR.

## Implementation Status

**Documented, not enforced.**

| | Decision | Current state |
|---|---|---|
| `main` exists and is protected | Required | ⚠️ Exists; **protection not configured** |
| `develop` exists and is protected | Required | ❌ **Does not exist** |
| Seven required status checks | Required | ❌ Not configured — CI has never run |
| Force-push disabled, admins included | Required | ❌ Not configured |
| Auto-delete merged branches | Required | ❌ Not configured |
| Branch naming, merge strategy, tagging | Documented | ✅ `docs/git/branching-strategy.md` |

Every unmet item is a **GitHub repository setting**, not code, and cannot be configured from this repository. They require the owner acting in repository settings.

Until then this strategy is advisory. The gap between an accepted branching ADR and an unprotected `main` is precisely the kind of drift the amendment register exists to make visible.
