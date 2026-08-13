# ADR-034 — Firebase Authentication Integration

- **Status:** Accepted
- **Date:** 2026-08-13
- **Supersedes:** none. Extends ADR-010 to the first Firebase *product*. Registers A-051, A-052 and A-053.

## Context

ADR-010 settled the Firebase **platform**: `firebase_core` is confined to `core/firebase/`, initialisation happens once outside the widget tree, and *"adding a product means adding a dependency and a provider for it — never editing initialisation code."* It deliberately declined to decide anything about products, on the ground that *"the right abstraction depends on what each product is used for, and inventing it before the first consumer would guess."*

Mission 2.2 is that first consumer. Mission 2.1 declared `AuthRepository` in `features/auth/domain/`; this decision records how it is implemented, and four questions ADR-010 left open now have to be answered.

**Where does a Firebase product package live?** ADR-010's confinement rule is about `firebase_core`. `firebase_auth` is a different package with a different consumer, and putting it in `core/firebase/` for symmetry would make `core/` hold feature code — which ADR-022 forbids by definition, since `core/` is *"defined by having every feature as a potential consumer"*.

**The mobile `User` cannot be built from what the volumes make available to it.** `User` requires `role` and `orgId`. Volume 4 Chapter 4.7 §2 sets `role` as a Firebase custom claim, readable from the signed token. It sources `org_id` from the backend's `users` table, reachable only through `POST /v1/auth/verify` (Chapter 4.6 §2) — and `backend/` is empty (ADR-015). Without a decision, the repository cannot construct its own return type.

**Mission 2.1's interface includes a sign-up flow the product does not have.** `signUpWithEmailPassword`, `signUpWithGoogle`, an `inviteCode` parameter and an `OrgInviteCode` entity have no requirement, no screen and no endpoint behind them. Volume 10 Chapter 10.4 §4 states the opposite outright: accounts are *"provisioned by the client organization, not public self-signup"*, and the login screen is not *"a consumer app missing a 'Sign Up' option, since there deliberately isn't one"*.

**Firebase's own auth stream has no "not yet known" state.** `authStateChanges()` emits `null` or a `User`. `Session` has three cases, and the third — `unknown` — exists precisely for the window before the first emission. Mapping the stream shape directly would collapse it.

## Decision

### A Firebase product is owned by the feature that consumes it, not by `core/`

`firebase_auth` and `google_sign_in` are confined to **`lib/features/auth/data/`**, with a line each in the `Architecture boundaries` CI job. Six package-confinement rules are now machine-checked where there were four.

**The platform and its products are confined differently, and that asymmetry is the decision.** `firebase_core` belongs in `core/firebase/` because every feature is a potential consumer of initialisation. `firebase_auth` has exactly one consumer and will only ever have one; putting it in `core/` would make `features/auth/` un-replaceable by moving its dependency somewhere every other feature can reach.

This is the first entry in the confinement register owned by a feature rather than by a `core/` module. It is what ADR-022 §2.3's mechanism was built to express, and it is the shape every future feature package should follow.

### The error boundary is a static mapper, and the code strings were read from the package

`FirebaseAuthErrorMapper` converts `FirebaseAuthException` to `AuthenticationException`. `AuthRepositoryImpl._guard` converts `GoogleSignInException` and everything else. No third-party auth error escapes `features/auth/data/` — the guarantee `DioClient` makes for `DioException`.

**The mapper is static so the mapping is testable without a live Firebase project**, which is the shape error-handling.md §8 established for `ErrorInterceptor.mapToNetworkException` and §28 requires ("a test per mapped code").

**Reading the package rather than recalling it changed the mapping.** `wrong-password` and `user-not-found` are deprecated: Firebase enables email enumeration protection by default for projects created since September 2023, and collapses both into `invalid-credential` so that a caller cannot learn whether an account exists. A mapping written from memory would have named the two dead codes and missed the live one. `INVALID_LOGIN_CREDENTIALS` — the emulator's spelling of the same condition — is mapped alongside it so behaviour does not differ between the emulator and a real project.

### `org_id` is carried as a Firebase custom claim

The repository builds `User` from the ID token's claims: `role` (already specified by Volume 4 Chapter 4.7 §2) and `org_id` (added here, registered as **A-052**).

**The property Chapter 4.7 §2 protects survives.** *"A client can never claim its own role"* holds because the claim is set at provisioning time and the token is signed by Firebase — not because the value is unavailable on the device. An `org_id` claim inherits both properties. The backend continues to re-derive role and scope from its own tables on every request (Chapter 4.8 §1), so no server-side check starts trusting the client.

