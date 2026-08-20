# ADR-042 — Background Upload Runs in the Main Isolate

- **Status:** Accepted
- **Date:** 2026-08-16
- **Supersedes:** none. Constrained by ADR-040 (one store instance behind four contracts) and ADR-035 (the token inversion).

## Context

Volume 5 Chapter 5.11 §1 requires an Android foreground service that starts when a chunk enters `Uploading`, holds one persistent notification for the whole queue, and stays alive until the queue drains. Volume 3 Chapter 3.1 §2 names the package: *"a foreground service (`flutter_foreground_task`) driving Dio multipart uploads."*

`flutter_foreground_task` 10.0.0 runs its `TaskHandler` in a **separate Dart isolate**, entered through a top-level `@pragma('vm:entry-point')` callback. Traffic across that boundary is `sendDataToTask` / `sendDataToMain`, restricted to primitives, `String` and `Map`/`List`.

The obvious reading of *"a foreground service driving Dio multipart uploads"* is that the upload runs inside the service — that is, in the task isolate. That reading does not survive contact with three decisions already taken.

### 1. ADR-040 requires one `IsarChunkStore` instance, and an isolate cannot share one

ADR-040 put `ChunkQueueSource` in `core/queue/` so `features/upload/` could read rows `features/recording/` writes. Mission 4.2 added `ChunkUploadSource` and `ChunkMetadataSource` in `core/upload/`. `main.dart` binds **one** `IsarChunkStore` behind all four, and says why in as many words: *"the queue must observe exactly the rows the finalizer writes, not a second connection's view of them."*

An upload running in the task isolate needs its own `Isar.open` on the same directory. That is a second connection, and it reopens the exact hazard ADR-040 closed.

### 2. `firebase_auth` does not serve tokens to a background isolate

ADR-035 has `AuthInterceptor` obtain a Firebase ID token through `AuthTokenSource`, satisfied by `features/auth/data/`. The Firebase SDK's instance is bound to the isolate that initialised it. Every authenticated Vump call in Chapter 5.10 §1 — registration, status confirmation, metadata — would have no token in the task isolate.

### 3. The Riverpod graph does not cross either

ADR-003 makes the provider graph this project's only dependency-injection mechanism, and ADR-006 declines a second one. A task isolate would need its own `ProviderContainer` with its own overrides — a second composition root, which is a second place for the wiring to be wrong.

## Decision

### The foreground service keeps the process alive; the main isolate does the work

`UploadDispatcher` lives in `features/upload/application/` and runs in the main isolate. It subscribes to `ChunkQueueSource.watchQueue()`, claims work through Chapter 5.10's pipeline, and asks `UploadServiceHost` to start, update and stop the Android service around the batch.

An Android foreground service keeps its host **process** alive. Keeping the process alive keeps the main isolate alive. That is the entirety of what Chapter 5.11 §3 asks for: *"this chapter only owns keeping the OS from killing the attempt outright while a connection exists."*

The `TaskHandler` is therefore empty, and that is the design rather than an omission. It exists because the plugin will not start a service without one.

### The package is confined to `features/upload/data/`, behind a port

`UploadServiceHost` is declared in `features/upload/domain/repositories/` and implemented by `ForegroundUploadServiceHost` in `data/`. The `Architecture boundaries` CI job gains a **fourteenth** confinement rule pinning `flutter_foreground_task` to that directory.

Owned by a feature rather than by `core/`, on the line ADR-034 drew for Firebase products: an OS capability belongs to the module that consumes it, which is what keeps `features/upload/` the replaceable unit. Verified by deliberate breakage — an injected import in `application/` fails the check, and removing it restores a pass.

### The dispatcher reaches Chapter 5.10 through a function, not a field

`UploadOneChunk` is a typedef, and `uploadDispatcherProvider` supplies `() => ref.read(chunkUploadPipelineProvider).uploadNext()`.

This is not a style preference. `sessionRegistrarProvider` throws until `features/projects_tasks/` exists (open item 36), so *constructing* the pipeline throws. Holding it as a field, or `ref.watch`-ing it in the provider, would move that throw to app startup and turn an unbuilt feature into a launch crash. Behind a function, the seam is touched only when there is a chunk to send, and `UploadDispatcher` converts the throw into a logged stop.

### Starting the service is triggered by an observed `uploading` row, not by a launched runner

§1 says the service starts *"the moment any chunk enters Uploading"*. The dispatcher takes that literally: a row observed in `uploading`, not a runner that has been launched and may yet claim nothing.

The difference is not academic. Starting on a launch would put a notification on screen for the duration of one `claimNext` every time the queue was already empty — and every time the pipeline could not be constructed at all, which is the state of the application today. That is precisely the flicker §1 exists to prevent.

Stopping uses a wider condition: a runner still in flight holds a claimed row even before the queue re-emits, and stopping the service under it would hand the OS permission to kill the transfer.

## Alternatives Considered

- **Run the pipeline in the task isolate.** The literal reading of Volume 3 Ch. 3.1 §2. Rejected on all three counts above; the `firebase_auth` one is fatal on its own, since it is a platform limitation rather than a design choice this project can trade away.

- **Open a second Isar connection in the task isolate and pass results back as maps.** Technically possible — Isar supports multi-isolate access. Rejected: it re-opens ADR-040's single-instance guarantee three commits after it was made, and the serialisation boundary would force `UploadableChunk`, `ChunkMetadataDocument` and `UploadOutcome` through `Map<String, dynamic>` round-trips that nothing else in this codebase needs.

