# Cross-cloud federation into the Firebase project — Mission 7.6, Phase 2.
#
# ADR-036 put invite-code redemption in a Cloud Function for one reason, stated
# in its own words: "running the Admin SDK outside Google means holding a
# service-account private key that can grant `admin` on any organisation, while
# inside Cloud Functions the runtime authenticates through the metadata server
# and no key exists."
#
# Porting the function to Lambda therefore has to answer that, not sidestep it.
# ADR-036 named the shape — "Workload Identity Federation from AWS to GCP is the
# shape that avoids one" — and deferred the cost. This module is that answer.
#
# ## What replaces the key
#
# A key is a bearer secret: whoever holds the bytes is the service account.
# Federation replaces it with a **verifiable claim about which AWS role is
# calling**. The Lambda signs an AWS STS `GetCallerIdentity` request with the
# credentials AWS already gave it; GCP verifies that signature and reads the
# caller's role ARN out of it. Nothing here is a credential — the credential
# configuration the function bundles names this pool and is useless without an
# AWS identity that satisfies the condition below.
#
# ## Two pools, because there are two callers
#
# The Lambda federates from AWS. CI federates from GitHub Actions to run
# `terraform plan`, which reads these very resources. Different issuers cannot
# share a provider, so they cannot share a pool's trust surface meaningfully.
#
# CI's half exists because `ci.yml` runs `terraform plan` on every pull request,
# and the moment this module is added a plan without GCP credentials fails —
# or worse, is scoped around the gap and silently stops covering part of the
# infrastructure. That is the "green check that measures nothing" pattern
# A-205, A-214 and A-218 each record an instance of. Not tolerable for a
# security control.

locals {
  # Deterministic from the two values `modules/iam` builds the role name from.
  # See `redeem_role_name`'s drift warning.
  redeem_role_arn = "arn:aws:sts::${var.aws_account_id}:assumed-role/${var.redeem_role_name}"
}

# ===========================================================================
# The Firebase service account — what the Lambda becomes
# ===========================================================================
resource "google_service_account" "redeem" {
  project = var.gcp_project_id

  account_id   = "vump-${var.environment_slug}-redeem"
  display_name = "Invite-code redemption (${var.environment_slug})"
  description  = "Impersonated by the redeem Lambda via Workload Identity Federation. Holds a custom role with exactly two Firebase Auth permissions — never firebaseauth.admin. Mission 7.6."
}

# ===========================================================================
# The custom role — the part that makes federation better in KIND
# ===========================================================================
# `roles/firebaseauth.admin` is the narrowest PREDEFINED role carrying
# `firebaseauth.users.update`, and it is far too broad: it is full read/write
# on Firebase Authentication, so it can delete any user, enumerate every
# account, and rewrite anyone's claims.
#
# **That is very close to the capability ADR-036 rejected.** Its objection was a
# credential that "can grant `admin` on any organisation" — and a federated
# identity holding `firebaseauth.admin` can do exactly that. Federation would
# then have removed the KEY while keeping the CAPABILITY, satisfying half the
# reasoning and reporting it as all of it.
#
# So the service account gets a custom role holding precisely the two
# permissions the redeem route performs and nothing else. It cannot delete a
# user, cannot list users, cannot disable an account.
resource "google_project_iam_custom_role" "redeem" {
  project = var.gcp_project_id

  role_id     = "vumpRedeem${title(var.environment_slug)}"
  title       = "Vump invite redemption (${var.environment_slug})"
  description = "Create a user and set its custom claims. Nothing else. Deliberately narrower than roles/firebaseauth.admin — see Mission 7.6 Phase 2."

  # `createUser` and `setCustomUserClaims`, and no third thing.
  #
  # These two ids were UNVERIFIED at authoring time — taken from Google's
  # Firebase Authentication roles reference, whose permission tables did not
  # render when checked. F1 deferred exact-string confirmation to
  # implementation deliberately.
  #
  # CONFIRMED 2026-08-20 by the dev apply. GCP rejects unknown permission ids,
  # so acceptance is the confirmation — there is no weaker outcome where a
  # misspelt id is silently created.
  #
  # STILL UNPROVEN: that these two SUFFICE. No token has been exchanged and no
  # user has been created through this identity; Phase 4 is the first time
  # either happens. If `setCustomUserClaims` needs a third permission, ADD IT
  # HERE EXPLICITLY — do not substitute `roles/firebaseauth.admin`, which is
  # full read/write on Firebase Auth and would discard the whole argument
  # above, removing the key while keeping the capability.
  permissions = [
    "firebaseauth.users.create",
    "firebaseauth.users.update",
  ]
}

