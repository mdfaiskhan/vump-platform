# GitHub Actions OIDC federation and the two CI roles (ADR-049, decision D-1).
#
# No static access key exists for CI anywhere in this repository or in GitHub.
# GitHub mints a signed JWT per job; AWS exchanges it for credentials that
# expire in an hour. There is nothing in a secret store to steal.
#
# **The trust conditions are the security boundary of this whole file.** A
# wildcard or a missing condition here does not fail loudly — it silently makes
# the role assumable by repositories that are not this one. The repository is
# PUBLIC, so "assumable by any repository" means by anybody. Review the four
# conditions on each role as the load-bearing part; the permission policies
# below them are the ordinary part.

locals {
  # Account-global. One provider serves every environment, so a second
  # environment root must set manage_account_identity = false rather than try to
  # create a duplicate — see variables.tf.
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  # The subject GitHub mints depends on the TRIGGER unless the job declares an
  # environment, in which case the environment form replaces every other:
  #
  #   push to develop        repo:OWNER/REPO:ref:refs/heads/develop
  #   push to release/1.2    repo:OWNER/REPO:ref:refs/heads/release/1.2
  #   pull_request           repo:OWNER/REPO:pull_request     <- a literal, not a ref
  #   workflow_dispatch      repo:OWNER/REPO:ref:refs/heads/<branch>
  #   any, with environment  repo:OWNER/REPO:environment:<name>
  #
  # Binding to environments collapses all five to one exact string per role, so
  # a StringEquals on a literal is sufficient and no wildcard appears anywhere.
  # A ref-based condition would need a StringLike for release/** and hotfix/**,
  # AND would silently fail to match pull_request — which is the trigger Gap 16's
  # plan-on-PRs actually runs under. ci.yml's Commit convention job already lives
  # on that trigger today.
  ci_plan_subject     = "repo:${var.github_repository}:environment:ci-plan"
  ci_db_proof_subject = "repo:${var.github_repository}:environment:ci-db-proof"

  # Pins the workflow FILE, and the ref namespace it may run from. On a public
  # repo this is what stops a workflow added on some other branch from assuming
  # the role even if it declares the right environment.
  #
  # TWO values, and the second one is not optional. A `pull_request` run does
  # not use the workflow file from the base branch — it uses the merge commit,
  # so its job_workflow_ref is `…/ci.yml@refs/pull/<n>/merge`. Pinning to
  # refs/heads/develop alone would therefore reject EVERY pull request, not
  # merely those that edit ci.yml — and plan-on-PRs is the entire point of
  # gap 16. This is corrected from Mission 7.1 Part 2a, which asserted the
  # narrower claim; A-173 records the correction.
  #
  # The wildcard spans the PR number and nothing else. Repository, workflow file
  # path and ref namespace all stay exact.
  #
  # The residual trade, stated because it is real: a pull request may edit
  # ci.yml AND assume these roles in the same run, so someone with write access
  # can exercise plan-reader from an unmerged branch. Pinning to develop alone
  # would close that and close gap 16 with it. plan-reader is read-only and
  # explicitly denied the evidentiary buckets, which is what makes the trade
  # acceptable here; it would not be for a role that could write.
  ci_workflow_refs = [
    "${var.github_repository}/.github/workflows/ci.yml@refs/heads/develop",
    "${var.github_repository}/.github/workflows/ci.yml@refs/pull/*/merge",
  ]
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.manage_account_identity ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  # The audience GitHub is asked for by aws-actions/configure-aws-credentials.
  # Its absence from a role's trust conditions would let a token minted for any
  # other audience be replayed here, so every role below asserts it too.
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "github-actions"
  }
}

# Common trust-condition shape for both CI roles. Only the subject differs.
data "aws_iam_policy_document" "ci_assume_role" {
  for_each = {
    "plan-reader" = local.ci_plan_subject
    "db-prover"   = local.ci_db_proof_subject
  }

  statement {
    sid     = "GitHubActionsWebIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value]
    }

    # Redundant against a well-formed subject, and kept as defence in depth: if
    # the subject string is ever edited wrongly, this still holds the line at
    # the repository boundary.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository"
      values   = [var.github_repository]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:job_workflow_ref"
      values   = local.ci_workflow_refs
    }
  }
}

