# Couture Mali — PostgreSQL Data Model

Status: **approved 2026-07-05** (supersedes the earlier Firestore draft).
Backend: Node.js + Express + PostgreSQL (`backend/`). Roles: `MANAGER`
(le Gérant) and `SECRETARY` (la Secrétaire). Money is FCFA/XOF stored as
**integers** — no decimals, ever.

🔒 = financial: every route touching it is MANAGER-only (403 for the
secretary), verified by `backend/tests/security.test.js`.

The authoritative DDL lives in `backend/migrations/`; this document is the
readable map.

---

## Tables

### users
| column | type | notes |
|---|---|---|
| id | uuid PK | `gen_random_uuid()` |
| username | text UNIQUE | login identifier (may be an email) |
| password_hash | text | bcryptjs |
| name | text | display name |
| role | text CHECK (`MANAGER`,`SECRETARY`) | |
| created_at | timestamptz | |

No self-registration: accounts come from the seed script or the
manager-only `POST /api/users`. Role is read from this table on **every**
request — a tampered JWT cannot elevate privileges.

### clients
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| full_name | text | |
| phone | text | |
| address | text NULL | |
| created_at | timestamptz | |

Indexes: `lower(full_name) text_pattern_ops` (prefix search),
`phone`. List endpoints are paginated (default 20, max 100).

### client_measurements
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| client_id | uuid FK → clients ON DELETE CASCADE | |
| garment_type | text | boubou, chemise, pantalon, custom… |
| "values" | jsonb | flexible key→number map (épaule, poitrine…) |
| updated_at | timestamptz | |
| UNIQUE (client_id, garment_type) | | one sheet per garment type |

### products
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| category | text CHECK (`parfum`,`chaussure`,`tissu`) | |
| name | text | |
| price | integer CHECK ≥ 0 | sale price — visible to secretary |
| quantity | integer CHECK ≥ 0 | stock; DB constraint prevents negatives |
| low_stock_threshold | integer default 3 | manager alert |
| created_at | timestamptz | |

Writes are manager-only. The secretary never touches quantity directly —
stock only moves inside the sale transaction.

### product_images / model_media
`(id, product_id|model_id FK, url, thumb_url)` — media stored on the VPS
disk (served by nginx), thumbnails generated at upload for fast lists.

### 🔒 sales
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| kind | text CHECK (`produit`,`pret_a_porter`) | |
| item_id | uuid | product or model |
| item_name | text | snapshot at sale time |
| qty | integer CHECK > 0 | |
| unit_price | integer | **read from DB by the server** — never from the client |
| total | integer | computed server-side = qty × unit_price |
| sold_at | timestamptz | |
| created_by | uuid FK → users | |

`POST /api/sales` (both roles): single transaction —
`SELECT price … FOR UPDATE` → `UPDATE products SET quantity = quantity - qty
WHERE quantity >= qty` (409 if insufficient) → `INSERT sale`. Atomic: stock
and revenue can never disagree. `GET /api/sales` is manager-only.

### staff — contact info only (secretary may read)
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| full_name | text | |
| phone | text | |
| type | text CHECK (`couturier`,`autre`) | |
| joined_at | date | |
| active | boolean default true | |

### 🔒 staff_pay
| column | type | notes |
|---|---|---|
| staff_id | uuid PK, FK → staff | same id as staff row |
| piece_rate | integer NULL | couturiers: FCFA per piece (falls back to settings default) |
| monthly_salary | integer NULL | non-couturiers |
| salary_due_day | integer NULL | day of month |

### 🔒 tailor_daily_entries — APPEND-ONLY
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| tailor_id | uuid FK → staff | |
| entry_date | date | |
| pieces_count | integer CHECK ≥ 0 | |
| piece_rate | integer | snapshot of the rate that day |
| amount | integer GENERATED ALWAYS AS (pieces_count × piece_rate) STORED | DB computes it — cannot be forged |
| week_id | text | ISO `YYYY-Www`, computed by the API |
| created_by | uuid FK → users | |
| created_at | timestamptz | |
| UNIQUE (tailor_id, entry_date) | | one entry per tailor per day |

**A `BEFORE UPDATE OR DELETE` trigger raises an exception** — even a
direct SQL session cannot alter history. Mistakes are fixed via
corrections:

### 🔒 entry_corrections — APPEND-ONLY (the audit trail)
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| entry_id | uuid FK → tailor_daily_entries | |
| old_pieces | integer | snapshot at correction time |
| new_pieces | integer CHECK ≥ 0 | |
| reason | text NOT NULL, CHECK non-empty | **mandatory** — the "why" |
| corrected_by | uuid FK → users | |
| corrected_at | timestamptz | |

