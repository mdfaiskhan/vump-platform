# ADR-011 — S3 Storage Architecture

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Amends Volume 4, Chapter 4.10 §1 — see `docs/architecture/volume-amendments.md`.

## Context

Mission 0.17 provisioned the S3 foundation and immediately exposed a gap between the architecture volumes and what exists in AWS. Volume 4, Chapter 4.10 §1 names the buckets `human-archive-{env}`; the buckets that exist are `vump-platform-{env}`. S3 bucket names are immutable, so one of the two is wrong and it is not the infrastructure.

Underneath that is a larger inconsistency. Every architecture volume was written for a project called **Human Archive**. The repository, `CLAUDE.md`, the Flutter application, the Firebase project (`vump-platform-f86af`) and now the AWS account all say **Vump Technologies**. Left unresolved, every future AWS resource, IAM role and CloudFormation stack inherits the same ambiguity, and each one is harder to rename than the last.

The volumes are distributed as PDFs and cannot be edited in this repository. This record and its siblings are therefore the binding statement of the storage architecture; the volumes are corrected at their source against the amendment register.

## Decision

### Canonical name

**Vump Technologies** is the canonical project and product name. "Human Archive" is a legacy working title retained in the Volume 1–9 PDFs.

Every AWS, Firebase and repository resource uses `vump` or `vump-platform`. No resource is renamed to match the volumes.

### Bucket naming and layout

One bucket per environment, exactly as Volume 4, Chapter 4.9 §4 and 4.10 §1 require. Only the name changes:

```
vump-platform-dev
vump-platform-staging
vump-platform-prod
```

Volume 4, Chapter 4.10 §1's `s3://human-archive-{env}/` is superseded by `s3://vump-platform-{env}/`.

### Object key schema — unchanged and authoritative

Volume 5, Chapter 5.14 §1 remains the authoritative definition. It is correct, is implemented on both the client and backend sides, and this record changes nothing about it:

```
{org_id}/{project_id}/{task_id}/{session_id}/{sequence_index:04d}_{chunk_id}.mp4

org_9f2/proj_4a1/task_7c3/sess_e810/0003_chk_5b2a.mp4
```

Keys are ID-based, root-level and org-first. There is no top-level category prefix, and none is introduced.

### Chunk buckets hold chunks and nothing else

A consequence of the key schema, and now a rule. Because keys begin at `{org_id}/` with no common prefix, **every lifecycle rule on these buckets is necessarily bucket-wide.** Introducing a second class of object — AI inference output, annotation exports, thumbnails — would place it under the same lifecycle policy as raw footage, or force a retrofit of the key schema that Volume 5.14 §3 fixed for collision-proofing.

### Derived data — reserved for future architecture

Storage for AI inference output, annotation data and exports is **reserved for future architecture**. No bucket, prefix or layout is decided here.

This is deliberate restraint rather than an oversight. Volume 5 §3 places transcoding and thumbnail generation outside MVP, so no such data exists and no consumer of it exists. Designing its storage now would mean inventing an infrastructure decision for a feature whose requirements are unknown — and an S3 layout is expensive to change once written to.

What *is* decided, above, is the constraint that will shape it: these buckets carry a single bucket-wide lifecycle policy, so a second object class cannot simply be added alongside chunks. The decision is deferred; the constraint on it is recorded.

### CloudFront

CloudFront is **part of the production architecture** and is provisioned during Mission 0.17.

It may remain unused until media delivery requires it. Provisioning it now rather than at first need is deliberate: a distribution, its Origin Access Control, and the bucket-policy grant that pairs with them are a coherent unit, and retrofitting a CDN in front of a bucket that already has a settled access policy means revisiting that policy under delivery pressure. Standing the distribution up while the buckets are empty costs almost nothing and removes that future coupling.

Two properties must hold from the outset, because they are far harder to add later than to start with:

- **Origin Access Control, not public objects.** The bucket keeps Block Public Access enabled; CloudFront reaches the origin through OAC, and the bucket policy grants only that distribution.
- **Presigned URLs remain the access path for chunk upload and retrieval**, per Volume 4, Chapter 4.10 §2 and §3. CloudFront does not replace them and does not become a second unauthenticated route to evidentiary footage. Signed URLs or signed cookies gate any delivery path that is added later.

Volume 4 does not mention CloudFront at all. Amendment A-009 records that the volumes must be updated to include it.

### Region

All environments are in **`ap-south-1` (Mumbai)**.

A single region for all three environments, so staging exercises the same latency and the same regional service availability as production. No volume specified a region; this record fixes it.

**Data residency.** Recordings of identifiable people are stored in India. This constrains Volume 8, Chapter 8.6's privacy commitments, which must state the storage location, and it is a term any client contract with a residency clause will be read against. A later requirement to store a client's data elsewhere means a second bucket in that region, not a migration of this one.

CloudFront is global by nature and serves from edge locations worldwide; the origin remains `ap-south-1`. If a contract restricts where data may be *served* as well as stored, the distribution's geographic restrictions are the control, not the origin region.

