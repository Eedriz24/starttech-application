#!/usr/bin/env bash
#
# health-check.sh
#
# Checks the backend's health endpoint, either directly against a given URL
# (e.g. the CloudFront domain) or via kubectl port-forward against the
# in-cluster Service if no URL is given.
#
# Usage:
#   ./health-check.sh https://d123abc.cloudfront.net
#   ./health-check.sh                       # port-forwards to the Service instead

set -euo pipefail

URL="${1:-}"

check_url() {
  local base_url="$1"
  echo "=== Checking $base_url/api/v1/health ==="
  local response
  response="$(curl -s -o /tmp/health_body -w "%{http_code}" "$base_url/api/v1/health" || echo "000")"

  if [[ "$response" == "200" ]]; then
    echo "OK (HTTP 200)"
    cat /tmp/health_body
    echo ""
    exit 0
  else
    echo "FAILED (HTTP $response)"
    cat /tmp/health_body 2>/dev/null || true
    exit 1
  fi
}

if [[ -n "$URL" ]]; then
  check_url "$URL"
else
  echo "No URL given — port-forwarding to starttech-backend-api Service on :8080"
  kubectl port-forward svc/starttech-backend-api 8080:80 &
  PF_PID=$!
  trap 'kill $PF_PID 2>/dev/null || true' EXIT
  sleep 3
  check_url "http://localhost:8080"
fi
