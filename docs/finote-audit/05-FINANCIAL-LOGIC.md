# Audit Financial Logic

## Source entities

| Entity | Source | Core fields/semantics |
|---|---|---|
| `Transactions` | `lib/core/database/tables/transactions.dart:23-60` | income/expense, account/category, positive integer amount, date-only text, soft delete, legacy identity |
| `Categories` | `tables/categories.dart:9-21` | name/type, soft delete |
| `Accounts` | `tables/accounts.dart:29-47` | name/type, initial balance, active/default |
| `Transfers` | `tables/transfers.dart:12-32` | from/to account, positive amount, date, soft delete |
| `Assets` | `tables/assets.dart` | active asset metadata, symbol/type/pricing mode |
| `AssetTransactions` | `tables/asset_transactions.dart` | opening/buy/sell/adjustment, scaled quantity, price/total, optional linked cashflow |
| `AssetPrices` | `tables/asset_prices.dart` | local manual/API last-known price |

Foreign keys use restrict for transaction category/account and transfer accounts. This prioritizes preserving referential integrity over physical deletion.

## Money and dates

**TERVERIFIKASI:** IDR amounts are `int`; DB constraint `amount > 0`. Formatting is presentation-only via `currency_formatter.dart`. Transaction dates are text `YYYY-MM-DD` with `DateOnlyConverter`, preventing timezone shifts for financial calendar dates (`converters.dart:37-56`). Metadata timestamps are DateTime UTC.

## Income/expense/balance

`FinancialSummary.balance = totalIncome - totalExpense` (`core/finance/financial_summary.dart:1-13`). Reports aggregate active transactions by type and range (`report_repository.dart:28-76`). Dashboard monthly income/expense uses active transactions and current month (`dashboard_repository.dart:37-42`).

**Potential reconciliation point:** Dashboard `total_assets` sums all account initial balances plus all active transaction cashflow (`dashboard_repository.dart:28-36`), whereas account summary derives each account with transfers and excludes deleted transactions (`account_repository.dart:43-64`). These paths should be tested against the same fixture whenever a redesign moves or recomputes values.

## Account balance

`AccountSummary` receives total income, expense, incoming transfer, outgoing transfer. The conceptual balance is initial balance + income − expense + incoming − outgoing. Transfer SQL is pre-aggregated by account before joining, which avoids multiplying transaction rows by transfer rows (`account_repository.dart:49-64`).

## Transfers

Transfers are separate rows and never inserted into `transactions` (`transfer_repository.dart:51-72`). Unified history maps them to `FinancialActivityType.transfer`; reports include a separate transfer summary (`report_repository.dart:33-37`, `84-92`). This is the correct separation for personal-owned-account movement.

## Portfolio holdings

`AssetQuantity` uses scale `100000000` (8 decimal digits) and integer storage (`asset_quantity.dart:11-35`). Holdings query applies openingPosition + buy − sell + adjustment (`asset_transaction_repository.dart:174-199`). Negative results are rejected by create/update/delete service paths.

Buy/sell cashflow is atomic and linked through `sourceTransactionId` (`asset_activity_service.dart:190-237`). Buy creates expense category `Pembelian Aset`; sell creates income category `Penjualan Aset`. Opening position and adjustment do not create cashflow.

## Portfolio valuation

`PortfolioValuationService.valueFor` accepts a local price only when currency matches and quantity is not negative; missing prices remain `null`, not zero (`portfolio_valuation_service.dart:63-86`). Multiplication uses `BigInt`, scale 1e8, and half-up rounding with range check (`89-100`). Portfolio snapshot counts unvalued/integrity issues and groups by asset type (`18-60`).

## Net worth

`NetWorthService` sums account summary balances + known portfolio value (`net_worth.dart:34-51`). Missing prices produce a partial snapshot and do not become an extra “net cash invested” component. Provider watches account summaries and local portfolio valuation; it does not itself request market data (`59-73`).

## Period/category/charts

- Reports use date-only inclusive `BETWEEN` filters.
- Top income/expense categories are grouped and limited to five in summary (`report_repository.dart:38-56`).
- Financial trend chooses day/week/month bucket by range (`159-205`).
- Expense category chart left-joins category and labels missing category as unavailable (`207-245`).
- Investment cashflow explicitly sums active `Pembelian Aset` expense and `Penjualan Aset` income (`115-156`).

## Double-counting checks

**TERVERIFIKASI intent:** linked Buy/Sell uses normal transaction as cashflow; portfolio valuation uses asset activities/prices, not transaction total; net worth uses cash/account summaries plus portfolio value. **RISK:** any future UI must not add `AssetTransaction.totalAmount` to transaction cashflow or net worth. This is a redesign constraint, not a proven current defect.

## Precision risks

- IDR uses signed 64-bit integer constraints; very large aggregate sums can still overflow SQLite/Dart if inputs approach limits. **NOT VERIFIED under extreme production data.**
- Asset quantity and valuation explicitly use scaled integer/BigInt, a strong design choice.
- No floating-point source of truth was found in inspected finance tables.
