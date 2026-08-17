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
