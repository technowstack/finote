# Finote v1.3.0 - Phase 7C.1 Portfolio Screen Foundation

Status: **COMPLETE**

## Canonical screen

`AssetsPage` is the single Portfolio root at `/portfolio`. The third bottom
navigation destination opens it directly. Asset Detail is nested at
`/portfolio/assets/:id`; Add Asset is opened from Portfolio and returns to the
same root after save or cancel.

No duplicate `PortfolioScreen`, `AssetsScreen`, `AssetListScreen`, or
`ManageAssetsScreen` exists. Settings does not contain a second asset-list
entry.

## Layout and data flow

Portfolio renders the local holdings stream first, then combines the reactive
local price stream and `PortfolioValuationService` snapshot. Groups are shown in
stable order: Saham, Crypto, Reksadana, Emas, and Lainnya. Rows are sorted by
symbol or name within each group and open Asset Detail when tapped.

The summary shows known value when available. Partial values are qualified with
the number of unpriced assets, and an entirely unpriced portfolio shows
`Belum tersedia`; missing prices are never rendered as `Rp0`. Group subtotals
use the same valuation snapshot and are marked partial when necessary. No P/L,
Net Cash Invested, cash balance, Net Worth, charts, or investment analytics are
shown.

Stock rows use symbol, company name, lots, per-share price, and current value.
Crypto rows use symbol, name, fractional coin/token quantity, per-unit price,
and current value. Manual asset rows use their configured unit and show
`Harga belum diatur` when absent. API and manual assets remain grouped by asset
type rather than technical price source.

## Refresh and offline behaviour

The app-bar refresh icon is the single Portfolio refresh mechanism. Refresh is
asynchronous and leaves holdings and cached values visible. Successful quotes
update SQLite and the valuation UI reactively. Failed refreshes preserve old
prices and show `Harga terbaru belum dapat diperbarui.`. Stale last-known prices
remain usable and are labelled by the existing price presentation.

## Actions and navigation

Empty Portfolio has one central Add Asset CTA and no FAB. A non-empty Portfolio
uses one extended `Tambah Aset` FAB with bottom-safe scroll padding. Buy, Sell,
and Adjustment remain in Asset Detail, not on each Portfolio row. Archived
assets are excluded from the active Portfolio and remain available through the
existing archive/lifecycle UI.

## Scope and verification

This phase consolidates the existing screen rather than adding a new provider
or network architecture. Holdings, prices, and value calculations remain in
their existing repositories/providers/services. Reports, Accounts, Buy/Sell
cashflow semantics, and database schema are unchanged.

Coverage includes empty/no-position behavior from the existing asset tests and
a Portfolio UI regression proving a BTC quote and current value are rendered.
Light, dark, and system themes use the existing Material 3 app theme. The
scrolling layout uses safe bottom padding for small screens and long lists.

Deferred to later phases: stock-specific polish, advanced crypto/manual-asset
UI, Net Worth, Dashboard and Reports integration, P/L, charts, and historical
portfolio performance.
