# ADR-012 — S3 Lifecycle and Retention

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Amends Volume 4, Chapter 4.10 §4 and Volume 8, Chapter 8.7 §4 — see `docs/architecture/volume-amendments.md`.

## Context

Volume 4, Chapter 4.10 §4 fixes the storage-class ladder but states explicitly that "this chapter fixes the mechanism, not the exact day-counts, which are a policy decision". Volume 8, Chapter 8.7 §1 supplies the missing number: raw video chunks are retained 24 months from capture, then deleted.

Three things the volumes do not address have to be settled before any rule can be written.

**Incomplete multipart uploads.** Chunks are multi-hundred-megabyte files uploaded from mobile devices in the field. Volume 5, Chapter 5.12 has Collectors working offline, and Chapter 5.13 gives up automatic retry after six attempts, leaving a chunk Failed until connectivity returns or the Collector taps Retry. Every abandoned attempt leaves orphaned parts that are billed and do not appear in an object listing. No volume mentions them.

**Noncurrent versions.** Versioning was enabled in Mission 0.17.5 and is not required by any volume, so nothing governs the versions it accumulates.

**Environment differences.** Volumes 4 and 8 describe retention for production data. Neither says what dev and staging should do, and applying a 24-month production retention policy to disposable test data is expensive and pointless.

A fourth problem is severe enough to have its own record: Volume 8, Chapter 8.7 §3 and §4 are mutually incompatible on legal hold. **ADR-013 resolves that**, and this record is deliberately written to remain safe until it does.

## Decision

### Storage-class ladder — unchanged

Volume 4, Chapter 4.10 §4's ladder is correct and is adopted exactly:

| Class | From | Rationale (V4.10 §4) |
|---|---|---|
| S3 Standard | 0 days | Recent footage is most likely to be reviewed (FR-ADM-06) |
| S3 Standard-IA | 30 days | Access drops sharply once a session is Complete |
| S3 Glacier Instant Retrieval | 180 days | Long-term retention; metadata stays queryable regardless |

Applied to production only. Transitions never delete, so they are safe under any legal-hold outcome.

**Intelligent-Tiering is rejected**, despite being the usual recommendation for unpredictable access. The volumes describe a *known* access curve — hot for 30 days, cold after 180 — and an explicit ladder expresses that more cheaply than paying Intelligent-Tiering's per-object monitoring fee on millions of chunk objects.

### Object expiration — the policy stands; the rule is not yet enabled

This is the one place where the architecture decision and the current infrastructure deliberately differ, so the two are stated separately.

**Architecture decision.** Raw video chunks are retained for **24 months from capture**, configurable per Project or client contract, then deleted — exactly as Volume 8, Chapter 8.7 §1 specifies. This retention policy is adopted unchanged. It is not under review here and is not weakened by anything below.

**Current infrastructure implementation.** No expiration rule is configured on any production bucket. Objects are retained indefinitely.

**Why they differ.** A bucket-wide expiration rule cannot honour a legal hold recorded in Aurora, so enabling one today would delete held footage on schedule (ADR-013). The gap is safe in one direction only — it over-retains, never under-retains — and it costs storage rather than evidence.

**When they converge.** When ADR-013's enforcement mechanism is implemented and verified. The earliest object does not reach 24 months until two years after first capture, so no retention commitment is missed in the meantime.

Anyone reading this record should take the 24-month policy as settled and the absent rule as a known, tracked implementation gap — not as an unresolved question about how long footage is kept.

### Incomplete multipart uploads — abort after 14 days

**Correctness is unaffected by this value**, which is the point worth recording. Volume 5, Chapter 5.14 §3 makes the object key deterministic, and Chapter 5.13 §4 states that every retry reuses "the exact same deterministic S3 key… and *where possible* the same in-progress multipart upload ID". The upload ID is an optimisation; the key is the guarantee. Aborting an old upload costs re-uploaded bytes, never a duplicate object, so BR-11 holds regardless.

14 days therefore trades storage cost against re-upload cost, and nothing else. It is generous enough for a Collector working offline in the field for a fortnight, short enough that orphaned parts cannot accumulate unnoticed. It is an operational parameter, tunable without architectural consequence.

