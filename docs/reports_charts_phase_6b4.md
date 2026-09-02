# Phase 6B.4 Category Expense Chart

## Scope

The dedicated `Analisis Grafik` screen includes a donut Expense by Category
chart below the existing Income versus Expense section. A numeric breakdown
remains below the donut. Reports stays concise and does not render this full
category visualization.

The chart shows the five categories with the largest expenses. Any remaining
categories are combined into a presentation-only `Lainnya` slice and row. The
same grouped dataset drives both the donut and numeric breakdown, preserving
the exact total.

## Financial Source Of Truth

`expenseCategoryChartProvider(filter)` watches
`ReportRepository.watchExpenseCategories(filter.range)`. The Drift query aggregates
in SQLite by category and date range rather than loading transaction rows into
the widget.

Only active Expense transactions contribute to the result:

```text
Category Expense = SUM(active Expense transaction amounts)
```

Income, Transfer, Initial Balance, and soft-deleted transactions remain
excluded. Archived categories retain their historical names. A malformed
historical transaction whose category no longer exists is grouped under
`Kategori tidak tersedia`, so its expense remains visible and category totals
still reconcile with Reports.

For an equivalent period:

```text
SUM(all category amounts) = Report total expense = Expense chart total
```

No schema, backup, export, or account-balance behavior changed.

## Presentation

- Categories are ordered by expense descending, then category name and ID for
  stable ties.
- A donut uses stable Material color-scheme-derived palette slots by display
  order; `Lainnya` uses a neutral outline color.
- The center shows total filtered expense, or the selected slice amount and
  percentage after a tap.
- The breakdown shows a color indicator, category name, percentage, and exact
  IDR amount.
- Tapping a breakdown row selects its slice; tapping it again returns to the
  total.
- Each row provides an accessibility label containing the category, percentage,
  and exact amount.
- Empty and zero-only input uses the shared empty-state presentation.
- Long labels use ellipsis; the chart remains vertically scrollable as part of
  the single Analytics page list.
- Colors come from the Material theme and support Light, Dark, and System mode.

## Reactivity And Periods

The chart uses the same local Analytics `ReportRange` as Income versus Expense.
Changing Today, Week, Month, Year, Custom, or All refreshes both sections.
Transaction creation, amount/category/type/date edits, and soft deletion update
the Drift stream without manual screen refresh.

## Tests

Automated coverage verifies:

- the Rp2,200,000 multi-category fixture and deterministic sorting;
- reconciliation with Report and Income versus Expense totals;
- Income, Transfer, Initial Balance, and soft-delete exclusion;
- archived, custom, and missing category handling;
- reactive amount, category, type, date, and delete changes;
- Top 5 plus `Lainnya` across 10 categories without double counting;
- empty, zero, single-category, long-label, large-value, dark, and narrow UI;
- donut section values, selected-center state, and accessibility semantics;
- shared Analytics period changes and Reports remaining concise.

## Deferred

Advanced chart interaction and additional chart types remain deferred to their
explicitly planned Phase 6B work. The existing Analytics `ReportFilter`
period/account/category semantics apply to this chart.
