# ADR-001 — Adopt Clean Architecture

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none

## Context

Vump Technologies is a long-lived platform expected to grow across recording, backend integration and AI features. Without an enforced separation between UI, orchestration, business rules and I/O, a Flutter codebase converges on widgets that call HTTP clients directly and business rules that cannot be tested without a render tree.

The decision was needed before the first feature was written, because layering is prohibitively expensive to retrofit — every call site has to move.

## Decision

The application follows Clean Architecture. Every feature is divided into four layers:

```
feature/
├── data/           # DTOs, data sources, repository implementations
├── domain/         # Entities, repository interfaces, business rules
├── application/    # Use cases and orchestration
└── presentation/   # Widgets, screens, view state
```

Dependencies point inward. `presentation` and `data` may depend on `domain`; `domain` depends on nothing outside itself. `data` implements the interfaces that `domain` declares, so the direction of the dependency is the opposite of the direction of control.

## Alternatives Considered

- **Layer-first structure** (`lib/screens/`, `lib/models/`, `lib/services/`) — rejected. It groups unrelated features together and requires touching four distant directories to change one feature.
- **MVVM without a domain layer** — rejected. It keeps business rules in view models, which couples them to the presentation framework and makes them hard to test in isolation.
- **No prescribed architecture** — rejected. Consistency across a multi-volume platform cannot be left to per-feature judgement.

## Consequences

- Business rules are testable without Flutter, because `domain` has no framework dependency.
- Features can be developed and reviewed independently, since each owns its full vertical slice.
- Small features cost more files than they would in a flatter structure. This is accepted deliberately: the overhead is constant while the benefit scales.
- Crossing a layer boundary requires a mapping step (DTO to entity), which is additional code that must be maintained.
- Any violation of the inward dependency rule is a defect, not a style preference.

## Related Missions

- Mission 0.6.2 — Application Bootstrap, which established `lib/` and scaffolded the four layer directories under `lib/features/`.

## Implementation Status

`lib/features/` is empty. No feature has yet been built, so the layering is binding but not exercised. The first feature mission will be the first real test of this decision.

**Correction (Mission 0.18.1).** `lib/features/` previously contained four directories named `data/`, `domain/`, `application/` and `presentation/` — scaffolded in Mission 0.6.2 and described here as compliance. They were not. Four layer directories at the root of `features/` is the **layer-first structure this ADR explicitly rejects**; the layers belong *inside* each feature:

```
features/
└── recording/          <- the feature owns the layers
    ├── data/
    ├── domain/
    ├── application/
    └── presentation/
```

The directories were empty and have been removed. The distinction matters because the first feature built against the old scaffold would have inherited exactly the structure the Alternatives section rejects.
