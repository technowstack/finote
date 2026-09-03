# Finote v1.3.0 - Phase 7B.5 Current Market Value

Status: **COMPLETE**

## Valuation Pipeline

Current value is derived locally from the existing holdings and current-price
streams:

```text
Drift holdings + Drift current prices
↓
PortfolioValuationService
↓
AssetValuation / PortfolioSnapshot
↓
Riverpod Portfolio and Detail providers
```

No derived value is persisted. Holdings remain the active
`asset_transactions` aggregate. Prices remain the existing latest local price
records.

## Formula and Arithmetic

```text
current value = canonical quantity × current unit price
```

`AssetQuantity.scaled` uses a scale of `100,000,000`. The service multiplies
that fixed-point integer by the integer unit price using `BigInt`, divides by
the quantity scale, and rounds final Rupiah using **round half up**. The result
is returned as an integer and checked against the signed 64-bit range.

Stocks are valued using canonical shares, not displayed lots. For example,
13 lots are 1,300 shares, so 1,300 × Rp9.200 = Rp11.960.000.

Crypto, gold, mutual funds, and other assets use the same deterministic
quantity × unit-price calculation. Manual prices mean per gram or per
configured unit; they are not total holding values.

## Price Sources and Missing Data

API-priced assets use the latest local API quote. Manual-priced assets use the
latest local manual price. Portfolio valuation never reads a remote quote
directly and never requests the network.

Missing prices produce an unavailable `AssetValuation`, not zero. Known zero
holdings with a valid price produce a valid Rp0 value. Assets with no active
activity are excluded. Negative holdings are excluded from normal valuation and
reported as integrity issues.

The snapshot exposes known values, valued/unvalued asset counts, group totals,
and complete/partial/unavailable state. Partial totals show known values with a
qualification. If every owned asset lacks a price, the total is `Belum
tersedia`.

Archived assets are excluded because the active holdings stream is used.
Stale API prices remain usable and retain their stale metadata. Manual prices
never use backend stale semantics.

## UI and Reactivity

Portfolio now shows total known value, partial/unavailable status, group totals,
and current value on each owned asset row. Asset Detail shows current price,
current value, source, and update date. Refreshing API quotes updates SQLite,
which automatically recalculates the snapshot. Manual price changes and
holding buy/sell/adjustment changes follow the same reactive path.

Current value is intentionally not profit/loss, cost basis, Net Cash Invested,
cash balance, Reports data, Dashboard data, or Net Worth. No cashflow or asset
activity is mutated.

## Tests

Coverage includes canonical stock-share valuation, lot regression, fractional
crypto/gold/mutual-fund arithmetic, deterministic fractional-Rupiah rounding,
multiple/group totals, missing and stale prices, zero and no-position states,
archived/negative holdings, manual price updates, API cache updates, and
existing finance regressions.

Next phase: **7C.1 Portfolio Screen Foundation**, treated as a UI audit/polish
phase rather than a duplicate rewrite.
