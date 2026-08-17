# One Secrets Manager secret per Lambda function, holding that function's
# database credential.
#
# ## Why per-function secrets rather than SET ROLE
#
# ADR-044 records that `rds-data` actions scope to the *cluster*, so Volume 8
# Chapter 8.4 §1's table-level restrictions cannot be expressed in IAM. Mission
# 6.3 makes them PostgreSQL GRANTs — but the Data API authenticates as whatever
# user the secret names, and with one shared secret every function would
# authenticate as the master user and every GRANT would be decoration.
#
# The alternative measured in Mission 6.3 was `SET ROLE` inside a transaction.
# It works — session state persists across Data API calls within an explicit
# transaction, verified — but the restriction would then be a handler
# convention: a function that forgets to `SET ROLE` runs as `rds_superuser`,
# and nothing stops it. That is precisely the "conventional rather than real"
# property A-143 was raised to eliminate.
#
# With a secret per function, the function's IAM permits reading exactly one
# secret. It cannot authenticate as another function's role because it cannot
# read the credential. **Enforced by IAM, not by review.**
#
# ## What Terraform does and does not hold
#
# It creates the secret *containers* and nothing else. **No password is
# generated here and no version is written**, because a `random_password` would
# put every database credential into Terraform state — the exact property
# ADR-043 preserves by using `manage_master_user_password` for the master.
#
# `npm run db:bootstrap` generates each password, sets it on the role through
# the Data API, and writes the value. The password exists in the bootstrap
# process, the database and Secrets Manager, and nowhere else.

variable "environment_slug" {
  description = "AWS environment slug: dev, staging or prod."
  type        = string
}

variable "function_names" {
  description = "Lambda function names. One credential secret is created per function."
  type        = set(string)
}

resource "aws_secretsmanager_secret" "function" {
  for_each = var.function_names

  # ADR-016's convention: vump/{environment}/{secret-name}. The environment
  # here is the APP_ENV key rather than the AWS slug, matching the two secrets
  # ADR-016 already names.
  name        = "vump/${local.app_env}/db-${each.key}"
  description = "Aurora credential for the ${each.key} Lambda. Role vump_${replace(each.key, "-", "_")}."

  # Dev is disposable (ADR-014). A seven-day window on every mistaken destroy
  # would block re-creating the secret under the same name for a week, which is
  # the wrong trade for an environment whose data is synthetic.
  recovery_window_in_days = var.environment_slug == "prod" ? 30 : 0

  tags = {
    Name     = "vump-${var.environment_slug}-db-${each.key}"
    Function = each.key
  }
}

locals {
  app_env = {
    dev     = "dev"
    staging = "staging"
    prod    = "prod"
  }[var.environment_slug]
}

output "secret_arns" {
  description = "Credential secret ARN per function, for the IAM grant and the Lambda environment."
  value       = { for k, s in aws_secretsmanager_secret.function : k => s.arn }
}

output "secret_names" {
  description = "Credential secret names per function, for the bootstrap command."
  value       = { for k, s in aws_secretsmanager_secret.function : k => s.name }
}
