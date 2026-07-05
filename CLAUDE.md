# CLAUDE.md — Couture Mali (Tailoring Shop Management App)

Mobile app to manage a large tailoring shop in Mali. App UI language is **French**
(all labels, buttons, error messages). Currency is **FCFA / XOF, no decimals**.
The user communicates in Arabic; reply to them in Arabic unless asked otherwise.

## Non-negotiable rules

1. **Two operating users only**: `MANAGER` (le Gérant — full access to everything)
   and `SECRETARY` (la Secrétaire — must NEVER see any financial data: profits,
   revenues, expenses, tailor piece-rates/wages, staff salaries).
2. **Financial isolation must be enforced server-side** (API role check or
   Firestore security rules), never only by hiding UI. Any finance
   endpoint/collection must reject secretary access outright.
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
9. Paramètres — manager only: shop name + logo (shown on login screen),
   account passwords, default piece rate.

## Current codebase state (as of 2026-07-05)

- **`tailoring_app/` is the real app**: Flutter + Provider + go_router,
  feature-first layout (`lib/features/<feature>/{data,domain,presentation}`),
  core utilities in `lib/core/`.
- Built for **Firebase** (Auth, Firestore, Storage, FCM) but
  `lib/firebase_options.dart` still has `REPLACE_WITH_*` placeholder keys,
  so `MockDatabase.useMock` is true and the app runs on a **local mock DB**
  (SharedPreferences). Data is device-local only right now.
- Roles in `core/constants/app_constants.dart`: `admin` (= Gérant) and
  `secretary`; `customer` remains only as a transitional constant until
  the customers feature is refactored into the `/clients` collection.
- Seeded demo accounts (see README.md): `admin@tailor.app` / `Admin@1234`,
  `secretary@tailor.app` / `Secretary@1234`.

## Architecture decisions (made 2026-07-05)

- **Backend: Firebase** (Auth + Firestore + Storage). No Node/Postgres
  server. Financial isolation is enforced by Firestore security rules.
- **Customer role removed**: no self-registration, no customer-facing
  screens. Clients are plain records managed by manager/secretary.
- Data model lives in `docs/DATA_MODEL.md`. Key patterns:
  - Staff contact info (`staff`) is split from pay data (`staff_pay`,
    `tailor_daily_entries`) because Firestore read rules are per-document,
    not per-field — secretary can read the former, never the latter.
  - Historique is not a separate collection: an order whose status becomes
    `livre` simply shows up in the Historique query (move, not copy).
  - `settings/public` (shop name/logo, readable pre-auth for the login
    screen) is split from `settings/private` (default piece rate, manager
    only).
- Legacy Emergent scaffold (`backend/`, `frontend/`, old test harness)
  was deleted; the Flutter app is the whole product.
- Security rules + 29 emulator tests landed 2026-07-05
  (`tailoring_app/firestore.rules`, `tailoring_app/rules_tests/` —
  run with `npm test`). Customer role/screens removed the same day.
- Still to do, module by module: point each feature at the new
  collections (clients, staff + staff_pay, sales, expenses,
  pret_a_porter, settings) with real Firestore repositories replacing
  screen-local mock state; then activate a real Firebase project
  (firebase_options.dart still has REPLACE_WITH_* placeholders).

## Working conventions

- Work module by module; a module must run end-to-end before moving on.
- Every finance-related change needs tests proving secretary access is
  denied at the data layer.
- Clear, separate git commits per feature. Self-review the diff before
  concluding a phase.
- Run the app: `cd tailoring_app && flutter run -d chrome` (see README.md).
