# ADR-047 — Build Flavors Select the Environment

- **Status:** Accepted
- **Date:** 2026-08-18
- **Supersedes:** none. Replaces ADR-007's *mechanism* for selecting an environment while leaving its model — three environments, closed set — untouched.

## Context

ADR-007 selects the environment with `--dart-define=APP_ENV`, and that worked for as long as everything downstream of the choice was derived **in Dart**. Base URL, bucket name, log level and feature flags are all computed from `AppConfig.environment`, so one input decided all of them.

Mission 6.4 split Firebase into three projects, and native configuration is not derived in Dart. `google-services.json` is read by the `com.google.gms.google-services` Gradle plugin, and `GoogleService-Info.plist` by the iOS build. **Both are consumed before any Dart code exists**, so `--dart-define` cannot reach them. Volume 7 Chapter 7.7 §2 step 5 already assumed the answer — it places the file in `android/app/src/{flavor}/` — and Chapter 7.11 §2 says flavors are *"configured in android/app/build.gradle and iOS's scheme configuration, each pointing at the matching Firebase project"*. The project had no flavors.

So the choice was not "flavors or dart-defines". It was: adopt flavors, and then decide whether `APP_ENV` continues to exist **beside** them.

## Decision

**Gradle product flavors `dev`, `staging` and `prod` are the environment selector, and `APP_ENV` is derived from the flavor rather than passed alongside it.**

```shell
flutter run   --flavor dev
flutter build appbundle --flavor prod
```

One flag. It selects four things that must agree, and they cannot be selected separately:

| What | How the flavor reaches it |
|---|---|
| Firebase project | Gradle reads `android/app/src/{flavor}/google-services.json` |
| Application ID | `applicationIdSuffix` — `.dev`, `.staging`, none for prod |
| Launcher name | `src/{flavor}/res/values/strings.xml` |
| `AppConfig.environment` | Flutter defines `FLUTTER_APP_FLAVOR`; `appFlavor` reads it |

### The second selector is the thing being removed

Option A — flavors *plus* `--dart-define=APP_ENV` — was rejected, and the reason is ADR-007's own. ADR-007 refused to let the base URL live in a `.env` file beside `AppEnvironment` because *"it creates a second source of truth for a value ADR-007 assigns to `NetworkConfig`, and the failure mode is a build pointed at the wrong environment."*

Two selectors reproduce that defect exactly, one level up. `--flavor prod --dart-define=APP_ENV=staging` is a build whose Firebase project, application ID and API base URL disagree, it compiles, it installs, and nothing reports it. The only way to make that unrepresentable is to have one input.

### `appFlavor` is Flutter's own constant, not a convention

```dart
const String? appFlavor = String.fromEnvironment('FLUTTER_APP_FLAVOR') != ''
    ? String.fromEnvironment('FLUTTER_APP_FLAVOR')
    : null;
```

The Flutter tool defines `FLUTTER_APP_FLAVOR` from `--flavor`. It is a **compile-time constant**, so ADR-007's central guarantee survives intact: the environment is baked into the binary and nothing on the device can change it. A `switch` would read better than the conditional chain in `app_config.dart` and would not be const-evaluable, which is the whole reason the chain is written that way.

### The flavor names are the `AppEnvironment.slug` values, deliberately

`dev` / `staging` / `prod` already existed on the enum as the AWS resource suffixes fixed by ADR-011. Naming the flavors after them means the Gradle string and the Dart string are the same string, so there is no mapping table to drift. This is why the flavors are not called `development` / `production`.

### `APP_ENV` survives as a fallback, for builds that have no flavor

`flutter test` runs without a flavor, so `appFlavor` is null there. The fallback keeps those builds working and keeps every existing test valid. It is **not** a second way to select an environment for a real build: a flavor always wins when present, and the fallback is only consulted when there is none.

### An unrecognised flavor is reported at the selector

`AppConfig.environmentWasRecognised` tests the **flavor**, not the resolved value. `--flavor prd` falls back to development, so testing the resolved value would report the typo as recognised — the fallback would conceal precisely the mistake the flag exists to surface. ADR-007 required the fallback to be visible; this keeps it visible now that the input has changed.

### Per-environment application IDs

`com.vump.humanarchive` is the base. `dev` and `staging` take suffixes; production is the bare identifier, so a shipped build never carries an environment marker. The suffixes let all three install on one device at once, which is what makes comparing a staging build against a production one a matter of opening two icons.

