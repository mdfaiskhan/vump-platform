# ADR-044 — Database Access via the RDS Data API

- **Status:** Accepted
- **Date:** 2026-08-17
- **Supersedes:** none. Resolves a contradiction between Volume 4, Chapter 4.9 §2 and Volume 8, Chapter 8.4 §1 — see `docs/architecture/volume-amendments.md` A-142.

## Context

Two accepted volumes describe how a Lambda function reaches Aurora, and they describe different mechanisms.

**Volume 4, Chapter 4.9 §2** states: *"Aurora Serverless v2 runs inside a private VPC subnet, reachable only from the Lambda functions (via a VPC-attached execution role) — never exposed to the public internet directly."* That is a network path: the function joins the VPC, opens a TCP connection to port 5432, and speaks the PostgreSQL wire protocol.

**Volume 8, Chapter 8.4 §1** writes every function's database permission as **`rds-data:ExecuteStatement`**. That is the RDS Data API — an HTTPS endpoint outside the VPC, reached with SigV4-signed calls. A function using it does not join the VPC and has no route to the cluster at all.

They cannot both be implemented. This is the same shape as ADR-015, where a passing remark contradicted an accepted decision and blocked implementation: Mission 6.1 could not write a VPC without knowing whether it needed a NAT gateway, and could not write an IAM role without knowing whether it needed `AWSLambdaVPCAccessExecutionRole`.

The contradiction is not a typo. Each half is internally coherent, and V8.4 §1's action names are specific enough that they were clearly written against the Data API rather than borrowed loosely.

## Decision

**The backend reaches Aurora exclusively through the RDS Data API.**

No Lambda function joins the VPC. Aurora sits in private subnets with no gateway of any kind and a security group carrying no rules.

Concretely:

- **Access** — `rds-data` actions against the cluster ARN, with the credential resolved from Secrets Manager by ARN (ADR-016), exactly as Volume 8, Chapter 8.4 §1 and §2 describe.
- **Cluster** — `enable_http_endpoint = true`. Without it the cluster is unreachable, because nothing else in the configuration can open a connection to it.
- **Network** — no internet gateway, no NAT gateway, no VPC endpoints, no public subnets, no Lambda security group.
- **Engine floor** — a version the Data API supports in `ap-south-1`. Verified against the AWS region and version table: 17.4+, 16.1+, 15.3+, 14.8+, 13.11+. **PostgreSQL 18 is offered in this region and is absent from that table**, so it is not selectable while this record stands.
- **Password encryption** — `scram-sha-256`, pinned in the cluster parameter group, because *"for Aurora PostgreSQL version 14 and higher databases, Data API only supports `scram-sha-256`."*

Volume 4, Chapter 4.9 §2's *intent* — Aurora never reachable from the public internet — is satisfied more completely than the mechanism it names would achieve. A VPC-attached design reaches the cluster over a network path that exists and is restricted; this one has no network path to restrict.

### Why the availability was verified rather than assumed

`aws rds describe-db-engine-versions` **cannot answer whether the Data API is available.** The `SupportsHttpEndpoint` field is absent from its response for every `aurora-postgresql` version — in `ap-south-1`, and also in `us-east-1` and `ap-southeast-1`, where the Data API demonstrably works. Reading that absence as "unsupported" would have been wrong, and it is the obvious mistake to make.

The check that works is the AWS region-and-version table, corroborated by `rds-data.ap-south-1.amazonaws.com` resolving. This is recorded because the next person to verify a regional feature will reach for the CLI first, as this mission did.

## Alternatives Considered

- **VPC-attached Lambda, as Volume 4, Chapter 4.9 §2 states** — rejected, and it is the serious alternative. It is the conventional design, it has no 1 MiB response ceiling, and it keeps IAM from being the only control. It was rejected on cost and on blast radius: a NAT gateway is roughly $32/month per availability zone before data processing, and Volume 4, Chapter 4.7's Firebase token verification means the functions must reach `googleapis.com`, which VPC endpoints cannot serve — so the NAT is not optional under that design. Across three environments (ADR-014) that is a standing bill for an MVP with no users, on a project whose compute was chosen in Volume 4, Chapter 4.1 specifically so that *"cost tracks actual Collector activity rather than a fixed server bill."* A NAT gateway is the opposite of that property.
- **VPC-attached Lambda with interface endpoints and no NAT** — rejected as not viable. Endpoints cover Secrets Manager and S3; they cannot reach Firebase, and token verification is on the critical path of every authenticated request.
- **Data API for reads, direct connection for writes** — rejected. Two access paths means two failure modes, two credential paths and two sets of IAM, to serve one schema.
- **RDS Proxy with VPC-attached Lambda** — rejected. It solves connection pooling, which is the problem the Data API also solves, while still requiring the VPC attachment and the NAT that motivated moving away from that design.
- **Deferring the decision and building the VPC to suit both** — rejected. "Both" means provisioning the NAT and the public subnets, which is the expensive half of the design, in order to avoid choosing.

## Consequences

- **IAM is the only access control.** ADR-014 already records that single-account isolation *"depends entirely on IAM correctness until migration"*; this stacks the database on that same control. There is no network layer behind it. IAM review for these roles is load-bearing, not routine.
- **The 1 MiB response limit is a real constraint on the API.** Volume 4, Chapter 4.6's Admin read endpoints — rate-limited at 300 requests/minute in Volume 8, Chapter 8.3 §1 precisely because dashboards poll — must paginate. This is a requirement on Mission 6.2, not a tuning note, and a query that works against a small dev dataset will fail against a real one.
- **Reads and writes both hit the writer.** The Data API *"can only execute Data API queries on writer instances"*, so a reader instance serves no query this backend makes. Read scaling, if ever needed, requires abandoning this decision rather than adding an instance.
- **Nothing can open a Postgres connection to the cluster.** Schema migration (Mission 6.3) must run through the Data API, or the security group needs an ingress rule and something to connect from. That is a deliberate, reviewable change — but it must be planned, and 6.3 should not discover it.
- **Cold starts improve and NAT cost disappears.** No ENI attachment, no NAT gateway, no VPC endpoints. For a dev environment scaling to zero ACUs, the idle cost of the whole data tier approaches nothing.
- **The engine version is constrained by a table AWS maintains**, not by what RDS offers. An upgrade to PostgreSQL 18 is blocked until the Data API supports it, and the block will not be visible in `describe-db-engine-versions`.
- Any future proposal to attach Lambda functions to the VPC now requires an ADR superseding this one.

## Related Missions

- Mission 6.1 — AWS Foundations, which surfaced the contradiction and was blocked by it.

## Implementation Status

**Implemented, not applied.**

| | Decision | Current state |
|---|---|---|
| `enable_http_endpoint` | Required | ✅ In the plan |
| No NAT, no IGW, no VPC endpoints | Required | ✅ None in the configuration |
| Aurora security group with no rules | Required | ✅ |
| No `AWSLambdaVPCAccessExecutionRole` | Required | ✅ Attached to no role |
| Engine version Data API-supported | Required | ✅ 16.14, against a 16.1 floor |
| `password_encryption = scram-sha-256` | Required | ✅ Cluster parameter group |
| Pagination on Admin reads | Required | ⬜ Mission 6.2 — no backend exists |
| Per-table permission | Volume 8, Chapter 8.4 §1 | ⬜ **Not expressible in IAM.** Mission 6.3, via PostgreSQL `GRANT` |
| Applied to AWS | — | ❌ Plan only |
