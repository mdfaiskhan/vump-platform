# ADR-036 — Invite-Code Redemption Runtime

- **Status:** Accepted
- **Date:** 2026-08-13
- **Supersedes:** none. Adds a **temporary** second backend runtime alongside ADR-015, retired at Mission 6/7. Unblocks A-051.

## Context

`AuthRepositoryImpl._redeemInviteCode` throws an `UnimplementedError`. ADR-034 recorded why, and named the three things missing: a redemption endpoint, an Admin surface that issues codes, and a way to set `role` and `org_id` for an account nobody provisioned. A-051 registered self-service sign-up as a product change the project owner asked for and left it blocked on exactly those.

**The blocking constraint is where a custom claim can be written from.** Volume 4 Chapter 4.7 §2 sets `role` as a Firebase custom claim *"at account provisioning time… not read from a request body — a client can never claim its own role"*, and A-052 added `org_id` alongside it. Writing a custom claim requires a privileged credential that can act on the Firebase project. A device cannot hold one, so redemption is server-side by necessity, not by preference.

**`backend/` is empty.** ADR-015 fixes the runtime as AWS Lambda with Node and TypeScript behind API Gateway, and Volume 4 Chapter 4.6 §2 defines exactly two auth routes — `POST /v1/auth/verify` and `GET /v1/users/me`. Neither redeems anything, and none of it is built. Waiting for the real backend means sign-up stays blocked through Missions 3, 4 and 5.

The project owner has decided to build redemption now and accept the throwaway cost. This record exists so that decision is legible later, when someone finds a Firebase Cloud Function in a repository whose accepted runtime decision says AWS Lambda.

## Decision

### One HTTPS callable Cloud Function, doing exactly one job

`redeemInviteCode(code)` — validate a code, consume one use, set the caller's claims. Nothing else goes in this runtime. It is not a general-purpose backend and must not accumulate one; every other endpoint belongs to ADR-015's Lambda.

**The caller's `uid` comes from the verified auth context, never from the request body.** A callable function receives `request.auth.uid` already verified by the SDK. Accepting a uid as a parameter would let any signed-in account provision claims for any other — the same rule ADR-034 applies to the role claim, at the only other point where claims are written.

### Firebase Cloud Functions rather than AWS Lambda — and the usual reason for this is wrong

**The premise "only the Firebase Admin SDK can set a custom claim, therefore it must be a Cloud Function" does not hold.** The Admin SDK is an ordinary Node library. It runs on Lambda, and ADR-015 already anticipates that: it lists *"the Firebase Admin SDK for Node"* among the backend's dependencies. Capability is not the discriminator, and stating it as one would leave a real trade-off unexamined.

**The discriminator is what credential each option requires to exist.**

Running the Admin SDK outside Google's infrastructure means authenticating with a **service-account private key**. For this operation that key is the most dangerous credential the system would possess: `setCustomUserClaims` can grant `admin` on any organisation to any account, and a leaked key is a silent, total authorization bypass that no Firestore rule or API-Gateway policy would catch. ADR-016 could hold it in Secrets Manager, and ADR-007 would keep it out of the repository, but a key that exists can be exfiltrated, and this one has no blast-radius limit.

Inside Cloud Functions there is no key. The runtime authenticates as the project's own service account through the metadata server, so the credential is never materialised, never stored, never rotated and never leaked.

**A distinction worth keeping, because it decides the ported design too:** token *verification* does not need this. `verifyIdToken` can be satisfied with Google's public certificates and no secret at all, which is why ADR-015's plan to verify on Lambda carries no such exposure. Writing claims is the operation that needs privilege. When Mission 6/7 ports this, that asymmetry is the thing to preserve — the ported endpoint needs a key that verification never did.

**Conclusion: a Lambda would be worse, and the reason is the private key, not the capability.** Accepting a second temporary runtime is the cheaper of the two costs, because the runtime is disposable and the key would not have been.

### This is temporary. It is retired at Mission 6/7

