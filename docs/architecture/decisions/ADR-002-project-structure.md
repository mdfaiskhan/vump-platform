# ADR-002 — Top-Level Project Structure

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none

## Context

ADR-001 defines how a single feature is organised internally, but not where features live, nor where code that belongs to no feature goes — the root widget, the router, the theme, application configuration.

Without an agreed home for these, application-wide concerns accumulate wherever they were first needed, and `main.dart` grows into a bootstrap, a theme definition and a route table at once.

## Decision

The `mobile/lib/` tree is divided into four top-level directories:

```
lib/
├── main.dart       # Entry point only: composition root, nothing else
├── app/            # Application-wide concerns
│   ├── app.dart        # Root widget
│   ├── router.dart     # Route configuration
│   ├── config/         # Application configuration
│   └── theme/          # Design language
├── core/           # Cross-cutting infrastructure shared by all features
├── features/       # Feature modules, each structured per ADR-001
└── shared/         # Reusable widgets and utilities with no feature owner
```

`main.dart` contains only the composition root. It wires the provider container to the root widget and calls `runApp`; it holds no widget definition, no theme and no routes.

`app/` owns what is true of the application as a whole. `features/` owns what is true of one capability. Nothing in `app/` may depend on a specific feature.

## Alternatives Considered

- **Everything under `features/`, with no `app/`** — rejected. The root widget, router and theme belong to no feature, and forcing them into one creates a false owner.
- **A single `common/` directory instead of `core/` and `shared/`** — rejected. Infrastructure (networking, storage, logging) and presentation helpers (widgets, formatters) have different dependency profiles and different reviewers.
- **Flat `lib/` with no grouping** — rejected. It does not survive the first dozen files.

## Consequences

- The location of any given file is predictable from what it does, without searching.
- `main.dart` stays small permanently — it has exactly one job.
- A new feature is added by creating one directory under `features/`, touching nothing else.
- The `core/` and `shared/` distinction requires judgement at the margin, and some files will be arguable. The cost of an occasional wrong call is low; the cost of merging them is not.
- `core/` and `shared/` are currently empty. They are declared so that the first file needing them has an unambiguous home.

## Related Missions

- Mission 0.6.2 — Application Bootstrap, which created the tree and reduced `main.dart` to a composition root.
- Mission 0.8 — App Configuration Foundation, which added `app/config/`.
