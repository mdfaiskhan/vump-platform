variable "environment_slug" {
  description = "Environment this federation serves — `dev`, `staging` or `prod`."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_slug)
    error_message = "environment_slug must be dev, staging or prod."
  }
}

variable "gcp_project_id" {
  description = <<-EOT
    Firebase project this federation grants into, e.g. `vump-platform-f86af`.

    Not a secret: ADR-016 places Firebase client identifiers in the Public tier,
    and ADR-010 records why concealing them protects nothing.

    **This project is not managed by Terraform.** It, its Firestore database and
    its Auth configuration were created by hand in Mission 6.4, which open item
    118 records. This module attaches federation to a project it did not create
    and does not own, which is why every reference here is by id rather than by
    resource.
  EOT
  type        = string
}

variable "aws_account_id" {
  description = "AWS account whose Lambda execution role is trusted. 12 digits."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be exactly 12 digits."
  }
}

variable "aws_region" {
  description = "Region the trusted Lambda runs in, for the STS verification URL."
  type        = string
}

variable "redeem_role_name" {
  description = <<-EOT
    Name of the Lambda execution role permitted to impersonate the Firebase
    service account. Exactly one role, never a prefix.

    **This is a string, not a reference, and that is deliberate.** The AWS role
    is created by `modules/iam` from `"vump-$${var.environment_slug}-$${each.key}"`,
    and taking a dependency on that resource here would couple a GCP module to
    an AWS one for a value both can compute identically.

    **DRIFT WARNING.** If `modules/iam`'s role naming changes, this condition
    silently stops matching and redemption fails with an authentication error
    that names nothing. `modules/iam/main.tf` carries the reciprocal comment.
  EOT
  type        = string
}

variable "github_repository" {
  description = <<-EOT
    `owner/repo` GitHub Actions federates from, for the CI plan credential.
    Exact match, never a wildcard — ADR-049's rule, restated here because this
    provider enforces it in a different syntax.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be owner/repo."
  }
}
