# ADR-043 — Infrastructure as Code: Terraform

- **Status:** Accepted
- **Date:** 2026-08-17
- **Supersedes:** none. Closes the deferral in Volume 4, Chapter 4.9 §5, which sent the choice to Volume 7 — where it was never made.

## Context

Volume 4, Chapter 4.9 §5 defers *"Infrastructure-as-code tooling (CDK/Terraform/CloudFormation) choice — Volume 7."* Volume 7, Chapter 7.8 covers per-developer IAM users, CLI profiles and credential hygiene, and **never takes the decision**. The deferral was never discharged, and nothing in the repository has had authority to provision anything.

The consequence is visible in `infrastructure/aws/README.md`, which says so plainly: *"This is not infrastructure-as-code. There is no state file and nothing detects drift."* Eighteen files declare AWS state; a human applies them with `aws s3api` commands copied from a README. That was an honest substitute for three S3 buckets and their policies. It does not survive contact with a VPC, an Aurora cluster and six IAM roles, where the resources have dependencies on each other and the order of application matters.

Mission 6.1 cannot proceed without closing this. A VPC applied by hand has no record of which subnet belongs to which route table beyond the memory of whoever typed it.

## Decision

**Terraform is the infrastructure-as-code tool for this repository.**

Concretely, this fixes:

- **Tool** — Terraform, `>= 1.11`, pinned in every module's `required_version`.
- **Provider** — `hashicorp/aws ~> 6.0`, with the exact version recorded in `.terraform.lock.hcl` and committed.
- **Layout** — `infrastructure/terraform/`, split into `modules/` (network, database, iam) and `environments/{slug}/` root modules. One root module per environment, sharing the modules.
- **State** — S3, bucket `vump-platform-tfstate`, key `{slug}/terraform.tfstate`, encrypted, versioned. **S3-native locking** via `use_lockfile`, which is why no DynamoDB lock table exists.
- **Applied deliberately, never by CI**, per `folder-structure.md` §1.3. A pipeline that can apply infrastructure is a pipeline that can destroy it.

Existing hand-applied configuration in `infrastructure/aws/` is **not migrated**. The three S3 buckets, their lifecycle rules and their bucket policies stay where they are, and `infrastructure/aws/README.md` continues to govern them. Terraform owns what Terraform created.

### Why the split, rather than one tool for everything

Importing three buckets that already exist, are correct, and are governed by a README with verification commands would buy consistency and risk a `terraform destroy` reaching production footage. The buckets hold evidentiary recordings under Volume 8, Chapter 8.7's retention obligations; they are the one thing in this account that cannot be recreated.

This is a real cost, stated rather than hidden: **there are now two mechanisms for AWS state**, and a reader has to know which governs what. The boundary is drawn at what already exists — everything provisioned from Mission 6.1 onward is Terraform's.

### Why not the alternatives

The full trade-off was traced in Mission 6.1's report. In short:

- **AWS CDK (TypeScript)** — the strongest alternative, and the one with the best language story: same TypeScript as the backend (ADR-015), one toolchain, and `grant*` methods that generate least-privilege IAM automatically. Rejected on two counts. Its generated IAM is convenient precisely where this project needs deliberation — Volume 4, Chapter 4.9 §2's per-function narrowness is the thing most easily lost to a helper that emits a slightly broader policy than asked. And its state is CloudFormation's, so a failed Aurora update rolls back on CloudFormation's terms rather than ours.
- **AWS SAM** — rejected. It is a Lambda and API Gateway tool, and Mission 6.1 provisions neither. A VPC, subnets, security groups and an Aurora cluster all fall through to raw CloudFormation YAML, so the entire mission would be written in the part of SAM that is not SAM. It also has no answer for the account-level controls Volume 8, Chapter 8.4 §3 and §4 require — Block Public Access, CloudTrail, GuardDuty.
- **Continuing with hand-applied JSON** — rejected, and it is the status quo. It has no state, no dependency ordering and no drift detection, and its own README says so.

