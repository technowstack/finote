# Phase 6B.4 Category Expense Chart

## Scope

The dedicated `Analisis Grafik` screen now includes a horizontal Expense by
Category chart below the existing Income versus Expense section. Reports stays
concise and does not render the full category chart.

The chart shows the six categories with the largest expenses. Any remaining
categories are combined into a presentation-only `Lainnya` row. This keeps the
screen readable for datasets with many categories while preserving the exact
total.

## Financial Source Of Truth

`expenseCategoryChartProvider(range)` watches
`ReportRepository.watchExpenseCategories(range)`. The Drift query aggregates
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

- Rows are ordered by expense descending, then category name and ID for stable
  ties.
- Horizontal bars are scaled against the largest visible category.
- Compact IDR values remain visible beside each bar.
- Tap or long press exposes an exact IDR tooltip.
- Each row provides an accessibility label containing the category and exact
  amount.
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
- Top 6 plus `Lainnya` across 30 categories without double counting;
- empty, zero, single-category, long-label, large-value, dark, and narrow UI;
- exact tooltips and accessibility semantics;
- shared Analytics period changes and Reports remaining concise.

## Deferred

Category selection, account filters, richer chart interaction, and additional
chart types remain deferred to their explicitly planned Phase 6B work.
