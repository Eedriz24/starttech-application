#!/usr/bin/env bash
#
# rollback.sh
#
# Rolls back the backend Deployment to the previous revision (or a specific
# revision if given), then verifies the rollout and health endpoint.
#
# Usage:
#   ./rollback.sh                # roll back to the previous revision
#   ./rollback.sh 4              # roll back to a specific revision number

set -euo pipefail

DEPLOYMENT="starttech-backend-api"
REVISION="${1:-}"

echo "=== Rollout history for $DEPLOYMENT ==="
kubectl rollout history "deployment/$DEPLOYMENT"

if [[ -n "$REVISION" ]]; then
  echo "=== Rolling back to revision $REVISION ==="
  kubectl rollout undo "deployment/$DEPLOYMENT" --to-revision="$REVISION"
else
  echo "=== Rolling back to previous revision ==="
  kubectl rollout undo "deployment/$DEPLOYMENT"
fi

echo "=== Waiting for rollout to complete ==="
kubectl rollout status "deployment/$DEPLOYMENT" --timeout=180s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/health-check.sh" ]]; then
  echo "=== Verifying health after rollback ==="
  "$SCRIPT_DIR/health-check.sh"
fi

echo "=== Rollback complete ==="
