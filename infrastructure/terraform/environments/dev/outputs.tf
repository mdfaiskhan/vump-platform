output "vpc_id" {
  description = "Development VPC."
  value       = module.network.vpc_id
}

output "aurora_cluster_arn" {
  description = "Cluster ARN. Mission 6.2 passes this as the Data API resourceArn."
  value       = module.database.cluster_arn
}

output "aurora_master_user_secret_arn" {
  description = <<-EOT
    ARN of the RDS-managed master credential. Becomes
    DATABASE_CREDENTIALS_SECRET_ARN in backend/.env.example, replacing that
    file's 000000000000 placeholder. An ARN is not a secret (ADR-016).
  EOT
  value       = module.database.master_user_secret_arn
}

output "database_name" {
  description = "Initial database name."
  value       = module.database.database_name
}

output "lambda_role_arns" {
  description = "Execution role ARNs by role name. Mission 6.2 attaches functions to these."
  value       = module.iam.role_arns
}

output "lambda_roles_by_domain" {
  description = <<-EOT
    Role names grouped by ADR-015 resource domain. The chunks domain carries two
    roles, so it deploys two functions — a Lambda has exactly one execution role.
  EOT
  value       = module.iam.roles_by_domain
}

output "api_invoke_url" {
  description = "Base URL of the deployed API stage. Deferred item 1's real value for development."
  value       = module.api_gateway.invoke_url
}

output "api_routes" {
  description = "Every route the API serves — the fifteen endpoints of Volume 4 Chapter 4.6."
  value       = module.api_gateway.routes
}

output "lambda_function_names" {
  description = "Deployed function names, keyed by ADR-015 function."
  value       = module.api_gateway.function_names
}

# ---------------------------------------------------------------------------
# GCP federation — Mission 7.6 Phase 2
# ---------------------------------------------------------------------------
# Surfaced at the root because Phase 3 and Phase 4 need them and the alternative
# is reading them out of state by hand. None is a credential: each is an
# identifier that grants nothing without an AWS or GitHub identity satisfying
# the pool's attribute condition. ADR-016's Public tier.
#
# The audiences carry the GCP project NUMBER, which is the only value in this
# module not derivable from configuration — every other id is deterministic from
# environment_slug and firebase_project_id.

output "redeem_audience" {
  description = "`audience` for the redeem Lambda's external-account credential configuration."
  value       = module.gcp_federation.redeem_audience
}

output "redeem_service_account_email" {
  description = "Firebase service account the redeem Lambda impersonates."
  value       = module.gcp_federation.redeem_service_account_email
}

output "redeem_regional_cred_verification_url" {
  description = "STS verification URL for the redeem credential configuration. Regional on purpose."
  value       = module.gcp_federation.regional_cred_verification_url
}

output "redeem_role_arn_trusted" {
  description = <<-EOT
    The exact AWS role ARN prefix the federation trusts. Output so a drift in
    `modules/iam`'s role naming shows up as a changed plan value rather than as
    a runtime authentication failure that names nothing.
  EOT
  value       = module.gcp_federation.redeem_role_arn_trusted
}

output "redeem_custom_role_permissions" {
  description = <<-EOT
    The two Firebase Auth permissions the redeem service account holds.

    Output so widening it is visible in a plan diff and in PR review. ADR-036's
    objection was a credential that "can grant `admin` on any organisation";
    this list is what keeps that from being true of the federated identity.
  EOT
  value       = module.gcp_federation.custom_role_permissions
}

output "ci_plan_audience" {
  description = "Audience for CI's GitHub Actions credential configuration. Needed when `ci.yml` gains its GCP auth step."
  value       = module.gcp_federation.ci_plan_audience
}

output "ci_plan_service_account_email" {
  description = "Read-only service account CI impersonates so `terraform plan` can refresh the federation resources."
  value       = module.gcp_federation.ci_plan_service_account_email
}
