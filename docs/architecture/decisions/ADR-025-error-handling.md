# ADR-025 — Error Handling Model

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Records the error model built in Mission 0.10 and previously undocumented. Diverges from Volume 3 Chapter 3.9 §5 and Volume 6 Chapter 6.9 — see amendments A-035, A-036, A-037.

## Context

The application has a complete error model and **no ADR governs it.**

`core/errors/` defines an `AppException` hierarchy of five types, a `Failure` value type, and a 28-case `ErrorCode` enum. Five infrastructure boundaries convert third-party errors into it. The design is coherent, deliberate, and documented in the doc comments of the files that implement it — and `docs/architecture/README.md` states plainly what that means: *"An architectural decision that is not recorded here does not exist. Verbal agreement, chat history, a comment in a pull request and an implementation detail in the codebase are all insufficient."*

It also names this specific omission. The Current State section lists *"decisions still to be recorded"* and includes the logging infrastructure and the HTTP client boundary — the two layers most entangled with the error path. The error taxonomy itself was not even on that list.

An error model meets every criterion in the guide's own "when to create a new ADR": it establishes a cross-cutting pattern for error handling, it defines what may cross a layer boundary, and it is expensive to reverse — every `catch` in the codebase depends on it.

**Two conflicts with the volumes make recording it urgent rather than tidy.**

**Volume 3, Chapter 3.9 §5 specifies a different model.** It requires that *"each feature that can fail defines its own sealed error type (a freezed union) rather than throwing a bare Exception, so the Presentation layer can pattern-match to the exact Chapter 2.9-specified message"*, with the worked example:

```dart
sealed class ChecklistFailure {}
class PermissionDenied extends ChecklistFailure {}
class InsufficientStorage extends ChecklistFailure { final int freeBytes; }
class BatteryTooLow extends ChecklistFailure { final int percent; }
```

The implementation is the opposite shape: one `final class Failure` distinguished by an `ErrorCode`, whose doc comment explicitly rejects the alternative — *"A hierarchy of failure subclasses would push infrastructure concerns back into the shape of the type."* Volume 6 §6.9 §1 depends on the volume's model by name. Neither disagreement is recorded anywhere.

**Volume 6, Chapter 6.9 §2 requires two global handlers that do not exist.** `FlutterError.onError` and `PlatformDispatcher.instance.onError`, both funnelling into one `ErrorReportingService`. Verified: neither is installed, no such service exists, and `firebase_crashlytics` — which §6.9 §3 selects — is not a dependency. An unexpected exception in the field today is reported nowhere.

`lib/features/` is empty. Every feature that will raise a domain error is unwritten, so this is the last moment the model can be recorded before code is written against an unstated version of it.

## Decision

### The error model is recorded as it is built, and specified in one reference

`docs/architecture/error-handling.md` is the canonical error handling standard: thirty sections covering purpose, philosophy, expected behaviour, the ten error categories, the exception hierarchy, object structure, codes, logging, user-facing messages, diagnostics, stack traces, recovery, fallback, propagation, testing, documentation and maintenance — with an audited register of known deviations.

It follows the ADR-plus-reference pattern used by ADR-019, ADR-020, ADR-022, ADR-023 and ADR-024.

**Placement is `docs/architecture/`, not `docs/development/`.** The error model is a layer-boundary contract — what may cross out of infrastructure, and in what shape — which puts it beside `folder-structure.md`'s import matrix rather than beside a writing standard. ADR-024 §20's audience test decides it: someone handling an error is deciding what crosses a boundary, which makes them a reader of architecture.

**Every rule was derived from the code, not chosen.** The reference cites the doc comments that already state each reason, because those comments are the primary record and this ADR is only making them binding.

### Two representations, asymmetric on purpose, with one conversion point

`AppException` is internal: it carries `errorCode`, `message`, `cause` and `stackTrace`, and never crosses out of infrastructure. `Failure` is what crosses: a `code` and an optional `message`, with **no `cause` and no `stackTrace`.**

`Failure.fromException` is the single sanctioned conversion. That factory is what makes the guarantee structural rather than habitual — a `Failure` cannot leak a Dio error, an Isar handle or a filesystem path into a widget, and cannot tempt application code into branching on an implementation detail.

`AppException` is **abstract, not sealed**, so infrastructure can extend it per concern. `Failure` is **`final` with no subclasses**, so there is exactly one failure type.

### `ErrorCode` is the closed vocabulary, and the only thing to branch on

28 cases in five groups. Infrastructure maps *into* it; application code switches *on* it. **No layer may branch on a message string or on a third-party error type** — the message is developer-facing prose that may be reworded at any time; the code is the contract.

Adding a case is routine. Changing an existing `code` string is a breaking change to every log query and dashboard that references it, and is treated as a protocol change.

### The catch-all at an infrastructure boundary is required

The established `_guard` form is specific `on` clauses first, a bare `catch` last, always constructing an `AppException` with `cause` and `stackTrace` preserved. A boundary that caught only the errors it had thought of would let the others through untranslated.

