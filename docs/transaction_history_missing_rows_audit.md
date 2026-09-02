# Transaction History Missing Rows Audit

## Result

**TRANSACTION HISTORY MISSING ROWS AUDIT: PASS**

The destination data and main history query were not losing imported rows. The
main History screen defaults to `Bulan ini`, so older legacy transactions are
outside the visible date range. The query already exposes them when the date
filter is removed or an older custom range is selected.

## Pipeline And Counts

For the deterministic activity fixture:

```text
Active destination transaction rows: 2 transactions + 1 transfer
FinancialActivityRepository result: 3 activities
Rendered activity rows:             3 rows
```

For the older-row regression fixture, two additional legacy transactions on
`10 Sep 2020` are returned by the all-time query, including both rows with the
same date and amount. No production database is available in the repository,
so real-user counts require running the same queries against that database.

## Findings

- The actual main History UI uses `FinancialActivityRepository.watch()`, not
  `TransactionRepository.watchHistory()`.
- The activity query uses `UNION ALL`, has no source restriction, and excludes
  only `deleted_at IS NOT NULL` records.
- Transaction and transfer account/category joins are `LEFT JOIN`; missing
  metadata uses safe display fallbacks and does not remove the activity.
- Archived accounts remain readable because account active state is not a
  query predicate.
- There is no `DISTINCT`, `GROUP BY`, or presentation deduplication.
- Main History has no pagination or load-more boundary; it loads the full
  filtered activity result. Home intentionally requests only five recent
  transactions.
- Activity ordering is stable: date descending, creation timestamp descending,
  activity kind descending, then entity ID descending. The legacy
  `TransactionRepository` path now also uses transaction ID as its final tie
  breaker.
- Type filters correctly separate Semua, Pemasukan, Pengeluaran, and Transfer.
- Soft-deleted transactions and transfers are correctly excluded.

## Root Cause And Fix

The apparent missing rows were old transactions hidden by the default
`Bulan ini` filter. The filter was visible but there was no direct all-time
choice. Main History now provides `Semua`, while preserving the existing month,
today, week, and custom date filters.

No importer, financial aggregation, account balance, Reports, or transfer
semantics were changed.

## Representative Trace

```text
Legacy transaction in destination DB
  -> source = legacy_import, valid account/category, deleted_at = NULL
  -> FinancialActivityRepository includes it when date predicate matches
  -> FinancialActivity model preserves UUID/entity ID
  -> _GroupedActivityList renders one row with stable Dismissible identity
```

When the default month predicate does not match, the row is intentionally not
returned; selecting `Semua` or its historical custom range returns it.

## Refresh And UI Behavior

The activity query watches transactions, transfers, categories, and accounts,
so successful import writes update the stream without restart. Import completion
also invalidates the existing transaction history provider. `Lihat semua` on
Home routes to the complete activity History; Home itself remains limited to
the latest five transaction rows by design.

## Regression Coverage

Added coverage for:

- older legacy transactions through the all-time activity query;
- two same-date/same-amount rows remaining distinct;
- legacy source inclusion.

Existing coverage covers normal income/expense, transfers, archived accounts,
search, date/type filters, soft deletes, stable activity identity, and UI
rendering.

## Validation

```text
dart format .             PASS
flutter analyze           PASS
flutter test              PASS (225 tests)
flutter build apk --debug PASS
```

Known non-blocking output consists of dependency notices, PDF Helvetica Unicode
warnings, and one existing widget-test hit-test warning.
