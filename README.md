# AOneGo9 — Super Admin Console

A deploy-ready **Flutter** admin panel for the AOneGo9 modeling-agency & production-house marketplace. One codebase renders an adaptive **desktop** (sidebar) and **mobile** (drawer) UI. All data currently comes from an in-memory mock layer that is structured to be swapped for a real backend with zero UI changes.

---

## 1. Run it

Requirements: Flutter SDK 3.27+ (Dart 3.6+). _(Uses the modern `Color.withValues` API.)_

```bash
# 1. Generate the platform runners (android/ios/web/desktop).
#    This project ships lib/ + pubspec.yaml only; this step adds the
#    platform folders WITHOUT touching your lib/ or pubspec.
flutter create .

# 2. Install dependencies and run
flutter pub get

# Web (recommended for an admin console)
flutter run -d chrome
flutter build web        # output in build/web

# Desktop
flutter run -d macos     # or windows / linux

# Mobile
flutter run -d <device>
```

Login screen has demo credentials pre-filled — just press **Sign In**.

---

## 2. Architecture

```
lib/
├── main.dart                       app entry (MaterialApp.router)
├── core/
│   ├── theme/                      colors + Material 3 dark theme
│   ├── responsive/                 breakpoints + ResponsiveLayout
│   ├── routing/                    go_router table + nav destinations
│   └── widgets/                    shell (sidebar/rail/drawer) + shared UI
├── data/
│   ├── models/                     domain models (fromJson/toJson) + status mappers
│   ├── mock/                       seed data (DELETE once API is live)
│   └── repositories/               <-- THE BACKEND SEAM
└── features/
    ├── auth/         login
    ├── dashboard/    KPIs + revenue chart + quick actions
    ├── analytics/    bar / line / pie charts
    ├── vendors/      approve · reject · suspend · KYC  ← core admin flow
    ├── users/        talent & user management
    ├── bookings/     oversight + dispute resolution
    ├── payments/     transactions, payouts, refunds, commission
    ├── reviews/      moderation
    ├── support/      tickets
    ├── cms/          banners + categories
    └── settings/     commission, KYC policy, admin team
```

### State management
Lightweight `StatefulWidget` + repository calls. `provider` is already in
`pubspec.yaml` if you prefer to lift state into `ChangeNotifier`s.

---

## 3. Where the backend dev plugs in  ⭐

**Everything funnels through one file:**

```
lib/data/repositories/admin_repository.dart
```

Each method returns mock data today and is annotated with the suggested REST
endpoint, e.g.:

```dart
// GET /api/admin/vendors
Future<List<Vendor>> vendors() async { ... }

// PATCH /api/admin/vendors/{id}  { status }
Future<void> setVendorStatus(String id, ApprovalStatus status) async { ... }
```

To go live:
1. Add an HTTP client (`dio` or `http`) to `pubspec.yaml`.
2. Replace each method body with a real call and `Model.fromJson(...)`.
3. Delete `lib/data/mock/`.

No widget code needs to change — models already have `fromJson`/`toJson`.

### Suggested endpoint map
| Area | Endpoints |
|------|-----------|
| Auth | `POST /api/admin/auth/login` |
| Dashboard | `GET /api/admin/dashboard/summary` |
| Vendors | `GET /api/admin/vendors`, `PATCH /api/admin/vendors/{id}` |
| Users | `GET /api/admin/users`, `PATCH /api/admin/users/{id}` |
| Bookings | `GET /api/admin/bookings`, `POST /api/admin/bookings/{id}/resolve` |
| Payments | `GET /api/admin/payments`, `POST /api/admin/payouts/run` |
| Reviews | `GET /api/admin/reviews`, `PATCH /api/admin/reviews/{id}` |
| Support | `GET /api/admin/support/tickets` |
| CMS | `GET/POST/PATCH /api/admin/cms/banners`, `/categories` |
| Analytics | `GET /api/admin/analytics/{revenue|signups|categories}` |
| Settings | `GET/PUT /api/admin/settings` |

---

## 4. Branding
Gold (`#C9A86C`) on deep charcoal, matching the AOneGo9 marketing site. All
tokens live in `lib/core/theme/app_colors.dart`.

> Mock data is illustrative. Wire the repository layer to your API to go live.
