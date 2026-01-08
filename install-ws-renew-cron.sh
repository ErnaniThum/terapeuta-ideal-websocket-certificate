#!/bin/bash
set -euo pipefail

CRON_MINUTE="0"
CRON_HOUR="3"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENEW_WS="$SCRIPT_DIR/renew-ws-cert.sh"

LOG="/var/log/ws-renew.log"

echo "Installing WS renewal cron job (03:00)..."

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Must be run as root."
  exit 1
fi

if [[ ! -x "$RENEW_WS" ]]; then
  echo "ERROR: Script not found or not executable: $RENEW_WS"
  exit 1
fi

mkdir -p /var/log

CRON_LINE="$CRON_MINUTE $CRON_HOUR * * * $RENEW_WS >> $LOG 2>&1"

(
  crontab -l 2>/dev/null | grep -v -F "$RENEW_WS"
  echo "$CRON_LINE"
) | crontab -

echo "✅ Installed:"
echo "  $CRON_LINE"
echo "Verify:"
echo "  sudo crontab -l"