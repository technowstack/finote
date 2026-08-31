# Phase 6A.4: Account-to-Account Transfer

## Actual Schema

Before this phase, Finote used Drift schema version `6` with `accounts` and
`transactions`; transactions had nullable `account_id`, and account balances
were derived by `AccountRepository.watchSummaries()`.

Schema version `7` adds a dedicated `transfers` table. Existing accounts,
transactions, categories, and settings are preserved. The migration creates an
empty transfers table and never synthesizes historical transfers.

## Transfer Semantics

Transfers are internal movements between Finote accounts. They are not
transactions and never appear as income or expense.

```text
transfers
- id
- uuid
- from_account_id
- to_account_id
- amount
- transfer_date
- note
- created_at
- updated_at
- deleted_at
```

Both account columns reference `accounts.id` with restricted deletion. The
database also enforces that source and destination differ. UUIDs and UTC
metadata timestamps follow existing Finote conventions. Transfer dates use the
existing local calendar date converter.

## Repository and Validation

`TransferRepository` provides active transfer listing, lookup, create, update,
and soft delete operations. Creation requires two existing active accounts.
Editing can preserve references to archived accounts so historical records stay
readable.

The repository rejects equal accounts, missing accounts, inactive accounts for
new transfers, zero/negative amounts, and values beyond SQLite's signed
64-bit integer range. Transfer amounts remain integer IDR values. Negative
account balances are allowed because Finote is a tracker, not a bank.

Creation inserts exactly one transfer row and never creates paired income or
expense transactions. There is no manually mutated account balance field.

## Balance Formula

The shared account summary query now derives:

```text
initial_balance
+ active income
- active expense
+ active incoming transfers
- active outgoing transfers
```

Transactions and incoming/outgoing transfers are pre-aggregated separately
before joining accounts. This avoids multiplying totals when an account has
multiple transactions and transfers. Soft-deleted transfers are excluded.

The query remains database-side and reactive through Drift. Transfer create,
edit, and soft delete events invalidate account summaries without an app
restart.

## UI

The Accounts page now links to a dedicated `Transfer Antar Akun` page. The page
supports creating, editing, and soft-deleting transfers without adding them to
unified transaction history. New transfers offer active accounts only; editing
retains archived accounts already referenced by the transfer.

The form includes `Dari`, `Ke`, `Nominal`, `Tanggal`, and optional `Catatan`.
Insufficient balance is allowed and does not block saving.

## Reports and Exports

Dashboard, Reports, Excel, Text, and PDF code paths remain transaction-only.
Transfers do not change global income, expense, report balance, category
totals, or export totals. Initial balances retain their existing meaning and
remain excluded from report income.

## Indexes

The migration/fresh schema adds:

- `transfers_from_account_id`;
- `transfers_to_account_id`;
- `transfers_date`;
- `transfers_deleted_at`.

These support account balance aggregation, transfer listing, date ordering,
and active-record filtering without adding speculative indexes.

## Backup, Restore, and Legacy Import

Transfers are included automatically in the existing SQLite backup archive.
Restore validation now requires the transfers table and its core columns. A
round-trip test confirms transfer rows and derived balances return after restore.

Legacy databases remain read-only and contain no transfers. Legacy import still
creates only income/expense transactions assigned to the default account and
does not create transfer records.

## Tests and Performance

Coverage includes:

- source/destination and amount validation;
- basic incoming/outgoing transfer balances;
- total-assets preservation;
- report income/expense preservation;
- amount, source, and destination edits;
- soft-delete reversal;
- negative source balances;
- archived-account transfer readability;
- schema migration and fresh install;
- backup/restore persistence;
- legacy import regression;
- transfer page rendering;
- 10,000 transactions plus thousands of transfers through the grouped balance
  query.

## Deferred Work

- Phase 6A.5: unified transaction history integration;
- Phase 6A.6: transfer-aware Reports;
- Phase 6A.7: transfer export integration;
- account filters, total-assets dashboard presentation, and advanced analytics.
