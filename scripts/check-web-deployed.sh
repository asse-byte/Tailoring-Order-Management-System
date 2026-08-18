#!/usr/bin/env bash
for w in /var/www/*; do
  if [ -d "$w" ]; then
    echo "=== $w ==="
    grep -i 'title>' "$w/index.html" 2>/dev/null || true
    cat "$w/manifest.json" 2>/dev/null || true
    echo ""
  fi
done
