#!/usr/bin/env bash
#
# deploy-frontend.sh
#
# Manual helper to build and deploy the React frontend to S3 + CloudFront.
# Mirrors what .github/workflows/frontend-ci-cd.yml does in CI.
#
# Required environment variables:
#   FRONTEND_S3_BUCKET          - target S3 bucket name
#   CLOUDFRONT_DISTRIBUTION_ID  - CloudFront distribution to invalidate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(cd "$SCRIPT_DIR/../frontend" && pwd)"

: "${FRONTEND_S3_BUCKET:?Set FRONTEND_S3_BUCKET before running}"
: "${CLOUDFRONT_DISTRIBUTION_ID:?Set CLOUDFRONT_DISTRIBUTION_ID before running}"

echo "=== Installing dependencies ==="
cd "$FRONTEND_DIR"
npm ci

echo "=== Running security audit ==="
npm audit --audit-level=high || echo "WARNING: audit found issues — review before deploying to production"

echo "=== Building static site ==="
npm run build

echo "=== Uploading to S3: $FRONTEND_S3_BUCKET ==="
aws s3 sync build/ "s3://$FRONTEND_S3_BUCKET" --delete

echo "=== Invalidating CloudFront cache: $CLOUDFRONT_DISTRIBUTION_ID ==="
aws cloudfront create-invalidation \
  --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
  --paths "/*"

echo "=== Frontend deploy complete ==="
