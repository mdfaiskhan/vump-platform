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

**Mission 6's items are also collected in [`mission-6-gap-register.md`](mission-6-gap-register.md)**, together with the "report, don't fix" items that were raised inside a close-out and never became rows here. That file is a hand-off to Mission 6.7's security review; this one remains the live register. Where they disagree, the ADR or amendment each cites is correct.

## The log

| # | Item | Owner | Evidence |
| --- | --- | --- | --- |
| 1 | `network_config` base URLs: **development is real** (the API Gateway invoke URL, Mission 6.5). Staging and production remain on the reserved `.example` TLD — correct, not unfinished, since no API Gateway exists in either environment | The mission that provisions staging/prod infrastructure | [network_config.dart](../../mobile/lib/core/network/network_config.dart). ADR-048 |
| 2 | iOS bundle identifier is still Flutter's template default **inside the Xcode project**. Firebase now holds the real one (`com.vump.humanarchive[.dev|.staging]`) in all three projects, and `ios/config/{flavor}/GoogleService-Info.plist` exists, but nothing wires either into a scheme | The first mission with a Mac or a cloud Mac build | [project.pbxproj](../../mobile/ios/Runner.xcodeproj/project.pbxproj) — still 6 occurrences of `com.example.mobile`. ADR-047, Amendment A-162 |
| 3 | ~~One Firebase project serves all three environments~~ — **CLOSED, Mission 6.4.** `vump-platform-f86af` (development), `vump-staging` and `vump-prod` exist, each with its own Firestore in `asia-south1`, and the build flavor selects between them | Closed | Three `android/app/src/{flavor}/google-services.json`, verified project IDs. ADR-047, Amendment A-162 |
| 4 | BR-04 is unenforced: the Recording Screen is a top-level route, so it is reachable without passing the Pre-Recording Checklist | Mission 3 | [router.dart:313-317](../../mobile/lib/app/router.dart#L313-L317) |
| 5 | Ch. 2.4 §4's Role Router does not exist. `/collector` and `/admin` are both directly reachable by anyone | Mission 2 | [router.dart](../../mobile/lib/app/router.dart) — zero `redirect:` declarations |
| 6 | Typed route arguments unresolved. Every parameter is a raw `String` from `pathParameters`, defaulted to `''` when absent | The first mission adding a parameterised route | [router.dart](../../mobile/lib/app/router.dart) — 7 `pathParameters` reads; ADR-004 Consequences |
| 7 | `main` and `develop` are 189 commits behind the work. Every mission from 0.17 onward — `infrastructure/`, `backend/`, ADR-011 through ADR-042, `docs/volumes/` — exists only on `mission-0.18.4-ci` | Mission 6.4/6.5 | `git rev-list --count main..mission-0.18.4-ci` → 189. `git ls-tree main docs/architecture/decisions` → ADR-001..010 only |
| 8 | No scoped per-developer IAM user exists. Volume 7 Ch. 7.8 §1 requires one *"scoped to the dev environment only"*; the single configured profile is `default`, resolving to `user/faisal-admin` | Unassigned — needs a mission | `aws configure list-profiles` → `default`; `aws sts get-caller-identity` → `arn:aws:iam::929570731524:user/faisal-admin`. Amendment A-144 |
| 9 | Account-plan viability is unchecked for any account other than `929570731524`. A Free-plan account closes itself and deletes its resources when credits run out or the plan ends | The first mission provisioning into a **second** AWS account | `aws freetier get-account-plan-state` → `PAID` for this account. Amendment A-146 |
| 10 | `functions/` is a Firebase Cloud Function ADR-036 marks **temporary**. **Mission 6.5 decided not to retire it**, and the item is now deliberately open rather than forgotten: retiring it moves claim-writing outside Google, which is the only thing that would force the credential ADR-036 defers | Unassigned — reopens only if claim-writing moves to AWS | Amendment **A-165**. Volume 4 Ch 4.9 §3's seam; `functions/src/index.ts` still deployed and unchanged |
| 11 | Nothing applies a merged migration. A schema change can be written, reviewed, merged and released without reaching any database, and neither CI nor the runner notices | Unassigned — needs a trace/decide mission, because the fix is a credential decision rather than a missing check | ADR-046: *"Run deliberately, never by CI"*. Amendment A-161 |
| 12 | ~~The `org_id: "vump-default"` claim cannot be represented in `users.org_id uuid`~~ — **CLOSED, Mission 6.5.** Migration `0009` adds the `Unassigned` org with a deterministic uuid, and `resolveOrgId` maps the literal to it by explicit lookup, refusing any other value rather than defaulting | Closed | `backend/packages/shared/src/org.ts`; proven live — `POST /v1/auth/verify` returned `orgId: 00000000-0000-4000-8000-000000000001`. Amendment A-166 |
| 13 | Firebase **Auth is not enabled** in any of the three new projects, and **billing is not linked**, so `redeemInviteCode` is not deployed to them and the Artifact Registry cleanup policy is not replicated. Both are console-only owner actions | Project owner, before Mission 6.4 can close | `accounts:signInWithPassword` → `CONFIGURATION_NOT_FOUND`; `firebase deploy --only functions` → *"must be on the Blaze plan"*. Amendment A-162 |

## Notes on individual entries

**Items 1–3 shared a cause, and item 3 broke the pattern.** All three were template or placeholder values that ADR-014's environment strategy requires to differ per environment, unset because no environment had been provisioned. Mission 6.4 provisioned the Firebase side and closed item 3. Items 1 and 2 remain, and are no longer blocked on the same thing: item 1 waits on real API domains, item 2 on a Mac.

~~**Item 3 has an adjacent absence.** There is no `mobile/ios/Runner/GoogleService-Info.plist` at all.~~ **Overtaken by Mission 6.4.** Three plists now exist at `mobile/ios/config/{flavor}/GoogleService-Info.plist`, one per environment. They are deliberately *not* at the Xcode-default path, because a single file there would reintroduce the one-project-for-three-environments defect item 3 just closed. Nothing consumes them until a scheme selects one, which is item 2.

**Items 4 and 5 are both redirect-shaped.** Both close with a route-level `redirect`, which ADR-004's Consequences already name as the home for exactly this. Neither is decided here. Item 5's owner precedes item 4's, so the mechanism will exist before item 4 needs it.

**Item 6 has no fixed mission number** because it is triggered by circumstance rather than scheduled. The parameterised routes already exist as of Mission 1.3, so the trigger is met and the next mission to touch route arguments inherits it.

**Item 7 is a branch-topology defect, not a code defect.** ADR-019 assigns `develop` the role of "everything merged but not yet a release candidate", and `develop` was cut from `main` — which predates Mission 0.17. Mission 6.1 was originally branched from it and had to be recut from `mission-0.18.4-ci`, because none of the ADRs, volumes or infrastructure it was told to read existed on the branch. Recorded here rather than fixed in 6.1: a 189-commit reconciliation onto two protected branches is its own piece of work with its own review, and folding it into an infrastructure mission would hide it inside an unrelated diff.

**Item 8 is not blocking and is not free.** Every `terraform plan`, and every `apply` that follows, runs with administrative rights in the account that holds `vump-platform-prod`. ADR-014 already names IAM as the only thing separating environments in a single account; item 8 is that argument applied to the human rather than to a service role. It has no owning mission yet, which is itself the thing to fix. **Mission 6.1's two applies both ran as `faisal-admin`**, so the 35 live resources were created by an unscoped principal. **Mission 6.3.2's apply ran as the same principal**, taking the total to **66 managed resources**, and additionally set seven database passwords via `npm run db:bootstrap` — so an unscoped human credential is now what created every Lambda, every API route and every per-function database credential in the account.

**Item 10 is the obligation ADR-036 wrote down and could not enforce.** That record is candid about it: *"No CI check can detect that Mission 6/7 has happened. If the port is forgotten, a Cloud Function silently becomes permanent architecture."* Mission 6.2 is the first half of Mission 6/7 and deliberately did not retire it, for the reason ADR-036 itself gives: the endpoint being ported **writes a Firebase custom claim**, and line 35 identifies claim-writing as the operation that genuinely needs a service-account key. That key is Mission 6.5's. Porting it in 6.2 would have pulled 6.5 forward.

Recorded here so the obligation has a tracked home rather than depending on someone remembering an ADR. It is the one deferred item whose failure mode is silent by construction.

**Item 9 is closed for this account and open for the next one.** Account `929570731524` is on the Paid plan (A-146), so the Free-plan auto-closure that would have deleted every resource on 2027-02-09 no longer applies — and because ADR-014 puts production in this same account, that question is settled for all three environments as they stand today.

It reopens the moment a second account exists. ADR-014's **target** architecture is separate accounts for Development, Staging and Production, deferred until production scale; a new account starts on whichever plan it is created with, and a Free-plan production account would be a platform with an expiry date. **The trigger is the first mission that provisions into an account other than `929570731524`**, and the check is one call — `aws freetier get-account-plan-state`, which must report `PAID` / `ACTIVE` before anything is created. Recorded as an item rather than left to memory because the failure is silent for months and then total.

**Item 11 is the third gap of A-148's shape and the first that cannot be closed by adding a CI job.** A-148 (`infrastructure/`) and A-153 (`backend/`) were both *a standard written and nothing executing it*, and both closed the same afternoon they were found, by running an existing read-only command in CI. Neither granted CI any access it did not already have.

This one does not have that exit. A runner that applies migrations must hold a credential that can `CREATE`, `ALTER` and `DROP` against a live database, which is exactly what ADR-046 and `folder-structure.md` §1.3 refuse in identical words to their refusal for `terraform apply`. Closing it therefore means answering a question larger than migrations — **should CI ever hold AWS write credentials?** — which also governs deployment and Mission 6.5's Firebase service-account key.

A read-only drift check that compares `schema_migrations` against the files is the likely answer and is still not taken here, because it needs a CI principal that does not exist: item 8 records that the only credential in use is the unscoped `faisal-admin`, and CI must not have it. Owner is deliberately unassigned rather than guessed — this is a trace/decide, not a chore.

**Item 3 closed, and item 2 did not.** The same mission created three Firebase projects and registered the real bundle identifier in each — but registering an identifier in Firebase and building an iOS app under it are different acts, and only the first is possible from this machine. Chapter 7.1 §4 puts iOS builds on a cloud Mac that does not exist yet, and there is no Apple Developer account, so `com.vump.humanarchive` is currently a string in a Firebase console rather than a real App ID. The plists are downloaded and committed so that the work waiting on a Mac is wiring, not discovery.

**Item 12 is a data-shape defect that Mission 6.4 made visible rather than introduced.** `redeemInviteCode` has written `org_id: "vump-default"` since Mission 2.9, when no organisation model existed and a literal was the honest placeholder — the function's own comment says so: *"When a real organisation model arrives (Volume 4 Ch. 4.4's `users` table), this constant becomes a row."* That model arrived in Mission 6.3. The constant did not become a row, and nothing failed, because no handler reads the claim yet (A-163).

