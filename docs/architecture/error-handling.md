# Error Handling

The canonical error handling standard for the Vump Technologies repository.

Governed by **ADR-025**. Where this document and the ADR disagree, the ADR governs.

Every rule below was derived from `mobile/lib/core/errors/` and the four infrastructure modules that raise into it, not chosen from preference. Where the repository was already consistent, the existing practice is the rule. Where a rule is unimplemented, it says so.

**Nothing already governed is restated.** Cited, not duplicated:

| Already fixed by | What it fixes |
|---|---|
| Volume 0 Ch. 0.2 (Constitution) §3, §4 | Offline-first; never lose a take; idempotent resumable uploads; errors handled explicitly at every layer boundary, no silently swallowed exceptions |
| Volume 3 Ch. 3.9 §5, Volume 6 Ch. 6.9 | Error modelling and global handling — **partially superseded, see A-035, A-036, A-037** |
| ADR-001, ADR-022 | Layer boundaries and the import matrix that make the taxonomy enforceable |
| ADR-017 | Whether a Firebase initialisation failure aborts startup |
| ADR-007, ADR-016 | Credentials never in source; what may be logged |
| ADR-021 | `empty_catches`, `only_throw_errors`, `avoid_catching_errors`, `unawaited_futures`, `use_rethrow_when_possible` as **errors** |
| ADR-023 §2.5, §3 | `ErrorCode` value casing; the `Exception` suffix; the ban on a `*Failure` hierarchy |

---

## Philosophy

### 1. Purpose of error handling

Error handling exists so that a failure produces a **known, named outcome** instead of an unknown one.

The Constitution §4 states the requirement: *"Errors are handled explicitly at every layer boundary — no silently swallowed exceptions, especially around recording and upload."* §3 states what is at stake: *"Never lose a take. Once the Collector taps Stop, the raw footage must be safely written to local storage before any other operation is attempted."*

That fixes the standard's priority order, which is not the usual one. In an app that records irreplaceable field footage on a device hours from the nearest developer:

1. **Do not lose data.** A failure that discards a recording is the worst outcome available.
2. **Do not proceed on a false assumption.** A caller that believes an operation succeeded is worse than one that knows it failed.
3. **Do not leak diagnostics.** A logged token is a disclosed token (ADR-007).
4. **Tell the Collector something actionable.** A specific cause and fix, never "Something went wrong".
5. **Keep working where possible.** Offline-first means a network failure is an expected condition, not an error state.

### 2. Philosophy — two representations, one conversion point

The design is already in the code and its reasoning is in the doc comments of `app_exception.dart` and `failure.dart`. Stated as a rule:

**An error has exactly two representations, and they are asymmetric on purpose.**

| | `AppException` | `Failure` |
|---|---|---|
| Lives in | `core/errors/app_exception.dart` | `core/errors/failure.dart` |
| Raised by | Infrastructure, at the boundary where a third-party error arises | Nothing — it is *built*, never thrown |
| Crosses out of infrastructure | **Never** | **Only this** |
| Carries | `errorCode`, `message`, `cause`, `stackTrace` | `code`, optional `message` |
| Mechanism | `throw` | Returned, or held in an `AsyncValue` error slot |
| Shape | Abstract base, extended per infrastructure concern | A single `final class`, distinguished by `code` |

**The conversion is one-way and happens once**, at `Failure.fromException`. That factory is what guarantees `cause` and `stackTrace` cannot reach the application layer by accident. `failure.dart` calls it *"the single sanctioned conversion point"*, and that is the load-bearing claim of the whole design: the guarantee is structural, not a habit.

**Why `Failure` omits `cause` and `stackTrace`.** Not tidiness. A failure that carried them could leak a Dio error, an Isar handle or a filesystem path into a widget, and — worse — would tempt application code into branching on an implementation detail. Omitting them makes the wrong thing impossible rather than discouraged.

**Why `AppException` is abstract and not sealed.** Sealing would confine subclasses to one file, and the taxonomy is deliberately extended per infrastructure concern across `errors/exceptions/`. `FirebaseInitializationException` exists outside that directory precisely because the base is open.

**Why `Failure` is `final` with no subclasses.** One failure type, distinguished by its `code`. A hierarchy of failure subclasses would push infrastructure concerns back into the shape of the type — the thing the conversion exists to prevent. This is a deliberate divergence from Volume 3 §3.9 §5, registered as **A-035**, and the divergence has a real cost recorded there.

### 3. Expected behaviour

Volume 6 §6.9 §1 splits errors into two kinds with two different handlers, and the split governs everything below:

| Kind | Definition | Handling |
|---|---|---|
| **Expected, modelled** | A condition the code anticipated: no network, a rejected credential, a full disk, invalid input | Raised as an `AppException`, converted to a `Failure`, pattern-matched in presentation into specific copy. **Never reaches a global handler.** |
| **Unexpected, uncaught** | Anything no layer anticipated: a null the type system should have prevented, an undocumented platform exception | Caught by a global handler and reported. **Not currently implemented — see §25 and A-036.** |

**Per-operation expectations, from the Constitution §3:**

- **Recording** — a failure after Stop must not lose footage. Writing to local storage precedes every other operation.
- **Upload** — retrying must never produce a duplicate or corrupted chunk in S3. Idempotency is a property of the deterministic object key (ADR-011), not of the upload attempt.
- **Anything network** — failure is an expected state, queued for later, never a blocking error.
- **Startup** — a platform failure is fatal or tolerated according to the environment, never silently ignored (ADR-017).

---

## Error categories

### 4. The categories, and which type carries each