## Alternatives Considered

- **Option A — flavors plus an independent `--dart-define=APP_ENV`.** Rejected above: two selectors that can disagree.
- **Option B — a pre-build script that copies the right `google-services.json` and emits the matching define.** Rejected. It keeps one selector but moves correctness into a step that can be skipped, and a build run without it is silently the previous environment. It also has no answer for iOS, where the plist is wired into the Xcode project rather than copied.
- **Keeping one Firebase project and one config file.** Rejected — that is the state Mission 6.4 exists to end. It made development auth users and production auth users the same records.
- **`--dart-define` alone, with runtime selection of Firebase options.** Rejected because it cannot work: the native SDKs read their configuration before Dart runs, and on Android the Gradle plugin has already compiled the values into resources.
- **Flavor-per-*build-type* instead of a flavor dimension.** Rejected. Debug/release is an orthogonal axis and is already used; overloading it would make "staging release" inexpressible.

## Consequences

- **`--flavor` is now required for any real build.** A bare `flutter run` gets the fallback and the development default, and installs no Firebase configuration of its own — the Gradle plugin has no non-flavor `google-services.json` to read any more. This is a change to how everyone builds, and it is the cost of the guarantee.
- **Three application IDs exist**, so three installs can coexist. Anything that assumed one package name per device — a script, a CI artefact name, an `adb` invocation — has to say which.
- **The Kotlin source package moved** from `com.example.mobile` to `com.vump.humanarchive`, and the `namespace` with it. That is unrelated to flavors but could not be deferred: the template identifier was also the Firebase Android app's package name, and it had to become real before three projects were registered against it.
- **`resValues` is not used.** AGP 9 disables that build feature by default, so the launcher name comes from a per-flavor `strings.xml` instead. The idiom matches how `google-services.json` is already selected, and it avoids switching a build feature on to name an application.
- **iOS is configured but unverified.** The three plists are downloaded to `ios/config/{flavor}/`, and nothing wires them into Xcode schemes, because there is no Mac and no Apple Developer account. See below.
- **`firebase_options.dart` became three files and a selector.** The single generated file named one project; three generated files each declare `DefaultFirebaseOptions`, so they are imported under prefixes and chosen by `AppConfig.environment`.

## iOS: registered, not wired, not verifiable

The bundle identifiers are registered in all three Firebase projects and the plists are in the repository. **Nothing consumes them**, because wiring a plist per configuration requires editing the Xcode project, and Chapter 7.1 §4 puts iOS builds on a cloud Mac this machine does not have. There is also no Apple Developer account, so the identifiers are strings in Firebase rather than real App IDs.

This is stated rather than hidden because it matches how iOS has been carried since Mission 0.15: registered, plausible, and never executed. The iOS half of this ADR is a decision recorded in advance of the ability to test it.

## Related Missions

- Mission 6.4 — the Firebase split, which needed this and produced it.

## Implementation Status

**Implemented for Android, verified on hardware.**

| | Decision | State |
|---|---|---|
| Gradle flavors `dev`/`staging`/`prod` | Required | ✅ `flavorDimensions("environment")` |
| Per-flavor `google-services.json` | Required | ✅ 3 files, verified project IDs |
| Application ID suffixes | Required | ✅ `.dev`, `.staging`, bare |
| Per-flavor launcher name | Required | ✅ 3 `strings.xml` |
| `APP_ENV` derived from flavor | Required | ✅ `appFlavor` |
| No independent `--dart-define=APP_ENV` | Required | ✅ Nothing passes it |
| Unrecognised flavor reported | ADR-007 | ✅ Checked at the flavor |
| Namespace / package renamed | Required | ✅ `com.vump.humanarchive` |
| `flutter analyze` / `flutter test` | Required | ✅ clean / 1038 passing |
| **Live on device** | — | ✅ **CPH2707: `Firebase initialised for Development (project "vump-platform-f86af")`**, and a real sign-in against it |
| iOS schemes | Required by Ch 7.11 §2 | ❌ **Not wired.** No Mac, no Apple account |
| Verified for staging/prod flavors on device | — | ⬜ Only `dev` was installed |
| **Real sign-in through the dev flavor** | — | ✅ **CPH2707, live**: authenticated against `vump-platform-f86af`, landed on the Dashboard, session survived a cold restart |
