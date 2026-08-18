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

variable "github_repository" {
  description = <<-EOT
    owner/repo the CI roles federate with. Every OIDC trust condition is an
    exact-match StringEquals built from this value, so a typo here fails closed
    — the role becomes assumable by nobody rather than by anybody.
  EOT
  type        = string
}

variable "state_bucket" {
  description = "Terraform state bucket (ADR-043). plan-reader reads it; terraform-apply also writes the lock."
  type        = string
}

variable "chunk_bucket" {
  description = "Chunk storage bucket for this environment. Capped by the permissions boundary."
  type        = string
}

variable "evidentiary_buckets" {
  description = <<-EOT
    Buckets holding evidentiary recordings, denied explicitly to plan-reader and
    to terraform-apply. ADR-043 keeps them outside Terraform's blast radius
    because they are the one thing in this account that cannot be recreated;
    this is that argument applied to the principals rather than to the state.
  EOT
  type        = list(string)
}

variable "human_user_name" {
  description = "The scoped human IAM user (ADR-049, Gap 1). Holds sts:AssumeRole and nothing else."
  type        = string
  default     = "faisal-dev"
}

variable "manage_account_identity" {
  description = <<-EOT
    Whether this instance owns the account-global identity resources: the GitHub
    OIDC provider and the human IAM user. Exactly ONE environment root may set
    this true, because both are account-wide rather than per-environment.

    dev owns them today because it is the only root that exists. When staging
    and prod roots appear (Missions 6.4/6.5), they must set this false and
    reference the same provider and user, or the apply will fail on a duplicate.
    This flag exists so that failure is a clear message rather than a puzzle.
  EOT
  type        = bool
  default     = true
}

variable "github_repository_owner" {
  description = "GitHub owner login, e.g. mdfaiskhan. The name half of the OIDC subject."
  type        = string
}

variable "github_repository_name" {
  description = "GitHub repository name without the owner, e.g. vump-platform."
  type        = string
}

variable "github_owner_id" {
  description = <<-EOT
    The owner's immutable numeric GitHub ID. GitHub embeds it in the OIDC
    subject claim, so the trust policy cannot be written without it. Measured
    from a real token, not assumed — see github-oidc.tf and A-171.
  EOT
  type        = string
}

variable "github_repository_id" {
  description = "The repository's immutable numeric GitHub ID. Embedded in the OIDC subject claim alongside the owner's."
  type        = string
}
