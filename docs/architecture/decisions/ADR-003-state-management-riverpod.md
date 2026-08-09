# ADR-003 — Riverpod for State Management

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none

## Context

Clean Architecture (ADR-001) requires that the presentation layer depend on the application layer without constructing its own dependencies. That needs a mechanism for dependency injection and for exposing observable state to widgets.

Flutter provides `InheritedWidget` and `setState`, neither of which scales to a platform with cross-cutting state such as session, theme and connectivity. A choice was required before any stateful surface was built, because state management is the hardest dependency to replace once features are written against it.

## Decision

Riverpod is the sole state management and dependency injection mechanism, via `flutter_riverpod`.

- The entire widget tree is wrapped in a single `ProviderScope`, installed in `main.dart`.
- Widgets that read state extend `ConsumerWidget` or `ConsumerStatefulWidget`.
- Dependencies are exposed as providers rather than constructed at call sites or reached through service locators.

No second state management solution is introduced. `setState` remains acceptable for state that is genuinely local to one widget and never observed elsewhere.

## Alternatives Considered

- **Provider** — rejected. Resolution is tied to the widget tree via `BuildContext`, which makes providers awkward to read outside a build method and defers dependency errors to runtime.
- **BLoC** — rejected. Well suited to complex event streams, but imposes event and state classes on every interaction, which is disproportionate for the majority of surfaces in this application.
- **GetX** — rejected. Bundles state, navigation and dependency injection into one opinionated framework, which conflicts with GoRouter (ADR-004) and with the layer boundaries of ADR-001.
- **A hand-rolled service locator** — rejected. No compile-time safety and no automatic disposal.

## Consequences

- Providers are declared at the top level and resolved without `BuildContext`, so the application layer is reachable from anywhere without the widget tree.
- Dependencies are overridable, which makes tests able to substitute fakes at the `ProviderScope` boundary.
- Riverpod's compile-time safety catches missing dependencies at build time rather than as a runtime `ProviderNotFoundException`.
- Every contributor must understand provider lifecycles and disposal. This is a real learning cost.
- The application is coupled to Riverpod's API surface. Version 2 is pinned; the migration to version 3 is a future decision requiring its own ADR.

## Related Missions

- Mission 0.6.1 — Dependency Management, which added `flutter_riverpod: ^2.6.1`.
- Mission 0.6.2 — Application Bootstrap, which installed `ProviderScope` at the root.
- Mission 0.7.1 — Theme Foundation, which added the first provider, `themeModeProvider`.

## Implementation Status

`ProviderScope` wraps the root widget in `main.dart`. One provider exists: `themeModeProvider`. `VumpApp` is a `ConsumerWidget` and reads it.
