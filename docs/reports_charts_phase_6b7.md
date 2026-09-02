# Phase 6B.7 - Chart Filters & Interaction

## Architecture

Analytics owns local filter state. `ReportFilter` is an immutable Riverpod
family key containing `ReportRange`, `accountId`, and `categoryId`. The report,
financial trend, Income vs Expense, and expense-category queries use the same
optional transaction predicates.

Reports remains period-only and concise. It passes its resolved date range in
the Analytics route. Changes made in Analytics stay local and do not modify the
Reports screen or create navigation entries.

No type filter was added. The current comparison charts need both Income and
Expense series, and Reports has no shared type-filter interaction to reuse.

## Filter Behavior

- Period chips apply immediately: Semua, Hari ini, Minggu ini, Bulan ini,
  Tahun ini, and Rentang.
- The account/category bottom sheet applies both selections only after
  `Terapkan`.
- Active filter chips show the selected account and category. Each chip can be
  removed independently.
- `Reset` restores Bulan ini, Semua Akun, and Semua Kategori.
- Account and category filters affect Income vs Expense, Expense by Category,
  and Financial Trend through the same SQL conditions.
- Saldo per Akun remains the global current asset position. Period, account,
  and category filters do not change it.
- Account options normally show active accounts. An account archived while
  selected remains visible with a `(diarsipkan)` label so historical filtering
  remains stable.
- A deleted/missing account or category ID falls back safely to the unfiltered
  value on the next option-stream update.
- Empty filtered results use `Tidak ada data untuk filter ini.`

## Financial Rules

Transaction queries retain these definitions:

```text
Income  = active income transactions matching ReportFilter
Expense = active expense transactions matching ReportFilter
Net     = Income - Expense
```

Transfers never enter the transaction chart queries. Initial balances never
enter those queries. Current account balances continue to come from
`AccountRepository.watchSummaries()`.

The deterministic filter fixture produced:

```text
Global                     Income 6.000.000  Expense 1.800.000
Account BCA                Income 5.000.000  Expense 1.500.000
Category Makanan           Income         0  Expense 1.300.000
BCA + Makanan              Income         0  Expense 1.000.000
```

Report totals, trend sums, and category expense sums reconciled exactly for
each applicable filter.

## Interaction And Formatting

- `fl_chart` retains built-in bar/point touch highlighting and exact IDR
  tooltips.
- Category and account rows now open exact-value tooltips on tap.
- Category tooltips include the category name, exact IDR amount, and share of
  the displayed expense total.
- Weekly/monthly tooltip labels clip partial buckets to the selected custom
  range.
- Axis values remain compact; tooltip values remain exact.
- The sentinel range for `Semua` is displayed as `Semua transaksi`.
- `Semua` chart data trims leading and trailing empty sentinel buckets instead
  of creating months through 2100.

## Performance

All transaction charts continue to aggregate in SQLite. No renderer loads raw
transactions and no N+1 account/category query was introduced. On the existing
10,000-transaction benchmark, the combined account/category report and chart
queries completed in about 9 ms on the validation machine. This timing is
informational and does not gate CI.

Existing date, account, category, and deleted-state indexes remain adequate for
the measured workload. No speculative composite index or schema migration was
added.

## Validation

- `dart format .`: passed
- `flutter analyze`: passed with no issues
- `flutter test`: 219 tests passed
- `flutter build apk --debug`: passed
- APK: `build/app/outputs/flutter-apk/app-debug.apk`

Coverage includes value equality, period/account/category/combined filters,
reconciliation, transfer and initial-balance exclusion, account-balance filter
independence, archived selection safety, reset, rapid period changes, partial
bucket tooltips, tap tooltips, responsive layout, and 10,000-row filtered query
performance.

## Known Limitations

- Account/category selections are local UI state and are not deep-linked or
  persisted across app restarts.
- Reports exposes period controls only, so only the period is handed to
  Analytics.
- There is no type filter, drill-down, zoom, pan, or persistent chart selection.
- Very long real-world histories still use monthly points; this remains a
  deliberate readability/performance tradeoff.
