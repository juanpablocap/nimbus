# Nimbus — Mobile App Architecture

## Overview

Flutter app for residents and guards. Two user experiences in one app, role-determined at login.

---

## Stack

- Flutter 3.x + Dart
- State management: Riverpod
- Navigation: GoRouter
- Backend: Supabase (supabase_flutter)
- QR generation: qr_flutter
- QR scanning: mobile_scanner
- Sharing: share_plus

---

## Project Structure

```
apps/mobile/lib/
├── main.dart                          # Entry point, Supabase init
├── core/
│   ├── constants/app_constants.dart   # Supabase URLs, Edge Function endpoints
│   ├── theme/app_theme.dart           # Light/dark themes
│   └── router/app_router.dart         # GoRouter config + bottom nav shell
├── features/
│   ├── auth/
│   │   ├── screens/login_screen.dart
│   │   └── providers/auth_provider.dart
│   ├── home/
│   │   └── screens/home_screen.dart   # Dashboard with quick actions + stats
│   ├── visits/
│   │   └── screens/
│   │       ├── visits_screen.dart     # List with filter chips
│   │       ├── create_visit_screen.dart # Create form
│   │       └── visit_detail_screen.dart # QR display + share + cancel
│   ├── scanner/
│   │   └── screens/scanner_screen.dart # QR scanner + validation + approve
│   ├── news/
│   │   └── screens/news_screen.dart   # Community feed
│   └── profile/
│       └── screens/profile_screen.dart # User info + properties + sign out
└── shared/
    ├── widgets/                        # Reusable UI components
    ├── models/                         # Data models
    └── services/                       # API service classes
```

---

## Navigation

Bottom navigation bar with 5 tabs:
1. **Home** — Dashboard with quick actions and stats
2. **Visits** — My visits list + create new
3. **Scan** — QR scanner (guard mode)
4. **News** — Community announcements
5. **Profile** — User info + sign out

Auth redirect: unauthenticated users are redirected to `/login`.

---

## QR Flow

### Resident Flow
1. Create visit (name, document, property, type, expiration, max uses)
2. Visit saved to Supabase with status "active"
3. Open visit detail → tap "Generate QR Code"
4. Calls `generate-qr` Edge Function → gets signed JWT
5. QR rendered with qr_flutter
6. Share via WhatsApp/messages with share_plus

### Guard Flow
1. Open Scan tab → camera activates
2. Scan QR code → sends token to `validate-qr` Edge Function
3. If valid: shows visitor name, document, property, resident info
4. Guard taps "Approve Entry" → calls `confirm-access` Edge Function
5. Access logged, visit usage incremented
6. If invalid: shows error reason (expired, used, cancelled, etc.)

---

## Theme

Matches admin dashboard design system:
- Primary accent: #2563EB (blue)
- Dark mode support (follows system)
- Material Design 3
- Card-based UI with subtle borders

---

## Dependencies

See `pubspec.yaml` for full list. Key ones:
- supabase_flutter: ^2.8.0
- flutter_riverpod: ^2.6.1
- go_router: ^14.8.1
- qr_flutter: ^4.1.0
- mobile_scanner: ^6.0.2
- share_plus: ^10.1.4

---

## Requirements

- macOS 14+ (for Flutter development)
- Xcode 15+ (for iOS builds)
- Android Studio (for Android builds)
- Flutter SDK 3.2+

