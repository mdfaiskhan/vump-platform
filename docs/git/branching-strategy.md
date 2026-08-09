# Branching Strategy

How work moves from an idea to production in the Vump Technologies repository.

**Binding record: [ADR-019](../architecture/decisions/ADR-019-branching-strategy.md).** This document is the operational guide; ADR-019 is the decision. Where they disagree, the ADR governs. Environment mapping is owned by [ADR-014](../architecture/decisions/ADR-014-environment-strategy.md).

---

## Branches

| Branch | Purpose | Lifetime | Protected |
|---|---|---|---|
| `main` | Production. Every commit is releasable. | Permanent | Yes |
| `develop` | Integration. Where completed work accumulates. | Permanent | Yes |
| `feature/*` | New capability. | Days | No |
| `fix/*` | Defect correction. | Hours to days | No |
| `chore/*` | Tooling, dependencies, configuration. | Hours | No |
| `docs/*` | Documentation and ADRs only. | Hours | No |
| `refactor/*` | Structural change with no behaviour change. | Days | No |
| `release/*` | Release stabilisation. | Days | No |
| `hotfix/*` | Urgent production defect. | Hours | No |

`main` and `develop` are never committed to directly. Every change arrives through a pull request.

---

## Flow

```
feature/x ──┐
fix/y     ──┼──► develop ──► release/1.2.0 ──► main ──► tag v1.2.0
chore/z   ──┘                                    ▲
                                    hotfix/* ────┘
```

1. Branch from `develop`.
2. Commit in small, coherent steps.
3. Open a pull request into `develop`.
4. Merge once CI is green, and approved if the team size requires it (see Protection Rules).
5. Cut `release/x.y.z` from `develop` when a version is ready.
6. Merge the release branch into `main`, tag it, and merge back into `develop`.

**Hotfixes are the one exception.** They branch from `main`, merge into `main`, and are then merged back into `develop` so the fix is not lost at the next release. A hotfix that skips the merge back reappears as a regression.

---

## Naming

```
<type>/<short-description>
<type>/<issue-number>-<short-description>
mission/<number>-<short-description>
```

- Lowercase kebab-case.
- Describe the change, not the file touched.
- Reference the issue number where one exists.

Good:

```
feature/142-recording-playback
fix/session-token-refresh-loop
chore/upgrade-riverpod-3
docs/adr-011-authentication
mission/0.16-git-foundation
```

Bad:

```
feature/stuff              # says nothing
fix                        # no description
Feature/New-Recording      # wrong case
faisal-branch              # named after a person, not the work
```

The `mission/*` form exists because this project is built in numbered missions. It is a `feature/*` branch by another name and follows the same rules.

---

## Branch Lifetime

**Short-lived, always.** A branch open for more than a few days diverges from `develop`, and the merge stops being a merge and becomes a negotiation.

If work is too large for a few days, split it. A branch that cannot be split is usually a mission that was scoped too broadly.

Delete the branch after merge. The pull request preserves the history.

---

## Keeping Up To Date

Rebase onto `develop` rather than merging `develop` in:

```bash
git fetch origin
git rebase origin/develop
```

Rebasing keeps the branch history linear and the pull request diff honest — it shows what the change does, not what happened to the branch while it was open.

**Never rebase a branch someone else has pulled.** Rewriting shared history forces everyone else to recover manually. If a branch is shared, merge instead.

---

## Merge Strategy

| Into | Strategy | Why |
|---|---|---|
| `develop` | Squash | One feature, one commit. `develop`'s history reads as a list of completed work. |
| `main` | Merge commit | Preserves the release branch's history and marks the release point. |
| Back-merges | Merge commit | Records that the back-merge happened. |

The squash commit message must follow the commit conventions — see `commit-conventions.md`. It is the message that survives, so it matters more than the individual commits it replaces.

---

## Protection Rules

`main` and `develop` require:

- A pull request. No direct pushes.
- All nine CI checks green: Format, Analyze, Test, Generated code drift, Architecture boundaries, Commit convention, Environment consistency, Secret scan, AWS credential isolation.
- The branch up to date with its base before merge.
- Conversations resolved.
- Force-push and deletion disabled, **including for administrators**.

That last point is the one people disable, and disabling it makes the rest advisory.

### Required approvals scale with the team

| Team size | Required approvals |
|---|---|
| 1 (today) | **0** — CI is the gate |
| 2+ | **1**, never the author |
| 5+ | 1, plus a code owner for `infrastructure/` and `docs/architecture/` |

GitHub forbids a pull request author from approving their own, so requiring one today would block every merge and be routinely bypassed. A bypassed rule is worse than an absent one. **Raise this to 1 before the second engineer's first pull request** — see ADR-019.

---

## Conflict Resolution

- The author resolves conflicts in their own branch, by rebasing onto `develop` — never by merging `develop` in.
- Resolve by understanding both sides. `--ours` and `--theirs` are for cases you have actually reasoned about.
- Run the full suite locally afterwards. A resolved conflict that compiles is not a resolved conflict.
- Conflicts in generated files (`*.g.dart`) are resolved by regenerating, never by hand.
- A conflict large enough to be ambiguous means the branch lived too long. Split the work.

## Emergency Production Fixes

An emergency changes the timeline, not the gates. CI still runs; protection still applies.

```
main ──► hotfix/<description> ──► PR to main ──► Staging verify ──► tag ──► Production
                                                                      └──► merge back to develop
```

Two steps get skipped under pressure, and both matter:

- **Staging verification.** Skipping it is how one incident becomes two.
- **The back-merge to `develop`.** Forgetting it means the fix vanishes at the next release and the defect returns, apparently having been fixed.

If production is broken badly enough that even this is too slow, **roll back instead of fixing forward** — Volume 10 Chapter 10.7 §3.

## CI Behaviour Per Branch

| Branch | On push | On pull request |
|---|---|---|
| `feature/*`, `fix/*`, `chore/*`, `docs/*`, `refactor/*` | None | Full suite |
| `develop`, `main` | Full suite | Full suite |
| `release/*`, `hotfix/*` | **Full suite** | Full suite |

Release and hotfix branches run on push because they accumulate commits before their pull request opens — the PR is the wrong moment to discover a failure on a hotfix.

⚠️ **Not yet configured.** `.github/workflows/ci.yml` currently triggers on `main` and `develop` only, so `release/*` and `hotfix/*` get no CI until their pull request opens.

## Tags and Releases

Tags follow semantic versioning with a `v` prefix: `v1.4.2`.

- **Major** — a breaking change to a published interface.
- **Minor** — new capability, backwards compatible.
- **Patch** — defect fixes only.

The tag is created on `main` after the release merge, never before. A tag pointing at a commit that was later amended is worse than no tag.

The version in `mobile/pubspec.yaml` matches the tag. ADR-006 records that `AppInfo.version` mirrors it too, and that all three must move together until the version is read from the platform bundle.
