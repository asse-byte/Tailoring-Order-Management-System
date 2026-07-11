# CLAUDE.md — Rayan Couture (Tailoring Shop Management App)

Mobile app to manage a large tailoring shop in Mali (Rayan Couture). App UI language is **French**
(all labels, buttons, error messages, and PDF reports). Currency is **FCFA / XOF, no decimals**.
The user communicates in Arabic; reply to them in Arabic unless asked otherwise.

## Non-negotiable rules

1. **Two operating users only**: `MANAGER` (le Gérant — full access to everything)
   and `SECRETARY` (la Secrétaire — must NEVER see any financial data: profits,
   revenues, expenses, tailor piece-rates/wages, staff salaries).
2. **Financial isolation must be enforced server-side** (API role checks
   backed by DB constraints), never only by hiding UI. Any finance
   endpoint must return 403 to the secretary, and the test suite in
   `backend/tests/` proving this must always pass.
3. **Speed is the #1 priority**: pagination on every long list, image
   compression + thumbnails, lazy loading, local caching, indexed queries.
4. No self-registration. The two accounts are seeded/managed by the manager.

## The 9 home-screen modules (exact order)

1. Clients — CRUD, instant debounced search (name/phone), flexible
   measurements per garment type (key-value/JSON, not fixed columns),
   per-client order history.
2. Produits — categories: Parfums / Chaussures / Tissus; price, stock,
   images; sale decrements stock and records revenue in Finances.
3. Staff / Personnel — two distinct types:
   - **Couturiers principaux**: per-piece pay. Manager sets `piece_rate`
     (per tailor or default), enters daily pieces count; system computes
     daily amount and weekly totals (paid weekly). Daily entries are
     immutable history — never deleted after week close.
   - **Non-couturiers**: fixed monthly salary.
   Secretary may see names/contacts only — never pay data.
4. Finances — **MANAGER ONLY, completely absent from secretary UI**.
   Totals: tailor wages, salaries, manual expenses (reason+amount+date),
   product sales, tailoring revenue; net profit = revenue − (wages +
   salaries + expenses). Period filters: day/week/month/year/custom.
5. Prêt-à-porter — ready-made models: name, fabric, images, optional
   video, price.
6. Commandes — active orders: client, garment details, fabric, reference
   measurements, start/expected dates, status (en cours / prêt). Marking
   delivered *moves* it to Historique (status change, not a copy).
7. Rendez-vous — simple calendar of client appointments (fitting,
   delivery, trial), linked to a client.
8. Historique — delivered orders, full details preserved, search/filter
   by client or date.
9. Paramètres — manager only: shop name + logo (shown on login screen, editable dynamically),
   account passwords, default piece rate.

## Current codebase state (as of 2026-07-06)

- **`tailoring_app/` is the real app**: Flutter + Provider + go_router,
  feature-first layout (`lib/features/<feature>/{data,domain,presentation}`),
  core utilities in `lib/core/`.
- Built for a **Node.js + PostgreSQL REST API** (no Firebase SDK or mock db files remain).
- Roles in `core/constants/app_constants.dart`: `admin` (= Gérant) and
  `secretary`.
- Seeded demo accounts (see README.md): `admin@tailor.app` / `Admin@1234`,
  `secretary@tailor.app` / `Secretary@1234`.
- The shop name and logo are dynamic and fetched from the REST API settings. The default name is set to "Rayan Couture" in the database seed.
- If no logo is uploaded, a beautiful visual placeholder (an "R" with gradient) is displayed on the login screen. The manager can upload a new logo dynamically from the settings screen.
- Image compression and thumbnail generation are done automatically by the `/api/upload` endpoint.

## Client change-batch (started 2026-07-10)

Large batch of owner-requested changes, executed one tested commit per item
(see the numbered plan). Progress:

- **Item 1 — DONE.** All money / large-number fields use comma thousands
  separators. Shared: `core/utils/money.dart` (`formatThousands`,
  `formatFcfa`, `parseThousands`) and `core/widgets/formatted_number_field.dart`
  (`FormattedNumberField` + `ThousandsSeparatorInputFormatter`, live grouping).
  Commas are display-only; always `parseThousands` before sending to the API.
