# Phase 6A.10: Accounts & Transfers Testing and Polish

## Readiness Result

```text
PHASE 6A - ACCOUNTS & TRANSFERS: PASS
```

The complete Phase 6A feature is stabilization-ready for Finote v1.1.0. No
BLOCKER, CRITICAL, or unresolved HIGH issue remains in automated validation.
This phase adds no new finance feature and makes no schema change.

## Final Architecture

- `AccountRepository` owns account CRUD and one database-side reactive balance
  aggregation for all accounts.
- `TransactionRepository` validates account assignment and preserves archived
  account references for historical records.
- `TransferRepository` stores one neutral transfer record and now resolves both
  account labels in one reactive joined query.
- `FinancialActivityRepository` uses one filtered `UNION ALL` query for Income,
  Expense, and one Transfer row.
- `ReportRepository` keeps transaction totals and transfer summaries separate.
- `ExportRepository` creates one shared account/transaction/transfer document
  consumed by Excel, Text, and PDF.
- Backup/restore snapshots the complete SQLite database. Legacy import assigns
  imported records to the canonical Default Account.

## Financial Invariants

Global period values remain integer transaction flows:

```text
Income  = sum(active income transactions)
Expense = sum(active expense transactions)
Net     = Income - Expense
```

Transfers never enter Income, Expense, Net, category totals, or monthly flow.

Each current account balance is derived:

```text
initial balance
+ active income
- active expense
+ active incoming transfer
- active outgoing transfer
```

Total Assets is the sum of all retained account balances. An owned-account
transfer changes allocation but not Total Assets. Initial balance contributes to
the account and Total Assets, but is not Income and is not synthesized as a
transaction. Negative derived balances remain allowed.

## Golden Dataset

The final deterministic regression uses:

```text
BCA Utama initial                 Rp5.000.000
BCA Tabungan initial               Rp500.000
Income to BCA Utama              Rp10.000.000
Expense from BCA Utama            Rp1.000.000
Transfer Utama -> Tabungan         Rp2.000.000
Expense from BCA Tabungan             Rp50.000
```

Verified results:

```text
BCA Utama                         Rp12.000.000
BCA Tabungan                       Rp2.450.000
Total Assets                      Rp14.450.000
Income                            Rp10.000.000
Expense                            Rp1.050.000
Net                                Rp8.950.000
Transfer volume                    Rp2.000.000
```

Accounts, Reports, unified History, and the normalized export document reconcile
against these exact values.

## Accounts and Transactions

Account create, edit name/type/initial balance, archive, and reactivate paths
remain covered. The canonical Default Account uses `is_default`, is initialized
idempotently, cannot be archived through normal account management, and stays
available for transaction creation and legacy import.

New transactions resolve a valid active account. Editing can reassign an active
transaction; archived accounts remain readable on historical records. Amount,
type, account, date, and soft-delete mutations recalculate balances rather than
mutating a cached balance. Transaction soft delete removes the record from
History, Reports, and exports and reverses its account effect.

## Transfers and History

Transfer create validates active, distinct source/destination accounts and a
positive signed-64-bit integer amount. Edit supports amount, source,
destination, date, and note. Soft delete reverses both balance effects without
changing Income or Expense. Existing transfers remain readable after an account
is archived.

Transfer list account labels previously refreshed only when the Transfers table
changed. The root cause was a transfer-only watch followed by a separate account
lookup. It is now one joined reactive query that watches both aliases, removes
the stale-label bug, avoids per-row queries, and adds stable ID ordering.

Unified History keeps deterministic date/creation/type/ID ordering, inclusive
date filters, type filters, and search over transaction/category/account and
transfer note/source/destination fields. A transfer appears once with an
unsigned neutral amount, direction, label, and icon.

## Reports and Export

Reports distinguish `Saldo periode`, `Saldo akun saat ini`, and `Total aset`.
Account summaries use the shared balance provider; archived account balances
remain included in Total Assets. Transfer count and volume are period-filtered
and counted once.

