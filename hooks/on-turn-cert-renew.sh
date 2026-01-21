#!/bin/bash
set -euo pipefail

echo "[on-renew] Certificate renewed. Reloading application..."

echo "[on-renew] Restarting terapeuta ideal websocket nginx container to apply new certificates..."
docker restart terapeuta-ideal-coturn-server

echo "[on-renew] Application reload completed."