# Legacy Import Missing Data Audit

## Scope And Result

This audit covers the actual legacy detector/importer, destination Drift schema,
and existing SQLite fixtures. The importer reads the legacy database with
`OpenMode.readOnly`; it never updates, deletes, or alters the source database.

**LEGACY DATABASE IMPORT MISSING DATA AUDIT: PASS** for the available fixtures
and automated validation. No production legacy database is committed to this
repository, so a real-user source count cannot be stated here.

## Actual Source Schema

The supported source of truth is the quoted SQLite table `"Transaction"`:

```text
id       INTEGER PRIMARY KEY
type     INTEGER       0 = expense, 1 = income
amount   INTEGER
subType  INTEGER       legacy category ID
date     INTEGER       Unix milliseconds, or parseable date string
title    TEXT nullable
```

The category lookup table is `TransactionSubType`:

```text
id       INTEGER PRIMARY KEY
name     TEXT
```

Recognized optional tables are `TransactionDay`, `TransactionType`, and
`AppSetting`. `TransactionDay` is not read as a transaction source. The source
query is ordered by `Transaction.id`; there is no `LIMIT`, `OFFSET`, `take`, or
batch pagination.

The detector checks SQLite integrity, required table names, and required column
names. It counts rows directly from `"Transaction"`. Row-level data problems
are classified during import so one malformed row no longer prevents valid rows
from being imported.

## Destination Schema And Identity

The destination is Drift schema version 8. Imported transactions use:

```text
source       = legacy_import
legacySource = catatan_keuangan_old:<SHA-256 of source bytes>
legacyId     = "Transaction".id
accountId    = canonical active Default Account
```

The destination has a unique index on `(legacy_source, legacy_id)`. No unique
constraint uses title, date, amount, or category. Therefore two legitimate rows
with the same date, type, category, and amount are not false duplicates when
their legacy IDs differ. Existing rows, including soft-deleted and user-edited
rows, are counted as duplicates and are not overwritten or resurrected.

## Row Accounting

`LegacyImportDiagnostics` reports:

```text
totalSourceRows
parsedRows
eligibleRows
importedRows
existingRows
skippedRows
failedRows
reasons
```

The reconciliation invariant is:

```text
totalSourceRows = importedRows + existingRows + skippedRows + failedRows
```

Current classification policy:

```text
IMPORTED              valid new source row inserted
DUPLICATE             existing legacy_source + legacy_id, including soft delete
SKIPPED_WITH_REASON   row cannot be safely parsed; reason is retained in memory
FAILED_WITH_REASON    reserved for a destination failure that prevents safe commit
```

The UI reports `Import selesai`, new rows, duplicate rows, failed rows, source
row total, and reason counts. Sensitive titles, notes, and amounts are not
logged.

## Reason Codes

The parser emits explicit reason codes instead of silently continuing:

```text
unknown_type
invalid_date
invalid_amount
invalid transaction id / subtype field
unsupported_row
```

Missing or blank subtype metadata is not a skipped transaction. The valid row is
preserved under the expense/income category `Tanpa Kategori`, with reason count
`missing_category_fallback` shown as an audit note. This avoids losing financial
history merely because category metadata is incomplete.

## Date And Amount Rules

Numeric legacy dates retain the established Unix millisecond interpretation via
`DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)`, then are persisted as
Finote calendar dates. Unix seconds are not guessed as milliseconds. Parseable
ISO date strings are also accepted.

Amounts are read as whole integers and must be positive because the destination
schema requires `amount > 0`. Null, non-integer, zero, and negative values are
reported as `invalid_amount`; they are not silently discarded. No floating-point
conversion is used for accepted money values.

## Account And Category Behavior

`ensureDefaultAccount()` runs inside the destination Drift transaction. Every
new legacy transaction receives that account ID. The legacy source has no
account dimension, so no account is inferred and no transfer is fabricated.

Active categories are reused by trimmed name and transaction type. Missing
subtype/category metadata uses `Tanpa Kategori`. Existing user-edited imported
transactions are left unchanged on reimport.

## Root Cause

The previous importer loaded all rows through a mapping that threw on the first
invalid type/date/amount/category. The detector also validated every row before
import. The result was an all-or-nothing failure with no row-level accounting,
so the UI could not distinguish malformed rows, duplicates, or valid rows that
had not yet reached the destination. Category lookup could also throw for a
missing subtype instead of preserving the transaction.

## Fix

The minimal fix was applied at the shared import boundary:

- detector metadata remains read-only and no longer aborts on a single malformed financial row;
- importer parses each source row independently and records a reason code;
- valid rows continue through one atomic destination transaction;
- missing category metadata falls back to `Tanpa Kategori`;
- duplicate lookup remains `(legacy_source, legacy_id)`;
- destination failures still fail safely through the enclosing transaction;
- user-visible completion includes source and diagnostic counts.

## Reimport And Recovery

Reimport is idempotent. Previously imported rows, including soft-deleted rows,
are duplicates; user corrections remain authoritative. A partially imported
database can be rerun: existing rows are counted and only source IDs not found
under the source identity are inserted. This supports the recovery case where a
first run reached 700 of 1,000 rows and a later run inserts the missing 300,
without creating 700 duplicates.

## Test Coverage

Automated tests cover:

- direct source count and `Transaction` as canonical source;
- Unix millisecond date mapping;
- all valid rows and exact integer financial totals;
- identical financial values with different legacy IDs;
- reimport and copied-source identity;
- partial existing import recovery;
- missing category fallback;
- malformed row accounting and reason code;
- unknown types and invalid amount behavior;
- ID gaps and large imports;
- Default Account assignment;
- soft-deleted/user-edited imported rows;
- no fabricated transfers;
- source bytes unchanged after import;
- backup/restore identity preservation.

## Validation Snapshot

```text
dart format .             PASS
flutter analyze           PASS
flutter test              PASS (222 tests)
flutter build apk --debug PASS
```

No generated code, dependency, destination schema, migration, index, or legacy
source file was changed by this audit.

## Known Limitations

- No production legacy database is available in the repository, so production source/duplicate/skipped counts require running the diagnostic result against the user's copied database.
- Destination insertion remains one atomic transaction; an unexpected destination/database failure returns an error rather than pretending partial success.
- Invalid source rows are skipped safely and reported, but their raw contents are intentionally not persisted or logged.
- Real-device file-picker and UI import flow remain manual validation items.
