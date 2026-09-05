# Finote v1.3.0 - Phase 7E.1 Backup / Restore Integration

Status: **COMPLETE**

## Backup Architecture

Finote uses a raw SQLite recovery backup, not structured Portfolio JSON.
`BackupService` creates a consistent `database.sqlite` snapshot with
`VACUUM INTO`, validates it, and stores it with `manifest.json` in one ZIP.

```text
finance_backup_YYYY-MM-DD_HH-mm-ss-SSS.zip
|- database.sqlite
`- manifest.json
```

The manifest keeps backup format version `1` and records the active Drift
database version. Phase 7E.1 completed at schema 10; Phase 7E.2 later added the
additive schema-11 index repair without changing the backup format.

## Source Data Included

The snapshot includes exact rows from:

- `accounts`, `categories`, `transactions`, `transfers`, and `settings`;
- `assets` including UUID, symbol, type, pricing mode, and archived state;
- `asset_transactions` including Opening Position, Buy, Sell, Adjustment,
  deterministic `quantity_scaled`, soft-delete state, and nullable
  `source_transaction_id`;
- `asset_prices`, including backup-critical manual prices and optional API
  last-known cache rows.

Integer IDs and UUIDs are preserved by physical database replacement. Buy/Sell
links therefore continue to reference the same restored Transaction and do not
create duplicate cashflow. Opening Position and Adjustment keep a null source
transaction relation. Unknown opening cost remains null.

## Price Policy

Manual and API prices share `asset_prices`; `assets.pricing_mode` determines the
source semantics. Raw SQLite backup therefore includes both. Manual price and
manual mode are required user data. API rows are rebuildable cache and are not
required conceptually, but their presence in a full snapshot is valid. A
supported older backup without `asset_prices` migrates to the current schema with an
empty price table.

Backup, restore, opening Portfolio, Dashboard, Reports, and Net Worth do not
request market data. Only explicit `Refresh Harga` may call the Market API.
Restore resets stale/in-flight market quote state before and after database
replacement; a disposed request cannot write an old quote into the restored
database.

## Derived Values

No separate Current Holding, Portfolio Total, Current Value, Net Worth, or
Investment Cashflow total is restored. After provider rebinding:

```text
Holding = Opening + Buy - Sell + Adjustment
Portfolio Value = holding x active local price
Net Worth = derived account balances + Portfolio value
Investment Cashflow = active typed Transactions
```

Soft-deleted activities remain excluded. Archived assets and their history are
preserved and follow the existing active-Portfolio exclusion policy. Zero
holding history remains stored.

## Precision

Asset quantity remains an exact signed 64-bit scaled integer at scale
`100000000`. Stocks remain canonical shares (`12 lot = 1200 shares`). Crypto,
gold, and mutual-fund fractions round-trip without JSON or binary floating-point
conversion. Money and manual prices remain integer values.

## Restore Safety and Lifecycle

Restore validates ZIP and manifest structure, supported versions, SQLite
integrity, required tables/columns/indexes, foreign keys, account assignment,
and transfer constraints before replacement. Schema-10 validation now includes
`asset_prices` and both price indexes.

The selected snapshot is migrated and validated in a temporary file. The live
shared database is closed before same-filesystem replacement. A rollback file
protects replacement failure, while the UI creates a persistent safety backup
before confirmation. The root `databaseProvider` is then invalidated once so
Transactions, Home, Accounts, Reports, Portfolio, and Net Worth bind to one new
shared `AppDatabase` instance.

Legacy Import remains separate and read-only. Old `Pembelian Aset` and
`Penjualan Aset` rows remain Transactions only and never synthesize holdings.

## Automated Tests

Coverage includes:

- full v1.3 raw SQLite Portfolio round-trip;
- exact IDs, UUIDs, links, timestamps, archive state, and soft-delete state;
- Opening, Buy, Sell, Adjustment, manual prices, and manual mode;
- stock, crypto, gold, and mutual-fund quantity precision;
- holdings, Portfolio, Net Worth, investment cashflow, account, and transfer
  recalculation;
- v9 Portfolio migration with absent API/manual price table;
- pre-Portfolio backup migration to empty Portfolio without synthesis;
- malformed schema-10 price-table rejection after current-schema migration;
- post-restore Riverpod transaction and Dashboard reactivity;
- repeated local Dashboard provider refresh completion;
- zero automatic Market API requests;
- disposed in-flight quote cannot write after restore reset.

## Validation

```text
dart format .             PASS
flutter analyze           PASS
flutter test              PASS (288 tests)
flutter build apk --debug PASS
git diff --check          PASS
```

Android runtime validation passed on a Pixel 6a: the current database was
exported through the system document picker, copied to the host, and verified
with `unzip -t` before app data was cleared. Restore preview reconciled 5,833
transactions, 31 categories, one account, and the original totals. Restore
completed successfully, and the same Dashboard totals remained available after
a process restart. Additional real-device transaction CRUD was stopped by
explicit user direction; equivalent post-restore provider CRUD remains covered
by the automated suite.

Next phase: **7E.2 Backward Compatibility & Migration Tests**.
