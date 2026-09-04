# Finote v1.3.0 - Phase 7C.2 Stock Holdings UI

Status: **BLOCKED**

## Stock semantics

Stocks use canonical shares in `AssetQuantity`; the UI asks for whole lots and
converts one lot to 100 shares. Market prices are per share and current value
comes only from `PortfolioValuationService`:

```text
13 lot = 1,300 shares
1,300 x Rp9.200 = Rp11.960.000
```

Portfolio rows show symbol, local company name, lots, current value, and price
per share. They never add a `.JK` suffix or use daily market change as user P/L.
The local asset name remains canonical and is not overwritten by quote metadata.

## Detail and activity UX

Stock Detail shows lot position, exact share count, per-share current price,
current value, update metadata, and activity history. Opening Position and normal
Buy/Sell forms use whole lots and show a live share preview. Buy/Sell forms show
price per share, calculated total, and available holding for Sell. Repository
validation remains the authority for sell limits and atomic cashflow changes.

Activity history keeps historical transaction prices separate from current
market price and displays them as `@ Rp... / saham` when available. Adjustment
quantity is preserved honestly; odd-lot holdings are shown as lots plus leftover
shares rather than silently rounded.

Unknown cost basis remains `Tidak diketahui`. No profit, loss, ROI, corporate
action, dividend, trading, chart, or broker behavior was added.

## States and integration

No-price and offline states keep holdings visible without showing `Rp0`. Cached
or stale prices continue to value positions. Stock quotes still use the single
Portfolio batch request and shared reactive cache/valuation pipeline; rows do
not make individual network requests. Reports, Accounts, and existing Buy/Sell
cashflow semantics are unchanged.

Stock creation continues to normalize `bbca` to `BBCA`, does not require remote
symbol validation, and does not ask for provider-specific identifiers.

## Verification and deferred scope

Tests cover lot/share valuation, opening position display, current price/value
rendering, activity price presentation, sell limits, full sell to zero, stale
and missing prices, offline cache, symbol normalization, and one-batch request
behavior. Automated checks use the existing Material 3 Light/Dark/System theme
and local-first providers. Real BBCA verification remains blocked because the
deployed provider currently responds with `PROVIDER_UNAVAILABLE` / rate limit.

Deferred: Phase 7C.3 crypto-specific UI, advanced market analytics, P/L and cost
basis analytics, corporate actions, dividends, splits, charts, screener,
watchlist, broker integration, trading, Net Worth, and investment Reports.