### Encryption and access — confirmed as built

- **SSE-S3.** Volume 8, Chapter 8.4 *decides* this, rather than treating it as a placeholder. SSE-KMS with a customer-managed key is an upgrade triggered only by a client contract requiring key-level audit. The current configuration is correct and must not be "upgraded" without that trigger.
- **Block Public Access on, ACLs disabled.** Matches Volume 4, Chapter 4.10 §3 — "no public access at all".
- **Versioning enabled.** Not required by any volume; adopted deliberately as protection against accidental overwrite. ADR-012 owns the noncurrent-version cost this creates.

### Environment isolation

**Current implementation:** a single AWS account containing all three environment buckets.

**Target architecture:** separate AWS accounts for Development, Staging and Production, per Volume 4, Chapter 4.9 §4's stated preference.

**Migration:** deferred until production scale.

Volume 4, Chapter 4.9 §4 permits the current arrangement — "at minimum, separate VPCs/Aurora clusters and S3 buckets" — so this is a compliant intermediate state, not a deviation. What it costs is blast radius: in a single account, a misapplied IAM policy or lifecycle rule can reach production data from a development context.

ADR-014 owns the environment model and the promotion path between them.

## Alternatives Considered

- **Rename the buckets to match the volumes** — impossible. S3 bucket names are immutable; it would mean creating new buckets and copying, for a name that is itself the outdated one.
- **Adopt "Human Archive" as canonical and rename the repository, Firebase project and AWS resources** — rejected. It inverts the cost: renaming live cloud resources and a codebase to match documents is far more expensive than correcting documents, and `CLAUDE.md` already names Vump Technologies as the project.
- **Introduce a `raw/` prefix so lifecycle rules can be scoped** — rejected. It contradicts the authoritative key in Volume 5.14, would invalidate the deterministic-key guarantee that BR-11 rests on, and orphans any object already written.
- **A single bucket with environment prefixes** — rejected. Contradicts Volume 4.9 §4, and makes least-blast-radius IAM boundaries impossible to express.
- **Defer CloudFront until a media-delivery feature needs it** — rejected. It has no MVP consumer today, but provisioning it later means reopening a settled bucket policy under delivery pressure. Standing it up now, unused, is cheaper than retrofitting it.
- **Public objects or a public bucket behind CloudFront** — rejected outright. Volume 4.10 §3 requires no public access; Origin Access Control keeps Block Public Access on and grants only the distribution.
- **Design derived-data storage now** — rejected. Volume 5 §3 places that work outside MVP; an S3 layout invented before its consumer exists is expensive to correct once written to.

## Consequences

- AWS resource naming is settled; every later resource follows `vump-platform-*` without re-deciding.
- Volume 4, Chapter 4.10 §1 is now wrong at its source and must be corrected there. The amendment register lists it.
- Lifecycle rules cannot be prefix-scoped. ADR-012 is written accordingly.
- Derived and annotation data have no storage layout, by design. The gap is reserved rather than filled, and the bucket-wide lifecycle constraint that will shape it is recorded.
- CloudFront exists in production from Mission 0.17 and may sit unused. It carries a small standing cost and must be included in access logging, alarms and the validation checklist even while idle — an unmonitored distribution is a route into the origin that nobody is watching.
- Running three environments in one account is a compliant intermediate state, not a permanent one. ADR-014 owns the target model; migration is deferred until production scale.
- The volumes and this repository now disagree in writing. The amendment register is what keeps that disagreement tracked rather than latent.

## Related Missions

- Mission 0.17.5 — S3 Environment Buckets, which created the buckets.
- Mission 0.17.6 — AWS Documentation Reconciliation, which produced the mismatch register.
- Mission 0.17.7 — AWS Documentation Alignment, which produced this ADR.

## Implementation Status

**Partially implemented.**

Buckets exist with versioning, Block Public Access, ACLs disabled and SSE-S3 — all consistent with this record.

| | Architecture decision | Current infrastructure |
|---|---|---|
| Bucket naming | `vump-platform-{env}` | ✅ Applied |
| Key schema (V5.14) | Authoritative, unchanged | ✅ No object written yet |
| SSE-S3 | Per V8.4 | ✅ Applied |
| Block Public Access | No public access | ✅ Applied |
| Versioning | Enabled | ✅ Applied |
| CloudFront + OAC | Part of production architecture | ❌ Not provisioned — Mission 0.17 |
| Bucket policy / IAM | Least-privilege, HTTPS-only | ❌ Not applied — Mission 0.17.9 |
| Derived-data storage | Reserved for future architecture | ❌ Not designed, by intent |
| Account isolation | Separate accounts per environment | ❌ Single account; migration deferred |
| Region | `ap-south-1` (Mumbai) | ✅ Confirmed |

The region is **`ap-south-1` (Mumbai)**, confirmed in Mission 0.17.9 and recorded above. Amendment A-010 is closed.
