# Phase 6A.2: Assign Transactions to Account

## Scope

Finote v1.1.0 now assigns each transaction created or imported by the
application to an account. Account balance calculation and transfers remain
out of scope.

## Actual Schema Before This Phase

Before this change, `AppDatabase` was Drift schema version `4`.

- `accounts` existed with integer `id`, UUID `uuid`, name, mapped account type,
  integer `initial_balance`, `is_active`, `is_default`, and UTC timestamps.
- `transactions` had no account relation.
- Transaction history joined transactions to categories only.
- Legacy import inserted transactions directly through
  `TransactionsCompanion`.

## Schema Version 5

`transactions.account_id` was added as a nullable integer foreign key to
`accounts.id` with `ON DELETE RESTRICT`.

Storage remains nullable because SQLite/Drift cannot safely add a required
column to populated existing tables in the first step. The migration resolves
the stable `is_default` account, fills every null account reference, and
verifies that no transaction remains unassigned. Application repository paths
require or resolve an active account for new records; updates allow an existing
archived account to remain attached without silently remapping history.

No destructive table reset or data rewrite is used.

## Default Backfill

Schema v5 migration:

1. ensures the existing default account exists;
2. updates all transactions with null `account_id` to that account's integer id;
3. verifies the remaining null count is zero.

Amounts, dates, UUIDs, category ids, legacy ids, and soft-delete state are not
changed. Fresh databases still create the `Tunai` default account once.

## Transaction Creation and Editing

`TransactionRepository.create`, `createMany`, and
`createManyWithCategories` now persist `account_id`. If a legacy caller omits
the optional repository argument, the active default account is selected, with
the first active account as a safe fallback. Normal UI creation always presents
an account picker.

Editing persists the selected account without creating another transaction.
An existing archived account remains valid for its historical transaction. A
different archived account cannot be selected for reassignment.

## UI

The transaction form now shows an `Akun` picker with active accounts and their
Bahasa Indonesia type labels. On edit, the currently assigned archived account
remains visible so history is not silently changed. Transaction history and
monthly history show the account name, and transaction detail shows an `Akun`
row.

No account filter, account balance, wallet dashboard, transfer UI, or account
export column was added.

## Legacy Import

Legacy databases remain read-only and do not need an account field. Imported
transactions explicitly receive the active stable default account. Existing
`legacy_source` plus `legacy_id` duplicate protection remains unchanged; repeat
imports do not create duplicate transactions or accounts.

## Backup and Restore

Backup remains a full SQLite snapshot with the existing archive format. Restore
validation now requires `account_id` in transactions and the existing accounts
table. Automated round-trip coverage confirms an assigned transaction keeps the
same account relation.

## Financial Regression

Reports, dashboard totals, and export document generation were not changed to
calculate by account. Existing transaction/report/export/legacy tests continue
to pass, so income, expense, balance, dates, and soft-delete exclusions remain
unchanged.

## Tests

Coverage includes:

- schema v5 creation and migration from v1/v2 data;
- account id backfill and preservation of transaction identity/data;
- income/expense transaction account persistence;
- changing an account without duplicating a transaction;
- archived account history readability;
- legacy default-account assignment and repeat-import safety;
- account relation backup/restore;
- 10,000 assigned synthetic transactions through history and existing report/
  export paths;
- transaction account picker and existing transaction UI regression.

## Known Limitations

- Account current balances are not calculated yet.
- Account filtering and account columns in exports are deferred.
- Transfers and transfer-aware history/reports remain deferred.
- Physical-device upgrade, restore, and manual workflow validation remains a
  follow-up.

## Deferred Work

- Phase 6A.3: Account Balance Calculation;
- Phase 6A.4+: transfers, account-aware reports/exports, backup migration, and
  legacy compatibility refinements.
