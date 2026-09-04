# Core Transaction Save Hang Fix

Phase: **7D.5A - Core Transaction Save Hang Fix**

Status: **BLOCKED**

## Reproduction and last checkpoint

The available Flutter test environment did not reproduce the reported Add
Expense, Add Income, or Edit hang. The simplest Add Expense and Edit Expense
flows completed in about one second. Temporary debug-only checkpoints reached
the final UI checkpoint in both flows:

```text
TX_SAVE_UI_START
TX_SAVE_VALIDATION_START
TX_SAVE_VALIDATION_OK
TX_SAVE_REPOSITORY_START
TX_SAVE_DB_START
TX_SAVE_DB_INSERT_DONE
TX_SAVE_DB_TRANSACTION_DONE
TX_SAVE_REPOSITORY_DONE
TX_SAVE_POST_WRITE_START
TX_SAVE_POST_WRITE_DONE
TX_SAVE_NAV_START
TX_SAVE_NAV_DONE
TX_SAVE_UI_FINISH
```

No CPU loop, unresolved Future, database lock, or navigation stall was found
in the controlled runs. The logs were removed and did not include financial
data.

## Save path

Normal transaction save is:

```text
Form validation
↓
TransactionRepository.create/update
↓
one Drift database transaction
↓
one transaction INSERT or UPDATE
↓
return to form
↓
single route pop
```

Create validates the category and resolves the account inside its existing
atomic database boundary. Update validates the category, account, and linked
asset restriction inside its existing atomic boundary. No post-save aggregate
provider is awaited.

## Findings

- `AccountSummary`, transaction history, Reports, Investment Cashflow,
  `PortfolioSnapshot`, Net Worth, and Dashboard are read-only derived streams.
- No provider `build`, `ref.listen`, or `ref.listenManual` writes transaction
  data back to SQLite.
- No circular provider dependency or cyclic manual invalidation was found.
- Normal transactions do not enter AssetTransaction synchronization.
- Historical/manual `Pembelian Aset` and `Penjualan Aset` remain reporting
  categories only; they do not synthesize asset activities.
- Normal save produces zero Market API requests.
- No stored account balance is manually mutated.
- Transaction schema version is 10; required `account_id`, category, amount,
  type, source, and timestamp defaults/constraints are satisfied by inserts.
- No nested database transaction occurs in normal TransactionRepository create
  or update.

## Stabilization changes

The previous edit-audit changes remain in place:

1. `_save` ignores a second invocation while `_saving` is true.
2. All asynchronous work after loading begins is covered by `try/catch/finally`.
3. Loading is reset when the form remains mounted, including failure paths.
4. Linked Buy/Sell direct edits remain blocked so cashflow and asset activity
   cannot diverge.

No financial semantics, schema, or dependencies were changed.

## Tests

Added layered coverage for:

- direct Drift transaction insert with required defaults;
- repository Expense and Income creation;
- repository Expense and Income editing, including amount, title, note, date,
  and account changes;
- failed insert followed by a successful insert;
- UI Expense creation;
- UI Expense edit;
- rapid Save tap protection;
- direct linked Buy edit rejection.

Automated validation passes:

```text
flutter analyze: PASS
flutter test: PASS (281 tests)
flutter build apk --debug: PASS
```

## Blocker

The required runtime matrix has not been executed on the existing user
database because no Android emulator or physical device is connected. Income
UI, migrated-database CRUD, field-by-field Android edits, restart persistence,
and actual Market API request observation remain unverified.

Phase 7E.1 Backup/Restore remains **NOT STARTED**.
