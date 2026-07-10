# Couture Mali — API (Express + PostgreSQL)

REST backend for the tailoring shop app. Two roles only — `MANAGER`
(le Gérant) and `SECRETARY` (la Secrétaire) — with financial isolation
enforced server-side and at the database level. See `../docs/DATA_MODEL.md`
for the schema and role matrix, and `../CLAUDE.md` for the closed
architecture decisions.

## Local development (no Docker needed)

```bash
npm install
npm test          # boots a real embedded PostgreSQL, runs the security suite
```

To run the API locally you need a `DATABASE_URL` (any reachable Postgres)
in `.env` (copy `.env.example`), then:

```bash
npm run migrate
npm run seed      # creates the two accounts from SEED_* env vars (once)
npm start
```

## Account recovery (locked-out manager)

There is **no self-service password reset** in the app, by design: the only
way to reset a password is to have access to the server. If the manager
forgets their password, username, or both, use the recovery script. It reads
`DATABASE_URL` if set, otherwise the local dev database — so keep the DB
running (`npm run dev`, or the API up) in another terminal.

```bash
# List every account — recover a forgotten USERNAME
npm run reset-password -- --list

# Set a new password (min 8 chars) for a username
npm run reset-password -- gerant NouveauPass#2026

# Also rename the account while resetting
npm run reset-password -- gerant NouveauPass#2026 --rename patron
```

> The `--` after `npm run reset-password` is required so npm forwards the
> arguments to the script.

On the production droplet, run it inside the API container:

```bash
docker compose exec api npm run reset-password -- --list
docker compose exec api npm run reset-password -- gerant NouveauPass#2026
```

## Deployment (DigitalOcean VPS, Docker Compose — same pattern as EduGete)

```bash
# on the droplet, inside backend/
cp .env.example .env        # set DB_PASSWORD, JWT_SECRET, SEED_* values
docker compose up -d --build
docker compose exec api node scripts/seed.js   # first run only
```

The API listens on `127.0.0.1:3000` — put nginx (with TLS) in front:

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

### Backups (non-negotiable for financial data)

Nightly dump via cron on the droplet:

```bash
docker compose exec -T db pg_dump -U couture couture_mali | gzip \
  > /root/backups/couture_$(date +%F).sql.gz
```

Keep at least 14 days; copy off-server (e.g. DO Spaces or rclone) weekly.

## Security invariants (tested in `tests/security.test.js`)

- Every financial route returns **403** for the secretary: sales reads,
  expenses, staff pay, tailor daily entries, finance summary, private
  settings, user management.
- Sales are **server-priced** (client prices are ignored) and decrement
  stock **atomically** in the same transaction.
- `tailor_daily_entries`, `expenses` and their correction tables are
  **append-only at the DB level** (triggers) — corrections with a
  mandatory reason are the only way to change a number; the full history
  (who, when, from → to, why) is preserved forever.
- JWT carries only the user id; the **role is read from the DB on every
  request** — a forged role claim does nothing.
- No self-registration: accounts exist only via the seed script or the
  manager-only `/api/users` routes.

Run `npm test` before every deploy; the suite must stay green.
