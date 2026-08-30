# Financial Accuracy Audit

## Definitions

- **Source of truth:** active rows in `transactions` (`deleted_at IS NULL`).
- **Income:** positive `amount` with `type = income`.
- **Expense:** positive `amount` with `type = expense`.
- **Balance:** `totalIncome - totalExpense`.
- **Date semantics:** local calendar dates, stored and compared as `YYYY-MM-DD`.
- **Week semantics:** Monday through Sunday.
- **Custom ranges:** inclusive start and end dates; reversed ranges are rejected.
- **Filtered summaries:** totals describe the exact filtered dataset. An expense-only
  dataset therefore has zero income and a negative balance equal to its expenses.

## Calculation Paths Audited

- Dashboard summary SQL calculates active balance, current-month totals, and today's count.
- Reports SQL calculates active period totals, count, category aggregates, and monthly history.
- Transaction history applies active/type/date/search filters and calculates its visible summary.
- Export repository resolves active filtered transaction rows; all exporters consume that model.
- Backup/restore and legacy import preserve integer transaction amounts and do not supply totals.

## Findings and Fixes

### Medium: report summary did not expose transaction count

- **Root cause:** `ReportData` contained income/expense totals but not count, while exports
  counted their resolved rows independently.
- **Fix:** Added shared `FinancialSummary` and `ReportData.transactionCount` from the same
  SQL filtered dataset.
- **Coverage:** Report tests now assert count for populated and empty periods; export tests
  compare report totals with the normalized export document.
- **Remaining risk:** Dashboard intentionally exposes today's count, not a full-period count.

### Low: date-period calculations were duplicated in UI screens

- **Root cause:** Reports and Transaction History each implemented week/month boundaries.
- **Fix:** Added `resolveFinancialDateRange` and reused it in Reports, Transaction History,
  and Dashboard month calculations.
- **Coverage:** Monday-week, custom inclusive, reversed, month, and year-boundary tests.
- **Remaining risk:** The Reports all-time option still uses its existing 2000-2100 bounds.

## Verified Consistency

- Soft-deleted transactions are excluded from dashboard, reports, history, and exports.
- Income and expense totals use positive integer amounts without double-negation.
- Category aggregation is grouped by category and transaction type.
- Top categories are ranked by aggregated nominal amount.
- Monthly history groups by the stored local `YYYY-MM` date prefix.
- Report/export totals reconcile for the deterministic synthetic dataset.
- Editing a transaction from expense/July to income/August moves it between both periods.
- Empty reports and exports produce zero totals without `NaN`, `null`, or infinity values.

## Remaining Risks

- Real-device restore/provider refresh validation remains pending.
- Legacy imports use the existing shared legacy source identity; cross-file ID collisions
  remain documented in `docs/core_stability_audit.md`.
- Large transaction-history UI performance still needs device measurement.
- Manual Android export validation remains pending.
