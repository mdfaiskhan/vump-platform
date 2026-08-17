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
