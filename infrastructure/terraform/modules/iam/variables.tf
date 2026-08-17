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

variable "db_credential_secret_arns" {
  description = <<-EOT
    Per-function Aurora credential secret ARNs, keyed by function name.

    Mission 6.3. Each function may read exactly one of these, which is what
    makes Volume 8 Chapter 8.4 §1's table-level restrictions enforceable: the
    Data API authenticates as whatever user the secret names, so a function that
    cannot read another function's credential cannot act as its database role.

    Empty until the credentials module is wired, so the IAM module stays usable
    on its own.
  EOT
  type        = map(string)
  default     = {}
}