Excel retains `Ringkasan`, `Transaksi`, `Akun`, and `Transfer` sheets with
numeric money and spreadsheet dates. Text remains UTF-8 and separates account,
transfer, and transaction sections. PDF remains valid and multi-page. Shared
filters and soft-delete rules keep all formats aligned with Reports. Archived
account names resolve safely.

## Data Safety

- Fresh schema 8 creates one Default Account, all required indexes, and an empty
  Transfers table.
- Automated migration paths cover schema 1, populated schema 2, account schema
  4, pre-transfer schema 6, and index-repair schema 7 to schema 8.
- No migration catch deletes or recreates a production database.
- Version-3 pre-account backup restore creates the Default Account, backfills
  account relations, preserves financial rows, and creates no transfer.
- Current backup/restore preserves account/transaction/transfer IDs, UUIDs,
  relationships, active and soft-delete states, and refreshes providers.
- Corrupt, incompatible, orphaned, or unsupported restore data is rejected
  before replacing the live database; rollback and safety-backup paths remain.
- Legacy import remains read-only, repeat-safe, source-aware, Default
  Account-assigned, and transfer-free. Reimport preserves edits, reassignment,
  and soft delete.

## Performance and Index Audit

The measured synthetic path contains 10,000 transactions, 5,000 transfers, and
three accounts. It loads 14,500 active unified-history rows, search, dashboard,
Reports, all account balances, shared export data, Text, Excel, multi-page PDF,
backup, restore, and post-restore verification without a crash.

Observed final run:

```text
history                 520 ms
unified history         275 ms
search                    11 ms
dashboard                  6 ms
report                     15 ms
account balances           11 ms
export data               500 ms
text                      160 ms
excel                     287 ms
PDF 10,000 rows        12,323 ms
backup                    165 ms
restore and verify        907 ms
```

Timings are informational and hardware-dependent. Existing indexes cover
transaction account/date/deletion and transfer source/destination/date/deletion
queries. No speculative index was added. PDF remains the known expensive path.

## UX Polish

- Default Account no longer offers an action that repository rules reject.
- Account cards use the explicit label `Saldo Saat Ini`.
- Long transfer directions and notes ellipsize instead of overflowing.
- Large transfer values scale down within a bounded trailing area.
- Small-screen transfer layout passes at 1.3x text scaling.
- Account and transfer surfaces continue to use Material `ColorScheme`; transfer
  presentation remains neutral and not expense-red.
- Save controls retain existing in-flight disabling and friendly Indonesian
  errors; raw database errors are not shown.

## Privacy and Product Boundary

Phase 6A adds no amount, account-name, transaction-note, or transfer-note logs.
Backup remains local and user initiated. A Finote transfer is explicitly an
internal financial record; it does not move bank funds and introduces no bank,
payment, cloud, or AI integration.

## Validation

```text
dart format .                                      PASS
dart run build_runner build --delete-conflicting-outputs PASS
flutter analyze                                    PASS
flutter test                                       PASS (179 tests)
flutter build apk --debug                          PASS
flutter build apk --release                        PASS
```

Build runner reported that the requested conflicting-output option is removed
by the installed version and ignored; generation itself completed successfully
and produced no tracked generated diff.

## Known Limitations

- Real-device file picker/share/open workflows and external Excel/PDF rendering
  were not exercised in this automated environment.
- Physical process death, Android activity recreation, and actual device restart
  remain manual release checks; persistence and provider refresh are covered at
  database/provider level.
- Theme modes use the shared app ColorScheme, but all Account/Transfer workflows
  were not manually traversed on a physical device in each mode.
- PDF generation for 10,000 rows is successful but materially slower than other
  formats.
- Release build emits non-blocking toolchain/font-tree-shaking warnings; the APK
  is produced successfully.

## Remaining Issues

```text
BLOCKER  none
CRITICAL none
HIGH     none
MEDIUM   none identified in Phase 6A scope
LOW      physical-device/manual release checks remain
```

No later product phase is started.
