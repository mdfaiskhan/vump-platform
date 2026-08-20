# ADR-048 — A REQUEST Authorizer Resolves the Caller

- **Status:** Accepted
- **Date:** 2026-08-18
- **Supersedes:** the design recorded in **A-159**, which made `org_id` a Firebase custom claim so that every function could scope by org without reading `users`. That amendment stands as history; its design is not adopted.

## Context

Chapter 4.8 §2's middleware chain begins *"1. Authenticate (Chapter 4.7) — attaches user, role, org_id"*, and every one of Chapter 4.6's fifteen endpoints is supposed to run behind it.

Nothing could implement that. Chapter 4.7 §1 step 4's caller lookup is a read of `users`, and Volume 8 Chapter 8.4 §1 gives that grant to `auth-verify` alone — enforced in PostgreSQL by migration `0007`, because ADR-044 records that per-table permission is not expressible in IAM under the Data API. Six functions were required to attach `org_id` and forbidden from reading the table it comes from.

A-159 resolved that by moving `org_id` into the token as a custom claim. Mission 6.5 re-traced it and found three problems:

1. **Chapter 4.7 §2 makes the claim a cache, not a source** — *"falling back to the users table as the authoritative source if the claim and the table ever disagree."* A design where the claim is the only source inverts the chapter it cites.
2. **A claim is written once and read until the token refreshes.** A user moved between orgs is stale everywhere until then; the table never is.
3. **It was the only reason to write claims from AWS**, which is what forces the Firebase credential question ADR-036 deferred. The design created the credential problem.

## Decision

**An API Gateway REQUEST authorizer resolves the caller once, and API Gateway attaches the result to every downstream request.**

`auth-verify` serves it — the same function, told apart by event shape. One function reads `users`, exactly as Chapter 8.4 §1 requires, and fourteen routes receive `userId`, `orgId` and `role` in `event.requestContext.authorizer` without a query and without a grant.

`role` remains a Firebase custom claim, because Chapter 4.7 §2 specifies it and `redeemInviteCode` already writes it. **`org_id` does not.**

### The authorizer is `auth-verify`, not an eighth function

A separate authorizer would need `SELECT` on `users`, which means an eighth database role, an eighth credential and an eighth secret — to run the query the existing function is already the only principal permitted to run. Mission 6.5 adds **zero** secrets, and this is how.

### Exactly one route is exempt, and the exemption is asserted but not enforced

`POST /v1/auth/verify` is not behind the authorizer. Chapter 4.7 reads as self-contradictory —

- §1 step 4: *"looks up **(or creates, on first login)** the matching users row"*
- §4 pseudocode: `if user is null: reject(401)`

— and the contradiction dissolves once the two are read as **different components**. §4 is the authorizer, in front of fourteen routes. §1 step 4 is `POST /v1/auth/verify`, which verifies its own token and creates the row.

Applying "reject" uniformly deadlocks the platform, and this is not hypothetical: four Firebase accounts existed with `users` empty, nothing writes to that table, and `redeemInviteCode` creates Firebase accounts without an Aurora row. Every account, existing and future, would have been refused at every door including the one meant to let them in. A-166.

A second exemption would open an endpoint with nothing in front of it, so a Terraform `check` asserts the exempt list is exactly `["POST /v1/auth/verify"]`.

**That assertion is weaker than it looks, and this record originally overstated it.** It said the check *"fails the plan otherwise"*. It does not:

- **A failed `check` is a warning, not an error.** When the condition was wrong during Mission 6.5, `terraform plan` printed `Warning: Check block assertion failed`, then completed, wrote its plan file, and `apply` ran from it. Nothing was blocked.
- **CI never evaluates it at all.** `check` blocks run during plan and apply. The `Terraform` CI job runs `fmt -check`, `init -backend=false`, `validate` and `tflint` — and no `plan`, because it holds no AWS credentials. Confirmed by the same run: `validate` reported `Success! The configuration is valid.` at the moment `plan` was warning about the failed assertion.

So the exemption is held by **code review plus a warning a human has to notice**, not by CI. That is materially less than "machine-checked", and the difference matters because the property being guarded is which routes are allowed to bypass authentication.

Closing it means running `terraform plan` in CI, which means giving CI AWS credentials — the same decision A-161 defers for migrations, and not one to take as a side effect. Recorded as gap 16 in `docs/development/mission-6-gap-register.md`.

### Deny, not allow-with-a-flag

A failed lookup returns an explicit `Deny`, so API Gateway refuses before the target function is invoked. Returning `Allow` with an "unauthenticated" flag would push the decision into fifteen handlers, any one of which could forget it. A handler that finds no authorizer context **fails** rather than falling back — a detached authorizer must not silently become an open endpoint.

### `authorizerResultTtlInSeconds = 0`

Caching a policy caches an authorization decision. A user removed from an org, or deleted, would keep working for the cache window. Correctness first; revisit under measured load.

## Alternatives Considered

- **A-159's `org_id` custom claim** — rejected above. It inverts Chapter 4.7 §2, goes stale, and drags in the deferred credential question.
- **Grant every function `SELECT` on `users`** — rejected. It is precisely what Chapter 8.4 §1 forbids, and A-158's per-function GRANTs exist to prevent it.
- **Each function calls `auth-verify` over HTTP** — rejected. A second network hop on every request, and a new internal authentication problem to solve.
- **A JWT authorizer** — rejected. It validates the token but cannot read `users`, so it delivers claims and not the row, which is the half that was never the problem.
- **An eighth Lambda as the authorizer** — rejected on cost: an eighth role, credential and secret for one query.

