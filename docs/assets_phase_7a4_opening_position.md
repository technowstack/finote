# Finote v1.3.0 - Phase 7A.4 Opening Portfolio Snapshot

Status: **COMPLETE**

## Purpose

Opening Position initializes what the user actually owns when Finote starts
tracking the Portfolio. It is designed for existing users and new users who
already own investments. Users without investments can leave every asset at
`Belum ada posisi`.

Historical `Pembelian Aset` and `Penjualan Aset` transactions remain historical
investment cashflow. They are not reconstructed into assets, quantities, cost
basis, or holdings.

## Persistence

An opening position is stored as one `asset_transactions` row with
`action = openingPosition`. No duplicate mutable opening quantity is added to
`assets`. The row has a nullable `source_transaction_id`, which remains null
for opening positions because this action is not cashflow.

The repository enforces one active opening position per asset. Editing updates
the existing row by id. Removing soft-deletes that row when no other active
asset activity exists; if later activity exists, removal is rejected safely.

Asset hard delete remains blocked once the opening row exists. Archive and
restore preserve the opening history.

## Quantity Rules

Quantities use the existing deterministic `AssetQuantity` fixed-point scale of
100,000,000 and support up to eight fractional decimal places. No binary
floating-point value is persisted.

- Stock input uses whole `Jumlah Lot`; one lot is persisted as 100 shares.
- Crypto input accepts decimal coin/token quantities, including `0,015`.
- Mutual fund input accepts decimal units.
- Gold input accepts decimal grams.
- Other assets use the configured unit label or a generic unit.
- Opening quantity must be greater than zero.

Unknown cost is represented by null, never zero. The form optionally stores a
single IDR `total_amount` when the user enables `Saya tahu modal awal`.

The date is a date-only `Tanggal Posisi` and means the start of Finote's
portfolio tracking, not the original purchase date. An optional note is stored
on the same activity.

## Financial Separation

Saving, editing, or removing an Opening Position does not create Income,
Expense, `Pembelian Aset`, Transfer, or any account balance change. It does not
modify Reports, Analytics, Dashboard, exports, or historical cashflow.

Portfolio and Asset Detail react through Riverpod/Drift streams. The UI shows
`Belum ada posisi` before initialization and the entered quantity afterward,
without showing market value, P/L, or Net Worth.

## Tests

Coverage includes exact fractional quantity round-trips, stock lot UX and
canonical conversion, optional known and unknown cost, stable dates, no
cashflow creation, duplicate prevention, edit without stacking, safe removal,
later-activity protection, reactive Portfolio/Detail flow, archive/restore,
and existing finance regressions.

## Backup and Limitations

Opening positions are ordinary rows in `asset_transactions`, so the existing
raw SQLite backup includes them automatically. Full investment backup/restore
audit remains Phase 7E.1.

Buy, Sell, Adjustment, full holdings workflows, market pricing, valuation,
P/L, Reports integration, Dashboard integration, and Net Worth remain deferred.
