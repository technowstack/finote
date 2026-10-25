# Inventaris Screen dan Komponen

## Ringkasan route

| Screen | Route | Source |
|---|---|---|
| Dashboard/Beranda | `/` | `lib/features/dashboard/presentation/dashboard_page.dart` |
| Transaksi | `/transactions` | `lib/features/transactions/presentation/transactions_page.dart` |
| Tambah transaksi | `/transactions/new` | `transaction_form_page.dart` |
| Detail transaksi | `/transactions/:id` | `transaction_detail_page.dart` |
| Ubah transaksi | `/transactions/:id/edit` | `transaction_form_page.dart` |
| Riwayat bulanan | `/reports/history/:month` | `monthly_transactions_page.dart` |
| Portofolio | `/portfolio` | `assets_page.dart` |
| Detail aset | `/portfolio/assets/:id` | `assets_page.dart`/detail class |
| Laporan | `/reports` | `reports_page.dart` |
| Analisis grafik | `/reports/analytics` | `analytics_chart_page.dart` |
| Akun & Dompet | `/accounts` | `accounts_page.dart` |
| Transfer | `/transfers` | `transfers_page.dart` |
| Kategori | `/categories` | `category_page.dart` |
| Pengaturan | `/settings` | `settings_page.dart` |
| Keamanan | `/security` | `security_page.dart` |
| Backup/restore | `/backup` | `backup_page.dart` |
| Import lama | `/legacy-import` | `legacy_import_page.dart` |
| Scan struk | `/receipt-scan` | `receipt_scanner_page.dart` |

## Detail per screen

### Dashboard / Beranda

- **Purpose:** ringkasan kekayaan bersih, cash/wallet, portfolio, saldo bulan berjalan, dan transaksi terbaru.
- **Structure:** `Scaffold` + `AppBar` + `RefreshIndicator` + `ListView`; summary card, scan receipt CTA, section recent transactions (`dashboard_page.dart:65-133`).
- **State/data:** `dashboardSummaryProvider`, `netWorthProvider`, `dashboardRecentTransactionsProvider` (`60-63`). Midnight timer dan resume lifecycle invalidate dashboard summary (`23-57`).
- **Components:** `_Summary`, `_NetWorthCard`, `_MonthlyBalanceCard`, `_MetricTile`, `_RecentTransactionsList`; `SectionHeader`, `AppErrorState`, `AppEmptyState`, `CurrencyText`.
- **States:** loading/error/empty recent transactions; net worth shows inline loading/error/partial message; summary failure has retry.
- **Navigation:** `Lihat semua` → `/transactions`; portfolio row → `/portfolio`; scan → `/receipt-scan`.
- **UX audit:** HIGH — financial summary combines cash and portfolio in one visual hierarchy; partial valuation is only a small supporting message. MEDIUM — list is vertical and likely scrollable, but no explicit quick add inside content beyond shell FAB.
- **Responsive:** currency uses `FittedBox`; metric tiles use `Expanded`, so narrow widths need runtime text-scale validation.
- **Screenshot:** `assets/playstore/1. dashboard.jpg` is recognizable correspondence, not runtime proof.

### Transaction History

- **Purpose:** unified history of income, expense, transfer, search, type/date/account/category filters.
- **Structure:** app bar search toggle, horizontal filter row, optional active filter chips, stream-driven list (`transactions_page.dart:69-180` and later list builders).
- **Data:** `financialActivityProvider(FinancialActivityQuery)` uses SQL `UNION ALL` with left joins (`financial_activity_repository.dart:14-167`).
- **Components:** `SearchBar`, filter chips, `FinancialActivity` rows, `AppLoadingState`, `AppEmptyState`, `AppErrorState`, FAB from `MainScaffold`.
- **States:** loading, error/retry, empty, populated; deletion uses SnackBar.
- **Navigation:** row to transaction detail or transfer handling; add FAB → bottom sheet → `/transactions/new`; search/filter remains local state.
- **UX audit:** MEDIUM — filter controls are horizontally scrollable; discoverability of advanced filters depends on the `Filter` button. LOW — active filters can become visually separated from primary type chips.
- **Responsive:** horizontal scrolling is intentional; trailing money is constrained/fitted in list code. Needs large-font validation.

