# Finote v1.3.0 - Phase 7D.3 Reports Integration

Status: **COMPLETE**

## Information architecture

Reports keeps period-based data separate from current point-in-time data:

- `Arus Kas`: Income, Expense, Net Flow, existing charts, and category analysis.
- `Arus Kas Investasi`: the shared `InvestmentCashflowSummary` for the selected
  report period and account scope.
- `Posisi Keuangan Saat Ini`: global current `NetWorthSnapshot`, independent of
  the selected period.

General cashflow continues to include `Pembelian Aset` as Expense and
`Penjualan Aset` as Income. Reports never sums `AssetTransactions`; linked
Buy/Sell cashflow is counted only through Transactions. Opening Position and
Adjustment do not enter cashflow.

## Filters and current state

Changing the report period changes Income, Expense, Net Flow, charts, and
investment cashflow. Current Cash, Portfolio, and Net Worth remain global and
point-in-time. The current investment section follows the existing report
period; it does not use arbitrary category filtering. Account-filter support is
available in the shared investment repository, while the current Reports page
does not expose an account selector.

Portfolio and Net Worth use local `PortfolioSnapshot` and `NetWorthSnapshot`.
Partial or unavailable prices remain explicitly marked as temporary; missing
prices are never converted to zero. Reports adds no market refresh control and
does not trigger the Market API.

The Account Balance visualization is labelled `Saldo per Akun` and its math is
unchanged. Reports does not add Portfolio charts, P/L, ROI, historical value,
or historical Net Worth timelines.

## Validation

Coverage includes Reports current-position rendering, investment cashflow
integration, existing period behavior, and the full regression suite. No schema
migration or dependency change was required.