# ---------------------------------------------------------------------------
# plan-reader — Gap 16. Runs terraform plan -lock=false and nothing else.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ci_plan_reader" {
  statement {
    sid       = "ReadState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/${var.environment_slug}/terraform.tfstate"]
  }

  # No PutObject and no DeleteObject. The job runs with -lock=false, so it never
  # acquires or releases a lock object, which is what makes "read-only" true
  # rather than nearly true. plan does not persist state to the backend.
  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.environment_slug}/*"]
    }
  }

  # "*" only where IAM offers nothing narrower — see boundary.tf.
  statement {
    sid    = "DescribeInfrastructure"
    effect = "Allow"

    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeTags",
      "ec2:DescribeAvailabilityZones",
      "rds:DescribeDBClusters",
      "rds:DescribeDBInstances",
      "rds:DescribeDBSubnetGroups",
      "rds:DescribeDBClusterParameterGroups",
      "rds:DescribeDBClusterParameters",
      "rds:ListTagsForResource",
    ]

    resources = ["*"]
  }

  # DescribeSecret, never GetSecretValue. plan reads a secret's metadata to
  # reconcile the container; it has no reason to read what is inside, and
  # ADR-016's tier rule says it may not.
  statement {
    sid    = "DescribeSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
    ]

    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:vump/${var.environment_slug}/*",
      var.master_user_secret_arn,
    ]
  }

  statement {
    sid    = "ReadIam"
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListRoleTags",
      "iam:GetUser",
      "iam:ListUserPolicies",
      "iam:ListAttachedUserPolicies",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetOpenIDConnectProvider",
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/vump-${var.environment_slug}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/vump-${var.environment_slug}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.human_user_name}",
      local.github_oidc_provider_arn,
    ]
  }

  statement {
    sid    = "ReadFunctions"
    effect = "Allow"

    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
    ]

    resources = [
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:vump-${var.environment_slug}-*",
    ]
  }

  statement {
    sid    = "ReadLogGroups"
    effect = "Allow"

    actions = [
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
    ]

    resources = [
      local.log_group_arn_pattern,
      "${local.log_group_arn_pattern}:*",
    ]
  }

  statement {
    sid       = "ReadApiGateway"
    effect    = "Allow"
    actions   = ["apigateway:GET"]
    resources = ["arn:aws:apigateway:${data.aws_region.current.region}::/restapis/*"]
  }

  # The evidentiary buckets, denied explicitly rather than merely not granted.
  #
  # This is why the AWS-managed ReadOnlyAccess policy is not used for this role:
  # it carries s3:GetObject on every bucket in the account, which reaches the
  # footage ADR-043 deliberately kept outside Terraform's blast radius. An
  # explicit Deny cannot be overridden by any later Allow, and unlike an absent
  # grant it is directly testable — which is how ADR-049's verification proves it.
  statement {
    sid     = "DenyEvidentiaryBuckets"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = concat(
      [for b in var.evidentiary_buckets : "arn:aws:s3:::${b}"],
      [for b in var.evidentiary_buckets : "arn:aws:s3:::${b}/*"],
    )
  }
}

resource "aws_iam_role" "ci_plan_reader" {
  name                 = "vump-${var.environment_slug}-ci-plan-reader"
  description          = "GitHub Actions: terraform plan -lock=false for ${var.environment_slug} (ADR-049, Gap 16). Read-only."
  assume_role_policy   = data.aws_iam_policy_document.ci_assume_role["plan-reader"].json
  permissions_boundary = aws_iam_policy.boundary.arn
  max_session_duration = 3600

  tags = {
    Name    = "vump-${var.environment_slug}-ci-plan-reader"
    Purpose = "ci"
  }
}

resource "aws_iam_role_policy" "ci_plan_reader" {
  name   = "plan"
  role   = aws_iam_role.ci_plan_reader.id
  policy = data.aws_iam_policy_document.ci_plan_reader.json
}

# ---------------------------------------------------------------------------
# db-prover — Gap 8. Runs the BR-08/11/21/22 behavioural proofs.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ci_db_prover" {
  statement {
    sid    = "ExecuteProofs"
    effect = "Allow"

    actions = [
      "rds-data:ExecuteStatement",
      "rds-data:BatchExecuteStatement",
      "rds-data:BeginTransaction",
      "rds-data:CommitTransaction",
      "rds-data:RollbackTransaction",
    ]

    resources = [var.cluster_arn]
  }

  # The seven per-function credentials, because the proofs' entire content is
  # "role X is refused operation Y". Each proof must authenticate AS the role
  # whose GRANT it is testing — the Data API authenticates as whichever user its
  # secret names (A-158).
  statement {
    sid       = "ReadFunctionCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = values(var.db_credential_secret_arns)
  }

  # The master credential, denied on CORRECTNESS grounds before blast-radius
  # grounds — and this is the more interesting of the two reasons.
  #
  # The master user bypasses every GRANT in migration 0007 and every trigger in
  # 0006. A behavioural proof run as master would PASS WHILE PROVING NOTHING.
  # Denying it is what keeps Gap 8's evidence real.
  #
  # It also keeps CI away from DDL, which is Gap 2's separate and undecided
  # question. ADR-049 decides the mechanism, not that.
  statement {
    sid       = "DenyMasterCredential"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.master_user_secret_arn]
  }
}

resource "aws_iam_role" "ci_db_prover" {
  name                 = "vump-${var.environment_slug}-ci-db-prover"
  description          = "GitHub Actions: BR-08/11/21/22 behavioural proofs against ${var.environment_slug} (ADR-049, Gap 8)."
  assume_role_policy   = data.aws_iam_policy_document.ci_assume_role["db-prover"].json
  permissions_boundary = aws_iam_policy.boundary.arn
  max_session_duration = 3600

  tags = {
    Name    = "vump-${var.environment_slug}-ci-db-prover"
    Purpose = "ci"
  }
}

resource "aws_iam_role_policy" "ci_db_prover" {
  name   = "proofs"
  role   = aws_iam_role.ci_db_prover.id
  policy = data.aws_iam_policy_document.ci_db_prover.json
}
