# ADR-027 — Logging Architecture

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Records the logging layer built in Mission 0.11.2 and named by `docs/architecture/README.md` as undocumented. Diverges from Volume 3 Chapter 3.7 §6 — see amendments A-042 and A-043.

## Context

`docs/architecture/README.md` has been carrying this gap in writing for eleven missions:

> *"Decisions still to be recorded: logging infrastructure, the HTTP client boundary, and runtime provisioning of build-time secrets. **The logging and networking layers are implemented but undocumented.**"*

The logging layer is four types and one interceptor — `AppLogger`, `LogLevel`, `LogFormatter`, `loggerProvider`, `LoggingInterceptor` — with 17 call sites, an environment-driven verbosity policy, a seven-header redaction list, and a deliberate rejection of the underlying package's default filter and printer. Every one of those is a decision. None is recorded in an ADR.

It is also the layer with the most decisions embedded in doc comments rather than in governance. `AppLogger` carries the sensitive-data contract, the reason it cannot redact, and the reason there is no `kDebugMode` check. `LogFormatter` carries the reason it is not `PrettyPrinter`. `logger_provider.dart` carries the reason there is no singleton. Those reasons are good, and they are one file rename away from being lost.

**Two things forced the ADR now rather than later.**

**Volume 3 Chapter 3.7 §6 asks for something the implementation does not deliver.** The chapter's stated payoff is that *"as much debugging as possible should be diagnosable from structured logs rather than requiring a physical device in hand"* — chosen deliberately for a Windows-first workflow with Android as the test target. The audit found that **no log leaves the device**: `loggerProvider` supplies no `LogOutput`, so the console is the only sink in all three environments. Combined with a production minimum level of `warning`, a production failure on a Collector's device produces no durable record anywhere. That is a gap between an approved Volume and the implementation, and nothing recorded it.

**`lib/features/` is empty, so every rule about feature logging is untested.** Only `core/` and `main.dart` have ever logged. The first feature to log will do so against whatever it finds, and what it finds today is five level methods with no written guidance on choosing between them.

## Decision

### The logging architecture is recorded as built, and specified in one reference

`docs/architecture/logging-standards.md` is the canonical logging standard: fifteen sections covering purpose, architecture, entry points, sinks, levels, format, contextual metadata, redaction, error-path integration, global handlers, production versus debug behaviour, ownership, testing, gaps and maintenance.

It follows the ADR-plus-reference pattern of ADR-019 through ADR-026, and is placed in `docs/architecture/` beside `error-handling.md` because logging is a `core/` boundary contract — what may be written, by whom, and what must never appear — rather than a writing practice.

**Every rule is derived from the implementation and its doc comments**, which already state most of the reasoning. This ADR makes them binding; it does not re-argue them.

### Absences are recorded as absences

The mission's constraint is adopted as a decision rather than followed silently: **where the repository has no logging behaviour, the standard records the absence and designs nothing.**

Applied in four places. There is no contextual metadata and **no Volume requires any**, so the standard records the absence and invents no correlation-ID scheme. There is no structured (key-value) encoding, and whether Volume 3 §3.7 §6's *"structured"* means machine-parseable is genuinely ambiguous in the text, so the standard says so rather than resolving it by assertion. There are no global handlers and no crash reporter — already A-036 and A-037 — so §10 states that every rule in the document applies to the modelled path only. And `isEnabled` has no caller, which is recorded as *not* a defect: it is the correct guard for an expensive message, and there is not yet one.

### The five levels are the vocabulary, and verbosity is a function of environment

`debug`, `info`, `warning`, `error`, `fatal` — the application's own enum, so no caller names the `logger` package's `Level` and the package stays replaceable.

Verbosity comes from `AppEnvironment` and **never from build mode**: `development` → `debug`, `staging` → `info`, `production` → `warning`. `AppLogger` records the reason no `kDebugMode` check exists — *"build mode and environment are different questions, and a staging build is a release build"* — and a `kDebugMode` gate would silence staging, which exists to rehearse production (ADR-014).

`_ThresholdFilter` replacing the package's `DevelopmentFilter` is part of the same decision: the default *"suppresses everything outside debug builds and would therefore silence production logging entirely."*

### Redaction is the caller's obligation, discharged at the boundary that knows

