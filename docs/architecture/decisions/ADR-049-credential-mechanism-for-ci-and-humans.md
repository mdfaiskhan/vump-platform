# ADR-049 — Credential Mechanism for CI and Humans

- **Status:** Accepted
- **Date:** 2026-08-18
- **Supersedes:** none. Closes gap 17 of `docs/development/mission-6-gap-register.md`, and answers for two new seams the question A-165 answered for the AWS↔Firebase seam.

## Context

Until this record, account `929570731524` had **exactly one IAM principal**: `faisal-admin`, holding `AdministratorAccess` directly, with one access key created 2026-08-09 and never rotated. It created all 67 managed resources, ran all 9 migrations and set all 7 database passwords. There was no CI principal at all, no OIDC provider, no SAML provider, no IAM Identity Center instance, and the account is not a member of an AWS Organization. Every one of those was verified live at the start of Mission 7.1.

Four register items were downstream of one unanswered question:

- **Gap 1** — the blast radius above.
- **Gap 8** — the BR-08/11/21/22 behavioural proofs need live AWS; CI has none.
- **Gap 16** — ADR-048's authorizer exemption is a Terraform `check`, checks evaluate at `plan`, and CI runs no `plan` because it has no credentials.
- **Gap 2** — nothing applies a merged migration. Related, and **not decided here**: it needs a principal that can execute DDL.

The register's own words: *"they share a single upstream decision: may CI hold AWS credentials, and of what strength?"* A-165 declined a long-lived Firebase key four days earlier and recorded Workload Identity Federation as the answer if that seam is ever crossed. Deciding these two seams inside a cleanup pass would settle the same question a second and third time, quietly.

## Decision

### D-1 — CI federates through GitHub OIDC. No static key exists.

A GitHub Actions OIDC provider is registered against `token.actions.githubusercontent.com`. GitHub mints a signed JWT per job; AWS exchanges it for a session expiring in one hour. **Nothing is stored in GitHub Secrets**, so there is nothing in a secret store to steal.

**Two roles, because the capabilities differ and must not be merged:**

| Role | For | Strength |
|---|---|---|
| `vump-dev-ci-plan-reader` | Gap 16 — `terraform plan -lock=false` | Read-only |
| `vump-dev-ci-db-prover` | Gap 8 — the behavioural proofs | Writes to the dev database |

A single role with an OR'd condition would hand every PR-triggered job the write capability. The capability split is the point.

**The trust conditions bind to a GitHub Environment, not to a branch.** The OIDC `sub` claim is trigger-dependent: `…:ref:refs/heads/develop` on a push, but the literal `…:pull_request` on a pull request. A branch-only condition matches pushes and **silently fails to authenticate on pull requests** — which is exactly the trigger Gap 16's plan-on-PRs runs under. Declaring `environment:` replaces every form with one stable subject, so a `StringEquals` on a literal suffices and no wildcard appears in the identity portion of any trust policy.

**The subject is the immutable-identifier form, and this was measured rather than assumed:**

```
repo:mdfaiskhan@76160659/vump-platform@1326922888:environment:ci-plan
```

The numbers are the owner's and repository's GitHub database IDs. Every published example uses `repo:OWNER/REPO:…`; a policy written from documentation is denied with `Not authorized to perform sts:AssumeRoleWithWebIdentity` and no indication of which condition missed. A-171 records it.

Each role additionally asserts `aud = sts.amazonaws.com`, `repository`, and a `job_workflow_ref` pinned to the `ci.yml` path.

### D-2 — A Terraform-owned user, an out-of-band key, and MFA-gated roles.

`faisal-dev` is created by Terraform and holds **`sts:AssumeRole` and nothing else** — verified: `s3:GetObject`, `rds-data:ExecuteStatement` and `iam:CreateRole` all evaluate to `implicitDeny` against it. It may assume two roles, `vump-dev-human-operator` and `vump-dev-human-terraform-apply`, both of which require `aws:MultiFactorAuthPresent`. Day-to-day credentials are therefore one-hour STS sessions, and **the long-lived key is inert without the MFA device.**

**There is no `aws_iam_access_key` resource.** That resource writes the secret into Terraform state — the class of problem ADR-043 avoided for Aurora via `manage_master_user_password` and A-158 avoided for the seven database credentials, and a direct contradiction of ADR-016's rule that secrets live in Secrets Manager only. `pgp_key` does not rescue it: ciphertext in state is still state. The key is created once, out of band:

```
aws iam create-access-key --user-name faisal-dev
```

