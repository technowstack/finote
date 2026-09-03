# Finote v1.3.0 - Phase 7A.5 Asset Activity

Status: **COMPLETE**

## Scope

This phase adds `Beli`, `Jual`, and `Penyesuaian` after an asset has been
created. Opening Position remains the initial snapshot. Holdings are derived
from active asset activities and no mutable current quantity is stored.

```text
Opening Position + Buy - Sell + Adjustment
```

Market pricing, portfolio value, P/L, charts, Net Worth, and investment report
summaries remain deferred.

## Linked Cashflow

Buy creates exactly one Expense transaction using the `Pembelian Aset`
category. Sell creates exactly one Income transaction using `Penjualan Aset`.
Both rows are created in one database transaction and are linked through
`asset_transactions.source_transaction_id`.

The category initializer now adds the two missing asset cashflow defaults for
existing databases in a repeat-safe way. Category identity currently follows
the active name and transaction type because the existing schema has no
semantic category key.

The selected active account is required. Buy decreases that account through
normal Expense semantics; Sell increases it through normal Income semantics.
No Transfer is created. Adjustment never creates cashflow.

Stock totals use shares (`lot * 100`) multiplied by integer price per share.
Other asset totals use deterministic fixed-point quantity multiplied by integer
price, with integer division. Fees and tax are not represented.

## Validation and Lifecycle

- Buy and Sell quantities must be positive.
- Sell is rejected when it exceeds active derived holdings.
- Selling all holdings is allowed and does not archive the asset.
- Adjustment supports adding or reducing quantity and cannot make holdings
  negative.
- Quantity uses the existing fixed-point scale and supports Indonesian decimal
  comma input.
- Save, edit, and delete operations are atomic where they touch both tables.
- Editing updates the existing asset activity and linked cashflow; it does not
  create another transaction.
- Deleting Buy/Sell soft-deletes both linked rows. Deleting Adjustment only
  affects the activity.
- Deleting a linked cashflow from Transaction History also soft-deletes its
  linked asset activity. Editing a linked cashflow directly is blocked and must
  be done from Asset Detail.

## UI

Asset Detail provides one `Tambah Aktivitas` action with Beli, Jual, and
Penyesuaian options. It shows current quantity and a basic newest-first
activity history with explicit Indonesian labels and quantity effects. No
market value or P/L is shown.

## Compatibility

Historical `Pembelian Aset` and `Penjualan Aset` transactions are not converted
into asset activities. Legacy Import remains unchanged and legacy rows remain
unlinked. Raw SQLite backup already includes new asset activity rows.

## Tests

Coverage includes stock buy/sell/adjustment calculations, buy from zero,
fractional precision, sell-limit rejection, account balance reconciliation,
linked cashflow creation, duplicate prevention by atomic flow, linked deletion
safety, existing Opening Position behavior, and the full existing regression
suite.

## Next Phase

Phase 7A.6 - Holdings Calculation. This phase is not implemented here.