### Add/Edit Transaction

- **Purpose:** manual income/expense entry, editing, receipt draft review, optional title/note, category/account/date.
- **State:** initialization first watches `categoryInitializationProvider`; edit additionally watches `transactionByIdProvider` (`transaction_form_page.dart:31-59`). Form state owns amount/title/note controllers, type/date/category/account and saving flag (`67-120`).
- **Layout:** `Scaffold`, app bar, bottom fixed save button, `Form` inside `ListView`; amount is hero field and type toggle (`144-220`).
- **Validation/business:** integer IDR parser/formatter, category required, account selection, type change resets category; save delegates `TransactionRepository` and receipt save paths.
- **States:** loading/error for category/edit load; disabled save while loading/saving; success returns/navigates; errors are user-friendly SnackBars.
- **Navigation:** new/edit from shell FAB/history/detail; receipt draft from scanner.
- **UX audit:** HIGH — form visibility depends on global default-category initialization; a seed failure blocks even a new transaction. MEDIUM — fixed bottom CTA competes with keyboard and long form; runtime keyboard/text scaling should be tested.
- **Screenshot:** `assets/playstore/2. transaksi.jpg` likely corresponds to this area, but exact state is not verified.

### Reports

- **Purpose:** period summary, transaction history tab, categories/month totals, investment cashflow, account/current assets and exports.
- **Structure:** app bar export action, `TabBar` Ringkasan/Riwayat, horizontal period chips, `TabBarView` (`reports_page.dart:60-148`).
- **Data:** `reportProvider`, `investmentCashflowProvider`, `netWorthProvider`, `financialTrendProvider`, `accountSummariesProvider` (`51-58`).
- **States:** report loading/error; export catches failure with SnackBar; chart subsections have their own loading/error handling.
- **Navigation:** analytics screen; monthly history; export dialog → save/share Excel/Text/PDF.
- **UX audit:** HIGH — one screen combines period selection, cashflow, current point-in-time account/portfolio concepts, charts, and export. This is a cognitive-load risk even if accounting semantics are intentionally separated.
- **Screenshot:** `assets/playstore/3. laporan.jpg` is likely correspondence.

### Financial Charts / Analytics

- **Route/source:** `/reports/analytics`, `analytics_chart_page.dart`.
- **Features:** period chips, date range, account/category filter, trend chart, expense category chart, account balance chart; chart granularity depends on range (`analytics_chart_page.dart:23-92`).
- **Components:** `FinancialTrendChart`, `ExpenseCategoryChart`, `AccountBalanceChart`, `ReportChartSection`.
- **State/data:** report chart providers and `ReportRepository` queries; no market request in inspected chart path.
- **UX audit:** MEDIUM — charts are vertically stacked and require scrolling; LOW — dense legend/labels may need large-font and narrow-screen validation.
- **Navigation:** reports page can open it with period handoff encoded in query parameters; invalid URI falls back to current month (`28-46`).
- **Screenshot:** `assets/playstore/4. grafik.jpg` likely correspondence.

### Investment Portfolio

- **Purpose:** active and archived assets, holdings, valuation, price refresh, asset CRUD.
- **Structure:** app bar with explicit `Refresh Harga`, stream state, summary, grouped active assets, archived section (`assets_page.dart:148-220`).
- **State/data:** `assetHoldingsProvider`, `allAssetHoldingsProvider`, `portfolioMarketQuotesProvider`, `activeAssetPricesProvider`, `portfolioValuationProvider`.
- **Business:** API/manual prices; local holdings are source; market refresh only from explicit button (`159-185`).
- **States:** loading/error/empty; partial/unvalued portfolio; archived assets; market refresh success/partial/failure SnackBar.
- **Navigation:** asset detail and forms; dashboard net worth portfolio row → portfolio.
- **UX audit:** HIGH — portfolio value can be partial, but the main summary remains a monetary number; the partial state must stay prominent. MEDIUM — active/archived assets in one scroll can increase scanning cost.
- **Responsive:** asset rows and price values use fitting/constrained layouts in lower classes; explicit large-font audit remains needed.
- **Screenshot:** `assets/playstore/5. portfolio.jpg` likely correspondence.

### Accounts & Wallets