Five exception types exist. The mapping from category to type is deliberately many-to-few: the type is chosen by **who handles it**, not by where it came from.

| Category | Type | Codes | Raised by |
|---|---|---|---|
| **Network** | `NetworkException` | 9 `NETWORK_*` | `core/network/` |
| **Authentication** | `AuthenticationException` | 4 `AUTH_*` | the networking boundary, and the identity provider when adopted |
| **Authorization** | `AuthenticationException` | 2 `AUTH_*` | as above |
| **Storage** | `StorageException` | 7 `STORAGE_*` | `core/database/`, `core/storage/` |
| **Validation** | `ValidationException` | 5 `VALIDATION_*` | the application's own rules |
| **Configuration** | *none* | *none* | — **a gap, see §13** |
| **Platform startup** | `FirebaseInitializationException` | `UNKNOWN` | `core/firebase/` — **two known deviations, see §30** |

### 5. Domain errors

**A domain error is a business rule refusing an operation.** `domain/` has no I/O (ADR-022 §3.1), so it cannot produce a network, storage or platform failure — only a rule violation.

Domain errors are expressed as `ValidationException`, or returned as a `Failure` without ever being thrown. `domain/` may import `core/errors/failure.dart` and `core/errors/error_codes.dart` and nothing else from `core/` (ADR-022 §5.1) — those two files are pure Dart precisely so a domain rule can name a failure.

**A domain rule must not throw a bare `Exception` or a `String`.** `only_throw_errors` is an **error** under ADR-021, so this is enforced rather than advised.

**The test for whether a failure is a domain error:** would the backend also have to enforce it? If yes, it is a business rule and belongs in `domain/`. If it is about the shape of an input rather than its meaning, it is validation (§12).

### 6. Application errors

**The application layer produces no error type of its own, deliberately.** No `ApplicationException` exists and none should.

A use case orchestrates: it calls repositories through the interfaces `domain/` declares, applies rules, and returns a result. Every failure it encounters is already an `AppException` from below or a rule violation from `domain/`. A dedicated application exception would only ever wrap one of those, adding a layer of indirection and a second thing to catch.

**The use case is where an exception becomes a `Failure`.** It is the last layer that may catch an `AppException`, because it is the last layer inside the boundary. `presentation/` receives a `Failure` and never an exception.

**A use case must not let an exception escape.** An `AppException` reaching a widget defeats the whole taxonomy: the widget then holds a `cause` and a `stackTrace` it must not have.

### 7. Infrastructure errors

**Infrastructure owns the conversion.** `app_exception.dart` states the contract: *"a Dio error, an Isar exception, a platform channel failure and a Firebase error are each caught at the boundary where they arise and rethrown as a subclass of this type. No layer above infrastructure ever sees a third-party exception."*

This is enforceable because ADR-022 §2.3 confines each third-party package to one module, and the `Architecture boundaries` CI job checks it:

| Package | Owner | Converts to |
|---|---|---|
| `dio` | `core/network/` | `NetworkException` |
| `isar` | `core/database/` | `StorageException` |
| `flutter_secure_storage` | `core/storage/` | `StorageException` |
| `firebase_core` | `core/firebase/` | `FirebaseInitializationException` |

**The confinement is what makes the guarantee testable.** Nothing above `core/network/` imports Dio, so nothing above it *can* catch a `DioException` — the compiler enforces what the rule states.

**The `_guard` pattern is the established form**, used identically in `DioClient._guard` and `SecureStorageService._guard`:

```dart
Future<T> _guard<T>({
  required ErrorCode errorCode,
  required String description,
  required Future<T> Function() action,
}) async {
  try {
    return await action();
  } on MissingPluginException catch (error, stackTrace) {
    throw StorageException(
      errorCode: ErrorCode.storageUnavailable,
      message: 'Secure storage is unavailable on this platform; '
          'could not $description.',
      cause: error,
      stackTrace: stackTrace,
    );
  } on PlatformException catch (error, stackTrace) {
    throw StorageException(
      errorCode: errorCode,
      message: 'Secure storage failed to $description '
          '(platform code: ${error.code}).',
      cause: error,
      stackTrace: stackTrace,
    );
  } catch (error, stackTrace) {
    throw StorageException(
      errorCode: errorCode,
      message: 'Secure storage failed to $description.',
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
```

Four properties are required of every boundary, and all four are visible above:

1. **Specific `on` clauses first, a bare `catch` last.** The specific clauses produce a precise `ErrorCode`; the catch-all guarantees nothing escapes untranslated.
2. **`cause` and `stackTrace` always passed.** The stack trace is captured at the origin, not at the rethrow.
3. **The message names the operation** — `description` is passed in by the caller, so the log says what was being attempted.
4. **Every path throws an `AppException`.** No path returns null, and no path swallows.

**The catch-all is required, and it is why `avoid_catches_without_on_clauses` is excluded from the lint set** (ADR-021). A boundary that only caught the errors it had thought of would let the ones it had not through untranslated. `avoid_catching_errors` remains enabled, so catching an `Error` — a programming mistake, not a failure — is still forbidden.

**`rethrow` where the exception is already in the taxonomy.** `MigrationRunner` does exactly this: `on StorageException { rethrow; }` before its catch-all, so a migration failure is not double-wrapped. `use_rethrow_when_possible` is enabled — `throw error` would replace the original stack trace with the catch site.

### 8. Network errors

`NetworkException` carries one field beyond the base: **`statusCode`**, held because *"retry and refresh policies are written against it, and reconstructing it from an `ErrorCode` would be lossy"*. It is null for transport failures, where no response was ever received.

