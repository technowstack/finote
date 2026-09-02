# Transaction Filter UX Polish

## Problem

Transaction History previously placed type and period chips together in one
long row, defaulted to the current month, and offered no clear advanced filter
surface. Older imported transactions could therefore look missing even though
they were present in the database.

## Filter Hierarchy

- Quick filters: `Semua`, `Pemasukan`, `Pengeluaran`, and existing unified
  `Transfer`.
- Advanced filters: period, account, and category in one Material 3 bottom
  sheet.
- Search remains independent and keeps its existing debounced title, note,
  category, and account semantics.

The default period is `Semua waktu`. Account and category defaults are null,
meaning all accounts and all categories. Legacy source is not exposed as a
user-facing filter.

## Bottom Sheet

`Filter transaksi` uses draft state. Period options are Semua waktu, Hari ini,
Minggu ini, Bulan ini, Tahun ini, and Rentang kustom. Account/category choices
are applied only after `Terapkan`; dismissing the sheet discards changes.
`Reset` clears advanced filters inside the sheet. Search remains independent.

The filter button shows `Filter` or `Filter • N` where N counts only active
advanced filters. Applied period, account, and category values appear as
independent removable chips. Default `Semua waktu` is not shown as a chip.

## Data Semantics

The UI translates state into `FinancialActivityQuery`, which keeps filtering in
SQLite. Account filtering includes transactions assigned to that account and
transfers entering or leaving it. Category filtering returns transactions only;
transfers have no category and are excluded. Source, archived state, and
soft-delete status do not silently hide valid historical transactions.

Home remains intentionally limited to five recent transactions. `Lihat semua`
opens the complete History screen. Full History now starts at all time and can
still be narrowed with period, account, category, type, or search filters.

## Empty, Navigation, And Responsive Behavior

An empty database shows `Belum ada transaksi.`. A non-empty database with no
matching result shows `Tidak ada transaksi yang cocok dengan filter.` and a
`Reset Filter` action. Filter state remains in the page while navigating to
detail and returning; edits update the reactive query and can remove a row if
it no longer matches.

The quick row remains horizontally scrollable on narrow phones. The advanced
controls are vertically scrollable in the bottom sheet, including long account
and category names. Existing Material 3 theme components and semantic selected
states work in light, dark, and system themes.

## Tests

Coverage includes all-time legacy visibility, same-date/same-amount row
preservation, account/category query filters, existing type/date/search
behavior, stable ordering, soft-delete exclusion, transfer handling, and the
transaction screen rendering.
