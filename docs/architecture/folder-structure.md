# Folder Architecture

The canonical folder structure and import rules for the Vump Technologies repository.

Governed by **ADR-022**. The decisions this document specifies live there; this document is the reference a developer reads before adding a file. Where the two disagree, the ADR governs.

Two earlier decisions are the foundation and are **not restated here**:

- **ADR-001** — Clean Architecture. Four layers per feature, dependencies pointing inward.
- **ADR-002** — Top-level project structure. The `lib/` split into `app/`, `core/`, `features/`, `shared/`.

This document adds what neither covers: the repository root, the responsibilities of each folder in detail, the complete import matrix, and the procedure for adding a feature.

---

## 1. Repository folder structure

```
Vump-Technologies/
├── .github/          CI workflows, PR and issue templates
├── backend/          AWS Lambda + Node.js + TypeScript (ADR-015)
├── docs/             Architecture decisions, source volumes, operations
├── infrastructure/   Version-controlled AWS configuration
├── mobile/           Flutter application
├── CLAUDE.md         Engineering constitution and governance rules
├── LICENSE
└── README.md
```

**`scripts/` and `assets/` do not exist**, deliberately. See §1.7 and §1.8 — both have a defined home and a defined trigger for creation, and neither is created before it has contents.

Each top-level directory is a **deployment or governance boundary**, not a grouping of convenience. The test for whether something belongs at the root is: *does it ship, or govern, independently of everything else here?* A directory that fails that test belongs inside one of the existing ones.

### 1.1 `mobile/`

| | |
|---|---|
| **Purpose** | The Flutter application. The only Dart package in the repository. |
| **Owns** | `lib/`, `test/`, the platform runners (`android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`), `pubspec.yaml`, `analysis_options.yaml` (ADR-021). |
| **Must not contain** | Infrastructure definitions, backend code, or documentation that governs anything outside the app. |
| **Deploys as** | An App Store / Play Store artifact. One build per release, environment selected at compile time by `APP_ENV` (ADR-007, ADR-016, ADR-018). |

`analysis_options.yaml` lives here rather than at the root because it configures a Dart package and there is exactly one. A root copy would govern nothing and would imply a second package exists (ADR-021).

### 1.2 `backend/`

| | |
|---|---|
| **Purpose** | The serverless API. AWS Lambda, Node.js, TypeScript, behind API Gateway. |
| **Owns** | One function per resource domain — `auth-verify`, `projects`, `tasks`, `sessions`, `chunks`, `metadata` (ADR-015). |
| **Must not contain** | Dart code, AWS resource definitions (those are `infrastructure/`), or Python — ADR-015 forecloses it. |
| **Deploys as** | Lambda functions, independently of the mobile release. |

**Currently empty.** ADR-015 decides what fills it and does not fill it. It is a separate root directory rather than a subdirectory of anything because it deploys on its own cadence and shares no toolchain with `mobile/`.

### 1.3 `infrastructure/`

| | |
|---|---|
| **Purpose** | Declared AWS state, version-controlled. |
| **Owns** | `aws/s3/` (bucket policies, lifecycle rules), `aws/iam/` (policy templates), `aws/cloudfront/` (distributions, Origin Access Control), `aws/config/environments.json`, and the shell that applies them. |
| **Must not contain** | Application code of any language, or secrets. Credentials come from the AWS profile and Secrets Manager (ADR-016). |
| **Deploys as** | AWS API calls, applied deliberately and never by CI. |

The separation from `backend/` is the one most easily confused. **`backend/` is code that runs; `infrastructure/` is state that exists.** A Lambda handler is `backend/`; the IAM policy that lets it read a bucket is `infrastructure/`.

### 1.4 `docs/`

| | |
|---|---|
| **Purpose** | The single source of truth for architecture. |
| **Owns** | `architecture/` (this document, the ADR register, the amendment register), `volumes/` (the source specification PDFs), `git/`, `development/`, `operations/`. |
| **Must not contain** | Code, or anything generated from code. |

