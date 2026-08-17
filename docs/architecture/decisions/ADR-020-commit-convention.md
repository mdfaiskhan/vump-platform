# ADR-020 — Commit Convention

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Supersedes Volume 7, Chapter 7.6 §4 in part — see `docs/architecture/volume-amendments.md`.

## Context

Commit messages are the only documentation that is guaranteed to survive. Code is rewritten, comments are deleted, tickets are archived and wikis rot — but `git log` persists, and it is what someone runs when a line of code makes no sense and everyone who wrote it has moved on.

Three things forced this decision now.

**The format was never binding.** `docs/git/commit-conventions.md`, written in Mission 0.16, describes Conventional Commits. It is a document, editable without governance, and nothing enforces it.

**Volume 7, Chapter 7.6 §4 says something subtly different**: *"Conventional, imperative-mood messages referencing the requirement/chapter they implement where relevant (e.g. `Add checklist retry action (FR-CHK-05, C-08)`)."* That example has no `type(scope):` prefix. Read as "conventional" in the ordinary sense it is satisfied by any tidy message; read as Conventional Commits it is not, because the example itself would fail.

**The merge strategy changes what actually matters.** ADR-019 squash-merges into `develop`, and GitHub uses the **pull request title** as the default squash commit message. Individual commits on a feature branch are discarded at merge. Validating every commit while ignoring the title would enforce the format on messages that never survive, and skip the one that does.

## Decision

### Conventional Commits, with traceability preserved

The format is [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>)<!>: <subject>

<body>

<footer>
```

Volume 7 §7.6 §4's *intent* — imperative mood and traceability to a requirement ID — is retained in full. Only the placement changes: the requirement ID moves from the subject into the footer, where it does not consume the 72-character header and is machine-readable.

```
feat(features/recording): add checklist retry action

Implements FR-CHK-05, C-08
```

Conventional Commits is chosen over a bespoke format for one reason that matters more than familiarity: it makes the type of change **machine-readable**, which is what lets the changelog Volume 11 Chapter 11.5 requires be derived from history rather than remembered.

### Types

| Type | Use for | Changelog category (V11.5) |
|---|---|---|
| `feat` | A new capability | **Added** |
| `fix` | A defect correction | **Fixed** |
| `perf` | A change made for performance | **Changed** |
| `refactor` | Structural change, no behaviour change | — |
| `docs` | Documentation and ADRs | — |
| `test` | Adding or correcting tests | — |
| `build` | Build system, dependencies, codegen | — |
| `ci` | CI pipeline | — |
| `style` | Formatting only | — |
| `chore` | Anything else with no product effect | — |
| `revert` | Reverting an earlier commit | Depends on what was reverted |

Anything touching authentication, storage, secrets or data handling is additionally marked **Security** in the changelog regardless of type, per V11.5 §2.

A change that fits two types is two commits.

### Scopes

The area affected, matching the repository structure:

```
core/network    core/database   core/storage    core/logging
core/errors     core/firebase   core/environment
app/config      app/theme       app/router
features/<name> infrastructure  docs/adr
deps            ci              android         ios
```

Scope is optional but expected. `feat(core/network): …` tells a reader whether to keep reading; `feat: …` does not.

### Breaking changes

Marked **both** ways — `!` before the colon for the reader scanning `git log`, and a `BREAKING CHANGE:` footer for the tool computing a version bump:

```
feat(core/storage)!: require StorageKey instead of String

BREAKING CHANGE: SecureStorageRepository.read now takes a StorageKey.
Call sites must use the registered key constant.
```

A breaking change forces a **major** version bump under Volume 10 Chapter 10.1's semantic versioning. Before v1.0.0, "breaking" means breaking an interface another layer depends on.

### Merge, revert, hotfix and release commits

| Kind | Format |
|---|---|
| **Merge** | Git-generated (`Merge pull request #12 from …`). Left as-is and exempt from validation — authored messages are the ones worth constraining |
| **Revert** | `revert: <original subject>`, with a `Reverts: <sha>` footer and a body saying **why**. A revert with no reason invites the change being reapplied |
| **Hotfix** | An ordinary `fix:` — the branch conveys the urgency, the message conveys the change. `Hotfix:` as a prefix would be a twelfth type meaning the same as `fix` |
| **Release** | `chore(release): v1.2.0`, containing only the version bump and changelog entry — nothing functional. It is the commit a tag points at, so it must be trivially reviewable |

### Structure

**Header** — required. 72 characters maximum, lowercase subject, imperative mood, no trailing full stop.

*Imperative* because the subject completes the sentence "this commit will…". "add retry logic", not "added" or "adds".

