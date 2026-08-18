#!/usr/bin/env bash
for s in 72-couture demo-couture rayan-couture yatt-services lah-collection; do
  echo "=== $s ==="
  if [ -d "/srv/$s" ]; then
    docker compose -f /srv/$s/docker-compose.yml exec -T db psql -U couture -d couture_mali -c "SELECT key, value FROM settings WHERE key IN ('shop_name', 'logo_url', 'theme_color');"
    echo "uploads in /srv/$s/uploads:"
    docker compose -f /srv/$s/docker-compose.yml exec -T api ls -la /app/uploads
  fi
done
