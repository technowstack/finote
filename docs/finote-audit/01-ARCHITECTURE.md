# Audit Arsitektur

Legenda: **TERVERIFIKASI** = terlihat langsung di source/config; **INFERENSI** = kesimpulan dari beberapa bukti; **TIDAK TERVERIFIKASI** = tidak dapat dibuktikan dari source yang dibaca.

## Stack

| Area | Temuan |
|---|---|
| Bahasa | **TERVERIFIKASI:** Dart; Android build memakai Kotlin DSL. |
| Framework | **TERVERIFIKASI:** Flutter, Material 3. `pubspec.yaml:30-58`, `app_theme.dart:240-325`. |
| Versi aplikasi | **TERVERIFIKASI:** `1.3.0+3`, `pubspec.yaml:19`; Android target SDK 36 dan compile SDK 37, `android/app/build.gradle.kts:15-36`. |
| State/DI | **TERVERIFIKASI:** Riverpod 2.6.1; `ProviderScope` di `lib/main.dart:7-10`, provider global/family/autoDispose di feature data. |
| Routing | **TERVERIFIKASI:** GoRouter 18 dengan `StatefulShellRoute.indexedStack`, `lib/app/router.dart:22-157`. |
| Database | **TERVERIFIKASI:** Drift 2.34, SQLite lokal; `AppDatabase` schema version 11, `lib/core/database/app_database.dart:25-43`. |
| Network | **TERVERIFIKASI:** `dart:io HttpClient` hanya untuk Market API, `market_api_client.dart:155-186`. |
| Auth lokal | **TERVERIFIKASI:** `local_auth`, secure storage untuk PIN verifier, SharedPreferences untuk flag biometrik. |

## Bootstrap

`main()` memastikan Flutter bindings, memuat locale `id_ID`, lalu menjalankan `ProviderScope(child: FinoteApp())` (`lib/main.dart:7-10`). `FinoteApp` memasang theme, locale Indonesia, router provider, logger listener untuk default category/account, dan membungkus route dengan `AppLock` (`lib/app/app.dart:13-51`).

`databaseProvider` membuat satu `AppDatabase`, mendaftarkan `onDispose(database.close)`, dan memakai `driftDatabase(name: 'finote')` bila executor tidak diberikan (`app_database.dart:37-42`, `208-212`). **INFERENSI:** aplikasi dimaksudkan memakai satu database shared melalui root Riverpod.

## Pola folder

```text
lib/
├── main.dart                         bootstrap Flutter
├── app/                              app shell, router, bottom navigation
├── core/
│   ├── config/                       compile-time config
│   ├── database/                     Drift database, converters, tables
│   ├── errors/                       error mapping
│   ├── finance/                      derived financial summaries/net worth
│   ├── services/                     logging
│   ├── theme/                        colors, spacing, themes, theme mode
│   ├── utils/                        dates, currency, UUID, ranges
│   └── widgets/                      reusable UI states and money widgets
└── features/
    ├── dashboard/                    summary/home
    ├── transactions/                 transaction model, repository, screens
    ├── transfers/                    account-to-account transfers
    ├── accounts/                     wallets/accounts
    ├── categories/                   category CRUD
    ├── reports/                      period reports and charts
    ├── export/                       document model and exporters
    ├── assets/                       asset CRUD, activities, holdings
    ├── market/                       prices, quote client, valuation
    ├── backup/                       ZIP backup/restore
    ├── legacy_import/                old SQLite import
    ├── app_lock/                     PIN/biometric security
    ├── settings/                     settings/reset
    └── receipt_scanner/               local OCR experimental flow
```

## Dependency/data flow

```text
Widget
  → ref.watch/provider family
  → Repository/Service
  → Drift query or local secure/platform API
  → domain record/value object
  → AsyncValue/Stream rebuild
```

Database tables: `accounts`, `categories`, `transactions`, `transfers`, `settings`, `assets`, `asset_transactions`, `asset_prices` (`app_database.dart:25-35`). Tables are in `lib/core/database/tables/`.

## Migrations

**TERVERIFIKASI:** additive migration gates from schema 1–11 create receipt fingerprint, accounts, account relation/backfill, transfers, assets, asset prices, and indexes (`app_database.dart:45-117`). Foreign keys are enabled in `beforeOpen` (`114-116`).

## Build/platform

- Android namespace/application ID pada source saat audit: `com.technowstack.finote`; target SDK 36, Java/Kotlin 17 (`android/app/build.gradle.kts:15-74`).
- Manifest requests CAMERA, INTERNET, USE_BIOMETRIC; `allowBackup=false` (`android/app/src/main/AndroidManifest.xml:1-10`).
- `pubspec.yaml` also declares iOS launcher icon configuration, but **TIDAK TERVERIFIKASI** apakah iOS build/runtime pernah divalidasi.
- Test tree memiliki unit, widget, migration, performance, export, backup, App Lock, market, and feature tests. **TERVERIFIKASI:** repository memiliki test coverage luas; total current pass rate harus diambil dari command terbaru, bukan diasumsikan dari `STATUS.md` historis.

## Dependency categories

Riverpod/GoRouter/Drift; local storage (`path_provider`, `sqlite3`, `shared_preferences`, `flutter_secure_storage`); document/file (`archive`, `file_picker`, `share_plus`, `pdf`); auth (`local_auth`, `cryptography`); charts (`fl_chart`); scanner (`image_picker`, `permission_handler`, `google_mlkit_text_recognition`); utility (`intl`, `uuid`, `url_launcher`, `package_info_plus`).

## Boundary notes

- No user account/cloud sync implementation was found in inspected paths.
- Market requests are external but core finance/holdings source is local.
- `app_database.g.dart` is generated Drift output; it should not be hand-edited.
