# ADR-052 — The Dispatcher Reconciles Stranded `uploading` Rows at Startup

- **Status:** Accepted
- **Date:** 2026-08-23
- **Supersedes:** none. Reverses a documented design position stated in `ChunkQueueSource`'s interface comment and repeated in `UploadDispatcher.start`, and corrects the premise Volume 5 Chapter 5.9 §3 rests it on. Closes the mechanism half of open item 137.

## Context

A chunk interrupted mid-upload is stranded at `uploading` permanently. It never retries, never fails, never recovers, and the UI reports it as still uploading. Open item 137 records the field evidence; this ADR records why the code does it and what changes.

### The four states, and the three ways out of `uploading`

`ChunkUploadStatus` defines exactly four states — `queued`, `uploading`, `failed`, `complete`. `IsarChunkStore` writes a status in five places, and only three of them leave `uploading`:

- `deferAttempt` — `uploading` → `queued` behind a backoff deadline
- `_transition` — `uploading` → `failed` or `complete`
- `claimNext` — `queued` → `uploading`
- `requeue` — `failed` → `queued`

**All three exits from `uploading` are in-process calls made by the running pipeline.** When the process dies mid-transfer, none of them ever runs. The row keeps the value `claimNext` wrote and nothing is left alive to change it.

### And nothing selects that row again

`claimNext` filters `statusEqualTo(ChunkUploadStatus.queued.wireName)`. A row at `uploading` is not a candidate. So the stranded row is invisible to the only mechanism that could move it.

The manual escape is closed too. `requeue` opens with:

```dart
if (row == null || row.status != ChunkUploadStatus.failed.wireName) {
  return;
}
```

and the interface states that as deliberate — *"Ignores a chunk that is not currently `failed`. A retry racing the dispatcher must not drag an `uploading` chunk backwards."* Chapter 2.7's C-11 gates its Retry Chunk button on `failed` for the same reason, so the button never renders for a stranded chunk. **There is no path back from `uploading`, by construction.**

### The premise this rests on is false

`ChunkQueueSource`'s interface comment states the position outright:

> *"So there is no re-queue step at launch and no separate recovery pass. The rows already say what they are; a new subscription reads them."*

`UploadDispatcher.start` repeats it, citing Chapter 5.9 §3:

> *"the queue's actual state was never only in memory to begin with. On relaunch, the queue simply resumes reading the same rows."*

**Half of that is true and the half that is false is the defect.** The rows do survive the kill — Isar persisted them, and nothing was lost. But *surviving* is not *resumable*. A row reading `uploading` describes a transfer that no longer exists, and "the rows already say what they are" is exactly wrong for the one row the kill touched: it says `uploading`, and that is untrue the instant the process dies.

Chapter 5.9 §3 offers this reasoning as what *"satisfies NFR-REL-04 directly: an app kill loses nothing"*. **NFR-REL-04 is therefore violated in precisely the scenario it names**, and the reasoning that was supposed to guarantee it is what prevents the recovery.

`shutDown` names the same failure from the other side, and treats it as a hazard to avoid:

> *"Chunks already in flight are left to finish — they hold claimed rows, and abandoning them here would strand those rows in `uploading` with nothing left to release them."*

The code already knew what stranding meant. What it did not have was anything to clear a row that got stranded anyway.

### Why this is safe to fix at startup and nowhere else

Deciding whether a row at `uploading` is genuinely transferring is impossible from inside a running app. Live transfer progress lives in `UploadProgressNotifier`, which is in-memory only and `build()`s empty; and `ChunkUploadProgressSnapshot.fraction` is null both when no transfer exists and when Dio reports `totalBytes` as `-1` for a stream it cannot measure. Neither signal distinguishes stalled from healthy.

**At process launch the question does not arise.** The Android foreground service declares no `android:process`, so it runs in the main process; the only isolate in the codebase hashes video for recording. Android will not run two instances of one app process, and a force-stop takes the service down with everything else. **A freshly launched process therefore has no in-flight transfer, and no row at `uploading` can be live.**

That safety is conditional on *when* reconciliation runs, and the condition currently holds: `start()` is called exactly once, from `main.dart`'s `_startUploadDispatcher`, and is idempotent (`if (_subscription != null || _shutDown) return`), with `_shutDown` a one-way latch that no code clears.

## Decision

**When the dispatcher starts, every row at `uploading` is reconciled before any claim.**

Each such row has its `uploadAttemptCount` incremented, then:

- if attempts remain under Chapter 5.13 §2's budget, it becomes `queued` with `nextAttemptAt` cleared, so it is eligible immediately
- if the budget is exhausted, it becomes `failed`, where C-11's existing Retry Chunk button applies

### The attempt counter is incremented, not preserved

