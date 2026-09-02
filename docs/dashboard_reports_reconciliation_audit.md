# Dashboard / Reports Financial Reconciliation Audit

## Result

**DASHBOARD / REPORT FINANCIAL RECONCILIATION: PASS**

The mismatch was in Home's `Saldo` metric, not in the imported data, account
balances, Reports, or Analytics. Home used a pre-Accounts transaction-only
balance while Wallet used the derived account balance.

## Metric Definitions

```text
Account balance = initial_balance + income - expense
                  + incoming_transfer - outgoing_transfer
Total assets    = sum(current derived account balances)
Income          = active income transactions in the selected period
Expense         = active expense transactions in the selected period
Net             = Income - Expense
```

Transfers and account initial balances are excluded from Income, Expense, and
Net. Soft-deleted records are excluded from all financial aggregates.

## Source Audit

| Surface | Source | Semantics |
| --- | --- | --- |
| Accounts / Wallet | `AccountRepository.watchSummaries()` | Current derived account balances, including initial balance and transfers |
| Home | `DashboardRepository.watchSummary()` | Now uses the shared account summary stream for Total Assets; monthly transaction query for month-to-date flow |
| Reports | `ReportRepository.watchReport()` | Selected-period active transaction Income, Expense, Net; separate current account section |
| Analytics | `financialTrendProvider`, `expenseCategoryChartProvider`, `accountBalanceChartProvider` | Same report transaction filters for flow charts; shared account summaries for assets |

Home now labels its cards `Total aset`, `Pemasukan bulan ini`, and
`Pengeluaran bulan ini`. Reports labels its flow metric `Saldo periode` and its
point-in-time metric `Total aset`.

## Deterministic Reconciliation

Fixture:

```text
Account A initial balance: Rp5.000.000
Income:                  Rp2.000.000
Expense:                   Rp500.000
Transfer A -> B:         Rp1.000.000
Account B initial balance:          Rp0
```

| Metric | Database expected | Wallet | Home | Reports | Analytics |
| --- | ---: | ---: | ---: | ---: | ---: |
| Account A | Rp5.500.000 | Rp5.500.000 | via Total Assets | account section | account chart |
| Account B | Rp1.000.000 | Rp1.000.000 | via Total Assets | account section | account chart |
| Total Assets | Rp6.500.000 | Rp6.500.000 | Rp6.500.000 | Rp6.500.000 | Rp6.500.000 |
| Income | Rp2.000.000 | N/A | Rp2.000.000 month | period value | trend value |
| Expense | Rp500.000 | N/A | Rp500.000 month | period value | trend value |
| Net | Rp1.500.000 | N/A | N/A (not displayed as a Home card) | Rp1.500.000 | trend value |

The transfer leaves Total Assets and Net unchanged. Initial Balance affects
Total Assets only.

## Query Findings

- The previous Home query calculated `SUM(income) - SUM(expense)` and exposed it
  as `Saldo`, ignoring `initial_balance` and transfers.
- Account balance calculation is database-backed and uses `LEFT JOIN` for
  transactions plus separate transfer aggregates. Archived accounts remain in
  the aggregate and therefore remain part of Total Assets.
- Reports use `deleted_at IS NULL`, transaction-date range predicates, and no
  source restriction, so `legacy_import` rows are included.
- Reports use `LEFT JOIN categories`; missing or archived categories do not
  remove financial rows. The report transaction query does not join accounts;
  account filtering uses `t.account_id` directly.
- Analytics reuses the Reports transaction predicates and the shared account
  summary provider. Its account balance section is intentionally current and
  not period-filtered.
- No old `source = manual` filter was found in financial aggregation paths.

## Legacy and Refresh Findings

- Legacy transactions are assigned to the canonical Default Account during
  import and are included in Wallet, Home, Reports, and Analytics.
- Import completion invalidates Home, transaction history, Reports, and category
  providers. Account summaries also update reactively because their Drift query
  watches accounts, transactions, and transfers.
- No restart is required for the corrected Home total. Restart persistence uses
  the same database-derived queries.

## Fix

`DashboardRepository` now derives `totalAssets` from
`AccountRepository.watchSummaries()` rather than duplicating the transaction
balance formula. The month-to-date income/expense and today-count query remains
transaction-based, matching Home's explicit labels.

No importer, schema, migration, transfer, or persisted balance changes were
made.

## Regression Coverage

Added dashboard coverage for:

- initial balance contributing to Total Assets;
- income and expense flow remaining separate;
- internal transfer preserving Total Assets;
- updated Home labels.

Existing Reports and Analytics coverage covers transfer exclusion, soft-delete
handling, archived-account history, missing categories, legacy transactions,
filters, and provider reactivity.

## Validation

```text
dart format .             PASS
flutter analyze           PASS
flutter test              PASS (223 tests)
flutter build apk --debug PASS
```

Known non-blocking output consists of dependency update notices, PDF Helvetica
Unicode warnings, and an existing widget-test hit-test warning.