**The mapping is complete and lives in one place** — `ErrorInterceptor.mapToNetworkException`, exposed as a static so it is testable without a live client:

| Dio failure | `ErrorCode` |
|---|---|
| `connectionTimeout`, `sendTimeout`, `receiveTimeout`, `transformTimeout` | `NETWORK_TIMEOUT` |
| `cancel` | `NETWORK_CANCELLED` |
| `connectionError`, `badCertificate` | `NETWORK_UNAVAILABLE` |
| `unknown` wrapping a `SocketException` | `NETWORK_UNAVAILABLE` |
| `unknown` wrapping a `FormatException` | `NETWORK_SERIALIZATION` |
| `unknown`, otherwise | `UNKNOWN` |
| `badResponse` 401 | `AUTH_UNAUTHENTICATED` |
| `badResponse` 403 | `AUTH_FORBIDDEN` |
| `badResponse` 404 | `NETWORK_NOT_FOUND` |
| `badResponse` 409 | `NETWORK_CONFLICT` |
| `badResponse` 429 | `NETWORK_RATE_LIMITED` |
| `badResponse` ≥ 500 | `NETWORK_SERVER_ERROR` |
| `badResponse` ≥ 400 | `NETWORK_BAD_REQUEST` |

**401 and 403 map to `AUTH_*`, not `NETWORK_*`, deliberately.** The transport succeeded; the request was refused for an identity reason, and the caller that must respond is the one deciding whether to refresh a session or refuse an action.

**A `badCertificate` is `NETWORK_UNAVAILABLE`, not a distinct code.** It is a hard failure with no client-side remedy, and giving it a code would invite a retry.

**The two-step unwrap.** Dio can only propagate a `DioException`, so `ErrorInterceptor` puts the converted `NetworkException` in that envelope's `error` field and `DioClient._guard` unwraps it. That indirection is what makes the end-to-end guarantee hold: a caller of `DioClient` sees a `NetworkException` and never a `DioException`. If the interceptor chain never ran, `_guard` still produces a `NetworkException` with `ErrorCode.unknown` rather than letting the Dio error through.

### 9. Storage errors

**One type for every on-device store** — local database, secure storage and the file system. `storage_exception.dart` states the reason: *"the caller's response is the same in each case: the data is not available, and the `ErrorCode` says why."*

**The backend that failed is not identified in the type**, and this is the rule that matters: which store a repository uses is an implementation detail, and encoding it in the exception would leak that detail upward through the `catch` clause. A caller that could write `on IsarException` would be coupled to Isar — the coupling ADR-009's engine risk (A-029) makes concretely expensive.

Seven codes distinguish read, write, delete, not-found, corrupted, unavailable and permission-denied. `STORAGE_NOT_FOUND` is a normal outcome for a cache lookup, not necessarily an error — the caller decides.

### 10. Authentication errors

Four codes: `AUTH_UNAUTHENTICATED`, `AUTH_INVALID_CREDENTIALS`, `AUTH_SESSION_EXPIRED`, `AUTH_TOKEN_REFRESH_FAILED`.

**`AuthenticationException` carries no credential, token or identifier.** `authentication_exception.dart` gives the reason in one line: *"An exception is logged, and a secret in a log is a secret disclosed."* This is ADR-007's position applied to the error path, which is the path most likely to be verbose.

**Whichever identity provider is adopted, its native errors are mapped to this type at the boundary.** No layer above sees a provider-specific error class. `AuthInterceptor` attaches a bearer credential and refreshes it once on a 401, per ADR-035. It reaches the token through `AuthTokenSource`, an interface `core/network/` declares and `features/auth/data/` implements, so the conversion to this type still happens at the feature boundary — the interceptor never sees a Firebase error.

### 11. Authorization errors

**Authorization shares `AuthenticationException` with authentication, deliberately.** Two codes: `AUTH_FORBIDDEN` (authenticated but not permitted) and `AUTH_ACCOUNT_DISABLED`.

`authentication_exception.dart` states why: *"they share a type because they share a consumer — the layer that decides whether to prompt for sign-in, refresh a session, or refuse an action."*

**The codes are what distinguish them, and the distinction is behavioural.** `AUTH_UNAUTHENTICATED` means *sign in and retry* — the operation may succeed afterwards. `AUTH_FORBIDDEN` means *do not retry* — this identity will never be permitted, and prompting for a sign-in the Collector has already completed is the wrong response. Conflating the two produces a sign-in loop.

### 12. Validation errors

**`ValidationException` is the only type that does not originate at a third-party boundary.** It is raised by the application's own rules when input is rejected — whether that input came from a user, a stored record or a remote response.

It carries **`field`**, naming the offending input where one can be named, so a form can attach the message to the correct control rather than to the form as a whole. Null for rules spanning several values.

Five codes: invalid input, required field, out of range, invalid format, already exists.

**Validate at the edge the value enters**, and validate a remote response as rigorously as user input. A malformed payload that passes unvalidated becomes a corrupted local record — which surfaces later as `STORAGE_CORRUPTED`, far from its cause.

### 13. Configuration errors

**There is no configuration exception type and no configuration error code. This is a gap, recorded rather than filled** — adding a type or an enum case is code, outside this mission.

What exists instead, and why it has held so far:

- **Configuration cannot fail at runtime.** `AppConfig` resolves from `--dart-define=APP_ENV` and is const-evaluable (ADR-006). There is no parse step and no I/O, so there is nothing to throw.
- **An unrecognised `APP_ENV` does not throw.** It falls back to `development` and is *logged as a warning* by `_announceEnvironment` in `main.dart`, because ADR-007 requires a silent fallback to be visible. A silent fallback would ship a staging binary pointed at production.
- **A missing platform is handled by ADR-017**, not by a configuration error: `AppFeatureFlags.firebaseFailureIsFatal` decides whether startup aborts.

