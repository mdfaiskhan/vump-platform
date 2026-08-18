# The human principal (ADR-049, decision D-2).
#
# Gap 1: every one of the 67 live resources, 9 migrations and 7 database
# credentials was created by faisal-admin, an unscoped administrator. This
# replaces it for day-to-day work. faisal-admin is retained as break-glass and
# is not deleted — Gap 1 closes to "faisal-admin is break-glass", never to
# "faisal-admin is gone".
#
# **The user holds no permission except sts:AssumeRole.** Its access key is
# generated out of band and never enters Terraform state (see below), and on its
# own it can read nothing, write nothing and describe nothing. Every working
# credential is a one-hour STS session obtained by assuming one of the two roles
# below, both of which require MFA. A disclosed key without the MFA device is
# inert.
#
# **There is deliberately no aws_iam_access_key resource in this file.** That
# resource stores the secret access key in plaintext in Terraform state, which
# is the class of problem ADR-043 avoided for Aurora via
# manage_master_user_password and A-158 avoided for the seven database
# credentials. ADR-016's tier rule places secrets in Secrets Manager only. The
# key is created once with:
#
#     aws iam create-access-key --user-name faisal-dev
#
# and pasted straight into the local credentials file. pgp_key would not rescue
# the resource: it leaves ciphertext in state and adds a PGP toolchain.
#
# The cost is honest and recorded in ADR-049: Terraform's drift detection stops
# at the user. A second key created by hand, or a key never rotated, is
# invisible to plan. infrastructure/terraform/README.md carries the
# list-access-keys check that covers it, the same pattern infrastructure/aws/
# already uses for the hand-applied buckets.

resource "aws_iam_user" "human" {
  count = var.manage_account_identity ? 1 : 0

  name = var.human_user_name
  path = "/"

  tags = {
    Name    = var.human_user_name
    Purpose = "human"
  }
}

locals {
  human_user_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.human_user_name}"

  human_role_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/vump-${var.environment_slug}-human-operator",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/vump-${var.environment_slug}-human-terraform-apply",
  ]

  # Identity-shaped IAM that terraform-apply may never touch. Letting it write
  # to any of these would restore the escalation the boundary exists to close:
  # rewriting its own policy, granting the user something beyond AssumeRole,
  # loosening the human roles' MFA condition, or editing the boundary itself.
  # These four stay with faisal-admin as a deliberate break-glass step.
  identity_arns = concat(
    local.human_role_arns,
    [
      local.human_user_arn,
      aws_iam_policy.boundary.arn,
    ],
  )
}

# The user's entire permission set: assume these two roles, nothing else.
data "aws_iam_policy_document" "human_assume_only" {
  statement {
    sid       = "AssumeScopedRoles"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = local.human_role_arns
  }
}

resource "aws_iam_user_policy" "human_assume_only" {
  count = var.manage_account_identity ? 1 : 0

  name   = "assume-scoped-roles"
  user   = aws_iam_user.human[0].name
  policy = data.aws_iam_policy_document.human_assume_only.json
}