Also trigger-protected against UPDATE/DELETE. The **effective** value is
the latest correction if any, else the original — via view
`tailor_entries_effective` (used by all weekly totals and finance sums).
The manager UI shows the current number + an openable history:
who, when, from → to, and why.

### 🔒 expenses — APPEND-ONLY, same pattern
`(id, reason text, amount integer ≥ 0, spent_at date, created_by,
created_at)` + trigger. Corrections in **expense_corrections**
`(id, expense_id FK, new_amount NULL, new_reason NULL, voided boolean
default false, reason NOT NULL, corrected_by, corrected_at)` — a wrong
expense is *voided* with a reason, never deleted. Effective view:
`expenses_effective` (latest correction wins; voided rows excluded from
sums but still visible in history).

### pret_a_porter_models
`(id, name, fabric_type, price integer, created_at)` — reads for both
roles (secretary sells at the counter), writes manager-only.

### orders
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| client_id | uuid FK → clients | |
| garment_type | text | |
| fabric | text | |
| measurements_snapshot | jsonb | copied from the client file at order time |
| price | integer | what the client pays — secretary invoices at the counter |
| advance | integer default 0 | acompte |
| start_date | date | |
| expected_date | date | |
| delivered_date | date NULL | set when status → `livre` |
| status | text CHECK (`en_cours`,`pret`,`livre`) | |
| notes | text NULL | |
| created_at | timestamptz | |

Historique = `WHERE status = 'livre'` — a status change *moves* the
order; nothing is copied, no detail is lost. Both roles CRUD;
DELETE is manager-only. Indexes: `(status, expected_date)`,
`(client_id, created_at DESC)`, `(status, delivered_date DESC)`.

### appointments
`(id, client_id FK, scheduled_at timestamptz, reason CHECK
(mesure, essayage, livraison, autre), notes NULL)` — both roles CRUD.
Index on `scheduled_at`.

### settings
Key-value: `(key text PK, value jsonb, is_public boolean)`.
Public rows (`shop_name`, `logo_url`) are served by
`GET /api/settings/public` **without auth** (login screen).
Private rows (🔒 `default_piece_rate`) are manager-only.

---

## API role matrix (deny-by-default)

Every route mount declares its allowed roles explicitly; anything not
mounted is 404, anything unauthenticated is 401.

| Route | SECRETARY | MANAGER |
|---|---|---|
| `POST /api/auth/login`, `GET /api/settings/public` | public | public |
| `/api/clients*`, `/api/orders*`, `/api/appointments*` | full CRUD (order DELETE: no) | full |
| `GET /api/products`, `GET /api/pret-a-porter` | ✅ read | full |
| `POST /api/products`, PUT/DELETE | ❌ 403 | ✅ |
| `POST /api/sales` | ✅ (server-priced, atomic) | ✅ |
| `GET /api/sales` 🔒 | ❌ 403 | ✅ |
| `GET /api/staff` | ✅ contacts only | ✅ |
| staff writes, `/api/staff-pay*` 🔒 | ❌ 403 | ✅ |
| `/api/tailor-entries*` 🔒 (+corrections) | ❌ 403 | ✅ (no UPDATE/DELETE anywhere) |
| `/api/expenses*` 🔒 (+corrections) | ❌ 403 | ✅ (append-only) |
| `/api/finance/summary` 🔒 | ❌ 403 | ✅ |
| `/api/settings/private` 🔒 | ❌ 403 | ✅ |
| `/api/users*` | ❌ 403 | ✅ |

## Test plan (non-negotiable, ports the 29 Firestore-rules tests)

`backend/tests/security.test.js` — Jest + Supertest against a real
PostgreSQL (embedded-postgres locally, the compose DB in CI/VPS):

- every 🔒 route returns **403** with a valid secretary token;
- secretary daily operations succeed (clients, measurements, orders,
  appointments, product reads, sale creation);
- sale with forged price/total in the body is ignored (server prices);
  sale with qty > stock → 409 and stock unchanged;
- tailor entry `amount` is DB-computed; UPDATE/DELETE on entries,
  corrections and expenses raise even in direct SQL (trigger tests);
- corrections require a non-empty reason; effective views return the
  corrected value while originals stay intact;
- unauthenticated: only `settings/public` and login reachable;
- JWT signed with the wrong secret, or for a deleted user → 401;
  role in the token payload is ignored (DB is the source of truth).
