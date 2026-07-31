# Syncs custom logo icons for each deployed shop on the server if present in DB/uploads,
# or sets generic neutral icons.
param(
    [string]$Server = $env:COUTURE_SERVER
)
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Serveur non defini."
}

Write-Host "=== Syncing shop logos on $Server ===" -ForegroundColor Cyan

$sh = @'
for d in /srv/*/; do
  s=$(basename "$d")
  [ -f "$d/docker-compose.yml" ] || continue
  
  CONTAINER="${s}-api-1"
  DB_CONTAINER="${s}-db-1"
  
  # Find Nginx root for this shop
  port=$(grep -m1 "^API_PORT=" "$d/.env" | cut -d= -f2 | tr -d " \t\r")
  [ -n "$port" ] || continue
  conf=$(grep -rl "127\.0\.0\.1:$port" /etc/nginx/sites-enabled/ 2>/dev/null | head -1)
  [ -n "$conf" ] || conf=$(grep -rl "127\.0\.0\.1:$port" /etc/nginx/sites-available/ 2>/dev/null | head -1)
  [ -n "$conf" ] || continue
  
  ROOT=$(grep -m1 -E "^[[:space:]]*root[[:space:]]" "$conf" | sed "s/.*root[[:space:]]*//; s/;.*//" | tr -d " \r")
  [ -n "$ROOT" ] || continue
  [ -d "$ROOT" ] || continue
  
  if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    LOGO_FILE=$(docker exec "$DB_CONTAINER" psql -U couture -d couture_mali -t -A -c "SELECT value FROM settings WHERE key = 'logo_url';" 2>/dev/null | tr -d '"\r\n' || true)
    if [ -n "$LOGO_FILE" ] && [ "$LOGO_FILE" != "null" ]; then
      FILE_NAME=$(basename "$LOGO_FILE")
      if [ -n "$FILE_NAME" ]; then
        docker cp "${CONTAINER}:/app/uploads/$FILE_NAME" /tmp/shop_logo.img 2>/dev/null || true
        if [ -f /tmp/shop_logo.img ]; then
          cp /tmp/shop_logo.img "$ROOT/icons/Icon-192.png" 2>/dev/null || true
          cp /tmp/shop_logo.img "$ROOT/icons/Icon-512.png" 2>/dev/null || true
          cp /tmp/shop_logo.img "$ROOT/icons/Icon-maskable-192.png" 2>/dev/null || true
          cp /tmp/shop_logo.img "$ROOT/icons/Icon-maskable-512.png" 2>/dev/null || true
          cp /tmp/shop_logo.img "$ROOT/favicon.png" 2>/dev/null || true
          cp /tmp/shop_logo.img "$ROOT/apple-touch-icon.png" 2>/dev/null || true
          rm -f /tmp/shop_logo.img
          chmod -R o+rX "$ROOT"
          echo "Synced logo for $s in $ROOT"
        fi
      fi
    fi
  fi
done
'@

# Save temporary remote script
$tmpSh = Join-Path $env:TEMP 'sync-logos-remote.sh'
$lf = $sh.Replace("`r`n", "`n").Replace("`r", "`n")
[IO.File]::WriteAllText($tmpSh, $lf, (New-Object Text.UTF8Encoding $false))

try {
    & scp $tmpSh "${Server}:/tmp/sync-logos-remote.sh"
    & ssh $Server "bash /tmp/sync-logos-remote.sh; rm -f /tmp/sync-logos-remote.sh"
}
finally {
    Remove-Item -Force $tmpSh -ErrorAction SilentlyContinue
}
