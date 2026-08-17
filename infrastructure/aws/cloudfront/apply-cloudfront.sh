#!/usr/bin/env bash
#
# Provisions CloudFront for one environment and grants it read access to the
# matching S3 bucket via Origin Access Control.
#
#   ./apply-cloudfront.sh prod
#   ./apply-cloudfront.sh staging
#   ./apply-cloudfront.sh prod --validate-only
#
# Idempotent. An existing OAC or distribution with the same name or
# CallerReference is reused rather than duplicated.
#
# The distribution is created DISABLED. See README.md before enabling it —
# an enabled distribution without TrustedKeyGroups serves every object in the
# bucket to the public internet.

set -euo pipefail

ENV_ARG="${1:-}"
MODE="${2:-}"

HERE="$(cd "$(dirname "$0")" && pwd)"

# Environment naming lives in one place for every infrastructure script.
# shellcheck source=../env.sh
. "${HERE}/../env.sh"

if ! vump_resolve_env "$ENV_ARG"; then
  echo "usage: $0 {development|staging|production} [--validate-only]" >&2
  exit 2
fi
if ! vump_resolve_aws; then exit 1; fi

# CloudFront is provisioned for staging and production only (ADR-011).
if [ "$VUMP_ENV" = "development" ]; then
  echo "FATAL: no CloudFront distribution is provisioned for development." >&2
  echo "       ADR-011: staging rehearses the production access path; development has no delivery role." >&2
  exit 2
fi

ENV="$VUMP_SLUG"
BUCKET="$VUMP_BUCKET"
REGION="$VUMP_REGION"

winpath() { vump_winpath "$1"; }

# Rendered templates must not survive a failed run.
cleanup() { rm -f "${HERE}/.rendered-distribution-${ENV}.json" "${HERE}/.rendered-bucket-policy-${ENV}.json"; }
trap cleanup EXIT

say() { printf '%s\n' "$*"; }
die() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validate before touching AWS
# ---------------------------------------------------------------------------

say "== validating configuration for ${ENV}"

for f in "oac-${ENV}.json" "distribution-${ENV}.json" "bucket-policy-with-oac.json.tmpl"; do
  [ -f "${HERE}/${f}" ] || die "missing ${f}"
  python -c "import json,io,sys; json.load(io.open(sys.argv[1],encoding='utf-8'))" "${HERE}/${f}" \
    || die "${f} is not valid JSON"
  say "   ok  ${f}"
done

python - "$HERE" "$ENV" "$BUCKET" <<'PY' || die "configuration failed validation"
import json, io, os, sys
here, env, bucket = sys.argv[1], sys.argv[2], sys.argv[3]

d = json.load(io.open(os.path.join(here, f"distribution-{env}.json"), encoding="utf-8"))
problems = []

if d.get("Enabled") is not False:
    problems.append("Enabled must be false on creation (see README)")

b = d["DefaultCacheBehavior"]
if b["ViewerProtocolPolicy"] != "https-only":
    problems.append("ViewerProtocolPolicy must be https-only")
if sorted(b["AllowedMethods"]["Items"]) != ["GET", "HEAD"]:
    problems.append("AllowedMethods must be GET,HEAD only — uploads never traverse the CDN")
if b["TrustedKeyGroups"]["Enabled"] and b["TrustedKeyGroups"]["Quantity"] == 0:
    problems.append("TrustedKeyGroups enabled with no key group")

o = d["Origins"]["Items"][0]
if o["DomainName"] != f"{bucket}.s3.ap-south-1.amazonaws.com":
    problems.append(f"origin must be the regional S3 endpoint for {bucket}")
if o.get("S3OriginConfig", {}).get("OriginAccessIdentity") != "":
    problems.append("legacy OAI must be empty — OAC supersedes it")
if "__OAC_ID__" not in json.dumps(d):
    problems.append("OriginAccessControlId placeholder missing")

if problems:
    for p in problems:
        print("   FAIL " + p)
    sys.exit(1)
