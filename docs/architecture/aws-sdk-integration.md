# AWS SDK Integration

How the backend talks to AWS, how Flutter talks to the backend, and why Flutter never talks to AWS.

Implements ADR-007 (secrets), ADR-011 (storage), ADR-014 (environments), ADR-015 (backend runtime). Follows Volume 4, Chapters 4.6, 4.7, 4.9 and 4.10, and Volume 5, Chapters 5.10, 5.13 and 5.14.

This is a design and integration specification, not an ADR. Where it and an accepted ADR disagree, the ADR governs.

---

## The single rule everything else follows

**The mobile application never holds an AWS credential.**

Not a permanent access key, not a temporary session token, not a Cognito identity. Volume 4, Chapter 4.10 §2 states it: *"the mobile app never holds a raw AWS credential (NFR-SEC-03 stays satisfied even at the network boundary)."*

The reason is device trust. A Flutter binary is distributed to devices outside your control, can be decompiled, and runs on hardware that may be rooted, jailbroken, or seized. Any credential compiled into it is a credential published. Even a scoped, short-lived one grants whatever it grants to whoever extracts it.

So AWS credentials exist in exactly one place: **the backend's IAM execution role**, which is never serialised, never transmitted, and never leaves the Lambda environment.

What crosses the network to the device is a **presigned URL** — a signature over one specific operation, on one specific object key, valid for a bounded time. Possessing it lets the holder perform that one operation and nothing else. It is a capability, not an identity.

---

## Backend credential strategy

### IAM roles only. No access keys. Ever.

The backend obtains credentials from the **Lambda execution role**, resolved automatically by the AWS SDK's default credential provider chain from the environment the function runs in.

The SDK client — `S3Client` from AWS SDK for JavaScript v3, per ADR-015 — is therefore constructed with **no credential parameters at all**, only a region. Any code that reads `AWS_ACCESS_KEY_ID`, accepts a key as configuration, or constructs a client with an explicit credential object is a defect, regardless of where the value came from.

This is not stylistic. Role-derived credentials rotate automatically, expire on their own, are scoped to one function, and never exist as a string that can be copied into a log, a ticket, or a `.env` file. An access key has none of those properties, and ADR-007 forbids one in source regardless.

**Local development** uses a named AWS CLI profile resolved by the same provider chain — so the code path is identical in every environment, and there is no "local mode" branch that behaves differently from production.

### Per-function least privilege

Volume 4, Chapter 4.9 §2 is specific: *"the chunk-registration Lambda can generate presigned S3 URLs but cannot itself read arbitrary S3 objects; the metadata Lambda can write to `chunk_metadata` but has no S3 permissions at all."*

Two policy templates implement that, in `infrastructure/aws/iam/`, and **each
attaches to its own role** — the separation is enforced by the principal, not by
the template:

| Role | Template | Actions | Deliberately absent |
|---|---|---|---|
| `vump-{env}-chunks-upload` | `chunks-presign-upload-s3-policy` | `s3:PutObject`, `s3:AbortMultipartUpload`, `s3:ListMultipartUploadParts` | `s3:GetObject` — it presigns uploads; it never reads footage |
| `vump-{env}-chunks-verify` | `chunks-verify-object-s3-policy` | `s3:GetObject`, `s3:GetObjectAttributes`, `s3:GetObjectVersionAttributes` | `s3:PutObject` — it checks integrity; it never writes |
| `vump-{env}-metadata` | *(none)* | *(no S3 policy)* | everything — it touches Aurora only |

**Seven roles across ADR-015's six domains.** The `chunks` domain carries two,
because a domain is a unit of code decomposition and a role is a unit of
privilege; the other five domains carry one each. Mission 6.1 briefly merged
both chunk policies onto a single role and that is recorded, with the reasoning,
in amendment **A-143**.

**Two chunks roles means two chunks functions.** A Lambda has exactly one
execution role, so the `chunks` domain deploys `chunk-registration` and
`chunk-verification` as separate functions — which is how Volume 8, Chapter 8.4
§1 already tabulates them.

**No role has `s3:DeleteObject`.** Deletion of raw footage is lifecycle's job, and ADR-013 gates it behind legal-hold enforcement. A backend role that can delete a chunk is a backend bug that can destroy evidence.

**A presigned URL carries the signer's permissions.** This is the part that catches people out: if the registration role held `s3:GetObject`, a presigned URL it generated could be crafted to read objects. Withholding `GetObject` from that role is what makes the narrowness real rather than conventional.

---

## The presigned upload flow

Per Volume 4, Chapter 4.10 §2 and Volume 5, Chapter 5.10.

```
Flutter                        Backend (Lambda)                 S3
   │                                 │                           │
   │ 1. POST /v1/sessions/{id}/chunks│                           │
   │    Bearer <Firebase ID token>   │                           │
   │    {sequence_index,             │                           │
   │     file_size_bytes,            │                           │
   │     checksum_sha256}            │                           │
   ├────────────────────────────────►│                           │
   │                                 │ verify token (Firebase    │
   │                                 │   Admin SDK, V4.7 §1)     │
   │                                 │ compute deterministic key │
   │                                 │   (V5.14 §1)              │
   │                                 │ presign multipart URLs    │
   │                                 │   (role credentials)      │
   │ 2. 201 {chunk_id,               │                           │
   │        s3_object_key,           │                           │
   │        upload_urls[]}           │                           │
   │◄────────────────────────────────┤                           │
   │                                 │                           │
   │ 3. PUT each part directly to S3 — no backend involvement    │
   ├────────────────────────────────────────────────────────────►│
   │                                 │                           │
   │ 4. PATCH /v1/chunks/{id}/status │                           │
   ├────────────────────────────────►│                           │
   │                                 │ HEAD object; compare      │
   │                                 │   size + checksum         │
   │                                 ├──────────────────────────►│
   │                                 │ 'complete' only if match  │
   │ 5. 200                          │   (FR-META-12)            │
   │◄────────────────────────────────┤                           │
```

