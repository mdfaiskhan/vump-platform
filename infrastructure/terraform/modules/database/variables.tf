variable "environment_slug" {
  description = "AWS environment slug: dev, staging or prod (naming-conventions.md §7.1)."
  type        = string
}

variable "engine_version" {
  description = <<-EOT
    Aurora PostgreSQL engine version. Must be a version the RDS Data API supports
    in this region: 17.4+, 16.1+, 15.3+, 14.8+ or 13.11+. PostgreSQL 18 is offered
    in ap-south-1 but is absent from the Data API support table — selecting it
    would leave enable_http_endpoint unusable.
  EOT
  type        = string
}

variable "database_name" {
  description = "Initial database created with the cluster."
  type        = string
}

variable "master_username" {
  description = "Master user. Not 'postgres' — a named account is attributable in the audit trail."
  type        = string
}

variable "min_capacity" {
  description = "Serverless v2 minimum ACU. 0 permits scale-to-zero on supported versions."
  type        = number
}

variable "max_capacity" {
  description = "Serverless v2 maximum ACU — the cost ceiling."
  type        = number
}

variable "backup_retention_period" {
  description = "Automated backup retention, in days."
  type        = number
}

variable "deletion_protection" {
  description = "Whether the cluster refuses deletion. Must be true for staging and production."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on destroy. Must be false for staging and production."
  type        = bool
}

variable "subnet_ids" {
  description = "Private database subnet IDs, spanning at least two availability zones."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for the cluster."
  type        = list(string)
}
