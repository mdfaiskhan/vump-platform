# Architecture Guardrails

The architectural invariants of the Vump Technologies repository, each with its authority, its enforcement mechanism, and the command that verifies it.

Governed by **ADR-026**. Where this document and the ADR disagree, the ADR governs.

## What this document is, and is not

**It is not a second copy of the architecture rules.** ADR-022 and `folder-structure.md` fix the folder and import rules; ADR-025 and `error-handling.md` fix the error boundary; ADR-021 fixes static analysis; ADR-023 fixes naming. All are cited here and none is restated.

**What this document adds is the enforcement column.** No existing document says, for any given invariant, whether a machine checks it or a human is expected to remember it. That gap matters more than it sounds: an invariant nobody checks is a convention, and the repository already has two documented cases of a rule that was binding in writing and unenforced in fact for months (ADR-020, and the layer directories ADR-001 corrected in Mission 0.18.1).

The register in §3 is therefore the substance. Everything else exists to make it readable.

**Every guardrail here is derived**, from one of: existing implementation, an accepted ADR, an approved Volume, the Project Constitution, or the Vision Document. Nothing is invented. Where a Volume and an accepted ADR disagree, the disagreement is recorded in §7 and registered as an amendment, never silently resolved.

---

## 1. The architectural boundaries

Four boundary kinds exist, in order of how expensive they are to cross wrongly.

| # | Boundary | Separates | Authority |
|---|---|---|---|
| **B1** | **Deployment** | `mobile/` · `backend/` · `infrastructure/` · `docs/` · `.github/` | ADR-022 §1 |
| **B2** | **Trust** | The device and the backend. The mobile app holds no AWS credential | Volume 4 Ch. 4.10 §2; `aws-sdk-integration.md` |
| **B3** | **Module** | `app/` · `core/` · one `features/<name>/` from another · `shared/` | ADR-002, ADR-022 §2 |
| **B4** | **Layer** | `domain/` · `data/` · `application/` · `presentation/` within a feature | ADR-001, ADR-022 §3 |

**B2 is the one with no recovery.** A Flutter binary is distributed to devices outside our control and can be decompiled, so a credential compiled into it is a credential published — and unlike a layer violation, it cannot be fixed by a refactor. It is the only boundary with a CI job dedicated solely to it.

**B4 is currently unexercised.** `lib/features/` is empty, so no layer boundary exists in the repository yet. Every B4 guardrail is binding and untested.

---

## 2. Module dependency graph

ADR-022 §5.1 fixes the **layer** import matrix. This is the **module** graph, which ADR-022 does not carry, taken from Volume 3 Chapter 3.5 §4 with the correction registered as **A-039**.

```text
core  ──────────────────────────────► depends on nothing in the app
  ▲
  │  every module depends on core, never the reverse
  │
  ├── auth              ── core
  ├── onboarding        ── core, auth
  ├── settings          ── core, auth
  ├── projects_tasks    ── core, auth
  ├── recording         ── core   (+ conceptually: a session is tied to a Task)
  ├── upload            ── core   (+ conceptually: a chunk exists once recording produces it)
  ├── metadata          ── core   ("depends on nothing outside core", V3.5 §4)
  └── admin_shared      ── core, auth
```

**The nine modules are Volume 3 Chapter 3.5's list**, and it is the authoritative one: `core`, `auth`, `onboarding`, `settings`, `projects_tasks`, `recording`, `upload`, `metadata`, `admin_shared`. ADR-022 §6.2 names five — `authentication`, `recording`, `upload`, `tasks`, `settings` — which were illustrative of the procedure rather than a complete inventory. Where the two differ, Volume 3 §3.5 is the module list and ADR-022 §6 is the procedure for adding one.

**The parenthesised dependencies are conceptual, not imports.** Volume 3 §3.5 §4 lists `recording → projects_tasks` and `upload → recording` in its bullets and then closes with the opposite rule — *"no two feature modules depend on each other directly without going through core"*. The chapter contradicts itself; ADR-022 R3 resolves it in favour of the closing rule, and A-039 records why. A conceptual dependency is expressed through `core`, through a shared abstraction, or through state — never through an import.

