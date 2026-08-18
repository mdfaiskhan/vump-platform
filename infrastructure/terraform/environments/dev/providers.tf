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