`docs/architecture/decisions/` is flat and chronological by number — no subfolders, no thematic grouping (`docs/architecture/README.md`).

### 1.5 `.github/`

| | |
|---|---|
| **Purpose** | Everything GitHub executes or renders. |
| **Owns** | `workflows/ci.yml`, `pull_request_template.md`, `ISSUE_TEMPLATE/`. |
| **Must not contain** | Scripts that a developer is expected to run locally. A check that only exists inside a workflow cannot be run before pushing. |

The location is fixed by GitHub, not by us — the one root directory whose name is not our decision.

### 1.6 Root files

`CLAUDE.md`, `README.md`, `LICENSE`, `.env.example`, `.gitignore`. **A file earns a place at the root only by governing the whole repository.** Anything narrower belongs in the directory it governs.

### 1.7 `scripts/` — reserved

**Does not exist. Purpose when it does:** developer and operator entry points that are not part of any deployable — a release preparation script, a local environment bootstrap, a one-off migration runner.

**Trigger for creation:** the first script whose audience is a *developer at the repository root*, that is not an implementation detail of one deployable.

**Why not now:** the only shell in the repository is `infrastructure/aws/env.sh` and `infrastructure/aws/cloudfront/apply-cloudfront.sh`, and both belong where they are. They are not general-purpose tooling; they apply that directory's AWS state and are documented in `infrastructure/aws/README.md`. Moving them to `scripts/` would separate them from the JSON they apply, so the reader of a lifecycle policy would no longer find the command that installs it.

**Rule when created:** a script goes in `scripts/` only if it crosses deployables or has no deployable. A script that only ever touches `infrastructure/` stays in `infrastructure/`; one that only builds the app stays in `mobile/`.

### 1.8 `assets/` — reserved, and constrained

**Does not exist.** Two different things are called assets, and they have **different correct homes**:

| Kind | Home | Why |
|---|---|---|
| **Runtime assets** the app loads — fonts, icons, images, `.riv` files | `mobile/assets/` | **Technical constraint, not preference.** Flutter resolves every path under `pubspec.yaml`'s `flutter: assets:` key relative to the package root, and refuses paths outside it. A repository-root `assets/` **cannot be declared in `pubspec.yaml` at all**, so the app could never load from it. |
| **Source and brand material** the app does not ship — design exports, logo masters, store screenshots, marketing copy | `assets/` at the root, when it exists | It belongs to the repository, not to one deployable, and shipping it inside `mobile/` would inflate the bundle with files no build reads. |

**Trigger for creation:** the first non-shipping brand or design artifact that needs version control. Runtime assets never trigger it — they create `mobile/assets/` and a matching `pubspec.yaml` entry instead.

This distinction is recorded because "put the assets in `assets/`" is the natural instinct and it produces a build that cannot find its fonts.

---

## 2. Flutter folder structure

```
mobile/lib/
├── main.dart       Composition root. Nothing else.
├── app/            What is true of the application as a whole
├── core/           Cross-cutting infrastructure, shared by all features
├── features/       One directory per capability, each per ADR-001
└── shared/         Reusable presentation with no feature owner
```

The four-way split is ADR-002's decision. What follows is what belongs inside each, which ADR-002 leaves open.

### 2.1 `main.dart`

**The composition root, and the only file permitted to know everything.** It wires the provider container, performs asynchronous startup, and calls `runApp`.

It holds no widget definition, no theme, no route table, and no business rule. Its size is the measure of whether the rest of this structure is being honoured: `main.dart` grows only when startup genuinely acquires a new step.

### 2.2 `app/`

Application-wide concerns that belong to no single capability.

```
app/
├── app.dart            Root widget (VumpApp)
├── router.dart         The single route table (ADR-004)
├── home_screen.dart    Placeholder; leaves when the first real screen exists
├── config/             AppConfig, AppEnvironment, AppInfo, AppConstants, AppFeatureFlags
└── theme/              The complete design language (ADR-005)
```

