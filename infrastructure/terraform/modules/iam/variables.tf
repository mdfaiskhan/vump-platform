variable "environment_slug" {
  description = "AWS environment slug: dev, staging or prod (naming-conventions.md §7.1)."
  type        = string
}

variable "cluster_arn" {
  description = "Aurora cluster ARN. Every rds-data grant is scoped to this resource."
  type        = string
}

variable "master_user_secret_arn" {
  description = "ARN of the RDS-managed master credential secret. Read at runtime by every Data API caller."
  type        = string
}

variable "chunk_s3_policy_documents" {
  description = <<-EOT
    Rendered S3 policy documents for the chunks domain, keyed by purpose. Supplied
    by the caller from infrastructure/aws/iam/*.json.tmpl so those files stay the
    single definition of the S3 grants rather than being restated in HCL.
  EOT
  type        = map(string)
}
