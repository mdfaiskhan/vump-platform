# Mission 7.6 — Retire the Invite-Code Cloud Function

**Handoff, written 2026-08-20 at the close of Phase 5.**

Branch `mission/7.6-retire-invite-function`, 24 commits, pushed, no PR.
Head `5e0f4cc`. Phases 1–5 done. **Phase 6 not started.**

---

## What the mission is

ADR-036 put invite-code redemption in a Firebase Cloud Function and said so
temporarily, for one stated reason: *"running the Admin SDK outside Google means
holding a service-account private key that can grant `admin` on any
organisation."* Mission 7.6 retires that function into `POST /v1/auth/redeem` —
**removing the reason rather than accepting it.** The Lambda reaches Firebase
through Workload Identity Federation and no key exists anywhere.

## State of the world

**Applied and live in `dev`.** The infrastructure described below is running.

| | |
|---|---|
| Route | `POST /v1/auth/redeem`, exempt from the REQUEST authorizer |
| Function | `vump-dev-redeem`, 8th Lambda, 2nd role in the `auth-verify` domain |
| DB role | `vump_redeem`, bootstrapped, holds SELECT + UPDATE on `org_invite_codes` |
| GCP | pool `vump-dev-aws`, SA `vump-dev-redeem@vump-platform-f86af`, custom role `vumpRedeemDev` (17 permissions) |
| Migrations | 0012 applied, 0013 applied |
| Client | redeems over `VumpApi`; `cloud_functions` absent from `mobile/lib/` |
| **Cloud Function** | **still deployed, still on disk in `functions/`** |

## Phase 6 — the only remaining work

Scoped as: delete `functions/`, drop `cloud_functions` and `cloud_firestore`
from `pubspec.yaml`, remove the CI confinement entries, supersede ADR-036.

### It cannot start with deletion. Open item 123 blocks it.

`InviteCodeRepositoryImpl.issue()` is the **only working path for issuing**
invite codes. It writes to Firestore directly, authorised by `firestore.rules`.
Phase 6 drops `cloud_firestore`.

There is no backend route for issuing, and there cannot be one without a
migration: **0012 grants `INSERT` on `org_invite_codes` to no role at all** —
deliberately, which is why seeding a test code needs break-glass `faisal-admin`.

So Phase 6 as scoped removes the mechanism and leaves nothing behind it. Admins
could not mint codes by any path.

**Three pieces are needed, and the third is the real decision:**

1. A route — `POST /v1/orgs/{orgId}/invite-codes`, or similar.
2. A migration granting `INSERT` to whichever principal serves it.
3. **An authorization rule to replace what `firestore.rules` was enforcing:**
   `request.auth.token.role == 'admin'` **and**
   `request.auth.token.org_id == request.resource.data.orgId`.

The tenant check currently lives in a Firestore rule that Phase 6 deletes, and
**BR-20 depends on it.** Deleting the rule without replacing the check is a
tenant-isolation regression, not a cleanup.

Start Phase 6 with a trace/decide on this. Nothing is deleted before it lands.

### Also true of Phase 6

- `functions/` deletion is gated on Phase 5's device proof, which A-226 provides.
  That gate is met.
- ADR-036 is **not** superseded yet. It stops being true when the function is
  deleted; superseding it earlier puts documentation ahead of code.
- CI has confinement entries naming `cloud_functions` / `cloud_firestore`. They
  come out with the packages, not before.

## Open items this mission created

| # | | Blocks |
|---|---|---|
| 119 | No gate compares deployed Lambda code against its source | — |
| 120 | Nothing checks a cross-system binding's two halves agree | — |
| 121 | A permission set built from what a caller *calls* ≠ what those calls *require* | — |
| 122 | Google sign-up with an invite code has never worked (A-224) | — |
| 123 | **No backend issuing route once Firestore is dropped** | **Phase 6** |

Item 122 needs its own trace/decide whenever it is picked up: fixing it means a
server capability that provisions claims for an account that **already exists**,
which is new behaviour and a new authorization question, not a port.

## Amendments written

`A-220` A-195 was never deployed · `A-221` federation applied (corrected in place
by A-222) · `A-222` attribute mapping could never match its binding · `A-223` a
custom role inherits none of a predefined role's floor · `A-224` Google sign-up
has never worked · `A-225` Phase 5 · `A-226` device proof.

## Things that will bite the next session

**Terraform cannot run from an agent shell.** Both AWS profiles chain through an
MFA device. The AWS **CLI** works from a cached STS session for about an hour;
Terraform and the JS SDK resolve credentials differently and cannot use that
cache. Plan and apply are human-run. `faisal-admin` is not a profile on this
machine — anything needing the master DB credential is break-glass.

**The `vump-dev-human-operator` policy update is still pending**, denied by
ADR-049 D-3 as designed. It adds the `db-redeem` secret ARN to a `GetSecretValue`
list. Non-blocking; finish via `faisal-admin` at leisure.

**`npm run format` fails on ~70 files** in `backend/`, on a clean tree. Windows
checks out CRLF, prettier defaults to LF, CI on Linux never sees it. Not caused
by this mission. `npm run verify` cannot pass locally on this machine.

**Bash heredocs truncate past ~150 lines** in the agent shell. Write larger files
with the Write tool.

**`flutter build apk --debug` needs `--flavor dev`** — the flavourless form reads
a stale artefact (A-205).

## Verification standing at close

| | |
|---|---|
| Backend unit | 217 passed, 18 files |
| Mobile | `flutter analyze` clean, 1141 tests, APK builds |
| Terraform | `fmt` clean, `validate` clean |
| Deployed: concurrency race | **PASS** — 1 created, 1 refused, 108ms overlap |
| Deployed: forged key (closes A-220) | **PASS** — A-195's exact refusal |
| Device: real redemption | **PASS** — A-226 |

Test fixtures left in `dev`: invite codes `RACE001` (spent) and `DEVICE01`
(spent); org `Device Proof Org` `00000000-0000-4000-8000-0000000000d1`; Firebase
accounts `cjG0mFDPQeOdNGsh4WdNGbUXap92` and `device-proof-1@example.com`. The
`chunk-hash-probe` Lambdas from Mission 7.3 are also still deployed, marked
`DELETE AFTER F4 IS DECIDED`.