`AppLogger` does not redact and **cannot** — by the time a value reaches a log call it is an opaque string, and a redactor that guessed would either miss secrets or mangle content. `LogFormatter` does not redact either.

`LoggingInterceptor` is the one place it happens, because there the sensitive values are still identifiable as headers: seven names, compared case-insensitively, replaced with `[REDACTED]` while the header's *presence* is still recorded — since knowing whether a request carried authorization is what makes a 401 diagnosable.

**Bodies are truncated, not sanitised**, and the standard states that limit as sharply as the interceptor does: a body could carry a credential under any key, and *callers posting credentials must not rely on this interceptor to hide them.*

`avoid_print` remains an analyzer error (ADR-021, guardrail I17) because `print` bypasses both the level filter and every redaction boundary.

### Diagnostic logging is not audit logging

Recorded as a boundary because conflating them is a category error with compliance consequences. Diagnostic logs are for engineers, lossy by design — production drops `info` — and go to a console. An audit trail is evidence, must be durable, and Volume 4 defers *"full audit/compliance logging requirements"* to Volume 8, which specifies an Aurora `audit_log` table.

Nothing `AppLogger` writes is durable anywhere, so nothing that must survive may be written only through it.

### Two divergences from Volume 3 are registered

- **A-042** — Volume 3 §3.7 §6 names four levels (`debug/info/warn/error`); five exist. `fatal` is load-bearing: ADR-017's abort path logs at it before rethrowing. The list is a floor, on the same basis A-031 established for §2 of the same chapter.
- **A-043** — Volume 3 §3.7 §6's *"diagnosable from structured logs rather than requiring a physical device in hand"* is not achieved: the console is the only sink, and no contextual identifier would let an aggregator group lines if one existed.

## Alternatives Considered

- **Design a remote log sink and a correlation-ID scheme as part of this mission.** Rejected, and it is the temptation the mission explicitly forecloses. Both would be invented architecture: no Volume specifies a mobile log destination, no Volume names a required log field, and choosing a sink depends on the unresolved crash-reporter question in A-037. Recording the absence gives the next mission a specified problem instead of an inherited guess.

- **Treat the console-only sink as adequate and not register A-043.** Rejected. Volume 3 §3.7 §6's justification is explicitly about not needing the device in hand, and it is the only sentence in the Volumes explaining *why* this project logs at all. An implementation that requires the device defeats the stated purpose, and leaving that unrecorded would mean the next reader assumes remote diagnosis works.

- **Read Volume 3 §3.7 §6's "structured logs" as requiring JSON, and record the plain-text format as a violation.** Rejected as overreach. The sentence is about remote diagnosability, not encoding, and the formatter's choices — ISO-8601 timestamps that *"sort lexicographically and parse without a format string"*, one event per line, no colour codes because they are *"unreadable in a log aggregator"* — are aggregator-oriented on purpose. The standard records the ambiguity and the sink gap separately, because only the second is unambiguous.

- **Adopt JSON output now.** Rejected. It would make console reading worse during development, which is where 4 of the 17 call sites are aimed, in exchange for machine-parseability nothing currently consumes. The right moment is when a sink exists to consume it, which is A-043.

- **Make `AppLogger` redact defensively** — scan messages for token-shaped substrings. Rejected, and the existing reasoning is better than any new one: *"a redactor that guesses would either miss secrets or mangle legitimate content."* A defensive scanner also invites callers to stop thinking about it, which converts a discharged obligation into a hopeful one.

- **Add a `trace` level, or drop `fatal` to match the Volume's four.** Rejected both ways. `LogLevel` already records that `trace`, `all` and `off` are *"either redundant with debug or a filter setting rather than a severity"*. Dropping `fatal` would remove the level ADR-017's abort path uses to distinguish aborting from failing.

- **Record the logging decisions inside ADR-025 (error handling), since most logging is on the error path.** Rejected. Levels, verbosity policy, format, sinks and redaction apply to all 17 call sites, of which 11 are not error-path at all. Folding them into an error ADR would bury them and leave the same governance gap for `info` and `debug`.

- **Extend the `Architecture boundaries` CI job with the `logger` confinement in this mission.** Rejected as out of scope — documentation only — but it is the cheapest finding in the audit: one line, and it closes a gap ADR-026's own register did not list.