This is why ADR-021 excludes `avoid_catches_without_on_clauses`: the rule would force an `ignore` comment at every boundary and convert a design invariant into per-site suppression. `avoid_catching_errors` stays enabled, so catching an `Error` — a programming mistake rather than a failure — remains forbidden.

### The stack-trace rule is about construction, not about catching

Bind and pass `stackTrace` when **constructing** an `AppException` from a foreign error: that is the only moment the origin trace can be captured. When logging an exception that already carries one, pass the exception and let its own trace travel with it.

This is recorded because two sites in the repository log an already-taxonomised exception without re-binding the trace, and both are **correct** — a naive "always bind the stack trace" rule would have flagged working code as defective.

### Retry is classified but not designed

**No retry logic exists**, and `AuthInterceptor` already records why: the refresh-and-retry question *"requires its own ADR. Until it is taken, this class stays inert."* This ADR does not take it.

What it does fix is the **classification** — which `ErrorCode`s are retryable and which are terminal — because that is derivable from the taxonomy and is the input the retry ADR will need. The distinction that matters most is `AUTH_UNAUTHENTICATED` (retry after a refresh) against `AUTH_FORBIDDEN` (never retry): conflating them produces a sign-in loop.

The constraints are already binding from elsewhere and are restated as constraints, not invented: idempotency is a property of ADR-011's deterministic key rather than of the attempt; backoff must be exponential with jitter so a device fleet does not synchronise into a thundering herd; retry state must survive a process kill because the Constitution requires the upload queue to survive a force-close.

### A user-facing message is resolved from the code

`ErrorCode.code` is *never rendered to a user*; `Failure.message` is a diagnostic aid. Display text is resolved from the code, which is the only form that is localisable, against Volume 2 §2.9's copy table.

**"Something went wrong" is forbidden** — Volume 3 §3.9 §5 requires every failure to name a specific cause and fix. In an offline-first app a generic message is also misleading: "Upload failed" suggests loss where the Constitution guarantees none.

### The divergences from the volumes are registered, not silently taken

Three amendments, because a documented model that contradicts a volume without saying so is exactly the latent disagreement the register exists to prevent:

- **A-035** — the single `Failure` against Volume 3 §3.9 §5's sealed per-feature unions, including the one capability the volume has and the implementation lacks: typed payload data.
- **A-036** — Volume 6 §6.9 §2's two global handlers and `ErrorReportingService`, none of which exists.
- **A-037** — Volume 6 §6.9 §3 selects Firebase Crashlytics in a decision it numbers "ADR-010", colliding with this repository's ADR-010, and the tool is not adopted.

## Alternatives Considered

- **Adopt Volume 3 §3.9 §5's sealed per-feature failure unions and change the code to match.** Rejected for this mission, and genuinely close on the merits. The volume's model has one capability the implementation lacks — typed payload data, so `InsufficientStorage { freeBytes }` can render "you need 2.3 GB free, you have 400 MB" as localisable structured data rather than an interpolated string. Rejected here because it is a rewrite of `core/errors/` and every boundary, which is code, and this mission changes none. A-035 records both options for the mission that owns the decision.

- **Record the model without registering the divergence.** Rejected. It would leave an accepted ADR silently contradicting two volumes, which is precisely the failure the amendment register exists to prevent and which A-032 was created to correct in another area.

- **Extend `Failure` with a payload field now** — a `Map<String, Object?>` of context. Rejected. It reintroduces untyped data at the boundary the model exists to keep typed, and `strict-casts` plus `avoid_dynamic_calls` (ADR-021) are in place specifically to stop that. If typed payloads are needed, the sealed-union option is the honest way to get them.

- **Install the global handlers as part of this mission.** Rejected. It is code, and it depends on an unresolved question: the handlers must funnel into one `ErrorReportingService`, and what that service does depends on whether Crashlytics is adopted (A-037). Installing handlers that only log would satisfy the letter of Volume 6 §6.9 §2 and none of its purpose.

- **Add the missing `CONFIG_*` error codes and move `FirebaseInitializationException`.** Rejected as out of scope, and recorded as the two smallest outstanding items in the error path. The exception's own doc comment already asks for both — *"a `firebaseInitializationFailed` case belongs in the taxonomy"* and *"it should be moved for consistency when `core/errors/` is next in scope"* — so the fix is specified and needs only a mission that may touch code.

- **Define a retry policy in this ADR.** Rejected. `AuthInterceptor` states that the question needs its own ADR, and the substance — concurrent-refresh coordination, backoff parameters, persistence of attempt counters, what happens when refresh finally fails — is design work, not documentation. Classifying retryable against terminal codes is the part that follows from the taxonomy and is the part taken here.

- **Add an `ApplicationException` type for the application layer.** Rejected. It would only ever wrap an `AppException` from below or a rule violation from `domain/`, adding indirection and a second thing to catch. The application layer's job in the error path is to *stop* exceptions, not to introduce one.

- **One exception type per store, replacing `StorageException`.** Rejected, and the existing reasoning is better than a new one: `storage_exception.dart` records that which store a repository uses is an implementation detail, and encoding it in the type would leak that detail upward through the `catch` clause. Given ADR-009's engine risk (A-029), a caller able to write `on IsarException` would be coupled to a package that may be replaced.