print("   ok  distribution config satisfies ADR-011 delivery constraints")
PY

if [ "$MODE" = "--validate-only" ]; then
  say "validate-only: no AWS changes made"
  exit 0
fi

"$AWS" sts get-caller-identity >/dev/null || die "AWS credentials not usable"
ACCOUNT_ID="$("$AWS" sts get-caller-identity --query Account --output text)"
say "== account ${ACCOUNT_ID}, region ${REGION}"

# ---------------------------------------------------------------------------
# Origin Access Control
# ---------------------------------------------------------------------------

OAC_NAME="$(python -c "import json,io,sys; print(json.load(io.open(sys.argv[1],encoding='utf-8'))['Name'])" "${HERE}/oac-${ENV}.json")"

OAC_ID="$("$AWS" cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='${OAC_NAME}'].Id | [0]" --output text 2>/dev/null || true)"

if [ -z "$OAC_ID" ] || [ "$OAC_ID" = "None" ]; then
  OAC_ID="$("$AWS" cloudfront create-origin-access-control \
    --origin-access-control-config "file://$(winpath "${HERE}/oac-${ENV}.json")" \
    --query 'OriginAccessControl.Id' --output text)"
  say "== created OAC ${OAC_ID}"
else
  say "== reusing OAC ${OAC_ID}"
fi

# ---------------------------------------------------------------------------
# Distribution
# ---------------------------------------------------------------------------

CALLER_REF="$(python -c "import json,io,sys; print(json.load(io.open(sys.argv[1],encoding='utf-8'))['CallerReference'])" "${HERE}/distribution-${ENV}.json")"

DIST_ID="$("$AWS" cloudfront list-distributions \
  --query "DistributionList.Items[?Comment!=null]|[?contains(Origins.Items[0].DomainName,'${BUCKET}.')].Id | [0]" \
  --output text 2>/dev/null || true)"

if [ -z "$DIST_ID" ] || [ "$DIST_ID" = "None" ]; then
  RENDERED="${HERE}/.rendered-distribution-${ENV}.json"
  sed "s|__OAC_ID__|${OAC_ID}|g" "${HERE}/distribution-${ENV}.json" > "$RENDERED"
  DIST_ID="$("$AWS" cloudfront create-distribution \
    --distribution-config "file://$(winpath "${RENDERED}")" \
    --query 'Distribution.Id' --output text)"
  rm -f "$RENDERED"
  say "== created distribution ${DIST_ID} (caller-ref ${CALLER_REF})"
else
  say "== reusing distribution ${DIST_ID}"
fi

DIST_DOMAIN="$("$AWS" cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.DomainName' --output text)"

# ---------------------------------------------------------------------------
# Bucket policy: add the OAC grant alongside the existing guardrails
# ---------------------------------------------------------------------------

POLICY="${HERE}/.rendered-bucket-policy-${ENV}.json"
sed -e "s|__BUCKET__|${BUCKET}|g" \
    -e "s|__ACCOUNT_ID__|${ACCOUNT_ID}|g" \
    -e "s|__DISTRIBUTION_ID__|${DIST_ID}|g" \
    "${HERE}/bucket-policy-with-oac.json.tmpl" > "$POLICY"

python -c "import json,io,sys; d=json.load(io.open(sys.argv[1],encoding='utf-8')); assert '__' not in json.dumps(d), 'unsubstituted placeholder'; print('   ok  rendered bucket policy')" "$POLICY"

"$AWS" s3api put-bucket-policy --bucket "$BUCKET" --policy "file://$(winpath "${POLICY}")"
rm -f "$POLICY"
say "== bucket policy updated on ${BUCKET}"

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

say ""
say "environment    ${ENV}"
say "bucket         ${BUCKET}"
say "oac            ${OAC_ID}"
say "distribution   ${DIST_ID}"
say "domain         ${DIST_DOMAIN}"
say "enabled        $("$AWS" cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.DistributionConfig.Enabled' --output text)"
say ""
say "The distribution is disabled. Read README.md before enabling it."