A process death mid-upload is a real event and consuming an attempt is the honest accounting of it. It also bounds the loop: an app that dies during upload repeatedly walks the chunk through the budget and lands it at `failed`, a visible state with a working manual remedy. Preserving the counter would reset the same chunk into the same crash indefinitely, silently — an unbounded retry loop is a worse failure than a chunk that stops and says so.

### Reconciliation applies the budget itself, and that is load-bearing

Today the six-attempt cap is enforced in exactly one place: `UploadDispatcher._settleTransient`, which reads `RetrySchedule.hasAttemptsLeft(outcome.attemptCount)` and calls `markFailed`. **It needs an `UploadOutcome`, and a killed process produces none.**

So incrementing the counter is not by itself sufficient to bound anything — `claimNext` filters on status and `nextAttemptAt` and never consults `uploadAttemptCount`. A reconciliation that only moved rows to `queued` would raise the counter past six forever and never reach `failed`. **The budget check therefore belongs inside the reconciliation**, using the same `RetrySchedule.maxAttempts` so one rule is not spelled twice.

### `nextAttemptAt` is cleared rather than set to a backoff delay

A relaunch is already a natural rate limiter, and the six-attempt budget now binds on this path, so the worst case is a small bounded number of immediate attempts before the chunk rests at `failed`. Making the Collector wait 5, 10 or 20 seconds after a relaunch would delay the recovery without preventing anything the budget does not already stop.

### What does not change

- **`claimNext`'s `queued`-only filter stays.** Its transaction is what makes a claim atomic, and its own comment gives the reason: *"a chunk claimed twice would be uploaded twice — the one duplication S3's same-key semantics cannot undo, because both attempts would be legitimate."* Reconciliation runs before claiming and never concurrently with it.
- **`requeue`'s `failed`-only gate stays.** For the *manual* path that guard remains correct: in a live app a row at `uploading` may well be transferring, and letting the Collector re-queue it is the double-upload this ADR exists to avoid. FR-UPL-07 is unchanged.
- **C-11's Retry Chunk button stays gated on `failed`.** With reconciliation in place a stranded chunk reaches `queued` or `failed` on its own, so the button is needed only where it already renders.
- **No new state, no new column, no schema change.** Reconciliation writes fields that already exist.

### The invariant a future mission must not break

Reconciliation is safe **because it runs once per process, before any claim, in a process with no in-flight transfer.** If a later mission ever restarts a dispatcher inside a live process — a restart-after-halt, or a second instance built from a rebuilt provider — reconciliation would then run while the previous instance's uploads are still going, and `shutDown`'s comment describes exactly those rows: claimed, in flight, deliberately left to finish. Re-queueing them would produce the duplicate `claimNext` guards against.

**Restarting a dispatcher in a live process is therefore forbidden while this reconciliation exists**, unless reconciliation is moved behind a check that no transfer is in flight. This constraint is stated here because nothing in the code enforces it today; it holds only because `main.dart` calls `start()` once and `_shutDown` never clears.

## Consequences

**Item 137's mechanism moves from hypothesis to confirmed.** It was recorded as UNCONFIRMED pending a read of the chunk rows, which open item 139's credential gap blocks. That read is no longer required: the absence of any transition out of `uploading` outside the running pipeline, and `claimNext`'s `queued`-only filter, are visible in the source. Item 139 stays open on its own merits and is no longer 137's blocker.

**A chunk that would have been lost is uploaded instead.** The 520,658,550-byte chunk stranded during Chapter 9.8 scenario 2 would have been re-queued on the next launch and uploaded. Nothing else about that scenario changes; the failure was never in capture, storage, or S3.

**The Collector sees a state that is true.** A stranded chunk currently reads "Uploading" with an animating indeterminate bar and no available action. After this it reads Queued and uploads, or reads Failed and offers Retry Chunk. Chapter 2.9 §2's *"should never have to wonder if it worked"* is served either way.

**A chunk can now reach `failed` without a network failure.** Six kills during upload will do it. This is intended and visible, but it means `failed` no longer implies the backend or the network refused anything — and C-11 still cannot name a cause (open item 53), so a Collector sees "Failed" without learning it was the app dying. That gap widens slightly here and is not closed by this ADR.

**Two documented statements become wrong and must be corrected in the same change**, or the code and its comments will disagree: `ChunkQueueSource`'s *"no re-queue step at launch and no separate recovery pass"*, and `UploadDispatcher.start`'s *"there is no recovery pass here and none is needed"*. Chapter 5.9 §3 itself is a Volume statement and is corrected by amendment, not edited.

**Startup does one more write.** A single indexed read of rows at `uploading`, and a write only for rows found — normally none. It runs before the first claim, so it cannot race one.

## Correction, 2026-08-23 — the wake mechanism, not the decision