## Consequences

- **The error model is now binding**, so a future feature cannot invent a second one, and a reviewer has a document to cite. It also means the model can only be changed by superseding this ADR — which is the intended cost.

- **A-035 is an open architectural question, not a filing exercise.** The typed-payload gap is real and will be felt by the first feature whose copy needs a number in it — the checklist, per Volume 3's own example. Deferring it is correct while `features/` is empty and gets more expensive with each feature written against the current model.

- **A-036 means unexpected exceptions are invisible in the field today.** A Collector's device, hours from the nearest developer, throws an unanticipated platform exception and nobody learns of it. This is the most consequential gap the audit found, and the reference records it as such.

- **The retry classification is committed before the mechanism exists.** If the retry ADR disagrees with the retryable/terminal split, it supersedes this one for that part. Fixing the classification early is worth that risk: the alternative is each caller deciding independently, which is how a sign-in loop gets shipped.

- **`avoid_catches_without_on_clauses` stays excluded from the lint set**, and that exclusion is now justified by an ADR rather than by a comment in `analysis_options.yaml`. The cost is real: nothing mechanically distinguishes a required boundary catch-all from a lazy one, so review is the only check.

- **`DioClient` is the one boundary without a catch-all**, relying on Dio wrapping every failure in a `DioException`. The reference records it as a deviation with a three-line fix. It is the only hole in the confinement guarantee, and it was found by audit rather than by the analyzer — which is what a documented standard is for.

- **The 13 documented Dio-to-`ErrorCode` mappings have no test.** Writing the standard made the gap visible: the mapping is the single most branch-heavy piece of error logic in the codebase and the static was made public specifically so it could be tested without a live client.

- **Volume 6 §6.9's crash-report scrubbing rule is now recorded ahead of the mechanism it constrains.** When a crash reporter is finally wired up, the requirement that reports are scrubbed of secure-storage contents and raw GPS or device fields is already stated, rather than being remembered at the moment of integration.

## Related Missions

- Mission 0.10 — Error Architecture, which built `core/errors/`, the five exception types and the `ErrorCode` taxonomy this ADR records.
- Mission 0.11.2 — Core Logging Infrastructure, which supplies the `AppLogger` the error path logs through.
- Mission 0.15 — Firebase Foundation, which produced `FirebaseInitializationException` and both of its self-documented deviations.
- Mission 0.19.1 — Static analysis (ADR-021), which makes seven of the error-path conventions analyzer errors and excludes `avoid_catches_without_on_clauses` for the reason this ADR now justifies.
- Mission 0.19.5 — Error Handling Standards, which produced this ADR, the reference, and amendments A-035 to A-037.

## Implementation Status

**Implemented for the modelled path. The unexpected-exception path does not exist.**

`docs/architecture/error-handling.md` carries the standard. Verified by audit over `mobile/lib/`:

| Audited | Result |
|---|---|
| Exception types, all extending `AppException` | 5 |
| `ErrorCode` cases, all `SCREAMING_SNAKE_CASE`, all documented | 28 |
| `Failure` subclasses | **0** — the single-type design holds |
| Third-party error types escaping their owning module | **0** — the four confinement checks pass |
| Boundaries ending in a catch-all | 4 of 5 — `DioClient` is the exception |
| Empty `catch` blocks | **0**, and it is an analyzer error |
| `print` calls | **0**, and it is an analyzer error |
| Redacted headers, case-insensitive | 7 |
| Global error handlers installed | **0 of 2** required by Volume 6 §6.9 §2 |
| Crash reporting | **not adopted** |
| Retry implementations | **0** |
| Configuration error codes | **0** |
| `flutter analyze` | No issues |

No code was changed. Every repository reference in both documents was verified to exist, and every quotation was taken from the file it is attributed to.

**Four errors in this mission's own draft were caught by verification and corrected.**

1. **The boundary list was wrong.** The draft listed `DioClient` among the boundaries with a specific-then-catch-all guard. It has `on DioException` and no catch-all. Reading the code instead of assuming the pattern turned an incorrect claim into a recorded deviation with a fix — the most useful finding in the audit.

2. **The stack-trace claim was wrong, and inverted a correct pattern.** The draft asserted zero `catch` clauses discard an available stack trace. Two do: `database_service.dart` does not bind it when rethrowing an already-taxonomised `StorageException`, and `main.dart`'s non-fatal branch logs without it. Both are **correct** — the exception already carries its origin trace, so a catch-site trace would be noise. The rule was restated to be about *construction* rather than about catching, which is what the code actually does.

3. **The retry section initially specified a mechanism.** It was cut back to a classification once `AuthInterceptor`'s doc comment was read: the mechanism explicitly needs its own ADR, and specifying one here would have been this mission inventing architecture it was told not to.

4. **A mission number was wrong.** The draft attributed `FirebaseInitializationException` to "Mission 0.12 — Firebase platform integration". ADR-010's own Related Missions section names **Mission 0.15 — Firebase Foundation**. Checking the citation against the ADR rather than inferring it from the ADR number caught it.
