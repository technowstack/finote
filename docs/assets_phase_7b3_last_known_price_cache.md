# Finote v1.3.0 - Phase 7B.3 Last-Known Price Cache

Phase 7B.3 stores the latest successful API quote locally without changing
holdings or financial cashflow.

## Storage

`asset_prices` contains at most one row per asset. The row is keyed by the
local asset ID, not by symbol, so symbol and asset-type changes cannot silently
reuse another asset's price.

Stored fields are:

- integer price and currency;
- backend `market_updated_at` and `is_backend_stale`;
- local `fetched_at` timestamp.

The table is added by the schema 9 to 10 migration and is included in normal
SQLite backup/restore automatically.

## Runtime Behaviour

Portfolio holdings load from Drift first. Active cached prices are then read
reactively from Drift. API refresh remains asynchronous and writes only valid
successful quotes. Missing or failed quotes do not delete an existing cache.

Automatic refresh uses a 15-minute local freshness window. Manual refresh
bypasses that window. Market failures therefore leave the last-known price
visible and do not block offline portfolio use.

Changing an asset's symbol, type, pricing mode, or currency invalidates its
cached price. Deleting an unused asset removes its cache row before deletion.

Price cache data is not used for current portfolio valuation, profit/loss,
reports, dashboard totals, or cashflow. Those remain deferred to later phases.