### Why the bytes bypass the backend

Step 3 goes device → S3 directly. Routing multi-hundred-megabyte chunks through Lambda would hit its payload limit, multiply cost, and add a hop that improves nothing. The backend authorises the transfer; it does not carry it.

### Why the backend computes the key, not the client

Volume 5, Chapter 5.14 defines the key as deterministic and computable on both sides. The backend is nonetheless the one that computes the key it signs, because a client-supplied key is a client-controlled write location. A compromised device could otherwise request a signature for another org's prefix.

The client computes the same key independently for local file naming (V5.14 §2). Agreement is a consistency check, not a trust relationship.

### Why retries are safe

Volume 5, Chapter 5.13 §4: every retry reuses the same `chunk_id` and the same deterministic key. Re-registering returns a signature for the same key. Uploading the same part number twice overwrites it. BR-11's "never a duplicate object" is structural, not a matter of discipline.

Presigned URLs expire after **3600 seconds** (`presignExpirySeconds` in `environments.json`). Volume 5, Chapter 5.13 §2 caps automatic retry at six attempts with backoff topping out at five minutes — roughly 30 minutes — so one hour covers the automatic path with headroom. An upload still running past expiry re-requests URLs, which V4.10 §3 already anticipates. This is a tunable operational parameter, not an architectural constraint.

### Completion is server-verified

Step 4 does not take the client's word. The backend performs a `HEAD` and compares size and checksum against what was registered before allowing `complete` (V4.10 §2 step 3, FR-META-12). A client claiming success it did not achieve is rejected.

---

## How Flutter communicates with the backend

**Transport:** the existing `DioClient` in `mobile/lib/core/network/` (ADR-011 network layer). No new HTTP mechanism.

**Base URL:** `NetworkConfig`, resolved from `AppConfig.environment` per ADR-007. Not the S3 or CloudFront hostname — the API base URL.

**Authentication:** a Firebase ID token as `Authorization: Bearer <jwt>` on every request (V4.7 §1 step 2). `AuthInterceptor` in `core/network/interceptors/` is the seam that will attach it; it is currently an inert placeholder by design.

**Role:** carried as a Firebase custom claim inside the token (V4.7 §2), never sent in a request body — a client can never assert its own role.

**Endpoints Flutter calls** (V4.6 §4):

| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/v1/tasks/{id}/sessions` | Start a recording session |
| `POST` | `/v1/sessions/{id}/chunks` | Register a chunk; receive presigned URLs |
| `PATCH` | `/v1/chunks/{id}/status` | Transition queued → uploading → complete/failed |
| `POST` | `/v1/chunks/{id}/metadata` | Submit the FR-META-11 payload |

**The only AWS hostname Flutter ever contacts is the presigned S3 URL handed to it in step 2** — and it contacts it with a signature it did not generate and cannot modify.

**Errors** map into the Mission 0.10 taxonomy at the `DioClient` boundary. An S3 error reaching a widget as a raw XML body would be a boundary failure, not a networking one.

---

## Environment-aware configuration

`infrastructure/aws/config/environments.json` is the single source: region, chunk bucket, CloudFront domain, presign expiry, per environment.

The backend selects its entry by the same environment identity ADR-014 defines — `development`, `staging`, `production` — supplied to the runtime as an environment variable. The bucket name is **never** derived by string concatenation from an environment name at a call site; it is looked up once at startup and injected.

The file contains no credential. Every value is a non-secret identifier, permitted in source for exactly the reason ADR-007 permits a base URL: it is discoverable by anyone who can observe the system's traffic, and concealing it protects nothing.

**Secrets — database passwords, third-party API keys — come from AWS Secrets Manager at runtime** (V8 §8.4), resolved by the same execution role. That is the subject of the Secrets Management mission and is not implemented here.

---

## What is not implemented, and why

**No S3 client code exists yet**, and that is now the narrow statement it sounds like rather than a description of an empty directory.

`backend/` exists as of Mission 6.2: an npm workspace, seven Lambda functions behind a REST API, and the shared package that holds the envelope, the error taxonomy and token verification (A-152, ADR-045). **The Firebase Admin SDK half of this document is implemented and real** — and needs no service-account secret, which A-149 establishes by experiment rather than by citation.

What remains unwritten is exactly the S3 half: `@aws-sdk/client-s3` and `@aws-sdk/s3-request-presigner` are not yet dependencies, and the presigned multipart flow above has no implementation. `POST /v1/sessions/{sessionId}/chunks` is provisioned and answers `NOT_IMPLEMENTED`. That work is Mission 6.3's.

Every design above was written runtime-agnostic and holds unchanged.

**The IAM roles are applied.** Mission 6.1 rendered these templates and created seven roles; `vump-{env}-chunks-upload` and `vump-{env}-chunks-verify` hold the two policies above, one each.

**No Dart API client is written.** This document defines the contract; implementing a repository or service against it is feature work, excluded by the mission's scope rules.
