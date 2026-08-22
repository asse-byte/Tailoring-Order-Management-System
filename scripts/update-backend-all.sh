#!/usr/bin/env bash
set -e
for s in 72-couture demo-couture rayan-couture yatt-services lah-collection; do
  if [ -d "/srv/$s" ]; then
    echo "=== Updating backend for $s ==="
    cd "/srv/$s"
    git pull
    docker compose restart api
  fi
done
echo "=== All backends updated and restarted ==="
