# AWS Infrastructure Configuration

Version-controlled configuration for the Vump Technologies AWS environment.

Every file here is the **declared** state. AWS is the **actual** state. They are expected to match, and a difference is a defect in one of them.

---

## Why these files exist rather than console clicks

A configuration applied by hand in the console has no history, no review, and no way to tell whether staging and production drifted apart. These files are reviewable in a pull request, diffable between environments, and reapplyable after a mistake.

This is not infrastructure-as-code. There is no state file and nothing detects drift — Volume 4, Chapter 4.9 §5 defers the CDK/Terraform choice to Volume 7. Until that decision is taken, these files plus the verification commands below are the substitute, and the gap should be understood rather than assumed away.

---

## Layout

```
infrastructure/aws/
├── s3/
│   ├── lifecycle-dev.json
│   ├── lifecycle-staging.json
│   ├── lifecycle-prod.json
│   ├── bucket-policy-dev.json
│   ├── bucket-policy-staging.json
│   └── bucket-policy-prod.json
└── cloudfront/
    ├── oac-{prod,staging}.json
    ├── distribution-{prod,staging}.json
    ├── bucket-policy-with-oac.json.tmpl
    ├── apply-cloudfront.sh
    └── README.md
```

**Note on precedence:** once CloudFront is provisioned, `cloudfront/bucket-policy-with-oac.json.tmpl` supersedes `s3/bucket-policy-{env}.json` for `prod` and `staging`. It contains the same three guardrail denies plus the OAC grant. Re-applying the `s3/` file to those buckets would silently remove CloudFront's access. See `cloudfront/README.md`.

One file per environment, named for its bucket: `vump-platform-{env}`.

**Region: `ap-south-1` (Mumbai)** for all environments, per ADR-011.

---

## Governing decisions

| Concern | Record |
|---|---|
| Bucket naming, key schema, CloudFront, encryption | ADR-011 |
| Lifecycle rules and retention | ADR-012 |
| Legal hold and object expiration | ADR-013 |
| Environment purpose and promotion | ADR-014 |

Where a file here and an accepted ADR disagree, the ADR governs and the file is a defect.

---

## Applying S3 lifecycle configuration

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket vump-platform-dev \
  --lifecycle-configuration file://infrastructure/aws/s3/lifecycle-dev.json

aws s3api put-bucket-lifecycle-configuration \
  --bucket vump-platform-staging \
  --lifecycle-configuration file://infrastructure/aws/s3/lifecycle-staging.json

aws s3api put-bucket-lifecycle-configuration \
  --bucket vump-platform-prod \
  --lifecycle-configuration file://infrastructure/aws/s3/lifecycle-prod.json
```

`put-bucket-lifecycle-configuration` **replaces** the entire configuration. It is not additive. Applying a file that omits a rule deletes that rule.

### Verify

```bash
for env in dev staging prod; do
  echo "--- vump-platform-$env"
  aws s3api get-bucket-lifecycle-configuration --bucket "vump-platform-$env"
done
```

Compare the output against the file. They should be identical apart from key ordering.

---

## What the production configuration deliberately omits

**There is no expiration rule on `vump-platform-prod`.** Objects are retained indefinitely.

This is not an oversight. ADR-012 adopts Volume 8, Chapter 8.7 §1's 24-month retention policy unchanged, and ADR-013 withholds the rule until a legal hold can survive it — a bucket-wide expiration rule cannot read the `legal_hold_at` column in Aurora, so enabling one today would delete held footage on schedule.

**Do not add an expiration rule to production** until ADR-013's four-point gate is satisfied. The rule is cheap to add and impossible to undo.

---

## Applying S3 bucket policies

```bash
for env in dev staging prod; do
  aws s3api put-bucket-policy \
    --bucket "vump-platform-$env" \
    --policy "file://infrastructure/aws/s3/bucket-policy-$env.json"
done
```

### Verify

```bash
for env in dev staging prod; do
  echo "--- vump-platform-$env"
  aws s3api get-bucket-policy --bucket "vump-platform-$env" \
    --query Policy --output text | python -m json.tool
  aws s3api get-bucket-policy-status --bucket "vump-platform-$env"
done
```

`get-bucket-policy-status` must report `"IsPublic": false` for every bucket.

---

## Why these policies contain no `Allow`

A bucket policy is not the only way to grant access, and for same-account principals it is not the usual one. An IAM role in this account is granted S3 access by its **identity policy**; the bucket policy only has to *not deny* it. Bucket policies are required for cross-account access, for service principals such as CloudFront, and — as here — for **guardrails that apply to everyone regardless of their IAM permissions**.

So these files are three unconditional-in-scope, conditional-in-trigger denies:

| Statement | Blocks |
|---|---|
| `DenyInsecureTransport` | Any request over plain HTTP. Implements Volume 4, Chapter 4.10 §3's "HTTPS-only bucket policy". |
| `DenyOutdatedTlsVersions` | Any request negotiating TLS below 1.2. |
| `DenyEncryptionDowngradeOnUpload` | An upload that explicitly asks for encryption weaker than SSE-S3. |

Least privilege is achieved by granting nothing here and granting narrowly in IAM (Step 5). Adding a broad `Allow` to a bucket policy is the common way least privilege is lost, because a bucket-policy `Allow` applies to every principal that matches it.

### The encryption statement, and why its shape matters

The naive form of this rule breaks uploads:

```json
"Condition": { "StringNotEquals": { "s3:x-amz-server-side-encryption": "AES256" } }
```

`StringNotEquals` evaluates to **true when the key is absent**, so that version denies every upload that simply omits the header — which is most of them, including presigned multipart uploads, since bucket default encryption already applies SSE-S3 server-side.

The form used here pairs it with a `Null` check:

```json
"Condition": {
  "Null":            { "s3:x-amz-server-side-encryption": "false" },
  "StringNotEquals": { "s3:x-amz-server-side-encryption": "AES256" }
}
```

Both must hold: the header is *present* **and** it is not `AES256`. Uploads that omit the header pass through and are encrypted by the bucket default; only an explicit downgrade attempt is denied.

### Lockout safety

Every statement is a `Deny` with a `Condition`. None is unconditional, so no combination of them can lock an administrator out of the bucket — the worst case is that a non-compliant request is refused. This is checked before the policies are applied.

### What is deliberately absent

**No CloudFront grant yet.** The Origin Access Control statement requires the distribution's ARN, which does not exist until Step 4. The bucket policy is revised then to add it. That revision is expected and is not drift.

**No principal grants yet.** Lambda execution roles do not exist until Step 5, per Volume 4, Chapter 4.9 §2.

---

## Notes on the rules themselves

**Bucket-wide filters.** Every rule uses `"Filter": {}`. The object key defined in Volume 5, Chapter 5.14 begins at `{org_id}/` with no common prefix, so there is nothing to scope on. ADR-011 makes the corresponding rule explicit: these buckets hold chunks and nothing else.

**Objects under 128 KB are not transitioned** to Standard-IA by S3 default, because the transition would cost more than it saves. Chunk files are multi-hundred-megabyte, so this does not apply to them — but it would apply to any small object placed in these buckets, which is a further reason to keep them pure.

**Glacier Instant Retrieval carries a 90-day minimum storage charge.** Deleting an object sooner is billed for the remainder. Only relevant once expiration is enabled.

**Dev and staging receive no storage-class ladder.** Their objects expire at 30 and 90 days, so most would never reach the 180-day Glacier transition, and the 30-day IA transition would save little against the per-object transition request cost.
