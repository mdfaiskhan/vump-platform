# The permissions boundary every Terraform-created role must carry (ADR-049).
#
# **A boundary is a cap, not a grant.** It grants nothing on its own. A role's
# effective permission is the intersection of its identity policy and this
# document, so a role can only ever do what BOTH allow.
#
# Why it exists, stated precisely, because "defence in depth" is not the reason:
# vump-{env}-human-terraform-apply must create IAM roles and attach policies to
# them — 23 of the 67 managed resources are IAM. A principal that can create a
# role and put a policy on it can create a role with Administrator and assume
# it. Without this document, ADR-049's scoped human principal would be an
# administrator by a two-step path, and the decision would be cosmetic.
#
# terraform-apply is therefore denied iam:CreateRole, iam:PutRolePolicy and
# iam:AttachRolePolicy unless the request carries iam:PermissionsBoundary equal
# to this policy's ARN. See human.tf. Escalation is then impossible rather than
# merely unattractive: the role it creates is capped by this document, and this
# document grants no IAM write of any kind.
#
# **The cap is the union of what every Terraform-created role legitimately
# does** — the seven Lambda execution roles, the two CI roles and the human
# operator role. It is deliberately wider than any single one of them.
# Narrowness lives in each role's own identity policy; this is the ceiling none
# of them may exceed.
#
# terraform-apply itself does NOT carry this boundary — it could not create
# roles if it did, since the document grants no iam:CreateRole. That is why
# identity-shaped IAM (this policy, the faisal-dev user, the two human roles) is
# denied to terraform-apply and stays break-glass. See human.tf.
data "aws_iam_policy_document" "boundary" {
  # CloudWatch Logs. Write for the Lambda roles, read for the operator and the
  # CI roles, both scoped to this environment's log groups.
  statement {
    sid    = "LogsWithinEnvironment"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
      "logs:ListTagsForResource",
    ]

    resources = [
      local.log_group_arn_pattern,
      "${local.log_group_arn_pattern}:*",
    ]
  }

  # The Data API, scoped to this environment's cluster. Every caller that
  # reaches the database — seven Lambdas, the db-prover, the human operator —
  # does so through these five actions and no other.
  statement {
    sid    = "DataApiOnThisCluster"
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

  # Secrets in this environment's namespace, plus the RDS-managed master
  # container. Reading a value is capped here; WHICH value each role may read is
  # its own policy's business (A-160), and this document does not relax that.
  statement {
    sid    = "ReadEnvironmentSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
    ]

    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:vump/${var.environment_slug}/*",
      var.master_user_secret_arn,
    ]
  }

  # Chunk storage. The upload/verify split (A-143) is enforced by the two role
  # policies, not here — this only caps the blast radius to the one bucket.
  #
  # s3:DeleteObject is absent from the cap entirely. ADR-013 gates deletion of
  # raw footage behind legal-hold enforcement and ADR-012 gives it to lifecycle.
  # No Terraform-created role may delete an object, whatever its own policy says.
  statement {
    sid    = "ChunkBucketObjects"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]

    resources = [
      "arn:aws:s3:::${var.chunk_bucket}",
      "arn:aws:s3:::${var.chunk_bucket}/*",
    ]
  }

  # Terraform state, read-only. plan -lock=false needs GetObject and nothing
  # else; no PutObject or DeleteObject appears here, so no capped role can write
  # state or acquire a lock however its own policy is written.
  statement {
    sid    = "ReadTerraformState"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.state_bucket}",
      "arn:aws:s3:::${var.state_bucket}/${var.environment_slug}/*",
    ]
  }

  # Describe-only reads for terraform plan.
  #
  # These are "*" because IAM does not support resource-level permissions for
  # EC2 and RDS Describe actions. That is a limit of the service, not a shortcut
  # taken here, and it is why the action list is enumerated rather than written
  # as ec2:Describe*.
  statement {
    sid    = "DescribeForPlan"
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
      "sts:GetCallerIdentity",
    ]

    resources = ["*"]
  }

  # IAM, READ ONLY, and this is the statement that makes the boundary work.
  #
  # There is deliberately no iam:CreateRole, PutRolePolicy, AttachRolePolicy,
  # CreateUser, CreateAccessKey, PutRolePermissionsBoundary or
  # DeleteRolePermissionsBoundary anywhere in this document. A role capped by it
  # cannot grant privilege to itself or to anything else, which is the property
  # the whole design rests on.
  statement {
    sid    = "ReadIamForPlan"
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

    resources = ["*"]
  }

  # Lambda and API Gateway reads, plus invoke for the human operator.
  statement {
    sid    = "ReadAndInvokeFunctions"
    effect = "Allow"

    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
      "lambda:InvokeFunction",
    ]

    resources = [
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:vump-${var.environment_slug}-*",
    ]
  }

  statement {
    sid       = "ReadApiGateway"
    effect    = "Allow"
    actions   = ["apigateway:GET"]
    resources = ["arn:aws:apigateway:${data.aws_region.current.region}::/restapis/*"]
  }
}

resource "aws_iam_policy" "boundary" {
  name        = "vump-${var.environment_slug}-boundary"
  description = "Permissions boundary for every Terraform-created role in ${var.environment_slug} (ADR-049). Grants nothing; caps everything."
  policy      = data.aws_iam_policy_document.boundary.json

  tags = {
    Name = "vump-${var.environment_slug}-boundary"
  }
}
