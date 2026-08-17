# ADR-033 — Database Startup Failure Policy

- **Status:** Accepted
- **Date:** 2026-08-13
- **Supersedes:** none. Supplements ADR-009, which specifies no startup failure policy. **Departs from ADR-017's Consequences in one respect** — see *Why this is not environment-driven*. ADR-017 remains Accepted and binding for Firebase and in every other respect.

## Context

Mission 1.2 wired `DatabaseService.open()` into the composition root, putting the database open on the startup path that Volume 6 Chapter 6.1 §2 requires and that ADR-009 already assumed when it recorded that *"database open is on the startup path, so its duration is worth recording"*.

That immediately raised a question ADR-009 does not answer: **what happens when the open fails?**

ADR-009 is thorough about the failure *representation* — every Isar error converts to a `StorageException` from the Mission 0.10 taxonomy, `storageUnavailable` when the database cannot be opened — and silent about the failure *policy*. It never says whether startup continues.

**The obvious place to look is ADR-017, and it points the other way.** ADR-017 made Firebase initialisation failure environment-driven, and its Consequences say: *"Any future startup prerequisite — the database (ADR-009), secure storage (ADR-008) — should use this same environment-driven shape rather than inventing its own policy."* Its Implementation Status repeats it: *"When they are [wired], this decision is the pattern to follow."*

So there is an accepted ADR naming this exact case and recommending a shape. This record departs from that recommendation deliberately, and the departure is the substance of the decision rather than a footnote to it.

Mission 1.2 implemented unconditional-fatal in `main.dart` and flagged the absence of a governing policy. This ADR records the decision that implementation embodies.

## Decision

**A database open failure aborts startup in every environment — `development`, `staging` and `production` alike.**

There is no feature flag, no environment split, and no soft-fail path. The failure is logged at `fatal` and rethrown, so it surfaces as a crash with a cause rather than as an application that runs strangely — the same surfacing shape ADR-017 chose for its fatal case.

### Why this is not environment-driven

ADR-017's split exists for a specific reason, stated in its own Alternatives when it rejected unconditional fatality for Firebase:

> *"It is right for production and hostile in development, where an offline machine or a fresh clone without configuration is normal. That friction would be paid daily to prevent a failure that only matters in two environments."*

**That reasoning does not transfer to the database, because the failure modes are not analogous.**

| | Firebase | Local database |
|---|---|---|
| Needs a network | Yes | No |
| Needs project configuration | Yes | No |
| Fails on a fresh clone | Yes, routinely | No |
| Fails on a developer's train journey | Yes | No |
| Needs only a writable directory | — | Yes, and one always exists on a real device |

Firebase's development tolerance protects against **normal, expected, environmental** conditions: no network, no configured project, a clone someone has just made. Those conditions are daily and benign.

A local database failing to open is none of those things. It means the writable application directory is unavailable, the storage is full or corrupt, or the schema migration failed. **On a developer's machine those conditions are as broken as they are in production** — there is no benign version of them. An environment split would therefore buy no development convenience while creating a path where a real defect is logged and walked past.

### Why the failure is fatal rather than degraded

The Constitution §3 requires offline-first: *"Every core workflow (viewing tasks, recording, chunking, queueing uploads) must work with no network connection."* All four of those workflows are local-persistence workflows. `NFR-REL-04` requires the app to *"recover its full local queue state after a force-close or crash"*, and Volume 5 §5.6 §3 puts the upload queue in this database rather than in memory precisely so that holds.

**Without local persistence the application cannot honour "never lose a take."** Constitution §3 states it as an absolute: *"Once the collector taps Stop, the raw footage must be safely written to local storage before any other operation is attempted."* An app that starts without the store that write targets is not degraded, it is broken — and the failure would surface at the worst possible moment, after a Collector has finished recording.

Failing at startup converts a data-loss defect into a launch failure. That is the trade, and it is the right way round.

### The mechanism this documents

`main.dart`'s `_openDatabase`, added by Mission 1.2. No code changes accompany this ADR; it records a decision already implemented.

```dart
Future<void> _openDatabase(
  ProviderContainer container,
  AppLogger logger,
) async {
  try {
    await container.read(databaseProvider.future);
  } on AppException catch (error, stackTrace) {
    logger.fatal(
      'The local database could not be opened. Aborting startup rather than '
      'running without local persistence.',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
```

Three properties are load-bearing:

- **It catches `AppException`, not `Exception`.** ADR-009 guarantees no `IsarError` escapes `core/database/`, so the only thing reachable here is the taxonomy. Catching wider would mask a programming error as a storage failure.
- **It rethrows rather than exiting.** The unhandled exception is what makes the failure visible to the platform and to a future crash reporter (A-036, A-037), rather than a silent `exit()`.
- **It logs before rethrowing.** This is the codebase's **second `fatal` call site**, which `logging-standards.md` §5 records as a decision rather than a detail — *"There is one, and adding a second is a decision."* This ADR is that decision.

## Alternatives Considered

