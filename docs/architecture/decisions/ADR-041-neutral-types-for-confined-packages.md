# ADR-041 — Neutral Types for Confined Packages

- **Status:** Accepted
- **Date:** 2026-08-15
- **Supersedes:** none. Third application of the inversion ADR-035 introduced and ADR-040 widened.

## Context

ADR-030 confines each third-party package to the layer that owns it, and the `Architecture boundaries` CI job enforces thirteen such rules. `dio` belongs to `core/network/` (ADR-007).

Mission 4.2 built Volume 5 Chapter 5.10's upload pipeline in `features/upload/`, and it is **the first code outside `core/network/` ever to make an HTTP request**. `features/auth/data/` talks to Firebase; Missions 3.1–3.12 made no network calls at all — Mission 3.11's security review confirmed *"no `dio`, no `http`, no socket"*.

That first consumer immediately hit three walls, all the same wall.

### 1. Chapter 5.10 §2 and §4 name Dio types directly

*"Dio's native upload-progress callback … feeds directly into the per-chunk percentage shown on C-11"* and *"Dio's cancellation tokens … allow an in-progress upload to pause cleanly"*. Both cite "ADR-004", which is a Volume-side citation collision — this repository's ADR-004 is GoRouter and the real record is ADR-007 (A-069, open item 34).

A feature naming `ProgressCallback` or `CancelToken` must import `package:dio`.

### 2. `DioClient`'s own signature leaks Dio — and the rule was green only by luck

`DioClient.post` returns `Future<Response<T>>`. `Response` is a Dio type. **Every caller of `DioClient` outside `core/network/` must therefore import `package:dio`**, which the confinement check forbids.

This has been true since Mission 0.10 and was never detected, because nothing outside `core/network/` had ever called `DioClient`. The rule was not holding; it was untested. That is the same shape as S1 (A-067), where a confinement rule sat red for two missions, and as open items 23, 26 and 32 — *"a whole checked in parts"*.

### 3. Widening the confinement was the obvious move, and the wrong one

It is one line of CI. It is also the first crack in a rule that has held for thirteen packages, and the argument that admits `features/upload/data/` admits the next feature too. A-067's lesson is that confinement gaps are invisible until something forces them into view, and this mission is that force.

## Decision

### `core/network/` publishes neutral types; the package stays where ADR-007 put it

| Type | Replaces | Used by |
|---|---|---|
| `TransferProgress` | Dio's `ProgressCallback` | Ch. 5.10 §2's per-chunk percentage |
| `TransferHandle` | Dio's `CancelToken` | Ch. 5.10 §4's pause |
| `VumpApi` | `DioClient`'s `Response<T>` | Every Vump endpoint |

`TransferProgress` is a bare typedef with Dio's own parameter shape — deliberately, because an adapter that reordered or renamed the parameters would be a second thing to get wrong for no gain. What is not Dio's is the *type*: nothing above `core/network/` learns which client produced the numbers.

`TransferHandle` wraps a `CancelToken` and publishes `cancel()` and `isCancelled`. `VumpApi` wraps `DioClient` and returns plain maps.

### This is the same inversion, a third time

- **ADR-035** — `core/network/` declares `AuthTokenSource`; `features/auth/` satisfies it. `core/` ↔ **one feature**.
- **ADR-040** — `core/queue/` holds a contract between two features. **feature ↔ feature**, neither of them `core/`.
- **ADR-041** — `core/network/` publishes a type that stands in for a **third-party** one. Neither party is a feature; the thing being decoupled from is a package.

The move is identical each time: the layer that owns the constraint states the requirement as a type it owns, and nothing outside it learns what is behind it. Recording it a third time is what makes it a pattern rather than three coincidences.

### `DioClient` is not changed

It stays the general-purpose client with its interceptor chain and its no-`DioException`-escapes guarantee. `VumpApi` sits on top and adds the one thing every Vump endpoint has in common: Volume 4 Chapter 4.6 §1's envelope.

Changing `DioClient`'s return type would touch the verified request path to serve a caller it does not need to know about — the same reasoning that kept `AuthInterceptor` untouched when the S3 upload needed to bypass it.

### `@internal` is not available, and CI carries the guarantee instead

`TransferHandle.token` exposes the wrapped `CancelToken` because `S3TransferClient` needs it. Dart has no package-private, and `@internal` is only valid inside a package's private API — a `src/` directory this project does not use.

The confinement check enforces what the annotation would have: a caller outside `core/network/` cannot *use* that value without naming `CancelToken`, which means importing `package:dio`, which fails CI. The guarantee is the same; it is checked in CI rather than by the analyzer.

