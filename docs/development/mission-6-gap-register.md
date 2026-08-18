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
| 1 | **Every AWS resource, schema change and database password was created by `faisal-admin`**, an unscoped administrative principal. 67 managed resources, 9 migrations, 7 credentials. **Closed forward-looking only (ADR-049):** `faisal-dev` now exists and `faisal-admin` is break-glass. What it already created is unchanged | Blast radius | A-144, item 8, **ADR-049** |
| 2 | **Nothing applies a merged migration.** A schema change can be written, reviewed, merged and released without reaching a database; neither CI nor the runner notices. Closing it means giving CI credentials that can `DROP` | Enforcement + credential decision | A-161, item 11 |
| 3 | **The seven per-function database secrets rotate manually.** V8.4 §2's automatic RDS rotation covers the master credential only; nothing schedules the rest | Credential lifecycle | ADR-016 |
| 4 | **Nothing issues the `admin` claim.** `firestore.rules` requires it to write `org_invite_codes`, and `redeemInviteCode` sets `role: "collector"` from a literal on every path — so that collection is writable by nobody, and admin is an undocumented manual bootstrap | Unreachable capability | A-158, ADR-036 |
| 5 | **Four live accounts carry `org_id: "vump-default"`**, a literal that no longer matches anything. It is mapped to the `Unassigned` org at read time by `resolveOrgId` and never rewritten, so the stale value persists in every token | Data shape | A-163, item 12 |
| 6 | **Every self-signup account lands in one shared organisation.** BR-20's tenant isolation therefore separates nobody among them. Acceptable only while ADR-036's "informal APK sharing among a trusted group" holds — **revisit before public distribution** | Tenant isolation, time-bounded | Migration `0009`, A-166 |
| 7 | **`functions/` is not retired** and claim-writing stays in Cloud Functions. Deliberate: porting it moves the writer outside Google, which is the only thing that forces the credential ADR-036 defers | Deliberate, with a trigger | A-165, item 10 |
| 8 | **The BR-08/11/21/22 behavioural proofs exist only as an uncommitted scratchpad script.** **Still open after ADR-049, and the reason has moved rather than gone:** the credential exists (`vump-dev-ci-db-prover`) and no CI job runs the proofs. Migration `0007` grants `DELETE` to nobody, so they cannot tear down. **This row said a read-only principal would close it; that was wrong — the proofs write** | Test coverage | 6.3.1 close-out, **A-172**, **A-173** |
| 9 | **Aurora runs at `MinCapacity 0` and auto-pauses.** ~~The first request after idle *can* exceed the Lambda's 15-second timeout~~ — **CONFIRMED, and it did**: 15876ms, 15889ms **and a third at 15428ms (21:02:37, 7.2's F5 self-heal — observed then, recorded only at 7.3)** against a 15000ms timeout on CPH2707, 2026-08-18. Until A-178 its consequence was not slowness but **an ended session**; the third occurrence self-healed, which is A-178 working. **Three occurrences across two launches makes it recurrent, not a one-off.** Timeout raised to 28s by Mission 7.3 — which does **not** close this: AWS documents a deep-sleep resume of **"30 seconds or longer"** after >24h idle and recommends timeouts of "30 seconds or more", and API Gateway's REST integration ceiling is **29s**, so AWS's own recommendation is unreachable through the API. An account quota increase to ~35–40s is being requested; until it lands 28s is **provisional**. **Mission 7.3's F4 measurement bears on the raised value:** hashing a real 633,232,477-byte chunk takes 7780ms at 1769MB (24.44 MB/s at 512MB, 81.39 MB/s at 1769MB, identical digests). Traced against ADR-048, that cost does **not** stack with the resume inside `chunks-verify` — the authorizer runs first with TTL 0 and pays the resume, so the cluster is awake before that handler starts. **The stacking risk lives in `auth-verify`**, which must absorb a deep-sleep resume in one invocation on the same ceiling, on the critical path of all fourteen authorized routes. Size the raised timeout on the authorizer's resume, and check the hash as a separate smaller budget. Design-level trace, not a measurement — recheck if verification ever runs off an S3 event instead (Ch 4.10 §2 step 3). Still open; reassess severity | Availability, **confirmed with consequence, recurrent** | A-156, ADR-043, **A-178** |
| 10 | **`GET /v1/users/me` and every route behind the authorizer add a Data API round-trip per request**, with `authorizerResultTtlInSeconds = 0`. Correctness was chosen over caching, unmeasured | Performance | ADR-048 |
| 11 | **CLOSED by Mission 7.2 (A-177).** ~~`POST /v1/auth/verify` fires twice per app launch.~~ `AuthNotifier.build` no longer calls `restoreSession`; 4 of 4 cold starts on CPH2707 now perform exactly one exchange. **Two further findings came out of fixing it:** a transient 5xx used to sign the user out (A-178) and **sign-in had its own duplicate with a different cause** (A-180) — this row's "per app launch" wording never covered that | Efficiency, now closed | 6.5.6 close-out, **A-177**, **A-178**, **A-180** |
| 12 | **`execute-api` hostnames are invisible to the AWS endpoint check** after A-168's narrowing. The three credential-material checks are unaffected and remain the disclosure guarantee | Narrowed guarantee, accepted | A-168 |
| 13 | **iOS is registered, unwired and unverifiable.** Bundle IDs exist in all three Firebase projects and the plists are committed, but `project.pbxproj` still carries `com.example.mobile` and nothing selects a plist. No Mac, no Apple Developer account | Platform | item 2, ADR-047 |
| 14 | **Staging and production have no Auth, no billing and no API Gateway.** Deliberate under ADR-014 until a release branch is cut | Deliberate | item 13, A-162 |
| 15 | **The backend has no coverage gate.** ADR-045 recorded it as "deliberately absent — revisit at 6.3"; 6.3 passed without revisiting | Overdue commitment | ADR-045 |
| 16 | **The authorizer exemption is asserted, not enforced.** ~~The Terraform `check` only evaluates during `plan`/`apply`, CI runs no `plan`~~ — **CLOSED by ADR-049.** CI assumes `vump-dev-ci-plan-reader` via OIDC and runs `terraform plan -lock=false`, and a separate step fails the job on a failed `check`, since a failed check is only a warning. Both halves were needed | Enforcement | ADR-048, 6.6, **ADR-049** |
| 17 | **CLOSED by ADR-049.** ~~No scoped principal exists for either a human or CI.~~ Gap 1 wants a per-developer IAM user (Volume 7 Ch 7.8 §1); gaps 8 and 16 want a read-only CI principal. Both reduce to the same question — **a long-lived key, or federated short-lived access** — and it is A-165's question asked of two new seams. Queued for its own trace/decide | Credential mechanism | A-165, item 8, gaps 1/8/16 |

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


