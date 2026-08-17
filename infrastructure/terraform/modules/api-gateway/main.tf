# API Gateway and the seven Lambda functions behind it.
#
# Volume 4, Chapter 4.9 §1 puts API Gateway in front of "one function per
# resource domain", and §2 makes it "the only public entry point; every Lambda
# function behind it is otherwise unreachable from outside AWS".
#
# ## REST API, not HTTP API
#
# The volumes never name the product tier — Chapter 4.6's "REST" is the
# architectural style (ADR-009). Two later requirements decide it, and both are
# REST-API-only features:
#
#   - Volume 8, Chapter 8.3 §1: rate limiting "enforced at API Gateway … via
#     **usage plans** per authenticated user". HTTP API has throttling but no
#     usage plans.
#   - Volume 8, Chapter 8.4 §3: "AWS WAF attached to API Gateway". WAF does not
#     attach to an HTTP API.
#
# Neither is built here. Choosing HTTP API now would be cheaper and would have
# to be undone to satisfy either, and the migration is not a configuration flag.
#
# ## The API is declared as OpenAPI rather than as a resource tree
#
# Fifteen routes over a nested path tree would be roughly twenty
# `aws_api_gateway_resource` blocks whose parents reference each other.
# Terraform forbids a resource referencing itself under `for_each`, so that
# shape cannot be generated from a list — it has to be hand-nested and
# hand-maintained. The OpenAPI body keeps the whole contract in one readable
# place, and the path templates in it are the same strings the handlers route
# on (`backend/packages/shared/src/router.ts`), so a mismatch is greppable.

locals {
  # The Chapter 4.6 catalogue: fifteen endpoints, mapped to functions by
  # RESOURCE TYPE rather than by URL nesting (the Mission 6.2.1 decision).
  # `/v1/projects/{projectId}/tasks` is nested under projects and served by
  # tasks, because the thing being listed is a task.
  routes = [
    { method = "POST", path = "/v1/auth/verify", function = "auth-verify" },
    { method = "GET", path = "/v1/users/me", function = "auth-verify" },

    { method = "GET", path = "/v1/projects", function = "projects" },
    { method = "POST", path = "/v1/projects", function = "projects" },

    { method = "GET", path = "/v1/projects/{projectId}/tasks", function = "tasks" },
    { method = "POST", path = "/v1/projects/{projectId}/tasks", function = "tasks" },
    { method = "PATCH", path = "/v1/tasks/{taskId}", function = "tasks" },
    { method = "POST", path = "/v1/tasks/{taskId}/assignments", function = "tasks" },
    { method = "DELETE", path = "/v1/tasks/{taskId}/assignments/{userId}", function = "tasks" },

    { method = "POST", path = "/v1/tasks/{taskId}/sessions", function = "sessions" },
    { method = "GET", path = "/v1/tasks/{taskId}/sessions", function = "sessions" },

    { method = "POST", path = "/v1/sessions/{sessionId}/chunks", function = "chunks-upload" },

    { method = "PATCH", path = "/v1/chunks/{chunkId}/status", function = "chunks-verify" },

    { method = "POST", path = "/v1/chunks/{chunkId}/metadata", function = "metadata" },
    { method = "GET", path = "/v1/chunks/{chunkId}/metadata", function = "metadata" },
  ]

  function_names = sort(distinct([for r in local.routes : r.function]))

  # OpenAPI paths, grouped by path with one operation per method.
  openapi_paths = {
    for path in distinct([for r in local.routes : r.path]) :
    path => {
      for r in local.routes : lower(r.method) => {
        operationId = "${r.function}-${lower(r.method)}"
        responses   = { "200" = { description = "See the Chapter 4.6 §1 envelope." } }
        # AWS_PROXY: the whole request is handed to the function and the
        # function owns the response, which is what lets one Lambda serve
        # several routes through its own router.
        "x-amazon-apigateway-integration" = {
          type                 = "aws_proxy"
          httpMethod           = "POST" # always POST for a Lambda proxy integration
          payloadFormatVersion = "1.0"
          uri                  = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.this[r.function].arn}/invocations"
        }
      } if r.path == path
    }
  }
}

