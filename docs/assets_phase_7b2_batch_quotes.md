# Finote v1.3.0 - Phase 7B.2 Batch Quote Integration

Status: **COMPLETE**

## Flow

```text
Local active holdings
↓
Eligible API-priced positive positions
↓
One POST /api/v1/market/quotes
↓
Map by asset type + normalized symbol
↓
Portfolio quote state
```

The request body is:

```json
{
  "assets": [
    {"symbol": "BBCA", "type": "stock"},
    {"symbol": "BTC", "type": "crypto"}
  ],
  "currency": "IDR"
}
```

Provider-specific identifiers are never sent. Quantities, balances, cash,
transactions, notes, and portfolio values remain local.

## Eligibility

Only active assets with `pricingMode = api`, type `stock` or `crypto`, a valid
symbol, and a positive holding are requested. Assets without activity, valid
zero holdings, negative/inconsistent holdings, archived assets, and manual
assets are excluded. An empty candidate list returns without an HTTP request.

The existing `assetHoldingsProvider` remains purely local. Candidate selection
uses its derived results and never changes the holdings source of truth.

## Mapping and Partial Results

`MarketRepository.getQuotes` deduplicates requests by
`AssetMarketKey(assetType, normalizedSymbol)`. It maps responses by that key,
not response order. The repository accepts the normalized batch response under
`quotes`, `results`, or `data.quotes` and supports optional per-item
`failures`.

Valid quotes remain available when another item fails. Missing quotes become
`MarketQuoteFailure`; they are never converted to price zero. Stale quote
metadata is preserved unchanged.

## Riverpod and UI

`portfolioMarketQuotesProvider` owns one quote state for Portfolio. It performs
one refresh when active holdings become available, supports the explicit
refresh button, and ignores a second in-flight refresh. Repeated automatic
refreshes with the same candidate set are suppressed; explicit refresh forces a
new request.

Portfolio renders local assets/holdings immediately. Quote loading and failure
messages are non-blocking, and available prices are shown lightly as
`Harga terbaru`. No price/value calculation is performed.

Batch failure preserves the last successful quote result and does not clear or
modify local financial data. No polling, retry loop, WebSocket, cache,
startup-global request, or per-asset `FutureProvider` was added.

## Performance and Privacy

The Portfolio makes one centralized batch request instead of one request per
asset. No arbitrary chunking is used because no backend batch limit is
documented. The current request contains only symbols, types, and currency.

## Tests

Coverage includes stock/crypto mixed batches, manual/no-position/zero/archive
filtering, one-request behavior, deduplication, response reordering, partial
success, missing quotes, empty batches, stale metadata, privacy payloads,
in-flight deduplication, and preservation after batch failure. Existing
single-quote and finance regression tests remain unchanged.

## Deferred

Local last-known-price persistence begins in Phase 7B.3. Current market value,
manual pricing, P/L, Net Worth, Reports, Dashboard, and real-time refresh remain
deferred.
