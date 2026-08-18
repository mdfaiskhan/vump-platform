# Lambda execution roles for ADR-015's six resource domains.
#
# **A role is not a domain.** ADR-015 fixes six domains — auth-verify, projects,
# tasks, sessions, chunks, metadata — and that decomposition is unchanged here. A
# domain is a unit of code decomposition; a role is a unit of privilege, and
# nothing requires them to be one-to-one. The `chunks` domain carries two roles
# because it does two things with opposite S3 needs, and Volume 4, Chapter 4.9 §2
# requires the separation:
#
#   "the chunk-registration Lambda can generate presigned S3 URLs but cannot
#    itself read arbitrary S3 objects; the metadata Lambda can write to
#    chunk_metadata but has no S3 permissions at all."
#
# The separation is load-bearing rather than tidy. A presigned URL carries the
# signer's permissions, so a role holding both s3:PutObject and s3:GetObject can
# presign a *read* of raw footage — and presigned URLs are handed to devices by
# design. Withholding GetObject from the upload role is what makes that
# impossible rather than merely unintended. See amendment A-143.
#
# The roles exist before the functions do. That order is deliberate: Mission 6.2
# writes handlers against a role that already says what the handler may do.
#
# **Consequence for Mission 6.2:** a Lambda function has exactly one execution
# role, so the two chunks roles mean the chunks domain deploys two functions.
# Volume 8, Chapter 8.4 §1 and docs/architecture/aws-sdk-integration.md both
# already describe chunk registration and chunk verification as separate
# functions, so this is the volumes' shape rather than a new one.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  # domain — the ADR-015 resource domain this role serves. Two roles may share one.
  # transactions — a role that only reads needs no transaction control.
  # s3_policy — key into var.chunk_s3_policy_documents, or null for no S3 access
  #   at all. Exactly one role holds each S3 policy; five roles hold none.
  roles = {
    "auth-verify"   = { domain = "auth-verify", transactions = false, s3_policy = null }
    "projects"      = { domain = "projects", transactions = true, s3_policy = null }
    "tasks"         = { domain = "tasks", transactions = true, s3_policy = null }
    "sessions"      = { domain = "sessions", transactions = true, s3_policy = null }
    "chunks-upload" = { domain = "chunks", transactions = true, s3_policy = "presign-upload" }
    "chunks-verify" = { domain = "chunks", transactions = true, s3_policy = "verify-object" }
    "metadata"      = { domain = "metadata", transactions = true, s3_policy = null }
  }

  # Roles that carry an S3 policy, keyed by role name. Built by filtering rather
  # than by a second hand-maintained list, so a role cannot be given an S3 policy
  # in one place and forgotten in the other.
  roles_with_s3 = {
    for name, cfg in local.roles : name => cfg.s3_policy if cfg.s3_policy != null
  }

  # There is deliberately no Firebase service-account secret grant here.
  #
  # Mission 6.1 gave auth-verify read access to `vump/{env}/firebase-service-account-*`
  # on the assumption that verifying a token needs a service-account key. It
  # does not — A-149 measured it and A-164 records that Volume 7 Chapter 7.7 §3
  # is wrong on this point. The Admin SDK validates against Google's public
  # certificates with no credential at all.
  #
  # The secret never existed, so the grant conferred nothing. It was removed in
  # Mission 6.5 because a permission that presupposes a key is a quiet vote for
  # the key half of the answer ADR-036 deferred, and that question is still
  # open. Whatever resolves it should add the grant it actually needs.

  log_group_arn_pattern = format(
    "arn:aws:logs:%s:%s:log-group:/aws/lambda/vump-%s-*",
    data.aws_region.current.region,
    data.aws_caller_identity.current.account_id,
    var.environment_slug,
  )
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  for_each = local.roles

  name        = "vump-${var.environment_slug}-${each.key}"
  description = "Lambda execution role in the ${each.value.domain} resource domain (ADR-015)."

  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name   = "vump-${var.environment_slug}-${each.key}"
    Domain = each.value.domain
  }
}

