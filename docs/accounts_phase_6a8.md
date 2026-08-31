# Phase 6A.8: Backup / Restore Migration

## Backup Structure

Finote retains the existing compatible archive structure and filename:

```text
finance_backup_YYYY-MM-DD_HH-mm-ss-SSS.zip
|- database.sqlite
`- manifest.json
```

The archive contains one complete SQLite snapshot. Accounts, transaction account
relations, transfers, categories, settings, UUIDs, timestamps, and soft-delete
values are therefore preserved without separate JSON copies or identity remaps.

## Manifest and Versions

The manifest continues to contain:

- `application`;
- `backupVersion`;
- `databaseVersion`;
- `createdAt` in UTC;
- `appVersion`.

`backupVersion` remains `1` because the ZIP and manifest formats did not change.
The Drift schema is now version `8`. Schema 8 is an idempotent repair migration
for account and transfer indexes that table-only upgrade migrations did not
create. The schema version and backup format version remain separate concepts.

The existing application identifier `Catatan Keuangan` is retained for backup
compatibility. Runtime app-version metadata remains sourced from the installed
package and will reflect v1.1 when release metadata is advanced.

## Snapshot Consistency

Backup continues to use SQLite `VACUUM INTO`, which creates a transactionally
consistent standalone database rather than copying a live main file without its
WAL or journal. The resulting snapshot is now checked with the same strict
validator used for restore.

Validation requires current schema metadata, complete core tables and columns,
required account/transfer indexes, one Default Account, assigned transaction
accounts, valid foreign keys, and no same-source/destination transfers.

## Preserved v1.1 Data

Full database backup preserves:

- account ID, UUID, name, type, initial balance, active/archive state, default
  state, and timestamps;
- transaction ID, UUID, category, account ID, amount, date, source, legacy
  metadata, receipt fingerprint, timestamps, and soft-delete state;
- transfer ID, UUID, source/destination account IDs, amount, date, note,
  timestamps, and soft-delete state;
- SQLite settings and categories.

Restore does not regenerate UUIDs or map relationships by account name. Existing
integer IDs and foreign-key relationships survive through the restored SQLite
file.

## Restore Preview

Preview still shows backup and financial metadata and now also includes:

- account count;
- active transfer count;
- active transfer volume.

Income and Expense remain transaction-only. Transfer volume is informational and
never enters those totals.

## Staging and Migration

Restore follows:

```text
decode archive
-> validate manifest and declared database version
-> extract database.sqlite to temporary staging
-> compare manifest version with actual SQLite user_version
-> migrate the staged copy
-> validate current schema and financial relationships
-> create/retain the UI safety backup
-> close the live database
-> copy the live database to a rollback file
-> atomically rename the staged database over the live path
-> validate the installed database
-> delete rollback only after success
-> invalidate databaseProvider
```

The original user-selected archive is never modified. Temporary extraction and
staging directories are deleted in `finally` blocks.

The swap now copies the current database to rollback while leaving the current
target in place until the staged file atomically replaces it. A process stop
before replacement therefore leaves the old database at its normal path; a stop
after replacement leaves the already staged-and-validated database there.

## Old v1.0 Backups

Finote v1.0 database schema 3 backups are supported. Opening and immediately
closing Drift was insufficient because migrations are lazy, so restore now
executes an awaited query against the staged copy to force migration.

The schema 3 to schema 8 path:

1. creates Accounts;
2. creates one Default Account named `Tunai`;
3. adds nullable `transactions.account_id` when absent;
4. assigns every historical transaction to the Default Account;
5. creates an empty Transfers table;
6. repairs account and transfer indexes;
7. validates relationships and current schema before activation.

No transfer rows are synthesized. Existing transaction/category UUIDs, amounts,
dates, legacy metadata, receipt fingerprints, and soft-delete values remain
unchanged.

## Integrity Validation

Both preview and execution reject:

- malformed ZIP or manifest data;
- missing or empty SQLite content;
- unsupported future backup/database versions;
- mismatch between manifest `databaseVersion` and actual `PRAGMA user_version`;
- failed SQLite integrity checks;
- missing tables, columns, or required indexes;
- foreign-key violations;
- null transaction account assignments;
- missing or duplicate Default Accounts;
- orphan transaction/transfer account IDs;
- transfers with identical source and destination accounts.

Corrupt staged data is rejected before the live database is closed. If swap or
installed verification fails, the rollback copy replaces the failed target.

## Safety Backup

The existing UI still creates a persistent `pre_restore_backup_...zip` before
destructive restore confirmation. It uses the same complete schema-8 snapshot and
strict validation, so accounts, account relations, and transfers are naturally
included. Restore is aborted if safety backup creation fails.

## Post-Restore State

The restore page invalidates `databaseProvider` after execution. Accounts,
Transactions, Transfers, unified History, Reports, Dashboard, Categories,
Exports, and other dependent repositories all watch that provider and rebuild
against the restored file.

Automated provider-lifecycle coverage verifies account summaries, transfers,
unified history, and Reports without an application restart.

## Financial Verification

Current account balances are recalculated from restored source records:

```text
initial balance
+ income
- expense
+ incoming transfer
- outgoing transfer
```

No cached balance is restored. Regression coverage verifies Total Assets,
transaction-only Report Income/Expense/Net, one-row transfer history, and
account/transfer-aware Excel, Text, and PDF generation after restore.

## Large Data

The performance fixture backs up and restores 10,000 transactions, 5,000
transfers, and three accounts. After restore it reloads account balances,
Reports, 14,500 unified active-history rows, and the normalized export document.
Timings remain informational and are not brittle CI thresholds.

## Known Limitations

- The archive remains memory-backed during ZIP decode/encode with a 100 MiB
  archive/database limit; streaming archives are deferred until measurements
  justify the complexity.
- Persistent safety backups have no dedicated in-app browser yet.
- Real-device SAF, process termination during replacement, restart persistence,
  and external Excel/PDF viewer checks remain manual release validation.
- Package `appVersion` remains tied to release metadata and is not independently
  changed by this phase.

## Deferred Work

Phase 6A.9 covers broader legacy database compatibility. Phase 6A.8 only keeps
the existing legacy import path under regression coverage and does not redesign
it.
