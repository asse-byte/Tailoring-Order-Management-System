# API Reference — CouturePro (Tailoring Shop Management)

REST API for the tailoring-shop app. Node.js + Express + PostgreSQL, one
isolated instance per shop. All responses are JSON. Money is **FCFA/XOF
integers** (no decimals). Error messages are in **French** (returned as
`{ "error": "..." }`).

- **Base URL (prod):** `https://api.<shop>.<domain>` (e.g. `https://api.rayan-couture.couturepro.app`)
- **Base URL (local):** `http://localhost:3000`
- **Auth:** `Authorization: Bearer <JWT>` on every route except the two public ones.
- **Content type:** `application/json` (except `POST /api/upload`, multipart).

---

## Authentication & roles

Login returns a JWT valid **12h**. The token carries only the user id — **the
role is re-read from the `users` table on every request**, so a tampered or
stale token can never elevate access.

Two roles only:

| Role | Meaning | Access |
| --- | --- | --- |
| `MANAGER` | le Gérant | Everything, including all finance. |
| `SECRETARY` | la Secrétaire | Daily operations only. **Every `[FINANCE]` route returns `403`.** Never sees profits, revenues, expenses, wages, salaries. |

Financial isolation is enforced server-side (route middleware backed by DB
constraints), and proven by `backend/tests/security.test.js`. Any of the 8
`[FINANCE]` mounts returns `403` to the secretary.

### Status codes

| Code | When |
| --- | --- |
| `200` / `201` / `204` | Success (204 = deleted, no body) |
| `400` | Bad input / invalid value / check violation |
| `401` | Missing, invalid or expired token; wrong credentials |
| `403` | Authenticated but role not allowed (secretary on finance) |
| `404` | Unknown route or record |
| `409` | Duplicate (unique), linked-data conflict (FK), or **append-only** trigger block |
| `429` | Login rate limit exceeded |
| `500` | Internal error |

---

## Append-only financial model (important)

Financial history is **append-only**: `tailor_daily_entries`, `sales`,
`expenses`, `salary_payments`, `order_items` and their `*_corrections`. These
tables **cannot be updated or deleted** — a DB trigger raises (`409`). The only
way to change a number is to **POST a correction** (a new row with a mandatory
`reason`); the effective value is the latest correction. Every revenue/cost sum
reads the `*_effective` SQL views.

Master/identity data (`staff`, `clients`, `products`, `pret_a_porter_models`,
settings) supports **full manager edit + hard delete**; historical rows keep a
name **snapshot** so reports survive the deletion. See `CLAUDE.md` (Type-A vs
Type-B).

---

## Public endpoints (no token)

### `POST /api/auth/login`
Rate-limited. Body:
```json
{ "username": "gerant", "password": "..." }
```
`200` →
```json
{ "token": "<jwt>", "user": { "id": "...", "username": "gerant", "name": "Le Gérant", "role": "MANAGER" } }
```
`401` on bad credentials, `429` if too many attempts.

### `GET /api/settings/public`
Shop identity for the login screen (no auth). →
```json
{ "shop_name": "Rayan Couture", "logo_url": null, "promo_group_link": "...", "theme_color": "#0F766E" }
```

---