**Belongs here:** the root widget; the route table; configuration resolved from `APP_ENV`; every design token. Per ADR-005, every `Color` literal in the application lives in `app/theme/app_colors.dart` and nowhere else, and spacing, radius, duration, size, elevation and opacity each have a token file beside it.

**Does not belong here:** anything a single feature owns; any business rule; any I/O.

**Feature-blindness, and its one exception.** ADR-002 states that nothing in `app/` may depend on a specific feature. ADR-022 narrows that to a precise rule, because ADR-004 requires the route table to live in `app/router.dart` and a route table must name its screens:

> **`app/router.dart` is the only file in `app/` permitted to import from `features/`, and only from `features/<name>/presentation/`.** Every other file in `app/` names no feature.

`router.dart` may name a screen. It may not import a feature's `domain/`, `data/` or `application/` — a route that needs a use case is a route doing a feature's work.

### 2.3 `core/`

Cross-cutting **infrastructure**. The technical capabilities every feature needs and none of them owns.

```
core/
├── database/       Isar: config, service, migrations, collections   (ADR-009)
├── environment/    EnvironmentProfile — the single read surface     (ADR-018)
├── errors/         AppException taxonomy, Failure, ErrorCode
├── firebase/       Platform initialisation                          (ADR-010)
├── logging/        AppLogger, LogFormatter, LogLevel
├── network/        Dio client, interceptors, NetworkConfig          (ADR-007)
└── storage/        Secure storage service and its interface         (ADR-008)
```

Two conventions are already established and are binding for new modules:

- **`providers/`** — a module that needs to be injected exposes its Riverpod providers in its own `providers/` subdirectory (`core/network/providers/dio_provider.dart`). Consumers depend on the provider, never on the constructor (ADR-003). `errors/` and `environment/` have none, correctly: they are pure types and static resolution with nothing to inject.
- **`interfaces/`** — where core declares an abstraction it also implements, the abstraction lives in `interfaces/` (`core/storage/interfaces/secure_storage_repository.dart`), so a feature can depend on the interface and a test can substitute it.

**The confinement rule.** Each third-party infrastructure package is confined to the one `core/` module that owns it, so that module stays the only thing to rewrite if the package is replaced:

| Package | Owner | Decision |
|---|---|---|
| `dio` | `core/network/` | ADR-007 |
| `isar` | `core/database/` | ADR-009 |
| `flutter_secure_storage` | `core/storage/` | ADR-008 |
| `firebase_core` | `core/firebase/` | ADR-010 |

Enforced by the `Architecture boundaries` CI job. A violation is a defect, not a style preference.

**`core/` reads `app/config/`, and nothing else from `app/`.** Environment-derived values come from `AppEnvironment` and `AppConfig` (ADR-007, ADR-018); the theme is off limits. The full rule and the reason the direction cannot reverse are in §5.2.

**Does not belong in `core/`:** anything one feature uses. A helper written for recording that no other feature calls belongs to recording, however technical it looks. `core/` is defined by *who uses it*, not by *how low-level it is*.

### 2.4 `features/`

One directory per capability, each owning a complete vertical slice per ADR-001. **Currently empty** — no feature has been built.

The name is the capability as a user would describe it — `authentication`, `recording`, `upload`, `tasks`, `settings` — in `snake_case`. Not a layer, not a technology, not a screen.

### 2.5 `shared/`

Reusable **presentation** with no feature owner. **Currently empty.**

**Belongs here:** a design-system component used by two or more features; a formatter or extension used across features; a reusable widget that carries no business rule.

**Does not belong here:** anything with I/O — that is `core/`. Anything one feature uses — that is the feature's `presentation/`. Anything that decides something a domain rule should decide.