Deploying the same function to three projects multiplies the sites but changes nothing about the defect, which is why it is logged rather than fixed here: correcting it means deciding what an organisation *is* at sign-up time, and that belongs to the mission that ports redemption onto the AWS backend.

**Item 13 is the only thing standing between Mission 6.4 and completion.** Neither action can be performed by any credential this project holds: enabling Authentication is a console gesture with no CLI equivalent, and linking billing is a decision about money. They are recorded as a deferred item rather than as a blocked mission step because the second one — billing — also gates the Artifact Registry cleanup policy, and an unlinked project silently accrues nothing today but will the moment functions deploy to it.

**Item 10 changed character in Mission 6.5, and that is the point of re-reading it.** It was an omission — Mission 6.2 built the backend and did not retire the Cloud Function. It is now a decision with a reason attached: Volume 4 Chapter 4.9 §3 says *"the only integration point between the two clouds is Chapter 4.7's token verification… and nothing else crosses the boundary"*, and verification needs no credential. Porting `redeemInviteCode` would widen that seam and require either a Workload Identity trust relationship or a long-lived key able to mint `admin` on any organisation.

So the item stays open because closing it costs more than leaving it. That is a different state from "nobody got to it", and A-165 records which one this is. The owner is unassigned deliberately: the trigger is a decision to move claim-writing, not a date.

**Item 12 closed with one row and one lookup.** The fix is deliberately not a schema change: `org_id` was always meant to be a uuid, and the literal was a placeholder from Mission 2.9 that outlived the absence it stood for. Migration `0009` inserts the row it was standing in for, and `resolveOrgId` refuses any org it does not recognise instead of defaulting — so a future real organisation cannot be silently collapsed into `Unassigned`, which is the failure BR-20's tenant isolation exists to prevent.

The trusted-group assumption survives: every self-signup account still lands in one shared organisation, and **that should be revisited before public distribution**, the same trigger ADR-036's own distribution assumption carries.
