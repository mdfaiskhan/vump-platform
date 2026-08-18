# Mission 6 — Gap Register

Every "report, don't fix" item raised across Missions 6.1 to 6.6, in one place.

**Authority: none.** This is a hand-off, not a decision. Every row restates something already recorded in an ADR, an amendment or `deferred-items.md`; the "Source" column is where the real record lives. Nothing here is new policy, and where this file and a source record disagree, the source is correct.

**Why it exists.** Mission 6 ran as six sub-missions, each with its own close-out and its own list of things deliberately not fixed. Mission 6.7 is the security review, and asking it to re-derive that list from six reports would mean it either misses something or spends its budget on archaeology. This is the single reference point instead.

**What it is not.** It is not a risk register (Volume 11 Ch. 11.4) — nothing here is scored for likelihood, and most are certainties rather than risks. It is not a bug tracker (Ch. 11.7) — every entry was taken knowingly. `deferred-items.md` remains the live register for items with owning missions; this file is the Mission 6 slice of it plus the items that never became deferred items because they were reported inside a close-out and nowhere else.

---

## The register

Ordered by what a security review would want first, not by discovery.

| # | Gap | Class | Source |
|---|---|---|---|
| 1 | **Every AWS resource, schema change and database password was created by `faisal-admin`**, an unscoped administrative principal. 67 managed resources, 9 migrations, 7 credentials | Blast radius | A-144, item 8 |
| 2 | **Nothing applies a merged migration.** A schema change can be written, reviewed, merged and released without reaching a database; neither CI nor the runner notices. Closing it means giving CI credentials that can `DROP` | Enforcement + credential decision | A-161, item 11 |
| 3 | **The seven per-function database secrets rotate manually.** V8.4 §2's automatic RDS rotation covers the master credential only; nothing schedules the rest | Credential lifecycle | ADR-016 |
| 4 | **Nothing issues the `admin` claim.** `firestore.rules` requires it to write `org_invite_codes`, and `redeemInviteCode` sets `role: "collector"` from a literal on every path — so that collection is writable by nobody, and admin is an undocumented manual bootstrap | Unreachable capability | A-158, ADR-036 |
| 5 | **Four live accounts carry `org_id: "vump-default"`**, a literal that no longer matches anything. It is mapped to the `Unassigned` org at read time by `resolveOrgId` and never rewritten, so the stale value persists in every token | Data shape | A-163, item 12 |
| 6 | **Every self-signup account lands in one shared organisation.** BR-20's tenant isolation therefore separates nobody among them. Acceptable only while ADR-036's "informal APK sharing among a trusted group" holds — **revisit before public distribution** | Tenant isolation, time-bounded | Migration `0009`, A-166 |
| 7 | **`functions/` is not retired** and claim-writing stays in Cloud Functions. Deliberate: porting it moves the writer outside Google, which is the only thing that forces the credential ADR-036 defers | Deliberate, with a trigger | A-165, item 10 |
| 8 | **The BR-08/11/21/22 behavioural proofs exist only as an uncommitted scratchpad script.** They need live AWS, so CI cannot run them — the strongest evidence Mission 6 produced is the least repeatable | Test coverage | 6.3.1 close-out |
| 9 | **Aurora runs at `MinCapacity 0` and auto-pauses.** The first request after idle can exceed the Lambda's 15-second timeout while the resume ladder runs to ~30 seconds | Availability | A-156, ADR-043 |
| 10 | **`GET /v1/users/me` and every route behind the authorizer add a Data API round-trip per request**, with `authorizerResultTtlInSeconds = 0`. Correctness was chosen over caching, unmeasured | Performance | ADR-048 |
| 11 | **`POST /v1/auth/verify` fires twice per app launch.** `_toUser` runs on two paths — `_restoreSession` and the `sessionChanges` stream — and each performs the exchange. Harmless (idempotent, `ON CONFLICT DO NOTHING`) but doubled | Efficiency | 6.5.6 close-out |
| 12 | **`execute-api` hostnames are invisible to the AWS endpoint check** after A-168's narrowing. The three credential-material checks are unaffected and remain the disclosure guarantee | Narrowed guarantee, accepted | A-168 |
| 13 | **iOS is registered, unwired and unverifiable.** Bundle IDs exist in all three Firebase projects and the plists are committed, but `project.pbxproj` still carries `com.example.mobile` and nothing selects a plist. No Mac, no Apple Developer account | Platform | item 2, ADR-047 |
| 14 | **Staging and production have no Auth, no billing and no API Gateway.** Deliberate under ADR-014 until a release branch is cut | Deliberate | item 13, A-162 |
| 15 | **The backend has no coverage gate.** ADR-045 recorded it as "deliberately absent — revisit at 6.3"; 6.3 passed without revisiting | Overdue commitment | ADR-045 |
| 16 | **The authorizer exemption is asserted, not enforced.** The Terraform `check` only evaluates during `plan`/`apply`, CI runs no `plan` (no credentials), and a failed `check` is a **warning** rather than an error even then. The guarantee is held by code review | Enforcement | ADR-048, 6.6 |
| 17 | **No scoped principal exists for either a human or CI.** Gap 1 wants a per-developer IAM user (Volume 7 Ch 7.8 §1); gaps 8 and 16 want a read-only CI principal. Both reduce to the same question — **a long-lived key, or federated short-lived access** — and it is A-165's question asked of two new seams. Queued for its own trace/decide | Credential mechanism | A-165, item 8, gaps 1/8/16 |

