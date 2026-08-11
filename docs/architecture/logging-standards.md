# Logging Standards

The canonical logging standard for the Vump Technologies repository.

Governed by **ADR-027**. Where this document and the ADR disagree, the ADR governs.

Every rule below was derived from `mobile/lib/core/logging/`, the one interceptor that logs, and the 17 call sites that use them. Where the repository has no logging behaviour for something this document covers, **the absence is recorded as an absence** — no framework is designed here.

**Nothing already governed is restated.** Cited, not duplicated:

| Already fixed by | What it fixes |
|---|---|
| Volume 3 Ch. 3.7 §6 | `print()` banned; one project-wide logger; log levels so CI and test tooling can filter noise from signal |
| Volume 9 Ch. 9.2 | Level semantics, `chunk_id`/`session_id` correlation, the ring-buffer and Crashlytics sink, personal-data redaction, 90-day retention — **partly unmet, see A-044** |
| Volume 4 Ch. 4.1 | Backend monitoring and logging is Amazon CloudWatch |
| ADR-007, ADR-016 | Credentials never in source; a secret must never be logged |
| ADR-017 | A fatal startup failure is logged at `fatal` and rethrown |
| ADR-018 | `EnvironmentProfile.logLevel` is the read surface for the configured level |
| ADR-021 | `avoid_print` as an analyzer **error** |
| ADR-025 · `error-handling.md` §20–23 | What to log on the error path, redaction, and the stack-trace rule |
| ADR-026 · `architecture-guardrails.md` | I17 (`print`), and the enforcement status of each invariant |

---

## 1. Purpose

Logging exists so that a failure on a device you cannot reach is still diagnosable.

Volume 3 Chapter 3.7 §6 states the reason and it is specific to this project: *"This is a small rule with an outsized payoff for a Windows-first workflow: as much debugging as possible should be diagnosable from structured logs rather than requiring a physical device in hand."*