- **Follow ADR-017's environment-driven shape**, as ADR-017's Consequences recommend. **Rejected, and this is the closest call in the record.** The recommendation is sound as a default and wrong for this prerequisite: the development tolerance it grants exists to absorb missing network and missing configuration, and a local database needs neither. Applying the shape mechanically would create a `development` path where a full disk or a failed migration is logged and ignored — a real defect made quiet in the one environment where it is cheapest to fix. The pattern is followed in surfacing (log `fatal`, rethrow) and departed from in conditionality.

- **A `databaseFailureIsFatal` flag on `AppFeatureFlags`**, mirroring `firebaseFailureIsFatal`. Rejected as the concrete form of the above. It would also add an environment axis whose `development` branch nobody would ever deliberately exercise, and ADR-017 itself rejected a second configuration axis on the grounds that its combinations go untested.

- **Tolerate failure in development only when the database is empty** — that is, treat a first-run failure as benign and a subsequent one as fatal. Rejected. It requires knowing whether data existed before the open that just failed, which is precisely what a failed open cannot tell you.

- **Degrade to an in-memory database in development.** Rejected. It makes development diverge from production in the layer whose correctness is hardest to verify, and it would let a developer build and test a recording flow against a store that discards everything — the exact failure `NFR-REL-04` exists to prevent, hidden behind a working-looking app.

- **Catch the failure and show a user-facing error screen.** Rejected as premature, on the same ground ADR-017 rejected a degraded-mode banner: it presumes the app can do something useful without the database, and it cannot. Worth revisiting only if a genuinely read-only, network-only surface is ever built — and there is none, because offline-first means every surface reads locally.

- **Leave the policy unrecorded**, since the implementation already exists. Rejected. `docs/architecture/README.md` is explicit that *"an architectural decision that is not recorded here does not exist"*, and an unconditional-fatal path that contradicts a recommendation in an accepted ADR is exactly the kind of decision that gets quietly reverted by whoever next reads ADR-017 alone.

## Consequences

- **A device that cannot open its database cannot start the app**, in any environment. That is the intended behaviour and it is absolute.

- **ADR-017's Consequences are now partly out of date**, and a reader of ADR-017 alone will believe the database follows its shape. It does not. This is the unavoidable cost of the rule that accepted ADRs are never edited; it is mitigated by the cross-reference in `docs/architecture/README.md` and by this record's own Supersedes line.

- **Secure storage (ADR-008) is still unresolved and now has two precedents rather than one.** ADR-017 recommends its shape; this ADR shows the recommendation is not automatic. Whichever is right for secure storage, the mission that wires it must argue the case rather than copy either — and secure storage is genuinely closer to Firebase, since a keychain can be unavailable on a simulator in ways that are benign.

- **The fatal path cannot be exercised under `flutter test`**, which does not run `main()`. It is verified by Mission 1.2's temporary test asserting that `open()` converts a failure to `StorageException` and that concurrent callers share one attempt — the abort itself is unverified, exactly as ADR-017 records for its own fatal path.

- **Startup has three awaits and two of them can abort it.** Cold start against target P5 (< 2.5 s, `performance-standards.md` §2) now carries the database open, and there is no instrumentation to measure the change — recorded in `performance-standards.md` §14.

- **A developer with a misconfigured machine gets a crash rather than a log line.** Unlike ADR-017's development path, this is loud. That is deliberate: the conditions that cause it are defects, not circumstances.

- **This is the second `fatal` site.** A third needs its own justification, per `logging-standards.md` §5.

## Related Missions

- Mission 0.14 — Isar Local Database Foundation, which produced ADR-009 and left the failure policy unspecified.
- Mission 0.17.17 — Environment Configuration, which produced ADR-017 and recommended its shape for this case.
- Mission 1.2 — Open the Database at Startup, which implemented the policy and flagged that no ADR governed it.
- Mission 1.2b — Database Startup Failure Policy, which produced this record.

## Implementation Status

**Implemented, ahead of this record.** Mission 1.2 wired `_openDatabase` into `main.dart`; this ADR documents the decision that code embodies and adds no code of its own.

| Verified | Result |
|---|---|
| `_openDatabase` present in `main.dart` | Yes — catches `AppException`, logs `fatal`, rethrows |
| Environment conditionality | **None** — no flag, no branch |
| `AppFeatureFlags` entries | Unchanged: `databaseInspectorEnabled`, `firebaseFailureIsFatal` |
| `fatal` call sites in the codebase | **2** — Firebase (ADR-017), database (this ADR) |
| ADR-009 modified | **No** — supplemented, not edited |
| ADR-017 modified | **No** — departed from, with the departure recorded here and in the architecture README |
| Code changed by this mission | **None** |
| `flutter analyze` | No issues |

**One thing about this record's own premise is worth stating plainly.** Mission 1.2b's brief described ADR-033 as documenting a policy that differs from Firebase's, which it does. It did not mention that **ADR-017's Consequences explicitly name the database and recommend the environment-driven shape** — so this ADR is not merely filling a gap in ADR-009, it is declining a recommendation in an accepted ADR. That changes what the record has to do: state the departure in its Supersedes line, argue against the recommendation on its merits rather than ignore it, and register the divergence where ADR-032's refinement of ADR-024 is registered. All three are done above.
