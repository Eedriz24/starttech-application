# StartTech Application

Application source code and delivery pipelines for StartTech's full-stack app:
a React frontend and a Golang REST API backend, deployed to the infrastructure
provisioned by the companion [`starttech-infra`](../starttech-infra) repository.

## Repository Layout

```
starttech-application/
├── .github/workflows/
│   ├── frontend-ci-cd.yml   # Build + deploy React app to S3/CloudFront
│   └── backend-ci-cd.yml    # Test, build, scan, push, deploy Go API to EKS
├── frontend/                 # React source (Vite)
├── backend/                  # Golang source + Dockerfile
├── k8s/                      # Deployment / Service / Ingress manifests
├── scripts/                  # Manual deploy/rollback/health-check helpers
└── README.md
```

## Frontend

- Calls the API using **relative paths only** (`/api/v1/...`), never a hardcoded
  domain — see `frontend/src/api.js`. This works because CloudFront serves both
  the static frontend and proxies `/api/*` to the backend under one domain
  (configured in `starttech-infra`'s `cdn` module), so there's no mixed-content
  or CORS issue.

## Backend

- Exposes a health check at both `/api/v1/health` and `/health`.
- Reads config from environment variables:
  - `REDIS_HOST` — ElastiCache endpoint (session caching)
  - `MONGO_URI` — MongoDB Atlas connection string (persistent storage)
- Logs structured JSON to stdout (via Go's `log/slog` JSON handler) for
  Container Insights / FluentBit ingestion.

## Kubernetes

- `k8s/deployment.yaml` uses a rolling update strategy with `maxSurge: 1`,
  `maxUnavailable: 0` — zero-downtime deploys.
- `k8s/service.yaml` exposes container port `8080` via `ClusterIP`.
- `k8s/ingress.yaml` uses the `alb` ingress class so the AWS Load Balancer
  Controller provisions the ALB that `starttech-infra`'s CDN module looks up
  and fronts with CloudFront.

## CI/CD

**Frontend** (`frontend-ci-cd.yml`) — triggers on changes to `frontend/`:
`npm ci` → `npm audit` → `npm run build` → `aws s3 sync` → CloudFront invalidation.

**Backend** (`backend-ci-cd.yml`) — triggers on changes to `backend/` or `k8s/`:
`go test` → build & tag image with the git SHA → Trivy vulnerability scan →
push to ECR → update `k8s/deployment.yaml` image tag → `kubectl apply` →
`kubectl rollout status` verification.

## Required GitHub Secrets

| Secret | Used by |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | both workflows |
| `FRONTEND_S3_BUCKET` | frontend workflow |
| `CLOUDFRONT_DISTRIBUTION_ID` | frontend workflow |

## Manual Scripts

```bash
./scripts/deploy-frontend.sh    # build + sync to S3 + invalidate CloudFront
./scripts/deploy-backend.sh     # test + build + scan + push + deploy to EKS
./scripts/health-check.sh [url] # hit /api/v1/health, port-forwards if no URL given
./scripts/rollback.sh [revision] # kubectl rollout undo, defaults to previous revision
```