**Stated plainly so nobody mistakes it for architecture.** ADR-015 remains the backend runtime decision and is unchanged by this record. When the real backend exists, `redeemInviteCode` becomes a `/v1/...` route beside the others, this function is deleted, and this ADR is superseded.

What the port must carry over: the transactional decrement, the server-derived uid, and the claim write. What it must reconsider: how the ported endpoint obtains claim-writing privilege without a long-lived key — Workload Identity Federation from AWS to GCP is the shape that avoids one, and it is not free to set up, which is part of the cost being deferred.

The retirement obligation is recorded here and in the function's own source. It is not tracked anywhere that would prompt anyone, which is the honest weakness of writing it down.

### Firestore holds the codes, and security rules — not the UI — enforce who may write them

The `org_invite_codes` collection mirrors Mission 2.1's `OrgInviteCode` entity field for field: `code`, `orgId`, `expiresAt`, `remainingUses` (null meaning unlimited). The document ID is the code itself, so a lookup is a `get` rather than a query and the uniqueness constraint is the database's rather than a rule someone has to remember.

**Reads are denied to everyone.** A client that could read this collection could enumerate valid codes, which is the whole attack. Only the function — running with Admin privileges, which bypass rules entirely — reads it.

**Writes require the `admin` custom claim**, checked in the rule rather than in the Admin UI. The UI gate is a convenience; the rule is the enforcement, and it holds against anyone with the project's public config and an HTTP client. `request.auth.token.role == 'admin'` is checkable against the signed token with no extra read, so this costs no round trip:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /org_invite_codes/{code} {
      // Nobody reads. Enumeration of valid codes is the attack this
      // collection exists to enable, so the function — which bypasses
      // rules — is the only reader.
      allow read: if false;

      // The claim is set at provisioning time and signed by Firebase, so
      // it cannot be asserted by a client (Volume 4 Ch. 4.7 §2).
      allow create, update: if request.auth != null
        && request.auth.token.role == 'admin'
        && request.auth.token.org_id == request.resource.data.orgId;

      allow delete: if request.auth != null
        && request.auth.token.role == 'admin'
        && request.auth.token.org_id == resource.data.orgId;
    }
  }
}
```

**The `org_id` comparison is the part that matters most** and is easy to omit: without it, any admin could mint codes for another organisation, which defeats BR-20's org scoping (Volume 4 Chapter 4.8 §3) at the point where org membership is granted.

### The decrement is a Firestore transaction, and the read must happen inside it

Two people redeeming the last use must not both succeed. The rule is that the read of `remainingUses` and the write of `remainingUses - 1` occur in one `runTransaction`; Firestore aborts and retries the transaction if the document changed underneath it, which makes the check-then-write atomic rather than merely close together.

```text
runTransaction(tx):
  snap = tx.get(codeRef)                 # inside the transaction, always
  if !snap.exists                     -> AUTH_INVITE_CODE_INVALID
  if snap.expiresAt <= serverTime     -> AUTH_INVITE_CODE_EXPIRED
  if snap.remainingUses == 0          -> AUTH_INVITE_CODE_INVALID
  if snap.remainingUses != null:
      tx.update(codeRef, remainingUses: snap.remainingUses - 1)
  return snap.orgId
