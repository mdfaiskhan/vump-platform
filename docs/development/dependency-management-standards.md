# Dependency Management Standards

The canonical dependency management standard for the Vump Technologies repository.

Governed by **ADR-030**. Where this document and the ADR disagree, the ADR governs.

**Volume 3, Chapter 3.8 is the authority** — *"Dependency Management: How Packages Enter the Project, and How They're Kept Under Control"*. It fixes the monorepo question, a four-tier pinning policy, a six-item admission checklist, a review cadence and a minimal-surface principle. This document applies those to the 18 dependencies that exist, and records what is absent as absent.

**Nothing already governed is restated.** Cited, not duplicated:

| Already fixed by | What it fixes |
|---|---|
| Volume 3 Ch. 3.8 | The monorepo decision, pinning tiers, the admission checklist, review cadence, minimal surface. **The authority for this document** |
| Volume 3 Ch. 3.1 | The technology stack — one package per real need |
| Volume 0 Ch. 0.2 §2 | *"Any new third-party package or service must be recorded against the relevant Volume 3/4/6 chapter before being added"*; Windows-first development |
| ADR-022 §2.3 · `architecture-guardrails.md` | Package confinement — which module owns which package, and the CI job that checks it |
| ADR-021 | `secure_pubspec_urls`; generated code is analysed, not excluded |
| ADR-025 §7 | A new package brings a conversion boundary with it |
| ADR-028 · `review-checklist.md` §4.9 | The dependency items a reviewer checks |
| ADR-029 · `testing-standards.md` §1 | Which test tools are named, and which are absent |
| ADR-015 | The backend runtime and its AWS SDK — a separate dependency tree |

---

## 1. Shape — one package, no monorepo

**The app is a single Flutter package. There is no Melos workspace and no internal package split.** Verified: no `melos.yaml` anywhere in the repository.

Volume 3 §3.8 §2 fixes this and states the trade: *"Chapter 3.5's module boundaries are enforced by folder convention and lint rules (Chapter 3.7), not by splitting each module into its own publishable package. A monorepo buys stronger compile-time isolation between modules, at the cost of meaningfully more tooling overhead — for a single app with one team, that trade isn't worth it yet."*

**Revisited only if the codebase splits across multiple apps** — §3.8 §2 names a genuinely separate Admin web app as the trigger.

**This is why ADR-022's import rules matter as much as they do.** A Melos monorepo would make a cross-feature import a compile error; folder convention makes it a review item. The guardrail register records exactly which of ADR-022's rules are machine-checked as a result (ADR-026 I25–I33).

---

## 2. What is depended on

**15 direct, 6 dev, 105 transitive — 126 packages resolved.** Two of the 21 direct entries are SDK-provided (`flutter`, `flutter_test`), so 19 come from pub.

**Re-derived from `pubspec.lock` on 2026-08-13**, per §11's standing obligation rather than trusted from the previous revision. Mission 2.2 added `firebase_auth` and `google_sign_in`, which brought eight transitive packages with them. The figures this section previously carried — "12 direct … 115 resolved" — did not reconcile against the lockfile even before that change; the numbers below were counted, not adjusted.

| Package | Constraint | Tier (§3) | Owning module | Governed by |
|---|---|---|---|---|
| `flutter_riverpod` | `^2.6.1` | Core | — (used everywhere) | ADR-003 |
| `go_router` | `^14.6.2` | Core | `app/router.dart` | ADR-004 |
| `dio` | `^5.7.0` | Core | `core/network/` | ADR-007 |
| `isar` | `^3.1.0+1` | Core | `core/database/` | ADR-009 |
| `isar_flutter_libs` | `^3.1.0+1` | Core | `core/database/` | ADR-009, **A-029** |
| `flutter_secure_storage` | `^9.2.2` | Core | `core/storage/` | ADR-008 |
| `firebase_core` | `^4.13.0` | Core | `core/firebase/` | ADR-010 |
| `firebase_auth` | `^6.5.7` | Core | `features/auth/data/` | ADR-034 |
| `google_sign_in` | `^7.2.0` | Core | `features/auth/data/` | ADR-034, **A-053** |
| `cloud_functions` | `^6.3.6` | Leaf | `features/auth/data/` | ADR-036 — **temporary** |
| `cloud_firestore` | `^6.8.0` | Leaf | `features/auth/data/` | ADR-036 — **temporary** |
| `camera` | `^0.12.0+2` | Core | `features/recording/data/` | Volume 3 Ch. 3.1, **A-057** |
| `shared_preferences` | `^2.5.5` | Leaf | `features/recording/data/` | Volume 5 Ch. 5.2 §2, **A-057** |
| `logger` | `^2.5.0` | Leaf | `core/logging/` | ADR-027 |
| `freezed_annotation` | `^2.4.4` | Leaf | — (annotations) | — |
| `json_annotation` | `^4.9.0` | Leaf | — (annotations) | — |
| `cupertino_icons` | `^1.0.8` | Leaf | — | — |
| `build_runner` | `^2.4.13` | Dev | — | — |
| `freezed` | `^2.5.2` | Dev | — | — |
| `isar_generator` | `^3.1.0+1` | Dev | — | **A-048** |
| `json_serializable` | `^6.8.0` | Dev | — | — |
| `flutter_lints` | `^6.0.0` | Dev | — | ADR-021 |