**`metadata` is the module boundary most likely to look wrong**, and Volume 3 §3.5 §3 justifies it explicitly: metadata has its own immutability rule (BR-22), its own retention that outlives the raw chunk (BR-23), and its own Admin surface read independently of upload status. Folding it into `recording` or `upload` would scatter one cohesive rule set across two modules.

---

## 3. The invariant register

Every architectural invariant in force, with its authority and how it is checked. **This is the document's purpose.**

`Analyzer` = `flutter analyze` fails. `CI` = a named job fails. `Review` = a human is expected to notice.

### Enforced by CI

| # | Invariant | Authority | Enforced by |
|---|---|---|---|
| **I1** | `dio` only in `core/network/` | ADR-007, ADR-022 §2.3 | CI `Architecture boundaries` |
| **I2** | `isar` only in `core/database/`, a feature's `data/collections/`, or its `data/isar_*.dart` | ADR-039 | CI `Architecture boundaries` |
| **I3** | `flutter_secure_storage` only in `core/storage/` | ADR-008 | CI `Architecture boundaries` |
| **I4** | `firebase_core` only in `core/firebase/` | ADR-010 | CI `Architecture boundaries` |
| **I5** | The mobile app declares no AWS SDK package | Volume 4 Ch. 4.10 §2 | CI `AWS credential isolation` |
| **I6** | No AWS key, credential identifier or hardcoded AWS endpoint in `mobile/` | Volume 4 Ch. 4.10 §2, ADR-016 | CI `AWS credential isolation` |
| **I7** | No credential-bearing file, AWS key, private key or service-account key is tracked | ADR-016 | CI `Secret scan` |
| **I8** | Exactly three environments, agreeing across Dart, JSON and shell | ADR-014, ADR-018 | CI `Environment consistency` |
| **I9** | Bucket names derive from the slug rule `vump-platform-{slug}` | ADR-011 | CI `Environment consistency` |
| **I10** | Region is `ap-south-1` everywhere | ADR-011, A-010 | CI `Environment consistency` |
| **I11** | Committed generated files match what the generator produces | Volume 7 Ch. 7.13 §2 | CI `Generated code drift` |
| **I12** | Hand-written Dart is `dart format` clean | ADR-021 | CI `Format` |
| **I13** | Zero analyzer diagnostics | ADR-021, Constitution §4 | CI `Analyze` |
| **I14** | All tests pass; coverage is measured | Volume 9 Ch. 9.5 §2 | CI `Test` — **measured, not gated** |
| **I15** | The PR title follows Conventional Commits | ADR-020 | CI `Commit convention` |

### Enforced by the analyzer

| # | Invariant | Authority |
|---|---|---|
| **I16** | Every import inside `lib/` is a `package:mobile/…` import | Volume 3 §3.7 §2, ADR-021 |
| **I17** | No `print` — all output through `AppLogger` | ADR-007, ADR-016, ADR-021 |
| **I18** | No `dynamic` call; no implicit downcast; no raw generic | ADR-021 (`strict-casts`, `strict-inference`, `strict-raw-types`) |
| **I19** | No empty `catch`; only `Error`/`Exception` thrown; `rethrow` preserves the trace | ADR-025, ADR-021 |
| **I20** | No unawaited or discarded future | ADR-021 |
| **I21** | No `BuildContext` used across an `await` | ADR-021 |
| **I22** | No dead code — unused import, local, element or field | Constitution §4, ADR-021 |
| **I23** | One public declaration per file; `snake_case` filenames | `CLAUDE.md`, ADR-023 §1.1 |
| **I24** | No other package's `src/` is imported | ADR-021 (`implementation_imports`) |

### Enforced by review only

**These are the guardrails with no machine behind them.** Every one is checkable; none is checked.

