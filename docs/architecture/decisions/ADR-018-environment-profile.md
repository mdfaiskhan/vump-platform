# ADR-018 — Environment Profile as the Single Read Surface

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Extends ADR-007's ownership split.

## Context

By Mission 0.17.17 the environment model was correct but scattered. Six things vary per environment, and each was reached differently: the API base URL and bucket through `NetworkConfig`, the logging level through `AppLogger`, feature flags through `AppFeatureFlags`, the Firebase project through `DefaultFirebaseOptions`, and the CloudFront domain nowhere at all.

Nothing was duplicated, and every value had exactly one owner — ADR-007's split was holding. But a caller wanting to know "what does staging look like?" had to know five modules, and a reviewer asking "is anything missing for staging?" had no place to look.

That absence has a specific cost. A value added for one environment and forgotten for another produces no compile error when it lives in five separate places. The gap surfaces at runtime, in the environment nobody exercised.

The obvious fix is also the dangerous one. A configuration object holding the URL, the bucket and the log level for each environment would be a single place to read — and a **second definition** of every value it holds. It would compile, pass tests, and disagree with `NetworkConfig` the first time someone edited one of the two. That is precisely the duplication ADR-007 and ADR-016 exist to prevent.

## Decision

**`EnvironmentProfile` is the canonical way to read environment-varying configuration, and it defines nothing.**

Every member delegates to the module that owns the value:

| Exposed | Owner | Authority |
|---|---|---|
| `apiBaseUrl` | `NetworkConfig.baseUrlFor` | ADR-007 |
| `chunkBucket` | `NetworkConfig.chunkBucketFor` | ADR-011 |
| `cloudFrontDomain` | not provisioned — null | ADR-011 |
| `firebaseProjectId` | `DefaultFirebaseOptions` | ADR-010 |
| `logLevel` | `AppLogger.minimumLevelFor` | ADR-016 |
| `featureFlags` | `AppFeatureFlags.forEnvironment` | ADR-017 |

**Adding a value to the profile must never mean typing a literal.** If a value has no owner, give it one and delegate. A profile member containing a hardcoded string is a defect, not a shortcut.

Ownership is unchanged. ADR-007 still governs *where a value is defined*; this record governs *how it is read*. The two are different questions and the earlier answer stands.

### Placement

`lib/core/environment/`. It must read from `core/network/`, and ADR-007 states plainly that `app/config/` may not — so `app/config/` is closed to it. `core/` is the right home by ADR-002, and `core/` modules already read `AppConfig.environment` (network, logging, database, firebase all do), so the dependency direction is established precedent rather than a new one.

### Enforcement

Delegation is a property that can be silently broken, so it is tested rather than trusted. For every environment, each profile member is asserted equal to its owner's output. A future copy-paste into the profile fails those tests immediately.

A separate CI job checks the same agreement across languages — Dart, `environments.json` and `env.sh` — because no compiler spans that boundary.

## Alternatives Considered

- **A configuration object holding the values directly** — rejected, and it is the alternative that matters. It reads better and creates a second source of truth for six values. The failure mode is silent divergence discovered in production.
- **Leave the values scattered** — rejected. Correct but unreviewable: nothing shows whether an environment is fully specified, and additions are forgotten per environment rather than per value.
- **A generated profile, built from `environments.json` at build time** — rejected for now. It would give one machine-readable source across Dart and infrastructure, which is genuinely attractive, but it needs a code-generation step on a toolchain already pinned to a 2023-era analyzer by `isar_generator` (ADR-009). The CI consistency check buys most of the benefit for none of that cost. Worth revisiting if the toolchain is unpinned.
- **Put the profile in `app/config/`** — rejected. ADR-007 forbids `app/config/` importing from `core/network/`, and inverting that rule to suit one class would undo a deliberate dependency direction.
- **Expose a fabricated per-environment Firebase project** — rejected outright. Only one project exists; inventing `vump-platform-staging` in code would produce configuration that resolves to nothing.

## Consequences

- One place answers "what does this environment look like", and one place shows when an environment is under-specified.
- Duplication remains structurally impossible: the profile has no storage of its own.
- Startup logging is a single `describe()` call rather than five lookups.
- The profile is a dependency hub — it imports network, logging, firebase and config. That is acceptable for a read surface and would not be for a definition site.
- `firebaseProjectId` touches platform channels, so it is a getter and is excluded from `describe()`. Reading it before Firebase initialises will throw.
- **The profile makes an existing gap visible rather than fixing it**: all three environments return the same Firebase project, because only one exists. Production analytics, crash reports and auth users are currently indistinguishable from development ones. Closing it requires `flutterfire configure` against two further projects.
- Adding a seventh environment-varying value now has two steps — define it in an owner, expose it here — and forgetting the second leaves it reachable but undiscoverable.

## Related Missions

- Mission 0.17.17 — Environment Configuration, which produced this ADR.

## Implementation Status

**Implemented.**

`mobile/lib/core/environment/environment_profile.dart` exposes all six values. `main.dart` reads it for startup logging. Delegation is asserted by test for every member across all three environments, and cross-language agreement is enforced by the `environment-consistency` CI job.

The Firebase project gap is real and unresolved. Everything else resolves distinctly per environment, verified by tests asserting that no two environments share an endpoint or a bucket.
