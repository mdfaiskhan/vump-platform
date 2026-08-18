variable "region" {
  description = "AWS region. ap-south-1 for every environment, per ADR-011."
  type        = string
  default     = "ap-south-1"
}

variable "environment_slug" {
  description = "AWS environment slug. Fixed to dev for this root module."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR. Does not collide with the account's default VPC (172.31.0.0/16)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "database_subnets" {
  description = "Availability zone to CIDR, for the private database subnets."
  type        = map(string)

  default = {
    "ap-south-1a" = "10.0.20.0/24"
    "ap-south-1b" = "10.0.21.0/24"
  }
}

variable "engine_version" {
  description = "Aurora PostgreSQL version. Data API supports 16.1 and higher in ap-south-1."
  type        = string
  default     = "16.14"
}

variable "database_name" {
  description = "Initial database name."
  type        = string
  default     = "vump_dev"
}

variable "master_username" {
  description = "Master username. Deliberately not 'postgres'."
  type        = string
  default     = "vump_admin"
}

variable "min_capacity" {
  description = "Serverless v2 minimum ACU. 0 permits scale-to-zero, so an idle dev cluster costs nothing."
  type        = number
  default     = 0
}

variable "max_capacity" {
  description = "Serverless v2 maximum ACU — the dev cost ceiling."
  type        = number
  default     = 2
}

variable "backup_retention_period" {
  description = "Automated backup retention, in days."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Off for dev. Must be reconsidered for staging and production."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = <<-EOT
    True for dev: the environment holds synthetic, disposable data (ADR-014) and
    seven days of automated backups already cover accidental loss. Must be false
    for staging and production.
  EOT
  type        = bool
  default     = true
}

variable "chunk_bucket" {
  description = "Chunk storage bucket for this environment. Must match environments.json."
  type        = string
  default     = "vump-platform-dev"
}

variable "presign_expiry_seconds" {
  description = "Presigned URL lifetime. Must match environments.json (ADR-011, aws-sdk-integration.md)."
  type        = number
  default     = 3600
}

variable "firebase_project_id" {
  description = <<-EOT
    Firebase project the backend verifies ID tokens against.

    Not a secret: ADR-016 places Firebase client identifiers in the Public tier,
    and ADR-010 records why concealing them protects nothing. Deferred item 3
    records that one project currently serves all three environments.
  EOT
  type        = string
  default     = "vump-platform-f86af"
}

variable "github_repository" {
  description = <<-EOT
    owner/repo GitHub Actions federates from (ADR-049). The repository is
    public, so every OIDC trust condition is an exact-match StringEquals and no
    wildcard appears in any of them.
  EOT
  type        = string
  default     = "mdfaiskhan/vump-platform"
}

variable "state_bucket" {
  description = "Terraform state bucket (ADR-043). Must match backend.tf."
  type        = string
  default     = "vump-platform-tfstate"
}

variable "evidentiary_buckets" {
  description = <<-EOT
    Buckets holding evidentiary recordings, denied explicitly to plan-reader and
    terraform-apply. All three environments are listed regardless of which one
    this root provisions: a dev principal has no business reading staging or
    production footage either, and ADR-014 records that in a single-account
    model IAM is the only thing separating them.
  EOT
  type        = list(string)
  default     = ["vump-platform-dev", "vump-platform-staging", "vump-platform-prod"]
}

variable "github_repository_owner" {
  description = "GitHub owner login."
  type        = string
  default     = "mdfaiskhan"
}

variable "github_repository_name" {
  description = "GitHub repository name without the owner."
  type        = string
  default     = "vump-platform"
}

variable "github_owner_id" {
  description = <<-EOT
    Immutable numeric GitHub ID for the owner, embedded in the OIDC subject
    claim. Read from the REST API and confirmed against a real token's claims
    during Mission 7.1 (A-171). It changes only if the account is deleted and
    recreated, at which point federation should break rather than silently
    trust a re-registered name.
  EOT
  type        = string
  default     = "76160659"
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub ID for the repository, embedded in the OIDC subject claim."
  type        = string
  default     = "1326922888"
}
