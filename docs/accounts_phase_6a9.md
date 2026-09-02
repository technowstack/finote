# Phase 6A.9: Legacy Database Compatibility

## Supported Legacy Schema

Finote opens the selected Catatan Keuangan SQLite file with
`OpenMode.readOnly` and runs a lightweight integrity check. The source is never
altered.

Required tables and columns:

```text
Transaction
  id, type, amount, subType, date, title

TransactionSubType
  id, name
```

Recognized optional tables:

```text
TransactionDay
TransactionType
AppSetting
```

`TransactionDay` is not a financial source of truth. Missing optional tables do
not prevent import. Missing required tables/columns and invalid SQLite reject the
file. Row-level unknown types, non-positive/non-integer amounts, invalid dates,
and invalid primary keys are reported with reason codes while other valid rows
are imported. Missing/blank category metadata uses the `Tanpa Kategori` fallback.

## Mapping

Legacy types are converted at the importer boundary:

```text
0 -> expense
1 -> income
```

Amounts are accepted only as whole positive numbers and are stored as integer
IDR. There is no floating-point money conversion. Coverage includes `1`,
`1,000`, `1,000,000`, and large practical integer values.

Legacy dates retain the established Unix millisecond behavior. Numeric values
are read with `DateTime.fromMillisecondsSinceEpoch(..., isUtc: true)`, converted
to local time by the importer, and persisted with Finote's date-only converter.
Unix seconds are not interpreted as milliseconds automatically.

Each valid `Transaction.subType` is resolved to `TransactionSubType.id` when
available. Categories are reused by trimmed name plus income/expense type, or
created once when no active match exists. Missing metadata uses `Tanpa Kategori`.
Active Finote categories are loaded once per import, so category resolution does
not perform one query per transaction.

Imported records preserve amount, mapped type, title, category, calendar date,
legacy ID, and `source = legacy_import`. The known legacy schema has no imported
note field. No transfer is generated.

## Default Account

Every new legacy transaction is assigned to the single account identified by
`is_default`, never by the mutable display name. Import calls the canonical
`ensureDefaultAccount()` operation once inside the destination transaction.

If the canonical account was unexpectedly inactive, it is reactivated without
changing its ID, UUID, name, type, or initial balance. If absent, the same
operation creates one `Tunai` cash account. A duplicate default invariant still
fails safely rather than selecting an arbitrary account. Normal account
management no longer permits archiving the canonical Default Account.

The assignment is a compatibility fallback because the source has no account
dimension. It does not claim that historical funds actually belonged to that
wallet. Users can reassign imported transactions afterward.

Account balances and Total Assets remain derived:

```text
initial balance
+ income
- expense
+ incoming transfer
- outgoing transfer
```

Import never changes `initial_balance` to compensate for historical totals.

## Duplicate Identity

New imports use:

```text
legacy_source = catatan_keuangan_old:<SHA-256 of source database bytes>
legacy_id     = Transaction.id
```

The content fingerprint is deterministic and independent of temporary picker or
filesystem paths. An unchanged database copied to another path remains the same
source. Different source datasets with overlapping row IDs can coexist when
their database content differs.

The importer upgrades matching path-based Phase 6A identities and the older
unscoped `catatan_keuangan_old` identity to the content identity inside the same
Finote transaction. Historical unscoped identities do not contain enough data
to prove their original source; the first compatible reimport claims those old
rows. This is the only safe compatibility choice without inventing source
metadata.

Duplicate lookup includes soft-deleted rows. Reimport therefore:

- does not insert duplicate financial records;
- does not overwrite user-edited title, note, or category;
- does not reset a user-selected account;
- does not resurrect a soft-deleted transaction;
- does not duplicate categories or the Default Account.

Changing the contents of the legacy SQLite file creates a new source
fingerprint. Legacy databases should be treated as immutable source snapshots;
Finote never modifies them.

## Atomicity and Invalid Rows

Destination category creation, identity normalization, Default Account
resolution, and valid transaction insertion run in one Drift transaction. A
malformed source row is classified and skipped without blocking other valid
rows. An unexpected destination failure still rolls back all destination changes.
The completion summary exposes source, imported, duplicate, skipped, and failed
counts plus reason codes.
Sensitive source records, titles, notes, and amounts are not logged.

## Product Integration

Imported Income and Expense participate once in account balances, global and
category Reports, unified History, and exports. Unified History displays the
resolved Default Account label. Excel, Text, and PDF obtain the account through
the shared export document. Transfer summaries and existing transfer rows remain
unchanged.

The preview states that the destination is the Default Account. The completion
summary shows its current display name. Empty legacy databases are safe no-ops
and create no categories or financial records.

## Backup and Restore

Regression coverage performs:

```text
legacy import -> backup -> restore -> reimport
```

The transaction UUID, content-based legacy source, legacy ID, Default Account
relation, and duplicate protection survive the schema-8 SQLite snapshot. Restore
does not fabricate transfers.

## Large Import

A synthetic 10,000-row legacy database imports in one atomic batch with exact
integer totals. Default Account resolution occurs once. Active category mapping
is preloaded and reused. The test has no brittle timing threshold.

## Known Limitations

- No genuine production legacy fixture is stored in the repository; tests use
  realistic synthetic SQLite schemas.
- A source database intentionally edited after import has a different content
  identity and is treated as a different snapshot.
- A path-scoped development import moved before its first Phase 6A.9 reimport
  cannot always be associated automatically because the old identity encoded
  only its former path.
- Real-device document-provider behavior, external spreadsheet/PDF viewers, and
  restart persistence remain manual validation items.

## Remaining Work

Phase 6A.10 may perform broad testing and polish. It is not started by this
phase.