- **Purpose:** account CRUD, initial balance, active/archive/delete rules, account summaries.
- **Structure:** app bar transfer action, FAB, stream-driven `ListView.separated` of `_AccountCard` (`accounts_page.dart:152-201`). Forms are dialogs.
- **State/data:** `accountSummariesProvider`; `AccountRepository.watchSummaries()` aggregates income/expense/transfers.
- **Safety:** default account cannot archive; account with history can archive but not permanently delete; unused non-default account can delete after confirmation.
- **UX audit:** MEDIUM — account state, balance, archive, and permanent delete actions are mixed in card/menu interactions; clear distinction is important.
- **Screenshot:** `assets/playstore/6. account & wallet.jpg` likely correspondence.

### Account Details

**NOT IMPLEMENTED as a distinct route in the inspected router.** Account balances and actions are represented on `/accounts`; there is no `/accounts/:id` route. Any detail-like card behavior is embedded in `AccountsPage`.

### Categories

- **Purpose:** list by expense/income, add/rename/soft-delete category.
- **Structure:** app bar, segmented button, card containing divided list, FAB (`category_page.dart:24-72`, `100-145`).
- **Data:** `categoryInitializationProvider`, `categoriesByTypeProvider`, `CategoryRepository`.
- **States:** initialization loading/error; list loading/error/empty; CRUD SnackBars.
- **UX audit:** MEDIUM — deletion semantics are soft delete but copy says category “tidak akan muncul lagi”; users may not understand historical references remain. HIGH historical risk — duplicate/soft-deleted category combinations previously caused `getSingleOrNull()` failure during seeding; current seeder tolerates multiple rows but active/retired identity remains a data-model concern.

### Settings

- **Purpose:** hub for accounts, categories, backup/restore, legacy import, reset data, theme, security, about link.
- **Structure:** grouped `ListView` with Data/Tampilan/Keamanan/Tentang (`settings_page.dart:17-95`).
- **Reset:** two confirmation dialogs, loading guard, invalidates market quote state, executes `resetDataServiceProvider` (`99-185`).
- **UX audit:** HIGH — destructive reset sits in the same Data group as routine navigation; confirmation is strong, but recovery/backup expectations should be continuously tested.

### Security / PIN / Biometrics

- **Routes:** `/security`; root gate is `AppLock` in `FinoteApp`.
- **Security page:** PIN create/change/disable, 4/6 digit selector, biometric card (`security_page.dart:55-149`).
- **Gate:** initialized black loading gate; locked state displays PIN or biometric unlock and never returns child before unlock (`app_lock.dart:36-69`).
- **UX audit:** HIGH — enable/disable and lifecycle semantics are security-critical and require device runtime validation. MEDIUM — security page mixes PIN and biometric controls; capability/unavailable states need explicit hierarchy.

### Backup & Restore

- **Structure:** two tabs, Backup and Restore; backup card with system file picker note (`backup_page.dart:41-58`, `77-131`). Restore is a linear state machine: idle → validating → preview → safety backup → confirming → restoring → success/error (`166-249`).
- **Data:** `BackupService` creates ZIP containing `database.sqlite` and `manifest.json`, validates SQLite integrity/schema/foreign keys, creates safety backup, then replaces DB atomically with rollback path (`backup_service.dart:34-95`, `116-179`, `239-311`).
- **UX audit:** HIGH — restore is destructive and complex; preview/safety backup is appropriate, but external picker/lifecycle/App Lock interactions require runtime checks.

### Legacy Import

- **Structure:** state machine idle/detecting/compatible/importing/success/incompatible/failed (`legacy_import_page.dart:20-83`).
- **Features:** file picker, detector, preview, read-only source SQLite, atomic import, progress and summary.
- **Business:** maps legacy type `0/1`, category subtype names, default account, repeat-safe legacy source/id.
- **UX audit:** HIGH — category matching depends on exact `(name,type)` identity and excludes soft-deleted categories; this can create a new active category after a user soft-deletes the matching default. The current seeder no longer assumes only one historical row.

### Receipt Scanner

- **Purpose:** local image picker/camera + ML Kit OCR + rule parser, producing editable draft rather than automatic final transaction. **TERVERIFIKASI** from source/imports and tests; stable production status remains conditional in README/STATUS.