**Every non-SDK dependency carries an explicit caret constraint.** Verified: no bare, unconstrained dependency exists, which satisfies §3.8 §4 item 6.

**Every package has a documented reason.** Eleven of the fifteen runtime packages are named by an accepted ADR or, for the two added at Mission 3.1, by a Volume chapter plus the amendment that records the deviation; the rest are annotations, icons or lint rules. Nothing is present without a decision behind it, which is Volume 0 §2's requirement.

**`camera` is Core and `shared_preferences` is Leaf, which is not an inconsistency.** `camera` is the recording engine's reason to exist — Volume 5 is built on it and no alternative is substitutable without redesigning the capture path, which is §3's test for Core. `shared_preferences` holds one cached verdict behind the `WideAngleEligibilityCache` port; swapping it for any other key-value store would change one file. **`camera` is also the one Core package named by a Volume rather than by an ADR**: Volume 3 Ch. 3.1 fixes it by name in the mobile stack table, so no ADR was needed to choose it, and A-057 records only what that table left open.

**Two entries are marked temporary, and that is a tier of its own in practice.** `cloud_functions` and `cloud_firestore` exist only to reach the invite-code runtime ADR-036 stands up, and both leave the project when that runtime is retired at Mission 6/7 — redemption becomes a `/v1/...` route carried by `dio`, which is already here. They are classed Leaf rather than Core deliberately: nothing architectural depends on them, and their removal should be a deletion rather than a migration.

**The two Firebase-product entries are the first packages owned by a feature rather than by `core/`.** ADR-010 keeps the Firebase *platform* in `core/firebase/`; a Firebase *product* is owned by the module that consumes it, so `features/auth/` rather than `core/` is the unit that stays replaceable. Both carry a confinement line in the `Architecture boundaries` job, so this is an enforced rule and not documentation only.

**`pubspec.yaml` is grouped by purpose, not alphabetised** — state management, navigation, networking, logging, secure storage, Firebase, database, code generation — each group carrying a comment. ADR-023 §11 records why `sort_pub_dependencies` is deliberately excluded from the lint set: alphabetical order would destroy the grouping, which is the more useful organisation of about a dozen entries.

---

## 3. Version pinning

Volume 3 §3.8 §3 fixes four tiers. Reproduced with the repository's assignment:

| Tier | Rule | Why (§3.8 §3) |
|---|---|---|
| **Flutter SDK** | Pinned to a specific stable version *"in fvm config, not just 'stable channel'"* | *"Windows-first development across possibly multiple machines/CI runners must all build against the exact same Flutter version, or subtle version-skew bugs become a Windows-specific debugging tax"* |
| **Core architectural** | Caret on the minor version, *"reviewed and bumped deliberately, never on an automated schedule alone"* | *"Load-bearing for the whole app; an unreviewed automatic upgrade could silently change behavior in the upload/metadata path"* |
| **Leaf utility** | Caret, *"can be bumped opportunistically as part of unrelated PRs"* | *"Lower blast radius"* |
| **Dev-only** | Caret, *"bumped freely"* | *"Never ships in the release binary"* |

**The Dart SDK constraint is `^3.12.2`**, resolving to `>=3.12.2 <4.0.0` with `flutter: >=3.38.4` in the lockfile.

**fvm is not adopted.** The SDK is pinned in one place instead — `FLUTTER_VERSION: 3.44.9` in the CI workflow. Tracked as **A-024**, which records precisely why that is not equivalent: *"the pin is asserted in one file rather than derived from a shared source, so CI and a developer's machine can still diverge, just no longer silently on Google's release schedule."*

