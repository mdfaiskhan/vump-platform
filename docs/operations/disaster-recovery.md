# Disaster Recovery

What can be recovered, how, how long it takes, and what cannot be recovered at all.

Verified against live AWS on 2026-08-09, account `929570731524`, region `ap-south-1`. Every capability below was checked rather than assumed. Authority: ADR-011 to ADR-016, Volume 4 Ch. 4.9/4.10, Volume 8 Ch. 8.4/8.7, Volume 10 Ch. 10.6/10.7.

---

## Read this first

**Three things are not recoverable today.** Knowing which they are is more useful than any procedure below.

| Scenario | Recoverable? | Why |
|---|---|---|
| Object deleted or overwritten in S3 | ✅ Yes, within the version window | Versioning enabled on all three buckets |
| Lifecycle, bucket policy, IAM misconfiguration | ✅ Yes, minutes | Declared in `infrastructure/`, re-appliable |
| **Region loss (`ap-south-1`)** | ❌ **No** | No cross-region replication configured |
| **Malicious or mistaken permanent version deletion** | ❌ **No** | MFA Delete is **disabled** on all three buckets |
| **AWS account loss or compromise** | ❌ **No** | Single account holds all three environments (ADR-014) |

The first is the designed state. The last three are gaps, registered as amendments A-015 to A-017. None is expensive to close; all are expensive to discover during an incident.

---

## Recovery objectives — PROPOSED, NOT RATIFIED

**No volume states an RTO or RPO.** The closest is NFR-REL-01, *"No recorded footage shall be lost due to an app crash after Stop has been tapped"* — a device-side guarantee, not a backend durability commitment.

The targets below are a proposed operational default, in the same sense Volume 8 Chapter 8.7 proposes retention windows: **they require the project owner's sign-off before they mean anything.** Until ratified, treat them as engineering estimates, not commitments to a client.

| Data class | Proposed RPO | Proposed RTO | Basis |
|---|---|---|---|
| Uploaded chunks (prod) | 0 — no loss | 4 hours | Versioning; S3 durability |
| Chunk metadata (Aurora) | 5 minutes | 4 hours | Aurora PITR, once it exists |
| Infrastructure configuration | 0 | 30 minutes | Declared in the repository |
| Secrets | 0 | 1 hour | Secrets Manager recovery window |
| Mobile release | n/a | 24 hours (Android) / days (iOS) | Volume 10 Ch. 10.7 §3 |
| **Whole-region loss** | **Total loss of prod footage** | **Undefined** | No replication exists |

That last row is the honest state, not a placeholder. It is why A-016 matters.

### The one number that is real

Accidental deletion is recoverable **only while the previous version survives**. ADR-012 sets noncurrent-version expiry, so the recovery window is exact and verified:

| Environment | Recovery window |
|---|---|
| Production | **90 days** |
| Staging | 14 days |
| Development | 7 days |

After that the version is expired and the object is unrecoverable. This is the effective RPO for human error, and it is enforced by lifecycle rules that are live now.

---

## Scenario procedures

### 1. Object accidentally deleted (S3)

Deleting a versioned object does not remove it — it writes a **delete marker**. Recovery is removing that marker.

```bash
# Identify the delete marker
aws s3api list-object-versions --bucket vump-platform-prod \
  --prefix "org_9f2/proj_4a1/task_7c3/sess_e810/" \
  --query 'DeleteMarkers[?IsLatest==`true`].{Key:Key,VersionId:VersionId}'

# Remove it — the prior version becomes current again
aws s3api delete-object --bucket vump-platform-prod \
  --key "<key>" --version-id "<delete-marker-version-id>"
```

**Verify:** `aws s3api head-object --bucket vump-platform-prod --key "<key>"` returns metadata.

**Time:** minutes. **Deadline:** the window above.

### 2. Object overwritten with bad content

Same mechanism, different target — list versions, copy the good one over the current.

```bash
aws s3api list-object-versions --bucket vump-platform-prod --prefix "<key>" \
  --query 'Versions[].{VersionId:VersionId,LastModified:LastModified,Size:Size}'

aws s3api copy-object --bucket vump-platform-prod --key "<key>" \
  --copy-source "vump-platform-prod/<key>?versionId=<good-version-id>"
```

Note: the deterministic key (Volume 5.14) means a retried upload writes the *same bytes* to the same key, so overwrites in production are expected and harmless. A genuinely different payload at the same key indicates a defect, not a routine retry.

### 3. Lifecycle rules deleted or misconfigured

Declared in `infrastructure/aws/s3/lifecycle-{env}.json`. Re-apply:

```bash
aws s3api put-bucket-lifecycle-configuration --bucket vump-platform-prod \
  --lifecycle-configuration file://infrastructure/aws/s3/lifecycle-prod.json
```

`put-bucket-lifecycle-configuration` **replaces** the whole configuration, which makes it a clean rollback rather than a merge.

