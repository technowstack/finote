# Phase 6A.5: Transaction History Integration

## Scope

The main Finote transaction history now presents active income, expense, and
transfer records as one financial activity timeline. Transfers remain rows in
the dedicated `transfers` table and are not converted into transactions.

Report drill-down history, Reports calculations, and exports remain unchanged
for their later phases.

## Unified Activity Model

`FinancialActivity` is a small presentation/domain model with:

- `FinancialActivityType`: income, expense, or transfer;
- source entity ID and UUID;
- financial calendar date;
- amount;
- title and subtitle;
- optional transaction category name.

Stable activity identity is typed as `transaction:<uuid>` or
`transfer:<uuid>`, preventing collisions between tables and avoiding list
position identity.

## Query Strategy

`FinancialActivityRepository.watch()` runs one reactive SQLite `UNION ALL`
query. It does not load two lists in the widget or perform account lookups per
row.

The transaction branch joins categories and assigned accounts. The transfer
branch joins source and destination accounts with aliases. Both branches use
left joins and the fallback `Akun tidak tersedia`, so malformed missing account
relations do not crash the history screen.

Soft-deleted transactions and transfers are excluded in SQL. A global transfer
is selected once, so it appears exactly once rather than as separate incoming
and outgoing rows.

## Ordering and Grouping

Activities sort by:

1. financial activity date, newest first;
2. creation timestamp, newest first;
3. stable activity kind and entity ID for deterministic same-time ties.

The existing list grouping is reused with `FinancialActivity.date`. A date
header is emitted only before the first activity for that date.

## Presentation

Income and expense retain their existing signed IDR and semantic colors:

```text
+Rp10.000.000
-Rp75.000
```

Transfer rows use a Material color-scheme tertiary accent, a transfer icon,
and an unsigned amount:

```text
Transfer ke BCA Tabungan
BCA Utama → BCA Tabungan
Rp2.000.000
```

Icons, labels, and amount signs distinguish activity types without relying on
color alone. Long titles and account directions use ellipsis while the existing
currency widget protects the amount layout.

Transaction rows continue to open transaction edit. Transfer rows open the
existing transfer management route and immediately display its edit flow.
Swipe deletion dispatches to the correct repository and remains soft-delete
only.

## Filters and Search

The main history type filters are:

- Semua;
- Pemasukan;
- Pengeluaran;
- Transfer.

The existing Today, Week, Month, and custom inclusive date ranges apply to both
entity tables using their respective financial dates.

Search matches:

- transaction title, note, category, and assigned account name;
- transfer note, source account name, and destination account name.

The existing history UI has no category filter or account filter, so neither
was added in this phase. If a category filter is introduced later, transfers
must be excluded because they have no category.

## Financial Safety

This feature is read/presentation integration only. It does not create derived
transaction rows or change balance formulas.

- Dashboard and Reports remain based on income/expense transactions.
- Excel, Text, and PDF remain transaction-only.
- Account balances continue to use the Phase 6A.4 derived formula.
- A transfer does not alter global income, expense, or total assets.

## Archived and Missing Accounts

Archived account rows remain in the accounts table and therefore retain their
display names in historical transactions and transfers. Missing relations use
`Akun tidak tersedia` rather than failing the whole query.

## Performance

The unified query is database-filtered and resolves account/category labels in
the same SQL statement. Existing indexes on transaction account/date/deletion
and transfer source/destination/date/deletion remain sufficient; no schema or
index change was needed.

The performance fixture contains 10,000 transactions, of which 9,500 are
active, plus 5,000 transfers. The 14,500-row unified history query is measured
informationally without a brittle CI threshold.

## Regression Coverage

Tests cover:

- income, expense, and one transfer in one timeline;
- stable identity and deterministic ordering;
- transfer appearing exactly once;
- type and inclusive date filters;
- transfer note/source/destination search;
- date grouping and neutral transfer presentation;
- transaction and transfer soft-delete exclusion;
- transfer edit/date reactivity;
- archived account readability;
- transfer edit routing;
- restored transaction and transfer history;
- legacy-imported transactions with no synthesized transfers;
- large unified history loading;
- existing Dashboard, Reports, exports, and account balance suites.

## Known Limitations

- Report monthly drill-down remains transaction-only until Reports Integration.
- Transfers are not included in Reports or exports.
- The main history retains the existing full-result loading behavior; the
  current 14,500-row benchmark remains acceptable, but cursor pagination can be
  introduced if real-device measurements later require it.
- Physical-device font scaling, scrolling, restart, and manual workflow checks
  remain follow-up validation.

## Deferred Work

- Phase 6A.6: Reports Integration;
- Phase 6A.7: Export Integration;
- category/account filters and account-specific history;
- transfer report totals or analytics.
