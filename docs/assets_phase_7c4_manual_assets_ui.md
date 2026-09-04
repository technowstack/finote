# Finote v1.3.0 - Phase 7C.4 Manual Assets UI

Status: **BLOCKED**

## Scope

This phase polishes presentation and activity entry for manual-priced
Reksadana, Emas, and Lainnya assets. No provider, catalog, chart, P/L, Net
Worth, Reports, Dashboard, or schema work is included.

## Manual price semantics

Manual price is persistent local data stored through the existing
`AssetPriceRepository`. It is always a current price per configured unit:

- Reksadana: `Nilai per Unit` / NAB per unit;
- Emas: `Harga per Gram`;
- Lainnya: `Harga per Unit` or the existing configured unit label.

Missing price is shown as `Harga belum diatur`; it is never treated as Rp0 and
never replaced by acquisition cost. Current value remains derived from the
existing holdings and valuation providers.

## Portfolio and Detail UX

Manual groups remain `Reksadana`, `Emas`, and `Lainnya`, using the same row and
subtotal layout as API-priced assets. Manual rows show the asset name, exact
fractional quantity, current unit price, and derived current value. Detail
shows the matching unit-specific price label, current value, update timestamp,
price action, and activity action.

No P/L, ROI, acquisition-price substitution, technical pricing-mode label, or
external logo was added.

## Activity UX

Opening Position and Buy/Sell preserve the existing deterministic quantity
precision. Reusable quantity formatting displays values such as `123.4567
unit` and `5.25 gram`. Buy/Sell forms show the matching unit, per-unit price,
and a live calculated Total; Sell retains repository validation for over-selling.
Adjustment continues to change holdings without cashflow.

## Offline and refresh behaviour

Manual price changes use the existing reactive SQLite providers and work
offline. Portfolio refresh requests remain restricted to active API-priced
stock and crypto assets, so manual assets are never sent to the Market API.
Updating or clearing a manual price does not modify holdings or cashflow.

Clearing a price keeps holdings and activity history, while current value
becomes unavailable and group/portfolio totals remain partial as provided by
the shared valuation snapshot.

## Persistence and lifecycle

No schema or dependency changes were made. Existing backup/restore already
persists manual price rows. Archive preserves asset history and price data
while excluding the asset from the active Portfolio.

## Verification

Coverage includes fractional Reksadana quantity, fractional Gold quantity,
manual unit-price valuation, Indonesian quantity parsing, missing-price display,
and the absence of the technical `Manual` label in Portfolio rows. Automated
validation passes, but manual Gold and Mutual Fund verification is blocked
because no Android emulator/device is currently connected.

Deferred automatic gold pricing, mutual-fund NAV APIs, provider integrations,
product search, P/L, charts, Net Worth, Reports analytics, and Dashboard
integration remain out of scope.