**A missing or unrecognised claim throws rather than defaulting.** Defaulting a missing role to `collector` would grant an identity that provisioning never issued. `ErrorCode.authUnauthenticated` is the code, because an unprovisioned account is not signed in as far as this application is concerned.

### `Session.unknown()` is originated, not mapped

`sessionChanges` yields `Session.unknown()` before subscribing to `authStateChanges()`. Firebase has no such event, so it has to come from somewhere, and the alternative is a subscriber seeing `unauthenticated` before a restore has been attempted — which flashes the login screen at an already-signed-in Collector on every cold start.

### Sign-up is registered as a product change and left unimplemented

Self-service registration with organisation invite codes contradicts three volumes. It is recorded as **A-051**, a requirement change owned by the project owner, rather than treated as a defect in the volumes or quietly implemented.

**`_redeemInviteCode` throws an `UnimplementedError`, and the choice of throwable is deliberate.** An `AuthenticationException` would be caught by `application/` and rendered as "that code is not valid" — a false statement about a code nothing validated. An `Error` is outside the failure taxonomy, is not handled, and stops the program, which is the correct response to a path that was never built. A permissive stub would be worse than either: it would open registration to anyone who can type a string.

**Redemption is called before account creation**, so a rejected code leaves no orphaned Firebase account behind. Nothing in this codebase deletes one.

### Google Sign-In is the MVP SSO entry point

`google_sign_in ^7.2.0` is admitted for `SH-02`'s SSO entry point. `FR-AUTH-02` words that entry point as *"enterprise SSO (SAML/OAuth) when enabled for a client organization"*, which is a per-organisation IdP and a different mechanism; the narrowing is registered as **A-053**.

Two properties of `google_sign_in 7.x` are recorded because both are easy to get wrong: `initialize` must be called *"exactly once"* before any other method — held as an in-flight `Future`, the pattern ADR-009 and ADR-010 already use — and authentication now yields only an ID token, with access tokens moved to a separate authorization client. Firebase accepts the ID token alone.

## Alternatives Considered

- **Put `firebase_auth` in `core/firebase/` beside `firebase_core`.** Rejected. It reads as consistent and is the opposite: ADR-022 defines `core/` as what every feature could consume, and an auth product has exactly one consumer. It would move `features/auth/`'s dependency somewhere every other feature can reach, and the confinement check could no longer say anything useful.

- **Inject `DioClient` and call `POST /v1/auth/verify` for role and `org_id`.** This is what the volumes actually specify and it remains the more correct answer once a backend exists. Rejected for this mission on scope: it puts a network round trip, a response DTO and a second error-conversion boundary into a mission scoped to the Firebase boundary, and `backend/` is empty, so none of it could be exercised. A-052 records that it should be revisited when the backend lands.

- **Default a missing `role` claim to `collector`.** Rejected. It converts an unprovisioned account into a working one, and the failure would be invisible — the user gets in, with an identity nobody granted.

- **Have `_redeemInviteCode` return normally until a backend exists.** Rejected, and this was the tempting wrong answer: it makes the flow demonstrable and the tests pass. It also means any string is a valid invite code, which is not a partial implementation of the feature but the removal of it.

- **Throw `AuthenticationException(authInviteCodeInvalid)` from `_redeemInviteCode`.** Rejected. It is the honest-looking option and it lies: `application/` would render it as a rejected code, and the person holding a perfectly good code would be told it is bad.

- **Implement sign-up against the volumes and drop Mission 2.1's methods.** Rejected as not this decision's to take. The volumes are consistent that sign-up does not exist, but whether it should is a product question, and A-051 puts it to the owner rather than resolving it by deleting an interface.

- **Map `wrong-password` and `user-not-found` only, as the mission brief suggested.** Rejected on evidence. Both are deprecated and are not emitted by a project created since September 2023. They are retained alongside `invalid-credential` for projects with email enumeration protection disabled, not as the primary mapping.

- **Collapse `Session.unknown()` into `unauthenticated`.** Rejected — it is the whole reason the union has three cases, and the cost is a login screen flashing at every launch for a signed-in user.

- **Add a `firebaseAuthProvider` in `features/auth/data/providers/`.** Not rejected, out of scope. ADR-010 requires a product provider to depend on `firebaseAppProvider` so initialisation ordering is a dependency rather than an assumption. Provider wiring is Mission 2.3, which this mission may not touch. Recorded below as an obligation, not an omission.

## Consequences

- **`features/auth/` is replaceable at the cost of one directory.** Nothing outside `features/auth/data/` can name a Firebase auth type, and CI enforces it.

