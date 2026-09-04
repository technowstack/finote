# Reactive Transaction State and Main-Isolate Hang Fix

Phase: **7D.5B - Reactive Transaction State & Main-Isolate Hang Fix**

Status: **BLOCKED - automated correction complete; Android runtime verification unavailable**

## Reported behavior

A transaction write completed in SQLite, but Transaction History and Dashboard
could remain stale until a manual refresh. The app could then hang with the main
isolate stuck.

No connected Android emulator or physical device is available in this
environment. The reported user database and a frozen main-isolate stack could
therefore not be captured. The runtime correlation remains unproven.

## Reactive path audit

The normal production path uses one root `ProviderScope`, one non-auto-disposed
`databaseProvider`, and repositories that watch that provider. No second
production `AppDatabase` was found in normal transaction CRUD.

Transaction History already uses one Drift `customSelect().watch()` with
explicit dependencies on transactions, transfers, categories, and accounts.
Normal create, update, and soft delete operations notify its active
subscription without manual invalidation.

No provider cycle, write-on-read provider, aggregate write-back, or Market API
request was found in the transaction save path.

## Corrected hazards

1. The transaction form called `FormState.validate()` while its widget tree was
   building. Validation mutates Form state and could repeatedly dirty the main
   isolate during provider-driven rebuilds. Category error visibility is now
   explicit state changed only by user validation or selection.
2. Successful save navigation could be followed by `_saving` state mutation in
   `finally` while the route was leaving. Loading state now resets only when the
   form remains active because save failed or was cancelled.
3. Dashboard summary nested an account stream with `monthly.first` inside
   `asyncMap`. It is now one Drift-watched aggregate query over accounts and
   active transactions, preserving account-balance and transfer-neutral
   semantics without nested subscriptions.
4. Account summaries used `asyncMap` followed by a second one-shot account
   query for every aggregate emission. The watched query now returns and maps
   the account record and balances together in one emission.

The corrected local flow is:

```text
TransactionRepository create/update/softDelete
-> Drift table notification
-> active Transaction History, Account Summary, and Dashboard queries
-> Riverpod StreamProvider emission
-> widget rebuild
```

Transaction save still does not await Dashboard, Reports, Net Worth, Portfolio,
or any Market API work.

## Regression coverage

- Active Transaction History subscription emits after create, update, and soft
  delete without invalidation.
- Active Dashboard subscription emits after transaction create/update and
  account create/update.
- Initial transaction-form builds do not show validation errors or produce a
  framework exception.
- Rapid Save remains guarded.
- Existing account, transfer, report, export, Net Worth, asset, backup, restore,
  migration, and performance coverage remains green.

Validation:

```text
dart format .: PASS
flutter analyze: PASS
flutter test: PASS (283 tests)
flutter build apk --debug: PASS
git diff --check: PASS
```

## Remaining runtime blocker

Required Android verification remains:

- Add, edit, and delete Expense and Income against the existing user database;
- immediate Transaction History and Dashboard updates without manual refresh;
- repeated Dashboard refresh without a hang;
- frozen top main-isolate stack frames if any hang remains;
- restart persistence and zero Market API requests during normal finance CRUD.

Phase 7E.1 Backup/Restore remains **NOT STARTED**.
