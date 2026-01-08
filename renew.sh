#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
NGINX_NAME="nginx-certbot"

echo "Starting temporary nginx container..."

docker run -d \
  --name "$NGINX_NAME" \
  --rm \
  -p 80:80 \
  -v "$BASE_DIR/default.conf:/etc/nginx/conf.d/default.conf:ro" \
  -v "$BASE_DIR/letsencrypt:/etc/letsencrypt" \
  -v "$BASE_DIR/certbot:/var/www/certbot" \
  nginx:latest

# Give nginx a moment to boot
sleep 3

echo "Running certbot renew..."

docker run --rm \
  -v "$BASE_DIR/letsencrypt:/etc/letsencrypt" \
  -v "$BASE_DIR/certbot:/var/www/certbot" \
  certbot/certbot renew \
  --webroot \
  -w /var/www/certbot

echo "Stopping temporary nginx container..."
docker stop "$NGINX_NAME"

echo "Renew process finished"