**`shared/` does not import `app/theme/`.** A shared component reads colour from `Theme.of(context)` and status colours from the `AppSemanticColors` theme extension, exactly as ADR-005 requires of every widget. Importing the token files directly would bind a reusable component to one application's palette.

**The `core/` versus `shared/` test:** if it performs I/O or owns a third-party infrastructure package, it is `core/`. If it renders or formats, it is `shared/`. ADR-002 keeps them separate deliberately — they have different dependency profiles and different reviewers.

**Promotion is the only route in.** A widget is written inside the feature that needs it and moves to `shared/` when a *second* feature needs it. Nothing is placed in `shared/` speculatively: a component with one caller has not yet been shown to be reusable, and its API is being designed against a single case while pretending to be general.

---

## 3. Feature architecture

Every feature has exactly four layers (ADR-001):

```
features/<name>/
├── domain/          Entities, repository interfaces, business rules
├── data/            DTOs, data sources, repository implementations
├── application/     Use cases and orchestration
└── presentation/    Screens, widgets, view state
```

### 3.1 `domain/` — the centre

**Contains:** entities, value objects, repository *interfaces*, and business rules that hold regardless of how data arrives or how it is displayed.

**Depends on:** nothing outside itself. No Flutter, no Dio, no Isar, no Riverpod, no `core/`.

Pure-Dart annotation packages (`freezed_annotation`, `json_annotation`) are permitted, because they contribute no runtime behaviour and no platform dependency.

**Why the purity is absolute.** It is what makes business rules testable without a render tree or a device, and it is what lets the whole outer world be replaced without touching a rule. The moment `domain/` imports Flutter, a rule can only be tested by building a widget — and `core/errors/failure.dart` already documents this constraint: it is pure Dart *by necessity*, because `domain` consumes it.

> `domain/` may import `core/errors/failure.dart` and `core/errors/error_codes.dart` — and nothing else from `core/`. Those two files are pure Dart with no I/O and no third-party dependency; they exist to be the error vocabulary that crosses layers. Every other `core/` module performs I/O and is forbidden.

### 3.2 `data/` — the outward edge

**Contains:** DTOs, remote and local data sources, mappers, and the repository *implementations* of the interfaces `domain/` declares.

**Depends on:** its own `domain/` (for the interfaces it implements and the entities it produces), and `core/` (for `network/`, `database/`, `storage/`).

**The dependency inversion.** `data/` depends on `domain/`, never the reverse, even though control flows outward. That inversion is the entire point of the layering: `domain/` names what it needs, `data/` supplies it, and the arrow points inward.

**Mapping is mandatory at this boundary.** A DTO never leaves `data/`. Returning a DTO from a repository puts the wire format into the business rules, and the next API change becomes a change to `domain/`. ADR-001 accepts the mapping code as a deliberate cost.

**Must not contain:** business rules, widgets, or a `BuildContext`.

### 3.3 `application/` — orchestration

**Contains:** use cases. One per meaningful operation, each a single entry point that composes repository calls, applies rules and returns a result. Riverpod providers that expose those use cases live here.

**Depends on:** its own `domain/`, and `flutter_riverpod` (ADR-003 makes Riverpod the sole DI mechanism). It may import `core/logging/`.

**Must not depend on:** `data/`. A use case is handed a repository *interface*; it never selects an implementation. If a use case imports `data/`, it is no longer substitutable in a test and the inversion has been undone.

**Must not contain:** widgets, a `BuildContext`, or any `dart:io`.

**Why the layer exists at all** — the question every four-layer structure has to answer. Without it, orchestration lands in the view model, where it acquires a `BuildContext` and stops being testable, or in the repository, where a second caller finds a repository that does more than it says.

### 3.4 `presentation/` — the inward edge

**Contains:** screens, feature-local widgets, controllers/notifiers, and view state.

**Depends on:** its own `application/` (to invoke use cases), its own `domain/` (to display entities), `shared/`, and Flutter.