**What the gap costs.** `FirebaseInitializationException` uses `ErrorCode.unknown` because no code describes a platform service failing to start — its own doc comment says *"a `firebaseInitializationFailed` case belongs in the taxonomy"*. Any future configuration failure that genuinely can throw — a malformed remote config, a missing required asset — has no code to use either.

**The fix, when a mission owns it:** add a `CONFIG_*` group to `ErrorCode` covering at least a platform-initialisation failure, and give `FirebaseInitializationException` a code from it. See §30.

### 14. Third-party service failures

A third-party failure is converted at the module that owns the package (§7). Three rules govern the conversion:

- **Never let a third-party error type escape its module.** Enforced by the package-confinement rules and the `Architecture boundaries` CI job.
- **Preserve the original as `cause`.** The provider's own code is often the only way to diagnose the failure — `SecureStorageService` puts the `PlatformException.code` into the message, and `FirebaseInitializer` puts the `FirebaseException.code` into its message.
- **A third-party error is not automatically a failure of the operation.** `FirebaseInitializer` treats a `duplicate-app` error as success — the platform is already up, which happens on every hot restart — and adopts the existing app rather than failing. Recognising which provider errors are benign is part of writing the boundary.

### 15. Timeout handling

Three timeouts are configured, in `NetworkConstants`, and reach Dio through `NetworkConfig` (ADR-007):

| Timeout | Value | Covers |
|---|---|---|
| `connectTimeout` | 15 s | Establishing the connection |
| `receiveTimeout` | 30 s | Waiting for the response |
| `sendTimeout` | 30 s | Transmitting the request body |

All four Dio timeout types collapse to a single `NETWORK_TIMEOUT` code, with the specific type named in the message.

**`sendTimeout` matches `receiveTimeout` today, and chunk upload will need more.** `NetworkConstants` already records this: *"Uploads that need longer must raise it per request."* A 10-minute video chunk will not transmit in 30 seconds on a field connection, so the upload path must set a per-request `Options` rather than raise the global default — raising the global would make every ordinary request wait minutes before failing.

**A timeout is retryable; a `4xx` is not.** See §16.

**No operation outside the network layer has a timeout.** An Isar open, a keychain read and Firebase initialisation can all hang indefinitely. `FirebaseInitializer` deduplicates concurrent attempts and clears its in-flight future on failure so a later attempt is not handed the same failure forever — but nothing bounds how long the first attempt may take. Recorded in §30.

### 16. Retry policy

**One retry exists, and it is the narrow one.** ADR-035 discharged the ADR this section used to defer to, and `AuthInterceptor` now refreshes the credential once on a 401 and replays the request — the behaviour Volume 4 Chapter 4.7 §3 specifies for that component by name. It holds the in-flight refresh as a `Future`, so concurrent 401s share one refresh rather than triggering one each, and it marks the replayed request so a second 401 is never retried.

**No general retry mechanism exists.** Nothing implements backoff, a circuit breaker, a bounded attempt count or durable retry state. The upload queue is what needs those, and they remain unowned by any ADR.

**This section therefore defines the classification, and the mechanism only for the auth case.** What follows is derivable from the taxonomy and is the input the general retry ADR will need.

**Retryable — the condition may clear on its own:**

| Code | Why |
|---|---|
| `NETWORK_TIMEOUT` | Transient; the request may not have reached the server |
| `NETWORK_UNAVAILABLE` | Offline-first: expected, and clears when connectivity returns |
| `NETWORK_SERVER_ERROR` | A 5xx is the server's problem and is often momentary |
| `NETWORK_RATE_LIMITED` | Explicitly a "try later" — must honour `Retry-After` where present |
| `STORAGE_UNAVAILABLE` | The store may not be open yet |
| `AUTH_SESSION_EXPIRED`, `AUTH_TOKEN_REFRESH_FAILED` | Retryable **once**, after a refresh — never in a loop |

**Terminal — retrying cannot succeed and wastes battery:**

| Code | Why |
|---|---|
| `NETWORK_BAD_REQUEST`, `NETWORK_NOT_FOUND`, `NETWORK_CONFLICT` | The request is wrong; repeating it identically will fail identically |
| `NETWORK_SERIALIZATION` | A shape mismatch is a code defect |
| `AUTH_FORBIDDEN`, `AUTH_ACCOUNT_DISABLED`, `AUTH_INVALID_CREDENTIALS` | This identity will not be permitted |
| every `VALIDATION_*` | The input is invalid |
| `STORAGE_CORRUPTED`, `STORAGE_PERMISSION_DENIED` | Needs intervention, not repetition |
| `NETWORK_CANCELLED` | The caller asked for it to stop |

**Constraints any retry mechanism must satisfy**, all already fixed elsewhere:

- **Idempotency is a property of the key, not the attempt.** Constitution §3: *"Re-attempting an upload must never produce duplicate or corrupted chunks in S3."* ADR-011's deterministic object key is what delivers this — a retry writes to the same key.
- **Exponential backoff with jitter**, not a fixed interval. Fixed intervals synchronise a fleet of devices into a thundering herd against the same endpoint.
- **A bounded attempt count**, after which the chunk is marked failed and visible. Volume 5 §5.13 expects a final-attempt state, and Volume 6 §6.9 §3 expects that final attempt to be reported as a non-fatal so field patterns are visible.
- **Retry state must survive a process kill.** The Constitution requires the upload queue to survive a crash or force-close, so retry counters belong in the local database, not in memory.
- **A single refresh in flight.** Concurrent 401s must wait on one refresh, not trigger one each.

