# Ops scripts — backup & restore (per shop)

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

## Backing up the signing keystore (on your laptop, not the VPS)

Losing `rayan-couture-release.jks` or its password means you can **never** ship
an update to any app already installed on a client's phone. Back it up now:

1. Copy `C:/Users/cisse/keystores/rayan-couture-release.jks` to **encrypted**
   off-machine storage (an encrypted USB stick, or a private cloud drive).
2. Store its password in a **password manager** (Bitwarden, 1Password…), not in
   a plaintext file next to the key.
3. Keep a second copy in a different physical place. Treat it like the master
   key to your whole product — because it is.