**Must not depend on:** its own `data/`. This is the single most important prohibition in this document, because it is the one violation that looks harmless: a widget importing a repository implementation directly bypasses every use case, and the business rule is then enforced in some call sites and not others.

**Must not contain:** business rules. A widget may decide *how* to render a state; it may not decide *what* the state means. The test is whether the decision would need to be duplicated on the backend — if so, it is a domain rule that has escaped.

**Colour and spacing literals are forbidden here** by ADR-005. Widgets read colour from `Theme.of(context)`, status colours from the `AppSemanticColors` theme extension, and every spacing, radius and duration from the `app/theme/` tokens.

### 3.5 Dependency direction

```
                  ┌──────────────────┐
                  │  presentation/   │
                  └────────┬─────────┘
                           │ invokes
                           ▼
                  ┌──────────────────┐
                  │  application/    │
                  └────────┬─────────┘
                           │ depends on
                           ▼
                  ┌──────────────────┐
      implements  │     domain/      │  depends on nothing
      ┌──────────▶│   (the centre)   │
      │           └──────────────────┘
┌─────┴──────┐
│   data/    │
└────────────┘
```

Every arrow points inward. `data/` and `presentation/` are the two outer edges and **they never touch each other**.

---

## 4. Folder rules

Each rule states what it prevents. A rule whose justification is only "convention" is not a rule, it is a habit.

### R1 — No business logic in `presentation/`

**Prevents:** a rule enforced in one widget and forgotten in the next screen that shows the same data. Presentation has no single entry point, so a rule placed there has as many implementations as there are widgets that need it.

**Test:** would this decision also have to be made by the backend, or by a second screen? Then it is a domain rule.

### R2 — No feature code in `core/`

**Prevents:** `core/` becoming the place code goes when nobody decides where it belongs. `core/` is defined by having *every* feature as a potential consumer; the moment a module serves one, every other feature carries a dependency it does not use, and `core/` can no longer be reviewed as infrastructure.

**Test:** name the second feature that will call it. If you cannot, it is not `core/`.

### R3 — No cross-feature imports

`features/a/` may never import from `features/b/`, at any layer, in either direction.

**Prevents:** the failure this structure exists to avoid. One cross-feature import makes two features one deployable unit: they can no longer be reviewed, tested, or removed independently, and the import is invisible in the folder tree — the structure still *looks* modular while having stopped being so. It is also the ordinary route to a cycle (R4), since the reverse import always looks locally reasonable.

**What to do instead**, in order of preference:

1. **The concept is infrastructure** → move it to `core/`.
2. **The concept is presentation** → move it to `shared/`.
3. **The concept is a business rule both own** → it belongs to neither. Either it is genuinely one feature that was split too early, or it is a third capability both depend on.
4. **One feature needs to trigger the other** → communicate through state, not imports. A provider in `core/` that both watch, or a domain event, keeps the dependency on a shared abstraction rather than on each other.

**Never** reach for a cross-feature import because the code is "right there". That is exactly how it starts.

### R4 — No circular dependencies

Not between features, not between layers, not between `core/` modules.

**Prevents:** two units that can only be understood, changed and tested together while being filed as separate. Dart permits import cycles, so nothing fails immediately — the cost arrives later, as a change that cannot be made in one place.

The layer rules make intra-feature cycles impossible by construction: dependencies point inward only, and `domain/` imports nothing. R3 does the same between features. A cycle in `core/` means two modules are one module.

### R5 — Shared code lives only in `core/` or `shared/`

There is no third location, no `utils/`, no `common/`, no `helpers/`.

**Prevents:** the directory whose name describes nothing, which accumulates everything, and which nobody can review. ADR-002 rejected a single `common/` for exactly this reason: infrastructure and presentation helpers have different dependency profiles and different reviewers.

**Split rule:** does it perform I/O or own an infrastructure package? → `core/`. Does it render or format? → `shared/`.