**§3.8 §3 names `drift` among the core architectural packages.** The engine is Isar (ADR-009); the tier assignment transfers, the package name does not. Same known substitution A-026 records for the CI boundary check.

**`pubspec.lock` is committed**, and that is correct for an application: it makes a build reproducible from a clone and is what let this document's transitive audit run without resolving. A library would not commit it.

---

## 4. Adding a dependency

Volume 3 §3.8 §4 fixes a six-item checklist, applied *"before it's added, not after"*. Reproduced as the process, with the mechanism that checks each:

| # | §3.8 §4 asks | Mechanism |
|---|---|---|
| 1 | Does an already-approved package solve this? *"Prefer extending existing usage over adding a new package for a marginally better fit"* | Reviewer |
| 2 | Does it build cleanly in the Windows-first workflow — *"does adding it break `flutter analyze` / `flutter test` on Windows"*? Native plugins with Windows build steps *"are checked explicitly, since this has been a known pain point"* | Author locally; CI runs Linux only |
| 3 | Is it actively maintained — *"a commit or release within the last 6–12 months, no unresolved critical issues"* — and does it support the pinned Flutter SDK? | Reviewer |
| 4 | Is the license commercial-compatible? *"MIT, BSD, Apache 2.0 are pre-approved; anything else is checked individually"* | Reviewer |
| 5 | If load-bearing rather than a small utility, does it need its own ADR? | Reviewer |
| 6 | Is it added with an explicit constraint per §3, *"never a bare, unconstrained dependency"*? | Reviewer |

**Three obligations from elsewhere attach to the same moment:**

- **A confinement entry.** ADR-022 §2.3 confines each third-party infrastructure package to one module, and the `Architecture boundaries` CI job checks four of them. A new package with an owning module needs a line in that job, or the confinement is documentation only — which is already true of `logger` (ADR-027 §2).
- **A conversion boundary.** ADR-025 §7: a package that can fail needs its errors converted at the module that owns it, so nothing above sees a third-party error type.
- **A record against a Volume chapter.** Volume 0 §2 requires it *before* the package is added.

**Item 2 is the one this project cares about more than most**, and §3.8 §1 says so explicitly: *"every dependency must actually build on Windows for the parts of the workflow that run there."* **CI cannot check it** — the workflow runs `ubuntu-latest`, so Windows buildability is verified only on a developer's machine. Recorded in §9.

---

## 5. Review cadence and current staleness

Volume 3 §3.8 §5 fixes two rules:

- *"`flutter pub outdated` is run and reviewed at the start of each development phase boundary (per Volume 1's roadmap phases), **not continuously** — batching upgrades avoids constant churn while still preventing the dependency tree from silently aging for a year or more."*
- *"Any dependency with a published security advisory is patched immediately, outside the normal cadence, regardless of phase boundary."*

**No mechanism exists for either.** Verified: no CI step runs `flutter pub outdated`, no Dependabot configuration, no Renovate configuration, and no security-advisory scanning of any kind. §3.8 §7 defers *"the exact CI step that runs `flutter pub outdated` / security scanning"* to Volume 7, which does not specify it either.

**Measured state, from `flutter pub outdated` on 2026-08-11:**

| Finding | Count |
|---|---|
| Direct dependencies constrained below a resolvable version | **7** |
| Discontinued packages in the tree | **4** |
| Packages with newer versions blocked by constraints | **26** |

**Direct dependencies behind their latest release:**

| Package | Current | Latest | Gap |
|---|---|---|---|
| `go_router` | 14.8.1 | 17.5.0 | 3 majors — **resolvable now** |
| `flutter_secure_storage` | 9.2.4 | 11.0.0 | 2 majors — **resolvable now** |
| `flutter_riverpod` | 2.6.1 | 3.4.2 | 1 major — blocked |
| `freezed` | 2.5.2 | 3.2.5 | 1 major — blocked |
| `freezed_annotation` | 2.4.4 | 3.1.0 | 1 major — blocked |
| `build_runner` | 2.4.13 | 2.16.0 | 12 minors — blocked |
| `json_serializable` | 6.8.0 | 6.14.1 | 6 minors — blocked |

**Discontinued packages in the tree:** `flutter_secure_storage_macos` (3.1.3), `js` (0.6.7), `build_resolvers`, `build_runner_core`. All four are transitive, so none is directly fixable — three of the four disappear on a `flutter_secure_storage` or `build_runner` upgrade.

Registered as **A-047**.

---

## 6. Transitive dependencies

