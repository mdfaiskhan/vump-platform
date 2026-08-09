# ADR-004 — GoRouter for Navigation

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none

## Context

The platform requires deep linking, a web target where the URL bar must reflect application state, and eventually route-level access control. Flutter's imperative `Navigator.push` API supports none of these without substantial custom work, and it distributes routing knowledge across every call site that pushes a route.

A declarative router was required before the second screen existed, because converting imperative navigation after the fact means auditing every push and pop in the codebase.

## Decision

GoRouter is the sole navigation mechanism.

- Routes are declared in one place: `lib/app/router.dart`, exposing a single `appRouter`.
- The root widget uses `MaterialApp.router` with `routerConfig: appRouter`.
- Navigation is performed by path, using `context.go` and `context.push`, not by constructing widgets.

No screen constructs a `MaterialPageRoute` directly.

## Alternatives Considered

- **Imperative `Navigator` 1.0** — rejected. No URL synchronisation, no declarative deep link handling, and routing logic scattered across call sites.
- **Navigator 2.0 directly** — rejected. It is the correct primitive but its raw API is verbose enough that every team writing against it builds a wrapper. GoRouter is that wrapper, maintained by the Flutter team.
- **AutoRoute** — rejected. Capable, but depends on code generation for routes, adding a build step to every route change. GoRouter reaches the same place declaratively.

## Consequences

- Every route is visible in one file, so the navigable surface of the application can be read at a glance.
- Deep links and web URLs work as a property of the design rather than as a feature to be added.
- Route-level redirects — the natural place for authentication guards — have a defined home when that requirement arrives.
- Typed route arguments require either manual parsing or GoRouter's typed-routes generator. This is unresolved and will need a decision when the first parameterised route is built.
- The application is coupled to GoRouter's API. Version 14 is pinned; version 17 is available and migrating is a future decision.

## Related Missions

- Mission 0.6.1 — Dependency Management, which added `go_router: ^14.6.2`.
- Mission 0.6.2 — Application Bootstrap, which created `router.dart` and switched the root widget to `MaterialApp.router`.

## Implementation Status

`appRouter` declares one route: `/`, building `HomeScreen`. No nested routes, redirects or route parameters exist yet.
