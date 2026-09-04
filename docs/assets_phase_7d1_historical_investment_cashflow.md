# Finote v1.3.0 - Phase 7D.1 Historical Investment Cashflow

Status: **COMPLETE**

Historical investment cashflow is derived only from active `transactions` rows.
The current schema has no semantic category code, so classification uses the
category name together with the transaction type:

- `Pembelian Aset` + `expense` = purchase
- `Penjualan Aset` + `income` = sale

Opposite type combinations are excluded rather than silently corrected. A
category rename currently breaks classification; this limitation is documented
instead of introducing a category-system migration.

```text
Total Pembelian Aset = SUM(transaction.amount for purchase rows)
Total Penjualan Aset = SUM(transaction.amount for sale rows)
Dana Bersih Diinvestasikan = purchases - sales
```

The result can be negative and is never presented as profit. It is historical
cashflow, not current portfolio value, holdings, cost basis, P/L, or Net Worth.
The aggregate supports existing report date ranges and account filters.

Legacy-imported transactions remain ordinary transactions and are included
when their category and type match. New Buy/Sell activities already create one
linked cashflow transaction. Only that transaction is aggregated;
`asset_transactions.total_amount` is never read, preventing double counting.
Opening Position and Adjustment contribute zero because they create no
cashflow transaction. Soft-deleted transactions are excluded.

Reports shows `Arus Kas Investasi` with purchase total, sale total, and
`Dana Bersih Diinvestasikan`, with explanatory copy separating it from current
portfolio value and profit. General Income/Expense Reports continue to include
these transactions normally.

No schema migration or dependency was added. Holdings, valuation, manual
prices, market refresh, Net Worth, Dashboard, and exports remain independent.

Tests cover purchase/sale rows, invalid category types, negative net cash
invested, all-time and period/account filters, and soft-delete exclusion.