- **Widen the `flutter_foreground_task` confinement to `features/upload/`.** One line of CI, and it would let `UploadDispatcher` call the plugin directly. Rejected for the reason ADR-041 gives about `dio`: the argument that admits `application/` admits the next layer too, and the port costs one small file while making the dispatcher testable without a platform channel. Twenty-two of Mission 4.3's tests depend on that substitution.

- **Use `WorkManager` / `workmanager` instead.** Not considered seriously: Volume 3 Ch. 3.1 §2 names the package, so the choice is transcribed rather than taken. Recorded so nobody re-opens it as if it were open.

- **Toggle `allowWakeLock` per transfer to satisfy §1 literally.** Rejected — see A-079. It is a `ForegroundTaskOptions` field fixed at start, so honouring §1's wording means an `updateService` call around every chunk, re-entering the flicker §1 wants avoided, to save power only during gaps in a queue the dispatcher is actively draining.

## Consequences

- **The upload stops when the process dies.** Unlike a design where the OS owns the transfer, killing the app kills the attempt. Chapter 5.9 §3 already covers the loss: the rows still say `queued`, and a new subscription reads them at next launch. Nothing is lost, and NFR-REL-04 is satisfied by the queue rather than by the service.
- **iOS is untouched and unaddressed.** Chapter 5.11 §2's background `URLSession` is a different mechanism with a different lifecycle, and `UploadServiceHost` describes the Android shape deliberately rather than forcing both through one abstraction. Open item 22 — there is no macOS host, no Xcode and no device to build one against.
- **A fourteenth confinement rule exists**, and open item 41's question was asked of this mission: adding a package wakes a dormant rule, and a rule with no subject passes trivially.
- **`flutter_foreground_task` joins the legacy-KGP list.** The Android build then warned for three plugins — `battery_plus`, `cloud_functions` and `flutter_foreground_task` — where open item 14 named only the first. Builds today; a future Flutter will refuse it. **Since Mission 7.6 Phase 6 it warns for two**: `cloud_functions` left the project with ADR-036's runtime (A-227).
- **The empty `TaskHandler` will look like an oversight to the next reader.** It is documented as deliberate in three places (the class, the entry point, and here) because the reflex fix — moving work into it — is the thing this decision forbids.

## Related Missions

- Mission 4.3 — Background Upload (Android), which produced this decision.
- ADR-040 — the single-instance guarantee that rules out a second Isar connection.
- ADR-035 — the token inversion that does not cross an isolate boundary.
- ADR-041 — the confinement argument this reuses for a fourteenth package.
- A-078, A-079, A-080 — the three values and readings Chapter 5.11 does not supply.

## Implementation Status

| Item | State |
|---|---|
| `UploadServiceHost` port + `ForegroundUploadServiceHost` | Written |
| `UploadDispatcher` — claim loop, concurrency bound, service lifecycle | Written |
| `UploadBatchProgress` — §1's aggregate | Written, 11 tests |
| Android manifest — `FOREGROUND_SERVICE_DATA_SYNC` + `dataSync` service | Written, merged manifest verified |
| CI: `flutter_foreground_task` confined to `features/upload/data/` | Verified against a deliberately broken import |
| Composition root binds the host and starts the dispatcher | `main.dart` |
| Tests | 33 — 22 dispatcher, 11 aggregate |
| Device verification | **Verified** — CPH2707, Android 16 (API 36), via `lib/main_upload_probe.dart` |

## Device verification — CPH2707, Android 16 (API 36)

Recorded because Chapter 5.11 is a chapter about OS behaviour, and no unit test can observe it. Measured through `adb` against the probe target, 2026-08-16.

| §1 / §3 clause | Observed |
|---|---|
| Foreground service, `dataSync` | `isForeground=true`, `foregroundId=5110`, `types=0x00000001` |
| One service per batch, *"not restarted per chunk"* | One service record across a 5-chunk batch; `starts` never repeated |
| Aggregate progress | `Uploading 1 of 5 chunks.` → `3 of 5` → `5 of 5`, denominator steady |
| Chunks arriving mid-batch widen it | `1 of 5` → `3 of 7` → `5 of 7` |
| Concurrency bound of two | Batch drained in ~18 s = ⌈5/2⌉ × 6 s |
| Notification is silent, not interrupting | Grouped under the shade's **Silent** section; `ONLY_ALERT_ONCE` set |
| Survives backgrounding | HOME pressed mid-batch: service alive, text kept advancing |
| Stops when the queue drains | Service record gone and notification cleared, while still backgrounded |

### The dismissibility clause — observed, and deliberately not generalised

§1 wants the notification *"dismissible only once the queue is fully drained"*. **On this device it did not dismiss.** A full-width swipe on the card with the shade open left the notification in place, still counting, with the service still `isForeground=true`.

**This is one device and one OEM skin, and the result must not be read as Chapter 5.11 §1 being satisfied everywhere.** AOSP from Android 14 *permits* the user to dismiss a foreground-service notification regardless of `NO_CLEAR`, which this ColorOS build evidently does not implement. A stock Pixel on the same API level may well behave the opposite way.

No amendment is raised, because nothing was found to diverge. What is recorded instead is the reasoning the code already carries: **dismissibility is not a flag this application can set.** The notification goes away when the service stops, and the dispatcher stops it at exactly §1's two conditions — drained, or every remaining item `failed`. That holds on both sides of the OEM difference, which is why the design does not depend on knowing which one a given device implements.

Worth re-checking on a stock-Android device whenever one is available. It changes nothing about the code if it dismisses; it would only mean §1's wording overstates what any app can guarantee.
