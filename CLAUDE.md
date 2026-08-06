# CLAUDE.md — Rayan Couture (Tailoring Shop Management App)

Mobile app to manage a large tailoring shop in Mali (Rayan Couture). App UI language is **French**
(all labels, buttons, error messages, and PDF reports). Currency is **FCFA / XOF, no decimals**.
The user communicates in Arabic; reply to them in Arabic unless asked otherwise.

## Non-negotiable rules

1. **Two operating users only**: `MANAGER` (le Gérant — full access to
   everything) and `SECRETARY` (la Secrétaire). The secretary must NEVER see
   the shop's money: profits, revenues, product/model cost prices and margins,
   expenses, monthly staff salaries and salary payments.
   **Exception, deliberately granted by the owner (2026-07-20): TAILOR
   piece-rates and wages ARE hers** — see rule 2 for the exact boundary. Read
   rule 2 before touching any permission; the two rules together are the whole
   truth, and neither may be narrowed without the owner's word.
2. **Financial isolation must be enforced server-side** (API role checks
   backed by DB constraints), never only by hiding UI. Any finance
   endpoint must return 403 to the secretary, and the test suite in
   `backend/tests/` proving this must always pass.
   - **TAILORS are fully open to the secretary (owner decision 2026-07-20 & 2026-08-06):**
     piece prices differ per garment/model and there are many models, so routing
     every price or schedule correction through the manager was unworkable. The
     secretary therefore has full powers over tailors: she creates, edits and
     voids/deletes daily entries in the weekly schedule (via append-only corrections
     `entry_corrections`), INCLUDING `piece_rate`, and sees amounts, weekly totals
     and monthly rankings.
     **Audit & Accountability**: Every edit or void records the exact user
     (`corrected_by` = Manager or Secretary user ID) and timestamp (`corrected_at`),
     so the shop owner can audit who modified or voided any entry. `/api/tailor-entries`
     is both-roles; `/api/staff-pay` is both-roles but the secretary is confined to
     `type = 'couturier'` and to `piece_rate` — `monthly_salary` / `salary_due_day` are
     stripped from her reads, ignored on her writes, and any staff-pay route for a
     non-couturier returns 403 to her.
     Still MANAGER-ONLY: monthly salaries, `/api/salary-payments`,
     `/api/finance`, `/api/reports`, `/api/expenses`, `GET /api/sales`,
     product/model `cost_price` + `/stats`, `/api/settings/private`, `/api/users`.
   - **Secretary CRUD on master data (owner decision 2026-07-19, "interpretation
     A"):** the secretary MAY fully manage the roster/catalog on four pages —
     Tailleurs, Staff mensuel, Prêt-à-porter, Produits (create/edit/delete the
     records + their non-financial fields). What stays MANAGER-ONLY and is never
     shown/settable by her: tailor `piece_rate` + daily wage entries + weekly
     totals, monthly `salary` + salary payments, and product/model `cost_price`
     (+ the profit `/stats`). So on those pages `POST/PUT/DELETE /api/staff`,
     `/api/products`, `/api/pret-a-porter` are both-roles; `cost_price` is
     ignored on her writes and stripped from her reads; `/api/staff-pay`,
     `/api/tailor-entries`, `/api/salary-payments`, `/stats` remain 403.
     `DELETE /api/clients` is open to both roles (Type-A master data delete; past delivered orders preserved via `client_name_snapshot`).
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
   - **Couturiers principaux**: per-piece pay. Manager **or secretary** sets
     `piece_rate` (per tailor, per entry, or default) and enters the daily
     pieces count; system computes daily amount and weekly totals (paid
     weekly). Daily entries are immutable history — never deleted after week
     close (corrections only).
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

## Multi-shop / resale model (decided 2026-07-13)

The app is sold to multiple tailoring shops using the **isolated-instance-per-
shop** model (owner's choice): each shop gets its own Docker deployment + its
own PostgreSQL database. NO shared multi-tenancy, NO `shop_id` column — do not
add one unless the owner explicitly switches models. Each shop feels bespoke
purely through the already-dynamic settings (shop name, logo, default piece
rate, promo link). Onboarding a new shop is one command: `npm run setup-shop`
(`backend/scripts/setup-shop.js` — migrate → seed the 2 accounts → write shop
identity from env; idempotent). See `docs/ONBOARDING_NEW_SHOP.md`. Invoice logo
priority: uploaded logo → bundled `tailoring_app/assets/logo.jpeg` → "R"
placeholder. Dashboard tiles are unified on one Teal+Gold brand look (no more
per-module random colours).

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
  away, and order entries deep-link to the order detail. Manual appointment
  creation was later removed from the UI (orders are the source of delivery
  dates); the calendar is read/merge-only.
- **Item 4 — DONE.** Garment types (`core/constants/garment_types.dart`):
  `Boubou` → `Grand Boubou`, `Pantalon` removed, `Création` added. These
  types live only as a Flutter constant (no DB seed), so no migration was
  needed. The legacy English `garmentName()` word-map is unused by the
  active French dropdowns and left as-is.
- **Item 6 — DONE.** Staff split into two home modules: **Tailleurs**
  (couturiers, always piece-rate) keeps the existing screen (list/entries/
  weekly), and a new manager-only **Staff** module
  (`monthly_staff_screen.dart`, route `/admin/monthly-staff`, secretary
  redirected) for monthly employees. Tailor daily entries are now itemised:
  migration 007 adds `garment_type` + optional `order_id` to
  `tailor_daily_entries` and drops the one-row-per-day UNIQUE so a tailor can
  log several garment types per day. Client name is DERIVED from the linked
  order (never re-typed). New `GET /api/tailor-entries/weekly-detail`
  returns a tailor's week. Still append-only (corrections change pieces
  only). The `duplicate entry → 409` security test was replaced by one
  asserting multiple same-day entries. UI later simplified: the 3 tabs
  (Personnel/Entrées/Résumés) were removed — Tailleurs is now a single
  tailor list; tapping a tailor opens one sheet with everything (a real
  navigable Monday→Sunday week showing all 7 days with garments/quantities/
  clients + daily & weekly totals, plus add-entry, per-entry correction and
  edit-rate). The Flutter `_getWeekId` was made true ISO-8601 to match the
  backend `isoWeekId`.
- **Item 7 — DONE.** Order invoice + WhatsApp. `InvoiceService`
  (`orders/data/invoice_service.dart`) builds a branded A4 PDF (logo or the
  "R" placeholder, Rayan Couture, client, line items, total/advance/reste,
  dates, clickable promo link) via `pdf`/`printing` and shares it with
  `Printing.sharePdf`; `sendWhatsApp` opens `wa.me/<intl-phone>` (Mali 223
  prepended to 8-digit locals) with a prefilled recap, warning on a
  missing/invalid number. Both actions are on the order detail screen and
  available to BOTH roles (only the order price the client already knows —
  no internal financials). New public setting `promo_group_link`
  (migration 008) editable in Paramètres. Invoice/WhatsApp available to
  manager and secretary.
- **Item 8 — DONE.** Finances screen now shows, besides the KPI cards, a
  separate expandable detail table per category — delivered-order revenue,
  product sales, tailor wages (couture) and expenses — each listing its
  operations with a subtotal, driven by period presets (Jour/Semaine/Mois/
  Année/Personnalisé) that recompute from/to and reload. Rows come from the
  existing list endpoints filtered by date (`FinanceRepository.*Rows`).
  Expense editing still goes through the append-only `expense_corrections`
  path (unchanged) — the pattern was NOT weakened for the UI.
- **Item 9 — DONE.** Colour system unified on the single `AppColors`
  palette (Deep Teal primary, Gold accent, neutral surfaces/text, and the
  semantic tokens success/warning/error/info). Every scattered raw Material
  status colour (`Colors.green/red/orange`, incl. shades) across finance,
  staff, products, ready-to-wear, appointments, settings and client screens
  was mapped to `AppColors.success/error/warning` so success is one green,
  danger one red, warning one amber everywhere. The ≤ 3-day Rendez-vous
  warning uses `AppColors.error` for a clear, distinct red (item 3). Vivid
  per-module dashboard tile colours are intentional and kept.
- **Item 5 — DONE (calculation bug fixed).** `GET /api/finance/summary`
  computed COGS with the wrong `kind` literals (`'product'`/`'model'`) while
  sales store `'produit'`/`'pret_a_porter'`, so **cost of goods sold was
  always 0**. Effect: since COGS was introduced (commit d77178d, 2026-07-09)
  net profit was OVERSTATED and total costs UNDERSTATED by the full purchase
  cost of everything sold. Any net-profit figure the owner saw before this fix
  did not subtract product/model purchase costs — historical judgement calls
  based on those numbers should be revisited. Proven by
  `backend/tests/finance_calculations.test.js`.

## Antigravity review + corrections (2026-08-03)

A different tool (Antigravity) added 24 commits while Claude was away
(`5dc578c..d6d608f`). Reviewed against this file; most of it was sound
(suppliers/wholesale payments correctly append-only, staff-pay weekly fields
correctly gated). Four things contradicted the rules here and were corrected:

- **Cash-basis tailoring revenue was half-implemented (money bug).**
  Migration 016 switched order revenue from accrual (delivered order total) to
  cash-basis (`SUM(order_payments)`), but payment rows were only written for an
  advance. **An order delivered and paid in full at hand-over produced no row,
  so it never appeared in revenue at all** — reported for 72 Couture, equally
  true for Rayan Couture. Net profit was UNDERSTATED from commit `1eecd32`
  until this fix, so judgement calls made on those figures should be revisited
  (same class of problem as the COGS bug in item 5). Delivering an order now
  records the outstanding balance as collected cash.
- **`order_payments` violated the append-only principle.** No trigger, no
  corrections table, no effective view, `ON DELETE CASCADE` (deleting an order
  erased its cash from every total) and `CHECK (amount <> 0)` allowing negative
  rows. Migration 018 gives it the full treatment: `ON DELETE RESTRICT`,
  `amount > 0`, `order_payment_corrections`, append-only triggers and
  `order_payments_effective` (which finance + reports read). Lowering an
  advance writes correction rows — never a negative counter-row.
- **Order delete bypassed append-only.** The route ran
  `ALTER TABLE ... DISABLE TRIGGER` on `order_items`,
  `order_item_corrections` and `tailor_daily_entries`, deleted rows, then
  re-enabled inside a silent `catch`. That is table-wide DDL, not
  session-local: protection was off for **every** connection during the
  delete. Orders always carry append-only line items, so **an order is never
  hard-deleted** — cancelling is a status change to `annule` with
  `cancelled_at` + `cancel_reason` (migration 019), exactly like delivery moves
  an order to Historique. Items, corrections, cash and tailor entries survive.
  Cancelled orders are excluded from the active list and the agenda.
- **Wholesale/suppliers were visible to the secretary.** They expose totals,
  amounts paid and outstanding balances — money — so they are `managerOnly`
  like every other revenue module (owner decision 2026-08-03), hidden from her
  dashboard and blocked in the router.

Two further corrections, not rule violations but wrong-in-fact:

- **WhatsApp auto-send was fictional.** The service claimed
  `SENT_AUTOMATICALLY` while only pushing to an in-memory array, and ran
  whenever an order became `termine` — so a shop believed clients had been
  told their order was ready when nobody had. It now really posts to UltraMsg
  or Green API when `WHATSAPP_PROVIDER` / `WHATSAPP_INSTANCE_ID` /
  `WHATSAPP_API_KEY` are set, and otherwise reports `not_configured` and sends
  nothing. **Never make this report success without a provider.** The flow the
  shops actually use is the client-side `wa.me` button.
- **One shop's logo shipped to all of them.** `assets/logo.jpeg` had been
  replaced with 72H Couture's real logo, and one build serves every shop. The
  bundled asset is gone (no Dart code read it any more); logos are per-shop via
  `settings.logo_url` with the neutral initial placeholder. **Do not re-add a
  bundled shop logo** — it supersedes the invoice fallback described in the
  multi-shop section above. Web PWA icons are the neutral CouturePro icon and
  are swapped per shop at deploy time by `scripts/sync-shop-logos.ps1`.

Deliberately kept as Antigravity built it, on the owner's instruction:
**`POST /api/sales` accepts a client-supplied `unit_price`** (VIP discounts).
This relaxes the original "server-priced, the client never sends prices" rule —
the server still computes `total` and decrements stock atomically, but the unit
price is now the caller's to set, with no ceiling. Owner decision 2026-08-03.

## Master-data deletion — Type A vs Type B (NON-NEGOTIABLE, added 2026-07-17)

The manager (never the secretary) has **full edit + hard-delete** of
**Type-A master/identity data** — but Type-B financial history stays
append-only forever. This distinction is not up for debate:

- **Type A (master data): direct full edit + hard delete, allowed.**
  `staff` (couturiers + monthly), `clients`, `products`,
  `pret_a_porter_models`, garment catalogue, `appointments` (the manual ones —
  order-derived agenda entries are a read-only view of the order), `suppliers`,
  `wholesale_orders`, public settings. Every Type-A `DELETE` is `managerOnly`
  (verified in `backend/tests/master_data_delete.test.js`) EXCEPT the four the
  owner opened to the secretary in rule 2 (`clients`, `staff`, `products`,
  `pret-a-porter`).
  - **Garment catalogue (`custom_garments`, 2026-08-03):** the secretary adds
    models while taking an order, so her `PUT` is MERGED into what is stored —
    a payload missing a model can no longer wipe it. Removing a model is
    `DELETE /api/clients/settings/custom-garments/:gender/:garment`, manager
    only. Orders keep their own `garment_type` text, so removing a model never
    rewrites history.
  - **Deleting a supplier or a wholesale order** keeps its financial history:
    `supplier_purchases.supplier_name_snapshot` + `ON DELETE SET NULL`, and a
    wholesale order carrying payments refuses deletion with 409.
- **Type B (historical financial records): append-only forever, NO direct
  delete.** `tailor_daily_entries`, `sales`, `expenses`, `salary_payments`,
  `staff_pay_history` and all their `*_corrections`. Triggers still block
  UPDATE/DELETE; a correction row is the only way to change a number.

**How a Type-A hard delete keeps Type-B history intact (migration 012):**
deleting a tailor/client/product must never lose or alter one franc of past
history. Mechanism = **name SNAPSHOT on the historical row + no restricting
FK** (exactly the pre-existing `sales.item_id` + `item_name` pattern):
- `tailor_daily_entries.tailor_name_snapshot`,
  `staff_pay_history.staff_name_snapshot`,
  `salary_payments.staff_name_snapshot` — snapshot written at insert; the FK
  to `staff` was **dropped** (NOT `ON DELETE SET NULL`, because a cascaded
  UPDATE would fire the append-only trigger and abort the delete).
- `orders.client_name_snapshot` / `orders.tailor_name_snapshot` — orders is
  NOT append-only, so it keeps a real FK switched to `ON DELETE SET NULL` +
  snapshot; delivered orders stay in Historique after the client is deleted.
- Reports read `COALESCE(live.full_name, row.snapshot)` and expose a
  `*_deleted` flag so old data shows with an "ancien/supprimé" marker.
- Wage/finance TOTALS never join `staff`, so a delete changes no total (the
  weekly-total-unchanged invariant is a test).

Flutter: every Type-A delete uses `confirmDeleteByTyping` (the manager must
TYPE the exact name — not a yes/no — because this is irreversible), with a
French note that historical data is preserved.

**Security fix shipped in the same batch (independent of the feature):**
`DELETE /api/clients` was NOT `managerOnly` — the secretary could delete
clients. Fixed + regression test ("secretary DELETE /clients → 403").

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
