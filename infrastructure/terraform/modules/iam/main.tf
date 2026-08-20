# Lambda execution roles for ADR-015's six resource domains.
#
# Eight roles, six domains. See `chunks-*` and `redeem` in `local.roles`.
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

    # Mission 7.6. The auth-verify DOMAIN gains a second role, and no seventh
    # domain is created — ADR-015's six stand.
    #
    # **The reason is A-143's, applied to a different pair of privileges.** The
    # chunks domain has two roles because one must write and not read while the
    # other must read and not write. Here: `auth-verify` holds SELECT on
    # `users` and must NOT be able to create Firebase accounts; `redeem`
    # creates Firebase accounts and must NOT be able to read `users`. A single
    # role would hold both, and the separation would be conventional rather
    # than real.
    #
    # `transactions` because spending an invite-code use must be atomic against
    # a concurrent redemption of the last remaining use.
    #
    # No S3 policy, and no AWS permission for the GCP federation either: the
    # function SigV4-signs a GetCallerIdentity request locally and hands the
    # signed headers to Google, which makes the call. It never calls STS
    # itself, so there is nothing to authorise.
    "redeem" = { domain = "auth-verify", transactions = true, s3_policy = null }
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

  # `logs:DescribeLogGroups` cannot be scoped to a log group, and the pattern
  # above therefore never authorises it.
  #
  # It is a **list** call. IAM evaluates it against an ARN with an empty log
  # group name, which the denial Mission 7.3 hit states verbatim:
  #
  #   arn:aws:logs:ap-south-1:929570731524:log-group::log-stream
  #
  # Nothing ending in `/aws/lambda/vump-dev-*` can match that, so every
  # principal that was given `DescribeLogGroups` against
  # `log_group_arn_pattern` was given an action it could never actually use.
  #
  # This pattern is the narrowest form that does match. It keeps the region and
  # the account — both present in the denial above, which is what proves they
  # are part of the evaluated ARN — and wildcards only the portion IAM leaves
  # empty. `*` on its own would work and would also permit listing log groups
  # in any region of any account, which is a real widening and an unnecessary
  # one.
  log_group_list_arn_pattern = format(
    "arn:aws:logs:%s:%s:log-group:*",
    data.aws_region.current.region,
    data.aws_caller_identity.current.account_id,
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

  # DRIFT WARNING — this name is depended on from GCP, by value not reference.
  #
  # `modules/gcp-federation` trusts exactly one of these roles by ARN, in a
  # Workload Identity Federation attribute condition, so that only the redeem
  # Lambda may impersonate the Firebase service account. It computes that ARN
  # from the same two inputs this line uses rather than referencing this
  # resource, because a GCP module taking a dependency on an AWS one would
  # couple two providers for a string both can build.
  #
  # **Changing this format silently breaks that condition.** Nothing fails at
  # plan time; redemption fails at runtime with an authentication error that
  # names neither side. If this line changes, change
  # `modules/gcp-federation/variables.tf`'s `redeem_role_name` with it — its
  # `redeem_role_arn_trusted` output exists so the mismatch shows up as a plan
  # diff rather than as a production incident. Mission 7.6, Phase 2.
  name        = "vump-${var.environment_slug}-${each.key}"
  description = "Lambda execution role in the ${each.value.domain} resource domain (ADR-015)."

  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  # ADR-049, Fork A1. Every Terraform-created role carries the boundary, and
  # these eight are no exception — terraform-apply is denied iam:CreateRole
  # without it, so a role added later cannot quietly skip the cap.
  #
  # The cap does not narrow what these roles do today: boundary.tf allows the
  # logs, rds-data, Secrets Manager and chunk-bucket actions each of them
  # already holds. It removes reach they never had.
  permissions_boundary = aws_iam_policy.boundary.arn

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
# The Fork 1 seam — Mission 7.3 Batch 2b.
#
# `CompleteMultipartUpload` requires `s3:PutObject`, and A-143 makes the
# separation structural rather than conventional: the role that downloads
# evidentiary footage to hash it must not be able to overwrite it. So
# `chunks-verify` does not gain PutObject — it gains the ability to ask
# `chunks-upload`, which already holds it, to finalise one specific upload.
#
# **This is materially narrower than PutObject**, but the reason is the invoked
# function's validation and not the IAM boundary alone — and that validation was
# missing when this comment was first written. A-195 records it: `finalizeUpload`
# now reads the chunk row and refuses unless the supplied key AND upload id are
# the ones that chunk owns, so the capability is "finalise this specific
# registered upload" rather than "finalise anything in the bucket".
#
# With that check in place: this cannot create an object at an arbitrary key,
# cannot overwrite completed footage, and cannot presign anything. A-143's stated
# property — "chunks-verify holds s3:GetObject and cannot write" — remains
# literally true, and is now true for the reason this comment gives.
#
# Chapter 4.10 §2 step 3 anticipated the two-function shape in its own wording:
# "a Lambda (triggered either by that call or an S3 event notification)".
resource "aws_iam_role_policy" "chunks_verify_invoke_upload" {
  name = "invoke-chunks-upload"
  role = aws_iam_role.lambda["chunks-verify"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "FinalizeMultipartUploadViaChunksUpload"
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:vump-${var.environment_slug}-chunks-upload"
    }]
  })
}

resource "aws_iam_role_policy" "chunks_s3" {
  for_each = local.roles_with_s3

  name   = "s3"
  role   = aws_iam_role.lambda[each.key].id
  policy = var.chunk_s3_policy_documents[each.value]
}
