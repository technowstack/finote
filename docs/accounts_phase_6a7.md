# Phase 6A.7: Export Integration

## Scope

Excel, Text, and PDF now consume one normalized export document containing:

- transaction-based financial totals;
- transactions with resolved account names;
- current account summaries;
- period-filtered transfer activity.

The save, share, file naming, Android storage, and permission behavior remain
unchanged.

## Export Model

`ExportDocument` now composes `ExportTransaction`, `ExportAccount`, and
`ExportTransfer` rows. All three formats receive this same resolved data and do
not query the database or calculate account balances independently.

`ExportTransaction.account` contains the historical assigned account name.
`ExportAccount` contains the account type, initial balance, transaction totals,
incoming/outgoing transfer totals, derived current balance, and active status.
`ExportTransfer` contains one transfer date, source, destination, note, and
amount.

## Financial Semantics

The core export summary remains:

```text
Income = exported income transactions
Expense = exported expense transactions
Period balance = Income - Expense
```

Transfers and account initial balances never enter those fields. Transfer
volume is the sum of each exported transfer amount once.

Current total assets are separate:

```text
Total assets = sum of current derived account balances
```

Account balances come from `AccountRepository.watchSummaries()`, the same source
used by Accounts and Reports. They are current point-in-time values and are not
restricted to the exported transaction period.

## Repository Query

`ExportRepository.buildDocument()` starts the transaction/account query,
shared account summary aggregation, and transfer query together, then maps them
into the normalized document.

Transactions use a left account join and the fallback `Akun tidak tersedia` for
malformed missing relations. Transfers use one SQL row per transfer with left
joins for source and destination names and the same fallback. Archived account
names remain available because archived rows are retained.

Soft-deleted transactions and transfers are excluded in SQL.

## Filters

Date filters apply inclusively to `transaction_date` and `transfer_date`.
Current account balances and total assets remain point-in-time values regardless
of the selected period.

Reports has no account filter, so export does not add one. Type-specific Income
or Expense exports contain only the selected transaction type and omit the
separate transfer section. Category-filtered exports also omit transfers because
transfers have no category. Unfiltered period exports include transfers for the
same period.

## Archived Accounts

Historical transactions and transfers continue to export archived account
names. Account summaries include active and archived accounts with an explicit
status. This matches Reports semantics: active accounts are the normal display,
while Total Assets includes all retained accounts so archived value does not
silently disappear.

## Excel

The workbook contains four sheets:

1. `Ringkasan`: period Income, Expense, Balance, transaction count, current
   Total Assets, account count, transfer count, and transfer volume.
2. `Transaksi`: No, Date, Type, Account, Category, Title, Note, and numeric
   Amount.
3. `Akun`: account type, initial balance, transaction totals, incoming/outgoing
   transfers, current balance, and status.
4. `Transfer`: one row per transfer with Date, From, To, Note, and numeric
   Amount.

Dates retain spreadsheet date serials and monetary source cells remain numeric.
An empty Transfer sheet remains present with headers.

## Text

The UTF-8 text report now separates:

- core period summary;
- current account balances and Total Assets;
- transfer activity;
- transactions with Account and Category.

Empty sections use explicit `Tidak ada akun`, `Tidak ada transfer`, or
`Tidak ada transaksi` messages.

## PDF

The multi-page PDF now contains separate current-account, transfer, and
transaction tables. The transaction table includes Account; transfers use a
neutral standalone table and never appear as Income or Expense. Tables are
chunked to retain large-document pagination behavior.

## Preview

The existing Reports export dialog keeps Income, Expense, and period Balance
prominent and adds current Total Assets plus transfer count/volume. Selecting an
Income-only or Expense-only scope removes transfers from the preview and output.

## Performance

The shared performance fixture contains 10,000 transactions, of which 9,500 are
active, 5,000 transfers, and three accounts. Repository loading and all three
formats complete without a brittle hardware-dependent threshold. PDF remains
the heaviest format because it paginates all transaction and transfer rows.

## Regression Coverage

Tests cover:

- normalized transaction account, account summary, and transfer rows;
- exact Income, Expense, period Balance, account balances, Total Assets, and
  one-time transfer volume;
- Excel Account column, four sheets, numeric values, and one transfer row;
- Text account labels, transfer direction, sections, and financial values;
- valid multi-section PDF generation;
- type, category, date, and empty-data behavior;
- transaction and transfer soft-delete exclusion;
- archived historical account names and status;
- Reports/export core and supplemental consistency;
- restored account/transfer export;
- legacy Default Account export without fabricated transfers;
- 10,000 transactions plus 5,000 transfers through Excel, Text, and PDF.

## Known Limitations

- Account balances are current, not historical as of the export end date.
- There is no account-specific export filter because Reports has none.
- Category/type-filtered exports intentionally omit transfers.
- PDF generation remains the most expensive format for very large datasets.
- Physical-device file opening, sharing targets, font scaling, and external
  spreadsheet/PDF viewer checks remain manual release validation.

## Deferred Work

Phase 6A.8 may further validate backup/restore compatibility. Phase 6A.9 covers
legacy compatibility work. Neither phase is started by this implementation.