- **Item 2 — DONE.** Commandes redesigned: an order has multiple line
  items (`order_items`, append-only) each with its own qty/unit_price; the
  order total is derived from `order_items_effective` (voided lines = 0).
  Edits to a line go through `order_item_corrections` (mandatory reason) —
  never in place. Orders link to a tailor (`orders.tailor_id`) and use the
  4-state enum `en_attente → en_cours → termine → livre` (old 'pret' →
  'termine'). Several orders per client per day are allowed. Flutter:
  `OrderItemLine`, dynamic line-item create screen, per-line correction UI
  in the detail screen. Finance order revenue and the client order-history
  endpoint read the derived total. Migration 006.
- **Item 3 — DONE.** The Rendez-vous agenda (`GET /api/appointments`) is a
  merged view: manual appointments UNION every active order's expected
  delivery date (source 'order', read-only, reason 'livraison'). Creating an
  order therefore puts its delivery on the calendar automatically — no
  duplicate row, orders stay the source of truth. Sorted nearest-first;
  Flutter shows a red warning style + countdown badge for anything ≤ 3 days
  away, and order entries deep-link to the order detail.
- **Item 5 — DONE (calculation bug fixed).** `GET /api/finance/summary`
  computed COGS with the wrong `kind` literals (`'product'`/`'model'`) while
  sales store `'produit'`/`'pret_a_porter'`, so **cost of goods sold was
  always 0**. Effect: since COGS was introduced (commit d77178d, 2026-07-09)
  net profit was OVERSTATED and total costs UNDERSTATED by the full purchase
  cost of everything sold. Any net-profit figure the owner saw before this fix
  did not subtract product/model purchase costs — historical judgement calls
  based on those numbers should be revisited. Proven by
  `backend/tests/finance_calculations.test.js`.

## Architecture decisions (FINAL — closed 2026-07-05, do not reopen)

- **Backend: Node.js + Express + PostgreSQL** in `backend/`. JWT auth
  (bcryptjs) with RBAC middleware; the role is ALWAYS read from the
  `users` table on each request — never trusted from the token payload.
  A brief Firebase detour on 2026-07-05 was reverted the same day: the
  user's spec always said SQL. Do not propose Firebase again.
- **Hosting: DigitalOcean VPS with Docker Compose** — same pattern the
  user already runs for their EduGete project (same droplet if resources
  allow, else a small dedicated one). No managed PaaS. Local dev machine
  has no Docker: tests run on `embedded-postgres` (real PostgreSQL
  downloaded as an npm dev dependency).
- **PROJECT PRINCIPLE — every financial table is append-only +
  correction log, no exceptions.** This applies to ALL of them:
  `tailor_daily_entries`, `expenses`, `sales`, and pay-rate changes
  (`staff_pay_history`) — and to any financial table added later.
  UPDATE/DELETE are blocked by DB triggers (not just missing API
  routes); a change is a NEW row in the matching `*_corrections` /
  history table with a mandatory `reason`, linked to the original.
  Effective values come from SQL views (`*_effective`, latest
  correction wins) and every revenue/cost sum reads those views.
  The manager UI shows the current value plus an openable correction
  history (who, when, from→to, why). When adding a new financial
  table, add its triggers, correction table, effective view and
  append-only tests in the same commit.
- **Sales are atomic and server-priced**: `POST /api/sales` reads the
  price from the DB, computes the total server-side, and decrements
  stock in the same transaction (`quantity >= qty` guard). The client
  never sends prices. Secretary can create sales but `GET /api/sales`
  is manager-only (write-only pattern). Sale corrections (qty fix or
  void, manager-only) adjust product stock by the delta in the same
  transaction.
- **Customer role removed** from the Flutter app: no self-registration,
  no customer-facing screens. Clients are plain DB records.
- The 29 Firestore-rules guarantees were ported 1:1 to API integration
  tests in `backend/tests/` (Jest + Supertest against real PostgreSQL);
  the Firebase rules/config artifacts were then deleted.
- Data model: `docs/DATA_MODEL.md` (PostgreSQL schema). Key points:
  staff contacts (`staff`) split from pay (`staff_pay`); Historique is
  `orders.status = 'livre'` (a status change, not a copy);
  `settings` split into public rows (shop name/logo, readable without
  auth for the login screen) and private rows (manager-only).
- Flutter app data layer runs entirely on the REST API. All Firebase SDK dependencies, Firebase configurations, cloud functions, and local mock database files have been completely cleaned up.

## Working conventions

- Work module by module; a module must run end-to-end before moving on.
- Every finance-related change needs tests proving secretary access is
  denied at the data layer.
- Clear, separate git commits per feature. Self-review the diff before
  concluding a phase.
- Run the app: `cd tailoring_app && flutter run -d chrome` (see README.md).
