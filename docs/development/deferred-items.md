# Deferred Items

Known-incomplete implementation, each with the mission that owns closing it.

Authority: none — this is a log, not a decision. Every entry restates a fact already recorded in an ADR or a source comment; nothing here is new policy.

---

## What belongs here, and what does not

Volume 11 defines three registers, and this is none of them:

| Register | Volume 11 | Shape | Why these items are not it |
| --- | --- | --- | --- |
| Risk Register | Ch. 11.4 | Risk / Likelihood / Impact / Mitigation | These are not risks. Each is a certainty with a known fix, so likelihood is meaningless |
| Feature Tracker | Ch. 11.6 | One row per `FR-` group, status Not Started → Shipped | These are not features. They cut across FR groups or sit beneath all of them |
| Bug Tracker | Ch. 11.7 | Defect, severity, triage | These are not bugs. Every one was a deliberate deferral, taken knowingly and recorded at the time |

Neither Ch. 11.4's register nor Ch. 11.6's tracker exists as a file in this repository, so nothing was displaced by adding this one. When they are created, the two navigation entries below are also worth carrying into Ch. 11.4 as risks, because both are silent — nothing fails when they are wrong.

An item leaves this table only when its owning mission closes it. Nothing is deleted for going stale.

## The log

| # | Item | Owner | Evidence |
| --- | --- | --- | --- |
| 1 | `network_config` base URLs are placeholders on the reserved `.example` TLD, for all three environments | Mission 6 | [network_config.dart:76-78](../../mobile/lib/core/network/network_config.dart#L76-L78) |
| 2 | iOS bundle identifier is still Flutter's template default, `com.example.mobile` | Mission 6 | [project.pbxproj](../../mobile/ios/Runner.xcodeproj/project.pbxproj) — 6 occurrences: 3 `Runner` configurations, 3 `RunnerTests` |
| 3 | One Firebase project, `vump-platform-f86af`, serves development, staging and production alike | Mission 6 | [google-services.json:4](../../mobile/android/app/google-services.json#L4) — one `project_id`, no per-flavor override |
| 4 | BR-04 is unenforced: the Recording Screen is a top-level route, so it is reachable without passing the Pre-Recording Checklist | Mission 3 | [router.dart:313-317](../../mobile/lib/app/router.dart#L313-L317) |
| 5 | Ch. 2.4 §4's Role Router does not exist. `/collector` and `/admin` are both directly reachable by anyone | Mission 2 | [router.dart](../../mobile/lib/app/router.dart) — zero `redirect:` declarations |
| 6 | Typed route arguments unresolved. Every parameter is a raw `String` from `pathParameters`, defaulted to `''` when absent | The first mission adding a parameterised route | [router.dart](../../mobile/lib/app/router.dart) — 7 `pathParameters` reads; ADR-004 Consequences |
| 7 | `main` and `develop` are 189 commits behind the work. Every mission from 0.17 onward — `infrastructure/`, `backend/`, ADR-011 through ADR-042, `docs/volumes/` — exists only on `mission-0.18.4-ci` | Mission 6.4/6.5 | `git rev-list --count main..mission-0.18.4-ci` → 189. `git ls-tree main docs/architecture/decisions` → ADR-001..010 only |
| 8 | No scoped per-developer IAM user exists. Volume 7 Ch. 7.8 §1 requires one *"scoped to the dev environment only"*; the single configured profile is `default`, resolving to `user/faisal-admin` | Unassigned — needs a mission | `aws configure list-profiles` → `default`; `aws sts get-caller-identity` → `arn:aws:iam::929570731524:user/faisal-admin`. Amendment A-144 |

## Notes on individual entries

**Items 1–3 share a cause.** All three are template or placeholder values that ADR-014's environment strategy requires to differ per environment, and none has yet been given a real value because no environment has been provisioned. Mission 6 owns all three together; fixing one without the others leaves the environment split half-built.

**Item 3 has an adjacent absence.** There is no `mobile/ios/Runner/GoogleService-Info.plist` at all, so iOS has no Firebase configuration rather than the wrong one. Same owner, same fix.

**Items 4 and 5 are both redirect-shaped.** Both close with a route-level `redirect`, which ADR-004's Consequences already name as the home for exactly this. Neither is decided here. Item 5's owner precedes item 4's, so the mechanism will exist before item 4 needs it.

**Item 6 has no fixed mission number** because it is triggered by circumstance rather than scheduled. The parameterised routes already exist as of Mission 1.3, so the trigger is met and the next mission to touch route arguments inherits it.

**Item 7 is a branch-topology defect, not a code defect.** ADR-019 assigns `develop` the role of "everything merged but not yet a release candidate", and `develop` was cut from `main` — which predates Mission 0.17. Mission 6.1 was originally branched from it and had to be recut from `mission-0.18.4-ci`, because none of the ADRs, volumes or infrastructure it was told to read existed on the branch. Recorded here rather than fixed in 6.1: a 189-commit reconciliation onto two protected branches is its own piece of work with its own review, and folding it into an infrastructure mission would hide it inside an unrelated diff.

**Item 8 is not blocking and is not free.** Every `terraform plan`, and every `apply` that follows, runs with administrative rights in the account that holds `vump-platform-prod`. ADR-014 already names IAM as the only thing separating environments in a single account; item 8 is that argument applied to the human rather than to a service role. It has no owning mission yet, which is itself the thing to fix.
