# ADR-015 — Backend Runtime

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none. Confirms Volume 4, Chapter 4.1.

## Context

Volume 4, Chapter 4.1 records the compute decision: *"Chosen: AWS Lambda (Node.js/TypeScript) behind API Gateway, one function per resource domain (auth-verify, projects, tasks, sessions, chunks, metadata)."* It is an accepted decision with alternatives weighed and consequences stated.

During Mission 0.17 the platform was described in passing as "Flutter + FastAPI + PostgreSQL + S3". FastAPI is a Python framework. That is not a small divergence: it changes the AWS SDK (`@aws-sdk/client-s3` versus `boto3`), the packaging and deployment model, the code-generation and type story, and every dependency in the backend.

The conflict surfaced in Mission 0.17.15, which could not write a single line of SDK client code without resolving it. `backend/` was — and remains — empty, so no implementation had committed to either. The decision could therefore be taken cleanly rather than as a migration.

The reason this needs its own record, when Volume 4 already contains the decision, is that a contradiction reached the point of blocking implementation. A decision that has been questioned once will be questioned again, and the volumes are PDFs that this repository cannot amend. This record is the durable, in-repository statement.

## Decision

**The backend runtime is AWS Lambda with Node.js and TypeScript, behind API Gateway**, exactly as Volume 4, Chapter 4.1 specifies. One function per resource domain.

FastAPI is not adopted. Python is not introduced to the backend. The Mission 0.17 mention of FastAPI is obsolete and carries no authority.

Concretely, this fixes:

- **Runtime** — Node.js on AWS Lambda.
- **Language** — TypeScript, compiled. Not plain JavaScript.
- **API layer** — Amazon API Gateway, the only public entry point (Volume 4, Chapter 4.9 §2).
- **Decomposition** — one function per resource domain: `auth-verify`, `projects`, `tasks`, `sessions`, `chunks`, `metadata`.
- **AWS SDK** — AWS SDK for JavaScript v3, specifically `@aws-sdk/client-s3` and `@aws-sdk/s3-request-presigner` for the presigned upload flow.
- **Firebase token verification** — the Firebase Admin SDK for Node (Volume 4, Chapter 4.7 §1 step 3).

Everything in `docs/architecture/aws-sdk-integration.md` was written to be runtime-agnostic and holds unchanged under this decision. What it deferred — the client code itself — is now unblocked.

`backend/` is empty. This record decides what will fill it; it does not fill it.

## Alternatives Considered

- **FastAPI on Lambda, via Mangum or a container image** — rejected. Volume 4 already chose Node/TypeScript with reasons that still hold, and nothing has changed to invalidate them. Adopting Python would mean contradicting an accepted decision to gain nothing measurable, while splitting the codebase across two languages and two dependency ecosystems.
- **FastAPI on ECS Fargate or EC2** — rejected twice over. It changes both the language and the compute model, and Volume 4, Chapter 4.1 explicitly rejected always-on compute for paying for idle capacity on an MVP with an unproven usage curve.
- **Plain JavaScript instead of TypeScript** — rejected. The chunk registration and metadata payloads (Volume 4, Chapter 4.5) are structured enough that a type error becomes a runtime failure in a Collector's upload path, hours into fieldwork, where it is least recoverable.
- **A single Lambda handling every route** — rejected. It contradicts Chapter 4.1's per-domain decomposition and defeats Chapter 4.9 §2's least-privilege model, which depends on each function carrying only the permissions its domain needs. One function would need the union of every permission.
- **Re-opening the compute decision entirely** — rejected. Volume 4 weighed the alternatives and recorded consequences. Re-litigating a reasonable prior decision because a passing remark disagreed with it is how architecture erodes.

## Consequences

- The backend is a single-language codebase. Tooling, linting, dependency management and CI are uniform.
- The AWS SDK for JavaScript v3 is modular, so each function bundles only the clients it uses — which keeps cold-start cost proportional to what a function actually does.
- TypeScript types can be shared between functions, and the API contract in Volume 4, Chapter 4.6 can be expressed as types rather than as prose plus hope.
- Cold-start latency remains the accepted tradeoff Chapter 4.1 named, mitigated later with provisioned concurrency only if measurement demands it.
- A compile step now sits between source and deployment. CI must build before it deploys, and a type error becomes a build failure rather than a production one — which is the point.
- **Mobile and backend remain different languages** — Dart and TypeScript. The deterministic S3 key of Volume 5, Chapter 5.14 is therefore implemented twice, once on each side. Volume 5 anticipates this and requires the two to agree. It is a genuine duplication and needs a shared test vector so the implementations cannot silently diverge.
- Any future proposal to introduce Python to the backend now requires an ADR superseding this one.

## Related Missions

- Mission 0.17.15 — AWS SDK Integration, which surfaced the conflict and was blocked by it.

## Implementation Status

**Not implemented.** `backend/` is empty. No Lambda function, no `package.json`, no `tsconfig.json`, no SDK dependency exists.

What this record unblocks is the client code deferred by `docs/architecture/aws-sdk-integration.md` — the S3 client construction, the presigned multipart URL generation, and the completion verification. That work belongs to a backend implementation mission, not to Mission 0.17.

Nothing in the repository contradicts this decision. The single FastAPI reference, in `aws-sdk-integration.md`, was corrected when this record was written.
