#!/usr/bin/env bash
# Update EVERY shop deployment on this VPS in one run:
#   safety backup → git pull → rebuild (migrations auto-run) → health check.
#
# Runs on the VPS. Each shop is a subdirectory of SHOPS_DIR that contains its
# own docker-compose.yml (its own clone + .env + volumes), e.g. /srv/rayan-couture.
#
#   SHOPS_DIR=/srv ./scripts/update-all.sh
#
# One shop failing does NOT stop the others; a summary is printed at the end and
# the script exits non-zero if any shop failed (so cron can alert you).
#
# Env:
#   SHOPS_DIR    base directory holding the shop folders (default /srv)
#   SKIP_BACKUP  set to 1 to skip the pre-update backup (not recommended)
set -uo pipefail   # deliberately NOT -e: keep going past a failing shop

SHOPS_DIR="${SHOPS_DIR:-/srv}"
SKIP_BACKUP="${SKIP_BACKUP:-0}"

ok=(); failed=()

for dir in "$SHOPS_DIR"/*/; do
  [ -f "${dir}docker-compose.yml" ] || continue
  shop="$(basename "$dir")"
  echo "═══════════ $shop ═══════════"
  (
    cd "$dir" || exit 1

    # 1) Safety backup BEFORE any migration runs (skippable but discouraged).
    if [ "$SKIP_BACKUP" != "1" ] && [ -x ./scripts/backup.sh ]; then
      echo "  • backup…"
      ./scripts/backup.sh >/dev/null || { echo "  ! backup failed — skipping this shop"; exit 1; }
    fi

    # 2) Pull latest code. .env and named volumes are untracked → preserved.
    #    --ff-only refuses to create surprise merges if the clone diverged.
    echo "  • git pull…"
    git pull --ff-only || { echo "  ! git pull failed"; exit 1; }

    # 3) Rebuild + restart. The api image's CMD runs migrations on boot
    #    (idempotent), so a schema change is applied here automatically.
    echo "  • rebuild + restart…"
    docker compose up -d --build || { echo "  ! docker compose up failed"; exit 1; }

    # 4) Health check on this shop's own port (from its .env).
    port="$(grep -E '^API_PORT=' .env 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"
    port="${port:-3000}"
    sleep 5
    if curl -fsS "http://localhost:${port}/api/settings/public" >/dev/null 2>&1; then
      echo "  ✅ healthy on :$port"
    else
      echo "  ! health check failed on :$port (check: docker compose logs api)"; exit 1
    fi
  )
  if [ $? -eq 0 ]; then ok+=("$shop"); else failed+=("$shop"); fi
done

echo
echo "═══════════ Summary ═══════════"
echo "  updated: ${ok[*]:-none}"
echo "  FAILED : ${failed[*]:-none}"
[ "${#failed[@]}" -eq 0 ]
