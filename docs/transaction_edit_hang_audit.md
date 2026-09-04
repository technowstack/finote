# Transaction Edit Hang Audit

Phase: **7D.5 - Transaction Edit Hang Audit & Stabilization**

Status: **BLOCKED**

## Reproduction

The reported UI hang could not be reproduced in the available Flutter widget
test environment. The existing edit flow was exercised with a normal Expense,
amount change, formatted IDR input, save, navigation back, and a rapid second
Save tap. It completed in approximately one second and persisted exactly one
row. No Android emulator or physical device is connected for the requested
manual matrix.

| Scenario | Automated result | Runtime result |
| --- | --- | --- |
| Normal Expense | amount edit passes | not verified on device |
| Normal Income | repository semantics unchanged | not verified on device |
| Amount only | passes | not verified on device |
| Title only | controller is initialized once; no loop found | not verified on device |
| Date | local state only; no loop found | not verified on device |
| Category | local state only; no loop found | not verified on device |
| Account | local state only; no loop found | not verified on device |
| Note only | controller is initialized once; no loop found | not verified on device |
| Linked Buy | direct edit rejected safely | not verified on device |
| Linked Sell | same repository guard as Buy | not verified on device |
| Save unchanged | no special write loop found | not verified on device |
| Cancel | route pop only | not verified on device |

## Diagnostic findings

Temporary checkpoints on the normal Expense edit produced this sequence:

```text
EDIT_TX_START
EDIT_TX_VALIDATED
EDIT_TX_DB_START
EDIT_TX_DB_TRANSACTION_START
EDIT_TX_DB_TRANSACTION_DONE
EDIT_TX_DB_DONE
EDIT_TX_INVALIDATION_START
EDIT_TX_INVALIDATION_DONE
EDIT_TX_NAVIGATION
EDIT_TX_END
```

This establishes that the tested edit does not stop in validation, Drift
transaction execution, provider invalidation, or GoRouter navigation. The
temporary logs were removed and did not include transaction data.

## Root-cause assessment

No exact runtime root cause can be confirmed without reproducing the report.
The source audit found two real submit-path hazards and stabilized them:

1. `_saving` was checked only by the button's rebuilt `onPressed` state. A
   second tap arriving before that rebuild could enter `_save` twice. `_save`
   now returns immediately when a save is already active.
2. Receipt fingerprinting and duplicate detection occurred after `_saving` was
   set but outside the `try` block. An exception there could leave the form in
   `Menyimpan...`. All post-loading work is now covered by `try/catch/finally`,
   and `_saving` is reset whenever the form remains mounted.

These fixes do not alter transaction amounts, categories, accounts, dates,
soft-delete behavior, or investment semantics.

## Provider and persistence graph

```text
Transaction edit form
  -> TransactionRepository.update
       -> one db.transaction boundary
       -> transactions UPDATE

Drift transactions stream
  -> transaction history / financial activity

Drift transactions + transfers stream
  -> AccountRepository.watchSummaries
       -> accountSummariesProvider

Asset activities + local prices streams
  -> PortfolioSnapshot / portfolioValuationProvider

accountSummariesProvider + portfolioValuationProvider
  -> netWorthProvider

Transaction/report streams
  -> Reports providers
```

Read providers perform reads and derived calculations only. Portfolio valuation
does not refresh prices, Net Worth does not write or call the network, and
Reports recomputation is read-only. No circular `ref.watch` dependency or
manual invalidation cycle was found. A normal transaction edit makes zero
Market API requests.

The edit form invalidates only `transactionByIdProvider` because it is a
FutureProvider used by the detail route. History, account, report, portfolio,
and Net Worth views are Drift-reactive and do not need broad invalidation.

## Linked Buy/Sell policy

Direct Transaction History editing of a cashflow linked to an AssetTransaction
is blocked. Buy and Sell cashflow must be edited from Asset Detail, where
`AssetActivityService.updateBuy` / `updateSell` update the activity and its
linked cashflow inside one database transaction. The direct transaction edit
error now shows:

```text
Transaksi pembelian/penjualan aset harus diubah dari detail aset.
```

This avoids allowing amount or category changes that could diverge from asset
quantity, price, total, or activity type. Opening Position and Adjustment have
no linked cashflow and are unaffected.

## Validation

- Normal Expense edit and rapid double-submit regression pass.
- Direct linked Buy edit remains rejected and leaves both rows active.
- `flutter analyze` passed.
- Full `flutter test` passed with 281 tests.
- `flutter build apk --debug` passed.
- Device/manual validation is blocked because no Android emulator/device is
  connected.

## Remaining risks

The field-by-field Android matrix, migrated-database edit path, and actual
reported hang remain unverified. Phase 7E.1 must remain not started until this
phase is reproduced and accepted on a runtime target.