### 17. Exception hierarchy

```text
Exception  (dart:core, implemented not extended)
└── AppException                        abstract — errorCode, message, cause, stackTrace
    ├── NetworkException                + statusCode
    ├── AuthenticationException
    ├── StorageException
    ├── ValidationException             + field
    └── FirebaseInitializationException  (in core/firebase/ — see §30)
```

**`AppException implements Exception`** rather than extending it — `Exception` is an interface in Dart with no state to inherit.

**Adding a subclass is permitted and expected**; that is why the base is abstract rather than sealed. The bar: a new subclass is justified only when it carries a **field** the base cannot, or when its consumer differs from every existing type's. `NetworkException.statusCode` and `ValidationException.field` are the two cases that met it. A new subclass that adds no field and no distinct consumer should be an `ErrorCode` case on an existing type instead.

**There is no parallel `Failure` hierarchy, and there must not be** (§2, ADR-023 §3, A-035).

### 18. Error object structure

**`AppException`** — four fields, and each has a stated purpose:

| Field | Type | Purpose |
|---|---|---|
| `errorCode` | `ErrorCode` | The condition. What a caller branches on |
| `message` | `String` | Developer-facing. Written *for a reader of logs, not for a user*; may name internal details freely |
| `cause` | `Object?` | The originating third-party error. Diagnostics only; **must never be surfaced above infrastructure** |
| `stackTrace` | `StackTrace?` | Captured at the origin, so logging records the true point of failure rather than the point of rethrow |

**`Failure`** — two fields:

| Field | Type | Purpose |
|---|---|---|
| `code` | `ErrorCode` | The condition. The value application code branches on |
| `message` | `String?` | Optional. Absent where the code is self-describing |

`Failure` implements `==` and `hashCode` over both fields, so it is comparable in a test and usable as a value in state. `AppException` does not — an exception is an event, not a value, and two failures of the same kind are equal while two exceptions are distinct occurrences.

**`toString()` is for logs and is composed, not overridden away.** `AppException.toString()` emits `Type(CODE): message | cause: …`; subclasses append their own field — `NetworkException` appends `| status: 404`, `ValidationException` appends `| field: email`. A subclass that adds a field extends the base's output rather than replacing it.

### 19. Error codes

**28 codes in five groups**, in `core/errors/error_codes.dart`. The enum's own doc comment states the contract: *"the stable vocabulary that infrastructure maps into and that application code switches on — a layer must never branch on an exception's message string or on a third-party error type."*

| Group | Count | Prefix |
|---|---|---|
| Unclassified | 1 | `UNKNOWN` |
| Network | 9 | `NETWORK_` |
| Authentication and authorisation | 6 | `AUTH_` |
| Storage | 7 | `STORAGE_` |
| Validation | 5 | `VALIDATION_` |

**Naming is fixed by ADR-023 §2.5:** `camelCase` enum member, `SCREAMING_SNAKE_CASE` wire value in a `final String code` field. The wire value is never derived from the member name — deriving it would turn every rename into a silent protocol change.

**Adding a case is routine. Changing an existing `code` string is not**, because it breaks every log query and dashboard that references it. The enum says so, and it is the practical reason the two are kept separate.

**`UNKNOWN` is a measurement, not a category.** *"A frequent occurrence of this in logs indicates a gap in the taxonomy rather than a class of error."* Three sites currently produce it — an unclassifiable Dio failure, a `badResponse` with an unmapped status, and every `FirebaseInitializationException` (§13). The third is a known gap, not a genuine unknown.

**Never branch on a message string.** The message is developer-facing prose and may be reworded at any time; the code is the contract.

---

## Observability

### 20. Logging requirements

Five levels, in `LogLevel`, each with a fixed `label` written to output:

| Level | Use for | In the error path |
|---|---|---|
| `debug` | Diagnostic detail while developing | Suppressed outside development |
| `info` | A normal, expected event | Not used for failures |
| `warning` | Something unexpected that was recovered | A fallback taken — an unrecognised `APP_ENV` |
| `error` | An operation failed; the application continues | The default for a caught `AppException` |
| `fatal` | Unrecoverable; the application cannot continue meaningfully | A failure that aborts startup (ADR-017) |

**Verbosity narrows as the environment gets more real** — `AppLogger.minimumLevelFor(environment)`, and there is a test asserting exactly that.

**Log the exception, not a re-description of it.** `AppLogger`'s methods take `error` and `stackTrace` named arguments; pass the `AppException` itself. Its `toString()` already emits the code, the message, the cause and any subclass field.

**Log at the layer that decides**, once. The boundary that converts an error does not log it — the caller that decides what to do does. Logging at both produces two entries for one failure, and a reader cannot tell whether it happened twice. `main.dart` is the model: `_initializeFirebase` catches, decides fatal-or-not from the flag, and logs at the matching level.

**`print` is forbidden and is an analyzer error** (ADR-021). It bypasses `AppLogger`, escaping both the level filtering and the redaction below — *a printed token is a leaked token*.

**Redaction is not optional.** `LoggingInterceptor` replaces the value of seven headers with `[REDACTED]`, compared case-insensitively because a server may echo `authorization` in any casing:

```text
authorization        proxy-authorization    cookie
set-cookie           x-api-key              x-auth-token
x-refresh-token
```

Bodies are truncated to `maxLoggedBodyLength` (2000 characters) rather than omitted — the opening of a payload usually diagnoses a shape mismatch.