resource "google_project_iam_member" "redeem" {
  project = var.gcp_project_id
  role    = google_project_iam_custom_role.redeem.name
  member  = "serviceAccount:${google_service_account.redeem.email}"
}

# ===========================================================================
# Pool 1 — AWS, for the redeem Lambda
# ===========================================================================
resource "google_iam_workload_identity_pool" "aws" {
  project = var.gcp_project_id

  workload_identity_pool_id = "vump-${var.environment_slug}-aws"
  display_name              = "Vump AWS (${var.environment_slug})"
  description               = "Trusts one Lambda execution role. Mission 7.6."
}

resource "google_iam_workload_identity_pool_provider" "aws" {
  project = var.gcp_project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.aws.workload_identity_pool_id
  workload_identity_pool_provider_id = "aws-lambda"
  display_name                       = "AWS Lambda"

  aws {
    account_id = var.aws_account_id
  }

  attribute_mapping = {
    "google.subject"     = "assertion.arn"
    "attribute.aws_role" = "assertion.arn"
  }

  # THE security control in this module.
  #
  # Without it, the pool trusts the AWS ACCOUNT — every role, every Lambda,
  # every EC2 instance, anything that can call GetCallerIdentity. That would be
  # a far wider grant than the service-account key it replaces, which is the
  # failure mode worth naming: federation is only narrower than a key if the
  # condition makes it so.
  #
  # `startsWith` rather than `==` because STS renders an assumed-role ARN as
  # `.../assumed-role/{role}/{session}`, and the session suffix is chosen by
  # Lambda per invocation. The prefix is the role, which is the identity.
  attribute_condition = "assertion.arn.startsWith('${local.redeem_role_arn}')"
}

resource "google_service_account_iam_member" "aws_impersonation" {
  service_account_id = google_service_account.redeem.name
  role               = "roles/iam.workloadIdentityUser"

  # Scoped to the mapped attribute rather than to the whole pool. `principalSet`
  # on `*` would let any identity the pool admits impersonate this account, and
  # the attribute condition above would be the only thing standing in the way.
  # Two independent narrowings rather than one.
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.aws.name}/attribute.aws_role/${local.redeem_role_arn}"
}

# ===========================================================================
# Pool 2 — GitHub Actions, for `terraform plan` in CI
# ===========================================================================
# Reuses ADR-049's PATTERN, not its infrastructure. The AWS pool above cannot
# serve GitHub: a provider trusts one issuer, and these are two.
resource "google_iam_workload_identity_pool" "github" {
  project = var.gcp_project_id

  workload_identity_pool_id = "vump-${var.environment_slug}-github"
  display_name              = "Vump GitHub Actions (${var.environment_slug})"
  description               = "Read-only, for `terraform plan` on pull requests. Mission 7.6."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project = var.gcp_project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # Exact match, no wildcard — ADR-049's rule: "The repository is public, so
  # every OIDC trust condition is an exact-match StringEquals and no wildcard
  # appears in any of them." Same rule, this provider's syntax.
  attribute_condition = "assertion.repository == '${var.github_repository}'"
}

resource "google_service_account" "ci_plan" {
  project = var.gcp_project_id

  account_id   = "vump-${var.environment_slug}-ci-plan"
  display_name = "Terraform plan, CI (${var.environment_slug})"
  description  = "Read-only. Lets `terraform plan` refresh the federation resources it manages, so a plan cannot silently stop covering them. Mission 7.6."
}

# `roles/viewer` is broad for a reader and is still the right call here: a plan
# refreshes whatever the configuration declares, and predicting that set as a
# permission list would break the plan every time a resource is added — which
# is the same silent-gap failure this account exists to prevent.
#
# It is READ-ONLY, holds nothing on the redeem service account, and cannot
# impersonate it. What it can do is see the shape of a project it does not own.
resource "google_project_iam_member" "ci_plan_viewer" {
  project = var.gcp_project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.ci_plan.email}"
}

resource "google_service_account_iam_member" "github_impersonation" {
  service_account_id = google_service_account.ci_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