### R6 — Every feature is self-contained

A feature directory holds everything that feature owns, and deleting it leaves the application compiling.

**Prevents:** the situation where removing a capability requires an archaeology expedition. It is also the only practical proof that R2, R3 and R5 have been followed: if deleting a feature breaks an unrelated one, something leaked.

**Consequence:** a feature's only outward dependencies are `core/`, `shared/`, and Flutter. Note the asymmetry — `app/router.dart` refers *into* a feature (§2.2), which is why removing a feature also means removing its routes. That is a one-line edit in a known file, not an expedition.

### R7 — One public class per file, `snake_case` filenames

**Prevents:** a file whose name does not predict its contents, and a symbol that cannot be found from its name. Enforced by `file_names` and checked by `flutter analyze` (ADR-021). `CLAUDE.md` states both as coding standards.

### R8 — No layer directories at the root of `features/`

`features/data/` is the layer-first structure ADR-001 explicitly rejects. The layers belong *inside* each feature.

**Prevents:** exactly the defect Mission 0.18.1 corrected — four empty layer directories sat at `features/` for eleven missions, described in ADR-001 as compliance while being the structure it rejected. A first feature built against that scaffold would have inherited it.

**Test:** every directory directly under `features/` is a capability name. If one is `data`, `domain`, `application` or `presentation`, the mistake has already happened.

---

## 5. Import rules

### 5.1 The matrix

Rows import columns. ✔ permitted, ✘ forbidden.

| From ↓ · May import → | `app/config/` | `app/theme/` | `core/` | `shared/` | own `domain/` | own `application/` | own `data/` | own `presentation/` | other feature |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `main.dart` | ✔ | ✔ | ✔ | ✘ | — | — | — | — | ✘ |
| `app/` (except `router.dart`) | ✔ | ✔ | ✔ | ✔ | — | — | — | ✘ | ✘ |
| `app/router.dart` | ✔ | ✔ | ✔ | ✔ | — | — | — | ✔ | — |
| `core/` | ✔¹ | **✘** | ✔ | ✘ | — | — | — | — | ✘ |
| `shared/` | ✔¹ | ✘² | ✔ | ✔ | — | — | — | — | ✘ |
| `features/x/domain/` | ✘ | ✘ | ✘³ | ✘ | ✔ | ✘ | ✘ | ✘ | ✘ |
| `features/x/data/` | ✔¹ | ✘ | ✔ | ✘ | ✔ | ✘ | ✔ | ✘ | ✘ |
| `features/x/application/` | ✔¹ | ✘ | ✔⁴ | ✘ | ✔ | ✔ | **✘** | ✘ | ✘ |
| `features/x/presentation/` | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | **✘** | ✔ | ✘ |

¹ `app/config/` only, and the direction is one-way — see §5.2.
² A shared widget reads colour from `Theme.of(context)` and status colours from the `AppSemanticColors` theme extension, per ADR-005. It does not import the token files.
³ Except `core/errors/failure.dart` and `core/errors/error_codes.dart` — pure Dart, no I/O, and the error vocabulary that must cross every layer.
⁴ `core/logging/` and the error taxonomy. A use case that needs `core/network/` directly is doing `data/`'s job.

The three bold cells are the ones that matter most and are the easiest to violate by accident. See §5.3 and §5.2.

### 5.2 `core/` and `app/config/` — one-way, and why the asymmetry is correct

`core/` is infrastructure: it knows how to talk to a network, a database and a keychain, and it knows nothing about this application's appearance.

**`core/` may import `app/config/`.** This is not a concession to existing code — it is what ADR-007 and ADR-018 require. `NetworkConfig` derives base URLs and timeouts from `AppEnvironment`; `AppLogger` derives its level from it; `EnvironmentProfile` in `core/environment/` delegates to `AppConfig` by design, because a profile holding its own copy of a base URL would be a second source of truth that silently disagrees with the first.

