# ADR-008 — Secure Storage for Secrets

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none

## Context

ADR-007 forbids secrets in source code and states that they "are obtained at runtime from a secure source," leaving the mechanism to a later decision. That decision is now due: authentication is the next substantial feature, and a session cannot survive an app restart without persisting a token somewhere.

Flutter offers several persistence options and only one of them is secure. `SharedPreferences` writes to a plist on iOS and an XML file on Android — plain text, readable by anyone with filesystem access, trivially extracted from a rooted or jailbroken device and from an unencrypted backup. A local database is no better by default: records are stored unencrypted unless encryption is configured explicitly, and configuring it raises the same question one level down, namely where the encryption key lives.

The failure mode is not theoretical. Persisting a refresh token in `SharedPreferences` is one of the most common credential leaks in mobile applications, and it happens because the convenient API and the secure API look equally reasonable at the call site. The decision has to be taken before the first token is written, because a secret stored insecurely is compromised from the moment it is written, and moving it later does not un-leak it.

A second problem is coupling. If features call a storage package directly, every feature becomes a place where a key name can be misspelled, a secret can be written to the wrong store, and the storage backend becomes impossible to replace.

## Decision

### `flutter_secure_storage` is the only secure storage solution

Secrets are persisted through `flutter_secure_storage` and through nothing else. It delegates to the platform's own credential store — the Keychain on iOS and macOS, `EncryptedSharedPreferences` backed by the Keystore on Android — so key material is protected by the operating system rather than by application code.

No second secure storage package is introduced.

### All secrets are stored only through Secure Storage

The following must never be written anywhere else:

- JWT access tokens
- Refresh tokens
- Device and push notification tokens
- API secrets and keys obtained at runtime
- Session identifiers that grant access
- Encryption keys for any other store
- Passwords, PINs and passphrases, if ever held at all

The test for whether a value is a secret is capability, not sensitivity: **if possessing the value lets someone act as the user or as the application, it is a secret.**

### `SharedPreferences` is forbidden for secrets

No secret is written to `SharedPreferences`, to a local database, to a file, to a log, or to any analytics or crash-reporting payload. `SharedPreferences` remains acceptable for non-secret user preferences — theme choice, onboarding completion, sort order — and for nothing else.

Per ADR-007, secrets are equally forbidden from logs. The logging layer redacts credential-bearing headers, but that is a safety net, not permission to pass a secret to a log call.

### Secure Storage is abstracted behind a service

Access is mediated by an abstraction in `core/storage/`, placed there because ADR-002 designates `core/` for cross-cutting infrastructure. The abstraction consists of:

- An **interface** declaring the operations the application needs — read, write, delete, clear — in the application's own vocabulary.
- An **implementation** that adapts `flutter_secure_storage` to that interface, and is the only file in the codebase importing the package.
- A **key registry**: storage keys are declared as constants in one place, never as string literals at call sites.
- Exposure through **Riverpod**, per ADR-003, so the implementation is overridable in tests without any call site changing.

Platform failures are converted at this boundary into `StorageException` from the Mission 0.10 taxonomy. A `PlatformException` must not escape `core/storage/`, exactly as a `DioException` must not escape `core/network/`.

### UI and features never touch `flutter_secure_storage` directly

No file under `lib/features/`, `lib/app/` or `lib/shared/` may import `flutter_secure_storage`. Any such import is a defect.

### Future authentication depends only on the abstraction

The authentication feature depends on the interface, never on the package or on its implementation. Per ADR-001, the dependency points inward: the `domain` layer declares what it needs of storage, and `core/storage/` satisfies it.

This is what makes the backend replaceable. Moving to a different credential store, or to a hardware-backed key, becomes a change to one implementation file rather than to every call site holding a token.

## Alternatives Considered

- **`SharedPreferences`** — rejected. Plain text on both platforms. Suitable for preferences, never for credentials.
- **A local database (Isar) with an encryption key** — rejected for secrets. It moves the problem rather than solving it: the encryption key is itself a secret needing secure storage. The correct arrangement is the inverse — hold the database key in Secure Storage — which this decision permits.
- **Hive with `AesCipher`** — rejected for the same reason, with the added cost of a second storage dependency.
- **Hand-rolled platform channels to Keychain and Keystore** — rejected. It reimplements a maintained package and puts the correctness of credential handling on this team, in exchange for nothing.
- **In-memory only, re-authenticating on every launch** — rejected. It is genuinely more secure and unacceptable as a product experience; it also does not survive backgrounding on either platform.
- **Storing secrets in the backend session only, with a cookie** — rejected. It does not remove the need to persist the cookie, and cookie storage on mobile is less protected than the Keychain.

## Consequences

- Credentials are protected by the operating system's credential store rather than by application code, and are excluded from unencrypted device backups.
- The storage backend is replaceable, because exactly one file imports the package.
- Secure storage is **asynchronous** on both platforms. Any code reading a token must be async, which affects application startup: the session cannot be known synchronously before `runApp`, so the router needs a loading state while the token is read. This is a real constraint on the authentication mission.
- Secure storage is **slower** than a plain preferences read — a Keychain round trip is measured in milliseconds, not microseconds. Values read repeatedly during a session should be held in memory by the service rather than re-read per request.
- Android's `EncryptedSharedPreferences` requires **minSdk 23**. The Android configuration must be verified before the first secret is written.
- **iOS Keychain entries survive application uninstall.** A reinstalled app can therefore find a stale token belonging to a previous installation. The service must clear storage on first run after install, tracked by a non-secret flag in ordinary preferences.
- Tests cannot reach the platform stores, so the interface must be substitutable by an in-memory fake. This is a direct benefit of the abstraction and a requirement on its design.
- Every new secret requires a registered key constant, which is marginally more ceremony than a string literal, and is the point.
- This ADR governs secrets **at rest on the device**. It does not decide how build-time secrets such as third-party API keys reach the device in the first place; ADR-007's prohibition on those in source code stands, and provisioning them remains an open decision.

## Related Missions

- Mission 0.6.1 — Dependency Management, which added `flutter_secure_storage: ^9.2.2`.
- Mission 0.10 — Error Architecture, which defined the `StorageException` and storage error codes this layer maps onto.
- Mission 0.11.1 — Architecture Reconciliation, whose ADR-007 deferred the secret mechanism to this record.
- Mission 0.13 — Secure Storage Foundation, which produced this ADR.

## Implementation Status

**Not implemented.** This ADR is a decision, not a description.

`flutter_secure_storage: ^9.2.2` is declared in `pubspec.yaml` and is unused. `lib/core/storage/` does not exist, no abstraction has been written, and no secret is persisted anywhere in the application.

`shared_preferences` is not currently a dependency, so the prohibition against using it for secrets is forward-looking rather than corrective.

The Android `minSdk` and the iOS first-run clearing behaviour described above are unverified.