| # | Invariant | Authority | What would close it |
|---|---|---|---|
| **I25** | No cross-feature import, at any layer, in either direction | ADR-022 R3, V3.4 §1, V3.5 §4 | A grep over `lib/features/*/` |
| **I26** | No circular dependency between features, layers or `core/` modules | ADR-022 R4 | An import-graph cycle check |
| **I27** | `presentation/` never imports its own `data/` | ADR-022 §5.3 | A grep, once `features/` exists |
| **I28** | `application/` never imports its own `data/` | ADR-022 §5.3 | A grep, once `features/` exists |
| **I29** | `domain/` imports nothing outside itself but `failure.dart` and `error_codes.dart` | ADR-001, ADR-022 §3.1 | A grep, once `features/` exists |
| **I30** | `app/` names no feature except `app/router.dart`, and only its `presentation/` | ADR-022 §2.2 | A grep — **checkable now** |
| **I31** | `core/` never imports `app/theme/` | ADR-022 §5.2 | A grep — **checkable now** |
| **I32** | `app/config/` never imports `core/` (the one-way rule) | ADR-022 §5.2, `network_config.dart` | A grep — **checkable now** |
| **I33** | No layer directory at the root of `features/` | ADR-001, ADR-022 R8 | A directory-name check — **checkable now** |
| **I34** | Nothing enters `shared/` without a second consumer | ADR-002, ADR-022 R5 | Not mechanically checkable |
| **I35** | Type suffixes come from the closed vocabulary | ADR-023 §3 | A forbidden-suffix grep — **checkable now** |
| **I36** | A third-party error is converted at the module that owns the package | ADR-025 §7 | Not mechanically checkable |
| **I37** | No `Failure` subclass | ADR-025, ADR-023 §3 | A grep — **checkable now** |
| **I38** | Every non-ADR document states its precedence; markdown mechanics hold | ADR-024 §3, §30 | A markdown-lint job |
| **I39** | `firebase_auth` only in `features/auth/data/` | ADR-034, ADR-022 §2.3 | CI `Architecture boundaries` |
| **I40** | `google_sign_in` only in `features/auth/data/` | ADR-034, A-053 | CI `Architecture boundaries` |
| **I41** | `core/` never imports `features/` | ADR-022 §2, ADR-035 | A grep — **checkable now** |
| **I42** | `cloud_functions` only in `features/auth/data/` | ADR-036 | CI `Architecture boundaries` |
| **I43** | `cloud_firestore` only in `features/auth/data/` | ADR-036 | CI `Architecture boundaries` |
| **I44** | `battery_plus` only in `features/recording/data/` | FR-CHK-03, ADR-030 | CI `Architecture boundaries` |
| **I45** | `connectivity_plus` only in `features/recording/data/` | FR-CHK-04, ADR-030 | CI `Architecture boundaries` |

**I2 widened at Mission 3.7 and is enforced again.** It read `isar` only in `core/database/` until Volume 5 Chapter 5.8's three collections were placed in the feature that owns them — a collection cannot be declared without importing the package, so the tables could satisfy the old rule or live with their feature, not both. ADR-039 supersedes ADR-009 on that clause alone and the CI check was widened to match; the job passes. **The rule did not weaken.** The engine, its lifecycle and its migrations are still `core/database/`'s exclusively, the two feature locations are a directory and a filename prefix rather than a layer, and nothing above `data/` may name an Isar type.

**I42 and I43 are temporary**, and are the only invariants in this register with an expiry: both packages leave the project when ADR-036's runtime is retired at Mission 6/7. They are registered anyway — an unenforced boundary is not cheaper for being short-lived, and the confinement is what keeps the retirement a deletion of one directory rather than a hunt.

**I41 was implicit until ADR-035 tested it.** ADR-022 states the rule; nothing checked it, because `core/` had no reason to want anything from a feature until `AuthInterceptor` needed a token. The resolution — `core/network/` declares `AuthTokenSource` and the composition root supplies the implementation — is the pattern every later `core/` module with the same problem should follow, and this invariant is what stops the shortcut being taken instead.

**I39 and I40 belong to the I1–I4 family and are numbered at the end** because the register's numbers are cited from elsewhere — A-026 and ADR-026 both reference `I25`–`I33` by number — and renumbering would silently invalidate those citations.

**They are the first confinement rules owned by a feature rather than by a `core/` module.** ADR-010 keeps the Firebase *platform* in `core/firebase/` (I4); a Firebase *product* has one consumer, so `features/auth/` is the unit that stays replaceable. Placing `firebase_auth` in `core/` for symmetry with I4 would put feature code in `core/`, which ADR-022 defines against.