## Consequences

- **The logging layer is now governed**, so a future feature cannot invent a second logging path, and the reasons currently living in doc comments are binding rather than incidental.

- **A-043 makes explicit that production logging is currently write-only.** `warning` and above, to a console nobody is attached to. Anyone who assumed field diagnosis was possible now has evidence that it is not, which is the point of recording it.

- **The absence of contextual metadata is on record without a scheme being imposed.** The next mission is free to choose one, and knows why it matters — the Glossary makes `Session` the unit people reason about, and nothing currently lets lines from one be grouped.

- **The redaction contract is binding, and its one gap is stated.** Header redaction is enforced by the interceptor; body redaction does not exist and will not. A caller that posts a credential in a body is logging it.

- **The redaction list has no test**, and this ADR records that as the highest-value missing test in the layer. Seven header names are the only thing between a bearer token and a log line, `_redactHeaders` is a pure function, and the `LogOutput` seam needed to test it already exists and is already used.

- **`logger` confinement remains unchecked**, so a `package:logger` import in a feature would pass CI while breaking substitutability. Named here so it is a known gap rather than a surprise.

- **Every rule applies to the modelled path only.** Until A-036's global handlers exist, an unanticipated exception is formatted by the framework, at a severity this standard does not choose, to a sink it does not control.

- **Nothing in the repository changed.** The layer works as documented; the value is that the next contributor can see both what it does and what it does not.

## Related Missions

- Mission 0.11.2 — Core Logging Infrastructure, which built the layer this ADR records.
- Mission 0.11 — Network Foundation, which produced `LoggingInterceptor` and the redaction list.
- Mission 0.19.1 — Static analysis (ADR-021), which makes `avoid_print` an error.
- Mission 0.19.5 — Error handling (ADR-025), whose §20–23 this standard references rather than repeats, and which registered A-036 and A-037.
- Mission 0.19.7 — Logging Standards, which produced this ADR, the standard, and amendments A-042 and A-043.

## Implementation Status

**Implemented and undocumented until now. The remote-diagnosis half does not exist.**

`docs/architecture/logging-standards.md` carries the standard. Verified by audit over `mobile/lib/` and `mobile/test/`:

| Audited | Result |
|---|---|
| Logging entry points | 17 call sites, all through an injected `AppLogger` |
| Level distribution | `info` 7 · `error` 4 · `debug` 4 · `warning` 2 · `fatal` 1 |
| `print` calls | **0**, and it is an analyzer error |
| `package:logger` imports in `lib/` | **3**, all in `core/logging/` |
| Log sinks in production | **1** — the console. `loggerProvider` supplies no `LogOutput` |
| `LogOutput` implementations | 1, in a test (`_SilentOutput`) |
| Redacted headers, case-insensitive | 7 |
| Contextual metadata fields | **0** — no correlation, session, device or version identifier |
| Global error handlers feeding the logger | **0 of 2** required by Volume 6 §6.9 §2 |
| Tests asserting the level policy | 3 |
| Tests asserting format, filtering or redaction | **0** |
| `isEnabled` callers | **0** |
| Files that log outside `core/` and `main.dart` | **0** — `features/` and `shared/` are empty |
| `flutter analyze` | No issues |

No code was changed. Volume 3 §3.7 §6 and Volume 4 §4.1 were read from the source PDFs and quoted from the extracted text.

**Two errors in this mission's own draft were caught by verification and corrected.**

1. **The package-confinement claim was wrong.** The draft stated that `package:logger` is imported in `core/logging/` *"plus one import in `core/network/` for the `LogOutput` type"*. Grepping showed three imports, all in `core/logging/` — `LoggingInterceptor` imports `AppLogger`, not the package. The confinement is tighter than written, and correcting it surfaced the more useful finding: `logger` is a fifth package with a documented owner and no CI check, which ADR-026's register does not list.

2. **The claim that no test uses the `LogOutput` seam was wrong.** `firebase_initializer_test.dart` defines `_SilentOutput extends LogOutput` and injects it, *"so a failing-by-design test does not print noise."* The seam is real and exercised — which is what makes the untested redaction path a short test to write rather than an infrastructure problem, and changed §13 from a complaint into a specification.
