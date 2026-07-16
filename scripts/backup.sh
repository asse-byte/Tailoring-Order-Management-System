#!/usr/bin/env bash
# Per-shop backup — PostgreSQL dump + uploads volume, timestamped and rotated.
#
# Runs ON THE VPS, from a shop's deploy directory (where docker-compose.yml and
# .env live), e.g.:
#     cd /srv/rayan-couture && ./scripts/backup.sh
#
# Schedule it daily with cron (see scripts/README.md). Backs up the TWO things
# that live on the server: the database and the uploaded images. The signing
# keystore (.jks) lives on your dev laptop, NOT here — back it up separately
# (also documented in scripts/README.md).
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"          # delete local backups older than this many days
DB_USER="${DB_USER:-couture}"
DB_NAME="${DB_NAME:-couture_mali}"
STAMP="$(date +%Y-%m-%d_%H%M%S)"

cd "$(dirname "$0")/.."               # run from the compose directory
mkdir -p "$BACKUP_DIR"

echo "[1/3] Dumping database ($DB_NAME)…"
# --clean --if-exists makes the dump self-restoring (drops then recreates);
# --no-owner keeps it portable across environments.
docker compose exec -T db pg_dump -U "$DB_USER" --clean --if-exists --no-owner "$DB_NAME" \
  | gzip > "$BACKUP_DIR/db_${STAMP}.sql.gz"

echo "[2/3] Archiving uploads volume…"
# --volumes-from the api container gives us its /app/uploads mount without
# needing to know the project-prefixed volume name.
API_CID="$(docker compose ps -q api)"
if [ -z "$API_CID" ]; then
  echo "  ! api container not running — cannot archive uploads." >&2
  exit 1
fi
docker run --rm --volumes-from "$API_CID" \
  -v "$(pwd)/$BACKUP_DIR:/backup" alpine \
  tar czf "/backup/uploads_${STAMP}.tar.gz" -C /app uploads

echo "[3/3] Rotating local backups older than ${KEEP_DAYS} days…"
find "$BACKUP_DIR" -name 'db_*.sql.gz'      -mtime +"$KEEP_DAYS" -delete
find "$BACKUP_DIR" -name 'uploads_*.tar.gz' -mtime +"$KEEP_DAYS" -delete

# --- OFF-SITE COPY (critical: a backup on the same disk is not a backup) ------
# Configure ONE of the following, then uncomment it. A backup that never leaves
# the VPS is lost with the VPS.
#
#   rclone (to Google Drive / S3 / etc. — run `rclone config` once):
# rclone copy "$BACKUP_DIR/db_${STAMP}.sql.gz"      "${RCLONE_REMOTE:?set RCLONE_REMOTE}"
# rclone copy "$BACKUP_DIR/uploads_${STAMP}.tar.gz" "${RCLONE_REMOTE}"
#
#   or scp to another machine you control:
# scp "$BACKUP_DIR/db_${STAMP}.sql.gz" "$BACKUP_DIR/uploads_${STAMP}.tar.gz" user@host:/backups/

echo "✅ Backup done: $BACKUP_DIR/db_${STAMP}.sql.gz + uploads_${STAMP}.tar.gz"
echo "   Remember: enable the off-site copy above, and back up the .jks separately."
