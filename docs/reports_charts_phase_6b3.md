# Phase 6B.3 Analytics Chart Screen

## Hybrid UX

Reports remains the quick financial overview. It keeps the financial summary,
Income versus Expense preview, category summaries, account balances, and
transfer summary. A small `Lihat Analisis Grafik` action below the preview opens
the detailed chart screen.

`Analisis Grafik` is a full-screen route at `/reports/analytics`. It uses one
vertical `ListView`, a horizontal period selector, and the shared
`ReportChartSection`. Phase 6B.3 renders only the existing Income versus Expense
chart under `Arus Keuangan`; later chart sections remain omitted until their
phases begin.

## Period Handoff

Reports sends the selected `ReportRange` as `start` and `end` ISO date query
parameters. The route accepts only valid calendar dates from 2000 through 2100
and falls back to the current month when parameters are absent or invalid.

Both screens use the shared `ReportPeriod`, `resolveReportRange`, and
`ReportRange` types, so Today, Week, Month, Year, Custom, and All retain the same
boundaries. Analytics changes its period locally. Returning with Back preserves
the Reports selection because navigation uses `context.push` and does not
mutate Reports state.

Reports does not currently expose account, category, or transaction-type
filters, so Phase 6B.3 carries only its active date range.

## Shared Chart Data

Reports preview and Analytics both watch `financialTrendProvider(range)` and
render `IncomeExpenseChart`. Riverpod shares the same provider family instance
while both routes use the same range, avoiding a second analytics aggregation
implementation.

The existing Drift query remains authoritative:

```text
Income  = active Income transactions
Expense = active Expense transactions
Net     = Income - Expense
```

Transfers, initial account balances, and account archive state do not enter the
query. Soft-deleted transactions disappear reactively. No network request,
cache, persisted chart data, or raw transaction scan was added.

## States And Layout

- `ReportChartSection` supplies independent loading, empty, error, and retry
  states.
- Empty ranges show `Belum ada transaksi pada periode ini.` while period
  controls remain available.
- Analytics uses a 340 dp chart area; Reports retains its compact 260 dp
  preview.
- The shared chart keeps exact IDR tooltips, compact axes, semantic Income and
  Expense colors, text legends, and accessibility values.
- The period selector scrolls horizontally. The screen scrolls vertically and
  avoids nested vertical scroll views.
- Widget coverage exercises a 320-pixel phone, landscape, 1.3 text scaling, and
  Dark theme. System theme continues through the app theme configuration.

## Tests

Automated coverage verifies:

- production GoRouter navigation from Reports to Analytics and Back;
- period handoff and preserved Reports state;
- direct-route current-month fallback and invalid query handling;
- local Analytics period changes;
- Reports preview, Analytics chart, and Report totals reconciliation;
- reactive transaction creation, amount edits, and soft deletion;
- transfer, initial-balance, and account-archive exclusion;
- empty, dark, narrow, landscape, and scaled-text rendering;
- existing Reports, export, backup/restore, and performance regressions through
  the full suite.

## Known Limitations

Analytics does not persist local period changes across a process restart. A
direct route starts from its query parameters or the current month. Category,
financial-trend, account-balance, advanced filter, and chart-polish work remains
deferred to Phases 6B.4 through 6B.8.
