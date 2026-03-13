## Helm Umbrella Chart — brighter-k8s

Deploys the full BrighterProject stack to Kubernetes.

## Commands

```bash
# Update Redis dependency
helm dependency update

# Local (Minikube — images built locally)
helm install brighter . -f values.yaml -f values.local.yaml

# Upgrade — specify only changed services
helm upgrade brighter . -f values.yaml -f values.prod.yaml \
  --set "users-ms.image.tag=<sha>"

# Rollback
helm rollback brighter

# Rotate secrets
./scripts/seal.sh && kubectl apply -f sealed-secrets/
kubectl rollout restart deployment brighter-users-ms
```

## Structure

```
values.yaml            # shared defaults
values.local.yaml      # Minikube: imagePullPolicy=Never, domain=localhost
values.staging.yaml    # staging overrides
values.prod.yaml       # prod: HA postgres, HPA, TLS
charts/
  users-ms/            # JWT issuer + forwardAuth target
  properties-ms/
  bookings-ms/
  payments-ms/
  frontend/            # TanStack Start SSR, port 3000
  admin-panel/         # React Router SPA, port 3000
templates/
  middlewares.yaml     # Traefik Middleware CRDs: jwt-auth, api-strip, admin-strip
  cluster.yaml         # CloudNativePG Cluster resource
sealed-secrets/        # Encrypted — safe to commit
scripts/
  prerequisites.sh     # Install Traefik + CloudNativePG once per cluster
  seal.sh              # Create/rotate sealed secrets interactively
```

## Prerequisites (run once per cluster)

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml
./scripts/prerequisites.sh                            # local
ACME_EMAIL=you@example.com ./scripts/prerequisites.sh # prod (TLS)
```

Traefik and CloudNativePG are NOT chart dependencies — they install CRDs that must exist before `helm install` renders templates.

## Secrets

| Secret | Created by | Contains |
|---|---|---|
| `brighter-db-credentials` | Manual | `username`, `password` |
| `brighter-db-app` | CloudNativePG | `uri` — **must use `asyncpg://` scheme, not `postgresql://`** |
| `users-ms-secrets` | seal.sh | `SECRET_KEY`, `GOOGLE_CLIENT_ID`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD` |
| `payments-ms-secrets` | seal.sh | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` |
| `notifications-ms-secrets` | seal.sh | `RESEND_API_KEY` |

## Gotchas

| Issue | Fix |
|---|---|
| `Unknown DB scheme: postgresql` | CloudNativePG may create URI with `postgresql://`; delete secret and recreate with `asyncpg://` |
| `Init:CrashLoopBackOff` on fresh DB | Init container runs `aerich upgrade \|\| (aerich init-db && aerich upgrade)`; check the db-app secret URI if it loops |
| `forwardAuth 500` | Traefik is in `traefik` ns — `middlewares.yaml` uses FQDN `users-ms.default.svc.cluster.local` (already correct) |
| `CRD not found` on `helm install` | Run `prerequisites.sh` first |
| IngressRoute 404 | `global.domain` must match the Host header exactly (case-sensitive) |