**Five of these are checkable against code that exists today** — I30, I31, I32, I33, I35, I37 — and are the natural first extension of the `Architecture boundaries` job. The rest need `lib/features/` to have contents before they can be tested at all, which is the honest reason they are unenforced rather than an oversight.

---

## 4. Dependency direction

**Layer direction is fixed by ADR-001 and specified by ADR-022 §5.1's import matrix. Not repeated here.**

The one thing worth stating in a guardrails document, because it is the invariant most often inverted by good intentions:

> `data/` depends on `domain/`, never the reverse — even though control flows the other way. `domain/` declares the repository interface; `data/` implements it.

ADR-001 states it as *"the direction of the dependency is the opposite of the direction of control"*. This is the single point on which Volume 3 Chapter 3.4 §3 disagrees with the implementation: its arrow runs `Domain → Data/Repositories → Platform Services`, downward and uninverted. ADR-001 governs; the divergence is registered as **A-038**.

**Module direction:** every module depends on `core`, never the reverse (§2).

**Trust direction:** the device asks the backend for a capability; the backend never trusts the device. `aws-sdk-integration.md` records the consequences — the backend computes the object key it signs, because a client-supplied key is a client-controlled write location, and it performs a `HEAD` to verify size and checksum rather than taking the client's word.

---

## 5. Ownership boundaries

**One owner per concern.** A second owner is a second source of truth, and the environment model is the worked example of why: it is expressed in Dart, JSON and shell, no compiler checks across that boundary, and CI `Environment consistency` exists solely because drift there means a staging build pointed at the production bucket.

| Concern | Sole owner | Authority |
|---|---|---|
| HTTP transport | `core/network/` | ADR-007 |
| Local database | `core/database/` | ADR-009 |
| Secure storage | `core/storage/` | ADR-008 |
| Firebase platform startup | `core/firebase/` | ADR-010 |
| Logging | `core/logging/` | ADR-021 (`avoid_print`) |
| Error taxonomy | `core/errors/` | ADR-025 |
| Environment resolution | `app/config/` | ADR-006, ADR-007 |
| The single read surface for environment values | `core/environment/EnvironmentProfile` | ADR-018 |
| Design tokens — every `Color`, spacing, radius, duration | `app/theme/` | ADR-005 |
| The route table | `app/router.dart` | ADR-004 |
| Composition and startup | `main.dart` | ADR-002 |
| AWS resource state | `infrastructure/aws/` | ADR-011, ADR-012 |
| AWS credentials | The Lambda execution role | `aws-sdk-integration.md`, ADR-016 |
| Architecture decisions | `docs/architecture/decisions/` | `docs/architecture/README.md` |

**`EnvironmentProfile` is a read surface, not an owner.** ADR-018 makes it delegate to whichever module owns each value rather than hold a copy — *"a profile holding its own copy of the base URL would be a duplicate that compiles, passes tests, and silently disagrees with `NetworkConfig` the first time someone edits one of the two."* Adding a value there must never mean typing a literal.

---

## 6. Architectural invariants that hold today

Verified by running each check against the working tree, not asserted. Commands in §9.

| Checked | Result |
|---|---|
| Package confinement (I1–I4, I39–I40, I42–I43) | 8 of 8 pass |
| AWS SDK dependency, credential references, hardcoded endpoints (I5–I6) | none present |
| Credential-bearing files, AWS keys, private keys, service-account keys (I7) | none tracked |
| Environment sets across Dart / JSON / shell (I8) | agree — `development`/`staging`/`production` |
| Bucket names from the slug rule (I9) | `vump-platform-dev` · `-staging` · `-prod` |
| Region (I10) | `ap-south-1` in `environments.json` and `env.sh` |
| Generated code drift (I11) | none |
| `dart format` on 59 hand-written files (I12) | 0 changed |
| `flutter analyze` (I13) | no issues |
| Cross-feature imports (I25) | none — `features/` is empty |
| `core/` importing `features/` (I41) | none |
| `app/` importing `features/` (I30) | none |
| `core/` importing `app/theme/` (I31) | none |
| `app/config/` importing `core/` (I32) | none |
| Layer directories at the root of `features/` (I33) | none |
| Forbidden type suffixes (I35) | none across 48 declared types |
| `Failure` subclasses (I37) | none |

