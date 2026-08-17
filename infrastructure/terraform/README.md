# Terraform

Infrastructure as code for AWS, per **ADR-043**.

Everything provisioned from Mission 6.1 onward lives here. Everything that
existed before it — the three S3 buckets, their lifecycle rules and bucket
policies, the CloudFront configuration — stays in `../aws/` and is applied by
hand from that directory's README.

**The boundary is what already existed.** ADR-043 records why the buckets were
not imported: they hold evidentiary footage under Volume 8, Chapter 8.7's
retention obligations, and they are the one thing in this account that cannot be
recreated. Consistency was worth less than keeping them outside the blast radius
of a `terraform destroy`.

---

## Layout

```
infrastructure/terraform/
├── .tflint.hcl
├── modules/
│   ├── network/     VPC, subnets, route table, security groups
│   ├── database/    Aurora Serverless v2 cluster, subnet group, parameter group
│   └── iam/         Six Lambda execution roles (ADR-015 domains)
└── environments/
    └── dev/         The only environment provisioned. Staging and prod: Mission 6.4/6.5
```

One root module per environment, sharing the modules. **Not Terraform
workspaces** — a workspace shares a configuration, so a change meant for dev is
one `apply` away from production and the difference is invisible in the diff. A
directory per environment puts the target in the path.

---

## Prerequisites

### 1. The state bucket

State lives in `vump-platform-tfstate`. **It cannot be created by Terraform**,
because the configuration that would create it is the configuration that stores
its state in it. These four commands are the bootstrap, run once per account:

```bash
aws s3api create-bucket \
  --bucket vump-platform-tfstate \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
  --bucket vump-platform-tfstate \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket vump-platform-tfstate \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

aws s3api put-public-access-block \
  --bucket vump-platform-tfstate \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

**Versioning is not optional.** Terraform state is the only record of which real
resource each configuration block refers to; a corrupted or truncated state file
with no previous version means reconciling by hand against the console.

Locking is **S3-native** (`use_lockfile` in `backend.tf`). There is no DynamoDB
lock table, and one should not be added — that requirement went away in
Terraform 1.11.

### 2. Credentials

From the AWS provider chain, per ADR-016. A profile, never an access key in a
file. No `AWS_ACCESS_KEY_ID` appears anywhere in this directory and none should.

---

## Running it

```bash
cd environments/dev

terraform init
terraform validate
terraform plan -out=dev.tfplan
```

`terraform apply` is run **deliberately, by a human, never by CI**
(`docs/architecture/folder-structure.md` §1.3). A pipeline that can apply
infrastructure is a pipeline that can destroy it.

### Checks

```bash
terraform fmt -recursive -check -diff     # from infrastructure/terraform/
tflint --recursive                        # from infrastructure/terraform/
```

`tflint` needs `tflint --init` once to fetch the AWS ruleset pinned in
`.tflint.hcl`.

---

## What the dev environment contains

| | |
|---|---|
| **VPC** | `10.0.0.0/16`. Does not collide with the account's default VPC (`172.31.0.0/16`), which Terraform does not manage. |
| **Subnets** | Two private, `10.0.20.0/24` in `ap-south-1a` and `10.0.21.0/24` in `ap-south-1b`. Aurora requires two AZs. |
| **Gateways** | **None.** No internet gateway, no NAT, no VPC endpoints. |
| **Security groups** | The Aurora group carries **no rules**. The VPC's default group is adopted and emptied. |
| **Aurora** | Serverless v2, PostgreSQL 16.14, 0–2 ACU, one writer, no reader. Encrypted, 7-day backups. |
| **Data API** | Enabled. It is the only way to reach the cluster. |
| **IAM** | Six execution roles, one per ADR-015 domain, with no function attached yet. |

### The CIDR plan, including what is not built

`10.0.0.0/16` is carved with room for the design ADR-044 did **not** choose, so
that adopting it later does not mean re-addressing the VPC:

| Range | Purpose | Provisioned |
|---|---|---|
| `10.0.0.0/24`, `10.0.1.0/24` | Public — NAT, load balancers | ❌ Reserved, not built |
| `10.0.10.0/24`, `10.0.11.0/24` | Application — VPC-attached Lambda ENIs | ❌ Reserved, not built |
| `10.0.20.0/24`, `10.0.21.0/24` | Database | ✅ |

Nothing unused is provisioned. The reservation is a note here, not a resource.

---

## Two things that will surprise someone

**Nothing can open a Postgres connection to the cluster.** Not a bastion, not a
laptop, not a Lambda. The security group has no ingress rule and the VPC has no
gateway. Under ADR-044 that is correct — the Data API is an HTTPS endpoint
outside the VPC — but it means **schema migration (Mission 6.3) must run through
the Data API**, or this configuration needs a deliberate change. It is not an
oversight to be patched at the moment it is discovered.

**The engine version is constrained by a table AWS maintains, not by what RDS
offers.** PostgreSQL 18 is available in `ap-south-1` and is absent from the Data
API support list, so upgrading to it would remove the only access path the
backend has. `describe-db-engine-versions` will not warn you — it reports no
Data API support information at all. See ADR-044 and amendment A-142.

---

## Governing decisions

| Concern | Record |
|---|---|
| Terraform as the IaC tool, state, layout | ADR-043 |
| Data API as the sole database access path | ADR-044 |
| Six Lambda domains | ADR-015 |
| Region, bucket naming | ADR-011 |
| Environment purpose and promotion | ADR-014 |
| Secrets in Secrets Manager, ARNs not values | ADR-016 |
| Resource naming, `dev` slug rather than `development` | ADR-023 |

Where a file here and an accepted ADR disagree, the ADR governs and the file is
a defect.