The dependency is safe because of what `app/config/` is: const-evaluable configuration with no behaviour and no I/O (ADR-006). Importing it couples `core/` to a compile-time value, not to the application's identity or its widget tree.

**The direction is strictly one-way.** `app/config/` must never import `core/`. `core/network/network_config.dart` states this rule in its own doc comment — *"this class reads `AppEnvironment`; nothing in `app/config/` may import from here"* — and it holds today: `app/config/` imports nothing from `core/`. Reversing it would create the cycle R4 forbids, and would put a base URL in two places at once, which is the failure ADR-018 exists to prevent.

**`core/` must not import `app/theme/`.** A database service that imports a colour token has a presentation dependency in its I/O path, and `core/` stops being liftable into a second application. This is the prohibition that the blanket rule "`core/` may not import `app/`" was reaching for, and it is the precise form of it.

**`core/` must not import `shared/`.** `shared/` is presentation. Infrastructure importing a widget inverts the stack.

`core/` therefore stays substitutable: it depends on a compile-time enum and on nothing that renders.

### 5.3 Why `presentation/` and `application/` may not import `data/`

These are the two prohibitions that produce the worst outcome while looking most convenient.

The repository *interface* lives in `domain/`; the *implementation* lives in `data/`. A layer that imports `data/` has bound itself to one implementation:

- **The test substitution stops working.** A fake can replace an interface, not a concrete class the caller named directly.
- **The use case stops being the single entry point.** A widget that reaches `data/` skips whatever rule the use case applied, so the rule holds on some screens and not others — which is worse than not having it, because it looks enforced.
- **The failure is silent.** Everything compiles, the feature works when demonstrated, and the defect surfaces as an inconsistency between two screens months later.

The wiring happens in providers: `data/` exposes a provider that returns the interface type, and `application/` depends on the provider. The implementation is named in exactly one place.

### 5.4 Package imports only

Every import inside `lib/` is a `package:mobile/...` import. Relative imports are forbidden and enforced by `always_use_package_imports` (ADR-021, Volume 3 §3.7 §2).

**Why:** a relative import makes a file's position in the tree part of its meaning, so moving a file rewrites unrelated files, and two different paths can resolve to the same library — which produces two copies of a "singleton" and a type that is not equal to itself.

### 5.5 Enforcement, and what is not yet enforced

**Enforced by CI today** — the `Architecture boundaries` job checks the four package-confinement rules of §2.3, and `flutter analyze` enforces `always_use_package_imports` and `implementation_imports` (ADR-021).

**Documented but not yet machine-checked:** R3 (cross-feature imports), R4 (cycles), the `presentation/`↛`data/` and `application/`↛`data/` prohibitions, the `app/`↛`features/` rule with its `router.dart` exception, `core/`↛`app/theme/`, and the one-way direction of `core/`→`app/config/`.

The last three are checkable **now** and are the natural first extension of the `Architecture boundaries` job, since they concern code that already exists. All of them were verified by hand for this mission and none is violated.

This is stated plainly rather than glossed. Every one of these is a grep over `lib/`, and each becomes checkable the moment `features/` has contents — a rule against cross-feature imports cannot be tested with zero features. **The gap closes in the mission that builds the first feature**, and until then these rules are binding in writing and unenforced in fact.

Amendment A-026 records the related position: boundary enforcement uses the CI job rather than `custom_lint`, because the job already covers the package rules without adding seven dependencies. Extending that job is the intended mechanism, not a new tool.

---

## 6. Adding a feature

The architecture is designed so that a new capability changes **one new directory and one existing line**. If adding a feature requires touching anything else, either the feature is misplaced or a rule above is being broken.

### 6.1 The procedure

```
mobile/lib/features/<feature_name>/
├── domain/
│   ├── entities/
│   └── repositories/          Interfaces only
├── data/
│   ├── dtos/
│   ├── datasources/
│   ├── mappers/
│   └── repositories/          Implementations of domain/repositories/
├── application/
│   ├── usecases/
│   └── providers/
└── presentation/
    ├── screens/
    ├── widgets/
    └── controllers/
```

