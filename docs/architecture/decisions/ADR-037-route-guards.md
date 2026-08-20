# ADR-037 — Route Guards

- **Status:** Accepted
- **Date:** 2026-08-13
- **Supersedes:** none. Discharges the guard ADR-004 deferred, and retires the `/` placeholder ADR-022 §2.2 made conditional.

## Context

ADR-004 named route-level redirects as *"the natural place for authentication guards"* and left the guard itself undecided, because there was no authentication to guard. Its Mission 1.3 correction restates the position: *"That guard remains undecided."*

Everything it was waiting for now exists. `AuthNotifier` carries a resolved `AuthState` before the first frame (Mission 2.5), and `SignupScreen` is functionally complete but deliberately unrouted (Mission 2.6) precisely so a guard could exist before it became reachable.

Three requirements converge on one mechanism. Volume 2 Chapter 2.4 §4 wants the Role Router to send a user to their role's root *"once, silently"*. Volume 6 Chapter 6.7 §3 wants a failed silent re-authentication to *"fall back to the Login screen"*. And `SignupScreen` needs to be reachable by someone with no session at all, which is the one hole a blanket "redirect everything to /login" would close by mistake.

**Two facts about GoRouter shape the answer.** `GoRouterRedirect` returns `FutureOr<String?>`, so an async redirect is possible — and blocks navigation while it resolves, which is the wrong place to wait on anything. And GoRouter evaluates `redirect` only when navigation occurs, so a session that changes while the user is standing still is invisible to it.

## Decision

### The guard is a pure function, in `app/`, not in the router

`AuthGuard.redirect({AuthState? auth, String location})` in `lib/app/auth_guard.dart` decides every case. It touches no `BuildContext`, no provider and no `GoRouter`.

**The reason is testability, and the difference is large.** Every rule — the auth fallback, the role guard, the public-route exemption, the loading case — is a table test with no widget tree, no pump and no navigation. What remains for the router is one line that passes it two arguments. A guard entangled with `GoRouterState` would have to be tested by driving a router, which is slower, flakier, and tests the framework as much as the rule.

It lives in `app/` rather than `features/auth/` because it is routing policy, and `app/router.dart` is its only consumer. It imports `features/auth/application/` for the state type — which `app/` may do, since ADR-022's restriction is on `core/`, and `router.dart` already imports feature presentation by the same ADR's router exception.

### The router becomes a provider

`appRouter` was a top-level `final`. A top-level object has no `Ref`, and `redirect` must read `authNotifierProvider`, so the router is now `routerProvider` and `VumpApp` reads it with `ref.watch`.

**ADR-004's "routes are declared in one place" is untouched.** This is still the only route table; only its ownership moved from the library to the container. The alternative — reaching a global `ProviderContainer` from a top-level object — was rejected below.

`redirect` uses `ref.read`, not `ref.watch`. It runs during navigation rather than during a build, and watching would rebuild the provider that owns the router it is running inside.

### `refreshListenable` is what makes a session change move anyone

Without it the guard fires only on navigation, and the two most important cases involve no navigation at all: signing in (the screen no longer navigates — see below) and a session ending underneath someone.

`_AuthRefresh` is a `ChangeNotifier` fed by `ref.listen(authNotifierProvider)`, because `Listenable` is the type `refreshListenable` takes. Riverpod disposes the subscription with the provider.

### The Role Router moves out of the login screen

Mission 2.4 performed it imperatively with `context.go` after a successful sign-in, and its own comment recorded why that was temporary: *"putting it there now would mean two places deciding where a signed-in user belongs."* That is now exactly the situation the guard would create, so the imperative navigation is deleted.

**Neither `LoginScreen` nor `SignupScreen` navigates.** Both change the session and stop; the guard does the rest. This is what makes sign-in, sign-up, session restore and session expiry all land correctly through one code path instead of four.

### `AsyncLoading` declines rather than redirects

A null `auth` means the session is still resolving. Redirecting then would send a signed-in user to `/login` for the moment it takes to find out — the flash `Session.unknown` was originated to prevent (Mission 2.2). `main.dart` resolves the session before `runApp`, so this is a guard against a rebuild rather than a state a user normally reaches.

### `/signup` is public and unlinked — the second half superseded

Public because a person creating an account has no session to be guarded by; there is no way to protect this route without making it unusable.

~~Unlinked because Volume 2 SH-02 specifies Login as email/password fields, an SSO entry point and error states, and Volume 10 Chapter 10.4 §4 records the absence of a Sign Up option as deliberate.~~

**Superseded by A-056 (2026-08-14).** The reasoning was right on its own terms, and those terms changed: Volume 10's framing exists for an App Store reviewer, and this build is shared as an APK among a known group rather than submitted for review. A-056 is the amendment this section said would be needed, and Login now links here. **The public-route half stands unchanged** — it was never about obscurity.

~~**The invite code is the gate, not the obscurity of the route.**~~ **Superseded by A-056 (2026-08-14):** the code is optional, so reaching `/signup` without one now creates a Collector in the default organisation. The route being public is unchanged and still correct — a person creating an account has no session to be guarded by.

### `/` is retired

It served Mission 0.6's `HomeScreen`, and ADR-022 §2.2 marked it as leaving *"when the first real screen exists"* — a condition now met several times over. `/` is a redirect-only route: the guard rewrites it to a role root or to `/login` before any builder runs.

