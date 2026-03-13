#!/usr/bin/env bash
# prerequisites.sh — install Traefik and CloudNativePG as standalone releases.
#
# Run this ONCE per cluster before `helm install brighter`.
# These two install CRDs that the main chart depends on; they must be registered
# in the cluster before the application manifests are rendered.
#
# Usage:
#   ./scripts/prerequisites.sh                    # local / no TLS
#   ACME_EMAIL=you@example.com ./scripts/prerequisites.sh  # production with TLS
#
# Re-running is safe — helm upgrade --install is idempotent.

set -euo pipefail

ACME_EMAIL="${ACME_EMAIL:-}"

# ── Traefik ──────────────────────────────────────────────────────────────────
echo "→ Adding Traefik repo..."
helm repo add traefik https://traefik.github.io/charts
helm repo update traefik

if [[ -n "$ACME_EMAIL" ]]; then
  echo "→ Installing Traefik (production, ACME email: $ACME_EMAIL)..."
  helm upgrade --install traefik traefik/traefik \
    --namespace traefik \
    --create-namespace \
    --set ports.web.expose.default=true \
    --set ports.websecure.expose.default=true \
    --set "ports.web.http.redirections.entryPoint.to=websecure" \
    --set "ports.web.http.redirections.entryPoint.scheme=https" \
    --set ingressRoute.dashboard.enabled=false \
    --set providers.kubernetesCRD.enabled=true \
    --set providers.kubernetesCRD.allowCrossNamespace=true \
    --set "certificatesResolvers.letsencrypt.acme.email=${ACME_EMAIL}" \
    --set "certificatesResolvers.letsencrypt.acme.storage=/data/acme.json" \
    --set "certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=web" \
    --set persistence.enabled=true \
    --set persistence.size=128Mi \
    --wait
else
  echo "→ Installing Traefik (local, no TLS)..."
  helm upgrade --install traefik traefik/traefik \
    --namespace traefik \
    --create-namespace \
    --set ports.web.expose.default=true \
    --set ingressRoute.dashboard.enabled=false \
    --set providers.kubernetesCRD.enabled=true \
    --set providers.kubernetesCRD.allowCrossNamespace=true \
    --wait
fi

echo "→ Waiting for Traefik CRDs..."
kubectl wait --for condition=established --timeout=60s \
  crd/ingressroutes.traefik.io \
  crd/middlewares.traefik.io

# ── CloudNativePG operator ────────────────────────────────────────────────────
echo "→ Adding CloudNativePG repo..."
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update cnpg

echo "→ Installing CloudNativePG operator..."
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace \
  --wait

echo "→ Waiting for CloudNativePG CRDs..."
kubectl wait --for condition=established --timeout=60s \
  crd/clusters.postgresql.cnpg.io

echo ""
echo "Prerequisites installed. Next:"
echo "  kubectl apply -f sealed-secrets/"
echo "  helm install brighter . -f values.yaml -f values.prod.yaml"