1. **Create `features/<name>/`** with the four layers. Create only the subdirectories the feature actually needs — the tree above is the vocabulary, not a checklist.
2. **Write `domain/` first.** Entities and repository interfaces, in pure Dart. If this step needs a Flutter import, the modelling is wrong.
3. **Write `data/`.** DTOs, data sources against `core/`, mappers, and the implementations of the interfaces from step 2.
4. **Write `application/`.** One use case per operation, depending on the interfaces — never the implementations.
5. **Write `presentation/`.** Screens and widgets that invoke use cases and read tokens from `app/theme/`.
6. **Register routes** — add the feature's routes to `app/router.dart` (§2.2). This is the one existing file that changes.
7. **Add the nested analysis configuration** required by Volume 3 §3.7 §2 and amendment A-025, which scopes `public_member_api_docs` to `domain/` and `data/`:

   ```
   features/<name>/domain/analysis_options.yaml
   features/<name>/data/analysis_options.yaml
   ```
   ```yaml
   include: ../../../../../analysis_options.yaml
   linter:
     rules:
       - public_member_api_docs
   ```

8. **Mirror the structure in `test/`.** `test/` mirrors `lib/`, so a feature's tests live at `test/features/<name>/<layer>/`. Volume 9 §9.5 §2 sets per-layer coverage targets — `domain` 90%+, `data` 80%+ — which the `Test` CI job measures and does not yet gate on, because there is nothing to gate.

### 6.2 The five planned features

| Feature | Adds | Changes elsewhere |
|---|---|---|
| `authentication` | `features/authentication/` | One route registration |
| `recording` | `features/recording/` | One route registration |
| `upload` | `features/upload/` | One route registration, if it has a screen |
| `tasks` | `features/tasks/` | One route registration |
| `settings` | `features/settings/` | One route registration |

None requires an architectural change. Each is a directory under `features/` and a line in `app/router.dart`.

Two will genuinely test the rules, and both are worth anticipating:

- **`recording` and `upload` are the R3 test case.** Recording produces chunks; upload consumes them. The temptation to have `upload/` import `recording/`'s entity will be immediate and locally sensible. It is forbidden. The chunk is a concept both depend on, which means it belongs to neither — the resolution is R3's option 3 or 4, decided when the second of the two is built, not improvised at the import site.
- **`settings` is the R2 test case.** Settings reads and writes values that every other feature observes, which makes it look like `core/`. It is not: it is a capability with screens and rules. The *storage* it uses is `core/storage/`; the settings feature is a feature.

### 6.3 What must never happen when adding a feature

- Adding a directory under `features/` that names a layer instead of a capability (R8).
- Importing another feature because the code is already written (R3).
- Putting a first widget in `shared/` before a second feature needs it (§2.5).
- Adding a module to `core/` for one feature (R2).
- Changing `app/` beyond the route registration in `router.dart` (§2.2).

---

## 7. Known discrepancy

**`lib/features/` and `lib/shared/` are not in the repository.** Both exist in a local working tree as empty directories, but git does not track empty directories and neither contains a file, so **a fresh clone has neither.**

ADR-002 declares both, stating they are "declared so that the first file needing them has an unambiguous home". That intent is not met by a directory a clone does not receive.

Per the governance rule that code is the defect where it disagrees with an accepted ADR, this is a defect in the repository, not in ADR-002. It is recorded rather than fixed here because the fix is a placeholder file (`.gitkeep`) in each directory, and Mission 0.19.2 was explicitly constrained against creating placeholder folders. **It is a two-file change and should be made deliberately, in its own commit.**

Practical impact today is limited — the first feature mission creates real files in `features/` — but until then, every document that says "`lib/features/` is empty" is describing a directory a new contributor does not have.
