# ADR-035 — Authenticated Requests and Token Refresh

- **Status:** Accepted
- **Date:** 2026-08-13
- **Supersedes:** none. Discharges the ADR that `AuthInterceptor` and error-handling.md §16 both defer to by name.

## Context

`AuthInterceptor` has been installed in `DioClient`'s chain since Mission 0.10 and has never attached anything. Its own doc comment says why: three decisions were open, and *"those require their own ADR. Until it is taken, this class stays inert."* error-handling.md §16 cites the same passage and records that **no retry logic exists anywhere in the repository**.

Mission 2.2 removed the reason for the deferral. `AuthRepository` now produces a real Firebase session, so there is a token to attach and a refresh to perform.

**The blocking problem is layering, and it is real rather than procedural.** `AuthInterceptor` lives in `core/network/`. The token comes from `features/auth/`. ADR-022 forbids `core/` importing `features/` — not as a style rule but by definition: `core/` is *"defined by having every feature as a potential consumer"*, so a `core/` module that imports one feature stops being `core/` and makes that feature un-replaceable.

Three further questions follow from it, and each had more than one defensible answer:

**Where refresh failure goes.** A failed refresh means the session is over, which is a navigation outcome. An interceptor must not reach into routing, and it must not call `AuthRepository` either — that is the same import ADR-022 forbids, wearing a different hat.

**What type reaches the caller.** Dio can only propagate a `DioException`, and `DioClient._guard` unwraps a `NetworkException` specifically. An auth failure raised inside the chain has to arrive as something the existing unwrap understands.

**What happens when Firebase is not initialised.** ADR-017 makes a Firebase startup failure survivable in development, and ADR-010 warned that *"when the first Firebase-dependent feature lands, starting without Firebase stops being degraded operation and becomes silent breakage."* A request needing a token in that state must fail legibly.

That last one was traced rather than assumed, and **the trace found a defect in Mission 2.2**. With no initialised app, `FirebaseAuth.instance` calls `Firebase.app()`, which throws `FirebaseException(plugin: 'core', code: 'no-app')`. `AuthRepositoryImpl` resolved `fb.FirebaseAuth.instance` in its **constructor initializer list** — outside `_guard` — so constructing the repository threw a raw `FirebaseException`. That is precisely the guarantee ADR-034 claims to make and did not.

## Decision

### `core/network/` declares what it needs; `features/auth/` satisfies it

`AuthTokenSource` is an `abstract interface class` in `core/network/interfaces/`, owned by the layer that *consumes* it:

```dart
abstract interface class AuthTokenSource {
  Future<String?> currentToken();
  Future<String?> refreshToken();
}
```

**This is ADR-001's dependency inversion applied sideways.** ADR-001 has `domain/` declare the repository interface that `data/` implements, so the dependency points inward against the direction of control. The same move works between `core/` and a feature: `core/network/` states its requirement as a type it owns, `features/auth/data/` implements it, and the composition root introduces them. No import crosses from `core/` to `features/`, and `features/auth/` remains replaceable because `core/network/` never learns its name.

`core/storage/interfaces/secure_storage_repository.dart` is the existing precedent for both the shape and the location.

**Two return values, two meanings, and the distinction is load-bearing:**

- **`null` — nobody is signed in.** The request proceeds with no `Authorization` header and the server decides. The interceptor does not invent an authorization policy the backend already owns (Volume 4 Chapter 4.8 §1: the API is *"the sole arbiter"*).
- **A throw — the token could not be determined.** Firebase is down, or the platform never initialised. The request fails; sending it unauthenticated would turn a local fault into a confusing 401.

Implementations throw `AuthenticationException`, per error-handling.md §26's rule for `features/*/data/`.

### The token source is provided by override, not by default

`authTokenSourceProvider` is declared in `core/network/providers/` and throws until overridden — the idiom `databaseDirectoryProvider` already uses, and for the same reason: failing at the override point is easier to diagnose than the alternative. Here the alternative is worse than a misplaced file. A provider defaulting to "no token" would send every request unauthenticated, and the symptom would be a server 401 that looks like an expired session rather than unwired configuration.

Nothing reads `dioClientProvider` today, so making it require an override costs no existing call site.

### A 401 triggers one refresh and one retry

Volume 4 Chapter 4.7 §3 specifies this behaviour directly, for this component: *"if a token expires while a background upload is in flight, the upload's Dio auth interceptor requests a fresh token and retries the request rather than failing the chunk outright — consistent with Chapter 2.9's rule that a transient condition should self-recover, not surface as a Collector-facing error."*

