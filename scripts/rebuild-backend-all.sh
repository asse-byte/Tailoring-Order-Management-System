#!/usr/bin/env bash
set -e
for s in 72-couture demo-couture rayan-couture yatt-services lah-collection; do
  if [ -d "/srv/$s" ]; then
    echo "=== Building backend for $s ==="
    cd "/srv/$s"
    git pull
    docker compose up -d --build api
  fi
done
echo "=== All backends rebuilt and active ==="
