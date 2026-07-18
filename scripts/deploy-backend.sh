#!/usr/bin/env bash
#
# deploy-backend.sh
#
# Manual helper to test, build, scan, push, and deploy the Golang backend.
# Mirrors what .github/workflows/backend-ci-cd.yml does in CI.
#
# Required environment variables:
#   AWS_REGION        (defaults to us-east-1)
#   EKS_CLUSTER_NAME   (defaults to starttech-cluster)
#   ECR_REPOSITORY     (defaults to starttech-backend-api)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/../backend" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/../k8s" && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-starttech-cluster}"
ECR_REPOSITORY="${ECR_REPOSITORY:-starttech-backend-api}"

echo "=== Running Go tests ==="
cd "$BACKEND_DIR"
go test ./...

echo "=== Logging into ECR ==="
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"

SHA_SHORT="$(git rev-parse --short HEAD)"
IMAGE_URI="$REGISTRY/$ECR_REPOSITORY:$SHA_SHORT"

echo "=== Building image: $IMAGE_URI ==="
docker build -t "$IMAGE_URI" .

echo "=== Scanning image (requires trivy installed locally) ==="
if command -v trivy &>/dev/null; then
  trivy image --severity CRITICAL,HIGH "$IMAGE_URI" || echo "WARNING: vulnerabilities found — review before deploying to production"
else
  echo "trivy not installed locally — skipping local scan (ECR basic scanning will still run on push)"
fi

echo "=== Pushing image ==="
docker push "$IMAGE_URI"

echo "=== Updating kubeconfig for $EKS_CLUSTER_NAME ==="
aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

echo "=== Updating deployment manifest with new image tag ==="
sed -i.bak "s|image: .*|image: $IMAGE_URI|" "$K8S_DIR/deployment.yaml" && rm -f "$K8S_DIR/deployment.yaml.bak"

echo "=== Applying manifests ==="
kubectl apply -f "$K8S_DIR/"

echo "=== Verifying rollout ==="
kubectl rollout status deployment/starttech-backend-api --timeout=180s

echo "=== Backend deploy complete: $IMAGE_URI ==="