The Vision Document sharpens the stakes. Collectors are *"field workers"* operating *"hours from the nearest developer"* (Volume 6 §6.9 §3's phrasing), and the Constitution §3 requires the app to work offline — so the moments most worth logging happen where nobody is watching.

**The consequence for this standard:** a log line is written for someone reading it later, remotely, without the device and without the code in front of them. That is the test every rule below is measured against.

---

## 2. Architecture

Four types, all in `core/logging/`, and one interceptor.

| Component | Responsibility |
|---|---|
| `AppLogger` | The application's only logging mechanism. Five level methods, each taking an optional `error` and `stackTrace` |
| `LogLevel` | The application's own severity vocabulary, so no caller names the `logger` package's `Level` |
| `LogFormatter` | Renders an event as plain lines. Replaces `PrettyPrinter` |
| `loggerProvider` | The single sanctioned way to obtain an `AppLogger` (ADR-003) |
| `LoggingInterceptor` | The only component that logs on behalf of another layer — and the only one that redacts |

**The `logger` package is confined to `core/logging/` — exactly three files.** Verified: `package:logger` is imported by `app_logger.dart`, `log_formatter.dart` and `log_level.dart`, and nowhere else in `lib/`. `LoggingInterceptor` imports `AppLogger`, not the package. `LogLevel`'s doc comment states the purpose: *"no code outside `core/logging` refers to the `logger` package's `Level` type — replacing the underlying package should not require editing call sites."*

**That confinement is a convention, not a checked invariant.** The `Architecture boundaries` CI job enforces four package confinements — `dio`, `isar`, `flutter_secure_storage`, `firebase_core` (ADR-026 guardrails I1–I4). `logger` is a fifth package with a documented owner and **no check**, so a `package:logger` import in a feature would pass CI while breaking the substitutability the layer exists to provide. Recorded in §14; the fix is one line in the existing job.

One test imports `package:logger` deliberately, for the `LogOutput` type it substitutes (§13). Tests are outside the confinement rule, as they are for every other package.

**There is no singleton, no static instance and no service locator**, deliberately. `logger_provider.dart` records why: *"A global would be reachable from anywhere, unoverridable in tests, and constructed before configuration was known."*

**`_ThresholdFilter` replaces the package's `DevelopmentFilter`.** This is load-bearing rather than incidental: `DevelopmentFilter` *"suppresses everything outside debug builds and would therefore silence production logging entirely."*

---

## 3. Entry points

**Every log statement goes through an `AppLogger` obtained from `loggerProvider`.** There is no other entry point.

Verified — 17 call sites in `lib/`, and no `print`:

| Location | Level(s) | What it records |
|---|---|---|
| `main.dart` | `info`, `warning`, `error`, `fatal` | Startup: the resolved environment, an unrecognised `APP_ENV`, and the Firebase outcome |
| `core/firebase/firebase_initializer.dart` | `info`, `debug`, `error` | Platform initialisation, adoption on hot restart, failure |
| `core/database/database_service.dart` | `info`, `error` | Open with collection count and duration, close, failure |
| `core/database/migrations/migration_runner.dart` | `info`, `debug` | Schema version reached, each migration applied |
| `core/network/interceptors/logging_interceptor.dart` | `debug`, `warning` | Every request, response and failure |

**Distribution:** `info` 7, `error` 4, `debug` 4, `warning` 2, `fatal` 1.

**Only `core/` and `main.dart` log today.** `lib/features/` and `lib/shared/` are empty, so no feature or widget has ever logged. Every rule below about feature logging is therefore binding and unexercised.

**A caller reaches the logger through injection, never construction.** `DatabaseService`, `MigrationRunner`, `FirebaseInitializer` and `LoggingInterceptor` all take `AppLogger` as a constructor argument. `main.dart` reads it from the container. Nothing calls `AppLogger(...)` outside `loggerProvider` and one test.

---

## 4. Sinks

**The console is the only sink in every environment. Nothing ships a log off the device.**

`AppLogger` takes an optional `LogOutput`, documented as *"an injection point for tests and for future log destinations. When null, the underlying package writes to the console."* `loggerProvider` supplies no output:

```dart
final Provider<AppLogger> loggerProvider = Provider<AppLogger>(
  (Ref ref) => AppLogger(environment: AppConfig.environment),
);
```

**The seam is real and exercised** — `test/core/firebase/firebase_initializer_test.dart` defines a `_SilentOutput extends LogOutput` that discards output, *"so a failing-by-design test does not print noise."* That is the only supplied `LogOutput` in the repository.

**Volume 9 Chapter 9.2 §3 specifies the sink, and it is not a remote aggregator.** Mobile logs are *"kept in a local ring buffer (last N entries) attached automatically to a Crashlytics report if a crash occurs, and are **not otherwise transmitted off-device** — logging is for local debugging and crash context, not a telemetry pipeline in itself (that's Chapter 9.3, Analytics, a deliberately separate concern)."*

| Sink | Specified by | Status |
|---|---|---|
| Console | — | Exists. The default, in all three environments |
| **Local ring buffer, last N entries** | **V9.2 §3** | **Does not exist** |
| **Attached to a Crashlytics report on crash** | **V9.2 §3** | **Does not exist** — Crashlytics not adopted (**A-037**) |
| Global handlers feeding it | V6.9 §2 | Do not exist (**A-036**) |
| A remote log aggregator | — | **Deliberately not wanted.** V9.2 §3 forbids off-device transmission; telemetry is Chapter 9.3's separate concern |
| Backend logs to CloudWatch | V4 §4.1 | `backend/` is empty (ADR-015) |

> **Corrected in Mission 0.19.8.** This section previously framed the gap as *"no log leaves the device, so Volume 3 §3.7 §6's payoff is not achieved"*, and implied a remote aggregator was missing. Volume 9 Chapter 9.2 §3 — not consulted when this document was written — makes off-device transmission **explicitly unwanted**. The real gap is narrower and different: the **ring buffer and the crash-report attachment** are specified and absent. Registered as **A-044**, which corrects **A-043**.

**The practical effect, compounded by §5's level policy:** in production the logger emits `warning` and above to a console nobody is attached to, and nothing retains those lines for a crash report to carry. A production failure on a Collector's device today produces no record that survives the process — which is what V9.2 §3's ring buffer exists to prevent.

**The backend's sink is decided and is not this one.** Volume 4 Chapter 4.1 fixes *"Monitoring/Logging: Amazon CloudWatch (Lambda + RDS metrics/logs)"*. `backend/` is empty (ADR-015), so nothing implements it. Mobile logging and backend logging are separate concerns with separate sinks and must not be conflated.

---

## 5. Levels and severity

Five levels. `LogLevel`'s doc comment explains the count: *"`logger` also offers `trace`, `all` and `off`, which are either redundant with [debug] or a filter setting rather than a severity."*

| Level | Label | Use for | Used at |
|---|---|---|---|
| `debug` | `DEBUG` | Diagnostic detail while developing | 4 sites |
| `info` | `INFO` | A normal, expected event worth recording | 7 sites |
| `warning` | `WARNING` | Something unexpected that was recovered | 2 sites |
| `error` | `ERROR` | An operation failed; the application continues | 4 sites |
| `fatal` | `FATAL` | Unrecoverable; the application cannot continue meaningfully | 1 site |

**Volume 3 §3.7 §6 names four — `debug/info/warn/error`.** The implementation adds `fatal` and spells the third `warning`. The added level is load-bearing: ADR-017's abort path logs at `fatal` before rethrowing, which is what distinguishes *"aborting startup rather than running against an uninitialised platform"* from an ordinary failure. Registered as **A-042**, on the same basis as A-031 for the same chapter — the list is a floor, not a closed set.

**Verbosity is a pure function of environment**, per `AppLogger.minimumLevelFor`:

| Environment | Minimum | Effect |
|---|---|---|
| `development` | `debug` | Everything, including every HTTP request |
| `staging` | `info` | *"Enough to trace a session without the volume of development logging"* |
| `production` | `warning` | *"Logs record what went wrong rather than what happened"* |

**Volume 9 Chapter 9.2 §1 disagrees with the production row.** It defines `info` as *"Normal lifecycle events worth seeing **in production logs** — Session started, chunk finalized, upload complete."* A production minimum of `warning` filters exactly those events out. Registered as **A-044**, found in Mission 0.19.8 — Volume 9 Chapter 9.2 was not consulted when this document was first written.

**There is no `kDebugMode` check anywhere in this layer, deliberately.** `AppLogger` states why: *"build mode and environment are different questions, and a staging build is a release build."* A `kDebugMode` gate would silence staging, which exists to rehearse production (ADR-014).

**The switch is exhaustive over `AppEnvironment`**, so adding an environment is a compile error rather than a silent default. Three tests assert the policy — `app_environment_test.dart` checks all three mappings, and `environment_profile_test.dart` checks that `EnvironmentProfile.logLevel` equals the owner.

**Choosing a level, in one line each:**

- `debug` — you would delete it before shipping if you had to. It will not appear in staging or production.
- `info` — a reader reconstructing what happened would want this line. Startup, a database opening, a migration applied.
- `warning` — a fallback was taken, or something unexpected was survived. An unrecognised `APP_ENV`; an HTTP call that failed.
- `error` — an operation did not complete. Pass the `AppException`.
- `fatal` — the application is about to stop. One site, and adding a second is a decision.

**`isEnabled(level)` exists so a caller can skip building an expensive message** that would be discarded. Nothing currently uses it; it is the correct guard for a log line whose message costs real work to construct.

---

## 6. Format and structured logging

`LogFormatter` emits one line per event, with error and stack trace indented beneath:

```text
2026-08-09T14:32:07.118Z [ERROR  ] Token refresh failed
  error: NetworkException(NETWORK_TIMEOUT): request timed out
  stack:
    #0  TokenRefresher.refresh (package:mobile/...)
```

Three decisions are recorded in the formatter itself:

- **Not `PrettyPrinter`.** *"Its boxes and colour codes are pleasant in a terminal and unreadable in a log aggregator, where these lines will eventually be shipped."*
- **ISO-8601 timestamps**, because *"they sort lexicographically and parse without a format string."*
- **Stack traces truncated at 15 frames**, because *"deep traces bury the event that caused them. The frames nearest the failure are the ones that matter, and they come first."* The omitted count is printed.

**The level label is padded to 7 characters** so messages align down the page.

**On "structured logs".** Volume 3 §3.7 §6 requires debugging to be *"diagnosable from structured logs"*. The current format is **line-oriented and deliberately aggregator-friendly** — sortable timestamps, a fixed-width level, one event per line — but it is **not key-value structured**: there is no JSON encoding and no field separation a parser could rely on beyond the timestamp and level prefix.

Whether §6's *"structured"* means machine-parseable records or simply well-organised output is genuinely ambiguous in the text, and this document does not resolve it by assertion. What is not ambiguous is the sink gap in §4, which defeats the sentence's purpose either way. Both are recorded in **A-043**.

---

## 7. Contextual metadata

**A log event carries five things and nothing else:** the timestamp, the level, the message, an optional `error`, and an optional `stackTrace`.

**There is no correlation ID, request ID, session ID, Collector ID, device ID or app version attached to any log line.** Verified: no such identifier appears anywhere in `core/logging/` or the interceptors.

> **Corrected in Mission 0.19.8.** This section previously stated that *"no Volume requires specific contextual fields"*, and that was wrong. **Volume 9 Chapter 9.2 §2 requires them by name:** *"Every log line touching a chunk or session includes its `chunk_id`/`session_id`… this is what makes it possible to reconstruct one Collector's one session's full journey."* The absence is therefore a **deviation from an approved Volume**, not a neutral gap. Registered as **A-044**. Volume 9 Chapter 9.2 was not consulted when this document was first written, which is the single largest miss in Mission 0.19.7.

The requirement is narrower and more useful than a general correlation ID: it applies to lines *touching a chunk or session*, and the identifiers are Volume 4 Chapter 4.4's, so a mobile log line and a backend CloudWatch line can be joined on the same value. Volume 9 §9.2 §4 pairs it with a redaction rule that depends on it — logs *"reference a `chunk_id` and let a developer join against the metadata store if genuinely needed, rather than duplicating sensitive fields into logs by default."*

What exists instead, and is worth preserving:

- **`LoggingInterceptor` correlates a request with its response by timing**, stashing the start time in `RequestOptions.extra` under `'vump.request.start'`. The doc comment notes that `extra` *"is the sanctioned per-request scratch space and is not transmitted, so the timing does not leak into the request itself."*
- **Messages name their subject inline** — `'Database "${config.name}" opened with N collections in Xms'`, `'→ GET https://…'`. That is how a reader currently reconstructs context.

**Any future correlation identifier must not be a secret or a personal identifier.** §8's prohibitions apply to metadata exactly as they apply to a message.

---

## 8. Sensitive data and redaction

`AppLogger`'s doc comment carries the contract, and it is the most emphatic in the codebase. The following must **never** appear in a log message, an error object, or any value interpolated into either:

`Authorization` headers in any form · access tokens · refresh tokens · passwords, PINs and passphrases · API keys and secrets of any kind · session cookies and identifiers that grant access.

*"Per ADR-007 these values are forbidden in source code; logging one puts it back in plain text and defeats that decision."*

**`AppLogger` does not redact, and cannot.** *"By the time a value reaches a log call it is an opaque string, and a redactor that guesses would either miss secrets or mangle legitimate content. Redaction is the caller's obligation, discharged at the boundary where the sensitive value is known."*

**`LogFormatter` does not redact either** — *"A secret passed to a log call will be written verbatim."*

**Log the shape of a thing, not the thing.** `'Authorization header present'`, not the header. `'refresh failed for user ${user.id}'`, not the token.

### Where redaction actually happens

`LoggingInterceptor` is the one place, *"because here the sensitive values are still identifiable as headers"*. Seven header names, compared case-insensitively because a server may echo `authorization` in any casing:

```text
authorization    proxy-authorization    cookie    set-cookie
x-api-key        x-auth-token           x-refresh-token
```

Each is replaced with `[REDACTED]`. **The header's presence is still recorded**, since *"knowing whether a request carried authorization is exactly what makes a 401 diagnosable."*

**Bodies are truncated, not sanitised** — 2000 characters, with the full length noted. The interceptor states the limit of its own guarantee: *"A body is unstructured at this layer and could contain a password or token under any key… Callers posting credentials must not rely on this interceptor to hide them."* That is the sharpest rule in this document: **a request body carrying a credential is the caller's problem, and the logging layer will not save them.**

**Interceptor order is what makes redaction work**, and it is fixed by ADR-007: `AuthInterceptor` → `LoggingInterceptor` → `ErrorInterceptor`. Auth runs first so anything it adds is subject to redaction. An interceptor added after logging would write its credential to the log.

**Volume 6 §6.9 §4 extends the same obligation to crash reports** — scrubbed of secure-storage contents and raw GPS or device fields beyond what is needed to reproduce the bug, *before* being sent. No reporter exists (A-037), so the rule is recorded ahead of the mechanism.

**Volume 9 §9.2 §4 adds a second class of forbidden value, and it is not a credential.** *"GPS coordinates, device identifiers, and any field Volume 8, Chapter 8.6 classifies as personal data are never logged at `info`/`debug` level in a form that would leak them into a general-purpose log stream — logs reference a `chunk_id` and let a developer join against the metadata store if genuinely needed, rather than duplicating sensitive fields into logs by default."*

Two things follow. **Personal data is as forbidden as a secret**, and it is easier to log by accident because it is not obviously sensitive — a GPS coordinate looks like diagnostic detail. And **the correct substitute is an identifier, not omission**: log the `chunk_id` and join against the metadata store. That is why §7's missing `chunk_id` is not merely a convenience gap — it is the mechanism this rule depends on.

V9.2 §4 states its own enforcement: *"This mirrors, and is enforced by the same **review discipline** as, Volume 6 Chapter 6.9's crash-report scrubbing rule."* No analyzer or CI check exists for it, which is why it appears in the review checklist (`docs/development/review-checklist.md`) rather than here alone.

**`avoid_print` is an analyzer error** (ADR-021, guardrail I17) for this reason: `print` bypasses both the level filter and every redaction boundary. A printed token is a leaked token.

---

## 9. Error-path logging

**Fixed by ADR-025 and specified in `error-handling.md` §20–23. Not restated.** The three rules that matter most, by reference:

- **Log the exception, not a re-description of it.** `AppException.toString()` already emits the code, message, cause and any subclass field.
- **Log once, at the layer that decides.** The boundary that converts an error does not log it; the caller that decides what to do does. `main.dart` is the model — it catches, decides fatal-or-not from the ADR-017 flag, and logs at the matching level.
- **Bind `stackTrace` when constructing an exception; pass the exception when logging one.** An already-taxonomised exception carries its own origin trace, so two sites deliberately log without re-binding it.

**One thing belongs here rather than there:** `AppLogger.error`'s doc comment states that *"an `AppException` renders its error code and message, which is what makes a log line searchable."* That is the reason `ErrorCode` values are `SCREAMING_SNAKE_CASE` (ADR-023 §2.5) — they are greppable in an aggregator, distinguishable from prose.

---

## 10. Global handlers

**Neither global handler exists.** Volume 6 §6.9 §2 requires `FlutterError.onError` and `PlatformDispatcher.instance.onError`, both funnelling into one `ErrorReportingService` *"so there is exactly one place that decides what happens next, not two independent logging paths."*

Verified: no handler is installed and no such service exists. Registered as **A-036** by ADR-025; restated here only as the boundary it sets for this document.

**The consequence for logging specifically:** an unanticipated exception never reaches `AppLogger` at all. It is printed by the framework's default handler in a format this standard does not govern, at a severity it does not choose, to a sink it does not control. Every rule in this document applies to the modelled path only.

**When the handlers are installed**, they must log through `AppLogger` rather than beside it — otherwise §6's format and §8's redaction apply to one path and not the other, which is the *"two independent logging paths"* Volume 6 §6.9 §2 forbids by name.

---

## 11. Production versus debug behaviour

**The only difference is the minimum level**, and it comes from `AppEnvironment`, never from build mode (§5).

| | `development` | `staging` | `production` |
|---|---|---|---|
| Minimum level | `debug` | `info` | `warning` |
| HTTP requests and responses | Logged | **Not logged** | **Not logged** |
| HTTP failures | Logged | Logged | Logged |
| Startup, database open, migrations | Logged | Logged | **Not logged** |
| Errors and fatals | Logged | Logged | Logged |
| Format | Identical | Identical | Identical |
| Sink | Console | Console | Console |

**Request logging disappearing outside development is correct and deliberate.** `LoggingInterceptor` logs requests and responses at `debug` and failures at `warning`, so the level policy alone means a production build records failed calls and not successful ones — without a second configuration switch.

**Nothing is compiled out.** Suppression is a runtime filter, so a discarded `debug` call still evaluates its message argument. This is why `isEnabled` exists (§5), and it is the one performance consideration in this layer: on a device recording video, a `debug` line that builds a large string in a hot path costs frame budget in production even though nothing is written.

---

## 12. Ownership and boundaries

| Concern | Owner |
|---|---|
| The logging mechanism | `core/logging/` — ADR-026 guardrail, and the `logger` package is confined here |
| Verbosity policy | `AppLogger.minimumLevelFor` |
| The read surface for the configured level | `EnvironmentProfile.logLevel` (ADR-018) — a delegating view, never a copy |
| Output format | `LogFormatter` |
| HTTP redaction | `LoggingInterceptor` + `NetworkConstants.redactedHeaders` |
| Backend logs | CloudWatch (Volume 4 Ch. 4.1) — a separate sink, separate concern |
| Audit and compliance logging | **Not this layer.** Volume 4 defers *"full audit/compliance logging requirements"* to Volume 8, which specifies an Aurora `audit_log` table. A durable audit record of who did what is a backend data concern, not diagnostic output |

**The audit-versus-diagnostic distinction is the one most worth holding.** Diagnostic logs are for engineers, are lossy by design (production drops `info`), and go to a console. An audit trail is evidence, must be durable, and lives in a database. Using `AppLogger` for anything that must survive would be a category error — nothing it writes is durable anywhere.

**Every layer may log, and every layer receives the logger by injection.** No exception: a widget that needs to log takes an `AppLogger` from `ref.read(loggerProvider)` like any other dependency.

---

## 13. Testing

**What exists:**

- **The level policy is asserted three times** — `app_environment_test.dart` checks all three environment mappings; `environment_profile_test.dart` checks `logLevel` delegates to the owner rather than duplicating it.
- **The `LogOutput` seam is used** — `firebase_initializer_test.dart`'s `_SilentOutput` discards output so a failing-by-design test does not print noise.

**What does not exist:** no test asserts on log *content*, on the format `LogFormatter` produces, or on redaction. Verified — `LogFormatter`, `_ThresholdFilter` and `_redactHeaders` have no tests.

**The redaction gap is the one that matters.** §8's seven-header list is the only mechanism standing between a bearer token and a log line, it is a pure function of its input, and nothing verifies it. A capturing `LogOutput` — the seam already exists — makes it a short test:

- A request carrying each of the seven headers logs `[REDACTED]` and not the value.
- Comparison is case-insensitive, so `Authorization` and `authorization` are both caught.
- A non-sensitive header passes through unchanged.
- A body over 2000 characters is truncated and the full length reported.

**Silence log output in tests rather than tolerating it.** `_SilentOutput` is the pattern; a test that prints real log lines makes a failing run harder to read.

---

## 14. Known gaps and deviations

Audited across `mobile/lib/` and `mobile/test/`. Recorded rather than fixed — this is a documentation and governance mission.

| Gap | Evidence | Disposition |
|---|---|---|
| **No ring buffer, no crash-report attachment** | V9.2 §3 specifies both; `loggerProvider` supplies no `LogOutput` at all | **A-044.** The largest gap. Off-device transmission is *not* wanted (V9.2 §3) — the missing piece is local retention that a crash report can carry |
| **Production suppresses `info`** | `minimumLevelFor(production)` = `warning`; V9.2 §1 wants lifecycle events *"worth seeing in production logs"* | **A-044.** A direct contradiction with an approved Volume |
| **No `chunk_id`/`session_id` on log lines** | V9.2 §2 requires them on *"every log line touching a chunk or session"* | **A-044.** No chunk or session exists yet, so unexercised rather than violated in practice |
| **No global handlers** | Volume 6 §6.9 §2 requires two; neither installed | **A-036** (ADR-025). Unmodelled exceptions never reach `AppLogger` |
| **No crash reporting** | Volume 6 §6.9 §3 selects Crashlytics; not a dependency | **A-037** (ADR-025) |
| **Not key-value structured** | Line-oriented text; no JSON, no parseable field separation | Part of **A-043**; §6 records that V3.7 §6's *"structured"* is ambiguous. V9.2 §2's join-on-`chunk_id` requirement makes parseability more valuable than §6 alone implied |
| **`fatal` is undocumented in the Volumes** | V3.7 §6 names four levels; five exist | **A-042.** The list is a floor, as A-031 established for the same chapter |
| **`logger` confinement is unchecked** | The CI job covers four packages; `logger` is a fifth with a documented owner and no check (§2) | Add `check logger lib/core/logging/` to the `Architecture boundaries` job. One line, and it closes an ADR-026-shaped gap that ADR-026 did not list |
| **No test for redaction, format or filtering** | `LogFormatter`, `_ThresholdFilter`, `_redactHeaders` untested | The highest-value missing test in this layer (§13) |
| **`isEnabled` has no caller** | Verified across `lib/` | Not a defect — it is the correct guard for an expensive message, and there is not yet one |
| **CI does not filter logs by level** | V3.7 §6 cites CI and test tooling filtering noise from signal; `flutter test --reporter expanded` does no filtering | Recorded. Tests can silence output, which is half of what §6 describes |

---

## 15. Maintenance

- **A new log call picks its level from §5's one-line tests**, and passes the exception rather than describing it.
- **A new sink must not bypass `LogFormatter` or the redaction contract.** Adding a `LogOutput` is the sanctioned mechanism; adding a second logging path is not (§10).
- **A new sensitive header is added to `NetworkConstants.redactedHeaders`**, which is the single list. A new *kind* of sensitive value at a new boundary needs redaction at that boundary — `AppLogger` will not do it.
- **A second `fatal` call site is a decision**, not a detail. There is one, and it aborts startup.
- **Replacing the `logger` package should touch `core/logging/` only.** `LogLevel` exists to make that true; a call site naming `Level` breaks it.
- **When a feature first logs**, this document's untested rules get their first exercise. Nothing in `features/` has ever logged.