**97 transitive packages against 18 direct.** The ratio is the point of §3.8 §6's minimal-surface principle: *"every dependency is a piece of code the team didn't write but is nonetheless responsible for — for its bugs, its maintenance lifecycle, and its Windows-buildability."*

**Transitive packages are not directly managed.** They are resolved, locked and audited, not constrained: adding a constraint on a transitive package to force a version is a `dependency_overrides` entry, and there is none in `pubspec.yaml`. That is the correct default — an override silences the resolver rather than satisfying it.

**When an override is unavoidable**, it carries a comment naming the upstream issue and the condition for removal. None exists today, so this is a rule stated ahead of its first use.

**The transitive tree is where the analyzer version is decided**, which §7 covers, and it is the reason a single unmaintained dev dependency can hold back eight packages.

---

## 7. Code generation and the toolchain constraint

Four packages form the codegen chain: `build_runner`, `freezed` + `freezed_annotation`, `json_serializable` + `json_annotation`, `isar_generator`.

**`isar_generator 3.1.0+1` is the binding constraint on the entire chain.** Its published `pubspec.yaml` declares:

```yaml
environment:
  sdk: ">=2.17.0 <3.0.0"

dependencies:
  analyzer: ">=4.6.0 <6.0.0"
  source_gen: ^1.2.2
  dart_style: ^2.2.3
```

Three consequences, all verified:

**It declares no support for Dart 3, and the project runs Dart 3.12.2.** It resolves only because pub relaxes the upper SDK bound of packages published before Dart 3. The package is running outside its own declared support range.

**It caps `analyzer` below 6.0.0** while 14.1.0 is current, and **`source_gen` at 1.x** while 4.2.4 is current. The resolved tree therefore holds `analyzer 5.13.0`, `source_gen 1.5.0`, `_fe_analyzer_shared 61.0.0` against a current 105.0.0.

**That cap propagates to `freezed`.** The resolver states it directly: *"because `freezed >=2.5.8` depends on `source_gen ^2.0.0` and `isar_generator >=3.0.1` depends on `analyzer >=4.6.0 <6.0.0`… version solving failed"*, concluding *"because mobile depends on both `freezed ^2.5.2` and `isar_generator ^3.1.0+1`, version solving failed."*

**So `freezed` cannot pass 2.5.7, and `flutter_riverpod` cannot reach 3.x, while `isar_generator` is present.** Registered as **A-048**. This is a new, concrete consequence of the engine problem A-029 records for `isar_flutter_libs` — a different package, a different mechanism, and one A-029 does not mention.

**`analyzer` is not a direct dependency and is not pinned by this project.** It arrives through the codegen chain, which is why ADR-021's 176 lint rules are evaluated by whatever `flutter analyze` ships with rather than by the resolved `analyzer` package — the two are independent, and the lint set is unaffected.

**Generated output is committed** (ADR-021, Volume 6 §6.2, Volume 3 §3.6 §5) and checked by the `Generated code drift` CI job, so a toolchain change that alters generator output fails loudly rather than silently.

---

## 8. Security

**All 16 pub-sourced dependencies carry a pre-approved licence.** Verified against each package's `LICENSE`: MIT (`cupertino_icons`, `flutter_riverpod`, `dio`, `logger`, `freezed_annotation`, `json_annotation`, `freezed`, `json_serializable`), BSD-3-Clause (`flutter_secure_storage`, `go_router`, `firebase_core`, `build_runner`, `flutter_lints`), Apache-2.0 (`isar`, `isar_flutter_libs`, `isar_generator`). No package requires the individual check §3.8 §4 item 4 reserves for anything else.

**Nothing verifies licences on an ongoing basis.** A transitive package could arrive under a copyleft licence and nothing would notice.

**Package sources are constrained by the analyzer.** `secure_pubspec_urls` (ADR-021) makes a `git:` or `http:` dependency source an analyzer diagnostic — *"a `git:` or `http:` dependency URL fetches code over a channel nobody verifies."* Every dependency resolves from `pub.dev`.

**The mobile app may not depend on an AWS SDK at all.** The `AWS credential isolation` CI job fails on any package matching `aws[_-]`, `amplify[_-]`, `minio` or `s3_` in `pubspec.yaml`. Volume 4 §4.10 §2 is the authority: the app reaches S3 only through backend-issued presigned URLs, which are a capability rather than an identity. This is the only dependency rule enforced by a dedicated CI job.

**Firebase is one package today.** `firebase_core` initialises the platform and nothing else; ADR-010 records that adding a product *"means adding a dependency and a provider for it — never editing initialisation code."* `firebase_crashlytics` is selected by Volume 6 §6.9 §3 and not adopted (**A-037**).

