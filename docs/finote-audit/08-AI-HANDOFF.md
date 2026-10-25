# Finote — AI Handoff

## Product

Finote adalah personal finance tracker offline-first dengan transaksi income/expense, akun/dompet, transfer internal, laporan/export, backup/restore, import database Catatan Keuangan lama, App Lock PIN/biometrik, dan portfolio assets/investments.

## Verified stack

- Flutter/Dart; version app `1.3.0+3`.
- Material 3, Indonesian locale.
- Riverpod 2.6.1; GoRouter 18.
- Drift 2.34 + SQLite schema 11.
- Android target SDK 36/compile 37, Java/Kotlin 17.
- Packages: local_auth, flutter_secure_storage, cryptography, shared_preferences, file_picker, archive, pdf, share_plus, fl_chart, ML Kit, image picker, permissions.

## Architecture

`lib/main.dart` bootstraps locale and `ProviderScope`. `FinoteApp` applies theme/router/AppLock. `router.dart` owns route graph. Feature folders use presentation/data/domain selectively. Repositories query Drift; Riverpod providers expose streams/futures/state notifiers; widgets render `AsyncValue` states.

## Directory map

| Path | Responsibility |
|---|---|
| `lib/app/` | shell, router, bottom navigation, add menu |
| `lib/core/database/` | database, migrations, tables, converters |
| `lib/core/theme/` | Material themes, semantic colors, spacing, theme persistence |
| `lib/core/finance/` | financial summary and net worth derivation |
| `lib/core/widgets/` | shared loading/error/empty/money/section UI |
| `lib/features/transactions/` | transaction CRUD and unified history |
| `lib/features/accounts/` | account CRUD and balance summaries |
| `lib/features/transfers/` | account-to-account transfer CRUD |
| `lib/features/categories/` | category initialization/CRUD |
| `lib/features/reports/` | reports, period filters, charts |
| `lib/features/export/` | shared export document and Excel/Text/PDF |
| `lib/features/assets/` | assets, activities, holdings |
| `lib/features/market/` | prices, batch market API, valuation |
| `lib/features/backup/` | ZIP backup, validation, restore |
| `lib/features/legacy_import/` | legacy SQLite read-only import |
| `lib/features/app_lock/` | PIN/biometric store, controller, gate |
| `lib/features/settings/` | settings hub and reset |
| `lib/features/receipt_scanner/` | local OCR experimental draft flow |

## Major screens/routes

`/`, `/transactions`, `/transactions/new`, `/transactions/:id`, `/transactions/:id/edit`, `/portfolio`, `/portfolio/assets/:id`, `/reports`, `/reports/analytics`, `/reports/history/:month`, `/accounts`, `/transfers`, `/categories`, `/settings`, `/security`, `/backup`, `/legacy-import`, `/receipt-scan`. Exact source paths are in `02-SCREEN-INVENTORY.md`.

## Design system

Material 3, Roboto, centralized `ColorScheme` in `app_theme.dart`, semantic income/expense colors in `app_colors.dart`, spacing 4/8/12/16/24/32 in `app_spacing.dart`, card radius 12, dialog/sheet radius 16, input radius 12, stadium chips, circular FAB, floating SnackBars. Both light and dark themes exist; theme mode persists in SharedPreferences.

## Core business rules

- IDR is integer; no floating-point source of truth.
- `balance = income - expense` for flow summary.
- Account balance conceptually = initial + income − expense + incoming transfer − outgoing transfer.
- Transfers are not income/expense.
- Active transaction/report/export queries exclude soft-deleted rows.
- Holdings = opening + buy − sell + adjustment.
- Asset quantity scale is 1e8 integer.
- Buy/sell create one linked cashflow transaction atomically; opening/adjustment do not.
- Portfolio current value uses local/manual/last-known price; unknown price stays unknown.
- Net worth = account cash + known portfolio value; partial state remains partial.

## Navigation/state

Five-tab `StatefulShellRoute.indexedStack` preserves branch state. Full-screen routes overlay shell. Providers are reactive Drift streams or Riverpod state/future providers. AppLock wraps the entire router output.

## Offline/security

SQLite is local source of truth. Market API is optional and explicit-refresh only. PIN verifier uses secure storage + PBKDF2-HMAC-SHA256; biometrics use OS `local_auth`; no templates are stored. Backup is ZIP SQLite snapshot + manifest, with integrity/version/foreign-key validation and safety backup before restore.

## Important UX issues

1. Category seed failure can block transaction form.
2. Reports combines period flow and point-in-time wealth concepts.
3. Partial portfolio value needs prominent explanation.
4. History uses join-sensitive read paths.
5. Legacy import exact category identity interacts with soft delete.
6. App Lock/Reset/runtime release validation remains incomplete.
7. Horizontal filters and dense charts need large-text/accessibility testing.

## Unknowns/evidence gaps

- TalkBack, 200% text scale, screen reader traversal, and WCAG measurements.
- Complete Android biometric/lifecycle/enrollment runtime matrix.
- End-to-end reset → restart → restore runtime evidence.
- Production Market API behavior, TLS, availability, and privacy contract.
- iOS/web/desktop runtime parity.
- Exact current test pass count after all working-tree changes.

## Suggested inspection order

1. `lib/app/app.dart`, `router.dart`, `main_scaffold.dart`.
2. `core/theme/*`, `core/widgets/shared_widgets.dart`.
3. `core/database/app_database.dart` and all tables.
4. Transactions/accounts/transfers repositories and screens.
5. Reports/export repositories and screens.
6. Assets/market valuation and explicit refresh path.
7. Backup/restore/reset.
8. App Lock and Android manifest/config.
9. Tests matching each flow before proposing redesign.
