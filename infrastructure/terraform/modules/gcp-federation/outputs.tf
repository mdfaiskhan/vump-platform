# Everything a caller needs to build a credential configuration, and nothing
# that is itself a credential. Each value below is an identifier: possessing
# them grants nothing without an AWS or GitHub identity that satisfies the
# attribute conditions in `main.tf`.

output "redeem_audience" {
  description = <<-EOT
    The `audience` for the redeem Lambda's external-account credential
    configuration. Goes into the bundled JSON, which holds no secret.
  EOT
  value       = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.aws.name}"
}

output "redeem_service_account_email" {
  description = "Service account the redeem Lambda impersonates."
  value       = google_service_account.redeem.email
}

output "regional_cred_verification_url" {
  description = <<-EOT
    The `credential_source.regional_cred_verification_url` for the redeem
    Lambda's external-account configuration.

    Regional rather than global on purpose: the call stays inside the region
    the function runs in.

    **Lambda has no EC2 metadata server**, so the credential configuration
    cannot use the `region_url`/`url` fields that read `169.254.169.254`.
    Google's libraries fall back to `AWS_ACCESS_KEY_ID`,
    `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` and `AWS_SESSION_TOKEN` when the
    metadata server is unavailable — all four of which Lambda sets from the
    execution role. This URL is the one field still required.
  EOT
  value       = "https://sts.${var.aws_region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15"
}

output "redeem_role_arn_trusted" {
  description = <<-EOT
    The exact AWS role ARN prefix this federation trusts.

    Output so a `terraform plan` diff makes a drift in the role name visible as
    a changed value, rather than as a silent authentication failure at runtime.
    See `redeem_role_name`'s drift warning.
  EOT
  value       = local.redeem_role_arn
}

output "ci_plan_audience" {
  description = "Audience for CI's GitHub Actions credential configuration."
  value       = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.github.name}"
}

output "ci_plan_service_account_email" {
  description = "Read-only service account CI impersonates to refresh GCP state."
  value       = google_service_account.ci_plan.email
}

output "custom_role_permissions" {
  description = <<-EOT
    The two permissions the redeem service account holds.

    Output so that widening it is visible in a plan diff and in a PR review.
    ADR-036's objection was a credential that "can grant `admin` on any
    organisation"; this list is what keeps that from being true of the
    federated identity, and a change to it is the single most
    security-relevant edit anyone can make to this module.
  EOT
  value       = google_project_iam_custom_role.redeem.permissions
}