**The failure to look for:** an expiration rule appearing on production. ADR-013 forbids it until legal-hold enforcement exists. If one is present, remove it immediately — it deletes evidentiary footage on schedule.

### 4. Bucket policy rollback

```bash
aws s3api put-bucket-policy --bucket vump-platform-prod \
  --policy file://infrastructure/aws/s3/bucket-policy-prod.json
aws s3api get-bucket-policy-status --bucket vump-platform-prod   # IsPublic must be false
```

⚠ **Once CloudFront is provisioned, do not use the file above for prod or staging.** It omits the Origin Access Control grant and would silently revoke CloudFront's access. Use `infrastructure/aws/cloudfront/bucket-policy-with-oac.json.tmpl`, rendered by `apply-cloudfront.sh`.

**Lockout is not a risk:** every statement is a conditional `Deny`, verified — no combination locks an administrator out.

### 5. IAM recovery

Policy templates are in `infrastructure/aws/iam/`. **None is applied yet** — no roles exist, because the backend does not exist.

Once applied, recovery is re-rendering and re-attaching. The invariants to re-verify after any IAM change:

- `chunk-registration` has **no** `s3:GetObject` — a presigned URL carries the signer's permissions.
- **No role has `s3:DeleteObject`.** A backend role that can delete a chunk is a backend bug that can destroy evidence.

### 6. Secrets Manager recovery

**Zero secrets exist today** (verified). When they do:

A deleted secret enters a **recovery window** of 7–30 days and can be restored:

```bash
aws secretsmanager restore-secret --secret-id vump/prod/firebase-service-account
```

Past the window, the secret is gone and must be recreated from its source — a new Firebase service account key, or a rotated Aurora credential. Nothing in this repository holds a copy, by design (ADR-016).

**Never use `--force-delete-without-recovery`.** It removes the window that makes this recoverable.

### 7. Environment recovery (rebuild from scratch)

Everything except data is declared in the repository:

1. Create the bucket — name from ADR-011, region `ap-south-1`.
2. Enable versioning, Block Public Access, SSE-S3.
3. Apply lifecycle: `infrastructure/aws/s3/lifecycle-{env}.json`.
4. Apply bucket policy: `infrastructure/aws/s3/bucket-policy-{env}.json`.
5. CloudFront, if applicable: `apply-cloudfront.sh {env}`.
6. Verify with the checklist below.

**Data is not rebuildable.** Steps 1–6 restore an empty environment. For production this is a last resort, not a recovery.

**Constraint:** the bucket name is immutable and already taken by the deleted bucket for a period after deletion. A production rebuild under the same name may not be immediate.

### 8. CloudFront recovery — BLOCKED

CloudFront is **not provisioned**. `CreateDistribution` fails with `AccessDenied: Your account must be verified`, pending an AWS Support case.

One artifact exists: OAC `E1VQWTIQ7EZLC0` for prod, inert without a distribution. `apply-cloudfront.sh` is idempotent and will reuse it once the account is verified.

No CloudFront recovery procedure can be written or tested until then.

### 9. Database backup and restore — DESIGN ONLY

**No Aurora cluster exists** (verified: 0 clusters). Volume 4 Chapter 4.9 specifies Aurora Serverless v2 in a private VPC; **no volume specifies a backup strategy**, which is registered as amendment A-018.

Proposed, pending ratification:

| Control | Proposal |
|---|---|
| Automated backups | Enabled, 30-day retention (Aurora max is 35) |
| Point-in-time recovery | Enabled — gives the proposed 5-minute RPO |
| Manual snapshots | Before every schema migration |
| Snapshot copies | Cross-region, once A-016 is addressed |
| Restore testing | Quarterly, to a scratch cluster |

**Restore procedure** (once the cluster exists): restore to a *new* cluster, never in place — an in-place restore destroys the evidence of what went wrong.

```bash
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier vump-prod \
  --db-cluster-identifier vump-prod-restore-<date> \
  --restore-to-time <iso8601>
```

Then verify row counts and the newest `chunk_metadata` timestamp, repoint the application, and retain the original cluster until the restore is confirmed.

**The asymmetry to understand:** Volume 8 Chapter 8.7 retains metadata for 7 years and video for 24 months. Metadata is the durable record of what was captured once footage is gone, so **metadata loss is the more serious failure**, despite being the smaller dataset.

### 10. Production deployment rollback

Per Volume 10 Chapter 10.7 §3, and it is asymmetric by platform:

- **Android** — halt the staged rollout instantly in Play Console; to revert, release the previous build with a *higher* versionCode. Android has no true downgrade.
- **iOS** — no equivalent halt. The practical rollback is an expedited fix release through App Review.

This is why Chapter 10.6 makes the rollback decision early, while the rollout is small. **Trigger** (Ch. 10.6): crash-free rate more than 0.5 points below the previous version. **Approval** (Ch. 10.7 §4): the project owner, explicitly — one of only two gates that is not automatable.

### 11. Infrastructure rollback

Every AWS configuration is a file in `infrastructure/`; `git revert` then re-apply.

