# One Lambda execution role per resource domain, per ADR-015.
#
# ADR-015 fixes six domains: auth-verify, projects, tasks, sessions, chunks,
# metadata. Volume 4, Chapter 4.9 §2 requires the roles to be least-privilege and
# per-function, "e.g. the chunk-registration Lambda can generate presigned S3 URLs
# but cannot itself read arbitrary S3 objects; the metadata Lambda can write to
# chunk_metadata but has no S3 permissions at all."
#
# The roles exist before the functions do. That order is deliberate: Mission 6.2
# writes handlers against a role that already says what the handler may do.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  # transactions — a domain that only reads needs no transaction control.
  # firebase_secret — only the token-verification path reads the Firebase key.
  # chunk_s3 — only the chunks domain touches S3 at all.
  domains = {
    "auth-verify" = { transactions = false, firebase_secret = true, chunk_s3 = false }
    "projects"    = { transactions = true, firebase_secret = false, chunk_s3 = false }
    "tasks"       = { transactions = true, firebase_secret = false, chunk_s3 = false }
    "sessions"    = { transactions = true, firebase_secret = false, chunk_s3 = false }
    "chunks"      = { transactions = true, firebase_secret = false, chunk_s3 = true }
    "metadata"    = { transactions = true, firebase_secret = false, chunk_s3 = false }
  }

  # Secrets Manager appends a six-character suffix to every secret ARN, so a
  # secret that does not exist yet can only be named by prefix. The wildcard
  # covers that suffix and nothing else — not the path, not the environment.
  firebase_secret_arn_pattern = format(
    "arn:aws:secretsmanager:%s:%s:secret:vump/%s/firebase-service-account-*",
    data.aws_region.current.region,
    data.aws_caller_identity.current.account_id,
    var.environment_slug,
  )

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

resource "aws_iam_role" "domain" {
  for_each = local.domains

  name        = "vump-${var.environment_slug}-${each.key}"
  description = "Lambda execution role for the ${each.key} resource domain (ADR-015)."

  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name   = "vump-${var.environment_slug}-${each.key}"
    Domain = each.key
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
  for_each = local.domains

  name   = "logs"
  role   = aws_iam_role.domain[each.key].id
  policy = data.aws_iam_policy_document.logs.json
}

# Data API access, scoped to this environment's cluster.
#
# IAM cannot express table-level permission here: rds-data actions are scoped to
# the cluster, so Volume 8, Chapter 8.4 §1's "on chunk_metadata only" is not
# enforceable at this layer. It is enforced by PostgreSQL GRANTs on a per-domain
# database user, which is Mission 6.3's schema work. Until then these six roles
# are equally privileged inside the database, and that gap is real.
data "aws_iam_policy_document" "data_api" {
  for_each = local.domains

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

  statement {
    sid       = "ReadDatabaseCredential"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.master_user_secret_arn]
  }

  dynamic "statement" {
    for_each = each.value.firebase_secret ? [1] : []

    content {
      sid       = "ReadFirebaseServiceAccount"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [local.firebase_secret_arn_pattern]
    }
  }
}

resource "aws_iam_role_policy" "data_api" {
  for_each = local.domains

  name   = "data-api"
  role   = aws_iam_role.domain[each.key].id
  policy = data.aws_iam_policy_document.data_api[each.key].json
}

# The chunks domain's S3 grants, rendered from infrastructure/aws/iam/*.json.tmpl.
#
# Both templates attach to the single chunks role, because ADR-015 fixes six
# domains and both grants belong to chunks. That merges two previously separate
# permission sets onto one principal: the role that presigns uploads now also
# holds s3:GetObject. See docs/architecture/volume-amendments.md A-143 — a
# presigned URL carries the signer's permissions, so this widens what a presigned
# URL from this role can be crafted to do. Recorded, not silently accepted.
resource "aws_iam_role_policy" "chunks_s3" {
  for_each = var.chunk_s3_policy_documents

  name   = "s3-${each.key}"
  role   = aws_iam_role.domain["chunks"].id
  policy = each.value
}