---

## Three of these are the same gap wearing different clothes

**2, 8 and 16** are all *a standard written and nothing executing it* — the shape A-148 and A-153 named and closed, and A-161 could not.

The distinction that matters to 6.7 is **why** each is still open:

- **8** is open because the check needs live AWS and CI has none. A read-only credential would close it.
- **16** is open for the same reason, one step further along: the assertion exists and is correct, and the pipeline that would run it does not run.
- **2** is open because closing it needs a credential that can **write** — and that is a different question with a different answer.

**They therefore share a single upstream decision: may CI hold AWS credentials, and of what strength?** A read-only principal closes 8 and 16 and leaves 2 untouched. That question also governs deployment and Mission 6.5's deferred Firebase key, so it is worth answering once rather than three times.

**1 is the same question about a human** rather than about a pipeline, which is why it sits first: today there is exactly one principal, it is unscoped, and it did everything.

## What this register deliberately does not do

It does not rank by severity. Ranking is 6.7's job and it has context this file does not — what the product is exposed to, who has access, and what ships first. Ordering here is by kind, and the sequence above is a suggestion about reading order, not a verdict.

## Gap 17 absorbs gaps 1, 8 and 16's shared question — and it is A-165's question again

Mission 6.7 was authorised to build both a scoped human principal and a read-only CI principal, and built neither, because each runs into the same decision from a different side:

- **A human principal** needs an access key. `aws_iam_access_key` writes the secret into **Terraform state** — precisely what ADR-043 avoids for the database via `manage_master_user_password`, and what ADR-016 forbids generally. So Terraform can own the user and its policy, and the credential has to be issued out of band.
- **A CI principal** needs credentials GitHub Actions can use. That is either **static access keys held as repository secrets** — a long-lived credential of the class ADR-036 calls *"a silent, total authorization bypass"* if leaked — or **OIDC federation**, where GitHub exchanges a short-lived token for an AWS role and no secret is stored at all.

**A-165 answered exactly this shape for the AWS↔Firebase seam**, four days ago, by declining to create a long-lived key and recording Workload Identity Federation as the answer if the seam ever has to be crossed. Deciding the CI seam inside a cleanup pass would settle the same question a second time, quietly, as a side effect of a chore — which is the failure A-164 records for Volume 7 Chapter 7.7 §3.

**Recommendation, not a decision: OIDC for CI, and Terraform-owned user with an out-of-band key for the human.** Both belong in one trace/decide with one ADR, because the answer to "long-lived or federated" should be the same for both seams or the difference should be argued.
