output "cluster_arn" {
  description = "Cluster ARN. The resource every rds-data call names."
  value       = aws_rds_cluster.this.arn
}

output "cluster_identifier" {
  description = "Cluster identifier."
  value       = aws_rds_cluster.this.cluster_identifier
}

output "master_user_secret_arn" {
  description = <<-EOT
    ARN of the Secrets Manager secret RDS created for the master credential.
    An ARN is an identifier, not a secret (ADR-016): it grants nothing without
    IAM permission to read what sits behind it.
  EOT
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "database_name" {
  description = "Initial database name."
  value       = aws_rds_cluster.this.database_name
}
