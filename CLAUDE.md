## Helm Charts — brighter-k8s

Two separate Helm releases to stay under Kubernetes' 1 MiB secret limit.

| Chart | Release name | What it deploys |
|---|---|---|
| `brighter-app/` | `brighter` | App services + Redis + CloudNativePG cluster |
| `brighter-obs/` | `brighter-obs` | Tempo, Loki, Promtail, Grafana, Prometheus, OTEL Collector |

## Quick Reference

```bash
# App — initial install
helm install brighter ./brighter-app -f brighter-app/values.yaml -f brighter-app/values.prod.yaml --namespace brighter

# App — upgrade (specify only changed services)
helm upgrade brighter ./brighter-app -f brighter-app/values.yaml -f brighter-app/values.prod.yaml \
  --set "users-ms.image.tag=<sha>" --namespace brighter

# Observability — initial install
helm install brighter-obs ./brighter-obs -f brighter-obs/values.yaml --namespace brighter

# Observability — upgrade
helm upgrade brighter-obs ./brighter-obs -f brighter-obs/values.yaml --namespace brighter

# Rollback
helm rollback brighter
helm rollback brighter-obs

# Rotate secrets
./scripts/seal.sh && kubectl apply -f brighter-app/sealed-secrets/ -f brighter-obs/sealed-secrets/
kubectl rollout restart deployment brighter-users-ms
```

## Prerequisites (run once per cluster)

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml
./scripts/prerequisites.sh                            # local
ACME_EMAIL=you@example.com ./scripts/prerequisites.sh # prod (TLS)
```

Traefik and CloudNativePG are NOT chart dependencies — they install CRDs that must exist before `helm install` renders templates.

## Update dependencies

```bash
helm dependency update ./brighter-app
helm dependency update ./brighter-obs
```

## Structure

```
brighter-app/
  Chart.yaml          # redis + local service subcharts
  values.yaml         # shared defaults
  values.prod.yaml    # prod: Redis persistence, pullPolicy=Always
  values.local.yaml   # Minikube: imagePullPolicy=Never, domain=localhost
  values.staging.yaml # staging overrides
  charts/
    redis-*.tgz       # fetched by helm dependency update
    users-ms/         # JWT issuer + forwardAuth target
    properties-ms/
    bookings-ms/
    payments-ms/
    notifications-ms/
    frontend/         # TanStack Start SSR
    admin-panel/      # React Router SPA
  templates/
    middlewares.yaml  # Traefik Middleware CRDs: jwt-auth, api-strip, admin-strip
    cluster.yaml      # CloudNativePG Cluster resource
  sealed-secrets/     # App secrets — safe to commit

brighter-obs/
  Chart.yaml          # Tempo, Loki, Promtail, Grafana, Prometheus
  values.yaml         # all observability config
  charts/
    tempo-*.tgz
    loki-*.tgz
    promtail-*.tgz
    grafana-*.tgz
    prometheus-*.tgz
  templates/
    otel-collector/   # Deployment + Service + ConfigMap
    grafana-dashboard-cm.yaml
    grafana-alerting-cm.yaml
  dashboards/         # brighter.json — mounted via ConfigMap
  alerting/           # Grafana provisioning: rules, contact-points, policies
  sealed-secrets/     # grafana-admin-secret, grafana-alerting-secrets

scripts/
  prerequisites.sh    # Install Traefik + CloudNativePG once per cluster
  seal.sh             # Create/rotate sealed secrets interactively
```

## Service names (stable across releases)

The obs chart sets `fullnameOverride` so these names are fixed regardless of the release name `brighter-obs`:

| Service | Name |
|---|---|
| Tempo | `brighter-tempo` |
| Loki | `brighter-loki` |
| Prometheus server | `brighter-prometheus-server` |
| OTEL Collector | `otel-collector` (hardcoded in template) |

## Secrets

| Secret | Chart | Created by | Contains |
|---|---|---|---|
| `brighter-db-credentials` | app | Manual | `username`, `password` |
| `brighter-db-app` | app | CloudNativePG | `uri` — **must use `asyncpg://` scheme** |
| `users-ms-secrets` | app | seal.sh | `SECRET_KEY`, `GOOGLE_CLIENT_ID`, `SMTP_USER`, `SMTP_PASSWORD`, `TURNSTILE_SECRET_KEY` |
| `payments-ms-secrets` | app | seal.sh | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_CONNECT_WEBHOOK_SECRET`, `INTERNAL_API_KEY` |
| `notifications-ms-secrets` | app | seal.sh | `RESEND_API_KEY` |
| `properties-ms-secrets` | app | seal.sh | `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` |
| `grafana-admin-secret` | obs | seal.sh | `admin-user`, `admin-password` |
| `grafana-alerting-secrets` | obs | seal.sh (optional) | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `GRAFANA_EXTERNAL_URL` |

## Gotchas

| Issue | Fix |
|---|---|
| `Unknown DB scheme: postgresql` | CloudNativePG may create URI with `postgresql://`; delete secret and recreate with `asyncpg://` |
| `Init:CrashLoopBackOff` on fresh DB | Init container runs `aerich upgrade \|\| (aerich init-db && aerich upgrade)`; check the db-app secret URI if it loops |
| `forwardAuth 500` | Traefik is in `traefik` ns — `middlewares.yaml` uses FQDN `users-ms.default.svc.cluster.local` (already correct) |
| `CRD not found` on `helm install` | Run `prerequisites.sh` first |
| IngressRoute 404 | `global.domain` must match the Host header exactly (case-sensitive) |

## Git & Branch Workflow

- **Branch off `main`**: infra changes use `feat/<slug>` or `chore/<slug>` branches, PRed directly to `main` — no `dev` staging layer for infra
- **Approval required**: at least one human approval before merging
- **CI must be green**: all checks must pass before merging
- **Branch cleanup**: delete merged branches periodically — keep them for a while for reference, then clean up