**The gap:** nothing detects drift. A console change is invisible until someone re-runs a script and silently overwrites it — or until an incident. Volume 4 Chapter 4.9 §5 defers the IaC tooling choice to Volume 7. Until then, the verification checklist below is the only detection mechanism, and it is manual.

---

## Incident response flow

```
Detect ─► Contain ─► Assess ─► Recover ─► Verify ─► Record
```

1. **Detect.** Alarm, failed CI, or a report. Note the time.
2. **Contain.** Stop the bleeding before diagnosing. For a credential: **rotate first** (ADR-016) — rewriting history is cleanup, rotation is containment. For a bad release: halt the rollout. For a destructive script: stop it.
3. **Assess.** What is affected, and is data at risk? If yes, the version window is running — that is the clock that matters.
4. **Recover.** The relevant procedure above. Prefer restoring beside the damage rather than over it.
5. **Verify.** The checklist below. A recovery that is not verified is a hypothesis.
6. **Record.** What happened, why, what was done, and what would have prevented it. If a check would have caught it, add the check.

**For any suspected data loss in production, before anything else:** confirm whether the affected objects are under legal hold (V8.7 §3). A held object may not be deleted, and a recovery action that destroys one is worse than the original incident.

---

## Responsibilities

The project is currently one person, so these are roles rather than people — but the distinction matters, because two of them are approvals rather than actions.

| Role | Responsibility |
|---|---|
| Incident lead | Runs the flow above; owns the timeline |
| **Project owner** | **Approves production rollback** (V10 Ch. 10.7 §4) and any destructive recovery |
| Owner | Approves legal-hold override — never unilateral; itself an `audit_log` entry (V8.7 §3) |

**No destructive recovery action in production is taken by one person alone once the team exceeds one.** Restoring the wrong version over good data is a recovery that causes the incident it was meant to fix.

---

## Disaster recovery checklist

Run at the start of any suspected data-loss incident.

- [ ] Time noted; incident record opened
- [ ] Blast radius identified — which environment, which keys, which time range
- [ ] **Legal hold checked** on affected objects (V8.7 §3)
- [ ] Version window confirmed as still open — 90/14/7 days
- [ ] Containment done: rotation, rollout halt, or script stopped
- [ ] Recovery target chosen — version ID or timestamp, written down before acting
- [ ] Recovery performed **beside** the damage, not over it
- [ ] Verification checklist passed
- [ ] Configuration re-verified against `infrastructure/` — drift is invisible otherwise
- [ ] Incident recorded, with the check that would have caught it

## Verification checklist

Run after any recovery, and quarterly as a drill. Everything here was executed on 2026-08-09 and passed except where noted.

```bash
# Buckets exist, correct region
for e in dev staging prod; do aws s3api get-bucket-location --bucket vump-platform-$e; done

# Versioning enabled — the entire basis of object recovery
for e in dev staging prod; do aws s3api get-bucket-versioning --bucket vump-platform-$e; done

# Block Public Access — all four true
for e in dev staging prod; do aws s3api get-public-access-block --bucket vump-platform-$e; done

# Encryption — AES256
for e in dev staging prod; do aws s3api get-bucket-encryption --bucket vump-platform-$e; done

# Bucket policy present and not public
for e in dev staging prod; do aws s3api get-bucket-policy-status --bucket vump-platform-$e; done

# Lifecycle matches the repository — and prod has NO expiration rule
for e in dev staging prod; do aws s3api get-bucket-lifecycle-configuration --bucket vump-platform-$e; done
```

- [ ] All three buckets in `ap-south-1`
- [ ] Versioning `Enabled` on all three
- [ ] Block Public Access all four flags true
- [ ] SSE-S3 (`AES256`) on all three
- [ ] `IsPublic: false` on all three
- [ ] Lifecycle matches `infrastructure/aws/s3/lifecycle-{env}.json`
- [ ] **Production has no current-object expiration rule** (ADR-013)
- [ ] Plain-HTTP request returns 403
- [ ] `flutter analyze`, `flutter test`, CI green

---

## Known gaps

| # | Gap | Consequence | Amendment |
|---|---|---|---|
| 1 | No cross-region replication | Region loss destroys all production footage | A-016 |
| 2 | MFA Delete disabled | An admin credential can permanently delete versions, defeating recovery | A-015 |
| 3 | Single AWS account | Account compromise or closure loses all environments | ADR-014 (accepted, migration deferred) |
| 4 | Account-level Block Public Access unset | A future bucket does not inherit protection | A-013 |
| 5 | No RTO/RPO ratified | No agreed target to recover against | A-017 |
| 6 | No Aurora backup strategy documented | The most durable data class has no written plan | A-018 |
| 7 | No drift detection | Configuration can diverge from the repository unnoticed | V4.9 §5, deferred to Volume 7 |
| 8 | DR never drilled | Every procedure here is untested | This document |

Gap 8 is the one that turns the others from theory into surprise. **A procedure that has never been executed is a draft.**