## Two things this surfaced that were not the point

### `VumpApi` recovers the backend's named error, which a plain client loses

`ErrorInterceptor` converts a 400 into `NETWORK_BAD_REQUEST: Server returned 400 for POST …` before anything reads the body. Correct for a general-purpose client — it knows nothing about envelopes — and wrong for this API, because Chapter 4.6 §1 requires errors *"always carry a specific code, never a bare HTTP status alone, mirroring Chapter 2.9's named-cause-and-fix rule at the API layer"*, and Chapter 2.9 §2 treats a generic failure message as a defect rather than a fallback.

Found by a Mission 4.2 test that scripted a `CHUNK_ALREADY_REGISTERED` refusal and got back a bare 400. `VumpApi._named` reads the envelope back off the failure's cause. `ErrorInterceptor` is untouched.

### The confinement check matched text, not imports

`check()` grepped for the bare string `package:dio` anywhere in a file. Mission 4.2 tripped it twice in one sweep — on two files whose **doc comments stated that they deliberately do not import the confined package**. A rule that fails on a true statement about itself teaches people to stop writing the statement.

It now matches `import`/`export` directives. No coverage is lost: a package can only be used by importing it, and `export` is checked so a re-export cannot smuggle one across. Verified by deliberate breakage — an injected `import 'package:dio/dio.dart';` in `features/upload/data/` still fails.

## Alternatives Considered

- **Widen `dio`'s confinement to `features/upload/data/`.** Rejected for the reason under Context 3. One line now, an unbounded precedent later, and A-067's lesson is that a widened rule is invisible until it matters.
- **Change `DioClient` to return decoded bodies.** Rejected. It edits the verified request path and removes a capability — streamed responses, downloads — from a client whose whole job is to be general.
- **Re-export Dio's types from `core/network/`.** Rejected outright. It satisfies a naive checker while leaving every consumer bound to Dio's API, which is compliance without the property the rule protects — the same objection ADR-040 raised against passing `LocalChunk` through a contract.
- **Put `VumpApi` in `features/upload/data/`.** Rejected. Chapter 4.6 §1's envelope is a property of the whole API, not of one feature, and the second feature to call the backend would either duplicate it or import a sibling.
- **A `shared/` module.** Rejected. ADR-022 R5 admits nothing to it without a second consumer, and `core/network/` is where ADR-007 already put network concerns.

## Consequences

- **`dio` is confined for the first time under real pressure.** The rule was previously green by absence; it is now green with a feature actively making HTTP requests through it.
- **A third module publishes stand-in types**, and each must stay free of the thing it stands in for. `TransferHandle` leaking `CancelToken` into a feature would be the coupling it was built to remove — the same hazard ADR-040 named for `core/queue/`.
- **A small duplication is accepted.** `features/upload/domain/` declares its own `ChunkUploadProgress`, identical in shape to `TransferProgress`, because ADR-022 forbids `domain/` importing `core/` and that rule is worth more than deduplicating one typedef. `data/` bridges the two.
- **Cancellation crosses `domain/` as a bare `Future<void>`.** Completing means stop. No type, no import, and `data/` wires it to a `TransferHandle` in one line.
- **`core/upload/` joins `core/queue/` in the names-no-feature check**, which is now a loop over a list rather than two copies of one block.
- **This pattern will recur** wherever a feature needs a confined package's concept: a background-work handle for Chapter 5.11, a connectivity signal for Chapter 5.12. The shape is established.

## Related Missions

- Mission 4.2 — Upload Pipeline, which produced this decision.
- ADR-035 — `core/` ↔ one feature, the first instance.
- ADR-040 — feature ↔ feature, the second.
- ADR-007 — where `dio` was confined, and what it does and does not cover.
- A-067 — the confinement gap that argued for enforcing rules in CI rather than in prose.
- A-069, open item 34 — why Chapter 5.10 §2/§4's "ADR-004" is not this repository's.

## Implementation Status

| Item | State |
|---|---|
| `core/network/transfer_progress.dart` | Written, 100% covered |
| `core/network/transfer_handle.dart` | Written, 100% covered |
| `core/network/vump_api.dart` | Written, 100% covered |
| `features/upload/data/` imports no `package:dio` | Verified by deliberate breakage |
| CI: `core/upload/` names no feature | Verified by deliberate breakage |
| CI: confinement matches directives, not text | Verified by deliberate breakage |
| `DioClient`, `AuthInterceptor`, `ErrorInterceptor` | Unchanged |
