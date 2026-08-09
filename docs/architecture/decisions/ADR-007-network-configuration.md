# ADR-007 — Network Configuration and Environment Selection

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** ADR-006 in part — its networking assumptions only. ADR-006 remains Accepted and binding in every other respect.

## Context

ADR-006 established `app/config/` as the home for application configuration and recorded that `AppEnvironment` "carries environment identity only, holding no endpoints, keys or credentials." At the time this was correct: no networking existed, and keeping endpoints out of a freshly created configuration layer was the conservative choice.

Mission 0.11 required a Dio client to read a base URL from that layer. The requirement could not be satisfied. There was no endpoint in `app/config/`, and ADR-006 forbade adding one. The mission halted before any code was written.

That halt exposed a question ADR-006 never answered: **who owns an endpoint?** ADR-006 treated all configuration as one concern with one home. It is not. The application's name and version describe *what the application is* — they are true of the product regardless of where it is deployed. A base URL and a timeout describe *what the application talks to* — they are properties of infrastructure and change per deployment while the product stays the same.

A second question was left open by ADR-006 and is now unavoidable. It deferred build-time environment selection, noting that "how the value is supplied and validated is an architectural change and needs its own ADR." `AppConfig.environment` is consequently hardcoded to `development`. Introducing per-environment endpoints without resolving this would compile a single URL into every build, including production. The two decisions cannot be taken separately.

## Decision

### Supported environments

The application supports exactly three environments:

| Environment | Purpose |
|---|---|
| `development` | Local development. The default. |
| `staging` | Pre-production verification. |
| `production` | Live, user-facing builds. |

The set is closed. Adding a fourth is an architectural change requiring a new ADR.

### Ownership is split by concern

**`app/config/` owns application identity** — what the application *is*:

- Application name
- Version and build
- Environment identity (which environment this build targets)
- Flavor

**`core/network/` owns network configuration** — what the application *talks to*:

- Base URL
- Timeout values (connect, receive, send)
- Retry policy
- API configuration (default headers, content type, response type)

The rationale is dependency direction, not filing convenience. Network endpoints are infrastructure. ADR-002 designates `core/` as "cross-cutting infrastructure shared by all features", and a base URL is infrastructure by the same reasoning that puts the HTTP client there. Placing endpoints in `app/config/` would make application identity depend on deployment topology, so that adding a new backend service would edit the file that declares the product's name.

`core/network/` may read `AppConfig.environment` to select its values. The dependency runs one way: **network configuration depends on environment identity; environment identity never depends on network configuration.** `app/config/` must not import from `core/network/`.

### Secrets never belong in source code

Anything committed to the repository is public to everyone with repository access, is preserved in history after deletion, and is shipped inside the application bundle where it can be extracted. No access control applied later changes this.

**Forbidden in source code, without exception:**

- API keys
- AWS credentials — access key IDs, secret access keys, session tokens
- Firebase secrets — service account keys, server keys, admin credentials
- Access tokens
- Refresh tokens
- Signing keys, certificates and private keys of any kind
- Database passwords and connection strings containing credentials

**Permitted in source code:**

- Base URLs
- Timeout values
- Retry counts and backoff parameters
- Non-secret headers such as content type and API version
- Feature flag defaults

The distinction is disclosure consequence, not sensitivity. A base URL is discoverable by anyone who inspects the application's traffic; committing it reveals nothing that running the app does not. A key grants capability, and committing it grants that capability to every reader.

Secrets are obtained at runtime from a secure source — the platform keystore, an authenticated secrets service, or a token exchange. Selecting that mechanism is a future decision requiring its own ADR. Until it is taken, no feature requiring a secret may ship.

Tokens acquired at runtime are held in secure storage and never written to logs. This binds the logging layer as much as the network layer.

### Environments are selected with `--dart-define`

The active environment is supplied at build time:

```
flutter run  --dart-define=APP_ENV=development
flutter build appbundle --dart-define=APP_ENV=staging
flutter build appbundle --dart-define=APP_ENV=production
```

`development` is the default when `APP_ENV` is absent or unrecognised. An undeclared build is a developer's machine; defaulting to production would aim an unverified build at live infrastructure. This preserves ADR-006's reasoning while replacing its hardcoded constant.

An unrecognised value falls back to `development` rather than failing the build, and the fallback must be logged. A silent fallback and a hard failure are both worse: the first hides a typo in a release pipeline, the second breaks builds over a value that has a safe default.

`--dart-define` is a compile-time constant, so the resolved environment remains `const` and is available before `runApp` — preserving the property ADR-006 valued.

## Alternatives Considered

- **Keep endpoints in `app/config/`, amending ADR-006's wording only.** Rejected. It resolves the conflict textually while leaving application identity coupled to deployment topology.
- **A `.env` file loaded at runtime.** Rejected. It adds a dependency and an asynchronous load before configuration is available, breaking the `const` guarantee. It also invites secrets into a file that is trivially committed by accident.
- **Separate `main_development.dart` / `main_staging.dart` / `main_production.dart` entry points.** Rejected. It duplicates the composition root three times, contradicting ADR-002's rule that `main.dart` has exactly one job.
- **Resolve the environment from `kDebugMode` / `kReleaseMode`.** Rejected. It cannot distinguish staging from production, since both are release builds.
- **Fail the build on an unrecognised `APP_ENV`.** Rejected in favour of logged fallback, as argued above.
- **Leave `AppConfig.environment` hardcoded and defer selection again.** Rejected. Per-environment endpoints without build-time selection would ship one URL to every environment.

## Consequences

- Mission 0.11 is unblocked. Its requirement 3 is satisfied by `NetworkConfig` reading `AppConfig.environment`, with no URL hardcoded in the Dio client.
- Configuration has two homes rather than one, and contributors must know which. The rule is a single question: *does this describe the product, or what the product talks to?*
- ADR-006's no-endpoints rule no longer applies to `core/network/`. It continues to apply to `app/config/`, which must still hold no endpoint, key or credential.
- Release pipelines must pass `--dart-define=APP_ENV`. A pipeline that forgets produces a development build silently — mitigated by the required log line, not eliminated. Build configuration should assert the value.
- The three environments are compiled in, so all three base URLs are present in every binary. This is accepted: they are not secrets.
- No feature depending on a secret can ship until the runtime secret-provisioning ADR is taken. This is a deliberate constraint, not an oversight.
- `AppConfig.environment` changes from a hardcoded constant to a `--dart-define` lookup. This is a change to code written under ADR-006 and must be made in `app/config/`, outside the Mission 0.11 network paths.

## Related Missions

- Mission 0.8 — App Configuration Foundation, which created `app/config/` and deferred environment selection.
- Mission 0.11 — Network Foundation, which surfaced the conflict and halted rather than resolve it silently.
- Mission 0.11.1 — Architecture Reconciliation, which produced this record.

## Implementation Status

**Implemented.**

`mobile/lib/core/network/` holds `NetworkConfig`, which derives the base URL and timeouts from `AppEnvironment`.

`--dart-define=APP_ENV` resolution was completed in Mission 0.17.17. `AppConfig.environment` is a compile-time constant resolved from `String.fromEnvironment`, with an unrecognised value falling back to `development` and reporting that fallback through `AppConfig.environmentWasRecognised`, which the composition root logs as ADR-007 requires. Verified against all three environments plus a typo case.

The base URLs remain IANA-reserved `.example` placeholders and must be replaced before any build ships.
