#!/usr/bin/env bash
# seal.sh — create or re-seal Kubernetes secrets for BrighterProject
#
# Prerequisites:
#   brew install kubeseal   (or the equivalent for your OS)
#   kubectl context pointed at the target cluster
#
# Usage:
#   ./scripts/seal.sh [namespace]          # seal ALL secrets
#   ./scripts/seal.sh [namespace] db       # seal only db-credentials
#   ./scripts/seal.sh [namespace] users    # seal only users-ms-secrets
#   ./scripts/seal.sh [namespace] payments      # seal only payments-ms-secrets
#   ./scripts/seal.sh [namespace] bookings      # seal only bookings-ms-secrets
#   ./scripts/seal.sh [namespace] notifications # seal only notifications-ms-secrets
#   ./scripts/seal.sh [namespace] properties    # seal only properties-ms-secrets
#   ./scripts/seal.sh [namespace] grafana       # seal only grafana secrets
#
# Run this whenever you need to rotate a secret value. The resulting
# sealed-secrets/*.yaml files are safe to commit to Git.

set -euo pipefail

NS=${1:-default}
TARGET=${2:-all}
OUT=sealed-secrets

seal_db() {
  echo "  → brighter-db-credentials"
  read -rs -p "  PostgreSQL password: " PG_PASS; echo
  kubectl create secret generic brighter-db-credentials \
    --namespace "$NS" \
    --from-literal=username=brighter \
    --from-literal=password="$PG_PASS" \
    --dry-run=client -o yaml \
    | kubeseal --format yaml \
    > "$OUT/db-credentials.yaml"
}

seal_users() {
  echo "  → users-ms-secrets"
  read -rs -p "  SECRET_KEY (JWT signing key): " SECRET_KEY; echo
  read -rs -p "  SMTP_PASSWORD: " SMTP_PASSWORD; echo
  read -rs -p "  TURNSTILE_SECRET_KEY (Cloudflare): " TURNSTILE_SECRET_KEY; echo
  kubectl create secret generic users-ms-secrets \
    --namespace "$NS" \
    --from-literal=SECRET_KEY="$SECRET_KEY" \
    --from-literal=SMTP_PASSWORD="$SMTP_PASSWORD" \
    --from-literal=TURNSTILE_SECRET_KEY="$TURNSTILE_SECRET_KEY" \
    --dry-run=client -o yaml \
    | kubeseal --format yaml \
    > "$OUT/users-ms-secrets.yaml"
}

seal_payments() {
  echo "  → payments-ms-secrets"
  read -rs -p "  STRIPE_SECRET_KEY: " STRIPE_KEY; echo
  read -rs -p "  STRIPE_WEBHOOK_SECRET: " STRIPE_WEBHOOK; echo
  read -rs -p "  STRIPE_CONNECT_WEBHOOK_SECRET: " STRIPE_CONNECT_WEBHOOK; echo
  kubectl create secret generic payments-ms-secrets \
    --namespace "$NS" \
    --from-literal=STRIPE_SECRET_KEY="$STRIPE_KEY" \
    --from-literal=STRIPE_WEBHOOK_SECRET="$STRIPE_WEBHOOK" \
    --from-literal=STRIPE_CONNECT_WEBHOOK_SECRET="$STRIPE_CONNECT_WEBHOOK" \
    --dry-run=client -o yaml \
    | kubeseal --format yaml \
    > "$OUT/payments-ms-secrets.yaml"
}

seal_bookings() {
  echo "  → bookings-ms-secrets"
  echo "  (BOOKING_FIELD_ENCRYPTION_KEY: generate with"
  echo "     python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')"
  read -rs -p "  BOOKING_FIELD_ENCRYPTION_KEY (Fernet): " FIELD_KEY; echo
  read -rs -p "  CHECKIN_TOKEN_SECRET: " CHECKIN_SECRET; echo
  read -rs -p "  INTERNAL_CRON_SECRET: " CRON_SECRET; echo
  kubectl create secret generic bookings-ms-secrets \
    --namespace "$NS" \
    --from-literal=BOOKING_FIELD_ENCRYPTION_KEY="$FIELD_KEY" \
    --from-literal=CHECKIN_TOKEN_SECRET="$CHECKIN_SECRET" \
    --from-literal=INTERNAL_CRON_SECRET="$CRON_SECRET" \
    --dry-run=client -o yaml \
    | kubeseal --format yaml \
    > "$OUT/bookings-ms-secrets.yaml"
}

seal_notifications() {
  echo "  → notifications-ms-secrets"
  read -rs -p "  RESEND_API_KEY: " RESEND_API_KEY; echo
  kubectl create secret generic notifications-ms-secrets \
    --namespace "$NS" \
    --from-literal=RESEND_API_KEY="$RESEND_API_KEY" \
    --dry-run=client -o yaml \
    | kubeseal --format yaml \
    > "$OUT/notifications-ms-secrets.yaml"
}

seal_properties() {
  echo "  → properties-ms-secrets"
  read -rs -p "  R2_ACCESS_KEY_ID: " R2_ACCESS_KEY_ID; echo
  read -rs -p "  R2_SECRET_ACCESS_KEY: " R2_SECRET_ACCESS_KEY; echo
  kubectl create secret generic properties-ms-secrets \
    --namespace "$NS" \
    --from-literal=R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
    --from-literal=R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
    --dry-run=client -o yaml \
    | kubeseal --format yaml \
    > "$OUT/properties-ms-secrets.yaml"
}

seal_grafana() {
  echo "  → grafana-admin-secret"
  read -r  -p "  Grafana admin username [admin]: " GRAFANA_USER; GRAFANA_USER=${GRAFANA_USER:-admin}
  read -rs -p "  Grafana admin password: " GRAFANA_PASS; echo
  kubectl create secret generic grafana-admin-secret \
    --namespace "$NS" \
    --from-literal=admin-user="$GRAFANA_USER" \
    --from-literal=admin-password="$GRAFANA_PASS" \
    --dry-run=client -o yaml \
    | kubeseal --format yaml \
    > "$OUT/grafana-admin-secret.yaml"

  echo "  → grafana-alerting-secrets (TELEGRAM_BOT_TOKEN only — CHAT_ID and URL go in values.yaml)"
  read -r  -p "  TELEGRAM_BOT_TOKEN (leave blank to skip): " TG_TOKEN
  if [[ -n "$TG_TOKEN" ]]; then
    kubectl create secret generic grafana-alerting-secrets \
      --namespace "$NS" \
      --from-literal=TELEGRAM_BOT_TOKEN="$TG_TOKEN" \
      --dry-run=client -o yaml \
      | kubeseal --format yaml \
      > "$OUT/grafana-alerting-secrets.yaml"
  else
    echo "  (skipped — no Telegram token provided)"
  fi
}

mkdir -p "$OUT"

echo "Sealing secrets for namespace: $NS"

case "$TARGET" in
  db)            seal_db ;;
  users)         seal_users ;;
  payments)      seal_payments ;;
  bookings)      seal_bookings ;;
  notifications) seal_notifications ;;
  properties)    seal_properties ;;
  grafana)       seal_grafana ;;
  all)           seal_db; seal_users; seal_payments; seal_bookings; seal_notifications; seal_properties; seal_grafana ;;
  *)             echo "Unknown target: $TARGET (use: db, users, payments, bookings, notifications, properties, grafana, or all)"; exit 1 ;;
esac

echo ""
echo "Done. Commit the files in $OUT/ — they are encrypted and safe for Git."
echo "Apply them with:  kubectl apply -f $OUT/"
