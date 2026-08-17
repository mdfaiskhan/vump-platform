output "role_arns" {
  description = "Lambda execution role ARNs, keyed by ADR-015 resource domain."
  value       = { for k, r in aws_iam_role.domain : k => r.arn }
}

output "role_names" {
  description = "Lambda execution role names, keyed by ADR-015 resource domain."
  value       = { for k, r in aws_iam_role.domain : k => r.name }
}