# Trust shared by both human roles. MFA is the condition that makes the
# out-of-band key safe to hold: without the device, assuming either role fails,
# so the key grants nothing at all.
data "aws_iam_policy_document" "human_assume_role" {
  statement {
    sid     = "HumanWithMfa"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [local.human_user_arn]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

# ---------------------------------------------------------------------------
# operator — day-to-day read and operate. No infrastructure mutation.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "human_operator" {
  source_policy_documents = [data.aws_iam_policy_document.ci_plan_reader.json]

  # Everything plan-reader has, plus the operating verbs a person needs and a
  # plan job does not: run queries, read the credentials db:bootstrap sets, read
  # logs, invoke a function.
  statement {
    sid    = "OperateDatabase"
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

  statement {
    sid       = "ReadFunctionCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = values(var.db_credential_secret_arns)
  }

  statement {
    sid    = "ReadLogs"
    effect = "Allow"

    actions = [
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
    ]

    resources = [
      local.log_group_arn_pattern,
      "${local.log_group_arn_pattern}:*",
    ]
  }

  statement {
    sid       = "InvokeFunctions"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:vump-${var.environment_slug}-*"]
  }
}

resource "aws_iam_role" "human_operator" {
  name                 = "vump-${var.environment_slug}-human-operator"
  description          = "Human day-to-day operate role for ${var.environment_slug} (ADR-049). MFA required. No infrastructure mutation."
  assume_role_policy   = data.aws_iam_policy_document.human_assume_role.json
  permissions_boundary = aws_iam_policy.boundary.arn
  max_session_duration = 3600

  tags = {
    Name    = "vump-${var.environment_slug}-human-operator"
    Purpose = "human"
  }
}

resource "aws_iam_role_policy" "human_operator" {
  name   = "operate"
  role   = aws_iam_role.human_operator.id
  policy = data.aws_iam_policy_document.human_operator.json
}

# ---------------------------------------------------------------------------
# terraform-apply — provisions infrastructure. The escalation-sensitive one.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "human_terraform_apply" {
  # State, read AND write. Unlike plan-reader this one takes the lock, so it
  # needs PutObject and DeleteObject on the lock object (use_lockfile, ADR-043).
  statement {
    sid    = "WriteState"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.state_bucket}",
      "arn:aws:s3:::${var.state_bucket}/${var.environment_slug}/*",
    ]
  }

  # Network, database, functions and the API. Actions enumerated; resources are
  # "*" because a Create call names a resource that does not exist yet, so there
  # is nothing narrower to scope to.
  statement {
    sid    = "ProvisionNetworkAndDatabase"
    effect = "Allow"

    actions = [
      "ec2:Describe*",
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "rds:*",
      "apigateway:*",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ProvisionFunctionsAndLogs"
    effect = "Allow"

    actions = [
      "lambda:*",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:Describe*",
      "logs:ListTagsForResource",
    ]

    resources = [
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:vump-${var.environment_slug}-*",
      local.log_group_arn_pattern,
      "${local.log_group_arn_pattern}:*",
    ]
  }

  statement {
    sid    = "ProvisionSecretContainers"
    effect = "Allow"

    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
    ]

    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:vump/${var.environment_slug}/*",
    ]
  }

  # Workload IAM, scoped by name to this environment.
  statement {
    sid    = "ManageWorkloadIam"
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListRoleTags",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PassRole",
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/vump-${var.environment_slug}-*",
    ]
  }

  statement {
    sid    = "ReadIamAndProvider"
    effect = "Allow"

    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:GetUser",
      "iam:ListUserPolicies",
      "iam:ListAttachedUserPolicies",
      "iam:GetUserPolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
    ]

    resources = ["*"]
  }

  # ---- The three denies that close the escalation ----

  # 1. No role may be created, nor a policy attached to it, without this exact
  #    permissions boundary. A role created by terraform-apply is therefore
  #    capped by a document that grants no IAM write, so it cannot be used to
  #    climb any further. This is Fork A1 and the reason boundary.tf exists.
  statement {
    sid    = "DenyRoleWriteWithoutBoundary"
    effect = "Deny"

    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy",
    ]

    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.boundary.arn]
    }
  }

  # 2. The boundary may not be removed from a role once set, which would
  #    otherwise undo (1) in a second call.
  statement {
    sid       = "DenyBoundaryRemoval"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = ["*"]
  }

  # 3. Identity-shaped IAM is off limits entirely: terraform-apply's own role,
  #    the human operator role, the faisal-dev user and the boundary policy.
  #    Without this, terraform-apply could rewrite its own policy, or grant the
  #    user something beyond sts:AssumeRole, and the design would unwind.
  #    These stay with faisal-admin as a deliberate break-glass step, and
  #    ADR-049 records that as a cost rather than hiding it.
  statement {
    sid       = "DenyIdentityMutation"
    effect    = "Deny"
    resources = local.identity_arns

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:DeleteRolePermissionsBoundary",
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:PutUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:UpdateAccessKey",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:DeletePolicy",
    ]
  }

  # The evidentiary buckets, denied for the same reason as on plan-reader.
  # ADR-043 keeps them outside Terraform's blast radius; this makes that
  # structural for the principal that runs Terraform.
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

# NOTE: no permissions_boundary on this role, and it is not an oversight.
# The boundary grants no iam:CreateRole, so a terraform-apply capped by it could
# not create the seven Lambda roles. Its containment comes from the three Deny
# statements above instead.
resource "aws_iam_role" "human_terraform_apply" {
  name                 = "vump-${var.environment_slug}-human-terraform-apply"
  description          = "Human Terraform apply role for ${var.environment_slug} (ADR-049). MFA required. Cannot escalate: see the three Deny statements."
  assume_role_policy   = data.aws_iam_policy_document.human_assume_role.json
  max_session_duration = 3600

  tags = {
    Name    = "vump-${var.environment_slug}-human-terraform-apply"
    Purpose = "human"
  }
}

resource "aws_iam_role_policy" "human_terraform_apply" {
  name   = "terraform"
  role   = aws_iam_role.human_terraform_apply.id
  policy = data.aws_iam_policy_document.human_terraform_apply.json
}
