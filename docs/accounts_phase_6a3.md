# Phase 6A.3: Account Balance Calculation

## Scope

Finote v1.1.0 now displays derived balances for accounts. This phase does not
implement transfers, account-based reports, account export fields, or dashboard
redesign.

## Actual Architecture

The current database is Drift schema version `6`.

- `accounts.initial_balance` stores the amount present when the account was
  created.
- `transactions.account_id` is the Phase 6A.2 nullable foreign key to
  `accounts.id`.
- `transactions.type` stores `income` or `expense`.
- `transactions.amount` stores integer IDR values.
- `transactions.deleted_at` marks soft-deleted records.

`AccountRepository.watchSummaries()` is the single balance query path. It uses
one SQLite grouped aggregate for all accounts, then joins the result to the
typed account records. `accountSummariesProvider` exposes that stream to the
account list. Widgets do not calculate balances themselves.

## Formula

For account `A`:

```text
balance(A) = initial_balance(A)
           + active income assigned to A
           - active expense assigned to A
```

The SQL aggregate uses a `LEFT JOIN`, so accounts with no transactions still
show their initial balance. It uses `COALESCE` so empty income/expense sums are
zero.

The query is deliberately structured around income and expense components. A
future transfer phase can extend the summary with incoming and outgoing
components without mutating or duplicating the current balance formula.

## Inclusion Rules

- Only transactions with `deleted_at IS NULL` contribute.
- A transaction contributes only to its assigned account.
- Null or missing account assignments are not invented during reads; those
  malformed records are excluded from per-account summaries rather than
  crashing the Accounts screen.
- Archived accounts retain their initial balance and historical transaction
  effects. They remain visible in the existing all-account management list.
- Moving, editing, changing type, or soft-deleting a transaction recalculates
  the affected summaries through Drift reactivity.
- Editing an account's initial balance changes the derived balance without
  modifying transactions.

Negative derived balances are allowed. The existing account constraint still
requires `initial_balance >= 0`; an account can become negative through its
active expenses.

## Initial Balance Semantics

`initial_balance` represents money already present when the account was
created. It is not a fake income transaction and is not included in Reports'
income or expense totals.

Consequently:

```text
sum(account balances)
```

may differ from the global transaction balance by the sum of account initial
balances. This distinction is intentional. Dashboard, Reports, Excel, Text,
and PDF continue to derive global financial totals from active transactions
only.

## Account UI

The existing Accounts page now displays:

- account name;
- account type and active/archive state;
- current derived balance;
- total income;
- total expense.

The account form continues to show and edit `Saldo Awal`. There is no separate
account-detail route in the current implementation, so no new detail screen
was introduced.

## Performance and Indexes

The balance query performs a database-side aggregate instead of loading all
transactions into Dart for each account. Schema version `6` adds the justified
`transactions_account_id` index for account joins and filtering. Existing
indexes for type and soft-delete state remain unchanged.

The 10,000-transaction performance path uses multiple accounts and measures
the grouped account summary query. It does not enforce a brittle time limit.

## Regression Coverage

Tests cover:

- zero and positive initial balances;
- income, expense, multiple transactions, and negative balances;
- multiple-account isolation;
- amount edits;
- expense-to-income type changes;
- account reassignment;
- soft-delete reversal;
- initial balance edits;
- archived account balance retention;
- legacy import contribution to the default account;
- backup/restore balance preservation;
- global dashboard/report/export paths remaining unchanged;
- grouped balance calculation with 10,000 transactions.

## Known Limitations

- Transfers are not implemented and do not affect balances.
- There is no account filter in Reports or exports.
- Total assets are not exposed as a separate dashboard metric; whether
  archived accounts should be included in a future total-assets display remains
  a later product decision.
- Physical-device validation of upgrade, restore, legacy import, and restart
  flows remains a manual follow-up.

## Next Phase

`Phase 6A.4 — Account-to-Account Transfer` is planned next. It is not included
in this phase.
