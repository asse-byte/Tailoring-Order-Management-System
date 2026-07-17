# Ops scripts — provisioning, backup & restore (per shop)

## Provision a whole new shop in one command

```bash
./scripts/new-shop.sh                  # interactive: port, secrets, clone, .env,
                                       # docker, setup-shop, nginx, HTTPS, cron, CSV
./scripts/new-shop.sh --delete <slug>  # tear a test shop down
NEW_SHOP_DRY_RUN=1 ./scripts/new-shop.sh   # rehearse without touching anything
```

Then on the dev machine: `.\scripts\build-shop-app.ps1` builds branded web + APK
for that shop in one command (and restores `gradle.properties` afterwards).
Full flow: `docs/ONBOARDING_NEW_SHOP.md`.

These run **on the VPS**, from a shop's deploy directory (where its
`docker-compose.yml` and `.env` live), e.g. `/srv/rayan-couture`.

A complete backup of a shop is **three things**, and they do not all live in the
same place:

| # | What | Where it lives | Backed up by |
| - | ---- | -------------- | ------------ |
| 1 | PostgreSQL database (clients, orders, finances…) | VPS (db container) | `backup.sh` |
| 2 | `uploads/` images (products, logo) | VPS (uploads volume) | `backup.sh` |
| 3 | Android signing keystore `.jks` + its password | **your dev laptop** | manual (below) |

## Daily database + uploads backup

```bash
cd /srv/<shop>
./scripts/backup.sh          # writes ./backups/db_<stamp>.sql.gz + uploads_<stamp>.tar.gz
```

Automate with cron (3 AM daily):

```bash
crontab -e
# m h  dom mon dow  command
  0 3  *   *   *    cd /srv/rayan-couture && ./scripts/backup.sh >> /var/log/couture-backup.log 2>&1
```

### Off-site copy (do NOT skip)

A backup on the same disk as the database is lost with the server. Configure one
off-site target in `backup.sh` (an `rclone` remote to Google Drive/S3, or `scp`
to another machine) and uncomment those lines.

## Test the restore (do this at least once before the first real shop)

An untested backup is not a backup. This is **safe** — it restores into a
throwaway database and drops it, never touching the live shop:

```bash
cd /srv/<shop>
./scripts/restore.sh backups/db_2026-07-16_030000.sql.gz
```

You should see real row counts (users, clients, orders…). If you do, the backup
is proven restorable.

## Disaster recovery (only when the live DB is actually lost)

Destructive — overwrites the live database, then optionally the uploads:

```bash
cd /srv/<shop>
./scripts/restore.sh --force-into-live backups/db_<stamp>.sql.gz backups/uploads_<stamp>.tar.gz
docker compose restart api
```

## Update every shop at once (after `git push`)

Once a feature/fix is pushed, roll it out to **all** shops on the VPS with one
command. It backs up each shop first, pulls, rebuilds (migrations auto-run on
boot), then health-checks — and keeps going if one shop fails:

```bash
SHOPS_DIR=/srv ./scripts/update-all.sh
```

- One shop failing does not stop the others; a summary lists updated vs FAILED,
  and the script exits non-zero so cron can alert you.
- The web build is separate: rebuild it (`flutter build web …`) and re-copy
  `build/web` per shop only when the UI changed. The APK likewise is rebuilt and
  redistributed only on UI/logic changes (same keystore, higher version).
- Deploy order stays: server first (the API is backward-compatible), app after.

## Backing up the signing keystore (on your laptop, not the VPS)

Losing `rayan-couture-release.jks` or its password means you can **never** ship
an update to any app already installed on a client's phone. Back it up now:

1. Copy `C:/Users/cisse/keystores/rayan-couture-release.jks` to **encrypted**
   off-machine storage (an encrypted USB stick, or a private cloud drive).
2. Store its password in a **password manager** (Bitwarden, 1Password…), not in
   a plaintext file next to the key.
3. Keep a second copy in a different physical place. Treat it like the master
   key to your whole product — because it is.
