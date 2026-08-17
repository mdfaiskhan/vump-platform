variable "environment_slug" {
  description = "AWS environment slug: dev, staging or prod (naming-conventions.md §7.1)."
  type        = string
}

variable "region" {
  description = "AWS region. Used to build the integration URI."
  type        = string
}

variable "artifacts_dir" {
  description = <<-EOT
    Directory holding one esbuild bundle per function, as
    <artifacts_dir>/<function>/index.mjs. Produced by `npm run build` in
    backend/. Terraform zips it; it does not build it.
  EOT
  type        = string
}

variable "lambda_role_arns" {
  description = <<-EOT
    Execution role ARNs by function name, from the iam module. Seven roles
    across ADR-015's six domains — the chunks domain carries two, because a
    Lambda has exactly one execution role and A-143 split the privilege.
  EOT
  type        = map(string)
}

variable "db_credential_secret_arns" {
  description = "Per-function database credential secret ARNs, keyed by function name (Mission 6.3). Each function is given only its own."
  type        = map(string)
}

variable "lambda_environment" {
  description = "Non-secret environment variables common to every function. Secret VALUES are forbidden here (Volume 8 Ch. 8.4 §2)."
  type        = map(string)
}

variable "runtime" {
  description = <<-EOT
    Lambda runtime identifier.

    nodejs24.x, chosen in Mission 6.2.1 against what Lambda actually supports:
    nodejs20.x is already deprecated, nodejs22.x deprecates 2027-04-30, and
    nodejs26.x is public preview and documented as not for production. Keep in
    step with backend/package.json's `engines` and scripts/build.mjs's target.
  EOT
  type        = string
  default     = "nodejs24.x"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention. Explicit, because the default is never expire."
  type        = number
  default     = 30
}
