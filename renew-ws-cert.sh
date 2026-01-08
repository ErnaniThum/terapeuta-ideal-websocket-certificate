#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/hooks/on-cert-renew"

exec sudo "$SCRIPT_DIR/renew-cert.sh" \
  --cert-name terapeuta-ideal-ws \
  --conf "$SCRIPT_DIR/default.conf" \
  --hook "$HOOK"