## Session (any authenticated user)

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/auth/me` | Fresh current user (role from DB). |
| `POST` | `/api/auth/change-password` | Body `{ current_password, new_password?, new_username? }`. Requires the current password. |

---

## Clients — `both roles` (delete: manager)

| Method | Path | Role | Notes |
| --- | --- | --- | --- |
| `GET` | `/api/clients` | both | Query `q` (name/phone search), `limit`, `offset`. |
| `POST` | `/api/clients` | both | Body `{ full_name, phone?, address?, gender? }`. |
| `GET` | `/api/clients/:id` | both | |
| `PUT` | `/api/clients/:id` | both | Same body as POST. |
| `DELETE` | `/api/clients/:id` | **manager** | Hard delete; past orders kept in Historique via `client_name_snapshot`. |
| `GET` | `/api/clients/:id/measurements` | both | Flexible per-garment measurements. |
| `PUT` | `/api/clients/:id/measurements/:garmentType` | both | Body `{ measures: { ... } }`. |
| `DELETE` | `/api/clients/:id/measurements/:garmentType` | both | |
| `GET` | `/api/clients/:id/orders` | both | Client order history (derived totals). |
| `GET` | `/api/clients/settings/custom-garments` | both | Custom garment catalogue. |
| `PUT` | `/api/clients/settings/custom-garments` | both | |

## Orders (Commandes) — `both roles` (delete: manager)

Order total is **derived** from effective line items (voided lines = 0). Status
enum: `en_attente → en_cours → termine → livre`. Marking `livre` moves it to
Historique.

| Method | Path | Role | Notes |
| --- | --- | --- | --- |
| `GET` | `/api/orders` | both | Query `status`, `q`, `limit`, `offset`. |
| `POST` | `/api/orders` | both | Body `{ client_id, items:[{garment_type, quantity, unit_price}], tailor_id?, advance?, fabric?, expected_date?, status?, notes? }`. |
| `GET` | `/api/orders/:id` | both | Full order + line items. |
| `PUT` | `/api/orders/:id` | both | Header fields + status transitions. |
| `PUT` | `/api/orders/:id/plan` | both | Set `planned_date`. |
| `POST` | `/api/orders/:id/items` | both | Append a line item (append-only). |
| `POST` | `/api/orders/:id/items/:itemId/corrections` | both | Body `{ new_quantity, new_unit_price, voided?, reason }`. |
| `GET` | `/api/orders/:id/items/:itemId/corrections` | both | Correction history. |
| `DELETE` | `/api/orders/:id` | **manager** | |

## Appointments (Rendez-vous) — `both roles`

Merged read-only view (manual appointments ∪ active orders' delivery dates).

| Method | Path | Role |
| --- | --- | --- |
| `GET` | `/api/appointments` | both |
| `POST` | `/api/appointments` | both |
| `PUT` | `/api/appointments/:id` | both |
| `DELETE` | `/api/appointments/:id` | both |

## Products (Produits) — `read: both, writes: manager`

| Method | Path | Role | Notes |
| --- | --- | --- | --- |
| `GET` | `/api/products` | both | Query `category` (`parfum`/`chaussure`/`tissu`), `q`, pagination. |
| `POST` | `/api/products` | **manager** | Body `{ category, name, price, quantity?, cost_price?, low_stock_threshold? }`. |
| `PUT` | `/api/products/:id` | **manager** | |
| `DELETE` | `/api/products/:id` | **manager** | Sales keep `item_name` snapshot. |
| `GET` | `/api/products/:id/stats` | **manager** | `[FINANCE]`-style: sales stats. |

## Prêt-à-porter (ready-to-wear) — `read: both, writes: manager`

| Method | Path | Role |
| --- | --- | --- |
| `GET` | `/api/pret-a-porter` | both |
| `POST` | `/api/pret-a-porter` | **manager** |
| `PUT` | `/api/pret-a-porter/:id` | **manager** |
| `DELETE` | `/api/pret-a-porter/:id` | **manager** |
| `GET` | `/api/pret-a-porter/:id/stats` | **manager** |

## Sales — `create: both, reads: manager` (write-only for secretary)

Sales are **atomic and server-priced**: the server reads the price from the DB,
computes the total, and decrements stock in one transaction. The client never
sends prices.

| Method | Path | Role | Notes |
| --- | --- | --- | --- |
| `POST` | `/api/sales` | both | Body `{ kind: "produit"\|"pret_a_porter", item_id, qty }`. Secretary gets `{ ok: true, id }`; manager gets the full row. |
| `GET` | `/api/sales` | **manager** | Effective view (corrections applied). |
| `POST` | `/api/sales/:id/corrections` | **manager** | Body `{ new_qty?, voided?, reason }`. Adjusts stock by the delta. |
| `GET` | `/api/sales/:id/corrections` | **manager** | |

## Staff — `read: both (contact only), writes: manager`

| Method | Path | Role | Notes |
| --- | --- | --- | --- |
| `GET` | `/api/staff` | both | Names/contacts only — **no pay data**. |
| `POST` | `/api/staff` | **manager** | Body `{ full_name, phone?, type: "couturier"\|"autre" }`. |
| `PUT` | `/api/staff/:id` | **manager** | Also toggles `active`. |
| `DELETE` | `/api/staff/:id` | **manager** | Hard delete; wage history kept via `tailor_name_snapshot`. |

## Upload — `both roles`

| Method | Path | Role | Notes |
| --- | --- | --- | --- |
| `POST` | `/api/upload` | both | `multipart/form-data`, field `file`. Re-encodes images + generates thumbnails. Returns `{ url, thumb_url }`. |
| `GET` | `/uploads/<file>` | public static | Served with nosniff + sandbox CSP. |

---

## `[FINANCE]` — MANAGER ONLY (secretary → `403` on all of these)

### Staff pay — `/api/staff-pay`
| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/staff-pay` | Current rates/salaries per staff. |
| `PUT` | `/api/staff-pay/:staffId` | Body `{ piece_rate?, monthly_salary?, salary_due_day? }`. Journals the change to `staff_pay_history`. |
| `GET` | `/api/staff-pay/:staffId/history` | Pay-rate change history (append-only). |