error-handling.md §16 fixes the bounds: `AUTH_SESSION_EXPIRED` and `AUTH_TOKEN_REFRESH_FAILED` are *"retryable **once**, after a refresh — never in a loop"*.

The retry is marked in `RequestOptions.extra`. A retried request that 401s again is passed through untouched, so a server that rejects every token cannot produce an infinite loop.

### Concurrent 401s share one refresh, held as an in-flight future

error-handling.md §16 requires *"a single refresh in flight. Concurrent 401s must wait on one refresh, not trigger one each."*

The mechanism is the one this codebase already uses three times — `FirebaseInitializer`, `DatabaseService.open` and `AuthRepositoryImpl._googleInitialization` all hold the in-flight `Future` rather than a completion flag, so concurrent callers await the first attempt instead of racing. Five simultaneous 401s produce one refresh and five retries.

### A failed refresh fails the request and nothing else

The interceptor rejects with `AUTH_TOKEN_REFRESH_FAILED` and takes no further action. **Sign-out is driven by the session stream, which already exists.**

Firebase signs the user out when the refresh token is revoked or expired, so `AuthRepository.sessionChanges` emits `Session.unauthenticated()` and Volume 6 Chapter 6.4's route guard redirects to `SH-02`. The interceptor needs no interface method, no callback and no stream to make that happen — it is already happening, driven by the same event that caused the refresh to fail.

This keeps `AuthInterceptor` a pure request decorator. It cannot end a session, which means it cannot end one by accident.

### Auth failures travel as a `NetworkException` carrying an `AUTH_*` code

`ErrorInterceptor` already does exactly this: it maps a 401 to `ErrorCode.authUnauthenticated` on a `NetworkException`, and error-handling.md §8 records the reasoning — *"401 and 403 map to `AUTH_*`, not `NETWORK_*`, deliberately. The transport succeeded; the request was refused for an identity reason."*

`AuthInterceptor` follows the file's own precedent. `DioClient`'s documented contract — *"every method throws a `NetworkException`"* — is unchanged, and `_guard`'s existing unwrap needs no edit.

The `ErrorCode` is what carries the meaning, which is the design error-handling.md §19 rests on. A caller switches on `AUTH_UNAUTHENTICATED` or `AUTH_TOKEN_REFRESH_FAILED`; the exception class tells it which layer converted, not what happened.

### Firebase resolution is lazy everywhere, and Mission 2.2's eager resolution is corrected

`FirebaseAuthTokenSource` resolves `FirebaseAuth.instance` inside its guarded methods, never in its constructor, so an uninitialised platform surfaces as `AuthenticationException` at the point of use.

`AuthRepositoryImpl` is corrected the same way: the injected instance is stored and `FirebaseAuth.instance` resolved through a private getter, so every resolution happens inside `_guard`. `_guard` gains an `on FirebaseException` clause ahead of its catch-all, so `core/no-app` and `not-initialized` produce a message naming the real cause instead of an unclassified failure.

## Alternatives Considered

- **Import `AuthRepository` into `AuthInterceptor` behind a "it's only an interface" argument.** Rejected, and it is the tempting one because `domain/` interfaces feel dependency-free. They are not: the import still names `features/auth/`, still makes `core/network/` unbuildable without it, and still fails the CI boundary check. The direction of the abstraction is what matters, not whether the imported symbol is abstract.

- **Put `AuthTokenSource` in `features/auth/domain/`.** Rejected for the same reason. An interface helps only when the consumer owns it; owned by the feature, `core/network/` would still have to import `features/auth/` to name the type.

- **Use Dio's `QueuedInterceptor` to hold concurrent requests during a refresh.** Rejected, though it is the framework's own answer. It serialises *every* request through the interceptor, not just those waiting on a refresh, which pays a throughput cost on every call to solve a problem that occurs at token expiry. The in-flight future satisfies §16's requirement without changing the concurrency of the normal path.

- **Add `invalidateSession()` to `AuthTokenSource`.** Rejected. It puts a session-lifecycle trigger behind an interface named for tokens, and gives the interceptor the ability to sign a user out — a power it should not have, since a bug in retry logic then logs people out rather than failing one request.

