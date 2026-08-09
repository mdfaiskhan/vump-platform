# ADR-013 — Legal Hold Enforcement

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Resolves a contradiction within Volume 8, Chapter 8.7 — see `docs/architecture/volume-amendments.md`.

## Context

Volume 8, Chapter 8.7 makes two statements that cannot both be true.

**§3, Legal Hold:** any Project, Session or chunk can carry a `legal_hold_at` timestamp, and "while set, it is excluded from every automated deletion/lifecycle job in Sections 1 and 4, regardless of age."

**§4, Deletion Mechanics:** "native S3 lifecycle rules (Volume 4, Chapter 4.10) handle the storage-class transitions and eventual object expiration automatically — no custom deletion Lambda needed for the video files themselves."

An S3 lifecycle rule evaluates object age, size, prefix and tags. **It cannot read a column in Aurora.** A bucket-wide expiration rule built as §4 describes will delete objects that §3 says must never be deleted, on schedule, silently, and irreversibly.

This is not a documentation infelicity. It is a latent data-loss path in a system whose purpose is retaining evidentiary field recordings, and it would fire two years after the first capture — long after anyone remembered writing the rule.

The contradiction was found in Mission 0.17.6 while preparing lifecycle rules. It is being recorded now rather than at implementation time because the safe interim position — no expiration rule at all — needs to be a deliberate decision with an owner, not an omission.

## Decision

### Legal hold is enforced in S3, not only in the database

The `legal_hold_at` column in Aurora remains the **system of record** for who placed a hold and when, and remains the trigger for an `audit_log` entry per Volume 8.7 §3. It is not, and cannot be, the enforcement mechanism for object expiry.

Enforcement is a property of the object in S3.

### Object Lock is deferred until the production compliance review

**S3 Object Lock is not adopted today.** It is the strongest available mechanism — an object under an Object Lock legal hold cannot be deleted by a lifecycle rule, an API call, or an account administrator lacking `s3:BypassGovernanceRetention` — but adopting it now would be premature on two counts.

It is a **one-way door**: Object Lock cannot be disabled once enabled on a bucket. And its real driver is compliance, not engineering — whether hold integrity must be *demonstrable to a third party* is a question a client contract answers, not one this record can.

Object Lock is therefore **deferred until the production compliance review**, alongside the legal review Volume 8.7's own preamble already requires.

### The current implementation must stay Object-Lock-compatible

Deferring is not the same as foreclosing. Nothing built before the compliance review may make Object Lock harder to adopt afterwards. Concretely:

- **Versioning stays enabled on every bucket.** Object Lock requires it. Disabling versioning on any bucket would close the door.
- **Legal hold state is expressed per object, not only in Aurora.** When enforcement is implemented it uses an S3 object tag (`legal_hold=true|false`), which maps onto an Object Lock legal hold later without changing how the application places or clears a hold.
- **Placing and clearing a hold goes through one code path**, so swapping tag operations for Object Lock API calls is a change in one place rather than everywhere a hold is set.
- **The `legal_hold_at` column in Aurora remains the system of record** for who placed a hold and when, and remains the trigger for the `audit_log` entry required by V8.7 §3. That is unaffected by which S3 mechanism enforces it.

**Open question for the compliance review:** whether Object Lock can be enabled on the existing `vump-platform-*` buckets, or whether adoption requires new buckets and a migration. Historically it was settable only at bucket creation. This is cheap to answer while the buckets are empty and expensive once production holds footage — worth resolving early even though adoption itself is deferred.

### Interim enforcement: object tagging

Until Object Lock is adopted, legal hold is enforced by **S3 object tagging**, which any expiration rule filters on.

Its two weaknesses are accepted knowingly, and both are reasons the compliance review matters: an object written without the tag would never expire, and any principal holding `s3:PutObjectTagging` can clear a hold without the storage layer objecting. Object Lock is what closes both.

### Until enforcement exists, nothing expires

**No expiration rule is applied to production.** ADR-012 implements storage-class transitions only, which never delete.

This is why the two records are separate: the lifecycle work proceeds and delivers its cost saving, while the irreversible half waits for a mechanism that can honour a hold.

### Enabling expiration is gated