### Tailor daily entries — `/api/tailor-entries`
Piece-rate work log. Append-only; corrections change quantity, garment type
(model) and/or price-per-piece, or void the entry.

| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/api/tailor-entries` | Body `{ tailor_id, entry_date, pieces_count, piece_rate?, garment_type?, order_id? }`. Several per day allowed. |
| `GET` | `/api/tailor-entries` | Query `tailor_id`. Effective values. |
| `GET` | `/api/tailor-entries/weekly-detail` | Query `week_id` (ISO `YYYY-Www`), `tailor_id`. Full week + total. |
| `GET` | `/api/tailor-entries/weekly` | Query `week_id`. Per-tailor weekly totals. |
| `GET` | `/api/tailor-entries/monthly` | Query `month` (`YYYY-MM`). Ranking. |
| `POST` | `/api/tailor-entries/:id/corrections` | Body `{ new_pieces?, new_piece_rate?, new_garment_type?, voided?, reason }` (any subset; `reason` required). |
| `GET` | `/api/tailor-entries/:id/corrections` | Correction history. |

### Salary payments — `/api/salary-payments`
Disbursement ledger (documentation only; does not feed net-profit).

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/salary-payments` | Query `period`, `kind`. |
| `POST` | `/api/salary-payments` | Body `{ staff_id, period, kind: "mensuel"\|"hebdo", amount, paid_at?, note? }`. |
| `POST` | `/api/salary-payments/:id/corrections` | Body `{ new_amount?, voided?, reason }`. |
| `GET` | `/api/salary-payments/:id/corrections` | |

### Expenses — `/api/expenses`
| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/api/expenses` | Body `{ reason, amount, spent_at? }`. |
| `GET` | `/api/expenses` | Query `from`, `to`, pagination. Effective values. |
| `POST` | `/api/expenses/:id/corrections` | Body `{ new_amount?, new_reason?, voided?, reason }`. |
| `GET` | `/api/expenses/:id/corrections` | |

### Finance summary — `/api/finance`
`GET /api/finance/summary?from=YYYY-MM-DD&to=YYYY-MM-DD` (defaults: month-to-date).
→
```json
{
  "from": "2026-07-01",
  "to": "2026-07-31",
  "months_counted": 1,
  "revenue": { "sales": 0, "orders": 0, "total": 0 },
  "costs":   { "cost_of_goods_sold": 0, "tailor_wages": 0, "salaries": 0, "expenses": 0, "total": 0 },
  "net_profit": 0
}
```
`net_profit = revenue.total − costs.total`. `revenue.orders` counts delivered
orders; monthly salaries are prorated to the window. All sums read the
effective views.

### Reports — `/api/reports`
`GET /api/reports/summary?from=...&to=...` — richer breakdown per category.

### Settings (private) — `/api/settings/private`
| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/settings/private` | All settings (public + private). |
| `PUT` | `/api/settings/private` | Body may include `shop_name`, `logo_url`, `default_piece_rate`, `promo_group_link`, `theme_color` (`#RRGGBB`). |

### Users — `/api/users`
| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/users` | The two accounts. |
| `POST` | `/api/users` | Create/seed an account. |
| `PUT` | `/api/users/:id/password` | Reset a password. |
| `DELETE` | `/api/users/:id` | |

---

## Notes for clients (apps/integrations)

- **Always send prices? No.** Sales and order totals are computed server-side.
- **Pagination everywhere:** long lists accept `limit` (default 20–50, max
  100–200) and `offset`. Never rely on an unbounded list.
- **Dates:** `YYYY-MM-DD`. Weeks: ISO `YYYY-Www`. Months: `YYYY-MM`.
- **Corrections, not edits:** to change any financial number, POST a correction
  with a `reason`; a direct UPDATE/DELETE returns `409` (append-only).
- See `backend/tests/` for executable, always-passing examples of every rule,
  and `api.http` for ready-to-run requests.