---

## 7. Deviations from the approved Volumes

Recorded here and registered in `volume-amendments.md`. **No Volume is silently overridden.**

| Amendment | Volume says | In force | Class |
|---|---|---|---|
| **A-038** | V3.4 §2–3: five layers — Presentation, State, Domain, Data/Repositories, Platform Services — with arrows pointing downward, `Domain → Data` | ADR-001's four layers per feature with the dependency inverted, plus `core/` and `app/` outside any feature | Architecture decision |
| **A-039** | V3.5 §4 lists `recording → projects_tasks`, `upload → recording`, `onboarding`/`settings` → `auth`, `admin_shared → projects_tasks`, then closes by forbidding direct feature-to-feature dependency | ADR-022 R3: no cross-feature import, ever. The listed dependencies are conceptual | Documentation update (the chapter contradicts itself) |
| **A-040** | V3.5 §2: the `core` module owns the `ProviderScope` setup and `go_router` configuration | ADR-002: `main.dart` owns composition, `app/router.dart` owns routing; `core/` is infrastructure only | Architecture decision |
| **A-041** | V3.4 §2, V3.6 §5: the State layer holds `Notifier`s, files suffixed `_notifier.dart` | ADR-023 §4.2: the suffix is `Controller` | Documentation update — **and ADR-023's stated reason is weak here; see A-041** |

**Already registered and still open, relevant to these boundaries:** A-025 (`public_member_api_docs` scoping), A-026 (boundary enforcement uses CI, not `custom_lint`), A-029 (the Isar engine decision), A-034 (doc-comment coverage), A-035 to A-037 (the error model and global handlers).

**Six Volume 3 clauses were checked and found correct**, and are recorded in `volume-amendments.md`'s *Confirmed correct — no amendment* table rather than here: Chapter 3.4 §1 (no sideways feature dependency), §3.4 §5 (pure-Dart testability), §3.5 §3 (`metadata` as its own module), §3.6 §4 (the mirrored test tree), and §3.6 §5 (folder and file naming; generated files never hand-edited).

**The most useful of the six is Chapter 3.4 §1.** Its *"never sideways across features without going through a shared layer"* is exactly ADR-022 R3 — which establishes that §3.5 §4's bullet list is the outlier within Volume 3 itself, not that ADR-022 diverges from Volume 3 as a whole.

---

## 8. Adding or changing a guardrail

- **A new guardrail needs an authority.** An accepted ADR, an approved Volume, the Constitution or the Vision. A rule with no authority is a preference, and this document does not carry preferences.
- **A new invariant is added to §3 with its enforcement column filled in**, including `Review` where that is the honest answer. An invariant added without an enforcement column is how the register stops being useful.
- **Prefer extending an existing CI job to adding one.** A-026 records the position: the `Architecture boundaries` job already enforces the package rules dependency-free, and adopting `custom_lint` would add seven dependencies and a second mechanism for one outcome.
- **A guardrail that contradicts a Volume is registered as an amendment first.** Recording the disagreement is the mechanism; overriding a Volume silently is what the register exists to prevent.
- **Removing a guardrail requires a superseding ADR**, not an edit. The invariants trace to accepted ADRs, and an accepted ADR is never edited to change its meaning.

---

## 9. Verification commands

Every claim in §6 is reproducible. Run from `mobile/`.

**Read the exit codes carefully.** These checks pass when `grep` finds *nothing*, and `grep` exits **1** on no match — so a bare `grep` in a CI job reports failure exactly when the invariant holds. Every check below therefore captures the output and tests for emptiness, which is the same pattern `.github/workflows/ci.yml` uses for precisely this reason.