## Consequences

- **`withEnvelope` no longer verifies tokens.** Fourteen routes read the authorizer context. The behaviour moved to `withVerifiedToken`, used by exactly one route.
- **A route detached from the authorizer fails closed**, with a 500 naming the misconfiguration rather than a 200.
- **The authorizer runs on every request**, so `auth-verify` is now the hottest function and a Data API round-trip sits in front of every call. With TTL 0 there is no cache to soften it.
- **`resolveCaller`'s stub is gone.** `lookupCaller` and `provisionCaller` replace it, and the `Caller` handed to a domain handler now carries real values.
- **A-159 is superseded, not deleted.** Its reasoning was sound given what it knew; A-163 had already corrected its premise, and this record corrects its conclusion.

## Related Missions

- Mission 6.5 — which needed this and produced it.

## Implementation Status

**Implemented and applied to development.**

| | Decision | State |
|---|---|---|
| REQUEST authorizer | Required | ✅ `vump-dev-caller`, identity source `Authorization` |
| Served by `auth-verify` | Required | ✅ one function, discriminated by event shape |
| 14 routes behind it | Required | ✅ **verified against live AWS**, per-method |
| ~~Exactly one exempt~~ **Two named routes exempt** | Required | ✅ `POST /v1/auth/verify` verified live. `POST /v1/auth/redeem` added by the amendment below |
| The exemption enforced by CI | Intended | ❌ **No.** A `check` warns during `plan`; CI runs no `plan`. Gap 16 — **unchanged by the amendment** |
| Zero new secrets | Required | ✅ 8 before, 8 after |
| `org_id` no longer a claim | Supersedes A-159 | ✅ read from `users` |
| Deny is explicit | Required | ✅ 403 with an explicit-deny body |
| Live round-trip | — | ✅ 403 → 200 (row created) → 200 |
| Called by the mobile app | — | ⬜ **Not wired.** No app code calls either route yet |

---

## Amendment — Mission 7.6: the exemption becomes a two-route allowlist

**Status: Accepted. Supersedes this record's "Exactly one route is exempt" section.**

### What changed

`POST /v1/auth/redeem` is exempt from the REQUEST authorizer. The exempt set is now:

```
POST /v1/auth/verify
POST /v1/auth/redeem
```

### Why the original reasoning requires it rather than merely permits it

ADR-036 put invite-code redemption in a Cloud Function and recorded that the arrangement was temporary. Mission 7.6 retires it into `POST /v1/auth/redeem`, and that route **creates the Firebase account**. Its caller therefore has no token, no `users` row, and no Firebase identity of any kind.

This is the same condition that produced the first exemption, one step earlier in the same sequence:

| Route | The caller has | The route produces |
|---|---|---|
| `POST /v1/auth/redeem` | nothing | a Firebase account with claims |
| `POST /v1/auth/verify` | a token, no `users` row | the `users` row |
| everything else | both | — |

The authorizer refuses a caller with no `users` row. Putting redeem behind it would make the route unreachable by exactly the callers it exists for — verbatim the argument A-166 records for `/auth/verify`, and it holds here a fortiori: a redeem caller does not even have a token to present.

**So the count was never the property.** "Exactly one" was true of the system as it stood, and this record mistook a fact about the route inventory for a rule about authentication. The real rule is that a route may bypass the authorizer **only if the authorizer would refuse every legitimate caller of it**, and that is a statement about two routes now.

### The check is a set match, not a relaxed count

```hcl
condition = length(local.authorizer_exempt) == 2 && length(setsubtract(
  toset(local.authorizer_exempt),
  toset(["POST /v1/auth/verify", "POST /v1/auth/redeem"]),
)) == 0
```

**Deliberately not `length(...) <= 2`.** A count-based check lets a third exemption pass by deleting one of the two — it would be satisfied by an exempt set of `["POST /v1/auth/redeem", "GET /v1/projects"]`, which is precisely the failure it exists to prevent. The property worth guarding is *these named routes and no others*; the number is a consequence of the list, not the test.

Widening this list is a security decision that requires an ADR change, and the two-sided condition is what makes an edit that skips one show up as a plan failure rather than as a route quietly opening.

### What did not change

- **Fourteen routes remain behind the authorizer.** The API serves sixteen routes now; the authorizer count is unchanged because both exemptions are unauthenticated by construction.
- **Gap 16 is unchanged and remains open.** The check still runs only at `plan`, a failed `check` is still a warning rather than an error, and CI still runs no `plan`. Adding a second exemption does not weaken that further, but it does raise what the gap is worth: the allowlist now has two entries, and an unreviewed third would be the first one nobody had to argue for.
- **`withVerifiedToken` still serves exactly one route.** Redeem verifies nothing, so it needs a third wrapper rather than that one — see Mission 7.6 Phase 3.

### Related

- ADR-036 — the decision this retires, and the reason redeem exists as a route at all.
- A-166 — the deadlock that produced the first exemption.