# CloudWatch Logs, scoped by log group rather than by the AWS-managed
# AWSLambdaBasicExecutionRole, which grants logs:CreateLogGroup on "*".
#
# The cost of the narrower grant is a coupling: these roles can only write logs
# for functions named vump-{env}-*. Mission 6.2 must name its functions to match,
# and a mismatch shows up as a function that runs and logs nothing.
#
# No AWSLambdaVPCAccessExecutionRole is attached anywhere in this module. Under
# the Data API no function joins the VPC, so nothing needs the ec2:*NetworkInterface
# permissions that policy grants on "*" — the one unavoidable wildcard of the
# VPC-attached design is simply absent from this one.
data "aws_iam_policy_document" "logs" {
  statement {
    sid    = "WriteOwnLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      local.log_group_arn_pattern,
      "${local.log_group_arn_pattern}:*",
    ]
  }
}

resource "aws_iam_role_policy" "logs" {
  for_each = local.roles

  name   = "logs"
  role   = aws_iam_role.lambda[each.key].id
  policy = data.aws_iam_policy_document.logs.json
}

# Data API access, scoped to this environment's cluster.
#
# IAM cannot express table-level permission here: rds-data actions are scoped to
# the cluster, so Volume 8, Chapter 8.4 §1's "on chunk_metadata only" is not
# enforceable at this layer. It is enforced by PostgreSQL GRANTs on a per-domain
# database user, which is Mission 6.3's schema work. Until then every role here
# is equally privileged inside the database, and that gap is real — including the
# two chunks roles, whose S3 separation says nothing about what either may do to
# a table.
data "aws_iam_policy_document" "data_api" {
  for_each = local.roles

  statement {
    sid    = "ExecuteStatements"
    effect = "Allow"

    actions = concat(
      [
        "rds-data:ExecuteStatement",
        "rds-data:BatchExecuteStatement",
      ],
      each.value.transactions ? [
        "rds-data:BeginTransaction",
        "rds-data:CommitTransaction",
        "rds-data:RollbackTransaction",
      ] : [],
    )

    resources = [var.cluster_arn]
  }

  # The function's OWN database credential, and only its own.
  #
  # Mission 6.3 replaced the shared master credential with one per function.
  # This is the statement that makes the PostgreSQL GRANTs real: the Data API
  # authenticates as whatever user the secret names, so a function that cannot
  # read another's credential cannot act as another's database role.
  #
  # Falls back to the master secret only while the per-function secrets do not
  # exist, so the module remains applyable in that order.
  statement {
    sid     = "ReadOwnDatabaseCredential"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      lookup(var.db_credential_secret_arns, each.key, var.master_user_secret_arn),
    ]
  }

}

resource "aws_iam_role_policy" "data_api" {
  for_each = local.roles

  name   = "data-api"
  role   = aws_iam_role.lambda[each.key].id
  policy = data.aws_iam_policy_document.data_api[each.key].json
}

# The chunks domain's S3 grants, rendered from infrastructure/aws/iam/*.json.tmpl.
#
# **One policy per role, never both on one.** vump-{env}-chunks-upload holds
# s3:PutObject and cannot read; vump-{env}-chunks-verify holds s3:GetObject and
# cannot write. Neither holds s3:DeleteObject — deletion of raw footage is
# lifecycle's job and ADR-013 gates it behind legal-hold enforcement.
#
# This is the separation Volume 4, Chapter 4.9 §2 requires, and it is enforced by
# the roles rather than by the handlers: a presigned URL carries the signer's
# permissions, so the upload role *cannot* produce a URL that reads footage,
# however the code that calls it is written. A-143.
resource "aws_iam_role_policy" "chunks_s3" {
  for_each = local.roles_with_s3

  name   = "s3"
  role   = aws_iam_role.lambda[each.key].id
  policy = var.chunk_s3_policy_documents[each.value]
}