`HomeScreen` and its widget test are deleted. That test was the suite's oldest and pumped the whole application, so its coverage of router and theme wiring is deliberately replaced rather than dropped: `router_guard_test.dart` builds the real router inside `MaterialApp.router` and asserts against the actual route table.

## Alternatives Considered

- **Keep `appRouter` a top-level `final` and read a global `ProviderContainer` from `redirect`.** Rejected. It works, and it makes the container a piece of global mutable state that tests must set up and tear down around each other. The provider costs one `ref.watch` in `VumpApp`.

- **An async `redirect` that awaits `authNotifierProvider.future`.** Rejected. `GoRouterRedirect` permits it, and every navigation would then wait on a future that is already resolved in the overwhelmingly common case. Mission 2.5 put session resolution before the first frame precisely so routing never has to wait.

- **Per-route `redirect` callbacks instead of one top-level guard.** Rejected. The rules are global — every route is protected except two — so per-route callbacks would repeat the same predicate 19 times and fail open on the twentieth, when someone adds a route and forgets. A route that needs its own rule can still add one; the checklist-before-recording rule ADR-004 §68 mentions is the likely first.

- **Put the guard in `features/auth/`.** Rejected. It decides *routing*, not authentication, and it needs to know about `/admin` and `/collector` — feature paths that `features/auth/` has no business knowing.

- **Redirect `expired` somewhere other than `/login`.** Rejected. There is nowhere else to go; the difference between expired and unauthenticated is what Login *says*, which Mission 2.5 already built.

- ~~**Link "Create account" from Login.** Rejected as not this decision's to make.~~ **Taken later, by A-056 (2026-08-14)** — the extension this entry said it would require. Left recorded rather than edited away: the rejection was correct when made, and what changed was the distribution model, not the argument.

- **Keep `HomeScreen` behind the guard.** Rejected. It leaves a screen reading "Mission 0.19.1 Complete" reachable in a shipped build, and leaves ADR-022 §2.2's retirement condition unmet with nothing tracking it.

## Consequences

- **Every route is protected by default.** A new route is guarded the moment it is added, and opting out means adding it to `AuthGuard.publicRoutes` — a visible, reviewable act rather than an omission.

- **The role guard is a navigation correction, not a security boundary**, and must not be mistaken for one. A Collector reaching `/admin` is sent home silently; the reason that is safe is that the backend re-derives authorization on every request (Volume 4 Chapter 4.8 §1). The guard stops confusion, not attackers.

  **Corrected 2026-08-21, Mission 7.8.** This sentence cited two mechanisms: the backend's re-derivation ~~and the Firestore rules check the admin claim (ADR-036)~~. **The second no longer exists** — Mission 7.6 superseded ADR-036, undeployed its Cloud Function and deleted `firestore.rules` along with the database's only collection (A-227).

  **The claim is unchanged and the argument still holds**, because the deleted half was never load-bearing for *this* one. The Firestore rules governed who could write `org_invite_codes`; they never gated `/admin`. What makes a Collector's arrival at `/admin` harmless is, and always was, that every Chapter 4.6 route calls `requireRole` and scopes by `caller.orgId` — and `Caller.role` comes from the `users` table rather than a token claim, which Mission 7.8 made true of the client too.

  Recorded rather than quietly edited: a consequence that names two supports and loses one should say so, because the next reader would otherwise have no way to tell whether the remaining support was ever enough on its own.

- **`app/` now imports `features/auth/application/`**, which is new — previously only `router.dart` imported feature *presentation*. ADR-022's rule constrains `core/`, not `app/`, and its router exception already establishes that `app/` may name features. Recorded because the import matrix's shape changed even though no rule did.

- **The oldest widget test is gone.** `router_guard_test.dart` covers more, but the deletion is real and worth stating: the suite no longer has a test whose purpose is simply "the app builds".

- **Sign-up is reachable for the first time since Mission 2.4.** The full path — invite code, account creation, redemption, claim refresh, routing — now runs end to end.

## Related Missions

- Mission 0.6 — the `HomeScreen` placeholder this retires.
- Mission 1.3 — ADR-004's correction, which restated the guard as undecided.
- Mission 2.4 — the imperative Role Router this replaces.
- Mission 2.5 — session resolution before the first frame, which is what lets the guard be synchronous.
- Mission 2.6 — ADR-036, whose sign-up flow this makes reachable. **ADR-036 is Superseded as of Mission 7.6**; the flow it describes is now `POST /v1/auth/redeem`.
- Mission 2.7 — Route guards, which produced this ADR.

## Implementation Status

**Implemented.**

| Verified | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | **136 passed** — 27 added, 1 retired with `HomeScreen` |
| Guard rules | 14 table tests, no widget tree |
| Router wiring | 13 widget tests against the real `routerProvider` |
| Signed out → protected route | redirects to `/login` |
| Collector → `/admin/*`, Admin → `/collector/*` | each sent to their own root |
| Sign-in, sign-up, restore, expiry | all land correctly through the guard alone |
| No redirect loops | asserted exhaustively over 4 states × 7 locations |

**`DioClient` is not involved, which was worth checking rather than assuming.** Auth state comes from `AuthNotifier`, and every apparent reference to `DioClient` or `authTokenSourceProvider` in the auth path is doc-comment prose. ADR-035's unwired `authTokenSourceProvider` override remains unwired and remains unrelated to routing.

**The loop check earned its place.** A redirect whose destination also redirects makes GoRouter throw, and the failure appears at runtime on a state combination nobody tried by hand. Asserting that every destination is a fixed point for the state that produced it covers all 28 combinations mechanically.