### Noncurrent versions

| Environment | Retained |
|---|---|
| Production | 90 days |
| Staging | 14 days |
| Development | 7 days |

Safe under BR-11: keys are deterministic, so a noncurrent version can only arise from re-uploading byte-identical content to the same key. Expired delete markers are cleaned up in all environments.

### Environment behaviour

| | Development | Staging | Production |
|---|---|---|---|
| Storage-class ladder | No | No | **Yes** |
| Current-object expiration | 30 days | 90 days | **Never** (pending ADR-013) |
| Noncurrent versions | 7 days | 14 days | 90 days |
| Abort incomplete MPU | 14 days | 14 days | 14 days |
| Expired delete markers | Yes | Yes | Yes |

Dev and staging hold synthetic or disposable data and are expired aggressively; neither gets the ladder, because objects that live 30 or 90 days never reach the 30-day IA transition in a way that saves anything.

**Production never auto-deletes a current object.** That is the invariant this record exists to protect.

## Alternatives Considered

- **Implement the 24-month expiration now, per Volume 8.7 §1** — rejected. It would delete legally-held footage on schedule; see ADR-013.
- **Intelligent-Tiering for all objects** — rejected, as above: a known access curve does not need adaptive tiering, and the monitoring fee scales with object count.
- **Glacier Flexible or Deep Archive at 180 days** — rejected for now. Volume 4.10 §4 names Glacier Instant Retrieval "or deeper, per Volume 8.7". Deeper tiers impose retrieval delays measured in hours, which would make an Admin export (FR-ADM-06) fail in a way the UI has no state for. Revisit if storage cost becomes material.
- **No multipart abort rule** — rejected. Invisible, unbounded, billed.
- **7-day multipart abort** — rejected as too aggressive for offline field collection, though equally correct.
- **Mirror production lifecycle in all environments** — rejected. It would keep disposable test data for 24 months.
- **Prefix-scoped rules** — impossible. ADR-011 records why.

## Consequences

- Production storage cost declines automatically as footage ages, with no operational involvement.
- Dev and staging cannot grow without bound.
- Orphaned multipart parts are bounded at 14 days of accumulation.
- **Production data is currently retained forever.** This is deliberate and temporary, and it is a cost that grows until ADR-013 is implemented. It must not be forgotten simply because it is invisible.
- Volume 8, Chapter 8.7 §4's claim that "no custom deletion Lambda" is needed is not yet true. ADR-013 determines whether it becomes true.
- Adding a second class of object to these buckets would place it under raw-footage lifecycle. ADR-011 forbids it.
- Objects transitioned to Glacier Instant Retrieval carry a 90-day minimum storage charge; deleting one earlier is billed for the remainder. Only relevant once expiration is enabled.

## Related Missions

- Mission 0.17.6 — AWS Documentation Reconciliation.
- Mission 0.17.7 — AWS Documentation Alignment, which produced this ADR.
- Mission 0.17.8 — S3 Lifecycle Rules, which will implement it.

## Implementation Status

**Not implemented.** No lifecycle configuration is applied to any bucket. This record defines what Mission 0.17.8 applies.

| Rule | Architecture decision | Current infrastructure | Applied by |
|---|---|---|---|
| Storage-class ladder (prod) | Standard → IA 30d → Glacier IR 180d | ❌ Not applied | Mission 0.17.8 |
| Abort incomplete MPU | 14 days, all environments | ❌ Not applied | Mission 0.17.8 |
| Noncurrent versions | 90 / 14 / 7 days | ❌ Not applied | Mission 0.17.8 |
| Expired delete markers | Cleaned, all environments | ❌ Not applied | Mission 0.17.8 |
| Dev / staging object expiry | 30 / 90 days | ❌ Not applied | Mission 0.17.8 |
| **Production object expiry** | **24 months (V8.7 §1) — policy stands** | ❌ **Deliberately not applied** | **Blocked on ADR-013** |

Every row except the last is scheduled for Mission 0.17.8. The last is the deliberate divergence described above: the retention policy is decided, the rule is withheld until a legal hold can survive it.