**No dependency vulnerability scanning exists** — no `dart pub audit` step (the command does not exist in this SDK), no third-party scanner, no advisory feed. §3.8 §5's *"patched immediately"* rule has no trigger, so it depends on someone noticing.

**The backend's dependency tree does not exist yet.** ADR-015 fixes Node.js and TypeScript with AWS SDK for JavaScript v3 (`@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`) and the Firebase Admin SDK. `backend/` is empty, so there is no `package.json`, no lockfile and no npm audit. When it exists it is a **separate tree with separate rules** — this document governs `mobile/`.

---

## 9. CI verification

**No CI job verifies dependencies as such.** What the nine jobs do check, indirectly:

| Job | Dependency-relevant effect |
|---|---|
| `Analyze` | `secure_pubspec_urls` — no `git:`/`http:` sources |
| `AWS credential isolation` | No AWS SDK package in `mobile/pubspec.yaml` |
| `Generated code drift` | Committed generated output matches what the resolved generator produces |
| `Test`, `Format`, `Analyze` | Run `flutter pub get`, so an unresolvable `pubspec.yaml` fails the build |

**What is not checked:** staleness (§5), licences (§8), advisories (§8), Windows buildability (§4 item 2 — CI runs `ubuntu-latest`), and whether a new package was confined and given a conversion boundary (§4).

**CI pins the SDK** at `FLUTTER_VERSION: 3.44.9` rather than tracking `channel: stable`, so the resolved tree cannot move because Google released (A-024).

---

## 10. Gaps

Recorded rather than fixed — this is a documentation and governance mission.

| Gap | Evidence | Disposition |
|---|---|---|
| **`isar_generator` caps the codegen toolchain** | Declares `sdk: <3.0.0`, `analyzer: <6.0.0`, `source_gen: ^1.2.2`; blocks `freezed` past 2.5.7 and `flutter_riverpod` past 2.x (§7) | **A-048.** Resolved by A-029's engine decision — `isar_community 3.3.2` or Drift — not by a version bump |
| **7 direct dependencies behind a resolvable version** | §5. `go_router` 3 majors, `flutter_secure_storage` 2 majors, both **upgradable today** | **A-047.** The two unblocked ones are the cheapest available improvement |
| **No review cadence mechanism** | No CI step, no Dependabot, no Renovate | **A-047.** §3.8 §5 requires phase-boundary review; nothing triggers it |
| **No security advisory scanning** | Nothing watches for advisories; §3.8 §5's "patched immediately" has no trigger | **A-047** |
| **No licence verification** | All 16 are compliant today, checked by hand for this document; nothing re-checks | **A-047** |
| **Windows buildability is unverified by CI** | §3.8 §1 calls it the constraint *"this project cares about more than most"*; CI runs `ubuntu-latest` only | Recorded. A Windows CI runner would close it |
| **`logger` confinement unchecked** | The CI job covers four packages; `logger` is a fifth with a documented owner | Already recorded by ADR-027 §2. One line in the existing job |
| **4 discontinued transitive packages** | `flutter_secure_storage_macos`, `js`, `build_resolvers`, `build_runner_core` | Three clear on upgrading `flutter_secure_storage` and `build_runner` |
| **No `dependency_overrides` policy in practice** | None exists, so §6's rule is untested | Correct today |
| **Backend dependency tree absent** | `backend/` is empty (ADR-015) | Governed separately when it exists |

---

## 11. Maintenance

- **A new package runs §4's six-item checklist before it is added**, plus the confinement entry, the conversion boundary and the Volume record.
- **A core architectural package is never bumped on an automated schedule alone** (§3.8 §3). A deliberate, reviewed bump in its own commit.
- **A dev-only package is bumped freely** — it does not ship.
- **`flutter pub outdated` is reviewed at each phase boundary**, not continuously, and its output belongs in the phase's record.
- **A security advisory is patched immediately**, outside the cadence.
- **Removing a package removes its confinement entry, its conversion boundary and its ADR reference** — a stale confinement check passes forever and protects nothing.
- **Every figure in §2, §5, §6 and §8 is re-derived, not copied.** They come from `pubspec.yaml`, `pubspec.lock` and `flutter pub outdated`, and §5's numbers will be stale by the next release of anything.
- **Prefer extending an approved package to adding a new one** (§3.8 §4 item 1, §3.8 §6). One state management library, one HTTP client, one router.
