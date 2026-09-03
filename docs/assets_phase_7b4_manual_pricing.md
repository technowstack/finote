# Finote v1.3.0 - Phase 7B.4 Manual Asset Pricing

Status: **COMPLETE**

## Purpose

Manual-priced assets can store one locally managed current unit price while
working fully offline. Mutual funds, gold, and custom assets use this flow;
stocks and crypto continue to use the Finote Market API.

## Storage and Semantics

The existing `asset_prices` table is reused. No second price table or schema
migration was added. `price_amount` stores the deterministic integer IDR price
per unit, and `fetched_at` is the local timestamp of the latest price change.
For manual records, backend fields are unused: the asset's `pricingMode` is the
source distinction and `is_backend_stale` remains false.

There is no manual price history. Updating a price replaces the current row;
clearing it removes only that row. An absent row means `Belum diatur`, never
`Rp0`.

Price means price per configured unit:

- Gold: price per gram;
- Mutual fund: value/NAB per unit;
- Other: price per configured unit label, defaulting to unit.

Holdings, opening cost, buy/sell activities, cashflow, accounts, reports, and
dashboard totals are separate and unchanged.

## UI and Offline Flow

Asset Detail shows the current manual price, its update date, and `Atur Harga`
or `Ubah Harga`. `Hapus Harga` confirms that quantity remains stored. Portfolio
shows the manual unit price or `Harga belum diatur`; it does not calculate total
value in this phase.

Input accepts Indonesian-style separators such as `1.500.000` and stores only
the integer value. Prices must be greater than zero. No network request is
made for manual assets.

The existing reactive Riverpod price providers update Asset Detail and
Portfolio immediately after SQLite writes. The raw SQLite backup already
includes manual prices. API cache records remain reconstructable cache data;
manual price rows are user-entered state and must be preserved by backup and
restore.

Changing a manual asset's name or symbol preserves its price. Changing asset
type, currency, or pricing mode invalidates the current row. API-to-manual
therefore starts unset, and manual-to-API cannot send or display the old manual
price as an API quote.

## Tests and Deferred Scope

Coverage includes gold, mutual fund, and custom prices; exact update/clear;
unknown versus zero; archive and identity edits; pricing-mode transitions;
holding independence; API batch exclusion; and existing backup/report/account
regressions.

Current market value, Net Worth, P/L, price history, Reports, Dashboard, and
manual-asset Market API support remain deferred to later phases.

Next phase: **7B.5 Current Market Value**.
