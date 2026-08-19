# chunk-hash-probe — throwaway, measurement only. DELETE AFTER F4 IS DECIDED.
#
# ## What it is for
#
# Mission 7.3's F4 asks whether `chunks-verify` can satisfy Volume 4 Chapter
# 4.5 §3 — verify `checksum_sha256` "against the actual uploaded S3 object" —
# by streaming a SHA-256 over `GetObject`, inside API Gateway's 29-second REST
# integration ceiling, for a chunk Mission 3.8.1 measured at 633,232,477 bytes.
#
# That reduces to one number nothing in this repository knows: Lambda→S3
# in-region throughput, and how much of it memory buys. `probe/index.mjs`
# explains why it cannot be measured anywhere cheaper.
#
# ## Why it is here and not in the api-gateway module
#
# It is not an ADR-015 resource domain. Putting it in `local.lambda_functions`
# would give it an API Gateway route, an execution role from the IAM module, a
# database credential secret and a place in the route-inventory test — four
# kinds of blast radius for a function that exists to print one number.
#
# It gets its own role, its own S3 prefix, and no route at all. Invoked with
# `aws lambda invoke`, never over HTTP.
#
# ## Why two functions rather than one resized between runs
#
# 512 MB is what all seven functions run at today. 1769 MB is the allocation at
# which Lambda gives a function one full vCPU, and network scales with memory
# on the same curve — so the pair brackets the decision rather than sampling a
# point on it. Two functions also means one apply and two invokes, instead of
# an apply between measurements that would put a cold start in the middle of
# the comparison.

locals {
  # Deliberately not derived from anything. This function is temporary and a
  # shared local would outlive it.
  probe_memory_tiers = {
    "512"  = 512
    "1769" = 1769
  }
}

data "archive_file" "probe" {
  type        = "zip"
  source_dir  = "${path.module}/probe"
  output_path = "${path.module}/probe.zip"
}

# The probe's own role, carrying the boundary.
#
# The boundary is not optional and not decoration: ADR-049 D-3 denies
# `terraform-apply` `iam:CreateRole` unless the request carries
# `iam:PermissionsBoundary` equal to this policy. A role declared without it
# here does not produce a weaker role — the apply is refused.
resource "aws_iam_role" "probe" {
  name                 = "vump-${var.environment_slug}-chunk-hash-probe"
  permissions_boundary = module.iam.permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name      = "vump-${var.environment_slug}-chunk-hash-probe"
    Temporary = "Mission 7.3 F4 measurement. Delete once the number is recorded."
  }
}

data "aws_iam_policy_document" "probe" {
  # Scoped to one prefix, not the bucket.
  #
  # ADR-011 puts evidentiary footage in this bucket and ADR-049 kept
  # `plan-reader` away from it for that reason. A measurement function is not a
  # reason to widen that: `_probe/*` cannot collide with Chapter 5.14 §1's key
  # pattern, which always begins with an org uuid.
  statement {
    sid    = "ProbeFixtureObject"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["arn:aws:s3:::${var.chunk_bucket}/_probe/*"]
  }

  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.region}:*:log-group:/aws/lambda/vump-${var.environment_slug}-chunk-hash-probe-*:*"]
  }
}

resource "aws_iam_role_policy" "probe" {
  name   = "probe"
  role   = aws_iam_role.probe.id
  policy = data.aws_iam_policy_document.probe.json
}

resource "aws_cloudwatch_log_group" "probe" {
  for_each = local.probe_memory_tiers

  name = "/aws/lambda/vump-${var.environment_slug}-chunk-hash-probe-${each.key}"
  # One day. This is a throwaway and its logs should not outlive the decision.
  retention_in_days = 1

  tags = {
    Name      = "vump-${var.environment_slug}-chunk-hash-probe-${each.key}-logs"
    Temporary = "Mission 7.3 F4 measurement."
  }
}

resource "aws_lambda_function" "probe" {
  for_each = local.probe_memory_tiers

  function_name = "vump-${var.environment_slug}-chunk-hash-probe-${each.key}"
  description   = "TEMPORARY. Mission 7.3 F4: measures GetObject→SHA-256 throughput at ${each.value}MB. No API route. Delete after the number is recorded."

  role    = aws_iam_role.probe.arn
  runtime = "nodejs24.x"
  handler = "index.handler"

  filename         = data.archive_file.probe.output_path
  source_code_hash = data.archive_file.probe.output_base64sha256

  # 900 is Lambda's maximum and it is correct *here* precisely because this
  # function is not behind API Gateway. The whole point is to find out how long
  # the hash takes; a timeout tuned to the answer would truncate it. Seeding a
  # 633 MB fixture in 16 MiB parts also takes longer than any API-facing budget.
  timeout     = 900
  memory_size = each.value

  environment {
    variables = {
      CHUNK_BUCKET = var.chunk_bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.probe]

  tags = {
    Name      = "vump-${var.environment_slug}-chunk-hash-probe-${each.key}"
    Temporary = "Mission 7.3 F4 measurement. Delete once the number is recorded."
  }
}

output "probe_invoke_commands" {
  description = "How to run the F4 measurement once this is applied. Seed once, then measure at each tier."
  value = join("\n", concat(
    ["aws lambda invoke --profile vump-dev-operator --region ${var.region} --function-name ${aws_lambda_function.probe["512"].function_name} --payload '{\"mode\":\"seed\"}' --cli-binary-format raw-in-base64-out seed.json && cat seed.json"],
    [for k, fn in aws_lambda_function.probe :
      "aws lambda invoke --profile vump-dev-operator --region ${var.region} --function-name ${fn.function_name} --payload '{\"mode\":\"measure\"}' --cli-binary-format raw-in-base64-out measure-${k}.json && cat measure-${k}.json"
    ],
  ))
}