**The interceptor order is load-bearing and fixed** (ADR-007): `AuthInterceptor` → `LoggingInterceptor` → `ErrorInterceptor`. Auth runs first so anything it adds is subject to redaction; error conversion runs last so logging observes the raw failure with Dio's own classification intact. An interceptor added after logging would write its credential to the log.

### 21. User-facing error messages

**A user-facing message is resolved from the `code`, never taken from a `message` field.** `Failure.message` is *"a diagnostic aid rather than the primary channel"*, and `ErrorCode.code` is explicitly *"never rendered to a user"* — presenting an error is a localisation concern keyed by the code.

**"Something went wrong" is forbidden.** Volume 3 §3.9 §5 requires that every failure name a specific cause and fix, and Volume 6 §6.9 §1 requires presentation to map each case to the exact Volume 2 §2.9 copy — *"never a single generic 'Checklist failed' string."*

**A message the Collector sees must say what happened and what to do**, in that order. "No connection — your recording is saved and will upload automatically" is actionable; "Upload failed" is not, and in an offline-first app it is also misleading, because nothing has been lost.

**Never show a code, a stack trace, an exception type or a `cause` to a Collector.** The structural guarantee already prevents most of this: a widget receives a `Failure`, which has no `cause` and no `stackTrace` to show.

**The copy table is Volume 2 §2.9's, not this document's.** Where a code has no copy, that is a gap in the copy table, and the fallback must still be specific to the code — not a generic string.

### 22. Internal diagnostic information

Diagnostics live on `AppException` and stop at the conversion boundary. Three rules:

- **`message` is written for a log reader** and may name internal details freely — a URI, a platform error code, a schema version. It is discarded or replaced when a `Failure` is built.
- **`cause` is held for diagnostics only** and *"must never be surfaced above infrastructure"*. Its purpose is that the provider's own error is usually the only way to diagnose the failure.
- **No secret is ever a diagnostic.** No token, credential or key appears in a `message`, in a `field`, or in an exception type's fields. `AuthenticationException` carries none by construction, and the redaction list covers the transport path.

**Volume 6 §6.9 §4 extends this to crash reports:** they are scrubbed of anything Volume 8 would classify as sensitive — secure-storage contents and raw GPS or device fields beyond what is needed to reproduce the bug — *before* being sent. No crash reporter is currently wired up (§25, A-036), so this rule is stated ahead of the mechanism it constrains.

### 23. Stack trace policy

| Stage | Stack trace |
|---|---|
| Origin | **Captured.** `catch (error, stackTrace)` — always both, never just the error |
| Carried | On `AppException.stackTrace`, *"so the eventual logging infrastructure can record the true point of failure rather than the point of rethrow"* |
| Rethrown | **Preserved.** `rethrow`, never `throw error` — enforced by `use_rethrow_when_possible` |
| Converted to `Failure` | **Dropped.** Deliberately: `Failure` has no `stackTrace` field |
| Logged | **Yes**, via `AppLogger`'s `stackTrace` argument |
| Shown to a user | **Never** |

**Capture at the origin, not at the boundary.** A stack trace taken where an exception is rethrown points at the rethrow, which is the one location already obvious from the type. Every conversion site in the repository binds both values in its `catch` and passes both to the exception it constructs.

**An already-taxonomised exception is logged without a second trace, deliberately.** Where the caught exception is *already* an `AppException`, it carries its origin trace on its own `stackTrace` field, so binding and logging the catch-site trace would add a second, less useful trace to the same failure. Two sites do this and both are correct:

```dart
// database_service.dart — the migration failure is already in the taxonomy
} on StorageException catch (error) {          // stackTrace not bound
  _opening = null;
  logger.error('Database open failed.', error: error);
  rethrow;                                     // origin trace preserved
}
```

```dart
// main.dart — non-fatal branch; the exception carries its own trace
logger.error(
  'Starting without Firebase. Products that depend on it will fail.',
  error: error,
);
```

**The rule, stated precisely:** bind and pass `stackTrace` when **constructing** an `AppException` from a foreign error — that is the only moment the origin trace can be captured. When logging an exception that already has one, pass the exception and let its own trace travel with it.

**`LogFormatter` indents the trace beneath the message** rather than boxing or colouring it — chosen because boxes and colour codes are pleasant in a terminal and unreadable in a log aggregator, which is where these lines will actually be read.

---

## Behaviour and propagation

### 24. Recovery strategy

Recovery is chosen by the caller, from the code, and there are exactly four responses:

| Response | When | Example |
|---|---|---|
| **Retry** | A retryable code (§16), within an attempt budget | A timed-out chunk upload |
| **Fall back** | A degraded path exists and is honest about being degraded | Serving last-synced tasks while offline |
| **Refuse and explain** | Terminal, and the Collector can act | `VALIDATION_REQUIRED_FIELD` |
| **Abort** | Continuing would corrupt data or hide breakage | Firebase failing in production (ADR-017) |

**Aborting is a legitimate recovery strategy and the right one at startup.** ADR-017 chooses it deliberately: *"Starting without the platform the build was made against is silent breakage, not degraded operation."* The failure is logged at `fatal` and rethrown, so it surfaces as a crash with a cause rather than as an application that runs strangely.

**Never recover by discarding data.** The Constitution's *"never lose a take"* makes this absolute. If footage cannot be uploaded, it stays on the device and stays queued.

### 25. Fallback behaviour

**A fallback must be visible.** Two established examples, and both log:

- **An unrecognised `APP_ENV`** falls back to `development` and logs a `warning` naming the bad value and the fallback. ADR-007 requires this because a silent fallback ships a staging binary pointed at production.
- **Firebase failing in development** falls back to running without it and logs an `error` saying *"Products that depend on it will fail"* — not a warning, because the consequence is real.

