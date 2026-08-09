# Commit Conventions

**Binding record: [ADR-020](../architecture/decisions/ADR-020-commit-convention.md).** This is the operational guide; the ADR is the decision. Where they disagree, the ADR governs.

The repository follows [Conventional Commits](https://www.conventionalcommits.org/).

> **What is actually enforced:** the **pull request title**, by the `commit-convention` CI job. ADR-019 squash-merges into `develop`, so the PR title becomes the commit that lands — it is the message that survives. Individual commits on your branch are not validated and may include `wip` checkpoints. A commit message is read far more often than it is written — usually by someone trying to understand why a line exists, months later, with no other context.

---

## Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

Only the first line is required.

---

## Type

| Type | Use for |
|---|---|
| `feat` | A new capability |
| `fix` | A defect correction |
| `docs` | Documentation and ADRs only |
| `refactor` | Structural change with no behaviour change |
| `test` | Adding or correcting tests |
| `chore` | Tooling, dependencies, configuration |
| `perf` | A change made for performance |
| `style` | Formatting only — no code change |
| `ci` | Build and CI pipeline changes |
| `build` | Build system, dependencies, code generation |
| `revert` | Reverting an earlier commit |

If a change fits two types, it is two commits.

The genuine ambiguity is `refactor` versus `chore`: **`refactor` touches shipped code, `chore` does not.**

### Type → changelog category

Volume 11 Chapter 11.5 requires a Keep a Changelog entry written the day a change merges. The type determines the section:

| Type | Changelog category |
|---|---|
| `feat` | **Added** |
| `fix` | **Fixed** |
| `perf` | **Changed** |
| `BREAKING CHANGE` | **Changed** |
| everything else | not in the changelog |

Anything touching authentication, storage, secrets or data handling is additionally listed under **Security**, regardless of type.

---

## Scope

The area affected, matching the project structure:

```
core/network      core/database     core/storage
core/logging      core/errors       core/firebase
app/config        app/theme         app/router
features/<name>   docs/adr          ci
deps              android           ios
```

Scope is optional but expected. `feat(core/network): ...` tells a reader whether to keep reading; `feat: ...` does not.

---

## Subject

- Imperative mood: *add*, not *added* or *adds*.
- Lowercase, no trailing full stop.
- 72 characters or fewer.
- Describe the change, not the activity.

Good:

```
feat(core/storage): add secure storage abstraction
fix(core/network): map 429 responses to rate-limited error code
docs(docs/adr): record local database architecture as ADR-009
chore(deps): downgrade freezed to 2.5.2 for isar_generator compatibility
```

Bad:

```
update files                    # says nothing
Fixed the bug.                  # past tense, capitalised, trailing stop
feat: changes                   # describes activity, not outcome
WIP                             # not a commit worth keeping
```

---

## Body

Include one whenever the change is not self-evident.

**Explain why, not what.** The diff already shows what changed. What it cannot show is the constraint that forced the change, the alternative that was rejected, or the failure that prompted it.

```
fix(core/firebase): tolerate duplicate-app during initialisation

Hot restart discards Dart state but leaves the native Firebase SDK
initialised, so the next initializeApp call throws duplicate-app. Adopt
the existing instance instead of treating it as a failure.
```

Wrap at 72 characters. Separate from the subject with a blank line.

---

## Footer

**Issues:**

```
Closes #142
Refs #87
```

**Breaking changes** — required whenever a published interface changes incompatibly:

```
BREAKING CHANGE: SecureStorageRepository.read now takes a StorageKey
rather than a String. Call sites must use the registered key constant.
```

**Architecture decisions** — reference the ADR when a commit implements or is constrained by one:

```
Implements ADR-009
Constrained by ADR-007
```

---

## What Makes a Good Commit

**One logical change.** A commit that fixes a bug and reformats a file makes both halves harder to review and impossible to revert independently.

**Compiles and passes tests.** Every commit on a shared branch must be a point the repository could be checked out at. A commit that only works with the next one is one commit split by accident.

**Not a checkpoint.** `WIP`, `more changes` and `fix typo` are save points, not history. Squash them before opening a pull request, or rely on squash-merge into `develop` — but write the squash message properly, because it is the one that survives.

---

## Secrets

A commit that adds a credential is a disclosure, and removing it in a later commit does not undo it — history keeps it, and history is public to everyone with repository access.

Before committing, check the diff for anything matching ADR-007's forbidden list: API keys, AWS credentials, Firebase service account keys, access and refresh tokens, signing keys, credential-bearing connection strings.

If one is committed, treat the credential as compromised and rotate it. Rewriting history is a secondary step, not a fix.

Client identifiers — the Firebase API key in `firebase_options.dart`, `google-services.json` — are not secrets and are committed deliberately. ADR-010 records why.

---

## Merge, revert, hotfix and release commits

| Kind | Format |
|---|---|
| **Merge** | Git-generated. Left as-is, exempt from validation |
| **Revert** | `revert: <original subject>` with a `Reverts: <sha>` footer and a body saying **why**. A revert with no reason invites the change being reapplied |
| **Hotfix** | An ordinary `fix:`. The branch conveys urgency; the message conveys the change |
| **Release** | `chore(release): v1.2.0` — version bump and changelog entry only, nothing functional. It is the commit a tag points at, so it must be trivially reviewable |

```
revert: feat(core/network) add retry interceptor

The interceptor retried non-idempotent POSTs, duplicating chunk
registrations. Reapply once retries are restricted to GET and HEAD.

Reverts: a1b2c3d
Refs #211
```

## Release automation

Nothing is automated today — Volume 10 Chapter 10.7 §1 has a human incrementing `pubspec.yaml` and writing the changelog. This convention is what keeps automation available later:

- `feat` / `fix` / `BREAKING CHANGE` map onto minor / patch / major version bumps.
- The type table above maps commits onto Volume 11 Chapter 11.5's changelog sections.
- `semantic-release`, `release-please` and `git-cliff` consume this format unmodified.

Adopting a tool later is configuration. Retrofitting the format would be a history rewrite.

## Examples

```
feat(core/database): add Isar lifecycle service and migration runner

Isar migrates additive schema changes silently but offers no hook for
renames or type changes, so version tracking and ordered migration steps
are owned by the layer rather than left to the engine.

Implements ADR-009
Closes #58
```

```
fix(core/network): prevent DioException escaping the client

ErrorInterceptor built the NetworkException but Dio re-wrapped it in its
own envelope, so callers still saw a DioException. DioClient now unwraps
before rethrowing.

Refs #94
```

```
ci: fail the build on unformatted Dart sources

Generated files are excluded — the generator does not emit tall-style
output and reformatting them would be undone on the next build.
```