- **Two of the seven `AuthRepository` methods are unreachable**, and will be until a redemption endpoint exists. This is visible at runtime as a crash rather than as a handled failure, deliberately. **The sign-up path must not be linked from any screen** — Mission 2.4 owns `presentation/` and inherits that constraint.

- **A second source of truth for `org_id` now exists.** The claim and the `users` row can disagree. Volume 4 Chapter 4.7 §2 already names the resolution for the same situation with `role` — the table is authoritative — so this extends an existing rule rather than inventing one, but it is a real cost and A-052 carries it.

- **ADR-010's provisional startup tolerance is now live.** ADR-010 recorded that *"when the first Firebase-dependent feature lands, starting without Firebase stops being degraded operation and becomes silent breakage… It must not be allowed to persist by inertia."* This is that feature. ADR-017 already makes the behaviour environment-driven — tolerant in development, fatal in staging and production — which discharges the obligation, but the development-mode tolerance now means a developer running without Firebase gets an auth repository that fails on every call rather than an app that is merely missing analytics.

- **Google Sign-In cannot be exercised end-to-end from code alone.** It needs the provider enabled in the Firebase Console, an Android SHA-1 fingerprint, and an iOS URL scheme. ADR-010 already records that `ios/Runner/GoogleService-Info.plist` was never generated, so iOS cannot authenticate at all today.

- **The boundary has no tests**, which error-handling.md §28 requires of every boundary and Volume 9 Chapter 9.5 §2 sets at 80 % for `data/`. `FirebaseAuthErrorMapper.mapCode` was made static specifically so its 19 mapped codes are testable with no Firebase project; `AuthRepositoryImpl` is harder, because `GoogleSignIn` has only a private constructor and cannot be faked — substitution has to go through `GoogleSignInPlatform.instance`. Recorded rather than glossed.

- **A conflict between two error rules is now on record.** `cause` holds the original `FirebaseAuthException`, which exposes `email` and `credential`. error-handling.md §7 requires `cause` at every boundary; `authentication_exception.dart` states the type *"carries no credential, token or identifier"*. `cause` is passed, and the consequence — that it must never be logged verbatim — is documented at the deviation. `AppLogger` has no redaction for it (ADR-027 declined defensive redaction), so nothing enforces this today.

- **`features/auth/data/analysis_options.yaml` closes half of A-025** for this feature. `public_member_api_docs` is now enforced in this layer, four missions after ADR-022 §6.1 step 7 required it. `domain/` still has no such file.

## Related Missions

- Mission 0.10 — Error Architecture, which defined `AuthenticationException` and the `AUTH_*` codes this boundary maps into.
- Mission 0.15 — Firebase Foundation (ADR-010), which established the platform this product resolves through.
- Mission 0.19.10 — Dependency Management Standards (ADR-030), whose admission checklist both new packages were taken through.
- Mission 2.1 — Auth domain layer, which declared the `AuthRepository` interface implemented here.
- Mission 2.2 — Firebase `AuthRepository` implementation, which produced this ADR and amendments A-051 to A-053.

## Implementation Status

**Implemented for sign-in, session and sign-out. Sign-up is blocked at A-051.**

| Verified | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 28 passed |
| `dart format` (CI file set) | 0 changed |
| Package confinement checks | **6 of 6 pass**, including the two added here |
| `firebase_auth` imports outside `features/auth/data/` | **0** |
| `google_sign_in` imports outside `features/auth/data/` | **0** |
| Firebase error codes mapped | **19 explicit, plus a catch-all**, all read from `firebase_auth 6.5.7` in the pub cache |
| `AuthRepository` members implemented | **5 of 7** — both sign-up methods blocked |
| Boundary tests | **0** — see Consequences |

**Two claims were corrected by checking rather than reasoning.** The mission brief proposed mapping `wrong-password` and `user-not-found` to `AUTH_INVALID_CREDENTIALS`; reading the package showed both are deprecated and that `invalid-credential` is what a current project emits. And the amendment numbers first written into the source were `A-049` and `A-050`, which are already taken by unrelated entries — the register was read rather than assumed, and they became A-051 to A-053.

**Two `ErrorCode` gaps were found and not closed**, because `core/errors/` is outside this mission's declared scope:

- **No auth-specific rate-limit code.** Firebase's `too-many-requests` is the first line of brute-force defence in Volume 8 Chapter 8.5 §2. It maps to `NETWORK_RATE_LIMITED`, which is semantically right and reads oddly on an `AuthenticationException`.
- **No configuration code.** `operation-not-allowed` means the provider is not enabled in the Firebase Console — a deployment fault, not a user failure. error-handling.md §13 describes configuration errors as a category; the enum has no case for one, so it degrades to `UNKNOWN`.
