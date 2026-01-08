#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENEW_WS="$SCRIPT_DIR/renew-ws-cert.sh"

echo "Uninstalling WS renewal cron job..."

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Must be run as root."
  exit 1
fi

(
  crontab -l 2>/dev/null | grep -v -F "$RENEW_WS"
) | crontab -

echo "✅ WS cron job removed (if it existed)."
echo "Verify with:"
echo "  sudo crontab -l"