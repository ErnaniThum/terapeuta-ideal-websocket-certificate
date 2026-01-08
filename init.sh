#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo ./init-cert.sh --domain <fqdn> --cert-name <name> [--email <email>] [--conf <nginx_conf_path>] [--webroot <path>] [--le-dir <path>] [--nginx-name <container_name>]

Examples:
  sudo ./init-cert.sh --domain ws.terapeuta-ideal.com.br --cert-name terapeuta-ideal-ws --email ernani.thum@gmail.com
  sudo ./init-cert.sh --domain turn.terapeuta-ideal.com.br --cert-name terapeuta-ideal-turn --email ernani.thum@gmail.com --conf /opt/certbot/default.conf
EOF
}

# Defaults
EMAIL=""
LE_DIR="/etc/letsencrypt"
WEBROOT="/var/www/certbot"
NGINX_CONF="$(pwd)/default.conf"
NGINX_NAME="nginx-certbot"
DOMAIN=""
CERT_NAME=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="${2:-}"; shift 2 ;;
    --cert-name) CERT_NAME="${2:-}"; shift 2 ;;
    --email) EMAIL="${2:-}"; shift 2 ;;
    --conf) NGINX_CONF="${2:-}"; shift 2 ;;
    --webroot) WEBROOT="${2:-}"; shift 2 ;;
    --le-dir) LE_DIR="${2:-}"; shift 2 ;;
    --nginx-name) NGINX_NAME="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

# Validate required args
if [[ -z "$DOMAIN" || -z "$CERT_NAME" ]]; then
  echo "ERROR: --domain and --cert-name are required."
  usage
  exit 2
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: This script must be run as root (writes to /etc and /var)."
  exit 1
fi

if [[ ! -f "$NGINX_CONF" ]]; then
  echo "ERROR: nginx config file not found: $NGINX_CONF"
  exit 1
fi

echo "=== Init certificate ==="
echo "Domain     : $DOMAIN"
echo "Cert name  : $CERT_NAME"
echo "LE dir     : $LE_DIR"
echo "Webroot    : $WEBROOT"
echo "Nginx conf : $NGINX_CONF"
echo "Nginx name : $NGINX_NAME"
echo

# Create required directories (init is allowed to create)
mkdir -p "$LE_DIR"
mkdir -p "$WEBROOT"
chmod 755 "$WEBROOT"
chmod 700 "$LE_DIR"

# Refuse to initialize if cert-name already exists (prevents -0001 duplicates)
LIVE_DIR="$LE_DIR/live/$CERT_NAME"
RENEWAL_CONF="$LE_DIR/renewal/$CERT_NAME.conf"
if [[ -d "$LIVE_DIR" || -f "$RENEWAL_CONF" ]]; then
  echo "ERROR: A certificate with cert-name '$CERT_NAME' already exists."
  [[ -d "$LIVE_DIR" ]] && echo " - $LIVE_DIR"
  [[ -f "$RENEWAL_CONF" ]] && echo " - $RENEWAL_CONF"
  echo
  echo "If you intended to re-issue/replace it, do NOT use init."
  echo "Use renew flow or explicitly delete it:"
  echo "  docker run --rm -v \"$LE_DIR:/etc/letsencrypt\" certbot/certbot delete --cert-name \"$CERT_NAME\""
  exit 1
fi

cleanup() {
  if docker ps -q -f "name=^/${NGINX_NAME}$" >/dev/null 2>&1; then
    echo "Stopping temporary nginx container..."
    docker stop "$NGINX_NAME" >/dev/null || true
  fi
}
trap cleanup EXIT

echo "Starting temporary nginx container on :80..."
docker run -d \
  --name "$NGINX_NAME" \
  --rm \
  -p 80:80 \
  -v "$NGINX_CONF:/etc/nginx/conf.d/default.conf:ro" \
  -v "$LE_DIR:/etc/letsencrypt" \
  -v "$WEBROOT:/var/www/certbot" \
  nginx:latest

sleep 3

echo "Requesting certificate with certbot (webroot)..."
CERTBOT_ARGS=(
  certonly --webroot
  --webroot-path /var/www/certbot
  --cert-name "$CERT_NAME"
  --agree-tos
  --non-interactive
  --no-eff-email
  -d "$DOMAIN"
)

if [[ -n "$EMAIL" ]]; then
  CERTBOT_ARGS+=( --email "$EMAIL" )
else
  # If you truly want no email, certbot needs this.
  CERTBOT_ARGS+=( --register-unsafely-without-email )
fi

docker run --rm --name certbot \
  -v "$LE_DIR:/etc/letsencrypt" \
  -v "$WEBROOT:/var/www/certbot" \
  certbot/certbot "${CERTBOT_ARGS[@]}"

echo
echo "✅ Done!"
echo "Certificate files should be available at:"
echo "  $LE_DIR/live/$CERT_NAME/"
echo "  - fullchain.pem"
echo "  - privkey.pem"