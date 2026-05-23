#!/usr/bin/env bash
# prerequisites.sh — install Traefik and CloudNativePG as standalone releases.
#
# Run this ONCE per cluster before `helm install brighter`.
# These two install CRDs that the main chart depends on; they must be registered
# in the cluster before the application manifests are rendered.
#
# Usage:
#   ./scripts/prerequisites.sh          # local / no TLS
#   PRODUCTION=1 ./scripts/prerequisites.sh  # production (NodePort :30080, TLS via Caddy)
#
# Re-running is safe — helm upgrade --install is idempotent.

set -euo pipefail

PRODUCTION="${PRODUCTION:-}"

# ── Traefik ──────────────────────────────────────────────────────────────────
echo "→ Adding Traefik repo..."
helm repo add traefik https://traefik.github.io/charts
helm repo update traefik

if [[ -n "$PRODUCTION" ]]; then
  # Production: Traefik binds NodePort 30080 only.
  # TLS is terminated by Caddy at the host level; Caddy proxies plain HTTP to
  # localhost:30080. forwardedHeaders.insecure lets Traefik trust the
  # X-Forwarded-Proto: https header Caddy injects.
  echo "→ Installing Traefik (production, NodePort :30080 — TLS via Caddy)..."
  helm upgrade --install traefik traefik/traefik \
    --namespace traefik \
    --create-namespace \
    --set service.type=NodePort \
    --set ports.web.expose.default=true \
    --set ports.web.nodePort=30080 \
    --set "ports.web.forwardedHeaders.insecure=true" \
    --set ingressRoute.dashboard.enabled=false \
    --set providers.kubernetesCRD.enabled=true \
    --set providers.kubernetesCRD.allowCrossNamespace=true \
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
echo ""
echo "Caddy (host) config — add a block for the k8s domain:"
echo "  yourdomain.com {"
echo "    reverse_proxy localhost:30080 {"
echo "      header_up X-Forwarded-Proto https"
echo "      header_up X-Forwarded-For {remote_host}"
echo "    }"
echo "  }"
