terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Used directly by this root since Mission 7.3's `probe.tf` packages its own
    # zip. The api-gateway module already constrains it identically; a module's
    # constraint does not cover a root that uses the provider itself, which
    # tflint's terraform_required_providers rule is what caught.
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    # Mission 7.6. The Firebase project itself is NOT managed here — open item
    # 118 records that it and its two siblings were created by hand. This
    # provider manages only the Workload Identity Federation attached to it,
    # which ADR-036 requires so the redeem route can reach Firebase Admin
    # without a long-lived service-account key.
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Applied to every taggable resource. Environment carries the AWS slug (dev),
  # not the APP_ENV key (development) — naming-conventions.md §7.1 names using
  # the wrong one as the common mistake, and the buckets are vump-platform-dev.
  #
  # There is deliberately no Mission tag: it would be correct on the day these
  # resources are created and wrong after the first later mission touches them.
  # Provenance belongs in the amendment register, which is dated and does not
  # claim to describe the present.
  default_tags {
    tags = {
      Environment = var.environment_slug
      ManagedBy   = "terraform"
    }
  }
}

# Authenticates through Application Default Credentials — `gcloud auth
# application-default login`, run by a human before `terraform apply`.
#
# **No service-account key, deliberately, and this is the same argument one
# level up.** ADR-036 rejected the Lambda holding a key because it "can grant
# `admin` on any organisation"; a Terraform key would be strictly worse, since
# it can grant anything at all. A human identity with short-lived credentials
# mirrors what already happens on the AWS side, where applies run as
# `faisal-dev` with MFA rather than as a static credential.
provider "google" {
  project = var.firebase_project_id
  region  = var.region
}
