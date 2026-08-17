# ADR-017 — Environment-Driven Startup Failure

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Discharges the obligation recorded in ADR-010's "Provisional" section.

## Context

ADR-010 left startup deliberately tolerant of a Firebase initialisation failure: `main.dart` caught the exception, logged it, and continued. That was correct at the time — the project was unconfigured, no feature depended on Firebase, and aborting would have made the application unrunnable for everyone.

ADR-010 also recorded that the tolerance was **provisional**, and required it to become either fatal or an explicit degraded mode "recorded in an ADR", warning that it "must not be allowed to persist by inertia."

Two things have since changed. Firebase is configured and the Android platform is wired (Mission 0.15.2), so the original justification — "the project is unconfigured" — has expired. And Mission 0.17.17 introduced real environment resolution, which means the question no longer needs a single answer.

That last point is what makes this decision possible rather than merely overdue. "Should startup fail?" has no good universal answer: yes is right for production and wrong for a developer on a train with no network. The tolerance was never wrong — it was *unconditional*.

## Decision

**Whether a Firebase initialisation failure aborts startup is determined by the environment.**

| Environment | Failure is fatal | Reasoning |
|---|---|---|
| `development` | **No** | An unconfigured or offline machine must still run the app while no feature depends on Firebase. Failing here costs productivity and protects nothing. |
| `staging` | **Yes** | Staging exists to rehearse production (ADR-014). A staging build that tolerates a failure production would reject is not rehearsing production. |
| `production` | **Yes** | Starting without the platform the build was made against is silent breakage, not degraded operation. |

Expressed as `AppFeatureFlags.firebaseFailureIsFatal`, derived from `AppConfig.environment`, and read once in the composition root. A fatal failure is logged at `fatal` level and rethrown, so it surfaces as a crash with a cause rather than as an application that runs strangely.

Staging is deliberately grouped with production rather than with development. If the two differed, the first execution of the fatal path would be in production — the exact failure mode ADR-014 exists to prevent.

## Alternatives Considered

- **Keep the unconditional tolerance** — rejected. ADR-010 forbade it persisting by inertia, and its stated justification has expired. A production build that silently runs without Firebase will fail later, further from the cause, in front of a Collector.
- **Make it unconditionally fatal** — rejected. It is right for production and hostile in development, where an offline machine or a fresh clone without configuration is normal. That friction would be paid daily to prevent a failure that only matters in two environments.
- **A degraded mode with a user-visible banner** — rejected as premature. It presumes the app can do something useful without Firebase, which will stop being true the moment authentication lands. Revisit if a genuinely optional Firebase product is adopted.
- **Decide per Firebase product rather than per environment** — rejected for now. There is one product. Crashlytics failing is genuinely less severe than Auth failing, and when both exist this may deserve revisiting; inventing that granularity before the second product is speculative.
- **A `--dart-define` flag independent of `APP_ENV`** — rejected. It is a second axis of configuration whose combinations nobody would test, and it would let a production build be started with the check disabled.

## Consequences

- Production and staging cannot start against an uninitialised Firebase platform.
- Development keeps working offline, on a fresh clone, and on a machine without a configured project.
- ADR-010's provisional tolerance is discharged. It is now a decision with a stated scope rather than a note that something must be revisited.
- **The fatal path is exercised in staging before it can matter in production**, which is the entire argument for grouping the two.
- A developer whose machine is misconfigured sees an error log rather than a crash, so a genuine misconfiguration is quieter in development than elsewhere. That is the accepted cost of the split.
- The fatal path cannot be reached under `flutter test`, which compiles as `development`. It is verified by asserting the flag per environment rather than by triggering the abort.
- Any future startup prerequisite — the database (ADR-009), secure storage (ADR-008) — should use this same environment-driven shape rather than inventing its own policy.

## Related Missions

- Mission 0.15 — Firebase Foundation, which introduced the tolerance.
- Mission 0.15.1 — Firebase Platform Integration, which recorded it as provisional.
- Mission 0.17.17 — Environment Configuration, which produced this ADR.

## Implementation Status

**Implemented.**

`AppFeatureFlags.firebaseFailureIsFatal` is derived from `AppConfig.environment` and read by `main.dart`. Verified by test for all three environments.

The database and secure storage startup prerequisites do **not** yet follow this shape — neither is wired into the composition root at all. When they are, this decision is the pattern to follow.
