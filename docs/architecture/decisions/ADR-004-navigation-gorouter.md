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

**Correction (Mission 1.3, 2026-08-13).** The paragraph above is out of date in three of its four claims. `appRouter` now declares **18 routes**, implementing Volume 2 Chapter 2.4's navigation model:

```text
/                            HomeScreen — Mission 0.6's placeholder, retained
/login                       shared, role-agnostic (Chapter 2.4 §4)
/collector/…                 StatefulShellRoute.indexedStack, 5 branches
/admin/…                     StatefulShellRoute.indexedStack, 4 branches
/checklist/:taskId           full-screen gate toward capture
/recording/:sessionId        chrome-free; outside both shells
/processing/:sessionId
```

Claim by claim:

- **"one route"** — now 18.
- **"No nested routes"** — now false. Two `StatefulShellRoute.indexedStack` shells carry nine `StatefulShellBranch`es between them, five for the Collector root and four for the Admin root, and branches nest routes further: `/collector/projects/:projectId/tasks/:taskId` is three levels deep.
- **"or route parameters"** — now false. Three are in use: `projectId`, `sessionId`, `taskId`.
- **"redirects"** — ~~still accurate. There are none.~~ **Out of date as of Mission 2.7 (2026-08-13).** The guard this ADR named route-level redirects as the home for is built and is decided by **ADR-037**: one top-level `redirect` delegating to a pure `AuthGuard` function, refreshed by a `refreshListenable` fed from `authNotifierProvider`. It implements Chapter 2.4 §4's Role Router and Volume 6 Chapter 6.7 §3's Login fallback together. `/collector` and `/admin` are no longer directly reachable; `appRouter` is now `routerProvider`, because a redirect that reads Riverpod state needs a `Ref`. The route table is still declared in one place, so this ADR's decision is unchanged — only its "there are none" is.

Two Consequences of this ADR became live rather than hypothetical and are recorded here as unresolved, not as decided:

- **Typed route arguments.** Every parameter is read as a raw `String` from `GoRouterState.pathParameters`. The choice between manual parsing and GoRouter's typed-routes generator is still open, and the first parameterised routes now exist.
- **Route-level access control.** Beyond the Role Router, Volume 2 Chapter 2.3 §5 requires the Recording Screen to be reachable *only* through the Pre-Recording Checklist (BR-04). As a top-level route it is directly reachable, so that rule is currently unenforced. A redirect is the mechanism for both.

  **Partially discharged, Mission 2.7 (2026-08-13).** ADR-037 built the authentication and role half; `/recording/:sessionId` is now unreachable without a session but is still reachable without passing the checklist. BR-04 needs per-route state the guard does not have, and remains open.

Nothing in the Decision, Context, Alternatives or Consequences sections changed: routes are still declared in one place, the root widget still uses `MaterialApp.router`, navigation is still by path, and no screen constructs a `MaterialPageRoute`.
