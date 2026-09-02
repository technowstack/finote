# Phase 6B.5 Financial Trend Chart

## Placement

`Analisis Grafik` now presents sections in this order:

```text
Arus Keuangan
  Pemasukan vs Pengeluaran

Pengeluaran
  Pengeluaran per Kategori

Tren Keuangan
  Tren Keuangan
```

The main Reports page keeps its existing summary and Income versus Expense
preview. It does not include the full trend chart.

## Metrics And Data Source

`FinancialTrendChart` renders three lines from the existing
`financialTrendProvider(range)`:

```text
Net     = Income - Expense
Income  = active Income transactions
Expense = active Expense transactions
```

Net uses the primary solid line. Income and Expense use thinner, distinct dash
patterns and Finote's semantic income and expense colors. The legend names all
three series, so users do not need color alone to identify them.

`ReportRepository.watchFinancialTrend` remains the financial source of truth.
It groups transactions in one Drift query and returns integer
`FinancialTrendPoint` values. The chart converts integers to `double` only when
it builds `FlSpot` values for `fl_chart`.

Transfers and initial account balances live outside this query. Transfer
create/edit/delete and initial-balance edits cannot change Income, Expense, or
Net. Historical transactions from archived accounts remain included.

## Grouping And Empty Buckets

The chart uses `chartGranularityFor` from Phase 6B.1:

- ranges through 62 days use daily buckets;
- ranges from 63 through 180 days use Monday-based weekly buckets;
- longer ranges use monthly buckets.

Today, Week, Month, Year, Custom, and All therefore follow the same grouping as
the Income versus Expense chart. `_completeTrend` supplies every intermediate
bucket with integer zero values. A year produces 12 points regardless of the
transaction count.

The screen shows `Belum ada data tren pada periode ini.` when every bucket has
zero Income and Expense. It does not render a flat zero chart.

## Negative And Zero Net

Expense values stay positive. `FinancialTrendPoint.net` subtracts Expense from
Income and may return a negative integer. The renderer preserves that sign,
expands the Y axis below zero, and draws a dashed zero baseline. It does not
clamp Net.

The Y axis uses compact IDR values, including `-Rp1 jt`. Point tooltips show the
localized period and exact Pemasukan, Pengeluaran, and signed Net values.

## Filters And Reactivity

Analytics currently supports a date-period selector only. It has no account,
category, or type filter. All three charts watch the same local `ReportRange`;
changing that period updates them together.

The Drift stream reacts to transaction creation and edits to amount, type,
date, category, or account. Soft deletion removes the contribution. Category
and account reassignment leave global totals unchanged while keeping the chart
reactive. Phase 6B.7 owns future filter semantics.

## Reconciliation

For one range:

```text
SUM(Trend Income)  = Reports Income = Income vs Expense Income
SUM(Trend Expense) = Reports Expense = Income vs Expense Expense
SUM(Trend Net)     = Reports Income - Reports Expense
SUM(Trend Expense) = Expense by Category total
```

Tests enforce these equations across Today, Week, Month, Year, and Custom
ranges.

## Theme, Layout, And Accessibility

The chart uses the existing Material 3 card, spacing, typography, ColorScheme,
loading, error, retry, and empty states. It limits X-axis labels while retaining
all points. A wrapping text-and-icon legend, clipped plot area, fitted tooltip,
64 dp Y-axis gutter, and compact labels support small phones, landscape, and
moderate text scaling.

Light, Dark, and System themes supply line, grid, baseline, axis, and tooltip
colors. The chart exposes a semantic summary with each non-zero period and its
exact three values.

## Performance

The implementation reuses the existing grouped SQL query and Riverpod family.
The Income versus Expense and Financial Trend sections watch the same provider
instance for the same range. No per-bucket query, raw transaction scan, second
cache, network call, or persisted chart data was added.

The existing 10,000-transaction benchmark checks the grouped chart path. A
yearly range returns 12 monthly points rather than one point per transaction.

## Tests

Automated coverage includes:

- positive, negative, and zero Net points;
- income-only, expense-only, mixed, zero, and large values;
- exact tooltip values, legend labels, semantics, and zero baseline;
- localized daily and monthly labels without dropping data points;
- the deterministic Rp5,000,000 Income, Rp2,000,000 Expense, and Rp3,000,000
  Net fixture;
- complete empty buckets and adaptive granularity;
- amount, type, date, category, account, and soft-delete reactivity;
- transfer create/edit/delete, initial-balance edit, and archive exclusion;
- Reports, Income versus Expense, and category reconciliation;
- dark, narrow, landscape, and scaled-text rendering;
- Reports-page, export, backup/restore, and performance regressions through the
  full suite.

## Known Limitations

Analytics does not yet offer account, category, or type filters. The chart has
basic touch tooltips only. Phase 6B.7 may add shared filters or richer
interaction. Phase 6B.6 owns Account Balance Visualization and remains
unstarted.
