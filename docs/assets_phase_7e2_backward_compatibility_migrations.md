# Finote v1.3.0 - Phase 7E.2 Backward Compatibility & Migration Tests

Status: **COMPLETE**

## Supported Release Paths

Repository tags establish the supported release schemas:

| Release | Schema | Upgrade target | Result |
| --- | ---: | ---: | --- |
| v1.0.0 | 3 | 11 | Tested |
| v1.1.0 | 8 | 11 | Tested |
| v1.2.0 | 8 | 11 | Tested with 5,000 transactions |
| v1.3.0 fresh install | 11 | 11 | Tested |

Schema 1 was the table-free foundation and schema 2 shipped in v0.9.x. They
remain covered as internal historical paths but are not mislabeled as v1.0.
Schema 9 and 10 were v1.3 development schemas and remain supported by additive
migrations. There are no committed private/user SQLite or ZIP fixtures; release
fixtures are generated from the table definitions and migration history in the
corresponding repository tags.

## Schema History

| Version | Change | Preservation strategy |
| ---: | --- | --- |
| 1 | Foundation, no finance tables | `createAll` adds the first finance schema while unrelated tables remain untouched. |
| 2 | Categories, transactions, settings | Existing IDs, UUIDs, integer amounts, dates, sources, soft deletes, legacy identity, and settings remain unchanged. |
| 3 | Nullable receipt fingerprint | Add one nullable column. |
| 4 | Accounts | Add the table and one active Default Account. |
| 5 | Transaction-account relation | Add nullable `account_id`, backfill null rows to the Default Account, then verify no row is unassigned. |
| 6 | Transaction account index | Add `transactions_account_id`. |
| 7 | Transfers | Add an empty transfer table; no rows are synthesized. |
| 8 | Account/transfer index repair | Add missing indexes idempotently. This is the v1.1/v1.2 release schema. |
| 9 | Assets and asset activities | Add empty tables and indexes; historical finance rows are not inspected or converted. |
| 10 | Asset prices | Add an empty local price table and indexes; no fake zero price is inserted. |
| 11 | Receipt index repair | Idempotently add `transactions_receipt_fingerprint` for databases that passed through the old v2-to-v3 column migration. |

All production migrations are additive. There is no fallback that deletes or
recreates the production database after migration failure. Drift runs upgrade
steps transactionally; an error is surfaced rather than silently resetting user
data. Downgrade from a newer schema to an older app is not supported. Backups
with a newer schema are rejected before replacement.

## Existing User Result

Migration preserves transactions, category IDs and UUIDs, account IDs and
UUIDs, transfers, settings, transaction UUIDs, legacy source/ID pairs, exact
integer money, calendar-date strings, and soft-delete state. Pre-account rows
are assigned once to the one active Default Account. Existing account-era rows
keep their original account relation, and transfers are neither duplicated nor
converted to Income/Expense.

For pre-v1.3 users the correct post-upgrade state is:

```text
assets = 0
asset_transactions = 0
asset_prices = 0
```

Historical `Pembelian Aset` Expense and `Penjualan Aset` Income rows remain
Transactions. They contribute to Historical Investment Cashflow only. The test
fixture verifies purchases Rp10,000,000, sales Rp4,000,000, and net invested
Rp6,000,000 while holdings remain empty. Opening Position, Buy, Sell, and manual
prices work only after the user creates Portfolio records after migration.

## Categories and Enums

Startup category seeding uses an existence check by current `(name, type)` and
runs transactionally. Repeated initialization does not duplicate `Pembelian
Aset` or `Penjualan Aset`, and existing category IDs are preserved. The schema
has no immutable category semantic key, so a user rename remains authoritative;
Historical Investment Cashflow classification follows the documented current
name-plus-type rule rather than rewriting category names during migration.

Persisted enums use stable strings, never ordinals:

```text
TransactionSource: manual, legacy_import, receipt_scan, recurring
AssetType: stock, crypto, mutualFund, gold, other
AssetPricingMode: api, manual
AssetTransactionAction: openingPosition, buy, sell, adjustment
```

Asset pricing/action encoders now use exhaustive literal switches. Actual
historical transaction schemas constrain source values to the supported set;
unknown values therefore indicate a malformed database and restore rejects
them safely instead of crashing later in a provider.

## Database and Provider Lifecycle

Normal startup creates one `AppDatabase` through the root `databaseProvider`.
Repositories watch that provider. Migration occurs when this shared database is
opened, so Transaction History and Dashboard subscriptions use the migrated
connection. Restore remains the separate tested lifecycle: close, replace, then
invalidate the root provider once.

Post-migration tests keep active Drift subscriptions while creating Expense and
Income transactions, editing, and soft-deleting. Transaction History and
Dashboard emit immediately with timeouts, covering the prior stale UI/refresh
hang regression. Opening local holdings, Dashboard, and Portfolio providers
makes zero market requests. Only explicit `Refresh Harga` performs one batch
request.

The obsolete `/settings/assets` path never existed in repository history.
Portfolio remains the single `/portfolio` bottom-navigation destination, so no
legacy redirect or duplicate entry is required.

## Backup Compatibility

Backup format remains version 1. Supported old SQLite snapshots are staged,
migrated to schema 11, integrity/FK/index/value validated, and only then replace
the live database. A schema-3 backup without asset tables restores to an empty
Portfolio. A current backup created after migration includes new user-created
Assets, Opening Position, Buy/Sell links, exact scaled quantities, manual price,
and restores successfully.

## Automated Matrix

- fresh schema-11 tables, indexes, FK enablement, and one Default Account;
- actual v1.0 schema-3 assumptions to schema 11;
- actual v1.1/v1.2 schema-8 assumptions to schema 11;
- 5,000-row v1.2 migration without duplication;
- schema-10 missing receipt-index repair and second-open idempotency;
- exact IDs, UUIDs, amounts, dates, settings, legacy identity, and soft deletes;
- account balances and transfer-neutral total-assets reconciliation;
- SQLite `integrity_check` and `foreign_key_check`;
- empty Portfolio and zero automatic market requests after old-user migration;
- Historical Investment Cashflow without holding reconstruction;
- post-migration transaction create/edit/delete reactivity;
- post-migration Asset, Opening Position, Buy, Sell, manual price, explicit
  market refresh, backup, and restore;
- malformed enum and missing legacy-identity index rejection.

## Limitations

- No sanitized real production database is committed. Historical fixtures are
  derived from repository release tags; private financial databases must never
  enter source control.
- Schema downgrade is unsupported.
- Legacy Catatan Keuangan import remains a separate read-only path. Its Unix
  millisecond/date interpretation and content-hash duplicate identity are not
  changed by this phase.
- Android runtime migration validation was unavailable. `adb devices -l`
  reported no connected device and `emulator -list-avds` reported no available
  AVD. The user explicitly waived this runtime gate after reviewing the blocker.

## Validation

- `dart format .`: PASS
- `flutter analyze`: PASS (no issues)
- `flutter test`: PASS (294 tests)
- `flutter build apk --debug`: PASS
- `git diff --check`: PASS
- Android emulator/device migration: WAIVED by explicit user instruction because
  no runtime target was available

Phase 7E.2 is complete. Next phase: **7E.3 Portfolio Performance & Offline
Audit**. Phase 7E.3 has not started.
