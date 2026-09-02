# Phase 6B.1 Report Chart Foundation

## Existing Reports Architecture

`ReportsPage` resolves its period selector into a `ReportRange`. It watches
`reportProvider(range)` for period totals, category summaries, monthly history,
and transfer information. It separately watches `accountSummariesProvider` for
current account balances.

`ReportRepository.watchReport` uses one reactive Drift query with grouped SQL.
It excludes soft-deleted transactions, calculates Income and Expense from
transaction types, and keeps transfer count and volume in a separate result.
The Reports route remains `/reports` inside the GoRouter navigation shell.

## Chart Library

Finote uses `fl_chart ^1.2.0` for future chart rendering. The package supports
the project's Flutter 3.47.2 and Dart 3.13.2 toolchain, works offline, and
provides the bar, line, and pie primitives required by later 6B phases. No
second chart package or custom painter was added.

Phase 6B.1 does not render a production chart. This avoids shipping decorative
or incomplete chart UI before Phase 6B.2 defines the first visualization.

## Data Architecture

The implemented flow is:

```text
SQLite / Drift
      -> ReportRepository grouped queries
      -> integer chart models
      -> focused Riverpod providers
      -> ReportChartSection
      -> future fl_chart renderer
```

Models:

- `FinancialTrendPoint`: period, Income, and Expense.
- `CategoryChartPoint`: category identity, name, and Expense amount.
- `AccountBalanceChartPoint`: account identity, name, current balance, and
  archive state.

Providers:

- `financialTrendProvider(range)`
- `expenseCategoryChartProvider(range)`
- `accountBalanceChartProvider`

The first two providers use grouped SQL. They never load raw transaction
objects or issue one query per bucket/category. The account provider maps the
existing `AccountRepository.watchSummaries` stream, preserving the Phase 6A
balance formula and account ordering: active accounts first, then name.

## Financial Rules

All chart amounts remain integers through SQL, models, providers, and tests.
Future renderers may convert an integer to `double` only when passing a value to
`fl_chart`.

Trend data follows the same rules as Reports:

```text
Income  = active Income transactions
Expense = active Expense transactions
Net     = Income - Expense
```

The trend and category queries read only `transactions`. Transfers cannot
enter Income, Expense, or category values. Initial balances also cannot enter
these datasets. Soft-deleted transactions are excluded. Account archive state
does not remove transaction history.

Automated reconciliation compares the sum of trend points with
`ReportData.totalIncome` and `ReportData.totalExpense` for the same
`ReportRange`.

## Period Grouping

`chartGranularityFor` centralizes adaptive grouping:

- 1 through 62 days: daily buckets.
- 63 through 180 days: weekly buckets, starting Monday.
- More than 180 days: monthly buckets.

This gives Today, current week, and current month daily points. A year produces
monthly points. Medium custom ranges use weeks, while long custom ranges use
months.

The repository fills missing buckets with integer zero values. Daily points
use local financial calendar dates. Weekly SQL and completion use Monday as
the same deterministic boundary. Monthly points use the first calendar day of
each month. Results sort chronologically.

Expense categories sort by amount descending, then case-insensitive category
name, then category ID. This makes ties stable without random colors or order.

## Formatting And UI

`formatCompactIdr` formats axis-scale values such as `Rp500 rb`, `Rp1,5 jt`,
and `Rp1 M`. Models retain the integer amount. Existing `formatIdr` remains the
exact formatter for tooltips and details. Chart period and exact tooltip date
formatters use the existing `id_ID` locale.

`ReportChartSection<T>` provides a reusable Material 3 container with:

- title and optional subtitle;
- fixed, overridable default chart height;
- loading, empty, error/retry, and data states;
- user-safe Indonesian messages;
- a semantic container label.

The component derives colors and typography from `ThemeData`, so it works with
Light, Dark, and System modes. Future renderers must use the existing
`ColorScheme.incomeColor` and `expenseColor`, plus text/labels so color is not
the only signal. Tests cover a 320-pixel viewport with 1.3 text scaling.

## Performance And Persistence

Chart aggregation stays local and reactive through Drift. The 10,000-row
benchmark now measures monthly trend and category aggregation without brittle
time limits. Riverpod and Drift provide invalidation; no custom cache or broad
app invalidation was added.

No database schema, index, backup format, restore flow, export output, network
service, telemetry, or persisted chart dataset changed. Restored financial
records naturally regenerate chart data through the same reactive queries.

## Tests

Coverage includes:

- Reports-to-chart Income and Expense reconciliation;
- transfer and initial-balance exclusion;
- soft-delete exclusion;
- daily, weekly, monthly, month-boundary, and year-boundary buckets;
- zero-filled periods;
- deterministic Expense category aggregation;
- large integer precision;
- transaction create/edit/type/date/delete reactivity;
- shared account balance mapping;
- reusable loading, data, empty, and error states;
- Light/Dark rendering and small-screen text scaling;
- existing Reports, Export, Backup/Restore, and 10,000-row regressions through
  the full test suite.

## Known Limitations

- Phase 6B.1 provides no user-facing chart renderer or interaction.
- The existing Reports selector has no dedicated Year option; a year can be
  represented by a custom range and receives monthly buckets.
- Labels, tooltips, legends, and long-name behavior inside each final chart
  remain the responsibility of Phases 6B.2 through 6B.7.
