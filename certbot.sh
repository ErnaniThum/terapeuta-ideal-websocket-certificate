#!/bin/bash
set -e

echo "Starting nginx container..."
NGINX_PID=$(docker run -d \
  --name nginx \
  --rm \
    -p 80:80 \
  -v "$(pwd)/default.conf:/etc/nginx/conf.d/default.conf:ro" \
  -v "$(pwd)/letsencrypt:/etc/letsencrypt" \
  -v "$(pwd)/certbot:/var/www/certbot" \
  nginx:latest)

echo "Obtaining SSL certificates with Certbot..."
docker run -it --rm --name certbot \
  -v "$(pwd)/letsencrypt:/etc/letsencrypt" \
  -v "$(pwd)/certbot:/var/www/certbot" \
  certbot/certbot certonly --webroot \
  --webroot-path /var/www/certbot \
  --email ernani.thum@gmail.com \
  --cert-name terapeuta-ideal-ws \
  --agree-tos \
  --non-interactive \
  -d ws.terapeuta-ideal.com.br

echo "Stopping nginx container..."
docker stop "$NGINX_PID"
docker rm "$NGINX_PID"

echo "Done! Certificates saved in ./letsencrypt"