```bash
#!/usr/bin/env bash
# Local equivalents of the CI guardrails. Run from mobile/.
status=0
check() {  # check <label> <grep output>
  if [ -n "$2" ]; then
    echo "FAIL  $1"; echo "$2" | sed 's/^/        /'; status=1
  else
    echo "ok    $1"
  fi
}

# I1–I4, I39–I43 · each third-party package confined to the module that owns it
for p in "dio lib/core/network/" \
         "flutter_secure_storage lib/core/storage/" \
         "firebase_core lib/core/firebase/" \
         "firebase_auth lib/features/auth/data/" \
         "google_sign_in lib/features/auth/data/"; do
  set -- $p
  check "$1 confined to $2" \
    "$(grep -rl "package:$1" lib --include='*.dart' | grep -Ev "^$2" || true)"
done

# I2 · isar has three owners (ADR-039), so its owner is a regex
check "isar confined to its three owners" \
  "$(grep -rl 'package:isar' lib --include='*.dart' \
     | grep -Ev '^(lib/core/database/|lib/features/[^/]+/data/collections/|lib/features/[^/]+/data/isar_[^/]*\.dart)' || true)"

# I41 · core/ never imports features/
check "core/ does not import features/" \
  "$(grep -rn 'package:mobile/features' lib/core --include='*.dart' || true)"

# I30 · app/ names no feature, except app/router.dart
check "app/ is feature-blind" \
  "$(grep -rn 'package:mobile/features' lib/app --include='*.dart' \
     | grep -v 'lib/app/router.dart' || true)"

# I31 · core/ never imports the theme
check "core/ does not import app/theme/" \
  "$(grep -rn 'package:mobile/app/theme' lib/core --include='*.dart' || true)"

# I32 · app/config/ never imports core/ — the one-way rule
check "app/config/ does not import core/" \
  "$(grep -rn 'package:mobile/core' lib/app/config --include='*.dart' || true)"

# I33 · no layer directory at the root of features/
check "features/ holds capabilities, not layers" \
  "$(ls lib/features 2>/dev/null | grep -E '^(data|domain|application|presentation)$' || true)"

# I37 · no Failure subclass
check "Failure has no subclass" \
  "$(grep -rnE 'extends Failure|implements Failure' lib --include='*.dart' || true)"

exit $status
```

These exit non-zero on a real violation and zero when every invariant holds. I11–I15 are run by their own tooling rather than by grep:

```bash
flutter analyze                                    # I13
git ls-files '*.dart' | grep -vE '\.(g|freezed)\.dart$' \
  | xargs dart format --output=none --set-exit-if-changed   # I12
dart run build_runner build --delete-conflicting-outputs \
  && git diff --quiet -- '*.g.dart' '*.freezed.dart'        # I11
flutter test --coverage                            # I14
```

The jobs in `.github/workflows/ci.yml` are the authoritative versions of I1–I15; the script above is the local equivalent of the parts a developer can run before pushing.

---

## 10. Known gaps

Recorded rather than fixed — this is a documentation and governance mission.

| Gap | Detail | Disposition |
|---|---|---|
| **Six invariants are checkable now and unchecked** | I30, I31, I32, I33, I35, I37 concern code that already exists. §9 gives the command for each | Extend the `Architecture boundaries` CI job. The single highest-value follow-up in this mission |
| **Eight invariants cannot be tested yet** | I25–I29, I34, I36 need `lib/features/` to have contents | Belongs to the mission that builds the first feature, alongside ADR-022 §6.1's procedure |
| **I14 measures coverage but gates nothing** | Volume 9 §9.5 §2 sets `domain` 90%+, `data` 80%+; the job prints the number and does not fail | Deliberate: `features/` is empty, so any threshold would be vacuous |
| **A-038's layer-count divergence is unresolved** | Volume 3 §3.4's five layers and ADR-001's four describe the same system with different names and one inverted arrow. Both are readable as authoritative | Needs the Volume corrected or a note in it; the code follows ADR-001 |
| **A-041 may be resolved the wrong way** | ADR-023 §4.2 rejects `Notifier` on the grounds that it borrows another framework's vocabulary — but `Notifier` is Riverpod's own class name, so under ADR-003 it is native vocabulary, not foreign. The Volume's term may be the better one | ADR-023 is binding until superseded. Worth revisiting before the first controller is written, which is the last cheap moment |
| **No import-graph cycle check** | I26 has no mechanism at any scale | Needs a tool or a script; no cycle is possible today, since `core/` modules import only each other and `features/` is empty |
