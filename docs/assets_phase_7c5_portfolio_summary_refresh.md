# Finote v1.3.0 - Phase 7C.5 Portfolio Summary and Refresh UX

Status: **BLOCKED**

## Summary semantics

The Portfolio summary consumes the existing `PortfolioSnapshot`. It shows the
derived current value of active positive holdings only:

```text
active holdings x latest valid local price
```

It excludes cash accounts, wallet balances, Net Cash Invested, historical Buy
amounts, and historical Sell amounts. It is not Net Worth and does not show
P/L, ROI, or investment analytics.

The summary shows the number of active positive-holding assets. Assets with no
position and closed zero holdings are not counted. A complete valuation shows
`Total Portofolio`; a partial valuation shows `Nilai Portofolio` and the known
value is explicitly qualified. If all positive holdings lack prices, the value
is `Belum tersedia` with an explanation instead of Rp0.

## Groups

Group subtotals are read from the same shared valuation snapshot as the total.
Only groups containing positive holdings are included in the snapshot. A group
with missing prices shows the known subtotal plus the number of unavailable
prices. Empty groups are not rendered in the summary.

## Refresh

The existing app-bar `Perbarui harga` action remains the single Portfolio
refresh control. It refreshes only positive API-priced Stock and Crypto
holdings, in one batch. Manual Reksadana, Emas, and Lainnya prices are never
sent to the Market API or changed by refresh.

Automatic refresh is requested when eligible holdings appear, while the
existing 15-minute local freshness policy skips fresh cached prices. In-flight
requests are deduplicated by the controller. Removing the widget-level key
allows a later Portfolio rebuild to re-check the TTL without creating repeated
network requests.

While refreshing, holdings and current values remain visible. A failed or
partially failed request preserves successful and previously cached values and
shows the non-blocking `Harga terbaru belum dapat diperbarui.` message. Stale
API prices remain usable and manual price timestamps are unaffected by market
refresh.

## Reactivity and boundaries

SQLite price writes continue through the existing providers and automatically
recalculate Asset Detail, rows, group subtotals, and the Portfolio summary.
No current value, total, or group subtotal is persisted. Buy, Sell, Adjustment,
Reports, Accounts, Bottom Navigation, and cashflow semantics are unchanged.

## Verification

Tests cover positive-holding counts, zero-holding exclusion, all-prices-missing
state, partial state, group aggregation, one-batch refresh, in-flight request
deduplication, cached failure behavior, and manual-asset Market API exclusion.
Automated validation passes. Manual mixed-Portfolio emulator/device validation
remains blocked because no Android emulator/device is currently connected.

Deferred Net Worth, Dashboard portfolio cards, investment Reports, P/L, ROI,
charts, price history, realtime polling, WebSocket, watchlist, and trading
remain out of scope.
