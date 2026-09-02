# Phase 6B.2 Income vs Expense Chart

## Implementation

Reports now renders a grouped Income versus Expense bar chart immediately after
the financial summary. The chart watches `financialTrendProvider(range)` and
renders its normalized `FinancialTrendPoint` values with `fl_chart`; it does
not load transactions or recalculate report totals.

The existing adaptive grouping remains authoritative:

- Today, current week, and current month use daily buckets.
- A dedicated current-year selector uses twelve monthly buckets.
- Custom ranges use daily, weekly, or monthly buckets based on their length.
- Missing periods remain visible as zero-value buckets.

Long ranges keep every bucket but sample the visible x-axis labels to avoid
crowding. The y-axis uses compact IDR formatting. Touch tooltips retain exact
IDR values and show both series for the selected period.

## Financial Semantics

The chart uses the same grouped Drift data as Reports:

```text
Income  = active Income transactions
Expense = active Expense transactions
Net     = Income - Expense
```

Transfers and initial account balances never enter either series. Soft-deleted
transactions are excluded. Amounts remain integers until each bar value crosses
the `fl_chart` rendering boundary.

Automated checks reconcile both chart series with Reports for Today, Week,
Month, Year, and Custom ranges. Existing export and backup behavior is
unchanged.

## UX And Accessibility

- Income and Expense use the existing semantic `ColorScheme` colors.
- Directional icons and text legends distinguish the series without color
  alone.
- The chart exposes exact period values as one accessibility description.
- Empty and all-zero ranges show `Belum ada transaksi pada periode ini.`
- Loading and failures reuse `ReportChartSection` with a safe retry action.
- Layout and labels were exercised on a 320-pixel-wide dark-theme viewport.
- Animations respect the platform disable-animations preference.

## Scope

No database schema, dependency, export, backup/restore, network, telemetry, or
cache changed. Category, line-trend, account-balance, and advanced chart
interaction remain deferred to Phases 6B.3 through 6B.7.
