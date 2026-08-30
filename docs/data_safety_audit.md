# Data Safety Audit

## Scope

This audit covers local backup, restore, database migration, and legacy
Catatan Keuangan import. Backup archives are recovery files, not Excel, Text,
or PDF exports.

## Backup

- Backup format is ZIP with `database.sqlite` and `manifest.json`.
- The existing `finance_backup_YYYY-MM-DD_HH-mm-ss-SSS.zip` name is retained
  for compatibility.
- The manifest contains application, backup version, database version, UTC
  creation time, and app version. It contains no PIN or secrets.
- SQLite snapshots use `VACUUM INTO`, avoiding a blind copy of a live database
  and its WAL/journal state.
- The snapshot is checked with SQLite integrity and schema-version checks
  before the archive is returned or saved.
- Safety backups are retained under the app documents directory as
  `pre_restore_backup_...zip`; names are collision-safe.

## Restore

Restore follows:

```text
select → validate archive/manifest/database → preview → safety backup
→ confirm → stage → close → swap → verify → invalidate app state
```

Validation rejects broken ZIPs, missing or empty database files, malformed
manifests, unsupported backup versions, schema mismatches, corrupt SQLite,
missing core tables/columns, integrity failures, and foreign-key failures.

The current database is renamed to a rollback file before the staged database
is activated. The rollback file is deleted only after the replacement passes a
second SQLite/schema verification. If swapping or verification fails, the old
database is restored where possible. The UI aborts when the safety backup
cannot be created.

Restore previews show backup metadata plus active transaction count, category
count, date range, income, and expense totals. Successful restore invalidates
the database provider, causing dependent Riverpod providers to rebuild.

## Settings

SQLite data, including database settings, is included in backup/restore.
PINs, secure-storage secrets, biometric state, and other platform preferences
remain outside the financial database and are not restored.

## Database Migration

The current Drift schema version is `3`. Existing migrations are additive:

- versions below `2` create missing application tables;
- versions below `3` add `receipt_fingerprint` only when absent.

There is no destructive drop-and-recreate fallback. Existing rows, UUIDs,
amounts, dates, soft-delete values, and legacy metadata remain in place.

## Legacy Import

Legacy files are opened read-only. Detection validates SQLite integrity,
required tables, required columns, types, dates, and positive integer amounts.
The import runs in one Drift transaction and rolls back categories and
transactions on failure.

Legacy type mapping is limited to the adapter: `0` becomes expense and `1`
becomes income. Categories are mapped by legacy subtype and transaction type,
reusing active Finote categories by name/type.

Duplicate protection uses `legacy_source` plus `legacy_id`. New imports hash
the canonical selected file path for `legacy_source`, so repeated imports of
the same selected file skip existing records while separate selected files do
not collide when they reuse legacy IDs. Existing records using the historical
constant source key remain recognized for compatibility. Copying a legacy
database to a new path intentionally creates a new import source.

Successful imports invalidate Dashboard, Reports, Transactions, and category
providers. The original legacy file is never written or deleted.

## Temporary Files and Sensitive Data

Backup working directories, restore staging files, and rollback files are
cleaned after successful completion or failure where safe. User-selected
backup and legacy files are never deleted. Backup contents and financial
values are not logged or uploaded. File selection uses the system picker; no
`MANAGE_EXTERNAL_STORAGE` permission is used.

## Known Limitations / Release Blockers

- Real-device Android validation is still required for SAF paths, app restart,
  provider refresh, and a 10,000+ transaction backup.
- A moved copy of a legacy database is treated as a new source because the
  legacy format has no stable database identifier.
- Full process-crash testing during filesystem rename is not available in the
  Flutter test environment.
