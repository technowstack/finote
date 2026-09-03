# Finote v1.3.0 - Phase 7A.6 Holdings Calculation

Status: **COMPLETE**

## Source of Truth

Current holdings are derived only from active `asset_transactions` rows. No
mutable holding total is stored on `assets` or elsewhere.

```text
openingPosition + buy - sell + adjustment
```

The aggregate query uses a `LEFT JOIN`, so assets without activity remain
visible. Asset identity is always `asset_id`; symbols are never used for
aggregation.

## Action Effects

`openingPosition` and `buy` add the persisted quantity. `sell` subtracts the
persisted positive quantity. `adjustment` uses its signed persisted quantity.
Soft-deleted activities contribute no effect.

## Quantity and Display

`AssetQuantity` remains the single fixed-point value object with scale
`100000000`; aggregation stays integer-based and does not convert to `double`.
Stocks remain canonically stored as shares, while the display converts exact
whole multiples of 100 shares to lots. Crypto, mutual funds, gold, and other
assets preserve their fractional precision and configured display units.

## Repository and Riverpod Flow

```text
Drift aggregate query
↓
AssetTransactionRepository
↓
AssetHolding(asset, quantity, hasActivity)
↓
assetHoldingsProvider / holdingProvider
↓
Portfolio and Asset Detail
```

`assetHoldingsProvider` returns active assets for the Portfolio. The
`allAssetHoldingsProvider` supports archived-asset detail and lifecycle UI.
`holdingProvider(assetId)` derives one asset's result from the all-holdings
stream and does not issue an N+1 database query.

## State Semantics

- No active activities means `hasActivity = false` and displays `Belum ada posisi`.
- Active activities resulting in zero means `hasActivity = true` and displays a
  valid zero quantity such as `0 lot`.
- Archived assets are absent from the active holdings provider; their source
  activities and derived holding remain available in the all-holdings query.
- Negative results are preserved and exposed as inconsistent through
  `findNegativeHoldings`; they are never silently clamped to zero.

## Integrity and Performance

Sell and adjustment validation reuse the repository's central aggregate path
for current and excluding-activity calculations. The existing
`asset_transactions_asset_id` and `asset_transactions_deleted_at` indexes were
reviewed and are sufficient for the current grouped query. No schema migration
or new index was needed.

Holdings do not read linked cashflow amounts. Reports, accounts, transfers,
legacy import, and backup source records are unchanged. Restore will derive
holdings again from restored assets and asset activities.

## Tests

Coverage includes no activity, valid zero holdings, stock flow, exact crypto,
gold, and mutual-fund precision, soft-delete exclusion, archive filtering,
negative corruption detection, and same-symbol asset isolation. The existing
finance, reports, account, transfer, legacy-import, export, and backup tests
remain part of the full suite.

## Next Phase

Phase 7B.1 - Market API Client Foundation. It is not implemented here.