**Body** — whenever the change is not self-evident. **Explain why, not what.** The diff already shows what changed; what it cannot show is the constraint that forced it, the alternative rejected, or the failure that prompted it. Wrapped at 72 characters, blank line after the header.

**Footer** — issues (`Closes #142`), breaking changes, traceability (`Implements FR-CHK-05`), and ADR references (`Implements ADR-020`, `Constrained by ADR-007`).

### Validation: the pull request title, not every commit

**Enforced:** the PR title, by the `commit-convention` CI job. This is the message that becomes the squash commit in `develop` (ADR-019) — the one that survives.

**Not enforced:** individual commits on a branch. They are squashed away, so constraining them would add friction with no durable benefit, and it would forbid the `wip` checkpoints that are a legitimate part of working.

Merge and revert messages generated by git are exempt.

### Tooling: a dependency-free validator, not commitlint

Validation is a Python script inside the CI workflow. **commitlint is not adopted**, for two reasons.

It requires Node and a `package.json` at the repository root. ADR-015 makes the backend Node/TypeScript, but `backend/` is empty — so today this would mean a Node toolchain and a lockfile at the root of a Flutter repository, maintained for one linting rule.

Second, every existing CI guard in this repository — architecture boundaries, secret scan, environment consistency, credential isolation — is dependency-free and uses no third-party action. That is a deliberate supply-chain position: a workflow that validates commit messages should not be able to execute arbitrary third-party code against the repository.

**Revisit when `backend/` exists.** With a Node toolchain already present, commitlint becomes nearly free and brings a shared config the validator does not.

### Compatibility with future release automation

Nothing here assumes automation, because Volume 10 Chapter 10.7 §1 has a human incrementing `pubspec.yaml` and writing the changelog. But this convention is what makes automation possible later without a history rewrite:

- `feat` / `fix` / `BREAKING CHANGE` map onto minor / patch / major, so a tool can compute the next version from history.
- The type→category table above maps commits onto V11.5's Keep a Changelog sections.
- `semantic-release`, `release-please` and `git-cliff` all consume this format unmodified.

The constraint automation would impose is already satisfied: **a machine-readable history from the first commit**. Adopting a tool later is configuration; retrofitting the format is a rewrite.

## Alternatives Considered

- **Volume 7 §7.6 §4's format literally** — `Add checklist retry action (FR-CHK-05, C-08)`. Rejected. Readable but not machine-readable, so neither the changelog nor a version bump can be derived. Its intent is preserved via the footer.
- **No convention** — rejected. History becomes unsearchable and the changelog becomes recall.
- **commitlint** — deferred, not rejected. See above.
- **Validate every commit on the branch** — rejected. They are squashed away; it forbids legitimate `wip` checkpoints and enforces a rule on messages that never survive.
- **Validate nothing, rely on review** — rejected. Format is exactly what a machine checks better than a human, and a reviewer's attention is better spent on the change.
- **A `hotfix:` type** — rejected. It would mean the same as `fix`, with urgency already carried by the branch name.
- **Gitmoji or a custom prefix scheme** — rejected. No tooling ecosystem, and it optimises for the writer over the archaeologist.

## Consequences

- History is machine-readable from the first commit, so the changelog and version bumps become derivable rather than remembered.
- The PR title carries real weight. Authors used to treating it as a label will need to adjust, and the CI failure message explains why.
- Individual commits stay unconstrained, so working style is unaffected — at the cost that a branch's internal history may be untidy before squash. Acceptable, since it is discarded.
- Eleven types is a vocabulary to learn. The genuine ambiguity is `refactor` versus `chore`; the rule is that `refactor` touches shipped code and `chore` does not.
- The validator duplicates a small amount of logic that commitlint would provide. Accepted deliberately for zero dependencies.
- Merging to `main` uses a merge commit (ADR-019), so the release PR title matters as much as any other.
- Volume 7 §7.6 §4's example is now wrong at source and must be corrected there.

## Related Missions

- Mission 0.16 — Git & GitHub Foundation, which produced the document this record makes binding.
- Mission 0.18.2 — Branch Strategy, whose squash-merge decision determines what is validated.
- Mission 0.18.3 — Commit Convention, which produced this ADR.

## Implementation Status

**Implemented.**

`docs/git/commit-conventions.md` documents the format. The `commit-convention` CI job validates pull request titles and was tested against 13 cases — valid types, scopes, breaking-change markers, git-generated merge and revert messages, and five failure modes including V7 §7.6 §4's own example.

**Not yet enforced in practice:** CI has never run, because the workflow is uncommitted. Like ADR-019's protection rules, this convention is binding in writing and unenforced in fact until the workflow lands and the check is required on `main` and `develop`.