**The decision above stands unchanged.** Reconciliation at dispatcher start, one attempt spent per process death, the budget applied inside the reconciliation, `claimNext` and `requeue` untouched — all of that was verified on hardware and all of it holds. What was defective was the part this ADR never wrote down: **how the running dispatcher finds out.**

### What shipped, and what it did on a device

The implementation set `_reconciled` and called `_launch()`, which is gated on `_sawQueued`. That flag is set only by `_onQueueChanged`, which is fed by the queue subscription. And `IsarChunkStore.watchQueue()` is:

```dart
Stream<List<QueuedChunk>> watchQueue() async* {
  yield await currentQueue();                                  // first read
  await for (final void _ in _isar.localChunks.watchLazy()) {   // attaches here
    yield await currentQueue();
  }
}
```

`watchLazy()` reports writes made **after** it attaches. **Reconciliation's own write can land between the first read and that attach, and then no emission is ever produced for it.** Nothing else calls `_launch()` — only `_onQueueChanged` and a connectivity change — so the dispatcher holds its first read's state for the life of the process.

Mission 8.2 reproduced it on a CPH2707 on 2026-08-23, on a build made from this ADR's own implementation. A 369,099,659-byte chunk was force-stopped 4.7 s into its transfer. On relaunch the reconciliation fired correctly and logged *"Returned to the queue as attempt 1 of 6"* at 21:54:47.328 — and then the app said nothing for **eight and a half minutes**, across twelve monitor samples, with zero PUTs.

**The project owner's screen read "Queued"** the whole time, which is what made the diagnosis findable: the UI subscribes to `watchQueue()` **separately**, and its first read happened after the write. Two streams over the same rows, two first-read timings, two different answers. The database was right, the UI was right, and only the dispatcher was stale.

A confirming experiment settled it without a code change: recording an unrelated 15-second clip produced a write, the write produced an emission, and the dispatcher immediately claimed **both** chunks. The stranded one uploaded and verified at 22:05:21. **Nothing was ever lost** — the chunk was recoverable for the entire window and simply had nothing to wake its dispatcher.

### The correction

`_reconcileStranded` now reads the queue itself and feeds `_onQueueChanged` directly, rather than depending on an emission that may never come. `_onQueueChanged` is reused rather than reimplemented, because it recomputes both flags from a whole snapshot and folds the batch, and a second copy would be a second place for the rule to drift.

**Reordering to subscribe-before-reconcile was considered and rejected.** It narrows the window without removing the dependency on timing; the same race returns on a slower device or a slower Isar open. Reconciliation's write must be self-sufficient in waking the dispatcher.

### Why two triggers calling `_launch()` is safe by construction

`_launch()` is now reachable from the wake and from the subscription. That is provably bounded rather than probably fine:

- **`_launch()` is bounded, not merely idempotent.** It is synchronous with no `await`, so Dart completes it without interleaving and `_inFlight` cannot be read between the check and the increment. `while (_inFlight < _concurrency)` means extra calls cannot exceed Chapter 5.11 §3's limit.
- **`claimNext` is atomic**, so a duplicate runner cannot claim a row twice — the property the concurrency design already rests on.
- **`UploadBatchProgress.observe(n)` is idempotent.** With `done = total − remaining`, `observe(n)` gives `total' = max(total, n + done)`; applying it again gives `max(total', n + total' − n) = total'`.
- **`_syncService` is serialised** through its own future chain.
- **There is precedent in the same class.** `_runOne` already calls `_launch()` directly rather than waiting for the emission its own status write will produce, for this exact reason, and says so in a comment.

### The residual, stated rather than glossed

A **stale** first emission — read before the write — can still arrive after the wake and reset `_sawQueued` to false. The consequence is bounded: the wake has already run `_launch()`, so a claim attempt is in flight; `_inFlight > 0` keeps the service alive; and a successful claim writes a status, which produces a genuinely fresh emission. If the claim finds nothing, `false` was the correct answer anyway. This is a transient wrong flag that self-corrects on the next write, against a pre-fix state in which **no claim was attempted at all**.

### What the tests do and do not cover

Two tests were added and **verified to fail against the pre-fix dispatcher** — the first with *"Expected: a value greater than `<0>`, Actual: `<0>`"*, which is the device symptom exactly.

**The attach gap itself remains device-verified, not unit-tested.** Isar 3 needs a native core `flutter test` does not load, so no test here drives a real `watchLazy`. What is tested is the property that makes the gap harmless: the dispatcher reaches the right state whether or not an emission arrives. That is a stronger claim than modelling the gap, because it does not depend on the model being right — and this ADR's original five tests are the standing argument for that distinction. They passed while the code was broken on hardware, because `_FakeQueue` had no first-read-then-attach gap to lose a write in. **Open item 141** records that blind spot and recommends an audit of the other port fakes.