# claims are set after the transaction commits — see below
```

**Expiry is compared against the server's clock**, never a timestamp from the caller. A device clock is attacker-controlled.

**A null `remainingUses` means unlimited and is not decremented**, matching the entity's documented meaning rather than treating null as zero.

**The claim write happens after the transaction commits, and that ordering is a real trade-off.** `setCustomUserClaims` is not a Firestore operation and cannot join the transaction, so the two cannot be made atomic. Setting claims first would grant membership on a code that then fails to decrement; decrementing first means a crash between the two consumes a use without granting anything. The second is chosen because it fails closed: the person is not in the organisation, and an admin can issue another code. The first fails open, which is the failure this whole boundary exists to prevent.

**`AUTH_INVITE_CODE_INVALID` deliberately covers both "no such code" and "no uses left".** Distinguishing them tells a caller that a code exists, which is the enumeration signal the read rule already denies.

### Cost

Cloud Functions requires the **Blaze** plan. Its free tier is **2,000,000 invocations per month**; expected volume is one invocation per person joining an organisation — realistically tens per month during onboarding, and zero thereafter. Firestore's free tier likewise dwarfs a collection holding one small document per outstanding code. **The expected bill is zero, and the plan change is what enables billing at all rather than a charge being incurred.**

## Alternatives Considered

- **AWS Lambda with a Firebase service-account key.** Rejected, for the credential and not the capability — see the Decision. It keeps one runtime and introduces a long-lived key that can grant `admin` on any organisation.
- **Wait for the real backend at Mission 6/7.** Rejected by the project owner. It keeps sign-up blocked through three intervening missions, and the throwaway cost is one small function and its rules.
- **Validate the code client-side against a Firestore read.** Rejected outright. It requires clients to read the collection, which is exactly the enumeration this design denies, and a client cannot set its own claims regardless — it would be security theatre in front of an operation that still has to happen server-side.
- **Store codes in the local Isar database or in Remote Config.** Rejected. Neither is transactional across devices, and a use count that is not atomic is not a use count.
- **Have the function create the account as well as redeem the code.** Rejected. It duplicates the sign-up `firebase_auth` already performs on-device, and it would put password handling in a function that has no reason to see one.
- **A `remainingUses` of null meaning zero rather than unlimited.** Rejected — it contradicts Mission 2.1's entity, where the field is nullable precisely so unlimited is expressible.
- **Denying `delete` entirely, so codes are only ever exhausted.** Considered and not taken. An admin who mis-issues a code needs to revoke it, and expiry alone can be days away.

## Consequences

- **A second backend runtime exists, and the repository now contradicts ADR-015 unless read together with this record.** That is the cost the owner accepted. ADR-015 is unchanged and still governs everything else.
- **A retirement obligation exists with nothing to enforce it.** No CI check can detect that Mission 6/7 has happened. If the port is forgotten, a Cloud Function silently becomes permanent architecture — the failure mode this ADR's own existence is the only guard against.
- **The project gains Firestore**, which no other part of the application uses. ADR-009 chose Isar for local persistence and that is untouched; this is a server-side store the mobile app reaches only through the Admin UI's writes.
- **Two Flutter dependencies follow** — `cloud_functions` and `cloud_firestore` — each needing ADR-030's admission checklist, a confinement entry, and a conversion boundary. `FirebaseFunctionsException` is a distinct type from `FirebaseAuthException`, so whether `FirebaseAuthErrorMapper` extends or gains a sibling is an implementation decision this ADR does not pre-empt.
- ~~Signup becomes reachable in principle, and must stay unreachable in fact.~~ **Overtaken.** Mission 2.7 routed it behind the guard, and amendment **A-056** links it from Login — the sign-up flow is now a first-class entry point.
- **The Firestore location is a one-time, irreversible choice** made when the database is created. It is not a decision this ADR takes, and it should be made deliberately rather than accepted as a console default.

## Related Missions

- Mission 2.1 — the `OrgInviteCode` entity whose fields this collection mirrors.
- Mission 2.2 — ADR-034, which recorded the blocker and A-051.
- Mission 2.6 — Invite-code redemption, which produced this ADR.
- Mission 6/7 — the real backend, which retires it.

## Amendment — Mission 2.10 (2026-08-13): the function creates the account

**Status of this amendment: Accepted.** It changes what `redeemInviteCode` does, not where it runs.

### What changed, and why

Mission 2.9's security review found an email-enumeration oracle (**F1**) created by the ordering this ADR originally described. `AuthRepositoryImpl` created the Firebase account *first* and redeemed the code *second*, so an unauthenticated caller at the public `/signup` route could assert any email address and read the answer from which error came back:

- a registered address returned `AUTH_EMAIL_ALREADY_IN_USE` — *"An account already exists for this email"*
- an unregistered address created an account, failed redemption, deleted it again, and returned `AUTH_INVITE_CODE_INVALID`

No valid invite code was needed to run the probe. That defeats, on the sign-up path, exactly the property ADR-034 records Firebase preserving on the sign-in path — the collapse of `wrong-password` and `user-not-found` so *"a caller cannot learn whether an account exists"*.

**`redeemInviteCode` now takes `{code, email, password}` and does the whole thing server-side.** It validates the code first and creates the account only if the code was good, inside the same transaction discipline as before. An invalid or expired code touches nothing: no account is created, so none has to be deleted, and the caller gets one indistinguishable error whichever case it was.

### The caller has no identity, which is the point

The original design took the uid from `request.auth`, on the reasoning that a client must never name the account to provision. That reasoning is unchanged and is now satisfied more strongly rather than less: there is no account yet, so there is no uid to assert. The function creates the user itself and sets the claims on the user it just created, so the identity is server-chosen end to end.

Sign-up is therefore the one unauthenticated entry point in this runtime. **Amendment A-056 (2026-08-14) made the invite code optional**, so it no longer gates that entry point: an account without a code joins a default organisation as a Collector. What bounds the exposure instead is that no self-signup path can produce an admin, and a new Collector has no Task assigned to them.

### The compensating delete is retired for this path

Mission 2.6 added a delete-on-failed-redemption because the old ordering could leave an orphaned account holding an address its owner could not use or reuse. With validation first, nothing is created to orphan. `_discard` and its logging are removed from the email/password path.

### This does not reopen the Cloud Functions versus Lambda decision

Stated explicitly so it is not left ambiguous. The original decision turned on **what credential each runtime requires to exist**: running the Admin SDK outside Google means holding a service-account private key that can grant `admin` on any organisation, while inside Cloud Functions the runtime authenticates through the metadata server and no key exists.

Creating a user is `getAuth().createUser` — the same Admin SDK, the same credential, the same runtime. The responsibility expands; the privilege does not. Every word of the original reasoning holds, and the retirement obligation at Mission 6/7 is unchanged.

### Google sign-up does not follow this pattern, and does not need to

**Traced before assuming, because the shapes genuinely differ.**

`signUpWithGoogle` has no password to send. The identity comes from Google, and `FirebaseAuth.signInWithCredential` creates the Firebase account as a side effect of the first federated sign-in — the account exists before any code of ours runs.

**F1 does not reach that path, for a structural reason rather than a lucky one.** The enumeration oracle exists because email/password sign-up lets a caller *assert* an arbitrary address. Google sign-up requires *authenticating as* the identity in question: probing whether `someone@example.com` is registered would mean holding that person's Google account. An attacker learns only about accounts they already control.

So the Google path keeps client-side sign-in followed by server-side redemption, and **keeps its compensating delete**, which still has something to compensate for: a rejected code after a federated sign-in does leave a real account behind.

A symmetric server-side-first design is available — the client would send the Google ID token, the function would verify it and link the provider — and is deliberately not built. It closes no open finding, adds token verification to a runtime ADR-036 confines to one job, and the runtime is retired at Mission 6/7 regardless.

### Two other Mission 2.9 findings closed in passing

**F3 (unvalidated input reaching Firestore)** is closed by the same rewrite.
`normaliseCode` now enforces an alphanumeric character set and a length bound
before `.doc()` is called, so a code containing `/` — which Firestore reads as
a path segment rather than a key — is rejected as `VALIDATION_INVALID_INPUT`
instead of throwing an unhandled `internal`. Volume 8 §8.3 §2 asks for exactly
this: validation "before touching the database".

**F2 (no rate limiting)** is *not* closed and is now marginally more exposed:
the endpoint is unauthenticated by design, where before it required a Firebase
account. The mitigating factor is unchanged — a code is ~49 bits — but the
divergence from Volume 8 §8.3 §1, which rate-limits every other endpoint,
stands and is worth closing on its own terms.

### Passwords now transit the function

A cost the original design did not carry, recorded rather than left implicit. The password reaches `getAuth().createUser` over HTTPS inside Google's infrastructure — the same trust boundary Firebase Authentication already occupies — but it is now a value this project's own code holds in memory. It is never logged, never echoed in an error, and never written to Firestore. The function logs `uid` and `orgId` only.

---

## Implementation Status

**Implemented and deployed to `vump-platform-f86af`, which is now the development environment.**

Mission 6.4 created `vump-staging` and `vump-prod` and released `firestore.rules` to both. `redeemInviteCode` is deployed **only** to `f86af` and remains so. Staging and production have no Auth and no billing, so functions cannot deploy to them — and deliberately will not until a release branch is cut (ADR-014). That is the intended state, not a gap.

`f86af` was originally to be retired in favour of a new `vump-dev`; Mission 6.4.2 reversed that and deleted `vump-dev` instead. The deployment recorded here was therefore never interrupted. Amendment A-162.

The function's behaviour is unchanged and deliberately so — it still sets `role: "collector"` from a literal and still uses `org_id: "vump-default"`. Mission 6.4 multiplies the deployment sites; it does not fix the organisation model, and A-163 corrects A-159's claim that the `org_id` claim was unimplemented. Deferred item 12.

| Artefact | Where |
|---|---|
| `redeemInviteCode` | `functions/src/index.ts` — v2 callable, `asia-south1`, Node 22 |
| Security rules | `firestore.rules`, deployed and live |
| Deployment config | `firebase.json`, `.firebaserc` at the repository root |
| Issuing | `features/auth/data/invite_code_repository_impl.dart` |
| Admin surface | `features/auth/presentation/admin_invite_codes_screen.dart`, route `/admin/invite-codes` |
| Redemption client | `AuthRepositoryImpl._redeemInviteCode` — no longer throws |

**Verified against the live project, not asserted:**

| Check | Result |
|---|---|
| `firebase deploy --only firestore:rules` | rules compiled and released |
| `firebase functions:list` | `redeemInviteCode` · v2 · callable · asia-south1 · nodejs22 |
| Unauthenticated Firestore **read** of `org_invite_codes` | **403 `PERMISSION_DENIED`** |
| Unauthenticated Firestore **write** to `org_invite_codes` | **403 `PERMISSION_DENIED`** |
| Unauthenticated call to `redeemInviteCode` | **401**, `details.errorCode = AUTH_UNAUTHENTICATED` |
| Artifact Registry cleanup policy | set for `asia-south1`, images older than 1 day |
| `flutter analyze` / `flutter test` | clean / all passing |
| Package confinement | 8 of 8, including the two added here |

The three probes are the ones worth keeping: they exercise the deployed rules and the deployed function rather than the files that describe them, and the last confirms the error contract this application's mapper depends on arrives intact over the wire.

### One design point this ADR did not anticipate

**Account creation has to precede redemption, which reverses the ordering Mission 2.2 documented.** That code redeemed first so a rejected code left nothing behind. It cannot work: redemption sets a custom claim, so it needs an authenticated caller to set it on, and the uid is taken from the verified auth context rather than the payload. There is no account to name until one exists.

The orphaned account that ordering avoided is therefore real again, and is compensated rather than accepted — a failed redemption deletes the account it just created, so the person can retry instead of finding their address taken by an account they cannot use. If that delete also fails, it is logged as an error naming the consequence; it is not swallowed.

**A second consequence follows and is easy to miss:** `setCustomUserClaims` writes on the server, and the ID token the device holds was minted before it. Without forcing a refresh, `_toUser` reads no `role` and rejects the account it has just provisioned. `getIdToken(true)` closes that window.

### Deliberately not done

~~**`SignupScreen` is still unrouted and unlinked.**~~ **Overtaken twice:** Mission 2.7 routed it once the guard existed, and A-056 linked it from Login. Both steps are recorded where they were taken.

### Cost, as deployed

Blaze is active. Cloud Functions' free tier is 2,000,000 invocations per month against an expected volume of tens; Firestore holds one small document per outstanding code. The one real cost risk was container images accumulating in Artifact Registry, which the cleanup policy now bounds. **Expected bill remains zero.**
