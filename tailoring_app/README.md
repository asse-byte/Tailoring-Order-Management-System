# Tailoring Studio — Order Management System

A complete Flutter mobile app that turns paper-based tailoring shops into a digital,
real-time, multi-role business: customers place and track orders from their
phones, the shop owner runs the whole operation from an admin dashboard.

> **Status:** All 9 build steps complete. Ready to plug in your Firebase project,
> generate the native folders, and `flutter run`.

---

## ✨ Features at a glance

### 🔐 Authentication
- Email + password (Firebase Auth) with persistent sessions
- Customer self-registration; admins are seeded via a one-time setup screen
- Password reset email; in-app change-password flow (reauth + update)
- Role-based routing — customers and admins land in different shells

### 👤 Customer side
- Profile with avatar upload, phone, and **body measurements** (chest, waist, hips,
  shoulder, sleeve, height + notes)
- **Place new order**: garment picker (9 types), fabric description + photo, style
  reference photo, delivery date, special instructions — measurements are snapshotted
  into the order so size changes don't rewrite history
- **My Orders** with status filter chips, shimmer loading, empty states
- **Order detail** with photos, price, admin notes (gold accent), measurements grid,
  full status timeline
- **In-app notifications** with unread badge, tap to deep-link to the related order

### 🛠 Admin side
- **Dashboard** with live counts (today / pending / in-progress / completed),
  quick actions, recent activity feed
- **All orders** with search (customer / garment / id), status chips, date-range filter
- **Order detail** with admin actions: status update sheet (radio + note), price &
  notes editor, cancel-order with confirm dialog
- **Walk-in order**: pick existing customer or fill name/phone, full order form with
  measurements that sync back to the customer's profile
- **Customers** list with search, avatars, customer detail with editable measurements
  and full order history
- **Reports**: revenue card, status pie chart, daily/weekly/monthly line chart,
  top-garments bar chart, **PDF export** with date range
- **Notifications**: send to one customer or broadcast to all (batched fan-out)
- **Settings**: profile card, broadcast, reports, change password, sign out

### 📡 Other
- **Offline support**: Firestore handles cached reads automatically; an SQLite
  outbox queues offline order submissions (with copies of picked images) and
  auto-syncs the moment connectivity returns. The My Orders banner shows live
  pending-sync state with a spinner
- **Push (FCM)**: client-side complete (token registration, foreground heads-up
  via `flutter_local_notifications`, tap deep-links). A ready-to-deploy Cloud
  Function in `functions/index.js` does server-side delivery
- **Material 3** light + dark themes, Google Fonts (`Poppins`), shared widget
  library, deep-teal `#006D6D` + gold `#C9A84C` palette
- Clean architecture: feature folders × `domain` / `data` / `presentation`,
  Provider for state, GoRouter for navigation, Repository pattern throughout

---

## 🚀 Getting Started — full checklist

You need this once. After that, `flutter run` is all it takes.

### 1. Install Flutter
```bash
flutter --version   # should be 3.27+ on the stable channel
```

### 2. Generate the native platform folders
This repo only ships the Dart `lib/`, config, and rules files. Run from the
project root to create `android/`, `ios/`, etc.:

```bash
cd tailoring_app
flutter create . --platforms=android,ios --org com.yourdomain --project-name tailoring_app
```

### 3. Create a Firebase project
- Go to <https://console.firebase.google.com> → **Add project**
- Enable, in this order:
  1. **Authentication** → Sign-in method → **Email/Password** ✅
  2. **Cloud Firestore** → Create database → *Production mode*
  3. **Cloud Storage** → Get started
  4. **Cloud Messaging** (auto-enabled)

### 4. Connect Firebase to the Flutter app
The fastest path — install the FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This will:
- Register Android + iOS apps in your Firebase project
- Drop `google-services.json` into `android/app/`
- Drop `GoogleService-Info.plist` into `ios/Runner/`
- **Overwrite `lib/firebase_options.dart`** with your real values

> If you can't run `flutterfire configure`, manually replace every
> `// TODO: Replace with your Firebase config` comment in `lib/firebase_options.dart`.

### 5. Apply platform setup
See **`PLATFORM_SETUP.md`** for the exact `AndroidManifest.xml`, `Info.plist`,
and Xcode capability changes you need. (Most are 2-line edits.)

### 6. Deploy the security rules
```bash
firebase deploy --only firestore:rules,storage
```
Files: `firestore.rules` and `storage.rules` at the project root.

### 7. Install dependencies and run
```bash
flutter pub get
flutter run
```

