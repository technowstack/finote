# Finote v1.3.0 - Phase 7B.1 Market API Client Foundation

Status: **COMPLETE**

## Scope

This phase adds only the Flutter-side client for one normalized Finote Market
API quote. It does not refresh Portfolio, persist prices, calculate value/P&L,
or make any request during app startup.

```text
Flutter -> MarketApiClient -> Finote Market API -> MarketRepository -> MarketQuote
```

Flutter has no Yahoo, yfinance, CoinGecko, or Binance models or direct calls.

## Configuration and Endpoint

The base URL is centralized in `AppConfig.marketApiBaseUrl` and can be supplied
with:

```text
--dart-define=FINOTE_MARKET_API_BASE_URL=https://example.invalid/
```

The development default is `http://10.0.2.2:8080/`. No API key or credential is
defined or sent.

Single quotes use:

```http
GET /api/v1/assets/{SYMBOL}?type=stock|crypto&currency=IDR
```

Symbols are trimmed and uppercased at the request boundary. Provider suffixes
such as `.JK` are never added. Requests contain only symbol, type, and
currency.

## Normalized Model

`MarketQuote` contains symbol, optional name, Finote `AssetType`, integer IDR
price, currency, optional change metadata, `MarketStatus`, stale flag, and
optional UTC `updatedAt`.

Price is accepted only as an integer-valued JSON number and remains an `int`;
negative prices are rejected while zero is accepted. `changePercent` is
display-only metadata and may use a finite `double`; it never affects
holdings or cashflow.

Unknown market status values map to `unknown`. Invalid timestamps become null
because timestamps are metadata, not financial dates. Missing required fields
or malformed response types return `MarketInvalidResponse`.

## Errors and Offline Behavior

Transport failures map to `MarketNetworkUnavailable` or `MarketTimeout`.
HTTP 404 maps to `MarketNotFound`; other non-success responses map to
`MarketServerError`. Unsupported manual assets map to
`MarketUnsupportedAsset` before any network request. Raw socket, timeout, and
JSON exceptions do not escape the client.

The client is an optional enhancement. Asset CRUD, Opening Position,
Buy/Sell/Adjustment, and local holdings do not depend on it. No retry loop,
polling, WebSocket, cache, or Portfolio integration is included.

## Riverpod

`marketApiClientProvider` and `marketRepositoryProvider` expose the foundation.
No permanent per-symbol provider and no global quote request are created.

## Tests

Tests cover stock and crypto mapping, request paths, stale and closed metadata,
zero/negative prices, invalid timestamps, manual-asset guards, HTTP 404/500,
timeout, offline transport failure, malformed JSON, and missing required price.

## Deferred

Batch quotes begin in Phase 7B.2. Last-known price persistence, manual pricing,
current market value, P/L, Net Worth, Reports, Dashboard, and refresh
orchestration remain deferred.
