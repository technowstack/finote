# Phase 6A.6: Reports Integration

## Scope

Reports preserve their transaction-based financial totals and now add two
separate informational sections:

- current account balances and total assets;
- transfer count and volume for the selected report period.

Exports are intentionally unchanged until Phase 6A.7.

## Financial Semantics

The report period remains a flow calculation:

```text
Report balance = income transactions - expense transactions
```

Transfers and account initial balances do not contribute to report income,
expense, category totals, monthly history, or report balance.

Current total assets are a point-in-time position:

```text
Total assets = sum of current derived account balances
```

Each account balance continues to use the shared Phase 6A.3/6A.4 calculation:

```text
initial balance
+ income
- expense
+ incoming transfer
- outgoing transfer
```

Report balance and total assets can legitimately differ because total assets
include initial balances and all non-deleted historical records, while the report
balance only describes transactions in the selected period.

## Account Section

`Saldo akun saat ini` displays active accounts using
`accountSummariesProvider`. It is deliberately not labeled as a balance for the
selected report period because historical balance snapshots are not
implemented.

Archived accounts are omitted from the normal account rows, but their derived
balances remain included in `Total aset`. When archived accounts exist, the UI
states that total assets include them. This prevents archived historical value
from silently disappearing from the user's asset position.

The section handles loading, errors, and an empty active-account list without
showing invalid numeric values.

## Transfer Summary

`Transfer antar akun` uses `transfer_date` and the same inclusive calendar-date
boundaries as the existing report period. It shows:

- the number of active transfer records;
- the sum of each transfer amount once.

One transfer from A to B for Rp2.000.000 therefore contributes one transfer and
Rp2.000.000 volume, not Rp4.000.000. The section explicitly states that this
information does not affect income or expense. Soft-deleted transfers are
excluded.

## Query Architecture

`ReportRepository.watchReport()` retains its existing transaction-only
`filtered` CTE for summary, category, and monthly calculations. A separate
`filtered_transfers` CTE produces only the period transfer count and volume.
The branches are returned by the existing single reactive query and mapped to
the composed `TransferReportSummary` value.

The report query watches transactions, categories, and transfers. Transfer
amount/date edits and soft deletion therefore update the period summary without
a restart. Source/destination edits update the shared account balance query.

Current account balances are not recalculated in Reports. The existing
`AccountRepository.watchSummaries()` aggregate remains their single source of
truth and avoids per-account queries.

No schema, generated-code, index, or dependency change was required.

## Filters

Today, This Week, This Month, All, and custom ranges continue to resolve through
the existing financial calendar-date utility. Transaction filters use
`transaction_date`; transfer summaries use `transfer_date` with the same range.

An account filter was not added. The existing Reports architecture has no
account/category filter control, and Phase 6A.6 only requires a simple current
account position. Account-specific period flows remain a possible later
enhancement and must keep transfer flow separate from income and expense.

## Category and Monthly Reports

Category aggregation, top income/expense categories, and monthly income,
expense, and net history still read only from active transaction rows. Transfer
is not synthesized as a category and is not added to monthly bars or totals.

Archived accounts do not remove their transactions or transfers from historical
financial calculations. Reassigning a transaction changes the shared account
allocation but not its global report amount.

## Reports and Exports

Excel, Text, and PDF remain transaction-only until Phase 6A.7. For the same
period, their core income, expense, and net values continue to match Reports.
The new current-account and transfer-volume sections are temporarily
Reports-only and are not part of export documents yet.

## Performance

The existing performance fixture uses 10,000 transactions, 5,000 transfers,
and three accounts. Both the report query and shared account aggregate are
measured informationally without hardware-dependent timing assertions. The
report verifies that all 5,000 transfers are counted once.

## Regression Coverage

Tests cover:

- transfers excluded from income, expense, net, category totals, and monthly
  totals;
- deterministic initial balance, account balance, and total asset semantics;
- transfer count and one-time volume;
- transfer amount/date/source changes;
- transfer soft-delete exclusion;
- transaction account reassignment without global total changes;
- archived account history and total-asset preservation;
- current account and transfer presentation;
- restored reports with accounts, transactions, and transfers;
- legacy transactions allocated to the default account with no transfers;
- Reports and export core total consistency;
- 10,000 transactions plus 5,000 transfers.

## Known Limitations

- Account balances are current, not historical as of the report end date.
- There is no account-specific report filter or incoming/outgoing period-flow
  breakdown.
- Transfer volume is not charted or included in monthly history.
- Account and transfer information is not exported until Phase 6A.7.
- Physical-device scrolling, font scaling, restart, and end-to-end manual
  restore validation remain manual release checks.

## Deferred Work

Phase 6A.7 will integrate account and transfer information into Excel, Text, and
PDF exports. Phase 6A.6 does not start that work.