`faisal-admin` is **retained as break-glass** and is not deleted. Gap 1 closes to *"faisal-admin is break-glass"*, never to *"faisal-admin is gone"*.

### D-3 — A permissions boundary, because D-2 is otherwise cosmetic.

`terraform-apply` must create IAM roles and attach policies — 23 of the 67 resources are IAM. **A principal that can create a role and put a policy on it can create an administrator and assume it.** Without containment, D-2 would replace a principal holding `AdministratorAccess` with one that can grant itself `AdministratorAccess`.

`vump-dev-boundary` is attached to every Terraform-created role: the seven Lambda execution roles, both CI roles, and the human operator role. It **grants no IAM write of any kind**. `terraform-apply` is explicitly denied `iam:CreateRole`, `iam:PutRolePolicy` and `iam:AttachRolePolicy` unless the request carries `iam:PermissionsBoundary` equal to this policy — so any role it creates is capped by a document that cannot climb.

`terraform-apply` itself carries no boundary, and that is not an oversight: the boundary grants no `iam:CreateRole`, so a bounded `terraform-apply` could not create the Lambda roles. Its containment is three `Deny` statements instead, the third of which puts **identity-shaped IAM off limits entirely** — its own role, the operator role, the `faisal-dev` user and the boundary policy. Those stay with `faisal-admin` as a deliberate break-glass step.

## Alternatives Considered

- **Static access keys in GitHub Secrets** — rejected. The realistic leak vector is not GitHub being breached but the repository itself: a repo secret is readable by any workflow on any branch, and exfiltrating it is one committed line of YAML. Three project-specific facts made it worse rather than merely worse-in-general: ADR-016 records that the seven database secrets rotate only when someone re-runs `db:bootstrap`, `faisal-admin`'s own key was 9 days old and never rotated, so a "rotated regularly" static key was not a real option; **CloudTrail is not enabled** (A-019), so a stolen key's use would appear only in the non-durable 90-day Event history; and **the repository is public**.
- **`aws_iam_access_key` for the human** — rejected. See D-2.
- **One CI role with an OR'd `sub` condition** — rejected. It merges a read capability with a database-write capability.
- **A ref-based `sub` condition** — rejected. It needs `StringLike` for `release/**` and `hotfix/**`, and silently fails on `pull_request`.
- **The AWS-managed `ReadOnlyAccess` policy for plan-reader** — rejected. It carries `s3:GetObject` on every bucket, reaching the evidentiary footage ADR-043 deliberately keeps outside Terraform's blast radius.
- **Granting db-prover the RDS master credential** — rejected on **correctness** before blast radius. The master user bypasses every `GRANT` in migration `0007` and every trigger in `0006`, so a behavioural proof run as master would pass while proving nothing.
- **Name-prefix scoping instead of a boundary (Fork A2)** — rejected. `terraform-apply` could still `PutRolePolicy` an `Action: "*"` onto `vump-dev-anything` and assume it. It narrows the blast radius without closing the escalation.
- **`terraform-apply` with no IAM permissions at all (Fork A3)** — rejected as the answer, retained as the shape for identity IAM specifically.
- **IAM Identity Center** — the textbook answer, and deferred rather than rejected. It gives the human short-lived credentials with no long-lived key at all, and it is free, but it requires AWS Organizations and this is a standalone account. ADR-014's multi-account target is where it belongs. The assume-role shape adopted here is a strict subset, so adopting Identity Center later replaces the bootstrap user without disturbing anything downstream.

## Consequences

