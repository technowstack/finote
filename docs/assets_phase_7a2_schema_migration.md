# Finote v1.3.0 — Phase 7A.2 Asset Schema & Migration

Status: **COMPLETE**

## Schema Version

- Previous version: `8`
- New version: `9`
- Migration: additive `v8 -> v9`

Existing tables and rows are not rewritten. Fresh databases create the new
tables through Drift `createAll`; existing databases create them in the
`onUpgrade` block when `from < 9`.

## Tables Added

### `assets`

- `id`: local auto-increment integer primary key;
- `uuid`: unique client-generated UUID;
- `symbol`: optional user-facing symbol, preserving entered casing;
- `normalized_symbol`: nullable trimmed uppercase lookup value;
- `name`: required display name;
- `asset_type`: stable string, one of `stock`, `crypto`, `mutualFund`, `gold`,
  `other`;
- `pricing_mode`: stable string, `api` or `manual`;
- `currency`: integer-price currency metadata, default `IDR`;
- `unit_label`: optional display unit such as `share`, `gram`, or `unit`;
- `is_active`: archive/reactivate state;
- `created_at`, `updated_at`: UTC metadata timestamps.

`asset_type + normalized_symbol` is unique. Multiple symbol-less custom assets
remain possible because SQLite permits multiple null values in a unique index.
The displayed symbol is not overwritten by normalization.

### `asset_transactions`

- `id`: local auto-increment integer primary key;
- `uuid`: unique client-generated UUID;
- `asset_id`: restricted foreign key to `assets.id`;
- `action`: stable string, one of `openingPosition`, `buy`, `sell`,
  `adjustment`;
- `quantity_scaled`: non-zero fixed-point integer quantity;
- `price_amount`: nullable non-negative integer unit price;
- `total_amount`: nullable non-negative integer monetary total;
- `transaction_date`: date-only `YYYY-MM-DD` text;
- `note`: nullable text;
- `source_transaction_id`: nullable restricted foreign key to
  `transactions.id`;
- `created_at`, `updated_at`: UTC metadata timestamps;
- `deleted_at`: nullable soft-delete timestamp.

The source transaction index is unique for non-null values, allowing one
cashflow transaction to link to at most one asset activity while allowing many
unlinked activities.

## Quantity Representation

Canonical asset quantity uses fixed-point integer scale `100,000,000` through
`AssetQuantity`. Canonical parsing and arithmetic do not use binary `double`.
Values with up to eight fractional decimal places are supported:

```text
0.015      -> 1,500,000
0.000125   -> 12,500
5.25       -> 525,000,000
123.4567   -> 12,345,670,000
```

Values with more than eight fractional places or values outside the signed
64-bit range are rejected. This is the intentional v1.3 precision boundary.

Stocks use shares as the canonical unit. One Indonesian lot is represented as
100 shares, so `12 lot = 1200 shares`; lot display conversion belongs to a
later UI phase. Crypto, mutual funds, gold, and custom assets use the same
fixed-point representation.

## Money and Price

Money and unit prices remain SQLite/Dart integers. The schema has no floating
point financial columns. `price_amount` and `total_amount` are nullable so an
opening position can have known quantity but unknown historical cost basis.

## Opening Position and Holdings

Opening Position is represented by an asset activity with
`action = openingPosition`. There is no `assets.current_quantity` or separate
opening quantity source of truth.

The persistence repository provides a local holdings query using active
activities:

```text
openingPosition = +quantity
buy             = +quantity
sell            = -quantity
adjustment      = signed quantity
```

Soft-deleted activities do not affect the result. A full sell may produce zero
and does not remove the asset. The database does not use destructive triggers;
future buy/sell workflows must reject sell quantities greater than current
holdings because short selling is not supported.

## Enum Storage and Mapping

Asset type, pricing mode, and activity action are stored as stable strings and
mapped by explicit Drift converters. Unknown values throw `FormatException`;
they are not silently mapped to another enum value.

## Local Price Decision

No price table is added in 7A.2. Phase 7A.1 recommended one coherent latest
price architecture for both manual and API prices, but its implementation is
deferred to Phase 7B.3/7B.4. Historical prices, candles, OHLC, and provider
identifiers are intentionally absent.

## Indexes

Only persistence/query indexes justified by this phase are added:

- `assets_type_normalized_symbol` unique identity index;
- `assets_active` archive/activity index;
- `asset_transactions_asset_id` activity lookup index;
- `asset_transactions_date` date ordering/filter index;
- `asset_transactions_deleted_at` active activity index;
- `asset_transactions_source_transaction_id` unique nullable link index.

## Migration and Compatibility

Migration v8 to v9 creates `assets` and `asset_transactions` only. It does not:

- create assets from `Pembelian Aset`, `Penjualan Aset`, or `Investasi`;
- create opening positions;
- guess symbols, quantities, or cost basis;
- change transactions, categories, accounts, transfers, settings, UUIDs, or
  soft-delete state;
- contact a network service.

After a v1.2 upgrade, the new tables are empty. Legacy import remains read-only
and unchanged. Reports, Dashboard, account balances, transfers, and existing
cashflow semantics remain independent of the empty asset domain.

Backup uses a raw SQLite `VACUUM INTO` snapshot, so new source tables are
included automatically. Restore validation now requires the v9 asset tables,
columns, and indexes. The backup format version remains unchanged; the
manifest database version records `9`.

## Tests

Coverage includes:

- fresh v9 tables and indexes;
- v1.0/v1.2-style migration to v9 without recreation or data loss;
- UUID and stable enum persistence;
- symbol normalization and type-scoped uniqueness;
- exact fractional quantity round-trips and precision rejection;
- opening position with null price and total amount;
- opening/buy/sell/signed-adjustment holdings aggregation;
- soft-delete exclusion and zero holdings;
- nullable and valid source transaction relations;
- backup/restore schema validation and existing finance regressions;
- Reports, Dashboard, Accounts, Transfers, and Legacy Import regression.

## Known Limitations

- No asset UI, portfolio screen, market API, price cache, valuation, Net Worth,
  or Reports/Dashboard integration is included.
- No serialized asset-specific backup format exists because current backup is a
  raw SQLite snapshot.
- Historical investment cashflow semantic keys for `Pembelian Aset` and
  `Penjualan Aset` are not present in the current category schema and remain a
  later reporting decision.
- Quantity precision is limited to eight fractional decimal places.
