# ADR-006 — Centralised Application Configuration

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none

## Context

Application identity — name, organisation, version — and the environment a build targets are needed in diagnostics, about surfaces and eventually in behaviour that differs between development and production.

Left undeclared, these values are written inline where first needed. The application name ends up as a string literal in the root widget, the version drifts from `pubspec.yaml`, and environment differences are expressed as scattered `kDebugMode` checks.

## Decision

Configuration lives in `lib/app/config/` and nowhere else.

- **`app_info.dart`** — application identity. `AppInfo` owns the name, organisation, version and build. No other file may declare them.
- **`app_environment.dart`** — the `AppEnvironment` enum: `development`, `staging`, `production`. It carries environment identity only, holding no endpoints, keys or credentials. `defaultEnvironment` is `development`, because an undeclared build is a developer's machine and defaulting to production would aim an unverified build at live infrastructure.
- **`app_constants.dart`** — application-wide defaults for motion, shape and layout. It declares no literals; it binds names to the design tokens of ADR-005, and adds the composite `EdgeInsets` values that have no token equivalent.
- **`app_config.dart`** — the single entry point. It re-exports the other three, so one import yields the whole configuration surface, and declares the one value that is a choice rather than a constant: the active environment.

Configuration is compile-time constant. Nothing in `config/` performs I/O, reads a file, or holds mutable state.

## Alternatives Considered

- **A single configuration class** — rejected. Identity, environment and layout defaults change for unrelated reasons and at different times; one class hides that.
- **Restating durations and radii in `config/`** — rejected. It would give those values two definitions and violate the centralisation rule of ADR-005. Binding to the tokens keeps one definition.
- **`--dart-define` environment selection** — deferred, not rejected. Selecting an environment at build time requires deciding how the value is supplied and validated, which is an architectural change and needs its own ADR.
- **`package_info_plus` for version and build** — deferred. It removes the drift risk between `AppInfo` and `pubspec.yaml`, but adds a dependency and makes configuration asynchronous. Worth doing; not yet decided.

## Consequences

- Every configuration value has exactly one definition, so a change is a single edit.
- Consumers import one file rather than knowing how configuration is split.
- Configuration being `const` means it is available before `runApp` and carries no initialisation order risk.
- `AppInfo.version` and `AppInfo.build` duplicate `pubspec.yaml` and must be updated together. This is a known drift risk, accepted until the deferred `package_info_plus` decision is taken.
- `config/` depends on `theme/` for its token bindings. The direction is deliberate — configuration composes from tokens — but it means `config/` is not free of presentation concerns.
- Any application identity string outside `AppInfo` is a defect.

## Related Missions

- Mission 0.8 — App Configuration Foundation, which created the configuration layer.
- Mission 0.8.1 — Configuration Cleanup, which removed the duplicated application name from the theme layer and resolved the ambiguity between two files named `app_constants.dart`.

## Implementation Status

Fully implemented. `AppConfig.environment` is `development`. The root widget reads `AppInfo.appName` for its title. Environment selection at build time is not implemented.