### What Terraform costs

HCL is a third language in a repository that is otherwise Dart and TypeScript, and ADR-015 counts single-language uniformity as a benefit for the backend. That benefit does not extend here: infrastructure is not application code, and the alternative that preserved the uniformity (CDK) was rejected for reasons unrelated to language.

Licensing is noted rather than resolved: Terraform is BUSL-licensed since 1.5. Nothing in this project's use — a single team provisioning its own infrastructure — approaches the competitive-use restriction. OpenTofu is a drop-in fork if that position ever changes, and the configuration in this repository would work under it unmodified.

## Alternatives Considered

- **AWS CDK** — see above. The closest call, rejected on generated IAM and CloudFormation state semantics.
- **AWS SAM** — rejected. Optimises for Mission 6.2 at the cost of 6.1 and of Volume 8's account-level requirements.
- **Raw CloudFormation** — rejected. It is what CDK and SAM compile to, and writing it directly gives their state model with none of their ergonomics.
- **Pulumi** — not seriously considered. It shares CDK's language advantage and adds a fourth vendor relationship for a repository that has not yet provisioned a single server.
- **Importing the existing S3 buckets into Terraform** — rejected for now. Consistency is worth less than keeping the production footage bucket outside the blast radius of a `destroy`. Revisit when separate AWS accounts exist (ADR-014's target architecture), because the blast radius is what changes.
- **A DynamoDB lock table** — rejected as unnecessary. S3-native locking has done the job since Terraform 1.11, and a lock table is a resource to provision, pay for and forget to create per environment.
- **One root module with a `workspace` per environment** — rejected. Workspaces share a configuration, so a change intended for dev is one `terraform apply` away from production, and the difference is invisible in the diff. A directory per environment makes the target explicit in the path.

## Consequences

- The IaC deferral from Volume 4, Chapter 4.9 §5 is closed. Amendment A-141 records it against the volume.
- **Two mechanisms now govern AWS state.** `infrastructure/aws/` for what exists; `infrastructure/terraform/` for what follows. A reader must know the boundary, and it is documented in both READMEs.
- The state bucket is a manual prerequisite. It cannot be created by the configuration that stores its state in it, so `infrastructure/terraform/README.md` carries the four CLI commands that create and harden it. This is a genuine bootstrap gap, not an omission.
- Terraform state contains resource attributes, and for some resource types that includes secret material. It is why the state bucket is encrypted, versioned and Block-Public-Access'd, and why `manage_master_user_password` matters (ADR-044) — no password is expressed in the configuration, so none reaches the state.
- A third language and a third toolchain. CI does not run it yet; adding a `terraform validate` and `tflint` job is the obvious next step and is not this mission's.
- `folder-structure.md` §1.3's inventory of what `infrastructure/` owns is now wider by one directory.
- Nothing has been applied. The configuration plans cleanly and provisions nothing until someone runs `apply` deliberately.

## Related Missions

- Mission 6.1 — AWS Foundations, which needed the decision and produced this record.

## Implementation Status

**Implemented, not applied.**

| | Decision | Current state |
|---|---|---|
| Terraform as the tool | Required | ✅ `infrastructure/terraform/` |
| Module split | network / database / iam | ✅ Three modules |
| Root module per environment | One per slug | ✅ `environments/dev/` only — staging and prod are Mission 6.4/6.5 |
| S3 state backend | `vump-platform-tfstate` | ✅ Created, versioned, encrypted, BPA on |
| S3-native locking | `use_lockfile` | ✅ No DynamoDB table exists |
| Provider lock committed | Required | ✅ `.terraform.lock.hcl`, aws v6.60.0 |
| `terraform validate` clean | Required | ✅ |
| `tflint` clean | Required | ✅ 0 issues, `terraform` + `aws` rulesets |
| Applied to AWS | — | ❌ **Nothing applied.** Plan only: 32 to add, 0 to change, 0 to destroy |
| CI runs Terraform checks | Not decided here | ❌ Not built |
