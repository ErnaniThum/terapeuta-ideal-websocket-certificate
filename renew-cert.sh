#!/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  sudo ./renew-cert.sh [options]

Options:
  --cert-name <name>     Renew only a specific certificate
  --conf <path>          nginx challenge config (default: ./default.conf)
  --le-dir <path>        LetsEncrypt dir (default: /etc/letsencrypt)
  --webroot <path>       Webroot dir (default: /var/www/certbot)
  --nginx-name <name>    Temp nginx container name
  --hook <path>          Executable script to run on host only if renewal happened
  -h, --help             Show this help
EOF
}

### === DEFAULTS ===
LE_DIR="/etc/letsencrypt"
WEBROOT="/var/www/certbot"
NGINX_NAME="nginx-certbot"
NGINX_CONF="$(pwd)/default.conf"
CERT_NAME=""
FLAG="/var/run/certbot-renewed.flag"
HOOK=""

### === PARSE ARGS ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cert-name) CERT_NAME="${2:-}"; shift 2 ;;
    --conf) NGINX_CONF="${2:-}"; shift 2 ;;
    --le-dir) LE_DIR="${2:-}"; shift 2 ;;
    --webroot) WEBROOT="${2:-}"; shift 2 ;;
    --nginx-name) NGINX_NAME="${2:-}"; shift 2 ;;
    --hook) HOOK="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1"; usage; exit 2 ;;
  esac
done

### === PRECHECKS ===
if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Must be run as root."
  exit 1
fi

for p in "$LE_DIR" "$WEBROOT" "$NGINX_CONF"; do
  [[ -e "$p" ]] || { echo "ERROR: Missing $p"; exit 1; }
done

# Hook is optional, but if provided it must exist and be executable
if [[ -n "$HOOK" ]]; then
  if [[ ! -f "$HOOK" ]]; then
    echo "ERROR: Hook file not found: $HOOK"
    exit 1
  fi
  if [[ ! -x "$HOOK" ]]; then
    echo "ERROR: Hook is not executable: $HOOK"
    echo "Fix: chmod +x $HOOK"
    exit 1
  fi
fi

rm -f "$FLAG"

### === CLEANUP ===
cleanup() {
  if docker ps -q -f "name=^/${NGINX_NAME}$" >/dev/null 2>&1; then
    docker stop "$NGINX_NAME" >/dev/null || true
  fi
}
trap cleanup EXIT

### === START TEMP NGINX ===
echo "Starting temporary nginx..."
docker run -d \
  --name "$NGINX_NAME" \
  --rm \
  -p 80:80 \
  -v "$NGINX_CONF:/etc/nginx/conf.d/default.conf:ro" \
  -v "$LE_DIR:/etc/letsencrypt" \
  -v "$WEBROOT:/var/www/certbot" \
  nginx:latest

sleep 3

### === CERTBOT RENEW ===
echo "Running certbot renew..."

RENEW_ARGS=(
  renew
  --webroot -w /var/www/certbot
  --non-interactive
  # Runs only when a cert is actually renewed; writes a host-visible flag.
  --deploy-hook "sh -c 'echo renewed > /var/run/certbot-renewed.flag'"
)

if [[ -n "$CERT_NAME" ]]; then
  RENEW_ARGS+=( --cert-name "$CERT_NAME" )
fi

docker run --rm --name certbot \
  -v "$LE_DIR:/etc/letsencrypt" \
  -v "$WEBROOT:/var/www/certbot" \
  -v "/var/run:/var/run" \
  certbot/certbot "${RENEW_ARGS[@]}"

### === RESULT ===
if [[ -f "$FLAG" ]]; then
  echo "✅ Certificate renewal occurred."
  if [[ -n "$HOOK" ]]; then
    echo "Running hook: $HOOK"
    "$HOOK"
  fi
else
  echo "ℹ️ No certificates were due for renewal."
fi