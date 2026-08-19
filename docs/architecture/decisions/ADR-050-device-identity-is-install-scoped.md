# ADR-050 — Device Identity Is Install-Scoped and Self-Minted

- **Status:** Accepted
- **Date:** 2026-08-19
- **Supersedes:** none. Closes a deferral Volume 5 Chapter 5.7 §2 opened and Mission 3 recorded as undecided.

## Context

Volume 4 Chapter 4.4 §7 makes `device_id` and `device_model` part of every chunk's metadata, and Volume 5 Chapter 5.7 §2 says the device identifier is *"cached, stable"*. Neither says what it is.

Mission 3.8 built `ChunkMetadataAssembler` around a `DeviceContext` contract and bound an implementation that returned `MetadataIdentity.unsourced` from every getter, because there was no backend to send anything to and no decision about what to send. A-068's Guard 1 refuses a chunk whose identity is incomplete, so the blank was safe — it made the absence loud rather than letting unattributed footage upload. Mission 7.4 is the first mission where a real value has somewhere to go.

The question is genuinely a decision rather than a lookup, because the platform offers an answer and the answer is wrong.

## Decision

**The device identifier is a version-4 UUID minted by the app on first access and persisted in `shared_preferences`. It is scoped to the install, not to the device.**

```
core/identity/
  device_id_store.dart      the read-or-mint store  (shared_preferences)
  device_model_channel.dart the OS-reported model   (platform channel)
  uuid_v4.dart              the minter, shared with the recording ports
  interfaces/               DeviceContext, TaskContext
```

Both values are resolved once at the composition root and injected into `PlatformDeviceContext`, because `DeviceContext`'s getters are synchronous and both reads are futures. This is the arrangement `appVersion` has had since Mission 3.8, extended rather than invented.

### `ANDROID_ID` was rejected, on two grounds

**It is not stable across the event it most needs to survive.** `Settings.Secure.ANDROID_ID` resets on factory reset, and since Android 8 it is already per-app-signing-key rather than per-device. The property the spec asks for — stability — is exactly what it does not reliably provide, so adopting it would buy the *appearance* of a device-scoped identifier without the guarantee.

**It carries correlation surface the project has no use for.** It is an OS-scoped identifier that outlives the app. This project needs to answer one question — *"did these chunks come from the same install?"* — and a self-minted UUID answers exactly that and nothing else. Collecting an identifier with broader reach than the question requires is the kind of default that is hard to walk back once it is in a column.

**The cost, stated rather than glossed:** reinstalling the app produces a new device id. That is acceptable because nothing treats `device_id` as a key. It is a correlator for grouping and diagnosis; the chunk's identity rests on `chunk_id`, `session_id`, `task_id` and `collector_id`, all of which survive a reinstall because none of them is local.

### `shared_preferences`, not `flutter_secure_storage`

ADR-008 scopes secure storage to **secrets** — *"Secrets are persisted through `flutter_secure_storage` and through nothing else"* — and names JWT tokens and key material. A device id is not a secret: it travels in plaintext metadata to a backend that stores it in an unencrypted column. Putting it in the Keychain would misread ADR-008's scope rather than add safety, and would imply a confidentiality property the value does not have anywhere else in its life.

`shared_preferences` already holds two small non-secret values on this precedent (`OnboardingSeenStore`, `WideAngleEligibilityCache`).

### `device_model` comes from a platform channel, not a package

`device_info_plus` would surface dozens of fields across both platforms and carry ADR-030's full admission — confinement entry, inventory row, conversion boundary — to read two `Build` constants. `FreeSpaceChannel` set the precedent for exactly this trade in Mission 3, and it applies more strongly here because the surface being bought is larger and the need is smaller.

The channel reports `manufacturer model`, because `Build.MODEL` alone is `CPH2707`, which identifies nothing to a human reading A-08's metadata screen.

**One deliberate difference from `FreeSpaceChannel`: a failed read returns `null` rather than throwing.** Free space gates whether recording may start, so an unanswerable question must stop the flow. A device model is descriptive metadata, and throwing would fail a chunk over a label. The null becomes `MetadataIdentity.unsourced`, which A-068's Guard 1 then refuses — the chunk is still stopped, but by the guard that exists for it rather than by an exception from a metadata read.

## Consequences

**`core/identity/` acquires a `shared_preferences` grant, per-file.** The module also holds a platform channel and two contracts, none of which has business reaching a key-value store, so the CI rule names `device_id_store.dart` specifically rather than the directory. This is the fifth owner of that package and the fourth one granted as a single file.

**The empty string stays reserved.** `MetadataIdentity.unsourced` is `''`, so both the store and the channel treat a blank as absent rather than as a value. A blank that survived either read would present "no id" as sourced and slip past the guard that exists to catch it.

**`collector_id` is not covered by this ADR.** It is not a device property — it comes from `features/auth/`, and ADR-022 R3 forbids `features/recording/` from importing it in either direction. The composition root supplies it by watching the auth notifier, which is R3's first resolution applied to a value rather than to a type.

**What is still unproven:** stability across a real process death and a real reinstall, and the Kotlin half's output on hardware, are device checks. They are on Mission 7.4's step 5 checkpoint. The unit tests prove the read-before-write logic and the Dart side of the channel contract, and nothing more than that.