- **Gap 16 closes.** CI runs `terraform plan`, so ADR-048's `check` block evaluates. Running the plan was necessary and **not sufficient** — a failed check is a *warning*, not an error, so a separate CI step fails the job on one. Both halves were needed.
- **Gap 8 does not close.** The credential exists and is correctly scoped; **the proofs are not yet a CI job**. A-173 records why: migration `0007` grants `DELETE` to no role, so the proofs can seed and assert but cannot tear down, and the master credential that the uncommitted scratchpad used for teardown is now correctly denied.
- **Gap 1 closes forward-looking only.** It changes who acts from now on. The 67 resources, 9 migrations and 7 credentials `faisal-admin` already created are unchanged.
- **The register's "a read-only principal closes gap 8" was wrong**, and A-172 records the correction: the proofs write, so they need `db-prover` rather than `plan-reader`.
- **Gap 2 is untouched.** It needs a DDL-capable principal, which is a different question.
- **Terraform's drift detection stops at the user.** A second access key created by hand, or a key never rotated, is invisible to `plan`, because no `aws_iam_access_key` resource exists. `aws iam list-access-keys --user-name faisal-dev` is the covering check.
- **`pull_request_target` is now forbidden by CI.** On a public repository holding OIDC roles it runs fork-authored code in the base-repo context, where these roles are assumable. What protects the design today is that fork PRs cannot be granted `id-token: write` — a GitHub property, not one this repository controls, and that trigger is the one way to lose it from inside.
- **A pull request may edit `ci.yml` and assume `plan-reader` in the same run.** `job_workflow_ref` permits `refs/pull/*/merge`, because a `pull_request` run uses the merge ref and pinning to `refs/heads/develop` alone would reject *every* pull request, not merely those editing the workflow. Mission 7.1 Part 2a asserted the narrower claim and was wrong; A-174 records the correction. The trade is acceptable because `plan-reader` is read-only and explicitly denied the evidentiary buckets; it would **not** be acceptable for a role that could write, and `db-prover` should be reconsidered on this point when its CI job is built.
- **The `sub` claim's numeric IDs are load-bearing.** If the GitHub account or repository is ever deleted and recreated, federation breaks rather than silently trusting a re-registered name. That is the desired failure.
- **`environment: ci-plan` in `ci.yml` is not cosmetic.** Removing that line does not relax authentication, it breaks it — the subject changes to a trigger-dependent form that no trust policy matches.
- **Two GitHub Environments now exist**, `ci-plan` and `ci-db-proof`. They carry no protection rules today; the repository is public, so required reviewers are available for free and are the obvious hardening for `ci-db-proof` before its job is built.
- **`faisal-dev` needs its own MFA device, and `1_work_laptop` is not it.** *(Added 2026-08-18, after the decision was applied.)* IAM MFA devices are **per-user, not account-wide**: a device enrolled against `faisal-admin` satisfies `aws:MultiFactorAuthPresent` only for sessions authenticated as `faisal-admin`. Because both human roles trust `faisal-dev` and require MFA, `faisal-dev` must carry a device of its own or **neither role is assumable at all** — the user would hold a key that grants literally nothing, which is the design working exactly as intended and looking like a broken deployment. Mission 7.1's close-out gave `mfa_serial = arn:aws:iam::929570731524:mfa/1_work_laptop` in the sample `~/.aws/config`, which is wrong for this reason; the correct value is the serial of the device enrolled against `faisal-dev`, which is `arn:aws:iam::929570731524:mfa/2_dev_faisal`. This is the same class of error as A-171 — a plausible value that fails closed with a message naming no cause — and it is recorded here rather than fixed silently, because the wrong line was handed over as an instruction to run.
- **Identity IAM is break-glass.** Changing the boundary, the `faisal-dev` user or either human role requires `faisal-admin`. That is friction by design, and it is the friction that closes the escalation.
- **The account-global resources live in the `dev` root.** The OIDC provider and the `faisal-dev` user are account-wide, not per-environment. `manage_account_identity` guards this: staging and prod must set it `false` when they arrive, or the apply fails on a duplicate.

## Related Missions

- Mission 6.7 — authorised to build both principals and built neither, because each ran into this decision.
- Mission 7.1 — Credential Mechanism, which produced this record.

## Implementation Status

**Implemented and applied.**

| | Decision | Current state |
|---|---|---|
| GitHub OIDC provider | Required | ✅ `token.actions.githubusercontent.com`, `aud` `sts.amazonaws.com` |
| `plan-reader` role | Read-only | ✅ Live, boundary attached |
| `db-prover` role | Write, no master credential | ✅ Live, boundary attached |
| `faisal-dev` user | `sts:AssumeRole` only | ✅ Live |
| Human roles | MFA-gated | ✅ Both live |
| Permissions boundary | On every Terraform-created role | ✅ 10 roles; `terraform-apply` deliberately excluded |
| No secret in state | Required | ✅ No `aws_iam_access_key` resource exists |
| CI runs `terraform plan` | Gap 16 | ✅ Run 32123773224, 13 of 13 jobs green |
| Check-block failure fails CI | Gap 16's second half | ✅ Step present and passing |
| `pull_request_target` guard | New | ✅ Own job, passing |
| **`faisal-dev` access key** | Out of band | ❌ **Not yet created — the user runs this** |
| **`faisal-admin` key rotated** | Demote to break-glass | ❌ **Not yet. Deliberate: not before the new path is proven end-to-end** |
| **`db-prover` exercised** | Gap 8 | ❌ No CI job exists to exercise it |
| **`ref`-shape assumption** | Both trigger shapes | ⚠️ Proven only for `pull_request`. The `ref` form cannot run until this merges to `develop` — see A-175 |
