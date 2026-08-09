# CloudFront

Content delivery for `vump-platform-prod` and `vump-platform-staging`, per ADR-011.

---

## ⚠ Read this before enabling a distribution

**Both distributions are created with `Enabled: false`.** That is not an oversight.

Origin Access Control gives CloudFront permission to read a bucket that Block Public Access otherwise seals shut. **Block Public Access does not protect against CloudFront** — it protects against direct S3 access. Once OAC is granted, an *enabled* distribution with no viewer restriction will serve every object in the bucket to anyone who requests the URL, over the public internet, with no authentication.

For a bucket holding evidentiary recordings of identifiable people, that is the worst failure available in this mission.

So enabling is gated. Before setting `Enabled: true` on either distribution, all of the following must be true:

1. **A CloudFront key group exists** and is attached as `TrustedKeyGroups` on the default cache behaviour, so every request requires a signed URL or signed cookie.
2. **The private key is in AWS Secrets Manager**, never in this repository — ADR-007 forbids credentials in source, and a CloudFront signing key is a credential.
3. **A real consumer exists.** ADR-011 provisions the distribution ahead of need; it does not authorise serving content before a feature requires it.
4. **Access logging is configured** to a dedicated log bucket. Currently `Logging.Enabled` is `false` because no log bucket exists — an enabled distribution with no logs is an unauditable access path.

Until then the distribution exists, is wired to its origin, holds its bucket grant, and serves nothing.

---

## Why provision it now at all

ADR-011 records the reasoning: a distribution, its Origin Access Control, and the bucket-policy grant that pairs with them are one coherent unit. Retrofitting a CDN in front of a bucket whose access policy is already settled means reopening that policy later, under delivery pressure, when the cost of a mistake is highest.

Creating it disabled costs nothing and removes that future coupling.

---

## Files

```
infrastructure/aws/cloudfront/
├── oac-prod.json                     Origin Access Control config
├── oac-staging.json
├── distribution-prod.json            Distribution config (__OAC_ID__ substituted at apply time)
├── distribution-staging.json
├── bucket-policy-with-oac.json.tmpl  Guardrails + the CloudFront grant
├── apply-cloudfront.sh               Validate, create, wire, report
└── README.md
```

---

## Applying

```bash
# Validate without touching AWS
./infrastructure/aws/cloudfront/apply-cloudfront.sh prod --validate-only

# Provision
./infrastructure/aws/cloudfront/apply-cloudfront.sh prod
./infrastructure/aws/cloudfront/apply-cloudfront.sh staging
```

The script is **idempotent**: an OAC with the same name, or a distribution already pointing at the same bucket, is reused rather than duplicated. It validates every file before making any AWS call, and refuses to proceed if the distribution config drifts from the constraints below.

A distribution takes a few minutes to reach `Deployed`. It is usable — and inert — immediately.

### Verify

```bash
aws cloudfront list-distributions \
  --query "DistributionList.Items[].{Id:Id,Origin:Origins.Items[0].DomainName,Enabled:Enabled,Status:Status}" \
  --output table

aws s3api get-bucket-policy --bucket vump-platform-prod --query Policy --output text | python -m json.tool
aws s3api get-bucket-policy-status --bucket vump-platform-prod
```

`IsPublic` must remain `false`. A bucket policy that grants a service principal under an `AWS:SourceArn` condition is not a public policy, and AWS agrees — if this ever reports `true`, stop and investigate.

---

## Configuration decisions

| Setting | Value | Why |
|---|---|---|
| `Enabled` | `false` | See the gate above. |
| Origin | `{bucket}.s3.ap-south-1.amazonaws.com` | Regional endpoint. OAC signs with SigV4 and requires the regional form, not the global `s3.amazonaws.com` alias. |
| `OriginAccessIdentity` | `""` | OAC supersedes legacy OAI. Setting both is a misconfiguration. |
| `SigningBehavior` | `always` | CloudFront signs every origin request, so the bucket can require it unconditionally. |
| `AllowedMethods` | `GET, HEAD` | Delivery only. Uploads go direct to S3 via presigned multipart URLs (Volume 4, Chapter 4.10 §2) and must never traverse the CDN. |
| `ViewerProtocolPolicy` | `https-only` | Not `redirect-to-https`: a redirect implies a plaintext first request was acceptable. Matches the bucket's own `DenyInsecureTransport`. |
| `CachePolicyId` | `Managed-CachingOptimized` | Chunk objects are immutable — the key includes `chunk_id` (Volume 5, Chapter 5.14), so a given key's bytes never change. Long TTLs are safe by construction. |
| `Compress` | `false` | MP4 is already compressed; re-compressing spends CPU to add bytes. |
| `PriceClass` | `PriceClass_200` | Includes India, where the origin and the Collectors are. `PriceClass_100` excludes India entirely and would route Indian viewers to distant edges. |
| `HttpVersion` | `http2and3` | HTTP/3 materially helps on the mobile networks Collectors use. |
| `ViewerCertificate` | CloudFront default | No custom domain yet. A custom domain needs an ACM certificate **in `us-east-1`**, regardless of the origin's region — that surprises people, so it is written down here. |
| `GeoRestriction` | `none` | Access control is authentication's job, not geography's. If a client contract restricts where data may be served, this is the control to revisit. |
| `Logging` | disabled | No log bucket exists yet. Required before enabling — see gate item 4. |

---

## The bucket policy gains its first `Allow`

Until now the bucket policies contained only conditional `Deny` statements, deliberately: same-account principals are granted through IAM identity policies, and a broad bucket-policy `Allow` is how least privilege is usually lost.

CloudFront is the exception that the earlier note anticipated. It is a **service principal**, not an account principal, so no IAM identity policy can grant it — the bucket policy is the only mechanism. The grant is narrowed three ways:

- **Action**: `s3:GetObject` only. CloudFront cannot list, write or delete.
- **Principal**: `cloudfront.amazonaws.com`, not `*`.
- **Condition**: `AWS:SourceArn` pinned to one distribution ARN. Another AWS customer's distribution pointed at this bucket is refused.

The three `Deny` statements are unchanged and still win — an explicit deny always beats an allow, so the HTTPS and TLS floors apply to CloudFront's origin fetches too.

---

## Not provisioned for development

`vump-platform-dev` has no distribution. ADR-014 asks staging to rehearse the production access path so the first execution of that path is not in production; development has no delivery role, and adding a third OAC and bucket-policy grant would widen the access surface for no rehearsal value.

Adding it later is a one-line change: the config files are per-environment and the script takes the environment as an argument.
