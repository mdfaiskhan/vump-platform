# mobile

The Vump Technologies Flutter application. The only Dart package in the repository.

Governed by the accepted ADRs in [`docs/architecture/decisions/`](../docs/architecture/decisions/). Where this document and an accepted ADR disagree, the ADR governs.

## Layout

```text
lib/
├── main.dart       Composition root. Nothing else.
├── app/            Root widget, router, configuration, theme
├── core/           Cross-cutting infrastructure — network, database, storage,
│                   logging, errors, firebase, environment
├── features/       One directory per capability, four layers each (empty)
└── shared/         Reusable presentation with no feature owner (empty)
```

Placement rules, the import matrix and how to add a feature are in [`docs/architecture/folder-structure.md`](../docs/architecture/folder-structure.md).

## Running

```bash
cp .env.example .env.dev             # mobile/.env.example — holds APP_ENV, no secrets
flutter pub get
flutter run --dart-define-from-file=.env.dev
```

Three environments — `development`, `staging`, `production` — selected by `APP_ENV`. Everything else (API base URL, S3 bucket, logging level, feature flags) is derived from that one value. See [ADR-018](../docs/architecture/decisions/ADR-018-environment-profile.md).

## Checks

```bash
flutter analyze                      # must report no issues
flutter test --coverage
dart format .
```

`analysis_options.yaml` is the canonical static-analysis configuration: 176 lint rules, three type-system strictness flags, and a severity map, each rule documented in place. See [ADR-021](../docs/architecture/decisions/ADR-021-static-analysis-configuration.md).

Generated sources are committed, so a fresh clone builds without running `build_runner`. After changing an Isar collection or a Freezed model:

```bash
dart run build_runner build --delete-conflicting-outputs
```

CI fails if committed generated files do not match what the generator produces.

## Reference

| Topic | Document |
|---|---|
| Folder rules, import matrix, adding a feature | [`folder-structure.md`](../docs/architecture/folder-structure.md) |
| Naming — suffix vocabulary, every category | [`naming-conventions.md`](../docs/architecture/naming-conventions.md) |
| Static analysis | [ADR-021](../docs/architecture/decisions/ADR-021-static-analysis-configuration.md) |
| Layers per feature | [ADR-001](../docs/architecture/decisions/ADR-001-clean-architecture.md), [ADR-022](../docs/architecture/decisions/ADR-022-folder-architecture-rules.md) |
| State management | [ADR-003](../docs/architecture/decisions/ADR-003-state-management-riverpod.md) |
| Navigation | [ADR-004](../docs/architecture/decisions/ADR-004-navigation-gorouter.md) |
| Theme and design tokens | [ADR-005](../docs/architecture/decisions/ADR-005-theme-system.md) |
| Networking | [ADR-007](../docs/architecture/decisions/ADR-007-network-configuration.md) |
| Secure storage | [ADR-008](../docs/architecture/decisions/ADR-008-secure-storage.md) |
| Local database | [ADR-009](../docs/architecture/decisions/ADR-009-local-database.md) |

## Status

Foundation. `lib/features/` is empty — no feature has been built. The application starts, resolves its environment, initialises Firebase and renders a placeholder screen.

Two known constraints affect this package and are tracked in [`volume-amendments.md`](../docs/architecture/volume-amendments.md): the Android build depends on a Gradle shim for `isar_flutter_libs`, which predates AGP 8 (**A-029**), and 16 KB page size support for those prebuilt native libraries is unverified.