- **Expose a `sessionLost` stream from `core/network/` for the composition root to subscribe to.** Rejected as machinery for an event that already has a publisher. `sessionChanges` is the session's stream; a second one would be a third place session lifecycle is expressed, and the two could disagree.

- **Widen `DioClient` to throw any `AppException` so an `AuthenticationException` could pass through.** Rejected. It changes a documented guarantee every caller reads, and callers written as `on NetworkException` would silently stop catching auth failures. The `AUTH_*` code on a `NetworkException` conveys the same thing with a precedent already in the file.

- **Fail the request when `currentToken()` returns null.** Rejected. Not being signed in is not a transport failure, and the backend re-derives authorization on every request regardless (Volume 4 Chapter 4.8 §1). Refusing locally would duplicate a decision the server owns and make an unauthenticated endpoint impossible to call.

- **Retry more than once, with backoff.** Rejected here and left to the retry ADR error-handling.md §16 still owes. A 401 that survives a fresh token is not transient, and backoff belongs with the upload queue's durable attempt counter, not in an interceptor holding state in memory.

## Consequences

- **`AuthInterceptor` is no longer inert**, and the four open questions in its doc comment are closed. error-handling.md §16's statement that no retry logic exists is now false in one narrow place and should be amended when that section is next revised.

- **`dioClientProvider` now requires an override and throws without one.** This is deliberate and currently unexercised: nothing reads it. **The composition-root override is not wired**, because `main.dart` is outside this mission's scope. Until it is, any first consumer of `DioClient` fails immediately with a message naming the override — which is the intended failure, not a regression.

- **The layering precedent generalises.** Any future `core/` module needing something a feature owns declares an interface in its own `interfaces/` directory and is wired at the composition root. `AuthTokenSource` is the first instance; `recording` and `upload` will need the same move.

- **A development machine without Firebase now fails requests rather than crashing**, and the failure names Firebase rather than the request. It also means the route guard will redirect to a login screen where sign-in also fails — degraded, legible, and preferable to an unrelated `FirebaseException` from a constructor.

- **ADR-034's confinement claim is true again.** The eager `FirebaseAuth.instance` was a hole in it, found by tracing the ADR-017 path rather than by reading the code.

- **The retry path's test needs a fake `AuthTokenSource` and a mock HTTP adapter**, both of which are now cheap: the interface is two methods, and Dio ships `DioAdapter`-style substitution via `HttpClientAdapter`. No Firebase project is involved.

## Related Missions

- Mission 0.10 — Error Architecture, which installed the inert `AuthInterceptor` and fixed its position in the chain.
- Mission 0.17.17 — ADR-017, whose development-mode tolerance made the uninitialised-Firebase path reachable.
- Mission 2.2 — ADR-034, which produced the session this interceptor attaches, and the eager-resolution defect this ADR corrects.
- Mission 2.3 — Real `AuthInterceptor`, which produced this ADR.

## Implementation Status

**Implemented.**

| Verified | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 61 passed — 21 added by this mission |
| Package confinement | 6 of 6 pass |
| `core/` files importing `features/` | **0** |
| Generated code drift | none |
| Uninitialised-Firebase path | Traced to `FirebaseException(core/no-app)`, converted, and covered by 8 tests |

**Two defects were found by doing rather than reasoning, and both are fixed.**

**The uninitialised-Firebase question was expected to be a documentation note.** Following it through `FirebaseAuth.instance` → `Firebase.app()` → `noAppExists` showed a raw `FirebaseException` escaping `AuthRepositoryImpl`'s constructor — which no amount of reading the interceptor would have found. The tests reproduce it for free: a Flutter test host has no initialised Firebase, so `test/features/auth/data/firebase_auth_token_source_test.dart` runs in exactly the state under test without a fake.

**The replay initially re-sent the stale token, and a test caught it.** `client.fetch` re-enters the full chain, so `onRequest` ran again and overwrote the freshly refreshed credential with whatever `currentToken()` returned — which, on a source that caches, is the token the server had just rejected. Against Firebase it would have worked by accident, because the SDK's cache updates after a forced refresh; against any other implementation it would have retried with the rejected credential and failed. `_attach` now returns early when the retry flag is set.

**One test asserts a message rather than an `ErrorCode`**, against testing-standards.md §11's rule. It is deliberate and marked as such at the site: the requirement for the development-mode path is that the failure *says Firebase*, so legibility is the behaviour under test. It matches two substrings rather than a sentence, so a reword does not break it.