**Offline is a fallback path, not an error path.** The Constitution §3 requires every core workflow to work with no network. A network failure during recording, chunking or queueing is an expected condition and must not surface as an error to the Collector.

**No global fallback handler exists.** Volume 6 §6.9 §2 requires `FlutterError.onError` for framework errors and `PlatformDispatcher.instance.onError` for errors outside the Flutter zone, both funnelling into one `ErrorReportingService` *"so there is exactly one place that decides what happens next, not two independent logging paths"*.

**Verified: neither handler is installed, and no `ErrorReportingService` exists.** An unexpected exception today is printed by the framework's default handler and reported nowhere. Registered as **A-036**. This is the largest implementation gap in the error path and it belongs to a mission of its own — installing the handlers is code, and choosing what they report depends on the crash reporter question in **A-037**.

### 26. Propagation rules

| Layer | May throw | May catch | Must not |
|---|---|---|---|
| `core/` (infrastructure) | `AppException` subclasses | Third-party errors, at the owning module | Let a third-party error escape the module |
| `features/*/data/` | `AppException` subclasses | Third-party errors from its data sources | Return null instead of throwing |
| `features/*/domain/` | `ValidationException` | Nothing — it performs no I/O | Import anything from `core/` but `failure.dart` and `error_codes.dart` |
| `features/*/application/` | Nothing outward | `AppException` — **the last layer that may** | Let an exception reach `presentation/` |
| `features/*/presentation/` | Nothing | `Failure`, by pattern-matching on `code` | Catch an `AppException`; branch on a message string |
| `main.dart` | Rethrows a fatal startup failure | `AppException` at startup | Swallow a failure the environment says is fatal |

**Three rules govern every crossing:**

1. **Convert once, at the innermost boundary that understands the error.** Converting later means an intermediate layer saw a type it should not have.
2. **Never double-wrap.** `rethrow` when the exception is already an `AppException` — `MigrationRunner`'s `on StorageException { rethrow; }` is the pattern.
3. **The exception-to-`Failure` conversion happens exactly once**, in `application/`, via `Failure.fromException`.

**Escalation is allowed; silent absorption is not.** A layer may convert, enrich or rethrow. It may never catch and continue as though nothing happened — `empty_catches` is an analyzer **error** (ADR-021).

### 27. Repository-wide conventions

Enforced mechanically by ADR-021, all as **errors**:

| Rule | Prevents |
|---|---|
| `empty_catches` | A failure that happened and that no layer above will ever know about |
| `only_throw_errors` | Throwing a value that `on AppException` cannot catch |
| `avoid_catching_errors` | Turning a programming mistake into a handled condition |
| `unawaited_futures`, `discarded_futures` | A failure that arrives out of order, or never |
| `use_rethrow_when_possible` | Replacing the origin stack trace with the catch site |
| `throw_in_finally`, `control_flow_in_finally` | Discarding the in-flight exception |
| `avoid_print` | Bypassing `AppLogger`, its level filter and its redaction |

**Deliberately not enforced:** `avoid_catches_without_on_clauses`, excluded by ADR-021 because the catch-all at an infrastructure boundary is required by §7 — the rule would force an `ignore` comment at every boundary and convert a design invariant into per-site suppression.

**Conventions enforced by review, not by a tool:** convert at the owning module; capture both `error` and `stackTrace`; pass `cause` and `stackTrace` through; log once, at the deciding layer; never branch on a message string.

---

## Maintenance

### 28. Testing expectations

**What exists.** `test/core/firebase/firebase_initializer_test.dart` is the model, and asserts six error-path properties: an uninitialised initialiser reports itself so; the `app` getter throws rather than returning null; `initialize` **converts the failure into the application taxonomy**; state is not corrupted by a failed attempt; concurrent callers share one attempt; and a failed attempt is retryable rather than cached forever.

That third assertion is the one every boundary needs.

**What every boundary must have:**

- **A test that the third-party error is converted.** Assert the type is the `AppException` subclass and the `ErrorCode` is right. This is the guarantee the whole design rests on, and it is the one thing a type system cannot check — nothing stops a boundary from forgetting a `catch`.
- **A test per mapped code.** `ErrorInterceptor.mapToNetworkException` is a static specifically so this is possible without a live client; 13 documented mappings (§8) means 13 cases, and there is currently no test file for it. Recorded in §30.
- **A test that the catch-all catches.** Throw something the `on` clauses do not name and assert an `AppException` still emerges.
- **A test that `cause` and `stackTrace` survive** the conversion, and that they are **absent** from the resulting `Failure`.
- **A test that state is not corrupted by failure**, and that a failed attempt is retryable rather than poisoned.

**Test the failure path, not only the happy path.** Volume 9 sets per-layer coverage targets (`domain` 90%+, `data` 80%+), measured by the `Test` CI job and not yet gated because `lib/features/` is empty.

**Assert on the code, never on the message.** A test asserting a message string breaks on a reword and passes on a wrong code — exactly inverted.

**`use_test_throws_matchers` is enabled** (ADR-021): use `expect(..., throwsA(isA<StorageException>()))`, not a `try`/`catch` with a manual `fail()`.

### 29. Documentation requirements

