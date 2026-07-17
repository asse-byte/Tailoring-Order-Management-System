#!/usr/bin/env bash
# Restore / verify a backup produced by scripts/backup.sh.
#
# Two modes:
#
#   TEST (default, SAFE — does not touch the live shop):
#     ./scripts/restore.sh backups/db_2026-07-16_030000.sql.gz
#   Loads the dump into a throwaway database, prints table row counts so you can
#   confirm the backup is real and restorable, then drops it. Run this at least
#   ONCE before opening a real shop — an untested backup is not a backup.
#
#   DISASTER RECOVERY (destructive — overwrites the live database):
#     ./scripts/restore.sh --force-into-live backups/db_… [backups/uploads_…tar.gz]
#
set -euo pipefail

DB_USER="${DB_USER:-couture}"
DB_NAME="${DB_NAME:-couture_mali}"

cd "$(dirname "$0")/.."

FORCE=0
if [ "${1:-}" = "--force-into-live" ]; then FORCE=1; shift; fi
DB_DUMP="${1:?path to db_*.sql.gz required}"
UP_ARCHIVE="${2:-}"
[ -f "$DB_DUMP" ] || { echo "no such file: $DB_DUMP" >&2; exit 1; }

if [ "$FORCE" -eq 0 ]; then
  # ---- SAFE test restore into a temporary database ----
  TMPDB="couture_verify_$$"
  echo "[test] Creating throwaway database $TMPDB…"
  docker compose exec -T db createdb -U "$DB_USER" "$TMPDB"
  trap 'docker compose exec -T db dropdb -U "$DB_USER" "$TMPDB" >/dev/null 2>&1 || true' EXIT

  echo "[test] Loading dump…"
  gunzip -c "$DB_DUMP" | docker compose exec -T db psql -q -U "$DB_USER" -d "$TMPDB" >/dev/null

  echo "[test] Row counts in the restored copy:"
  docker compose exec -T db psql -U "$DB_USER" -d "$TMPDB" -c \
    "SELECT relname AS table, n_live_tup AS rows
       FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 12;"
  echo "✅ Backup is restorable. Temporary database dropped automatically."
  exit 0
fi

# ---- DISASTER RECOVERY into the live database ----
echo "⚠️  This OVERWRITES the LIVE database of the shop in $(pwd)."
read -r -p "Type 'yes' to proceed: " ok
[ "$ok" = "yes" ] || { echo "Aborted."; exit 1; }

echo "Restoring database…"
gunzip -c "$DB_DUMP" | docker compose exec -T db psql -q -U "$DB_USER" -d "$DB_NAME" >/dev/null

if [ -n "$UP_ARCHIVE" ]; then
  [ -f "$UP_ARCHIVE" ] || { echo "no such uploads archive: $UP_ARCHIVE" >&2; exit 1; }
  echo "Restoring uploads…"
  API_CID="$(docker compose ps -q api)"
  docker run --rm --volumes-from "$API_CID" -v "$(pwd):/host" alpine \
    sh -c "cd /app && tar xzf /host/$UP_ARCHIVE"
fi

echo "✅ Restore complete. Recommended: docker compose restart api"