# --- Lambda ------------------------------------------------------------------

# One zip per function, from the esbuild bundle. Terraform packages; it does
# not compile — `npm run build` in backend/ must have run first.
data "archive_file" "bundle" {
  for_each = toset(local.function_names)

  type        = "zip"
  source_dir  = "${var.artifacts_dir}/${each.key}"
  output_path = "${var.artifacts_dir}/${each.key}.zip"
}

# Created explicitly rather than left to Lambda's implicit creation.
#
# Two reasons. Retention: an implicitly created group never expires. And the
# execution roles from Mission 6.1 grant logs only on
# `/aws/lambda/vump-{env}-*`, so the name is load-bearing — a function named
# anything else runs and writes nothing.
resource "aws_cloudwatch_log_group" "lambda" {
  for_each = toset(local.function_names)

  name              = "/aws/lambda/vump-${var.environment_slug}-${each.key}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "vump-${var.environment_slug}-${each.key}-logs"
  }
}

resource "aws_lambda_function" "this" {
  for_each = toset(local.function_names)

  function_name = "vump-${var.environment_slug}-${each.key}"
  description   = "ADR-015 resource domain handler. Routes served are declared in this module's `routes` local."

  role    = var.lambda_role_arns[each.key]
  runtime = var.runtime
  handler = "index.handler"

  filename         = data.archive_file.bundle[each.key].output_path
  source_code_hash = data.archive_file.bundle[each.key].output_base64sha256

  # Generous on time, modest on memory: every request makes an outbound HTTPS
  # call to fetch Google's signing certificates on a cold start (see
  # backend/packages/shared/src/auth.ts), and Chapter 4.6's endpoints are all
  # small reads and writes.
  timeout     = 15
  memory_size = 512

  environment {
    variables = merge(var.lambda_environment, {
      APP_ENV = local.app_env
    })
  }

  # No vpc_config, deliberately. ADR-044 puts the database behind the Data API,
  # so no function joins a VPC — which is also what lets the certificate fetch
  # above work without a NAT gateway.

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = {
    Name   = "vump-${var.environment_slug}-${each.key}"
    Domain = each.key
  }
}

locals {
  # The APP_ENV key, not the AWS slug. naming-conventions.md §7.1 names using
  # one where the other belongs as the common mistake, so the mapping is
  # explicit rather than derived by string surgery.
  app_env = {
    dev     = "development"
    staging = "staging"
    prod    = "production"
  }[var.environment_slug]
}

resource "aws_lambda_permission" "api_gateway" {
  for_each = toset(local.function_names)

  statement_id  = "AllowInvokeFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[each.key].function_name
  principal     = "apigateway.amazonaws.com"

  # Scoped to this API. Without the source_arn any API Gateway in any account
  # could invoke these functions.
  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# --- API Gateway -------------------------------------------------------------

resource "aws_api_gateway_rest_api" "this" {
  name        = "vump-${var.environment_slug}-api"
  description = "Vump Technologies API. Volume 4, Chapter 4.6."

  # Regional rather than edge-optimised: every Collector is in one region and
  # the payloads are small JSON. An edge distribution would add a CloudFront
  # hop that buys nothing for a single-region audience.
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "Vump Technologies API"
      version = "1.0"
    }
    paths = local.openapi_paths
  })

  tags = {
    Name = "vump-${var.environment_slug}-api"
  }
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Redeploy when the API definition changes. Without this the routes change in
  # Terraform's state and the deployed stage keeps serving the old ones.
  triggers = {
    redeployment = sha1(aws_api_gateway_rest_api.this.body)
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id

  # The stage is the environment slug, not "v1". Versioning is in the path
  # (Chapter 4.6 §1: "Base path: /v1/…"), so putting it in the stage too would
  # give every URL two version segments.
  stage_name = var.environment_slug

  tags = {
    Name = "vump-${var.environment_slug}-stage"
  }
}