- **Every exception subclass documents what it covers and what it deliberately does not.** All five do. `StorageException` explaining why it does *not* name the failing backend is more useful than a list of its fields.
- **Every `ErrorCode` case carries a one-line doc comment** stating the condition. All 28 do.
- **A boundary documents its conversion contract.** `ErrorInterceptor` and `DioClient` both explain the two-step unwrap, which is the non-obvious part.
- **A deliberate deviation is documented at the deviation.** `FirebaseInitializationException` records both of its own (§30) in its doc comment — which is why they were findable by audit rather than lost.
- **`ErrorCode` values are documentation-visible identifiers.** They appear in logs and dashboards; changing one is a breaking change to something outside the codebase (§19).
- Doc-comment coverage is governed by Constitution §4 and is an open question — see amendment **A-034**.

### 30. Future maintenance and known deviations

**Maintenance rules.**

- **Adding an `ErrorCode` case is routine; changing an existing `code` string is a breaking change** to every log query and dashboard. Treat it as a protocol change.
- **A new exception subclass needs a field or a distinct consumer** (§17). Otherwise add a code to an existing type.
- **A new third-party package brings a conversion boundary with it.** Adding one without a boundary means its errors reach layers that cannot name them — and it needs a package-confinement entry in the `Architecture boundaries` CI job (ADR-022 §2.3).
- **When the retry ADR is written**, §16's classification is its input, and the Constitution's idempotency constraint is non-negotiable.
- **`UNKNOWN` frequency is a metric.** It measures gaps in the taxonomy. Reviewing it periodically is how the taxonomy stays honest.

**Known deviations.** Audited across `mobile/lib/`. Recorded rather than fixed — this is a documentation and governance mission.

| Deviation | Detail | Disposition |
|---|---|---|
| **`FirebaseInitializationException` is in the wrong directory** | Lives in `core/firebase/` while the other four subclasses are in `core/errors/exceptions/`. Its own doc comment records why — `core/errors/` was outside Mission 0.10's allowed paths — and says *"It should be moved for consistency when `core/errors/` is next in scope."* | **Move it.** A one-file move plus two import updates. Not done here: this mission changes no code. It is the smallest outstanding item in the error path |
| **`FirebaseInitializationException` uses `ErrorCode.unknown`** | No code describes a platform service failing to start. Its doc comment states the fix: *"a `firebaseInitializationFailed` case belongs in the taxonomy"* | Add a `CONFIG_*` or `PLATFORM_*` group to `ErrorCode` (§13) and give it a real code. Pair with the move above |
| **No configuration error category** | Neither a type nor a code (§13). It has held because configuration is const-evaluable and cannot fail at runtime | Filled by the same change as above |
| **No global error handlers** | `FlutterError.onError` and `PlatformDispatcher.instance.onError` are both absent, and no `ErrorReportingService` exists. Volume 6 §6.9 §2 requires all three | **A-036.** The largest gap in the error path. Depends on A-037's crash-reporter question |
| **No crash reporting** | `firebase_crashlytics` is not a dependency. Volume 6 §6.9 §3 selects Firebase Crashlytics in a decision it numbers "ADR-010" — which collides with *this* repository's ADR-010 | **A-037**, covering both the missing tool and the ADR-numbering collision between the volumes and this register |
| **`Failure` cannot carry typed payload data** | Volume 3 §3.9 §5's model has `InsufficientStorage { final int freeBytes; }`. `Failure` has a code and an optional string, so "you need 2.3 GB free, you have 400 MB" can only be interpolated into an unlocalisable message | **A-035.** The material divergence. Two options are recorded there; both are architecture changes needing their own ADR |
| **`DioClient._guard` has no catch-all** | It catches `on DioException` only, unlike the other four boundaries. The assumption is sound — Dio wraps every failure it produces in a `DioException` — but it is an assumption about a third-party library, not a guarantee the compiler checks. Anything Dio throws outside that envelope (a `StateError` from a malformed `Options`, an error from a future interceptor) escapes `core/network/` untranslated, which is the one thing §7 exists to prevent | Add a trailing `catch (error, stackTrace)` producing a `NetworkException` with `ErrorCode.unknown`, matching the other four. Three lines, and it closes the only hole in the confinement guarantee |
| **No test for `ErrorInterceptor.mapToNetworkException`** | 13 documented mappings, no test file. The static exists specifically to make this testable without a live client | Add `test/core/network/interceptors/error_interceptor_test.dart`. The highest-value missing test in the repository |
| **No timeout outside the network layer** | An Isar open, a keychain read and Firebase initialisation can hang indefinitely (§15) | Needs a decision about which operations get a deadline. Low priority while all three are local and fast |
| **No general retry mechanism** | §16. ADR-035 covers the 401 refresh-and-retry only; backoff, attempt caps and durable retry state are still unowned | Belongs to the mission that builds upload, where the Constitution makes it mandatory |

**Verified as conforming**, across `mobile/lib/`:

| Audited | Result |
|---|---|
| Exception types | 5, all extending `AppException`, all named `*Exception` |
| `ErrorCode` cases | 28, all `SCREAMING_SNAKE_CASE` values, all documented |
| `Failure` subclasses | **0** — the single `final class` design holds |
| Third-party error types escaping their owning module | **0** — the four confinement checks pass |
| Boundaries ending in a catch-all | `SecureStorageService`, `DatabaseService`, `MigrationRunner`, `FirebaseInitializer` — 4 of 5 |
| Boundaries relying on a single typed clause | `DioClient` (`on DioException` only) — see the deviation table above |
| Conversion sites that capture the origin stack trace | **all of them** |
| Sites logging an already-taxonomised exception without re-binding the trace | 2, both correct (§23) |
| Empty `catch` blocks | **0** — and it is an analyzer error |
| `print` calls | **0** — and it is an analyzer error |
| Redacted header list | 7 entries, case-insensitive |
| `flutter analyze` | No issues |