The production expiration rule from Volume 8, Chapter 8.7 §1 may be enabled only when all four hold:

1. Tag-based enforcement is implemented and **every** write path sets the tag — including the presigned-URL flow, where the tag must be a signed header rather than client discretion.
2. Placing and clearing a hold is verified end to end, including the `audit_log` entry required by V8.7 §3.
3. A held object is **demonstrated** to survive a lifecycle evaluation that would otherwise expire it — tested, not reasoned about.
4. Volume 8.7's durations have passed the legal review its own preamble requires.

## Alternatives Considered

- **Implement §4 literally — bucket-wide expiration, hold tracked only in Aurora** — rejected. It is the data-loss path this record exists to prevent.
- **A custom deletion Lambda that consults Aurora** — the honest alternative, and the one §4 explicitly rules out. It would work: a scheduled job selects expired chunks without an active hold and deletes those objects. Rejected as the primary mechanism because it moves the guarantee from the storage layer into application code, where a query bug deletes evidence. It remains the fallback's fallback if neither Object Lock nor tagging is workable.
- **Never expire raw video** — rejected. It contradicts V8.7 §1 and grows cost without bound; 24 months of multi-hundred-megabyte chunks is the dominant storage line item.
- **Adopt Object Lock now, in governance mode** — deferred rather than rejected. It is the strongest mechanism and remains the intended destination, but it is a one-way door driven by a compliance requirement that has not yet been established.
- **Object Lock in compliance mode** — rejected even as a future option. Compliance mode cannot be overridden by anyone, including the account root, for the retention period. Correct for regulated financial records; too rigid here, where a client contract may legitimately require early deletion.
- **Rely on the 24-month horizon and decide later** — rejected in substance, accepted in timing. The horizon is real, which is why implementation can wait; but an unrecorded decision would simply be rediscovered as an incident.

## Consequences

- Legal hold becomes enforceable where it matters — in the storage layer, at the moment of deletion.
- Volume 8, Chapter 8.7 §4's "no custom deletion Lambda needed" remains true under tagging and stays true under Object Lock later. Only the rejected Lambda alternative would have made it false.
- **Production retains raw video indefinitely until this is implemented.** Storage cost grows accordingly. This is a known, temporary, cost-only consequence — the opposite trade to the alternative, which was cost saving at the risk of destroying evidence.
- Every object write path must participate by setting the `legal_hold=false` tag on upload. The presigned-URL flow in Volume 4, Chapter 4.10 §2 must be checked, because the mobile client performs the actual `PutObject` and cannot be trusted to set a tag correctly — the tag belongs in the presigned URL's signed headers, not in client discretion.
- Placing a hold becomes a two-part operation: the Aurora timestamp and the S3 state. They can diverge, so reconciliation between them needs monitoring.
- Object Lock remains available as a later upgrade precisely because versioning stays on and hold state is already per-object. Deferring costs nothing structural; it only postpones the stronger guarantee.
- Until Object Lock is adopted, hold integrity depends on IAM discipline around `s3:PutObjectTagging` rather than on the storage layer. That is the gap the compliance review exists to close.

## Related Missions

- Mission 0.17.6 — AWS Documentation Reconciliation, which found the contradiction.
- Mission 0.17.7 — AWS Documentation Alignment, which produced this ADR.

## Implementation Status

**Not implemented.**

| | Architecture decision | Current infrastructure |
|---|---|---|
| Legal hold exists as a concept | Yes — V8.7 §3 | ✅ Unchanged |
| Aurora `legal_hold_at` as system of record | Yes | ❌ Schema not yet built |
| Per-object enforcement in S3 | Yes — tagging now | ❌ Not implemented |
| Object Lock | **Deferred to production compliance review** | ❌ Not enabled |
| Versioning (Object Lock prerequisite) | Must stay enabled | ✅ Enabled on all buckets |
| Production object expiration | 24 months (V8.7 §1) | ❌ Withheld until enforcement exists |

Production currently retains every object indefinitely, which is the intended safe state.

Carried into the compliance review: **can Object Lock be enabled on the existing `vump-platform-*` buckets, or does adoption require new buckets and a migration?** Cheap to answer now while they are empty.
