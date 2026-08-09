#!/usr/bin/env bash
#
# The single definition of environment naming for every infrastructure script.
#
#   source "$(dirname "$0")/../env.sh"
#   vump_resolve_env "$1"   # sets VUMP_ENV, VUMP_SLUG, VUMP_BUCKET, VUMP_REGION
#
# Sourced, never executed. Nothing here should be restated in a caller — a
# second copy of the naming rule is how staging ends up writing to production.
#
# Authority: ADR-011 (bucket naming, region), ADR-014 (environment model),
# ADR-016 (configuration tiers). Mirrors mobile/lib/app/config/
# app_environment.dart, which holds the same mapping for Dart.

# All environments are in ap-south-1 (ADR-011).
VUMP_REGION="ap-south-1"

# Canonical environment names, matching APP_ENV and environments.json.
VUMP_ENVIRONMENTS="development staging production"

# Resolves an environment name or its AWS slug into every derived value.
#
# Accepts either form, because the two differ and both are in use:
#   development | dev      -> slug dev
#   staging                -> slug staging
#   production  | prod     -> slug prod
#
# The slug is NOT equal to the environment name. The buckets were created as
# vump-platform-dev and vump-platform-prod, and S3 bucket names are immutable.
vump_resolve_env() {
  case "${1:-}" in
    development|dev)     VUMP_ENV="development"; VUMP_SLUG="dev" ;;
    staging)             VUMP_ENV="staging";     VUMP_SLUG="staging" ;;
    production|prod)     VUMP_ENV="production";  VUMP_SLUG="prod" ;;
    *)
      printf 'FATAL: unknown environment "%s". Expected one of: %s (or a slug: dev, staging, prod)\n' \
        "${1:-}" "$VUMP_ENVIRONMENTS" >&2
      return 2
      ;;
  esac

  # Derived by rule, per ADR-011 — never listed.
  VUMP_BUCKET="vump-platform-${VUMP_SLUG}"

  export VUMP_ENV VUMP_SLUG VUMP_BUCKET VUMP_REGION AWS_DEFAULT_REGION
  AWS_DEFAULT_REGION="$VUMP_REGION"
  return 0
}

# Locates the AWS CLI. It is not always on PATH under Git Bash on Windows.
vump_resolve_aws() {
  if command -v aws >/dev/null 2>&1; then
    AWS="aws"
  elif [ -x "/c/Program Files/Amazon/AWSCLIV2/aws.exe" ]; then
    AWS="/c/Program Files/Amazon/AWSCLIV2/aws.exe"
  else
    printf 'FATAL: aws CLI not found\n' >&2
    return 1
  fi
  export AWS
  return 0
}

# Converts a POSIX path to a Windows path for native aws.exe file:// arguments.
vump_winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}
