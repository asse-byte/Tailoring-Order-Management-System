# PRD — Tailoring Order Management System (Flutter)

## Original problem statement

Build a complete Flutter mobile app — **Tailoring Order Management System** — that
digitises the workflow of a tailoring shop. Targets:

- **Customers** can register, save body measurements, place orders with fabric &
  style photos, track status in real time, and receive notifications.
- **Admin (shop owner / staff)** can manage every order, update status & price,
  manage customers, send notifications, and view reports.

Tech stack: Flutter (Material 3) · Firebase (Auth + Firestore + Storage + FCM) ·
SQLite for offline · Clean Architecture with Repository pattern.

The user chose **Option C**: full Flutter codebase as files (no in-environment
preview), Firebase scaffolded with placeholders, hardcoded admin seed creds:
`admin@tailor.app` / `Admin@1234`.

## Architecture
- Feature-based folder layout: `features/{auth,orders,customers,notifications,reports}` ×
  `domain` / `data` / `presentation`.
- State: Provider; Navigation: go_router with role-aware redirect.
- Repositories wrap Firebase + Storage; SQLite outbox handles offline writes.
- Firestore offline persistence is enabled by default for cached reads.

## What's been implemented

| Step | Date | Summary |
|------|------|---------|
| 1 | Jan 2026 | Project setup, M3 theme (Poppins, deep-teal + gold), shared widgets |
| 2 | Jan 2026 | Auth: login, register, forgot/admin-setup, persistent session, role redirects |
| 3 | Jan 2026 | Customer orders: place / list / detail / measurements / profile |
| 4 | Jan 2026 | Admin dashboard, all-orders list, status updates, walk-in flow |
| 5 | Jan 2026 | Admin customer management with editable measurements + order history |
| 6 | Jan 2026 | In-app notifications, FCM token + foreground heads-up + deep-link, broadcast |
| 7 | Jan 2026 | Reports with fl_chart + PDF export via `pdf` + `printing` |
| 8 | Jan 2026 | Offline outbox via sqflite + auto-sync on reconnect |
| 9 | Jan 2026 | Change password, security rules, platform setup notes, polished README |

## What's deferred (future enhancements)
- WhatsApp / SMS notifications
- In-app payments
- Multi-branch support
- QR codes per order
- Arabic RTL
- Loyalty points

## Backlog (P0 / P1 / P2)

### P0
- (none — core spec is complete)

### P1
- Theme-aware `AppColors.surfaceAlt` in image placeholders for tighter dark-mode polish
- Manual "Retry sync" button in admin Settings for outbox entries that hit the 5-attempt cap

### P2
- Pagination/virtualisation on All Orders list once shop scales past ~1000 orders
- Server-side reports aggregation (currently client-side from the Firestore stream)
- Add web platform target (config template already in `firebase_options.dart`)

## Notes for the user

- This is a Flutter mobile project. The Emergent platform cannot run Flutter
  apps in its preview tab — there's no live preview by design (Option C).
- To actually run the app: `flutter create . --platforms=android,ios …` →
  `flutterfire configure` → `flutter run`. Full instructions in `README.md`.
- Hardcoded seed admin credentials live in `lib/core/constants/app_constants.dart`
  and `/app/memory/test_credentials.md`.
