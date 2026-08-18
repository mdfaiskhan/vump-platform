output "role_arns" {
  description = <<-EOT
    Lambda execution role ARNs, keyed by role name. Seven roles across ADR-015's
    six domains: the chunks domain carries two, because upload and verification
    have opposite S3 needs and a role is a unit of privilege rather than of code
    decomposition.
  EOT
  value       = { for k, r in aws_iam_role.lambda : k => r.arn }
}

output "role_names" {
  description = "Lambda execution role names, keyed by role name."
  value       = { for k, r in aws_iam_role.lambda : k => r.name }
}

output "roles_by_domain" {
  description = "Role names grouped by ADR-015 resource domain, so a caller can ask what a domain may do."
  value = {
    for domain in distinct([for cfg in local.roles : cfg.domain]) :
    domain => [for name, cfg in local.roles : name if cfg.domain == domain]
  }
}

output "permissions_boundary_arn" {
  description = "The boundary every Terraform-created role carries (ADR-049, Fork A1)."
  value       = aws_iam_policy.boundary.arn
}

output "ci_role_arns" {
  description = "GitHub Actions OIDC role ARNs, keyed by purpose. Not secrets — an ARN is an identifier (ADR-016)."
  value = {
    "plan-reader" = aws_iam_role.ci_plan_reader.arn
    "db-prover"   = aws_iam_role.ci_db_prover.arn
  }
}

output "human_role_arns" {
  description = "The two MFA-gated roles faisal-dev may assume (ADR-049, D-2)."
  value = {
    "operator"        = aws_iam_role.human_operator.arn
    "terraform-apply" = aws_iam_role.human_terraform_apply.arn
  }
}

output "human_user_name" {
  description = "The scoped human user. Its access key is created out of band and never enters state."
  value       = var.manage_account_identity ? aws_iam_user.human[0].name : var.human_user_name
}
