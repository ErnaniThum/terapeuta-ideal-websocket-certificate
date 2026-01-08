#!/bin/bash
set -euo pipefail

# Wrapper for creating the WS certificate using init-cert.sh
# Assumes init-cert.sh is in the same directory as this script.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INIT_SCRIPT="$SCRIPT_DIR/init-cert.sh"

if [[ ! -x "$INIT_SCRIPT" ]]; then
  echo "ERROR: init script not found or not executable: $INIT_SCRIPT"
  echo "Fix: chmod +x $INIT_SCRIPT"
  exit 1
fi

# Default values for WS cert creation
DOMAIN="turn.terapeuta-ideal.com.br"
CERT_NAME="terapeuta-ideal-turn"
EMAIL="ernani.thum@gmail.com"

# Use the same default.conf next to the scripts unless overridden
NGINX_CONF="$SCRIPT_DIR/default.conf"

# Call init script (must be run as root because it writes to /etc and /var)
exec sudo "$INIT_SCRIPT" \
  --domain "$DOMAIN" \
  --cert-name "$CERT_NAME" \
  --email "$EMAIL" \
  --conf "$NGINX_CONF"