### 8. Seed the admin account
On first launch the **Login** screen has an "Admin setup" link at the bottom.
Tap it once; it will create the admin user with these hardcoded seed credentials:

| Email             | Password    |
|-------------------|-------------|
| `admin@tailor.app`| `Admin@1234`|

> ⚠️ Change the password from **Settings → Change password** after first sign-in.

That's it — you can now register a customer on a second device, place orders,
update statuses from the admin app, broadcast notifications, etc.

### 9. (Optional) Deploy the Cloud Function for push delivery
In-app notifications work without this. To get system-tray heads-up pushes:

```bash
cd functions
npm init -y
npm install firebase-admin firebase-functions
cd ..
firebase login
firebase deploy --only functions
```

The function `deliverNotification` listens to `/notifications/{id}` writes and
calls FCM with the recipient's device token. Requires the **Blaze (pay-as-you-go)**
plan — there's a generous free monthly tier.

---

## 🗂 Project structure

```
tailoring_app/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md                             ← this file
├── PLATFORM_SETUP.md                     ← native config notes
├── firestore.rules                       ← security rules
├── storage.rules
├── functions/
│   └── index.js                          ← Cloud Function for push delivery
└── lib/
    ├── main.dart
    ├── firebase_options.dart             ← regenerated by flutterfire configure
    │
    ├── core/
    │   ├── constants/         (app_constants, app_strings, garment_types)
    │   ├── theme/             (app_colors, app_theme, context_colors)
    │   ├── utils/             (validators, date_formatter, connectivity_helper)
    │   ├── data/              (local_database — sqflite singleton)
    │   ├── router/            (app_router with role-aware redirect)
    │   └── widgets/           (primary_button, app_text_field, status_badge,
    │                          loading_shimmer, empty_state, …)
    │
    └── features/
        ├── auth/              (login, register, forgot/change password, admin setup)
        ├── customers/         (profile + measurements; admin customers list & detail)
        ├── orders/            (entities, repos, customer + admin shells, dashboards,
        │                      orders list / detail, walk-in, sync service)
        ├── notifications/     (entity, repo, FCM service, customer list, broadcast)
        └── reports/           (charts + PDF builder, admin reports screen)
```

---

## 🔧 Tech & versions

| Library                  | Why                                       |
|--------------------------|-------------------------------------------|
| `firebase_core` ^3.6     | Firebase init                             |
| `firebase_auth` ^5.3     | Email/password auth                       |
| `cloud_firestore` ^5.4   | Realtime data + offline persistence       |
| `firebase_storage` ^12.3 | Profile, fabric, style photos             |
| `firebase_messaging` ^15.1 + `flutter_local_notifications` ^17.2 | Push + foreground heads-up |
| `provider` ^6.1          | State management                          |
| `go_router` ^14.2        | Declarative routing with redirects        |
| `sqflite` ^2.3           | Offline outbox                            |
| `connectivity_plus` ^6.0 | Online/offline detection                  |
| `image_picker` ^1.1      | Fabric / style / avatar uploads           |
| `cached_network_image` ^3.4 | Smooth photo rendering                 |
| `fl_chart` ^0.69         | Pie / line / bar charts                   |
| `pdf` ^3.11 + `printing` ^5.13 | PDF reports + share sheet           |
| `google_fonts` ^6.2 (Poppins) | Typography                           |
| `shimmer` ^3.0           | Loading states                            |
| `intl` ^0.19, `uuid` ^4.5 | Date/number formatting, ids              |

---

## 🧪 Test credentials

After running step 8 (admin seed) you'll have:

| Role     | Email              | Password    |
|----------|--------------------|-------------|
| Admin    | `admin@tailor.app` | `Admin@1234`|
| Customer | (whatever you register from the customer app)         |

---

## 📌 Known polish follow-ups (small, non-blocking)

- A handful of image-placeholder backgrounds use the light-mode `AppColors.surfaceAlt`
  directly. They are visually fine but could use the `context.cSurfaceAlt` extension
  in `core/theme/context_colors.dart` for tighter dark-mode polish.
- The web Firebase config in `firebase_options.dart` is templated for future use
  — the app currently targets Android + iOS only.
- `OrdersSyncService` gives up after 5 failed attempts on a queued order. A
  manual "Retry sync" button in Settings would round this out.

---

## 🙋 What was *not* built (per spec — flagged "future enhancements")

These were intentionally deferred:

- WhatsApp / SMS notifications
- In-app payments
- Multi-branch support
- QR codes per order
- Arabic RTL
- Loyalty points

Each of these slots cleanly into the existing feature-folder layout when you're
ready to expand.
