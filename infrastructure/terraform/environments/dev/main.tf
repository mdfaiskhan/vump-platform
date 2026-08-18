# Development environment. ADR-014 assigns it synthetic, disposable data and
# permits it to be broken; nothing here is shaped for production durability.
#
# Scope is Mission 6.1: networking, the Aurora cluster, and the six Lambda
# execution roles. No Lambda function, no API Gateway, no schema, no Firebase.

locals {
  # The seven functions, named once. ADR-015's six domains with chunks split in
  # two (A-143). The api-gateway module derives the same list from its route
  # table; this is the copy the credential and IAM modules share.
  lambda_functions = [
    "auth-verify",
    "projects",
    "tasks",
    "sessions",
    "chunks-upload",
    "chunks-verify",
    "metadata",
  ]

  # The .tmpl files in infrastructure/aws/iam/ are rendered here rather than
  # restated in HCL, so the S3 grants have one definition. Their placeholders
  # predate Terraform and use __TOKEN__ rather than ${...}, so they are
  # substituted directly instead of through templatefile().
  #
  # This is the first time anything renders these templates. Until now they were
  # declarations no tool applied.
  chunk_s3_policy_documents = {
    for name, path in {
      "presign-upload" = "${path.module}/../../../aws/iam/chunks-presign-upload-s3-policy.json.tmpl"
      "verify-object"  = "${path.module}/../../../aws/iam/chunks-verify-object-s3-policy.json.tmpl"
      } : name => replace(
      replace(file(path), "__ENV__", var.environment_slug),
      "__BUCKET__", var.chunk_bucket,
    )
  }
}

module "network" {
  source = "../../modules/network"

  environment_slug = var.environment_slug
  vpc_cidr         = var.vpc_cidr
  database_subnets = var.database_subnets
}

module "database" {
  source = "../../modules/database"

  environment_slug        = var.environment_slug
  engine_version          = var.engine_version
  database_name           = var.database_name
  master_username         = var.master_username
  min_capacity            = var.min_capacity
  max_capacity            = var.max_capacity
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  subnet_ids         = module.network.database_subnet_ids
  security_group_ids = [module.network.aurora_security_group_id]
}

# Mission 6.3. One database credential per function.
#
# Containers only — no password is generated here, because a `random_password`
# would put every database credential into Terraform state. `npm run
# db:bootstrap` fills them. See the module for the full reasoning.
module "db_credentials" {
  source = "../../modules/db-credentials"

  environment_slug = var.environment_slug
  function_names   = toset(local.lambda_functions)
}

module "iam" {
  source = "../../modules/iam"

  environment_slug          = var.environment_slug
  cluster_arn               = module.database.cluster_arn
  master_user_secret_arn    = module.database.master_user_secret_arn
  chunk_s3_policy_documents = local.chunk_s3_policy_documents
  db_credential_secret_arns = module.db_credentials.secret_arns

  # ADR-049. The GitHub OIDC provider, the two CI roles, the faisal-dev user and
  # its two MFA-gated roles, all capped by the permissions boundary.
  #
  # dev owns the account-global half (the provider and the user) because it is
  # the only environment root that exists. staging and prod must set
  # manage_account_identity = false when they arrive.
  github_repository       = var.github_repository
  github_repository_owner = var.github_repository_owner
  github_repository_name  = var.github_repository_name
  github_owner_id         = var.github_owner_id
  github_repository_id    = var.github_repository_id
  state_bucket            = var.state_bucket
  chunk_bucket            = var.chunk_bucket
  evidentiary_buckets     = var.evidentiary_buckets
  manage_account_identity = true
}

# Mission 6.2. The seven Lambda functions and the REST API in front of them.
#
# `artifacts_dir` points at esbuild output that this configuration does not
# build. `npm run build` in backend/ must have run first, or the archive data
# source fails at plan with a missing directory. That coupling is deliberate:
# Terraform is not a build tool, and having it shell out to npm would make a
# plan depend on a toolchain the IaC has no way to pin.
module "api_gateway" {
  source = "../../modules/api-gateway"

  environment_slug = var.environment_slug
  region           = var.region
  artifacts_dir    = "${path.module}/../../../../backend/artifacts"

  lambda_role_arns = module.iam.role_arns

  # Non-secret only. The two secret ARNs below are identifiers, not values —
  # ADR-016: "A secret ARN is not a secret. It is an identifier; possessing it
  # grants nothing without IAM permission to read the secret behind it."
  # AWS_REGION is deliberately absent: it is a reserved Lambda variable that the
  # runtime sets itself, and setting it here is rejected at create time.
  # `loadConfig` reads the runtime's copy.
  lambda_environment = {
    CHUNK_BUCKET           = var.chunk_bucket
    PRESIGN_EXPIRY_SECONDS = tostring(var.presign_expiry_seconds)
    DATABASE_CLUSTER_ARN   = module.database.cluster_arn
    DATABASE_NAME          = module.database.database_name
    FIREBASE_PROJECT_ID    = var.firebase_project_id
  }

  # DATABASE_CREDENTIALS_SECRET_ARN is per-function, not shared, so it is
  # supplied separately and merged inside the module.
  #
  # Mission 6.3 created seven credentials and repointed seven IAM policies at
  # them, and left every function's *environment* naming the master secret.
  # Nothing failed, because no handler issued a query until Mission 6.5 — the
  # first real request found it immediately: IAM denied the master secret the
  # function was configured to use. A-158's per-function isolation was correct
  # in IAM and in PostgreSQL, and unreachable at runtime.
  db_credential_secret_arns = module.db_credentials.secret_arns

  # chunks-verify hashes the uploaded object; the other six do small reads and
  # writes. Volume 4 Chapter 4.5 §3 makes it verify `checksum_sha256` "against
  # the actual uploaded S3 object", and Mission 3.8.1 measured a real chunk at
  # 633,232,477 bytes.
  #
  # **Measured, not estimated** — Mission 7.3's `chunk-hash-probe`, streaming
  # GetObject through SHA-256 on that exact object size:
  #
  #   |  memory | total  | throughput  | margin to API Gateway's 29s |
  #   |---------|--------|-------------|-----------------------------|
  #   |   512MB | 25908ms| 24.44 MB/s  | 3092ms                      |
  #   |  1769MB |  7780ms| 81.39 MB/s  | 21220ms                     |
  #
  # Both tiers returned the identical digest, so this buys time and changes no
  # result.
  #
  # 512MB would have fit — with 3.1 seconds to spare on a 29-second ceiling, for
  # a call that also has to reach Aurora before and after the hash. That is not
  # margin, it is a coin toss on a slow day.
  #
  # **The cost is a wash**, which is what makes this uninteresting rather than a
  # trade-off: 25908ms x 512MB = 13,265 MB-seconds against 7780ms x 1769MB =
  # 13,760 MB-seconds. Lambda bills memory x duration, and 3.3x the memory for
  # 3.3x less time is the same bill. 1769MB is where a function gets one full
  # vCPU, and network scales on the same curve.
  lambda_overrides = {
    "chunks-verify" = { memory_mb = 1769 }
  }
}
