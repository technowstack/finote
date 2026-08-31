# Phase 6A.1: Account / Wallet Management

## Scope

Finote v1.1.0 now has local account management. This phase does not assign
transactions to accounts, calculate live account balances, or implement
transfers.

## Actual Schema Inspection

Before the change, `AppDatabase` used Drift schema version `3` and declared:

- `categories`;
- `transactions`;
- `settings`.

Long-lived records use an auto-increment integer `id`, a generated UUID `uuid`,
and UTC `createdAt`/`updatedAt` timestamps. Transactions and categories use
soft-delete conventions; accounts use reversible `isActive` archival because
they must remain available for future relationships.

## Schema Version 4

The migration creates `accounts` and preserves all existing tables and rows.
Fresh databases and upgrades both ensure one default account. Version 1
migration behavior avoids creating the account table twice when the existing
broad v1 table creation path runs.

No `account_id` was added to `transactions`, and no `transfers` table was
created.

## Account Table

Actual fields:

- `id`: local auto-increment primary key;
- `uuid`: unique generated UUID;
- `name`: required text, validated to 100 characters or fewer;
- `type`: stable `cash`, `bank`, `e_wallet`, or `savings` value;
- `initial_balance`: nonnegative integer IDR amount, default `0`;
- `is_active`: active/archive state, default `true`;
- `is_default`: stable default-account marker, default `false`;
- `created_at` and `updated_at`: UTC metadata timestamps.

The explicit `is_default` marker avoids relying on the mutable display name
`Tunai` for identity. No current balance is stored or calculated.

## Default Account

Migration and initialization create exactly one `Tunai` account with type
`cash`, zero initial balance, and `is_default = true`. Initialization is
idempotent and does not overwrite or recreate an existing marked account.

The only active account cannot be archived. Other accounts can be archived and
reactivated; archived accounts remain stored and are shown as inactive in the
management screen.

## UI and CRUD

Settings now links to `Akun & Dompet`. The management page supports:

- list active and inactive accounts;
- create account;
- edit name, type, and initial balance;
- archive account with confirmation;
- reactivate account.

Supported user-facing types are `Tunai`, `Bank`, `E-Wallet`, and `Tabungan`.
The page labels the amount `Saldo Awal` and does not display a misleading live
balance. Account lists update through Riverpod streams.

## Regression Coverage

Automated coverage verifies:

- schema version 4 and account table/index creation;
- v1 and v2 migration data preservation;
- UUID and stable account type mapping;
- idempotent default initialization;
- create, update, archive, and reactivation;
- empty/long names, zero, large integer, and negative balance validation;
- backup snapshot and restore preservation of accounts;
- existing transaction/report/export behavior remains independent of accounts.

Legacy import was not changed and remains read-only. Restore validation now
requires the accounts table for schema-version-4 databases. Export formats and
reports were not changed.

## Known Limitations

- Transactions are not associated with accounts yet.
- Account current balances are not calculated yet.
- Legacy imports do not assign accounts yet.
- Exports do not include account information yet.
- Physical-device upgrade and restore validation remains a manual follow-up.

## Deferred

- Phase 6A.2: assign transactions to accounts;
- Phase 6A.3: calculate account balances;
- Phase 6A.4+: transfers and later account-aware history, reports, exports,
  backup migration, and legacy compatibility.
