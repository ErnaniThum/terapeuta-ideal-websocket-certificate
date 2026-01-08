#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

exec sudo "$SCRIPT_DIR/renew-cert.sh" \
  --cert-name terapeuta-ideal-turn \
  --conf "$SCRIPT_DIR/default.conf"