---

## What Mission 7.1 changed (2026-08-18)

Gap 17 is closed by **ADR-049**: GitHub OIDC for CI, a Terraform-owned `faisal-dev` with an out-of-band key for the human, and a permissions boundary that stops `terraform-apply` escalating to administrator.

The knock-on, stated without rounding up:

- **16 closes.** Fully. `terraform plan` runs in CI and a failed `check` now fails the job.
- **1 closes forward-looking only.** The 67 resources `faisal-admin` created remain as they are.
- **8 stays open.** It has its credential and lacks a runnable proof suite — A-173. Logging this as closed would be the second time this row was rounded up.
- **2 is untouched**, deliberately. It needs a DDL-capable principal.

Two corrections to this file's own earlier text are recorded rather than silently applied: **A-172** (a read-only principal does not close gap 8) and **A-170** (the account held 67 resources, not ADR-043's 66; it now holds 79).


---

## What Mission 7.2 changed (2026-08-18)

An auth hardening pass, not the fake-to-real swap it was originally scoped as — `FakeAuthRepository` does not exist in `lib/` and has not since Mission 6.5.

- **11 closes** (A-177), device-proven.
- **9 is confirmed rather than closed** (A-178). It was filed as a possibility and is now a reproduced observation with a user-facing consequence.
- **Two new defects were found by fixing the first one**: A-178 (a 502 destroyed the session) and A-180 (sign-in duplicated the exchange for a different reason). Both fixed here.
- **15 gains a cross-reference**: `features/auth/domain/` produces no `lcov` entry at all, which under A-046's rule is worse than 0% — a file no test imports does not appear as untested, it does not appear. Deferred to the coverage-gate work by decision, not oversight.

One thing this pass did **not** produce is an ADR. Nothing in ADR-034, ADR-035 or ADR-048 was contradicted or amended; each was implemented incorrectly and now is not.
